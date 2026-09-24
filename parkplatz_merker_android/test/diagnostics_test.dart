import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/logic/models.dart';
import 'package:parkplatz_merker/logic/detection.dart';
import 'package:parkplatz_merker/logic/diagnostics.dart';

RawEvent act(int tMin, String activity, String transition) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'activity',
    t: t,
    data: {
      'type': 'activity',
      't': t,
      'activity': activity,
      'transition': transition,
      'rx': t + 100,
    },
  );
}

RawEvent loc(int tMin, double lat, double lng, double acc, {String reason = 'periodic'}) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'loc',
    t: t,
    data: {
      'type': 'loc',
      't': t,
      'lat': lat,
      'lng': lng,
      'acc': acc,
      'reason': reason,
    },
  );
}

RawEvent scan(int tMin, String mode, String target,
    {bool ok = true, bool found = false, int? rssi, String? error}) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'scan',
    t: t,
    data: {
      'type': 'scan',
      't': t,
      'mode': mode,
      'target': target,
      'end': t + 12000,
      'ok': ok,
      'found': found,
      'rssi': rssi,
      'error': error,
    },
  );
}

void main() {
  group('Diagnostics Tests', () {
    test('Thin periodic locations: max one per 5 minutes', () {
      final events = [
        loc(0, 52.52, 13.40, 10, reason: 'periodic'),
        loc(1, 52.52, 13.40, 10, reason: 'periodic'),
        loc(2, 52.52, 13.40, 10, reason: 'periodic'),
        loc(6, 52.52, 13.40, 10, reason: 'periodic'),
        loc(7, 52.52, 13.40, 10, reason: 'periodic'),
        act(10, 'IN_VEHICLE', 'ENTER'),
      ];

      final diag = diagnosticEvents(events);

      // Should have fewer periodic locations
      final periodicCount = diag.where((e) => e.type == 'loc' && e.str('reason') == 'periodic').length;
      expect(periodicCount, lessThan(events.where((e) => e.type == 'loc' && e.str('reason') == 'periodic').length));
    });

    test('Limit to 100 events', () {
      final events = <RawEvent>[];
      for (int i = 0; i < 200; i++) {
        events.add(loc(i, 52.52, 13.40, 10, reason: 'periodic'));
      }

      final diag = diagnosticEvents(events, limit: 100);

      expect(diag.length, lessThanOrEqualTo(100));
    });

    test('describeEvent: activity event', () {
      final event = act(0, 'IN_VEHICLE', 'ENTER');

      final desc = describeEvent(event);

      expect(desc.contains('Aktivität'), true);
      expect(desc.contains('IN_VEHICLE'), true);
      expect(desc.contains('ENTER'), true);
    });

    test('describeEvent: location event', () {
      final event = loc(5, 52.52, 13.40, 10, reason: 'exit');

      final desc = describeEvent(event);

      expect(desc.contains('Standort'), true);
      expect(desc.contains('52.52'), true);
      expect(desc.contains('±'), true);
    });

    test('describeEvent: scan found', () {
      final event = scan(10, 'transmitter', 'AA:BB:CC', found: true, rssi: -50);

      final desc = describeEvent(event);

      expect(desc.contains('Suche'), true);
      expect(desc.contains('gefunden'), true);
      expect(desc.contains('RSSI'), true);
    });

    test('describeEvent: scan not found', () {
      final event = scan(10, 'transmitter', 'AA:BB:CC', found: false);

      final desc = describeEvent(event);

      expect(desc.contains('Suche'), true);
      expect(desc.contains('nicht gefunden'), true);
    });

    test('describeEvent: scan error', () {
      final event = scan(10, 'transmitter', 'AA:BB:CC', ok: false, error: 'Permission denied');

      final desc = describeEvent(event);

      expect(desc.contains('Fehler'), true);
      expect(desc.contains('Permission'), true);
    });

    test('describeEvent: info event', () {
      final event = RawEvent(
        type: 'info',
        t: 5000,
        data: {
          'type': 'info',
          't': 5000,
          'msg': 'Test info message',
        },
      );

      final desc = describeEvent(event);

      expect(desc.contains('Info'), true);
      expect(desc.contains('Test info message'), true);
    });

    test('deviceStats: counts scans and hits', () {
      final events = [
        scan(5, 'transmitter', 'AA:BB:CC', found: true, rssi: -50),
        scan(10, 'transmitter', 'AA:BB:CC', found: false),
        scan(15, 'transmitter', 'AA:BB:CC', found: true, rssi: -60),
        scan(20, 'transmitter', 'AA:BB:CC', found: false),
      ];

      final stats = deviceStats(events, 'AA:BB:CC');

      expect(stats.scans, 4);
      expect(stats.hits, 2);
      expect(stats.lastSeen, isNotNull);
      expect(stats.lastRssi, -60);
    });

    test('deviceStats: with no scans', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        loc(5, 52.52, 13.40, 10),
      ];

      final stats = deviceStats(events, 'AA:BB:CC');

      expect(stats.scans, 0);
      expect(stats.hits, 0);
      expect(stats.lastSeen, isNull);
    });

    test('buildDiagnosticText: generates complete text', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        loc(5, 52.52, 13.40, 10),
        act(20, 'IN_VEHICLE', 'EXIT'),
      ];

      final permissions = {
        'location': '✓',
        'activity_recognition': '✓',
      };

      final nativeStatus = {
        'sdkInt': 30,
        'bluetoothEnabled': true,
      };

      final config = {
        'deviceMode': 'transmitter',
        'deviceAddress': 'AA:BB:CC:DD:EE:FF',
      };

      final tripResults = <TripResult>[];

      final text = buildDiagnosticText(
        events: events,
        permissions: permissions,
        nativeStatus: nativeStatus,
        config: config,
        tripResults: tripResults,
      );

      expect(text.contains('Parkplatz-Merker Diagnose'), true);
      expect(text.contains('Berechtigungen'), true);
      expect(text.contains('Native Status'), true);
      expect(text.contains('Einstellungen'), true);
      expect(text.contains('Ereignisse'), true);
    });
  });
}
