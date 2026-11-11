import 'dart:io';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/finance.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/downgrade.dart';

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
    // Auch die v3-Teile (Kategorien) entfernen, damit es echter v1-Stand ist.
    await downgradeTo(db, 1);
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

  test('Schema v5 → v6: Bestand bleibt, neue Tabellen nutzbar', () async {
    final dir = await Directory.systemTemp.createTemp('dokubox_v6');
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() =>
        AppDatabase(DatabaseConnection(NativeDatabase(file)));
    var db = open();
    final repo0 = DocumentRepository(db);
    final doc = await repo0.createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(
          title: 'Bescheid', correspondentName: 'Finanzamt',
          storageLocation: 'Box 2026'),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 'bescheid',
    );
    await repo0.createTask(
        documentId: doc.id, action: 'pruefen', dueAt: DateTime(2026, 12, 1));
    await downgradeTo(db, 5);
    await db.close();

    db = open();
    final repo = DocumentRepository(db);
    final docs = await repo.watchDocuments(const DocumentFilter()).first;
    expect(docs.single.title, 'Bescheid');
    expect(docs.single.contentHash, isNull);
    expect((await repo.watchTasksForDocument(doc.id).first).single.origin,
        isNull);
    await db.into(db.cases).insert(CasesCompanion.insert(title: 'Steuer 2025'));
    await db.into(db.personalData).insert(PersonalDataCompanion.insert(
        person: 'Ich', key: 'vorname', label: 'Vorname'));
    expect((await db.select(db.cases).get()).single.status, 'offen');
    await db.close();
    await dir.delete(recursive: true);
  });
}
