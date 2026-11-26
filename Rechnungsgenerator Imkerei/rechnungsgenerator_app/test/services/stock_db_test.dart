import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/database_service.dart';

/// Schema der Datenbank-Version 4 – so, wie es auf den Installationen
/// liegt, die das Lager noch nicht kennen. Nur die Tabellen, die der
/// Migrationsschritt berühren könnte.
const _v4Hives = '''
  CREATE TABLE hives (
    id TEXT PRIMARY KEY,
    number INTEGER,
    name TEXT,
    qr_id TEXT UNIQUE,
    queen_year INTEGER,
    queen_origin TEXT,
    location TEXT,
    position TEXT,
    status TEXT DEFAULT 'aktiv',
    notes TEXT,
    created_at TEXT,
    updated_at TEXT
  )
''';

const _v4Invoices = '''
  CREATE TABLE invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT,
    customer_id TEXT,
    date TEXT,
    status TEXT,
    created_at TEXT,
    updated_at TEXT
  )
''';

/// Die Eimer-Tabelle in Version 5: ohne die Spalte `crystallization`, mit den
/// neun alten Zustandswerten. Eine eingefrorene Kopie, denn
/// [DatabaseService.honeyBucketsTableSql] beschreibt inzwischen v6 – nur so
/// prüft der Test den Schritt und nicht sich selbst.
const _v5HoneyBuckets = '''
  CREATE TABLE honey_buckets (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    number INTEGER NOT NULL,
    variety TEXT NOT NULL,
    variety_name TEXT,
    harvest_date TEXT NOT NULL,
    bucket_size_kg REAL,
    filled_kg REAL NOT NULL,
    water_content REAL,
    state TEXT NOT NULL,
    location TEXT,
    label_photo TEXT,
    note TEXT,
    created_at TEXT,
    updated_at TEXT
  )
''';

