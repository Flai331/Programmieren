import 'package:dokubox/data/cases.dart';
import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/extract/duplicates.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _brief = 'Sehr geehrte Damen und Herren, anbei erhalten Sie die '
    'Abrechnung für den Zeitraum Januar bis Dezember mit allen Positionen '
    'und dem Gesamtbetrag zur Kenntnis. Mit freundlichen Grüßen';

void main() {
  late AppDatabase db;
  late DocumentRepository repo;
  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    repo = DocumentRepository(db);
  });
  tearDown(() => db.close());

  Future<Document> add(String nr, String title,
          {String firm = 'Finanzamt',
          DateTime? date,
          String text = '',
          String? hash,
          String? type,
          Map<String, Set<String>> refs = const {},
          List<String> link = const []}) =>
      repo.createDocument(
        docNumber: nr,
        draft: DocumentDraft(
            title: title,
            correspondentName: firm,
            docDate: date,
            docType: type,
            storageLocation: 'Box',
            contentHash: hash,
            linkDocumentIds: link),
        pdfPath: '$nr.pdf',
        pageCount: 1,
        ocrText: text,
        refs: refs,
      );

  test('Textähnlichkeit', () {
    expect(textSimilarity(_brief, '$_brief '), greaterThan(0.95));
    expect(textSimilarity(_brief, 'Ganz anderer Brief über etwas völlig '
        'anderes mit neuen Wörtern und Sätzen ohne Bezug'), lessThan(0.1));
    expect(textSimilarity('kurz', 'kurz'), 0);
  });

  test('Dubletten: Datei, Rechnungsnummer, Text', () async {
    final a = await add('2026-0001', 'Abrechnung',
        firm: 'enviaM',
        date: DateTime(2026, 3, 1),
        text: _brief,
        hash: 'abc',
        refs: {
          'RGNR': {'R-2026-77'}
        });
    expect(
        (await repo.findDuplicates(contentHash: 'abc')).single.reason,
        'gleiche Datei');
    expect(
        (await repo.findDuplicates(
                refs: {
                  'RGNR': {'R 2026 77'}
                },
                correspondentName: 'enviam'))
            .single
            .doc
            .id,
        a.id);
    expect(
        (await repo.findDuplicates(
                correspondentName: 'enviaM',
                ocrText: _brief,
                docDate: DateTime(2026, 3, 5)))
            .single
            .reason,
        'fast gleicher Text');
    // andere Firma → kein Treffer über Text
    expect(
        await repo.findDuplicates(
            correspondentName: 'Allianz', ocrText: _brief),
        isEmpty);
  });

  test('Verknüpfen legt Vorgang an und nimmt weitere auf', () async {
    final antrag = await add('2026-0001', 'Antrag Beihilfe',
        date: DateTime(2026, 1, 10));
    final bescheid = await add('2026-0002', 'Bescheid',
        date: DateTime(2026, 2, 1), type: 'Bescheid', link: [antrag.id]);
    final cases = await repo.casesForDocument(antrag.id);
    expect(cases.single.title, 'Finanzamt – Antrag Beihilfe');
    expect((await repo.casesForDocument(bescheid.id)).single.id,
        cases.single.id);
    // drittes Dokument verknüpft mit dem Bescheid → gleicher Vorgang
    final widerspruch = await add('2026-0003', 'Widerspruch',
        date: DateTime(2026, 2, 20), link: [bescheid.id]);
    final docs = await repo.watchCaseDocuments(cases.single.id).first;
    expect(docs.map((d) => d.doc.id), [antrag.id, bescheid.id, widerspruch.id]);
    expect(docs[1].role, 'bescheid');

    expect(await repo.watchOpenCaseCount().first, 1);
    await repo.setCaseStatus(cases.single.id, 'erledigt');
    expect(await repo.watchOpenCaseCount().first, 0);
    final all = await repo.watchCases().first;
    expect(all.single.docs, 3);

    await repo.removeFromCase(cases.single.id, widerspruch.id);
    expect((await repo.watchCaseDocuments(cases.single.id).first).length, 2);
    // doppelt hinzufügen bleibt einmal
    await repo.addToCase(cases.single.id, antrag.id);
    expect((await repo.watchCaseDocuments(cases.single.id).first).length, 2);
  });

  test('Rolle aus Dokumenttyp', () {
    expect(guessCaseRole('Bescheid'), 'bescheid');
    expect(guessCaseRole(null), 'sonstiges');
  });
}
