import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:beebrain/services/honey_service.dart';

/// Die Hakenliste und die Markierung durch den Dienst hindurch – gegen eine
/// Datenbank im Speicher, nicht gegen die Rechnung allein.
///
/// Zwei Stellen sind hier wirklich heikel, und genau dafür steht diese Datei:
/// Eine Markierung abzunehmen heißt, eine Spalte auf `null` zu setzen, und
/// `copyWith(crystallization: null)` bedeutet „unverändert" – nur das Flag
/// nimmt sie weg. Und das Melitherm muss zwei Dinge auf einmal tun: zurück auf
/// Haken 1 UND die Markierung löschen.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Ein Dienst, der auf eine frische Datenbank im Speicher schreibt.
  Future<HoneyService> dienst() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 7),
    );
    await DatabaseService.createStockTables(db);

    final datenbank = DatabaseService();
    datenbank.databaseForTests = db;
    addTearDown(() async {
      datenbank.databaseForTests = null;
      await db.close();
    });
    return HoneyService(datenbank);
  }

  Future<HoneyBucketModel> eimer(
    HoneyService service, {
    String state = HoneyStates.extracted,
    String? crystallization,
  }) async {
    final bucket = HoneyBucketModel(
      id: 'b1',
      code: 'SO-042',
      number: 42,
      variety: HoneyVarieties.summer,
      harvestDate: DateTime(2026, 7, 14),
      bucketSizeKg: 25,
      filledKg: 25,
      waterContent: 17.2,
      state: state,
      crystallization: crystallization,
      createdAt: DateTime(2026, 7, 14, 18),
    );
    await DatabaseService().insertHoneyBucket(bucket);
    return bucket;
  }

  group('Haken setzen und zurücknehmen', () {
    test('ein Haken schreibt den Zustand und eine Verlaufszeile', () async {
      final service = await dienst();
      final bucket = await eimer(service);

      final geaendert = await service.setState(bucket, HoneyStates.seeded);

      expect(geaendert.state, HoneyStates.seeded);
      final gelesen = await DatabaseService().getHoneyBucket('b1');
      expect(gelesen!.state, HoneyStates.seeded);
      expect(HoneyStates.ticksOf(gelesen.state), 2);

      final verlauf = await DatabaseService().getHoneyEvents('b1');
      expect(verlauf, hasLength(1));
      expect(verlauf.first.kind, HoneyEventKinds.state);
      expect(verlauf.first.state, HoneyStates.seeded);
    });

    test('ein Haken zurück schreibt den Verlauf nicht um', () async {
      final service = await dienst();
      var bucket = await eimer(service);

      bucket = await service.setState(bucket, HoneyStates.stirred);
      bucket = await service.setState(
          bucket, HoneyStates.stateForTicks(1)); // zwei Haken weg

      expect(HoneyStates.ticksOf(bucket.state), 1);
      // Beide Schritte stehen im Verlauf: dort steht, was geschah.
      final verlauf = await DatabaseService().getHoneyEvents('b1');
      expect(verlauf, hasLength(2));
      expect(
        verlauf.map((e) => e.state).toSet(),
        {HoneyStates.stirred, HoneyStates.stateForTicks(1)},
      );
    });
  });

  group('Markierung grob und kandiert', () {
    test('setzen lässt die Haken stehen', () async {
      final service = await dienst();
      final bucket = await eimer(service, state: HoneyStates.stirred);

      final geaendert = await service.setCrystallization(
          bucket, HoneyCrystallization.coarse);

      expect(geaendert.crystallization, HoneyCrystallization.coarse);
      expect(geaendert.state, HoneyStates.stirred, reason: 'kein Arbeitsschritt');
      expect(geaendert.needsAttention, isTrue);

      final gelesen = await DatabaseService().getHoneyBucket('b1');
      expect(gelesen!.crystallization, HoneyCrystallization.coarse);
      expect(gelesen.state, HoneyStates.stirred);

      final verlauf = await DatabaseService().getHoneyEvents('b1');
      expect(verlauf, hasLength(1));
      expect(verlauf.first.kind, HoneyEventKinds.crystallization);
      expect(verlauf.first.note, 'grob kristallin');
    });

    test('abnehmen räumt die Spalte wirklich leer', () async {
      // Die Falle: copyWith(crystallization: null) heißt „unverändert".
      final service = await dienst();
      final bucket = await eimer(service,
          state: HoneyStates.stirred,
          crystallization: HoneyCrystallization.solid);

      final geaendert = await service.setCrystallization(bucket, null);

      expect(geaendert.crystallization, isNull);
      final gelesen = await DatabaseService().getHoneyBucket('b1');
      expect(gelesen!.crystallization, isNull);
      expect(gelesen.needsAttention, HoneyStates.needsAttention(gelesen.state));

      final verlauf = await DatabaseService().getHoneyEvents('b1');
      expect(verlauf.first.note, 'Markierung entfernt');
    });
  });

  group('Durch das Melitherm', () {
    test('setzt auf Haken 1 und löscht die Markierung', () async {
      final service = await dienst();
      final bucket = await eimer(service,
          state: HoneyStates.readyToBottle,
          crystallization: HoneyCrystallization.coarse);

      final geaendert = await service.throughMelitherm(bucket);

      expect(HoneyStates.ticksOf(geaendert.state), 1);
      expect(geaendert.crystallization, isNull);
      expect(geaendert.needsAttention, isTrue,
          reason: 'nach dem Melitherm ist wieder zu impfen');

      final gelesen = await DatabaseService().getHoneyBucket('b1');
      expect(gelesen!.state, HoneyStates.stateForTicks(1));
      expect(gelesen.crystallization, isNull);

      final verlauf = await DatabaseService().getHoneyEvents('b1');
      expect(verlauf, hasLength(1));
      expect(verlauf.first.kind, HoneyEventKinds.state);
      expect(verlauf.first.note, 'durch das Melitherm');
    });

    test('auf einem Eimer ohne Markierung ändert es nichts Falsches',
        () async {
      final service = await dienst();
      final bucket = await eimer(service, state: HoneyStates.extracted);

      final geaendert = await service.throughMelitherm(bucket);

      expect(geaendert.state, HoneyStates.stateForTicks(1));
      expect(geaendert.crystallization, isNull);
    });
  });
}