/// Die neun Zustände, die ein Eimer vor v6 tragen konnte, und was aus jedem
/// werden muss. Geschichte, nicht ableitbar – deshalb hier von Hand.
const _v5Zustaende = <String, (String, String?)>{
  'frisch': (HoneyStates.extracted, null),
  'zu_impfen': (HoneyStates.extracted, null),
  'geimpft': (HoneyStates.seeded, null),
  'zu_ruehren': (HoneyStates.seeded, null),
  'geruehrt': (HoneyStates.stirred, null),
  'abfuellfertig': (HoneyStates.readyToBottle, null),
  'leer': (HoneyStates.empty, null),
  'grob': (HoneyStates.extracted, HoneyCrystallization.coarse),
  'fest': (HoneyStates.extracted, HoneyCrystallization.solid),
};

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openV4() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 4),
    );
    await db.execute(_v4Hives);
    await db.execute(_v4Invoices);
    await db.execute(DatabaseService.hiveActionsTableSql);
    await db.execute(DatabaseService.hiveActionsIndexSql);
    return db;
  }

  Future<List<String>> tables(Database db) async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    return rows.map((r) => r['name'] as String).toList();
  }

  group('Migration v4 → v5', () {
    test('legt die vier Lager-Tabellen an', () async {
      final db = await openV4();
      addTearDown(db.close);

      expect(await tables(db), isNot(contains('stock_items')));

      await DatabaseService.createStockTables(db);

      expect(
          await tables(db),
          containsAll([
            'stock_items',
            'stock_movements',
            'honey_buckets',
            'honey_bucket_events',
          ]));
    });

    test('legt die Indizes an', () async {
      final db = await openV4();
      addTearDown(db.close);

      await DatabaseService.createStockTables(db);

      final indizes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index'");
      final namen = indizes.map((r) => r['name'] as String);
      expect(namen, contains('idx_stock_movements_item'));
      expect(namen, contains('idx_honey_events_bucket'));
    });

    test('bestehende Völker, Maßnahmen und Rechnungen bleiben erhalten',
        () async {
      final db = await openV4();
      addTearDown(db.close);

      await db.insert('hives', {
        'id': 'h1',
        'number': 1,
        'name': 'Altvolk',
        'qr_id': 'hive-abc',
        'status': 'aktiv',
        'created_at': DateTime(2026, 3, 1).toIso8601String(),
      });
      await db.insert('hive_actions', {
        'id': 'a1',
        'hive_id': 'h1',
        'date': DateTime(2026, 5, 12).toIso8601String(),
        'type': HiveActionTypes.inspection,
        'note': 'vor der Migration',
        'created_at': DateTime(2026, 5, 12).toIso8601String(),
      });
      await db.insert('invoices', {
        'id': 'r1',
        'invoice_number': '2026-001',
        'customer_id': 'k1',
        'date': DateTime(2026, 6, 1).toIso8601String(),
        'status': 'bezahlt',
        'created_at': DateTime(2026, 6, 1).toIso8601String(),
      });

      await DatabaseService.createStockTables(db);

      expect(await db.query('hives'), hasLength(1));
      expect(HiveModel.fromMap((await db.query('hives')).first).name,
          'Altvolk');
      final massnahmen = await db.query('hive_actions');
      expect(massnahmen, hasLength(1));
      expect(HiveActionModel.fromMap(massnahmen.first).note,
          'vor der Migration');
      expect(await db.query('invoices'), hasLength(1));
    });

    test('ist mehrfach ausführbar', () async {
      // Ein abgebrochenes Update darf beim zweiten Versuch nicht scheitern.
      final db = await openV4();
      addTearDown(db.close);

      for (var i = 0; i < 3; i++) {
        await DatabaseService.createStockTables(db);
      }

      final alle = await tables(db);
      expect(alle.where((t) => t == 'stock_items'), hasLength(1));
      expect(alle.where((t) => t == 'honey_buckets'), hasLength(1));
    });

    test('erhält schon gebuchte Bewegungen bei nochmaligem Lauf', () async {
      final db = await openV4();
      addTearDown(db.close);

      await DatabaseService.createStockTables(db);
      await db.insert('stock_items', _glas().toMap());
      await db.insert('stock_movements', _bewegung(quantity: 200).toMap());

      // Noch einmal – etwa weil die Version nicht fortgeschrieben wurde.
      await DatabaseService.createStockTables(db);

      expect(await db.query('stock_movements'), hasLength(1));
      expect(await db.query('stock_items'), hasLength(1));
    });
  });

  group('Die Lager-Tabellen halten, was die Modelle schreiben', () {
    Future<Database> openV5() async {
      final db = await openV4();
      await DatabaseService.createStockTables(db);
      return db;
    }

    test('Posten gehen unverändert hinein und heraus', () async {
      final db = await openV5();
      addTearDown(db.close);

      final glas = _glas();
      await db.insert('stock_items', glas.toMap());

      final gelesen =
          StockItemModel.fromMap((await db.query('stock_items')).single);
      expect(gelesen.name, glas.name);
      expect(gelesen.minQuantity, 50);
      expect(gelesen.jarSizeG, 500);
      expect(gelesen.variety, HoneyVarieties.summer);
      expect(gelesen.isFilledJar, isTrue);
      expect(gelesen.isEmptyJar, isFalse);
      expect(gelesen.jarSizeKg, 0.5);
    });

    test('ein Eimer geht unverändert hinein und heraus', () async {
      final db = await openV5();
      addTearDown(db.close);

      final eimer = _eimer();
      await db.insert('honey_buckets', eimer.toMap());

      final gelesen =
          HoneyBucketModel.fromMap((await db.query('honey_buckets')).single);
      expect(gelesen.code, 'SO-042');
      expect(gelesen.number, 42);
      expect(gelesen.filledKg, 25);
      expect(gelesen.waterContent, 17.2);
      expect(gelesen.state, HoneyStates.extracted);
    });

    test('derselbe Code kann nicht zweimal vergeben werden', () async {
      final db = await openV5();
      addTearDown(db.close);

      await db.insert('honey_buckets', _eimer().toMap());
      // Der Code steht mit Permanentmarker auf dem Eimer – zwei Eimer mit
      // demselben Code wären nicht mehr unterscheidbar.
      await expectLater(
        db.insert('honey_buckets', _eimer(id: 'b2').toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('Abgeleitete Zahlen kommen aus der Datenbank', () {
    Future<Database> openV5() async {
      final db = await openV4();
      await DatabaseService.createStockTables(db);
      return db;
    }

    test('Bestand ist die Summe der Bewegungen', () async {
      final db = await openV5();
      addTearDown(db.close);

      await db.insert('stock_items', _glas().toMap());
      await db.insert('stock_movements',
          _bewegung(id: 'm1', quantity: 200).toMap());
      await db.insert(
          'stock_movements',
          _bewegung(id: 'm2', quantity: -80, reason: StockReasons.sale)
              .toMap());
      await db.insert(
          'stock_movements',
          _bewegung(id: 'm3', quantity: -5, reason: StockReasons.ownUse)
              .toMap());

      final rows = await db.rawQuery(DatabaseService.stockBalancesSql);
      final bestand = {
        for (final r in rows)
          r['item_id'] as String: (r['bestand'] as num).toDouble(),
      };

      expect(bestand['glas-500'], 115);
    });

    test('ein Posten ohne Bewegung fehlt in der Abfrage', () async {
      final db = await openV5();
      addTearDown(db.close);

      await db.insert('stock_items', _glas().toMap());

      final rows = await db.rawQuery(DatabaseService.stockBalancesSql);
      expect(rows, isEmpty);
    });

    test('Inhalt eines Eimers nach zwei Abfüllungen', () async {
      final db = await openV5();
      addTearDown(db.close);

      await db.insert('honey_buckets', _eimer().toMap());
      // Zwei Abfüllungen: 5 kg und 7,5 kg von 25 kg Einwaage.
      await db.insert(
          'honey_bucket_events', _abfuellung(id: 'e1', kg: 5).toMap());
      await db.insert(
          'honey_bucket_events', _abfuellung(id: 'e2', kg: 7.5).toMap());
      // Ein Zustandswechsel darf die Rechnung nicht beeinflussen.
      await db.insert(
          'honey_bucket_events',
          HoneyBucketEventModel(
            id: 'e3',
            bucketId: 'b1',
            date: DateTime(2026, 8, 2),
            kind: HoneyEventKinds.state,
            state: HoneyStates.readyToBottle,
            createdAt: DateTime(2026, 8, 2),
          ).toMap());

      final rows = await db.rawQuery(
          DatabaseService.bottledKgSql, [HoneyEventKinds.bottling]);
      final abgefuellt = {
        for (final r in rows)
          r['bucket_id'] as String: (r['entnommen'] as num).toDouble(),
      };

      expect(abgefuellt['b1'], 12.5);
      // Was übrig ist, wird daraus abgeleitet – nicht gespeichert.
      final eimer =
          HoneyBucketModel.fromMap((await db.query('honey_buckets')).single);
      expect(eimer.filledKg - abgefuellt['b1']!, 12.5);
    });

    test('ein Eimer ohne Abfüllung fehlt in der Abfrage', () async {
      final db = await openV5();
      addTearDown(db.close);

      await db.insert('honey_buckets', _eimer().toMap());

      final rows = await db.rawQuery(
          DatabaseService.bottledKgSql, [HoneyEventKinds.bottling]);
      expect(rows, isEmpty);
    });

    test('der Verlauf verschwindet mit seinem Eimer', () async {
      final db = await openV5();
      addTearDown(db.close);
      await db.execute('PRAGMA foreign_keys = ON');

      await db.insert('honey_buckets', _eimer().toMap());
      await db.insert(
          'honey_bucket_events', _abfuellung(id: 'e1', kg: 5).toMap());

      await db.delete('honey_buckets', where: 'id = ?', whereArgs: ['b1']);

      expect(await db.query('honey_bucket_events'), isEmpty);
    });
  });

  group('Migration v5 → v6: Zustände werden Haken', () {
    Future<Database> openV5() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 5),
      );
      await db.execute(_v5HoneyBuckets);
      await db.execute(DatabaseService.honeyEventsTableSql);
      // Je ein Eimer in jedem der neun alten Zustände.
      var nr = 0;
      for (final alt in _v5Zustaende.keys) {
        nr++;
        await db.insert('honey_buckets', {
          'id': 'b$nr',
          'code': 'SO-${nr.toString().padLeft(3, '0')}',
          'number': nr,
          'variety': HoneyVarieties.summer,
          'harvest_date': DateTime(2026, 7, 14).toIso8601String(),
          'filled_kg': 25.0,
          'state': alt,
          'created_at': DateTime(2026, 7, 14).toIso8601String(),
        });
      }
      return db;
    }

    Future<Map<String, HoneyBucketModel>> eimerNachAltzustand(
        Database db) async {
      final reihen = await db.query('honey_buckets', orderBy: 'number');
      final nachNummer = {
        for (final r in reihen)
          (r['number'] as int): HoneyBucketModel.fromMap(r)
      };
      var nr = 0;
      return {
        for (final alt in _v5Zustaende.keys) alt: nachNummer[++nr]!,
      };
    }

    test('jeder der neun alten Werte landet auf dem richtigen Haken',
        () async {
      final db = await openV5();
      addTearDown(db.close);

      await DatabaseService.migrateHoneyStatesToTicks(db);

      final eimer = await eimerNachAltzustand(db);
      _v5Zustaende.forEach((alt, erwartet) {
        final (zustand, markierung) = erwartet;
        expect(eimer[alt]!.state, zustand,
            reason: '\'$alt\' muss zu \'$zustand\' werden');
        expect(eimer[alt]!.crystallization, markierung,
            reason: 'Markierung von \'$alt\'');
      });
    });

    test('kein alter Wert bleibt in der Tabelle stehen', () async {
      final db = await openV5();
      addTearDown(db.close);

      await DatabaseService.migrateHoneyStatesToTicks(db);

      final reihen = await db.query('honey_buckets', columns: ['state']);
      for (final r in reihen) {
        expect(HoneyStates.all, contains(r['state'] as String));
      }
    });

    test('der Honig gilt nie als weiter, als er ist', () async {
      // Der böse Fehler wäre ein stilles Umkippen nach vorn: ein Eimer, der
      // nur geschleudert war, dürfte nach der Migration nicht als gerührt
      // gelten. Also: nie mehr Haken als vorher.
      final db = await openV5();
      addTearDown(db.close);

      await DatabaseService.migrateHoneyStatesToTicks(db);

      final eimer = await eimerNachAltzustand(db);
      _v5Zustaende.forEach((alt, _) {
        final vorher = HoneyStates.ticksOf(HoneyStates.normalize(alt));
        expect(HoneyStates.ticksOf(eimer[alt]!.state),
            lessThanOrEqualTo(vorher),
            reason: '\'$alt\' hat Haken dazugewonnen');
      });
    });

    test('ein zweiter Durchlauf ändert nichts mehr', () async {
      // ALTER TABLE kennt kein IF NOT EXISTS; liefe der Schritt doch zweimal,
      // bräche er sonst ab.
      final db = await openV5();
      addTearDown(db.close);

      await DatabaseService.migrateHoneyStatesToTicks(db);
      final ersterLauf = await db.query('honey_buckets', orderBy: 'number');
      await DatabaseService.migrateHoneyStatesToTicks(db);
      final zweiterLauf = await db.query('honey_buckets', orderBy: 'number');

      expect(zweiterLauf.toString(), ersterLauf.toString());
    });

    test('die Spalte fehlt vorher und ist hinterher da', () async {
      final db = await openV5();
      addTearDown(db.close);

      Future<bool> hatSpalte() async {
        final s = await db.rawQuery('PRAGMA table_info(honey_buckets)');
        return s.any((r) => r['name'] == 'crystallization');
      }

      expect(await hatSpalte(), isFalse);
      await DatabaseService.migrateHoneyStatesToTicks(db);
      expect(await hatSpalte(), isTrue);
    });

    test('der Verlauf bleibt unangetastet', () async {
      // Dort steht, was damals geschah. Beim Anzeigen bringt normalize() die
      // alten Werte auf die heutigen Beschriftungen.
      final db = await openV5();
      addTearDown(db.close);
      await db.insert('honey_bucket_events', {
        'id': 'e1',
        'bucket_id': 'b1',
        'date': DateTime(2026, 7, 20).toIso8601String(),
        'kind': HoneyEventKinds.state,
        'state': 'zu_ruehren',
        'created_at': DateTime(2026, 7, 20).toIso8601String(),
      });

      await DatabaseService.migrateHoneyStatesToTicks(db);

      final reihen = await db.query('honey_bucket_events');
      expect(reihen.single['state'], 'zu_ruehren');
      expect(HoneyStates.labelOf('zu_ruehren'), 'geimpft – täglich rühren');
    });
  });

}

StockItemModel _glas() => StockItemModel(
      id: 'glas-500',
      name: '500-g-Gläser Sommerblüte',
      // Abgefüllter Honig ist Ware, nicht Verpackung – deshalb Warengruppe
      // Honig. Leergut läge in der Gruppe Gläser, ohne Sorte.
      category: StockCategories.honey,
      unit: 'Stk',
      minQuantity: 50,
      pricePerUnit: 0.45,
      variety: HoneyVarieties.summer,
      jarSizeG: 500,
      createdAt: DateTime(2026, 3, 1),
    );

StockMovementModel _bewegung({
  String id = 'm1',
  required double quantity,
  String reason = StockReasons.purchase,
}) =>
    StockMovementModel(
      id: id,
      itemId: 'glas-500',
      date: DateTime(2026, 4, 1),
      quantity: quantity,
      reason: reason,
      createdAt: DateTime(2026, 4, 1),
    );

HoneyBucketModel _eimer({String id = 'b1'}) => HoneyBucketModel(
      id: id,
      code: 'SO-042',
      number: 42,
      variety: HoneyVarieties.summer,
      harvestDate: DateTime(2026, 7, 14),
      bucketSizeKg: 25,
      filledKg: 25,
      waterContent: 17.2,
      state: HoneyStates.extracted,
      createdAt: DateTime(2026, 7, 14, 18),
    );

HoneyBucketEventModel _abfuellung({required String id, required double kg}) =>
    HoneyBucketEventModel(
      id: id,
      bucketId: 'b1',
      date: DateTime(2026, 8, 1),
      kind: HoneyEventKinds.bottling,
      removedKg: kg,
      jarItemId: 'glas-500',
      jarCount: (kg * 2).round(),
      createdAt: DateTime(2026, 8, 1),
    );
