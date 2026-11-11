import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/attachments/attachment_service.dart';
import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Anhang: Foto verkleinern, Datei kopieren, entfernen', () async {
    final root = await Directory.systemTemp.createTemp('dokubox_att');
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    final svc = AttachmentService(repo, docsDir: () async => root);
    final doc = await repo.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'Schaden', storageLocation: 'Box'),
        pdfPath: 'p.pdf',
        pageCount: 1,
        ocrText: '');
    final big = img.Image(width: 4000, height: 3000);
    final photo = File('${root.path}/foto.png')
      ..writeAsBytesSync(img.encodePng(big));
    final note = File('${root.path}/notiz.txt')..writeAsStringSync('Hallo');

    final a = await svc.add(doc.id, photo.path);
    final b = await svc.add(doc.id, note.path);
    expect(a.kind, 'foto');
    expect(a.mime, 'image/jpeg');
    final stored = img.decodeJpg(
        Uint8List.fromList(File(await svc.absolutePath(a)).readAsBytesSync()))!;
    expect(stored.width, 2000);
    expect(b.kind, 'datei');
    expect(File(await svc.absolutePath(b)).readAsStringSync(), 'Hallo');
    expect(b.sha256, hasLength(64));
    expect((await repo.watchAttachments(doc.id).first).length, 2);
    await repo.deleteAttachment(a.id);
    expect((await repo.watchAttachments(doc.id).first).single.id, b.id);
    await db.close();
    await root.delete(recursive: true);
  });
}
