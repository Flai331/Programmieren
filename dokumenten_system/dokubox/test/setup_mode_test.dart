import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
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

  Future<Document> add(String title, DateTime? date) async {
    final n = await repo.nextProvisionalNumber();
    return repo.createDocument(
      docNumber: n,
      draft: DocumentDraft(
          title: title, docDate: date, correspondentName: 'enviaM',
          storageLocation: 'Box 2026'),
      pdfPath: 'pdfs/$n.pdf',
      pageCount: 1,
      ocrText: 'text $title',
    );
  }

  test('Ersterfassung: vorläufig sammeln, dann nach Datum nummerieren',
      () async {
    final now = DateTime(2026, 11, 11);
    // Eine normale Nummer gibt es schon.
    expect(await repo.nextDocNumber(now: now), '2026-0001');

    final a = await add('März', DateTime(2025, 3, 1));
    final b = await add('ohne Datum', null);
    final c = await add('Januar', DateTime(2024, 1, 15));
    expect([a.docNumber, b.docNumber, c.docNumber],
        ['V-0001', 'V-0002', 'V-0003']);
    expect(DocumentRepository.isProvisional(a.docNumber), isTrue);
    expect(await repo.watchProvisionalCount().first, 3);

    final result = await repo.assignFinalNumbers(now: now);
    expect(result.map((r) => '${r.oldNumber}→${r.doc.docNumber}'), [
      'V-0003→2026-0002', // Januar 2024
      'V-0001→2026-0003', // März 2025
      'V-0002→2026-0004', // ohne Datum
    ]);
    expect(result.first.sender, 'enviaM');
    expect(result.first.renames, {'pdfs/V-0003.pdf': 'pdfs/2026-0002.pdf'});
    expect(result.first.doc.pdfPath, 'pdfs/2026-0002.pdf');
    expect(await repo.watchProvisionalCount().first, 0);

    // Suche findet die neue Nummer, nicht mehr die alte.
    expect((await repo.watchDocuments(const DocumentFilter(query: '2026-0002'))
                .first)
            .single
            .title,
        'Januar');
    expect(
        await repo.watchDocuments(const DocumentFilter(query: 'V-0003')).first,
        isEmpty);

    // Nächste Ersterfassung beginnt wieder bei V-0001.
    expect(await repo.nextProvisionalNumber(), 'V-0001');
  });

  test('Verworfener vorläufiger Scan gibt die Nummer zurück', () async {
    final n = await repo.nextProvisionalNumber();
    await repo.releaseDocNumberIfUnused(n);
    expect(await repo.nextProvisionalNumber(), n);
  });
}
