import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/logic/models.dart';
import 'package:parkplatz_merker/logic/spots.dart';

void main() {
  group('Spots Merge Tests', () {
    test('Note and photo stay on update', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
          note: 'Parkhaus Ebene 3',
          photoPath: '/path/to/photo.jpg',
        ),
      ];

      final detected = [
        ParkingSpot(
          id: 'auto-100',
          time: 101000, // Updated time
          lat: 52.52,
          lng: 13.40,
          acc: 9,
          sources: ['Aussteigen', 'Transmitter weg'],
          manual: false,
        ),
      ];

      final merged = mergeSpots(existing, detected, {});

      expect(merged.length, 1);
      expect(merged[0].note, 'Parkhaus Ebene 3');
      expect(merged[0].photoPath, '/path/to/photo.jpg');
      expect(merged[0].time, 101000);
    });

    test('Deleted IDs never added', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final detected = [
        ParkingSpot(
          id: 'auto-200',
          time: 200000,
          lat: 52.53,
          lng: 13.41,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final deletedIds = {'auto-200'};

      final merged = mergeSpots(existing, detected, deletedIds);

      expect(merged.length, 1);
      expect(merged[0].id, 'auto-100');
    });

    test('Max 30 entries', () {
      final existing = <ParkingSpot>[];
      for (int i = 0; i < 40; i++) {
        existing.add(ParkingSpot(
          id: 'auto-$i',
          time: i * 1000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ));
      }

      final merged = mergeSpots(existing, [], {});

      expect(merged.length, 30);
    });

    test('Sorted by time descending', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
        ParkingSpot(
          id: 'auto-200',
          time: 200000,
          lat: 52.53,
          lng: 13.41,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final merged = mergeSpots(existing, [], {});

      expect(merged[0].time, 200000);
      expect(merged[1].time, 100000);
    });

    test('Address cleared on position change', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
          address: 'Hauptstraße 5, 12345 Berlin',
        ),
      ];

      final detected = [
        ParkingSpot(
          id: 'auto-100',
          time: 101000,
          lat: 52.53, // Changed lat
          lng: 13.41, // Changed lng
          acc: 9,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final merged = mergeSpots(existing, detected, {});

      expect(merged.length, 1);
      expect(merged[0].address, null);
    });

    test('Address kept on position unchanged', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
          address: 'Hauptstraße 5, 12345 Berlin',
        ),
      ];

      final detected = [
        ParkingSpot(
          id: 'auto-100',
          time: 101000,
          lat: 52.52, // Same
          lng: 13.40, // Same
          acc: 9,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final merged = mergeSpots(existing, detected, {});

      expect(merged.length, 1);
      expect(merged[0].address, 'Hauptstraße 5, 12345 Berlin');
    });

    test('Existing spot kept if not detected', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final detected = <ParkingSpot>[];

      final merged = mergeSpots(existing, detected, {});

      expect(merged.length, 1);
      expect(merged[0].id, 'auto-100');
    });

    test('New spots added', () {
      final existing = [
        ParkingSpot(
          id: 'auto-100',
          time: 100000,
          lat: 52.52,
          lng: 13.40,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final detected = [
        ParkingSpot(
          id: 'auto-200',
          time: 200000,
          lat: 52.53,
          lng: 13.41,
          acc: 10,
          sources: ['Aussteigen'],
          manual: false,
        ),
      ];

      final merged = mergeSpots(existing, detected, {});

      expect(merged.length, 2);
      final ids = merged.map((s) => s.id).toList();
      expect(ids.contains('auto-100'), true);
      expect(ids.contains('auto-200'), true);
    });
  });
}
