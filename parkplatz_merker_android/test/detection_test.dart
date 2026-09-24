import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/logic/models.dart';
import 'package:parkplatz_merker/logic/detection.dart';

// Hilffunktionen zum Bauen von Ereignissen (Zeiten in Minuten ab einer Basis)
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

RawEvent power(int tMin, bool plugged, {String reason = 'change'}) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'power',
    t: t,
    data: {
      'type': 'power',
      't': t,
      'plugged': plugged,
      'reason': reason,
    },
  );
}

RawEvent beaconBg(int tMin, String target, int rssi) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'beacon_bg',
    t: t,
    data: {
      'type': 'beacon_bg',
      't': t,
      'target': target,
      'rssi': rssi,
    },
  );
}

RawEvent manual(int tMin, double lat, double lng, double acc, {String source = 'widget'}) {
  final t = tMin * 60 * 1000;
  return RawEvent(
    type: 'manual',
    t: t,
    data: {
      'type': 'manual',
      't': t,
      'source': source,
      'lat': lat,
      'lng': lng,
      'acc': acc,
      'error': null,
    },
  );
}

void main() {
  group('Detection Tests', () {
    test('1. Normal trip 0-20 min, EXIT 20, WALKING 21, loc at 20 → parking spot at loc(20)', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        act(21, 'WALKING', 'ENTER'),
        loc(20, 52.52, 13.40, 10),
      ];
      final now = 22 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      final spot = spots[0];
      expect(spot.id, startsWith('auto-'));
      expect(spot.lat, 52.52);
      expect(spot.lng, 13.40);
      expect(spot.sources, ['Aussteigen']);
    });

    test('2. 2 min trip → no parking spot (too short)', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(2, 'IN_VEHICLE', 'EXIT'),
        loc(2, 52.52, 13.40, 10),
      ];
      final now = 3 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 0);
    });

    test('3. Traffic light: EXIT 10, ENTER 11, EXIT 30, WALKING 31 → one parking spot at time 30', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(10, 'IN_VEHICLE', 'EXIT'),
        act(11, 'IN_VEHICLE', 'ENTER'),
        act(30, 'IN_VEHICLE', 'EXIT'),
        act(31, 'WALKING', 'ENTER'),
        loc(30, 52.52, 13.40, 10),
      ];
      final now = 32 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      final spot = spots[0];
      expect(spot.time, 30 * 60 * 1000);
    });

    test('4. Long traffic jam: EXIT 10, ENTER 15 without WALKING, EXIT 30, WALKING 31 → one parking spot at 30', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(10, 'IN_VEHICLE', 'EXIT'),
        act(15, 'IN_VEHICLE', 'ENTER'),
        act(30, 'IN_VEHICLE', 'EXIT'),
        act(31, 'WALKING', 'ENTER'),
        loc(30, 52.52, 13.40, 10),
      ];
      final now = 32 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
    });

    test('5. Not finished yet: EXIT 20, now = 21 → no spot; now = 23 + WALKING 21 → one spot', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        act(21, 'WALKING', 'ENTER'),
        loc(20, 52.52, 13.40, 10),
      ];

      var now = 21 * 60 * 1000;
      var spots = detectParkings(events, now);
      expect(spots.length, 0);

      now = 23 * 60 * 1000;
      spots = detectParkings(events, now);
      expect(spots.length, 1);
    });

    test('6. Without WALKING: now = exit + 16 min → parking spot', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        loc(20, 52.52, 13.40, 10),
      ];
      final now = 36 * 60 * 1000; // exit + 16 min

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
    });

    test('7. Bus/Taxi rule: scans ok & never found → no parking spot', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        scan(5, 'transmitter', 'AA:BB:CC', found: false),
        scan(10, 'transmitter', 'AA:BB:CC', found: false),
        scan(25, 'transmitter', 'AA:BB:CC', found: false),
        loc(20, 52.52, 13.40, 10),
      ];
      final now = 30 * 60 * 1000;

      final results = evaluateTrips(events, now);
      final rejected = results.where((r) => r.status.contains('nicht dein Auto'));

      expect(rejected.length, 1);
    });

    test('8. All scans ok: false → parking spot anyway', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        scan(5, 'transmitter', 'AA:BB:CC', ok: false, error: 'Permission denied'),
        scan(10, 'transmitter', 'AA:BB:CC', ok: false, error: 'Permission denied'),
        loc(20, 52.52, 13.40, 10),
      ];
      final now = 36 * 60 * 1000; // now = exit + 16 min (>= noWalkFinalizeMs)

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
    });

    test('9. Transmitter gone: found at 12,14,16; not found at 18; EXIT 20 → time 18 (firstMiss), sources contain "Transmitter weg"', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        scan(12, 'transmitter', 'AA:BB:CC', found: true, rssi: -50),
        scan(14, 'transmitter', 'AA:BB:CC', found: true, rssi: -55),
        scan(16, 'transmitter', 'AA:BB:CC', found: true, rssi: -60),
        scan(18, 'transmitter', 'AA:BB:CC', found: false),
        act(20, 'IN_VEHICLE', 'EXIT'),
        act(21, 'WALKING', 'ENTER'),
        loc(19, 52.52, 13.40, 10),
      ];
      final now = 25 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      final spot = spots[0];
      expect(spot.time, 18 * 60 * 1000);
      expect(spot.sources.contains('Transmitter weg'), true);
    });

    test('10. Transmitter gone + EXIT in interval (16,18]: EXIT 17 → time 17', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        scan(12, 'transmitter', 'AA:BB:CC', found: true, rssi: -50),
        scan(14, 'transmitter', 'AA:BB:CC', found: true, rssi: -55),
        scan(16, 'transmitter', 'AA:BB:CC', found: true, rssi: -60),
        scan(18, 'transmitter', 'AA:BB:CC', found: false),
        act(17, 'IN_VEHICLE', 'EXIT'),
        loc(17, 52.52, 13.40, 10),
      ];
      final now = 25 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      expect(spots[0].time, 17 * 60 * 1000);
    });

    test('11. Charger cable: plugged true (initial) at 1, false (change) at 19, EXIT 20 → time 19, sources contain "Ladekabel ab"', () {
      final events = [
        power(1, true, reason: 'initial'),
        act(0, 'IN_VEHICLE', 'ENTER'),
        power(19, false, reason: 'change'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        loc(19, 52.52, 13.40, 10),
      ];
      final now = 25 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      final spot = spots[0];
      expect(spot.time, 19 * 60 * 1000);
      expect(spot.sources, ['Aussteigen', 'Ladekabel ab']);
    });

    test('12. Charger off mid-trip (min 5) and back on 6, off 19 → time 19', () {
      final events = [
        power(1, true, reason: 'initial'),
        act(0, 'IN_VEHICLE', 'ENTER'),
        power(5, false, reason: 'change'),
        power(6, true),
        power(19, false, reason: 'change'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        loc(19, 52.52, 13.40, 10),
      ];
      final now = 25 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      expect(spots[0].time, 19 * 60 * 1000);
    });

    test('13. pickLocation: closer inaccurate vs. later accurate (score)', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        loc(19, 52.51, 13.39, 50), // Inaccurate, close in time
        loc(21, 52.52, 13.40, 5),  // Accurate, later
        act(21, 'WALKING', 'ENTER'),
      ];
      final now = 30 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      // The better score should win (accuracy matters more at small time differences)
      final spot = spots[0];
      expect(spot.acc, lessThan(30)); // Should pick the accurate one
    });

    test('14. No location within 10 min → no parking spot', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        loc(5, 52.52, 13.40, 10),  // Too far before
        loc(35, 52.52, 13.40, 10), // Too far after
      ];
      final now = 40 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 0);
    });

    test('15. Manual event → parking spot manual-..., source "Manuell (Widget)"', () {
      final events = [
        manual(10, 52.52, 13.40, 25, source: 'widget'),
      ];
      final now = 15 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 1);
      final spot = spots[0];
      expect(spot.id, startsWith('manual-'));
      expect(spot.sources, ['Manuell (Widget)']);
      expect(spot.manual, true);
    });

    test('16. Two consecutive trips (with walking) → two parking spots', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
        act(21, 'WALKING', 'ENTER'),
        act(60, 'IN_VEHICLE', 'ENTER'),
        act(80, 'IN_VEHICLE', 'EXIT'),
        act(81, 'WALKING', 'ENTER'),
        loc(20, 52.52, 13.40, 10),
        loc(80, 52.53, 13.41, 10),
      ];
      final now = 90 * 60 * 1000;

      final spots = detectParkings(events, now);

      expect(spots.length, 2);
    });
  });

  group('Trip functionality', () {
    test('tripInProgress returns true for active trip', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
      ];
      final now = 10 * 60 * 1000;

      final inProgress = tripInProgress(events, now);

      expect(inProgress, true);
    });

    test('tripInProgress returns false when no active trip', () {
      final events = [
        act(0, 'IN_VEHICLE', 'ENTER'),
        act(20, 'IN_VEHICLE', 'EXIT'),
      ];
      final now = 25 * 60 * 1000;

      final inProgress = tripInProgress(events, now);

      expect(inProgress, false);
    });
  });
}
