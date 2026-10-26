import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/finance.dart';
import 'package:dokubox/extract/suggestion_service.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    repo = DocumentRepository(db);
  });

  tearDown(() => db.close());

  DocumentDraft draft({
    String title = 'Testdokument',
    String? correspondent,
    String? docType,
    List<String>? tags,
  }) =>
      DocumentDraft(
        title: title,
        correspondentName: correspondent,
        docType: docType,
        tagNames: tags,
        storageLocation: 'Box 2026',
      );

  Future<Document> create(
    String number, {
    String title = 'Testdokument',
    String ocr = '',
    String? correspondent,
    String? docType,
    List<String>? tags,
  }) =>
      repo.createDocument(
        docNumber: number,
        draft: draft(
            title: title,
            correspondent: correspondent,
            docType: docType,
            tags: tags),
        pdfPath: 'pdfs/$number.pdf',
        pageCount: 1,
        ocrText: ocr,
      );

  group('Nummernvergabe', () {
    test('vergibt fortlaufend pro Jahr im Format JJJJ-NNNN', () async {
      final now = DateTime(2026, 7, 19);
      expect(await repo.nextDocNumber(now: now), '2026-0001');
      expect(await repo.nextDocNumber(now: now), '2026-0002');
      expect(await repo.nextDocNumber(now: DateTime(2027, 1, 1)), '2027-0001');
    });

    test('releaseDocNumberIfUnused dreht nur die letzte Nummer zurück',
        () async {
      final now = DateTime(2026, 1, 1);
      final n1 = await repo.nextDocNumber(now: now);
      await create(n1);
      final n2 = await repo.nextDocNumber(now: now);
      // n2 wurde nie gespeichert → freigeben.
      await repo.releaseDocNumberIfUnused(n2);
      expect(await repo.nextDocNumber(now: now), n2);
      // n1 ist benutzt → kein Rollback möglich.
      await repo.releaseDocNumberIfUnused(n1);
      expect(await repo.nextDocNumber(now: now), '2026-0003');
    });
  });

  group('Dokumente + Volltextsuche', () {
    test('FTS findet Dokument über OCR-Text, Präfix und Nummer', () async {
      await create('2026-0001',
          title: 'KFZ-Police',
          ocr: 'Versicherungsschein Beitragserhöhung zum 01.01.2027',
          correspondent: 'HUK-COBURG');
      await create('2026-0002', title: 'Stromrechnung', ocr: 'Abschlag');

      Future<List<Document>> search(String q) =>
          repo.watchDocuments(DocumentFilter(query: q)).first;

      expect((await search('Beitragserhöhung')).single.docNumber, '2026-0001');
      expect((await search('beitrags')).single.docNumber, '2026-0001');
      expect((await search('HUK')).single.docNumber, '2026-0001');
      expect((await search('2026-0002')).single.docNumber, '2026-0002');
      expect(await search('existiertnicht'), isEmpty);
    });

    test('Filter nach Typ und Jahr', () async {
      await create('2025-0001', docType: 'Rechnung');
      await create('2026-0001', docType: 'Vertrag');

      final byType = await repo
          .watchDocuments(const DocumentFilter(docType: 'Vertrag'))
          .first;
      expect(byType.single.docNumber, '2026-0001');

      final byYear =
          await repo.watchDocuments(const DocumentFilter(year: 2025)).first;
      expect(byYear.single.docNumber, '2025-0001');
    });

    test('Soft-Delete entfernt aus Liste und Suche', () async {
      final doc = await create('2026-0001', ocr: 'unauffindbar');
      await repo.softDeleteDocument(doc.id);
      expect(await repo.watchDocuments(const DocumentFilter()).first, isEmpty);
      expect(
          await repo
              .watchDocuments(const DocumentFilter(query: 'unauffindbar'))
              .first,
          isEmpty);
    });

    test('Tags werden angelegt und wiederverwendet', () async {
      final d1 = await create('2026-0001', tags: ['Auto', 'Versicherung']);
      final d2 = await create('2026-0002', tags: ['auto']);
      expect(await repo.tagNamesForDocument(d1.id), ['Auto', 'Versicherung']);
      // Groß-/Kleinschreibung: kein Duplikat-Tag.
      expect(await repo.tagNamesForDocument(d2.id), ['Auto']);
      final tags = await repo.watchTags().first;
      expect(tags.map((t) => t.name), ['Auto', 'Versicherung']);
    });
  });

  group('Lernende Zuordnungen', () {
    test('zweites Dokument desselben Absenders erbt Typ und Tags', () async {
      await create('2026-0001',
          correspondent: 'HUK-COBURG',
          docType: 'Versicherungspolice',
          tags: ['Auto']);

      final suggestions = SuggestionService(repo);
      final suggested = await suggestions.buildDraft(
          'HUK-COBURG\nIhre Unterlagen\nDatum 01.02.2026');

      expect(suggested.correspondentName, 'HUK-COBURG');
      expect(suggested.docType, 'Versicherungspolice');
      expect(suggested.tagNames, ['Auto']);
      expect(suggested.docDate, DateTime(2026, 2, 1));
    });

    test('Keyword-Regel schlägt gelernten Typ, wenn beides da ist', () async {
      await create('2026-0001',
          correspondent: 'Stadtwerke', docType: 'Vertrag');
      final suggestions = SuggestionService(repo);
      final suggested =
          await suggestions.buildDraft('Stadtwerke\nRechnung Nr. 42');
      // Text sagt eindeutig "Rechnung" → Regel gewinnt.
      expect(suggested.docType, 'Rechnung');
    });
  });

  group('Ausmistliste', () {
    test('listet nur abgelaufene, nicht vernichtete Dokumente', () async {
      final expired = DocumentDraft(
        title: 'Alt',
        storageLocation: 'Box 2020',
        retentionUntil: DateTime(2023, 12, 31),
      );
      final doc = await repo.createDocument(
        docNumber: '2020-0001',
        draft: expired,
        pdfPath: 'pdfs/2020-0001.pdf',
        pageCount: 1,
        ocrText: '',
      );
      await create('2026-0001'); // ohne Frist → nicht in der Liste

      final candidates = await repo.watchCleanupCandidates().first;
      expect(candidates.single.id, doc.id);

      await repo.markDestroyed(doc.id);
      expect(await repo.watchCleanupCandidates().first, isEmpty);
    });
  });

  group('Rechnungen & Erstattung', () {
    Future<Document> bill(String number,
            {String status = PaymentStatus.open,
            DateTime? due,
            List<ClaimDraft>? claims}) =>
        repo.createDocument(
          docNumber: number,
          draft: DocumentDraft(
            title: 'Rechnung $number',
            storageLocation: 'Box 2026',
            amountCents: 5000,
            paymentStatus: status,
            dueDate: due,
            paymentReminderAt: due,
            claims: claims,
          ),
          pdfPath: 'pdfs/$number.pdf',
          pageCount: 1,
          ocrText: '',
        );

    test('offene Rechnungen nach Fälligkeit, bezahlt fällt raus', () async {
      final late = await bill('2026-0001', due: DateTime(2026, 12, 1));
      final soon = await bill('2026-0002', due: DateTime(2026, 11, 1));
      await bill('2026-0003', status: PaymentStatus.paid);

      final open = await repo.watchOpenPayments().first;
      expect(open.map((d) => d.id), [soon.id, late.id]);

      await repo.markPaid(soon.id, at: DateTime(2026, 10, 30));
      final paid = await repo.getDocument(soon.id);
      expect(paid!.paymentStatus, PaymentStatus.paid);
      expect(paid.paidAt, DateTime(2026, 10, 30));
      expect(paid.paymentReminderAt, isNull);
      expect((await repo.watchOpenPayments().first).single.id, late.id);
    });

    test('Einreichungen: anlegen, Status setzen, Filter, Zähler', () async {
      final doc = await bill('2026-0001', claims: [
        ClaimDraft(target: 'Beihilfe'),
        ClaimDraft(target: 'Private Krankenversicherung'),
      ]);
      expect(await repo.watchOpenFinanceCount().first, 3); // 1 Rechnung + 2

      final claims = await repo.claimsForDocument(doc.id);
      final beihilfe = claims.firstWhere((c) => c.target == 'Beihilfe');
      await repo.setClaimStatus(beihilfe.id, ClaimStatus.submitted,
          at: DateTime(2026, 10, 1), followUpWeeks: 6);
      final submitted = (await repo.claimsForDocument(doc.id))
          .firstWhere((c) => c.id == beihilfe.id);
      expect(submitted.submittedAt, DateTime(2026, 10, 1));
      expect(submitted.followUpAt, DateTime(2026, 11, 12, 9));

      final byFilter = await repo
          .watchDocuments(
              const DocumentFilter(financeStatus: ClaimStatus.submitted))
          .first;
      expect(byFilter.single.id, doc.id);

      await repo.setClaimStatus(beihilfe.id, ClaimStatus.partly,
          reimbursedCents: 3500);
      final settled = (await repo.claimsForDocument(doc.id))
          .firstWhere((c) => c.id == beihilfe.id);
      expect(settled.reimbursedCents, 3500);
      expect(settled.followUpAt, isNull);
      expect((await repo.watchOpenClaims().first).single.claim.target,
          'Private Krankenversicherung');
    });

    test('Bearbeiten ersetzt Einreichungen (entfernte per Soft-Delete)',
        () async {
      final doc = await bill('2026-0001',
          claims: [ClaimDraft(target: 'Krankenkasse')]);
      final kept = ClaimDraft.fromClaim(
          (await repo.claimsForDocument(doc.id)).single)
        ..status = ClaimStatus.submitted;
      await repo.updateDocument(
        doc.id,
        DocumentDraft(
          title: 'Rechnung',
          storageLocation: 'Box 2026',
          paymentStatus: PaymentStatus.paid,
          claims: [kept, ClaimDraft(target: 'Zusatzversicherung')],
        ),
      );
      var claims = await repo.claimsForDocument(doc.id);
      expect(claims.map((c) => '${c.target}:${c.status}'),
          ['Krankenkasse:eingereicht', 'Zusatzversicherung:einzureichen']);

      await repo.updateDocument(
        doc.id,
        DocumentDraft(title: 'Rechnung', storageLocation: 'Box 2026'),
      );
      claims = await repo.claimsForDocument(doc.id);
      expect(claims, isEmpty);
      expect(
          await repo.claimsForDocument(doc.id, includeDeleted: true),
          hasLength(2));
    });
  });
}
