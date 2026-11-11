import 'dart:io';

import 'package:dokubox/backup/backup_service.dart';
import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Backup mit PDFs, Vorlagen, Anhängen → Wiederherstellen', () async {
    final root = await Directory.systemTemp.createTemp('dokubox_backup');
    final docs = Directory('${root.path}/docs')..createSync();
    final temp = Directory('${root.path}/tmp')..createSync();
    final target = Directory('${root.path}/neu')..createSync();
    for (final f in [
      'pdfs/2026-0001.pdf',
      'vorlagen/sig.png',
      'anhaenge/foto.jpg',
    ]) {
      File('${docs.path}/$f')
        ..createSync(recursive: true)
        ..writeAsStringSync('inhalt $f');
    }
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    await DocumentRepository(db).createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(title: 'Test', storageLocation: 'Box'),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 't',
    );
    final backup = BackupService(db,
        docsDir: () async => docs, tempDir: () async => temp);
    final file = await backup.createBackup('geheim123');

    await expectLater(backup.restoreToTemp(file, 'falsch'),
        throwsA(isA<BackupException>()));

    final restored = await backup.restoreToTemp(file, 'geheim123');
    expect(File('${restored.path}/manifest.json').existsSync(), isTrue);
    await BackupService(db, docsDir: () async => target, tempDir: () async => temp)
        .applyRestore(restored);
    expect(File('${target.path}/anhaenge/foto.jpg').readAsStringSync(),
        'inhalt anhaenge/foto.jpg');
    expect(File('${target.path}/vorlagen/sig.png').existsSync(), isTrue);
    expect(File('${target.path}/pdfs/2026-0001.pdf').existsSync(), isTrue);
    expect(File('${target.path}/dokubox_restore.sqlite').existsSync(), isTrue);
    await db.close();
    await root.delete(recursive: true);
  });
}
