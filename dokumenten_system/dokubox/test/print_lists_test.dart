import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/reports/print_lists.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Box-Liste und Vernichtungs-Protokoll', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    for (var i = 1; i <= 3; i++) {
      await repo.createDocument(
        docNumber: '2026-000$i',
        draft: DocumentDraft(
            title: 'Dok $i', correspondentName: 'Müller GmbH',
            storageLocation: i == 3 ? 'Box 2025' : 'Box 2026'),
        pdfPath: '$i.pdf',
        pageCount: 1,
        ocrText: '',
      );
    }
    expect(await repo.storageLocations(), ['Box 2025', 'Box 2026']);
    final box = await repo.documentsAt('Box 2026');
    expect(box.map((r) => r.doc.docNumber), ['2026-0001', '2026-0002']);
    expect(box.first.sender, 'Müller GmbH');

    final at = DateTime(2026, 11, 11, 12);
    await repo.markDestroyed(box.first.doc.id, at: at);
    await repo.markDestroyed(box.first.doc.id, at: DateTime(2027)); // bleibt
    final destroyed = await repo.destroyedBetween(
        DateTime(2026, 11, 11), DateTime(2026, 11, 12));
    expect(destroyed.single.doc.destroyedFrom, 'Box 2026');
    expect(destroyed.single.doc.destroyedAt, at);
    expect(await repo.storageLocations(), ['Box 2025', 'Box 2026']);

    final font = ByteData.sublistView(
        File('assets/fonts/DejaVuSans.ttf').readAsBytesSync());
    for (final bytes in [
      await buildBoxListPdf('Box 2026', box, font: font),
      await buildDestructionLogPdf(destroyed, font: font, period: 'Nov 2026'),
    ]) {
      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF'), isTrue);
    }
    await db.close();
  });
}
