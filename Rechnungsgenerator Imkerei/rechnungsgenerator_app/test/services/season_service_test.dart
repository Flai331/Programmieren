import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/season_service.dart';

HiveModel _hive(String id, {int? number, String status = 'aktiv'}) =>
    HiveModel(
      id: id,
      number: number,
      qrId: 'qr-$id',
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

HiveActionModel _action({
  required String hiveId,
  required DateTime date,
  required String type,
  String? seasonTask,
  String id = 'a',
}) =>
    HiveActionModel(
      id: '$id-$hiveId-${date.millisecondsSinceEpoch}',
      hiveId: hiveId,
      date: date,
      type: type,
      seasonTask: seasonTask,
      createdAt: date,
    );

SeasonTaskStatus _statusOf(List<SeasonTaskStatus> alle, String taskId) =>
    alle.firstWhere((s) => s.task.id == taskId);

void main() {
  group('SeasonTask Zeitfenster', () {
    final varroa = SeasonCatalog.byId('varroa_sommer')!; // Juli–September
    final rest = SeasonCatalog.byId('restentmilbung')!; // Dezember–Januar

    test('Katalog ist vollständig auflösbar', () {
      for (final t in SeasonCatalog.tasks) {
        expect(SeasonCatalog.byId(t.id), same(t));
        expect(t.startMonth, inInclusiveRange(1, 12));
        expect(t.endMonth, inInclusiveRange(1, 12));
        expect(t.title, isNotEmpty);
      }
    });

    test('Aufgaben-Ids sind eindeutig', () {
      final ids = SeasonCatalog.tasks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('coversMonth ohne Jahreswechsel', () {
      expect(varroa.coversMonth(6), isFalse);
      expect(varroa.coversMonth(7), isTrue);
      expect(varroa.coversMonth(9), isTrue);
      expect(varroa.coversMonth(10), isFalse);
    });

    test('coversMonth über den Jahreswechsel', () {
      expect(rest.wrapsYear, isTrue);
      expect(rest.coversMonth(12), isTrue);
      expect(rest.coversMonth(1), isTrue);
      expect(rest.coversMonth(2), isFalse);
      expect(rest.coversMonth(11), isFalse);
    });

    test('Fenster umfasst den ganzen Endmonat', () {
      final w = varroa.currentWindow(DateTime(2026, 8, 15));
      expect(w.start, DateTime(2026, 7, 1));
      expect(w.contains(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(w.contains(DateTime(2026, 10, 1)), isFalse);
      expect(w.contains(DateTime(2026, 6, 30)), isFalse);
    });

    test('vor dem Fenster zählt der letzte Durchgang', () {
      // Im Mai 2026 ist die Sommerbehandlung noch nicht dran; sichtbar
      // bleibt, was im Sommer 2025 gemacht wurde.
      final w = varroa.currentWindow(DateTime(2026, 5, 1));
      expect(w.start.year, 2025);
      expect(w.contains(DateTime(2025, 8, 10)), isTrue);
    });

    test('Jahreswechsel-Fenster im Dezember und im Januar', () {
      final imDezember = rest.currentWindow(DateTime(2026, 12, 20));
      expect(imDezember.contains(DateTime(2026, 12, 27)), isTrue);
      expect(imDezember.contains(DateTime(2027, 1, 5)), isTrue);

      // Anfang Januar gehört noch zum Durchgang, der im Dezember begann.
      final imJanuar = rest.currentWindow(DateTime(2027, 1, 8));
      expect(imJanuar.start, DateTime(2026, 12, 1));
      expect(imJanuar.contains(DateTime(2026, 12, 27)), isTrue);
    });
  });

  group('Erledigt-Erkennung', () {
    final drohnen = SeasonCatalog.byId('drohnenrahmen')!;
    final waben = SeasonCatalog.byId('wabentausch')!;

    test('freie Maßnahme zählt über ihre Art', () {
      final a = _action(
          hiveId: 'h1',
          date: DateTime(2026, 4, 10),
          type: HiveActionTypes.combs);
      expect(drohnen.isFulfilledBy(a), isTrue);
      expect(waben.isFulfilledBy(a), isTrue);
    });

    test('zugeordnete Maßnahme zählt nur für ihre Aufgabe', () {
      // Der eigentliche Grund für das Feld: beide Aufgaben sind eine
      // Wabenerneuerung im Frühjahr und wären sonst nicht zu trennen.
      final a = _action(
        hiveId: 'h1',
        date: DateTime(2026, 4, 10),
        type: HiveActionTypes.combs,
        seasonTask: 'drohnenrahmen',
      );
      expect(drohnen.isFulfilledBy(a), isTrue);
      expect(waben.isFulfilledBy(a), isFalse);
    });

    test('andere Maßnahmenart erledigt die Aufgabe nicht', () {
      final a = _action(
          hiveId: 'h1',
          date: DateTime(2026, 4, 10),
          type: HiveActionTypes.feeding);
      expect(drohnen.isFulfilledBy(a), isFalse);
    });
  });

  group('SeasonService.buildStatuses', () {
    final referenz = DateTime(2026, 8, 15); // Varroa + Einfütterung sind dran

    test('ohne Maßnahmen ist alles offen', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2')],
        actions: const [],
        reference: referenz,
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      expect(varroa.total, 2);
      expect(varroa.doneCount, 0);
      expect(varroa.openCount, 2);
      expect(varroa.isComplete, isFalse);
      expect(varroa.isDue, isTrue);
      expect(varroa.progress, 0);
    });

    test('behandelte Völker gelten als erledigt', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2'), _hive('h3')],
        actions: [
          _action(
              hiveId: 'h1',
              date: DateTime(2026, 8, 1),
              type: HiveActionTypes.varroa),
        ],
        reference: referenz,
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      expect(varroa.doneCount, 1);
      expect(varroa.openCount, 2);
      expect(varroa.progress, closeTo(1 / 3, 0.001));
      expect(varroa.doneHives.single.hive.id, 'h1');
      expect(varroa.openHives.map((h) => h.hive.id), ['h2', 'h3']);
    });

    test('Maßnahme außerhalb des Fensters zählt nicht', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1')],
        actions: [
          // Restentmilbung im Januar, nicht die Sommerbehandlung
          _action(
              hiveId: 'h1',
              date: DateTime(2026, 1, 10),
              type: HiveActionTypes.varroa),
        ],
        reference: referenz,
      );
      expect(_statusOf(alle, 'varroa_sommer').doneCount, 0);
    });

    test('nicht aktive Völker zählen nicht mit', () {
      final alle = SeasonService.buildStatuses(
        hives: [
          _hive('h1'),
          _hive('h2', status: 'abgegeben'),
          _hive('h3', status: 'eingegangen'),
        ],
        actions: const [],
        reference: referenz,
      );
      expect(_statusOf(alle, 'varroa_sommer').total, 1);
    });

    test('alle Völker erledigt ⇒ abgeschlossen', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2')],
        actions: [
          for (final id in ['h1', 'h2'])
            _action(
                hiveId: id,
                date: DateTime(2026, 8, 5),
                type: HiveActionTypes.varroa),
        ],
        reference: referenz,
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      expect(varroa.isComplete, isTrue);
      expect(varroa.progress, 1);
    });

    test('ohne Völker ist nichts abgeschlossen', () {
      final alle = SeasonService.buildStatuses(
        hives: const [],
        actions: const [],
        reference: referenz,
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      expect(varroa.total, 0);
      expect(varroa.isComplete, isFalse);
      expect(varroa.progress, 0);
    });

    test('zwei Aufgaben gleicher Art bleiben getrennt', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1')],
        actions: [
          _action(
            hiveId: 'h1',
            date: DateTime(2026, 4, 20),
            type: HiveActionTypes.combs,
            seasonTask: 'drohnenrahmen',
          ),
        ],
        reference: DateTime(2026, 4, 25),
      );
      expect(_statusOf(alle, 'drohnenrahmen').doneCount, 1);
      expect(_statusOf(alle, 'wabentausch').doneCount, 0);
    });
  });

  group('Packliste', () {
    test('Mengen richten sich nach den offenen Völkern', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2'), _hive('h3'), _hive('h4')],
        actions: [
          _action(
              hiveId: 'h1',
              date: DateTime(2026, 8, 1),
              type: HiveActionTypes.varroa),
        ],
        reference: DateTime(2026, 8, 15),
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      expect(varroa.openCount, 3);

      final saeure = varroa.packList
          .firstWhere((e) => e.item.name == 'Ameisensäure 60%');
      expect(saeure.quantity, 600); // 200 ml × 3 offene Völker
      expect(saeure.quantityLabel, '600 ml');
    });

    test('Werkzeug wird nicht hochgerechnet', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2')],
        actions: const [],
        reference: DateTime(2026, 8, 15),
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      final brille = varroa.packList
          .firstWhere((e) => e.item.name == 'Schutzbrille + Handschuhe');
      expect(brille.quantity, isNull);
      expect(brille.quantityLabel, '');
    });

    test('alles erledigt ⇒ keine Mengen mehr nötig', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1')],
        actions: [
          _action(
              hiveId: 'h1',
              date: DateTime(2026, 8, 1),
              type: HiveActionTypes.varroa),
        ],
        reference: DateTime(2026, 8, 15),
      );
      final varroa = _statusOf(alle, 'varroa_sommer');
      final saeure = varroa.packList
          .firstWhere((e) => e.item.name == 'Ameisensäure 60%');
      expect(saeure.quantity, 0);
    });

    test('gebrochene Mengen mit Komma', () {
      const item = PackItem('Sirup', perHive: 12.5, unit: 'kg');
      const entry = PackListEntry(item: item, quantity: 37.5);
      expect(entry.quantityLabel, '37,5 kg');
    });
  });

  group('Anstehend und demnächst', () {
    test('due liefert nur den laufenden Monat, offene zuerst', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1'), _hive('h2')],
        actions: [
          // Einfütterung an beiden Völkern erledigt
          for (final id in ['h1', 'h2'])
            _action(
                hiveId: id,
                date: DateTime(2026, 8, 20),
                type: HiveActionTypes.feeding),
        ],
        reference: DateTime(2026, 8, 25),
      );
      final anstehend = SeasonService.due(alle);

      expect(anstehend.every((s) => s.isDue), isTrue);
      expect(anstehend.map((s) => s.task.id), contains('varroa_sommer'));
      expect(anstehend.map((s) => s.task.id), contains('einfuetterung'));
      // Abgeschlossenes rutscht ans Ende
      expect(anstehend.last.task.id, 'einfuetterung');
    });

    test('upcoming zeigt die nächsten Monate ohne Dopplung', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1')],
        actions: const [],
        reference: DateTime(2026, 8, 15),
      );
      final kommend = SeasonService.upcoming(alle, DateTime(2026, 8, 15));

      final ids = kommend.map((s) => s.task.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, isNot(contains('varroa_sommer'))); // steht schon an
      expect(ids, contains('wintervorbereitung')); // Oktober
    });

    test('upcoming rechnet über den Jahreswechsel', () {
      final alle = SeasonService.buildStatuses(
        hives: [_hive('h1')],
        actions: const [],
        reference: DateTime(2026, 11, 15),
      );
      final kommend = SeasonService.upcoming(alle, DateTime(2026, 11, 15));
      expect(kommend.map((s) => s.task.id), contains('restentmilbung'));
    });
  });
}
