import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:beebrain/services/honey_service.dart';
import 'package:beebrain/services/warmer_alarms.dart';

/// Die Meldung zur Wärmeschrank-Uhr, soweit sie ohne Handy prüfbar ist.
///
/// Was hier steht: dass Dart die richtigen Aufrufe mit den richtigen Namen
/// abschickt, dass eine abgelaufene Uhr keine Meldung mehr auslöst, und dass
/// die offenen Uhren beim Start aus dem Verlauf wiederkommen.
///
/// Was hier NICHT steht und nur auf dem Gerät zu sehen ist: ob Android die
/// Weckzeit hält, ob die Berechtigungsabfrage erscheint und ob die Meldung
/// tatsächlich kommt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final alarme = WarmerAlarms();
  final gerufen = <MethodCall>[];

  /// Die Kotlin-Seite gibt es im Test nicht – also einer, der mitschreibt.
  void kanalErsatz({Object? antwort = true, bool wirft = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WarmerAlarms.channel, (ruf) async {
      gerufen.add(ruf);
      if (wirft) throw PlatformException(code: 'kaputt');
      return antwort;
    });
  }

  setUp(() {
    gerufen.clear();
    // Im Test läuft kein Android; der Dienst hält sich sonst zurück.
    alarme.available = true;
    kanalErsatz();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WarmerAlarms.channel, null);
    alarme.available = false;
  });

  HoneyBucketModel eimer({String id = 'b1', String code = 'SO-042'}) =>
      HoneyBucketModel(
        id: id,
        code: code,
        number: 42,
        variety: HoneyVarieties.summer,
        harvestDate: DateTime(2026, 7, 14),
        filledKg: 25,
        waterContent: 17.2,
        state: HoneyStates.readyToBottle,
        createdAt: DateTime(2026, 7, 14, 18),
      );

  group('Die Weckzeit setzen', () {
    test('schickt Eimer, Zeitpunkt und Text hinüber', () async {
      final uhr = HoneyWarmer(
          startedAt: DateTime(2026, 11, 24, 9), requiredHours: 48);

      final ok = await alarme.schedule(
          bucket: eimer(), warmer: uhr, now: DateTime(2026, 11, 24, 10));

      expect(ok, isTrue);
      expect(gerufen, hasLength(1));
      expect(gerufen.first.method, 'schedule');
      final args = gerufen.first.arguments as Map;
      expect(args['bucketId'], 'b1');
      expect(args['dueAtMillis'], DateTime(2026, 11, 26, 9)
          .millisecondsSinceEpoch);
      expect(args['title'], contains('SO-042'));
      expect(args['text'], contains('48 h'));
    });

    test('eine abgelaufene Uhr meldet sich nicht mehr', () async {
      // Eine Meldung, die sofort kommt, sagt nichts, was nicht schon am
      // Eimer steht.
      final uhr = HoneyWarmer(
          startedAt: DateTime(2026, 11, 24, 9), requiredHours: 48);

      final ok = await alarme.schedule(
          bucket: eimer(), warmer: uhr, now: DateTime(2026, 11, 27, 9));

      expect(ok, isFalse);
      expect(gerufen, isEmpty, reason: 'kein Aufruf, nicht nur kein Erfolg');
    });

    test('ein Fehler der Gegenseite bleibt ein Nein', () async {
      kanalErsatz(wirft: true);
      final uhr = HoneyWarmer(
          startedAt: DateTime(2026, 11, 24, 9), requiredHours: 24);

      expect(
        await alarme.schedule(
            bucket: eimer(), warmer: uhr, now: DateTime(2026, 11, 24, 10)),
        isFalse,
      );
    });

    test('ohne Android wird gar nicht gerufen', () async {
      alarme.available = false;
      final uhr = HoneyWarmer(
          startedAt: DateTime(2026, 11, 24, 9), requiredHours: 24);

      expect(await alarme.canNotify(), isFalse);
      expect(
        await alarme.schedule(
            bucket: eimer(), warmer: uhr, now: DateTime(2026, 11, 24, 10)),
        isFalse,
      );
      await alarme.cancel('b1');
      expect(gerufen, isEmpty);
    });

    test('abnehmen nennt den Eimer', () async {
      await alarme.cancel('b7');
      expect(gerufen.single.method, 'cancel');
      expect((gerufen.single.arguments as Map)['bucketId'], 'b7');
    });
  });

  group('Beim Start wiederanmelden', () {
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

    Future<HoneyBucketModel> anlegen(String id, String code) async {
      final bucket = eimer(id: id, code: code);
      await DatabaseService().insertHoneyBucket(bucket);
      return bucket;
    }

    test('nur die Eimer mit laufender Uhr', () async {
      final service = await dienst();
      final a = await anlegen('b1', 'SO-001');
      final b = await anlegen('b2', 'SO-002');
      await anlegen('b3', 'SO-003'); // war nie im Schrank

      await service.startWarmer(a, at: DateTime(2026, 11, 24, 9));
      await service.startWarmer(b, at: DateTime(2026, 11, 24, 9));
      await service.stopWarmer(b, at: DateTime(2026, 11, 25, 9));

      final offen = await service.runningWarmers();
      expect(offen.map((u) => u.bucket.id), ['b1']);

      gerufen.clear();
      final gesetzt = await alarme.reregister(
          honey: service, now: DateTime(2026, 11, 25, 10));

      expect(gesetzt, 1);
      expect(gerufen, hasLength(1));
      expect((gerufen.single.arguments as Map)['bucketId'], 'b1');
    });

    test('abgelaufene Uhren werden nicht neu angemeldet', () async {
      final service = await dienst();
      final a = await anlegen('b1', 'SO-001');
      await service.startWarmer(a, at: DateTime(2026, 11, 24, 9));

      gerufen.clear();
      // Zwei Wochen später: die Uhr ist längst durch.
      final gesetzt = await alarme.reregister(
          honey: service, now: DateTime(2026, 12, 8, 9));

      expect(gesetzt, 0);
      expect(gerufen, isEmpty);
      // Die Uhr steht trotzdem noch im Verlauf – am Eimer ist sie zu sehen.
      expect(await service.runningWarmers(), hasLength(1));
    });

    test('ohne Eimer passiert nichts', () async {
      final service = await dienst();
      expect(await alarme.reregister(honey: service), 0);
      expect(gerufen, isEmpty);
    });
  });

  group('Die Texte', () {
    test('nennen Code, Sorte und Stunden', () {
      final uhr = HoneyWarmer(
          startedAt: DateTime(2026, 11, 24, 9), requiredHours: 24);
      expect(WarmerAlarms.titleFor(eimer()), 'Eimer SO-042 ist durchgewärmt');
      expect(WarmerAlarms.textFor(eimer(), uhr),
          'Sommerblüte stand 24 h im Wärmeschrank und kann heraus.');
    });
  });
}
