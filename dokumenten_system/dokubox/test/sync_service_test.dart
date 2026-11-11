import 'dart:io';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/sync/pairing.dart';
import 'package:dokubox/sync/sync_crypto.dart';
import 'package:dokubox/sync/sync_service.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verschlüsselung: richtig, falscher Schlüssel, Manipulation', () async {
    final secret = SyncCrypto.newSecret();
    final a = await SyncCrypto.fromSecret(secret);
    final b = await SyncCrypto.fromSecret(secret);
    final other = await SyncCrypto.fromSecret(SyncCrypto.newSecret());
    final sealed = await a.seal({'x': 1}, [1, 2, 3]);
    final opened = await b.open(sealed);
    expect(opened.json['x'], 1);
    expect(opened.data, [1, 2, 3]);
    expect(() => other.open(sealed), throwsA(isA<SyncAuthException>()));
    sealed[20] ^= 1;
    expect(() => b.open(sealed), throwsA(isA<SyncAuthException>()));
  });

  test('Pfade: nur erlaubte Ordner, kein ..', () {
    expect(safeLocalPath('/r', 'pdfs/a.pdf'), '/r/pdfs/a.pdf');
    expect(safeLocalPath('/r', '../etc/passwd'), isNull);
    expect(safeLocalPath('/r', 'pdfs/../../x'), isNull);
    expect(safeLocalPath('/r', 'dokubox.sqlite'), isNull);
    expect(PairingOffer.decode(const PairingOffer('192.168.1.2', 47900, 'id', 'Laptop', 'c2Vj').encode())!.name, 'Laptop');
  });

  test('Koppeln + Abgleich übers Netz (Handy ↔ Laptop) mit Dateien', () async {
    final root = await Directory.systemTemp.createTemp('dokubox_sync');
    final dirA = Directory('${root.path}/handy')..createSync();
    final dirB = Directory('${root.path}/laptop')..createSync();
    final dbA = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final dbB = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repoA = DocumentRepository(dbA), repoB = DocumentRepository(dbB);
    final handy = SyncService(dbA, repoA,
        docsDir: () async => dirA,
        allowLoopback: true,
        store: MemoryPairingStore('handy-id', 'Handy'));
    final laptop = SyncService(dbB, repoB,
        docsDir: () async => dirB,
        allowLoopback: true,
        store: MemoryPairingStore('laptop-id', 'Laptop'));

    File('${dirA.path}/pdfs/2026-0001.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('%PDF handy');
    final doc = await repoA.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'Bescheid', storageLocation: 'Box'),
        pdfPath: 'pdfs/2026-0001.pdf',
        pageCount: 1,
        ocrText: 'finanzamt bescheid');

    final offer = await laptop.startServer(host: '127.0.0.1', port: 0);
    final paired = await handy.pair(offer);
    expect(paired.name, 'Laptop');

    var report = await handy.syncWith(paired);
    expect(report.sent, greaterThan(0));
    expect(report.filesOut, 1);
    expect(File('${dirB.path}/pdfs/2026-0001.pdf').readAsStringSync(), '%PDF handy');
    expect((await repoB.watchDocuments(const DocumentFilter(query: 'finanzamt')).first)
        .single.id, doc.id);

    // Laptop legt einen Anhang an → Handy holt ihn beim nächsten Abgleich.
    File('${dirB.path}/anhaenge/foto.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('jpg');
    await repoB.addAttachment(
        documentId: doc.id, kind: 'foto', relPath: 'anhaenge/foto.jpg');
    report = await handy.syncWith((await handy.store.devices()).single);
    expect(report.received, greaterThan(0));
    expect(report.filesIn, 1);
    expect(File('${dirA.path}/anhaenge/foto.jpg').readAsStringSync(), 'jpg');
    expect((await repoA.watchAttachments(doc.id).first).length, 1);

    // Fremdes Gerät ohne Kopplung wird abgewiesen.
    final stranger = SyncService(dbA, repoA,
        docsDir: () async => dirA,
        allowLoopback: true,
        store: MemoryPairingStore('fremd', 'Fremd'));
    await expectLater(
        stranger.syncWith(PairedDevice(
            id: 'laptop-id', name: 'x', secret: offer.secret.replaceRange(0, 4, 'AAAA'),
            host: '127.0.0.1', port: offer.port)),
        throwsA(anything));

    await laptop.stopServer();
    await dbA.close();
    await dbB.close();
    await root.delete(recursive: true);
  });
}
