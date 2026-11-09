import 'dart:io';

import 'package:dokubox/ai/ai_extraction_service.dart';
import 'package:dokubox/data/categories.dart';
import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kategorien & Firmen', () {
    late AppDatabase db;
    late DocumentRepository repo;

    setUp(() {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      repo = DocumentRepository(db);
    });
    tearDown(() => db.close());

    Future<Document> doc(String number, String? firm, {String? categoryId}) =>
        repo.createDocument(
          docNumber: number,
          draft: DocumentDraft(
            title: 'Dok $number',
            correspondentName: firm,
            categoryId: categoryId,
            storageLocation: 'Box 2026',
          ),
          pdfPath: 'pdfs/$number.pdf',
          pageCount: 1,
          ocrText: 'text',
        );

    Future<String> catId(String name) async =>
        (await repo.allCategories()).firstWhere((c) => c.name == name).id;

    test('Standard-Kategorien und Beispiel-Firmen sind angelegt', () async {
      final names = (await repo.allCategories()).map((c) => c.name).toSet();
      expect(names, containsAll(kDefaultCategories));
      final union = (await repo.allCorrespondents())
          .firstWhere((c) => c.name == 'Union Investment');
      expect(union.categoryId, await catId('Bank & Geldanlage'));
      expect(union.aliases, contains('UnionDepot'));
      expect(
        await repo.categoryIdForCorrespondentName('enviam'),
        await catId('Energie & Wohnen'),
      );
    });

    test('Filter nach Kategorie zeigt nur Dokumente dieser Firmen', () async {
      await doc('2026-0001', 'Union Investment');
      await doc('2026-0002', 'enviaM');
      await doc('2026-0003', 'HUK-COBURG',
          categoryId: await catId('Versicherung'));
      await doc('2026-0004', null);

      Future<List<String>> numbers(String category) async => (await repo
              .watchDocuments(DocumentFilter(categoryId: await catId(category)))
              .first)
          .map((d) => d.docNumber)
          .toList();

      expect(await numbers('Bank & Geldanlage'), ['2026-0001']);
      expect(await numbers('Energie & Wohnen'), ['2026-0002']);
      expect(await numbers('Versicherung'), ['2026-0003']);
      expect(await numbers('Gesundheit'), isEmpty);
    });

    test('Kategorie beim Speichern umhängen gilt für alle Dokumente', () async {
      await doc('2026-0001', 'Stadtwerke Leipzig');
      expect(
          await repo.categoryIdForCorrespondentName('Stadtwerke Leipzig'),
          isNull);
      // Zweites Dokument mit Kategorie → Firma wird eingeordnet, auch das
      // erste Dokument erscheint im Filter.
      await doc('2026-0002', 'Stadtwerke Leipzig',
          categoryId: await catId('Energie & Wohnen'));
      final docs = await repo
          .watchDocuments(
              DocumentFilter(categoryId: await catId('Energie & Wohnen')))
          .first;
      expect(docs.map((d) => d.docNumber),
          containsAll(['2026-0001', '2026-0002']));
      // Ohne Angabe bleibt die Kategorie der Firma bestehen.
      await doc('2026-0003', 'Stadtwerke Leipzig');
      expect(await repo.categoryIdForCorrespondentName('Stadtwerke Leipzig'),
          await catId('Energie & Wohnen'));
    });

    test('Firma anlegen, bearbeiten, entfernen', () async {
      await repo.saveCorrespondent(
        name: 'DKB',
        aliases: 'Deutsche Kreditbank\n\nDKB AG',
        categoryId: await catId('Bank & Geldanlage'),
      );
      var dkb = (await repo.allCorrespondents())
          .firstWhere((c) => c.name == 'DKB');
      expect(dkb.aliases.split('\n'), ['DKB', 'Deutsche Kreditbank', 'DKB AG']);

      await repo.saveCorrespondent(
          id: dkb.id, name: 'DKB', aliases: '', categoryId: null);
      dkb = (await repo.allCorrespondents()).firstWhere((c) => c.id == dkb.id);
      expect(dkb.categoryId, isNull);

      await repo.deleteCorrespondent(dkb.id);
      expect((await repo.allCorrespondents()).any((c) => c.name == 'DKB'),
          isFalse);
      // Neues Dokument dieser Firma belebt sie wieder.
      await doc('2026-0001', 'DKB');
      expect((await repo.allCorrespondents()).any((c) => c.name == 'DKB'),
          isTrue);
    });

    test('Kategorie anlegen, umbenennen, löschen', () async {
      final hobby = await repo.createCategory('  Hobby & Verein ');
      expect(hobby.name, 'Hobby & Verein');
      expect((await repo.createCategory('hobby & verein')).id, hobby.id);
      await repo.renameCategory(hobby.id, 'Verein');
      await doc('2026-0001', 'Sportverein', categoryId: hobby.id);

      await repo.deleteCategory(hobby.id);
      expect((await repo.allCategories()).any((c) => c.id == hobby.id),
          isFalse);
      expect(await repo.categoryIdForCorrespondentName('Sportverein'), isNull);
      // Die Dokumente bleiben.
      expect(
          (await repo.watchDocuments(const DocumentFilter()).first).length, 1);
    });
  });

  test('Schema v2 → v3: Firmen bleiben, Kategorien kommen dazu', () async {
    final dir = await Directory.systemTemp.createTemp('dokubox_v3');
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() => AppDatabase(DatabaseConnection(NativeDatabase(file)));

    var db = open();
    await DocumentRepository(db).createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(
        title: 'Depotauszug',
        correspondentName: 'Union Investment',
        storageLocation: 'Box 2026',
      ),
      pdfPath: 'pdfs/2026-0001.pdf',
      pageCount: 1,
      ocrText: 'depot',
    );
    // Auf den v2-Stand zurückbauen: ohne Kategorien, Firma ohne Spalte.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('UPDATE correspondents SET category_id = NULL');
    await db.customStatement('ALTER TABLE correspondents DROP COLUMN category_id');
    await db.customStatement('DROP TABLE categories');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    db = open();
    final repo = DocumentRepository(db);
    final docs = await repo.watchDocuments(const DocumentFilter()).first;
    expect(docs.single.title, 'Depotauszug');
    final bank = (await repo.allCategories())
        .firstWhere((c) => c.name == 'Bank & Geldanlage');
    // Bestehende Firma gleichen Namens wurde eingeordnet.
    expect(await repo.categoryIdForCorrespondentName('Union Investment'),
        bank.id);
    expect(
        (await repo.watchDocuments(DocumentFilter(categoryId: bank.id)).first)
            .single
            .docNumber,
        '2026-0001');
    await db.close();
    await dir.delete(recursive: true);
  });

  group('KI-Kategorie', () {
    const cats = ['Bank & Geldanlage', 'Energie & Wohnen'];

    test('nur Kategorien aus der eigenen Liste werden übernommen', () {
      expect(
        parseAiJson('{"absender": "enviaM", "kategorie": "energie & wohnen"}',
                categories: cats)!
            .kategorie,
        'Energie & Wohnen',
      );
      expect(
        parseAiJson('{"absender": "enviaM", "kategorie": "Strom"}',
                categories: cats)!
            .kategorie,
        isNull,
      );
      expect(
        parseAiJson('{"kategorie": "Bank & Geldanlage"}')?.kategorie,
        isNull,
      );
    });

    test('Prompt nennt die Kategorien nur, wenn es welche gibt', () {
      final withCats =
          AiExtractionService.buildPrompt('Text', categories: cats);
      expect(withCats, contains('"kategorie"'));
      expect(withCats, contains('Bank & Geldanlage, Energie & Wohnen'));
      expect(AiExtractionService.buildPrompt('Text'),
          isNot(contains('kategorie')));
    });
  });
}
