import 'package:akku_schoner/logic.dart';
import 'package:flutter_test/flutter_test.dart';

AppEntry app(String pkg,
        {bool system = false,
        bool stopped = false,
        bool protected = false,
        int bgMin = 0,
        Level level = Level.soft,
        Level? auto,
        int? days7,
        bool audio = false,
        DateTime? last}) =>
    AppEntry(
      pkg: pkg,
      label: pkg,
      system: system,
      stopped: stopped,
      protected: protected,
      fgService: Duration(minutes: bgMin),
      autoLevel: auto ?? level,
      level: level,
      days7: days7,
      audio: audio,
      lastUsed: last,
    );

void main() {
  group('planCleanup', () {
    test('sanft = Stufe soft, komplett = Stufe full, nur laufende, nie geschützte', () {
      final plan = planCleanup([
        app('keep', level: Level.keep),
        app('soft'),
        app('full', level: Level.full),
        app('fullStopped', level: Level.full, stopped: true),
        app('launcher', level: Level.full, protected: true),
      ]);
      expect(plan.soft.map((a) => a.pkg), ['soft']);
      expect(plan.full.map((a) => a.pkg), ['full']);
      expect(plan.count, 2);
    });

    test('von Hand gesetzte Stufe erkennbar', () {
      expect(app('a', level: Level.full, auto: Level.soft).manual, isTrue);
      expect(app('a').manual, isFalse);
      expect(app('a').copyWith(level: Level.keep).level, Level.keep);
    });
  });

  group('Stufen', () {
    test('parseLevel und Begründung', () {
      expect(parseLevel('full'), Level.full);
      expect(parseLevel('soft'), Level.soft);
      expect(parseLevel(null), Level.keep);
      expect(autoReason(app('a', level: Level.keep, days7: 6)), contains('oft benutzt'));
      expect(autoReason(app('s', audio: true, days7: 0)), contains('Kopfhörer'));
      expect(autoReason(app('x', level: Level.full, days7: 0)), '7 Tage nicht benutzt');
      expect(autoReason(app('y', days7: null)), contains('Nutzungszugriff'));
    });

    test('fromMap liest Stufen aus Kotlin', () {
      final a = AppEntry.fromMap({
        'pkg': 'com.spotify.music',
        'label': 'Spotify',
        'autoLevel': 'soft',
        'level': 'full',
        'days7': 2,
      });
      expect(a.level, Level.full);
      expect(a.autoLevel, Level.soft);
      expect(a.manual, isTrue);
      expect(a.days7, 2);
    });
  });

  group('sortApps', () {
    test('aktive vor beendeten, dann Hintergrundzeit, dann zuletzt benutzt', () {
      final now = DateTime(2026, 10, 9, 12);
      final sorted = sortApps([
        app('stopped', stopped: true, bgMin: 500),
        app('old', last: now.subtract(const Duration(hours: 5))),
        app('bg', bgMin: 30),
        app('recent', last: now.subtract(const Duration(minutes: 5))),
      ]);
      expect(sorted.map((a) => a.pkg), ['bg', 'recent', 'old', 'stopped']);
    });
  });

  group('Formatierung', () {
    test('formatDuration', () {
      expect(formatDuration(const Duration(seconds: 20)), '< 1 min');
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
      expect(formatDuration(const Duration(minutes: 135)), '2 h 15 min');
    });

    test('formatAgo', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(formatAgo(null, now), 'nicht in den letzten 24 h');
      expect(formatAgo(now.subtract(const Duration(minutes: 3)), now), 'vor 3 min');
      expect(formatAgo(now.subtract(const Duration(hours: 4)), now), 'vor 4 h');
    });

    test('currentToMa erkennt Mikro- und Milliampere', () {
      expect(currentToMa(null), isNull);
      expect(currentToMa(-450000), -450);
      expect(currentToMa(1200), 1200);
    });
  });

  group('batteryAdvice', () {
    test('warnt bei Hitze und voller Ladung', () {
      final a = batteryAdvice(const BatteryState(level: 85, charging: true, temp: 42, health: 'good'));
      expect(a.where((x) => x.severity == Severity.danger), hasLength(1));
      expect(a.any((x) => x.text.contains('abstecken')), isTrue);
    });

    test('warnt bei wenig Akku', () {
      final a = batteryAdvice(const BatteryState(level: 12, temp: 25, health: 'good'));
      expect(a.any((x) => x.text.contains('bald laden')), isTrue);
    });

    test('defekter Akku ist gefährlich', () {
      final a = batteryAdvice(const BatteryState(level: 60, temp: 25, health: 'dead'));
      expect(a.first.severity, Severity.danger);
    });

    test('alles gut', () {
      final a = batteryAdvice(const BatteryState(level: 70, temp: 28, health: 'good', powerSave: true));
      expect(a.single.text, 'Alles im grünen Bereich.');
    });

    test('fromMap mit fehlenden Werten', () {
      final b = BatteryState.fromMap({'level': 55, 'currentNow': 300000});
      expect(b.level, 55);
      expect(b.currentMa, 300);
      expect(b.health, 'unknown');
    });
  });
}
