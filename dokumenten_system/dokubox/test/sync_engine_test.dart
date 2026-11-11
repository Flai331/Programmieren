import 'dart:convert';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/sync/sync_engine.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase(DatabaseConnection(NativeDatabase.memory()));

/// Über JSON schicken wie im Netz.
SyncChanges _wire(SyncChanges c) =>
    SyncChanges.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);

Future<SyncImport> _sync(AppDatabase from, AppDatabase to, {int? since}) async {
  final changes = _wire(await SyncEngine(from).exportChanges(since: since));
  final r = await SyncEngine(to).importChanges(changes);
  for (final id in r.changedDocuments) {
    await DocumentRepository(to).rebuildFts(id);
  }
  return r;
}

void main() {
  late AppDatabase a, b;
  late DocumentRepository ra, rb;
  setUp(() {
    a = _db();
    b = _db();
    ra = DocumentRepository(a);
    rb = DocumentRepository(b);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('Handy → Laptop: Dokumente, Firmen, Tags, Refs, Aufgaben, Dateien',
      () async {
    final doc = await ra.createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(
          title: 'Beitragsrechnung',
          correspondentName: 'Allianz',
          tagNames: ['Auto'],
          storageLocation: 'Box 2026'),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 'kfz versicherung beitrag',
      refs: {
        'VSNR': {'AB123'}
      },
    );
    await ra.createTask(
        documentId: doc.id, action: 'bezahlen', dueAt: DateTime(2026, 12, 1));

    final r = await _sync(a, b);
    expect(r.neededFiles, {'pdfs/2026-0001.pdf'});
    final docs = await rb.watchDocuments(const DocumentFilter(query: 'beitrag')).first;
    expect(docs.single.id, doc.id);
    expect(await rb.tagNamesForDocument(doc.id), ['Auto']);
    expect((await rb.refsForDocument(doc.id))['VSNR'], {'AB123'});
    expect((await rb.watchTasksForDocument(doc.id).first).single.action, 'bezahlen');
    // Standard-Kategorien gibt es auf beiden Seiten → zusammengeführt.
    expect((await rb.allCategories()).length, (await ra.allCategories()).length);

    // Zweiter Durchlauf ohne Änderungen: nichts Neues.
    final again = await _sync(a, b);
    expect(again.inserted + again.updated, 0);
  });

  test('Letzte Änderung gewinnt, ältere wird ignoriert', () async {
    final doc = await ra.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'Alt', storageLocation: 'Box'),
        pdfPath: 'p.pdf',
        pageCount: 1,
        ocrText: '');
    await _sync(a, b);
    // B ändert später
    await Future<void>.delayed(const Duration(seconds: 1));
    await rb.updateDocument(doc.id, DocumentDraft(title: 'Neu von B', storageLocation: 'Box'));
    await _sync(b, a);
    expect((await ra.getDocument(doc.id))!.title, 'Neu von B');
    // A schickt seinen (älteren) Stand → B bleibt bei „Neu von B“
    await b.customStatement("UPDATE documents SET title = 'Neu von B' WHERE id = ?", [doc.id]);
    await a.customStatement(
        "UPDATE documents SET title = 'veraltet', updated_at = 1 WHERE id = ?", [doc.id]);
    await _sync(a, b);
    expect((await rb.getDocument(doc.id))!.title, 'Neu von B');
  });

  test('Gleichnamige Firma auf beiden Geräten wird zusammengeführt', () async {
    final da = await ra.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'A', correspondentName: 'enviaM', storageLocation: 'Box'),
        pdfPath: 'a.pdf', pageCount: 1, ocrText: '');
    // B kennt enviaM schon (Standard-Firma) mit anderer ID.
    final firmB = (await rb.allCorrespondents()).firstWhere((c) => c.name == 'enviaM');
    final firmA = (await ra.allCorrespondents()).firstWhere((c) => c.name == 'enviaM');
    expect(firmA.id, isNot(firmB.id));
    await _sync(a, b);
    final docB = (await rb.getDocument(da.id))!;
    expect(docB.correspondentId, firmB.id);
    expect((await rb.allCorrespondents()).where((c) => c.name == 'enviaM').length, 1);
  });

  test('Nummer umbenannt (Haupt-Handy vergibt) → Datei lokal umbenennen', () async {
    final doc = await rb.createDocument(
        docNumber: 'V-L0001',
        draft: DocumentDraft(title: 'Vom Laptop', storageLocation: 'Box'),
        pdfPath: 'pdfs/V-L0001.pdf', pageCount: 1, ocrText: '');
    await _sync(b, a);
    await Future<void>.delayed(const Duration(seconds: 1));
    await a.customStatement(
        "UPDATE documents SET doc_number = '2026-0007', pdf_path = 'pdfs/2026-0007.pdf', "
        'updated_at = ? WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch ~/ 1000 + 5, doc.id]);
    final r = await _sync(a, b);
    expect(r.renames, {'pdfs/V-L0001.pdf': 'pdfs/2026-0007.pdf'});
    expect(r.neededFiles, isEmpty);
    expect((await rb.getDocument(doc.id))!.docNumber, '2026-0007');
  });

  test('nur Änderungen seit dem letzten Abgleich', () async {
    await ra.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'x', storageLocation: 'Box'),
        pdfPath: 'x.pdf', pageCount: 1, ocrText: '');
    final since = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10;
    final c = await SyncEngine(a).exportChanges(since: since);
    expect(c.isEmpty, isTrue);
  });
}
