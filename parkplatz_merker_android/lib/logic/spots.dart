import 'models.dart';

/// Vereinigt existierende und erkannte Parkplätze.
List<ParkingSpot> mergeSpots(
  List<ParkingSpot> existing,
  List<ParkingSpot> detected,
  Set<String> deletedIds, {
  int max = 30,
}) {
  final result = <ParkingSpot>[];

  // IDs in deletedIds ignorieren
  final existingFiltered = existing.where((s) => !deletedIds.contains(s.id)).toList();

  // Erkannte Spots zusammenführen
  final merged = <String, ParkingSpot>{};
  for (final spot in existingFiltered) {
    merged[spot.id] = spot;
  }

  for (final detectedSpot in detected) {
    if (deletedIds.contains(detectedSpot.id)) continue;

    if (merged.containsKey(detectedSpot.id)) {
      // Existierende ID + erkannter Eintrag
      final existingSpot = merged[detectedSpot.id]!;

      // Adresse nur behalten, wenn lat/lng gleich geblieben sind
      final shouldClearAddress = existingSpot.address != null &&
          (existingSpot.lat != detectedSpot.lat || existingSpot.lng != detectedSpot.lng);

      final updatedSpot = existingSpot.copyWith(
        time: detectedSpot.time,
        lat: detectedSpot.lat,
        lng: detectedSpot.lng,
        acc: detectedSpot.acc,
        sources: detectedSpot.sources,
        clearAddress: shouldClearAddress,
      );

      merged[detectedSpot.id] = updatedSpot;
    } else {
      // Neue ID hinzufügen
      merged[detectedSpot.id] = detectedSpot;
    }
  }

  result.addAll(merged.values);

  // Nach time absteigend sortieren
  result.sort((a, b) => b.time.compareTo(a.time));

  // Auf max kürzen
  if (result.length > max) {
    return result.sublist(0, max);
  }

  return result;
}
