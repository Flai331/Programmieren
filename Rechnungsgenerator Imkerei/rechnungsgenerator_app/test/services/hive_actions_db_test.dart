import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/database_service.dart';

/// Schema der Datenbank-Version 1 – so, wie es auf bestehenden
/// Installationen liegt. Die Migration muss diese Daten erhalten.
const _v1Hives = '''
  CREATE TABLE hives (
    id TEXT PRIMARY KEY,
    number INTEGER,
    name TEXT,
    qr_id TEXT UNIQUE,
    queen_year INTEGER,
    queen_origin TEXT,
    location TEXT,
    status TEXT DEFAULT 'aktiv',
    notes TEXT,
    created_at TEXT,
    updated_at TEXT
  )
''';

HiveActionModel _action({
  String id = 'a1',
  String hiveId = 'h1',
  DateTime? date,
  String type = HiveActionTypes.inspection,
  String? note,
  int? broodFrames,
  int? beeFrames,
  int? temper,
  bool? queenSeen,
  bool? swarmCells,
  double? amount,
  String? unit,
  String? treatment,
  List<String> photoPaths = const [],
}) =>
    HiveActionModel(
      id: id,
      hiveId: hiveId,
      date: date ?? DateTime(2026, 5, 12),
      type: type,
      note: note,
      broodFrames: broodFrames,
      beeFrames: beeFrames,
      temper: temper,
      queenSeen: queenSeen,
      swarmCells: swarmCells,
      amount: amount,
      unit: unit,
      treatment: treatment,
      photoPaths: photoPaths,
      createdAt: DateTime(2026, 5, 12, 9, 30),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openV1() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.execute(_v1Hives);
    return db;
  }

  group('Migration v1 → v2', () {
    test('legt die Maßnahmen-Tabelle an', () async {
      final db = await openV1();
      addTearDown(db.close);

      await db.execute(DatabaseService.hiveActionsTableSql);
      await db.execute(DatabaseService.hiveActionsIndexSql);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['hive_actions'],
      );
      expect(tables, hasLength(1));
    });

    test('bestehende Völker bleiben erhalten', () async {
      final db = await openV1();
      addTearDown(db.close);

      await db.insert('hives', {
        'id': 'h1',
        'number': 1,
        'name': 'Altvolk',
        'qr_id': 'hive-abc',
        'status': 'aktiv',
        'created_at': DateTime(2026, 3, 1).toIso8601String(),
      });

      await db.execute(DatabaseService.hiveActionsTableSql);
      await db.execute(DatabaseService.hiveActionsIndexSql);

      final hives = await db.query('hives');
      expect(hives, hasLength(1));
      expect(HiveModel.fromMap(hives.first).name, 'Altvolk');
    });

    test('ist mehrfach ausführbar', () async {
      final db = await openV1();
      addTearDown(db.close);

      for (var i = 0; i < 2; i++) {
        await db.execute(DatabaseService.hiveActionsTableSql);
        await db.execute(DatabaseService.hiveActionsIndexSql);
      }

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['hive_actions'],
      );
      expect(tables, hasLength(1));
    });
  });

  group('Migration v2 → v3', () {
    /// Maßnahmen-Tabelle in der Fassung von Version 2 – noch ohne die
    /// Spalte für die Saison-Zuordnung.
    const v2Actions = '''
      CREATE TABLE hive_actions (
        id TEXT PRIMARY KEY,
        hive_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        brood_frames INTEGER,
        bee_frames INTEGER,
        temper INTEGER,
        queen_seen INTEGER,
        swarm_cells INTEGER,
        amount REAL,
        unit TEXT,
        treatment TEXT,
        photo_paths TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''';

    Future<Database> openV2() async {
      final db = await openV1();
      await db.execute(v2Actions);
      return db;
    }

    Future<List<String>> columns(Database db) async {
      final info = await db.rawQuery('PRAGMA table_info(hive_actions)');
      return info.map((r) => r['name'] as String).toList();
    }

    test('ergänzt die Spalte season_task', () async {
      final db = await openV2();
      addTearDown(db.close);

      expect(await columns(db), isNot(contains('season_task')));
      await DatabaseService.addColumnIfMissing(
          db, 'hive_actions', 'season_task', 'TEXT');
      expect(await columns(db), contains('season_task'));
    });

    test('bestehende Maßnahmen bleiben erhalten', () async {
      final db = await openV2();
      addTearDown(db.close);

      // Datensatz im alten Format (ohne die neue Spalte)
      final alt = _action(id: 'alt', note: 'vor der Migration').toMap()
        ..remove('season_task');
      await db.insert('hive_actions', alt);

      await DatabaseService.addColumnIfMissing(
          db, 'hive_actions', 'season_task', 'TEXT');

      final rows = await db.query('hive_actions');
      expect(rows, hasLength(1));
      final gelesen = HiveActionModel.fromMap(rows.single);
      expect(gelesen.note, 'vor der Migration');
      expect(gelesen.seasonTask, isNull);
    });

    test('ist mehrfach ausführbar', () async {
      final db = await openV2();
      addTearDown(db.close);

      for (var i = 0; i < 3; i++) {
        await DatabaseService.addColumnIfMissing(
            db, 'hive_actions', 'season_task', 'TEXT');
      }
      final spalten = await columns(db);
      expect(spalten.where((c) => c == 'season_task'), hasLength(1));
    });

    test('Neuanlage ab v3 bringt die Spalte schon mit', () async {
      final db = await openV1();
      addTearDown(db.close);
      await db.execute(DatabaseService.hiveActionsTableSql);
      expect(await columns(db), contains('season_task'));
    });
  });

  group('Migration v3 → v4', () {
    Future<List<String>> hiveColumns(Database db) async {
      final info = await db.rawQuery('PRAGMA table_info(hives)');
      return info.map((r) => r['name'] as String).toList();
    }

    test('ergänzt die Spalte position', () async {
      final db = await openV1();
      addTearDown(db.close);

      expect(await hiveColumns(db), isNot(contains('position')));
      await DatabaseService.addColumnIfMissing(
          db, 'hives', 'position', 'TEXT');
      expect(await hiveColumns(db), contains('position'));
    });

    test('bestehende Völker behalten ihren Standort', () async {
      final db = await openV1();
      addTearDown(db.close);

      await db.insert('hives', {
        'id': 'h1',
        'number': 1,
        'name': 'Zuchtvolk Anna',
        'qr_id': 'hive-abc',
        'location': 'Hausstand',
        'status': 'aktiv',
        'created_at': DateTime(2026, 3, 1).toIso8601String(),
      });

      await DatabaseService.addColumnIfMissing(
          db, 'hives', 'position', 'TEXT');

      final gelesen = HiveModel.fromMap((await db.query('hives')).single);
      expect(gelesen.location, 'Hausstand');
      expect(gelesen.position, isNull);
      // Eigener Name bleibt, obwohl es jetzt einen Ort gibt
      expect(gelesen.effectiveName, 'Zuchtvolk Anna');
    });

    test('ist mehrfach ausführbar', () async {
      final db = await openV1();
      addTearDown(db.close);

      for (var i = 0; i < 3; i++) {
        await DatabaseService.addColumnIfMissing(
            db, 'hives', 'position', 'TEXT');
      }
      final spalten = await hiveColumns(db);
      expect(spalten.where((c) => c == 'position'), hasLength(1));
    });
  });

  group('Maßnahmen speichern und lesen', () {
    late Database db;

    setUp(() async {
      db = await openV1();
      await db.execute(DatabaseService.hiveActionsTableSql);
      await db.execute(DatabaseService.hiveActionsIndexSql);
    });

    tearDown(() => db.close());

    Future<HiveActionModel> roundTrip(HiveActionModel a) async {
      await db.insert('hive_actions', a.toMap());
      final rows =
          await db.query('hive_actions', where: 'id = ?', whereArgs: [a.id]);
      return HiveActionModel.fromMap(rows.single);
    }

    test('Durchsicht mit allen Kennzahlen übersteht den Umlauf', () async {
      final original = _action(
        broodFrames: 6,
        beeFrames: 10,
        temper: 4,
        queenSeen: true,
        swarmCells: false,
        note: 'ruhig auf den Waben',
      );
      final gelesen = await roundTrip(original);

      expect(gelesen.type, HiveActionTypes.inspection);
      expect(gelesen.broodFrames, 6);
      expect(gelesen.beeFrames, 10);
      expect(gelesen.temper, 4);
      expect(gelesen.queenSeen, isTrue);
      expect(gelesen.swarmCells, isFalse);
      expect(gelesen.note, 'ruhig auf den Waben');
      expect(gelesen.date, original.date);
    });

    test('Honigernte mit Menge und Einheit', () async {
      final gelesen = await roundTrip(_action(
        id: 'a2',
        type: HiveActionTypes.harvest,
        amount: 12.5,
        unit: 'kg',
      ));
      expect(gelesen.amount, 12.5);
      expect(gelesen.unit, 'kg');
      expect(gelesen.summary, '12,5 kg');
    });

    test('Varroabehandlung mit Mittel', () async {
      final gelesen = await roundTrip(_action(
        id: 'a3',
        type: HiveActionTypes.varroa,
        treatment: 'Ameisensäure 60%',
        amount: 200,
        unit: 'ml',
      ));
      expect(gelesen.treatment, 'Ameisensäure 60%');
      expect(gelesen.summary, 'Ameisensäure 60% · 200 ml');
    });

    test('Fotos werden als Liste gespeichert', () async {
      final gelesen = await roundTrip(_action(
        id: 'a4',
        photoPaths: const ['erste.jpg', 'zweite.jpg'],
      ));
      expect(gelesen.photoPaths, ['erste.jpg', 'zweite.jpg']);
      expect(gelesen.hasPhotos, isTrue);
    });

    test('leere Felder bleiben leer', () async {
      final gelesen = await roundTrip(_action(id: 'a5'));
      expect(gelesen.photoPaths, isEmpty);
      expect(gelesen.hasPhotos, isFalse);
      expect(gelesen.amount, isNull);
      expect(gelesen.queenSeen, isNull);
      expect(gelesen.note, isNull);
    });

    test('beschädigte Foto-Spalte macht die Maßnahme nicht unlesbar',
        () async {
      final map = _action(id: 'a6').toMap()..['photo_paths'] = 'kein json';
      await db.insert('hive_actions', map);
      final rows =
          await db.query('hive_actions', where: 'id = ?', whereArgs: ['a6']);
      expect(HiveActionModel.fromMap(rows.single).photoPaths, isEmpty);
    });

    test('Maßnahmen kommen neueste zuerst', () async {
      await db.insert('hive_actions',
          _action(id: 'alt', date: DateTime(2026, 4, 1)).toMap());
      await db.insert('hive_actions',
          _action(id: 'neu', date: DateTime(2026, 6, 1)).toMap());
      await db.insert('hive_actions',
          _action(id: 'mitte', date: DateTime(2026, 5, 1)).toMap());

      final rows = await db.query(
        'hive_actions',
        where: 'hive_id = ?',
        whereArgs: ['h1'],
        orderBy: 'date DESC, created_at DESC',
      );
      expect(rows.map((r) => r['id']), ['neu', 'mitte', 'alt']);
    });

    test('Maßnahmen anderer Völker werden nicht mitgeliefert', () async {
      await db.insert('hive_actions', _action(id: 'x1').toMap());
      await db.insert(
          'hive_actions', _action(id: 'x2', hiveId: 'h2').toMap());

      final rows = await db
          .query('hive_actions', where: 'hive_id = ?', whereArgs: ['h1']);
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'x1');
    });
  });
}
