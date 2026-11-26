import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:beebrain/services/personalization_service.dart';
import 'package:beebrain/utils/bucket_code.dart';

/// Die anpassbaren Verzeichnisse: Aussaat, Änderung, Rückfall.
///
/// Die Verzeichnisse liegen als statischer Zustand in den Modellklassen –
/// deshalb setzt jeder Test sie hinterher zurück, sonst trüge der nächste die
/// Einstellungen des vorigen mit sich.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final dienst = PersonalizationService();

  Future<Database> frischeDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 7),
    );
    await DatabaseService.createPersonalizationTables(db);
    dienst.databaseOverride = db;
    addTearDown(() async {
      dienst.databaseOverride = null;
      dienst.resetForTests();
      await db.close();
    });
    return db;
  }

  group('Aussaat', () {
    test('legt jedes Verzeichnis mit der Werkseinstellung an', () async {
      final db = await frischeDb();
      await dienst.load();

      for (final verzeichnis in Catalogs.all) {
        final vorgabe = CatalogDefaults.of(verzeichnis);
        final gesaet = dienst.entries(verzeichnis);
        expect(gesaet.length, vorgabe.length, reason: verzeichnis);
        for (var i = 0; i < vorgabe.length; i++) {
          expect(gesaet[i].key, vorgabe[i].key, reason: '$verzeichnis[$i]');
          expect(gesaet[i].label, vorgabe[i].label, reason: '$verzeichnis[$i]');
          expect(gesaet[i].builtIn, isTrue, reason: '$verzeichnis[$i]');
        }
      }
      expect(await db.query('catalog_entries'),
          hasLength(CatalogDefaults.all().length));
    });

    test('ein zweiter Start ändert nichts und verdoppelt nichts', () async {
      final db = await frischeDb();
      await dienst.load();
      final nachErstem = await db.query('catalog_entries');
      await dienst.load();

      expect((await db.query('catalog_entries')).toString(),
          nachErstem.toString());
    });

    test('rührt eine Änderung von mir nicht an', () async {
      await frischeDb();
      await dienst.load();
      final geimpft = dienst.entry(Catalogs.honeyState, HoneyStates.seeded)!;
      await dienst.save(geimpft.copyWith(label: 'angestellt, rühren!'));

      // Noch ein Start: die Aussaat darf nicht zurückschlagen.
      await dienst.load();

      expect(HoneyStates.labelOf(HoneyStates.seeded), 'angestellt, rühren!');
    });

    test('ergänzt einen Eintrag, der in der Tabelle fehlt', () async {
      // So kommen Einträge an, die eine neue Fassung der App mitbringt.
      final db = await frischeDb();
      await dienst.load();
      await db.delete('catalog_entries',
          where: 'catalog = ? AND entry_key = ?',
          whereArgs: [Catalogs.honeyState, HoneyStates.stirred]);

      await dienst.load();

      expect(dienst.entry(Catalogs.honeyState, HoneyStates.stirred), isNotNull);
    });
  });

  group('Was eine Änderung bewirkt', () {
    test('eine neue Beschriftung kommt in der App an', () async {
      await frischeDb();
      await dienst.load();
      final sorte = dienst.entry(Catalogs.honeyVariety, HoneyVarieties.rape)!;

      await dienst.save(sorte.copyWith(label: 'Rapshonig, cremig'));

      expect(HoneyVarieties.labelOf(HoneyVarieties.rape), 'Rapshonig, cremig');
      // Der Schlüssel bleibt – alte Eimer zeigen weiter aufs Richtige.
      expect(HoneyVarieties.all, contains('RA'));
    });

    test('ein zusätzlicher Schritt verlängert die Kette', () async {
      await frischeDb();
      await dienst.load();

      await dienst.save(CatalogEntry(
        catalog: Catalogs.honeyState,
        key: 'waermeschrank',
        label: 'im Wärmeschrank',
        // Zwischen „fertig gerührt" (2) und „abfüllfertig" (3).
        sortOrder: 2,
      ));
      await dienst.reorder(Catalogs.honeyState, [
        HoneyStates.extracted,
        HoneyStates.seeded,
        HoneyStates.stirred,
        'waermeschrank',
        HoneyStates.readyToBottle,
        HoneyStates.empty,
      ]);

      expect(HoneyStates.steps, [
        HoneyStates.extracted,
        HoneyStates.seeded,
        HoneyStates.stirred,
        'waermeschrank',
        HoneyStates.readyToBottle,
      ]);
      expect(HoneyStates.ticksOf('waermeschrank'), 4);
      expect(HoneyStates.ticksOf(HoneyStates.readyToBottle), 5);
      // Der neue Schritt nimmt die vorherigen mit.
      expect(HoneyStates.isDone('waermeschrank', HoneyStates.seeded), isTrue);
      expect(HoneyStates.isDone('waermeschrank', HoneyStates.readyToBottle),
          isFalse);
      // Und die Striche wachsen von selbst mit.
      expect(HoneyStates.strokeHint('waermeschrank'), '|||');
      expect(HoneyStates.strokeHint(HoneyStates.readyToBottle), '||||');
    });

    test('ein ausgeblendeter Eintrag verlässt die Auswahl, nicht die Daten',
        () async {
      await frischeDb();
      await dienst.load();
      final heide = dienst.entry(Catalogs.honeyVariety, HoneyVarieties.heather)!;

      await dienst.save(heide.copyWith(archived: true));

      expect(HoneyVarieties.all, isNot(contains(HoneyVarieties.heather)));
      // Ein alter Eimer mit dieser Sorte zeigt weiter seinen Namen.
      expect(HoneyVarieties.labelOf(HoneyVarieties.heather), 'Heide');
      expect(HoneyVarieties.isKnown(HoneyVarieties.heather), isTrue);
    });

    test('ein ausgeblendeter Zustand verbiegt alte Eimer nicht', () async {
      await frischeDb();
      await dienst.load();
      final geruehrt = dienst.entry(Catalogs.honeyState, HoneyStates.stirred)!;

      await dienst.save(geruehrt.copyWith(archived: true));

      expect(HoneyStates.steps, isNot(contains(HoneyStates.stirred)));
      // Der Eimer, der darauf steht, behält Beschriftung und Zustand.
      expect(HoneyStates.normalize(HoneyStates.stirred), HoneyStates.stirred);
      expect(HoneyStates.labelOf(HoneyStates.stirred), 'fertig gerührt');
    });

    test('ein Werkseintrag lässt sich nicht löschen', () async {
      await frischeDb();
      await dienst.load();

      expect(await dienst.remove(Catalogs.honeyState, HoneyStates.seeded),
          isFalse);
      expect(dienst.entry(Catalogs.honeyState, HoneyStates.seeded), isNotNull);
    });

    test('ein selbst angelegter Eintrag lässt sich löschen', () async {
      await frischeDb();
      await dienst.load();
      await dienst.save(const CatalogEntry(
        catalog: Catalogs.honeyVariety,
        key: 'LÖ',
        label: 'Löwenzahn',
        sortOrder: 99,
      ));
      expect(HoneyVarieties.all, contains('LÖ'));

      expect(await dienst.remove(Catalogs.honeyVariety, 'LÖ'), isTrue);
      expect(HoneyVarieties.all, isNot(contains('LÖ')));
    });

    test('Zurücksetzen holt die Werkseinstellung zurück', () async {
      await frischeDb();
      await dienst.load();
      final geimpft = dienst.entry(Catalogs.honeyState, HoneyStates.seeded)!;
      await dienst.save(geimpft.copyWith(label: 'irgendwas'));
      await dienst.save(const CatalogEntry(
        catalog: Catalogs.honeyState,
        key: 'erfunden',
        label: 'erfunden',
        sortOrder: 50,
      ));

      await dienst.resetToDefaults(Catalogs.honeyState);

      expect(HoneyStates.labelOf(HoneyStates.seeded),
          'geimpft – täglich rühren');
      expect(HoneyStates.steps, HoneyStates.defaultSteps);
    });
  });

  group('Wenn nichts zu laden ist', () {
    test('ohne Datenbank gilt die Werkseinstellung', () async {
      // Keine Tabellen, kein Schema – load() darf nicht durchschlagen.
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1));
      dienst.databaseOverride = db;
      addTearDown(() async {
        dienst.databaseOverride = null;
        dienst.resetForTests();
        await db.close();
      });

      await dienst.load();

      expect(dienst.isLoaded, isFalse);
      expect(HoneyStates.steps, HoneyStates.defaultSteps);
      expect(HoneyStates.labelOf(HoneyStates.seeded),
          'geimpft – täglich rühren');
    });

    test('eine leere Tabelle gilt wie die Werkseinstellung', () async {
      final db = await frischeDb();
      await db.delete('catalog_entries');

      expect(dienst.entries(Catalogs.honeyState).map((e) => e.key),
          CatalogDefaults.of(Catalogs.honeyState).map((e) => e.key));
      expect(HoneyStates.steps, HoneyStates.defaultSteps);
    });

    test('eine Kette ohne sichtbaren Schritt bleibt die Werkseinstellung',
        () async {
      // Alle Haken ausgeblendet wäre eine App, an der man nichts mehr
      // abhaken kann.
      await frischeDb();
      await dienst.load();
      for (final schritt in HoneyStates.defaultSteps) {
        final e = dienst.entry(Catalogs.honeyState, schritt)!;
        await dienst.save(e.copyWith(archived: true));
      }

      expect(HoneyStates.steps, HoneyStates.defaultSteps);
    });
  });

  group('Einstellbare Zahlen', () {
    test('ohne Eintrag gilt die Vorgabe', () async {
      await frischeDb();
      await dienst.load();

      expect(dienst.number(AppNumbers.warmerFirstHours, 48), 48);
    });

    test('ein gesetzter Wert kommt zurück, auch nach neuem Laden', () async {
      await frischeDb();
      await dienst.load();

      await dienst.setNumber(AppNumbers.warmerFirstHours, 36);
      expect(dienst.number(AppNumbers.warmerFirstHours, 48), 36);

      await dienst.load();
      expect(dienst.number(AppNumbers.warmerFirstHours, 48), 36);
    });

    test('ein unlesbarer Wert fällt auf die Vorgabe zurück', () async {
      final db = await frischeDb();
      await db.insert('app_settings',
          {'name': AppNumbers.warmerFirstHours, 'value': 'bald'});

      await dienst.load();

      expect(dienst.number(AppNumbers.warmerFirstHours, 48), 48);
    });
  });

  group('Buchungsgründe tragen eine Richtung', () {
    test('die Werkseinstellung behält ihre beiden Listen genau', () async {
      await frischeDb();
      await dienst.load();

      expect(StockReasons.inbound, [
        StockReasons.purchase,
        StockReasons.harvest,
        StockReasons.bottling,
        StockReasons.correction,
      ]);
      expect(StockReasons.outbound, [
        StockReasons.sale,
        StockReasons.consumption,
        StockReasons.ownUse,
        StockReasons.loss,
        StockReasons.bottling,
        StockReasons.correction,
      ]);
    });

    test('ein eigener Grund landet in der Liste seiner Richtung', () async {
      await frischeDb();
      await dienst.load();

      await dienst.save(const CatalogEntry(
        catalog: Catalogs.stockReason,
        key: 'messe',
        label: 'Messeverkauf',
        sortOrder: 99,
        direction: CatalogDirections.outbound,
      ));

      expect(StockReasons.outbound, contains('messe'));
      expect(StockReasons.inbound, isNot(contains('messe')));
      expect(StockReasons.directionOf('messe'), CatalogDirections.outbound);
    });
  });

  group('Anlegen und zählen', () {
    /// Eine Datenbank, die auch die Datentabellen kennt – nur damit lässt
    /// sich zählen, wer einen Eintrag benutzt.
    Future<Database> dbMitDaten() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 7),
      );
      await DatabaseService.createPersonalizationTables(db);
      await DatabaseService.createStockTables(db);
      dienst.databaseOverride = db;
      addTearDown(() async {
        dienst.databaseOverride = null;
        dienst.resetForTests();
        await db.close();
      });
      return db;
    }

    var zaehler = 0;
    Future<void> eimerMit(Database db, String sorte, String zustand) {
      final nr = ++zaehler;
      return db.insert('honey_buckets', {
          'id': 'b$nr',
          'code': '$sorte-${nr.toString().padLeft(3, '0')}',
          'number': nr,
          'variety': sorte,
          'harvest_date': DateTime(2026, 7, 1).toIso8601String(),
          'filled_kg': 25.0,
          'state': zustand,
          'created_at': DateTime(2026, 7, 1).toIso8601String(),
      });
    }

    test('aus der Beschriftung wird ein brauchbarer Schlüssel', () {
      expect(PersonalizationService.keyFromLabel('Messeverkauf'),
          'messeverkauf');
      expect(PersonalizationService.keyFromLabel('Für Bekannte'),
          'fuer_bekannte');
      expect(PersonalizationService.keyFromLabel('  Löwenzahn / Mai  '),
          'loewenzahn_mai');
      expect(PersonalizationService.keyFromLabel('Größe 500g'),
          'groesse_500g');
      // Nichts Verwertbares darf keinen leeren Schlüssel ergeben.
      expect(PersonalizationService.keyFromLabel('???'), 'eigener');
    });

    test('ein mitgegebener Schlüssel bleibt, wie er geschrieben ist', () {
      expect(PersonalizationService.keyAsGiven('LZ'), 'LZ');
      expect(PersonalizationService.keyAsGiven('  lz  '), 'lz');
      expect(PersonalizationService.keyAsGiven('L-Z!'), 'LZ');
      expect(PersonalizationService.keyAsGiven('!!'), 'eigener');
    });

    test('eine eigene Sorte ist sofort als Code gültig', () async {
      // Die Kamera und die Eingabe von Hand prüfen gegen das Verzeichnis –
      // eine neue Sorte muss dort ankommen, sonst wäre ihr Eimer nicht
      // auffindbar.
      await frischeDb();
      await dienst.load();
      expect(BucketCode.isWellFormed('LZ-001'), isFalse);

      await dienst.add(Catalogs.honeyVariety, key: 'LZ', label: 'Löwenzahn');

      expect(BucketCode.isWellFormed('LZ-001'), isTrue);
      expect(BucketCode.format('LZ', 1), 'LZ-001');
    });

    test('derselbe Schlüssel wird durchgezählt', () {
      expect(PersonalizationService.freeKey('raps', {}), 'raps');
      expect(PersonalizationService.freeKey('raps', {'raps'}), 'raps_2');
      expect(PersonalizationService.freeKey('raps', {'raps', 'raps_2'}),
          'raps_3');
    });

    test('ein neuer Eintrag hängt sich hinten an', () async {
      await frischeDb();
      await dienst.load();
      final vorher = dienst.entries(Catalogs.hiveActionType);

      final eintrag = await dienst
          .add(Catalogs.hiveActionType, label: 'Waben umhängen');

      expect(eintrag.key, 'waben_umhaengen');
      expect(eintrag.builtIn, isFalse);
      final nachher = dienst.entries(Catalogs.hiveActionType);
      expect(nachher.length, vorher.length + 1);
      expect(nachher.last.key, eintrag.key);
      // Und er ist in der App angekommen, nicht nur in der Tabelle.
      expect(HiveActionTypes.all, contains(eintrag.key));
      expect(HiveActionTypes.labelOf(eintrag.key), 'Waben umhängen');
    });

    test('eine eigene Sorte behält ihr Kürzel als Schlüssel', () async {
      await frischeDb();
      await dienst.load();

      final eintrag = await dienst.add(Catalogs.honeyVariety,
          key: 'LZ', label: 'Löwenzahn');

      // Das Kürzel steht auf dem Eimer – es darf weder aus der
      // Beschriftung gebildet noch kleingeschrieben werden, sonst stünde
      // auf dem nächsten Eimer `lz-001` neben `SO-042`.
      expect(eintrag.key, 'LZ');
      expect(HoneyVarieties.labelOf('LZ'), 'Löwenzahn');
      expect(HoneyVarieties.all, contains('LZ'));
    });

    test('gezählt wird, was in den Daten steht', () async {
      final db = await dbMitDaten();
      await dienst.load();
      await eimerMit(db, HoneyVarieties.summer, HoneyStates.extracted);
      await eimerMit(db, HoneyVarieties.summer, HoneyStates.seeded);
      await eimerMit(db, HoneyVarieties.rape, HoneyStates.seeded);

      final sorten = await dienst.usageCounts(Catalogs.honeyVariety);
      expect(sorten[HoneyVarieties.summer], 2);
      expect(sorten[HoneyVarieties.rape], 1);
      expect(sorten[HoneyVarieties.lime], isNull);

      final zustaende = await dienst.usageCounts(Catalogs.honeyState);
      expect(zustaende[HoneyStates.seeded], 2);
      expect(zustaende[HoneyStates.extracted], 1);
    });

    test('der Verlauf zählt mit', () async {
      final db = await dbMitDaten();
      await dienst.load();
      await db.insert('honey_bucket_events', {
        'id': 'e1',
        'bucket_id': 'b1',
        'date': DateTime(2026, 7, 2).toIso8601String(),
        'kind': HoneyEventKinds.state,
        'state': HoneyStates.stirred,
        'created_at': DateTime(2026, 7, 2).toIso8601String(),
      });

      final zustaende = await dienst.usageCounts(Catalogs.honeyState);
      expect(zustaende[HoneyStates.stirred], 1,
          reason: 'ein gelöschter Zustand machte alte Verlaufszeilen '
              'unlesbar');
    });

    test('ohne Datentabellen zählt nichts und stürzt nichts', () async {
      // Auf einer frischen Installation gibt es die Tabellen noch nicht.
      await frischeDb();
      await dienst.load();
      expect(await dienst.usageCounts(Catalogs.honeyState), isEmpty);
    });

    test('ein benutzter eigener Eintrag wird nicht gelöscht', () async {
      final db = await dbMitDaten();
      await dienst.load();
      final eintrag =
          await dienst.add(Catalogs.honeyVariety, key: 'LZ', label: 'Löwenzahn');
      await eimerMit(db, eintrag.key, HoneyStates.extracted);

      expect(await dienst.remove(Catalogs.honeyVariety, eintrag.key), isFalse,
          reason: 'sonst zeigte der Eimer nur noch den nackten Schlüssel');
      expect(dienst.entry(Catalogs.honeyVariety, eintrag.key), isNotNull);

      // Ausblenden geht dagegen immer.
      await dienst.save(eintrag.copyWith(archived: true));
      expect(dienst.entries(Catalogs.honeyVariety, withArchived: false)
          .map((e) => e.key), isNot(contains(eintrag.key)));
      expect(HoneyVarieties.labelOf(eintrag.key), 'Löwenzahn',
          reason: 'am alten Eimer bleibt die Beschriftung lesbar');
    });

    test('ein unbenutzter eigener Eintrag darf weg', () async {
      await dbMitDaten();
      await dienst.load();
      final eintrag =
          await dienst.add(Catalogs.honeyVariety, key: 'LZ', label: 'Löwenzahn');

      expect(await dienst.remove(Catalogs.honeyVariety, eintrag.key), isTrue);
      expect(dienst.entry(Catalogs.honeyVariety, eintrag.key), isNull);
    });
  });
}
