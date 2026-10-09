import 'package:akku_schoner/logic.dart';
import 'package:flutter_test/flutter_test.dart';

AppEntry app(String pkg,
        {bool system = false,
        bool stopped = false,
        bool protected = false,
        int bgMin = 0,
        DateTime? last}) =>
    AppEntry(
      pkg: pkg,
      label: pkg,
      system: system,
      stopped: stopped,
      protected: protected,
      fgService: Duration(minutes: bgMin),
      lastUsed: last,
    );

void main() {
  group('stopCandidates', () {
    test('nur laufende, nicht wichtige, nicht geschützte Nutzer-Apps', () {
      final apps = [
        app('a'),
        app('b', stopped: true),
        app('c', system: true),
        app('d', protected: true),
        app('com.whatsapp'),
        app('e'),
      ];
      final result = stopCandidates(apps, {...defaultImportant, 'e'});
      expect(result.map((a) => a.pkg), ['a']);
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
