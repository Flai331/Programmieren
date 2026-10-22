import 'dart:io';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/finance.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Schema v1 → v2: Bestandsdaten bleiben, Rechnungsfelder kommen dazu',
      () async {
    final dir = await Directory.systemTemp.createTemp('dokubox_migration');
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() =>
        AppDatabase(DatabaseConnection(NativeDatabase(file)));

    // v2 anlegen, ein Dokument speichern, dann auf den v1-Stand zurückbauen.
    var db = open();
    await DocumentRepository(db).createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(title: 'Alt', storageLocation: 'Box 2026'),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 'altbestand',
    );
    await db.customStatement('DROP TABLE claims');
    for (final column in [
      'amount_cents',
      'due_date',
      'payment_status',
      'paid_at',
      'payment_reminder_at',
    ]) {
      await db.customStatement('ALTER TABLE documents DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = open();
    final repo = DocumentRepository(db);
    final docs = await repo.watchDocuments(const DocumentFilter()).first;
    expect(docs.single.title, 'Alt');
    expect(docs.single.paymentStatus, isNull);

    await repo.updateDocument(
      docs.single.id,
      DocumentDraft(
        title: 'Alt',
        storageLocation: 'Box 2026',
        paymentStatus: PaymentStatus.open,
        amountCents: 1999,
        claims: [ClaimDraft(target: 'Beihilfe')],
      ),
    );
    expect((await repo.watchOpenPayments().first).single.amountCents, 1999);
    expect((await repo.watchOpenClaims().first).single.claim.target,
        'Beihilfe');
    await db.close();
    await dir.delete(recursive: true);
  });
}
