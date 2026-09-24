import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/logic/format.dart';
import 'package:parkplatz_merker/logic/models.dart';

void main() {
  group('Format Tests', () {
    test('sinceText: same day → "seit HH:MM"', () {
      final parked = DateTime(2026, 9, 24, 14, 32);
      final now = DateTime(2026, 9, 24, 15, 45);

      final result = sinceText(parked, now);

      expect(result, 'seit 14:32');
    });

    test('sinceText: yesterday → "seit gestern, HH:MM"', () {
      final parked = DateTime(2026, 9, 23, 14, 32);
      final now = DateTime(2026, 9, 24, 15, 45);

      final result = sinceText(parked, now);

      expect(result, 'seit gestern, 14:32');
    });

    test('sinceText: older → "seit Mo., TT.MM., HH:MM"', () {
      final parked = DateTime(2026, 9, 22, 14, 32); // Dienstag
      final now = DateTime(2026, 9, 24, 15, 45);

      expect(sinceText(parked, now), 'seit Di., 22.09., 14:32');
      expect(sinceText(DateTime(2026, 9, 21, 8, 5), now), 'seit Mo., 21.09., 08:05');
    });

    test('formatDistance: < 100 m, rounded to 5 m', () {
      expect(formatDistance(47.0), '45 m');
      expect(formatDistance(53.0), '55 m');
    });

    test('formatDistance: 100-999 m, rounded to 10 m', () {
      expect(formatDistance(345.0), '350 m');
      expect(formatDistance(354.0), '350 m');
    });

    test('formatDistance: >= 1000 m, in km with comma', () {
      expect(formatDistance(1200.0), '1,2 km');
      expect(formatDistance(1500.0), '1,5 km');
    });

    test('haversine: known distance ±1%', () {
      // Berlin: two points about 2 km apart
      final distance = haversineMeters(52.5200, 13.4050, 52.5100, 13.3800);

      // Should be around 2000-3000 meters
      expect(distance, greaterThan(1500));
      expect(distance, lessThan(3500));
    });

    test('formatClock: formats time correctly', () {
      final dt = DateTime(2026, 9, 24, 14, 32, 45);

      final result = formatClock(dt);

      expect(result, '14:32');
    });

    test('accuracyText: formats accuracy', () {
      final result = accuracyText(12.7);

      expect(result, 'Genauigkeit ± 13 m');
    });

    test('formatDateTime: formats date and time', () {
      final dt = DateTime(2026, 9, 22, 14, 32);

      final result = formatDateTime(dt);

      expect(result, '22.09. 14:32');
    });

    test('headline: generates correct text', () {
      final spot = ParkingSpot(
        id: 'auto-100',
        time: DateTime(2026, 9, 24, 14, 32).millisecondsSinceEpoch,
        lat: 52.52,
        lng: 13.40,
        acc: 10,
        sources: ['Aussteigen'],
        manual: false,
      );
      final now = DateTime(2026, 9, 24, 15, 45);

      final result = headline(spot, now);

      expect(result, 'Dein Auto steht seit 14:32 hier');
    });
  });
}
