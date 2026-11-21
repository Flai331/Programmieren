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

  Future<Document> add(String number, DateTime date, {bool pending = false}) =>
      repo.createDocument(
        docNumber: number,
        draft: DocumentDraft(
            title: number,
            docDate: date,
            tagNames: [if (pending) DocumentRepository.pendingTag]),
        pdfPath: 'pdfs/$number.pdf',
        pageCount: 1,
        ocrText: '',
      );

  test('gesammelt → auslesen → nur diese bekommen Nummern', () async {
    final a = await add(await repo.nextProvisionalNumber(), DateTime(2024, 5), pending: true);
    final b = await add(await repo.nextProvisionalNumber(), DateTime(2023, 1), pending: true);
    expect(await repo.watchPendingCount().first, 2);
    expect((await repo.pendingReview()).map((d) => d.id), [a.id, b.id]);

    await repo.updateDocument(b.id, DocumentDraft(title: 'B', docDate: DateTime(2023, 1)));
    expect(await repo.watchPendingCount().first, 1);

    final r = await repo.assignFinalNumbers(onlyIds: {b.id});
    expect(r.single.doc.id, b.id);
    expect(DocumentRepository.isProvisional((await repo.getDocument(a.id))!.docNumber), isTrue);
    expect(await repo.finalNumberedCount(), 1);
  });

  test('Nummern zurücksetzen und nach Datum neu vergeben', () async {
    final x = await add(await repo.nextDocNumber(), DateTime(2025, 3));
    final y = await add(await repo.nextDocNumber(), DateTime(2020, 1));
    final renames = await repo.resetNumbersToProvisional();
    expect(renames.length, 2);
    expect(await repo.finalNumberedCount(), 0);
    final r = await repo.assignFinalNumbers();
    final byId = {for (final n in r) n.doc.id: n.doc.docNumber};
    expect(byId[y.id]!.endsWith('0001'), isTrue);
    expect(byId[x.id]!.endsWith('0002'), isTrue);
  });
}
