import 'dart:io';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/sync/mirror.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ablage-Ordner: anlegen, umbenennen, Papierkorb', () async {
    final tmp = await Directory.systemTemp.createTemp('dokubox_ablage');
    final app = Directory('${tmp.path}/app')..createSync();
    final ablage = Directory('${tmp.path}/Ablage');
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    File('${app.path}/pdfs/2026-0001.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('pdf');
    final doc = await repo.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(
            title: 'Abschlag Strom', correspondentName: 'enviaM',
            docDate: DateTime(2025, 3, 1), storageLocation: 'Box'),
        pdfPath: 'pdfs/2026-0001.pdf',
        pageCount: 1,
        ocrText: '');
    final m = AblageMirror(repo, ablage, (r) async => '${app.path}/$r');
    await m.update([doc.id]);
    final f = File('${ablage.path}/2025/Energie & Wohnen/2026-0001 enviaM Abschlag Strom.pdf');
    expect(f.existsSync(), isTrue);

    await repo.updateDocument(doc.id, DocumentDraft(
        title: 'Jahresabrechnung', correspondentName: 'enviaM',
        docDate: DateTime(2025, 3, 1), storageLocation: 'Box'));
    await m.update([doc.id]);
    expect(f.existsSync(), isFalse);
    expect(File('${ablage.path}/2025/Energie & Wohnen/2026-0001 enviaM Jahresabrechnung.pdf')
        .existsSync(), isTrue);

    await repo.softDeleteDocument(doc.id);
    await m.update([doc.id]);
    expect(File('${ablage.path}/_Papierkorb/2026-0001 enviaM Jahresabrechnung.pdf')
        .existsSync(), isTrue);
    await db.close();
    await tmp.delete(recursive: true);
  });
}
