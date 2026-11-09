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

  test('Vorlagen anlegen, umbenennen, löschen', () async {
    final t = await repo.addTemplate(
        name: ' Unterschrift ', imagePath: 'vorlagen/a.png', aspect: 0.3);
    expect(t.name, 'Unterschrift');
    expect((await repo.allTemplates()).single.aspect, 0.3);
    await repo.renameTemplate(t.id, 'Kürzel');
    expect((await repo.allTemplates()).single.name, 'Kürzel');
    await repo.deleteTemplate(t.id);
    expect(await repo.allTemplates(), isEmpty);
    // Gelöschte bleiben für bestehende Eintragungen abrufbar.
    expect((await repo.getTemplate(t.id))?.imagePath, 'vorlagen/a.png');
  });

  test('ausgefüllte Kopie speichern und verwerfen', () async {
    final doc = await repo.createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(title: 'Antrag', storageLocation: 'Box 2026'),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 'antrag',
    );
    await repo.saveFill(doc.id,
        fillData: '{"items":[]}',
        filledPdfPath: 'pdfs/2026-0001_ausgefuellt.pdf');
    var saved = (await repo.getDocument(doc.id))!;
    expect(saved.filledPdfPath, 'pdfs/2026-0001_ausgefuellt.pdf');
    expect(saved.pdfPath, 'pdfs/2026-0001.pdf'); // Original unverändert
    await repo.clearFill(doc.id);
    saved = (await repo.getDocument(doc.id))!;
    expect(saved.filledPdfPath, isNull);
    expect(saved.fillData, isNull);
  });
}
