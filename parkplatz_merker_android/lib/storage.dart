import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'logic/models.dart';

class Storage {
  late Directory _docsDir;
  late Directory _photosDir;

  Future<void> initialize() async {
    _docsDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${_docsDir.path}/photos');
    await _photosDir.create(recursive: true);
  }

  File _eventsFile() => File('${_docsDir.path}/events.json');
  File _spotsFile() => File('${_docsDir.path}/spots.json');
  File _deletedFile() => File('${_docsDir.path}/deleted.json');

  /// Lädt Rohereignisse aus dem Speicher (werden von der nativen Seite geleert).
  Future<List<RawEvent>> loadEvents() async {
    try {
      final file = _eventsFile();
      if (!await file.exists()) return [];

      final json = await file.readAsString();
      if (json.trim().isEmpty) return [];

      final list = jsonDecode(json) as List;
      final events = <RawEvent>[];

      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final event = RawEvent.fromJson(item);
          events.add(event);
        }
      }

      // Rohereignisse älter als 3 Tage und über 5000 verwerfen.
      final now = DateTime.now().millisecondsSinceEpoch;
      final threeDaysAgo = now - (3 * 24 * 60 * 60 * 1000);
      final filtered = events.where((e) => e.t > threeDaysAgo).toList();

      if (filtered.length > 5000) {
        return filtered.sublist(filtered.length - 5000);
      }

      return filtered;
    } catch (e) {
      print('loadEvents error: $e');
      return [];
    }
  }

  /// Speichert Rohereignisse atomar.
  Future<void> saveEvents(List<RawEvent> events) async {
    try {
      final file = _eventsFile();
      final json = jsonEncode(events.map((e) => e.toJson()).toList());
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(json);
      await tmpFile.rename(file.path);
    } catch (e) {
      print('saveEvents error: $e');
    }
  }

  /// Lädt Parkplätze aus dem Speicher.
  Future<List<ParkingSpot>> loadSpots() async {
    try {
      final file = _spotsFile();
      if (!await file.exists()) return [];

      final json = await file.readAsString();
      if (json.trim().isEmpty) return [];

      final list = jsonDecode(json) as List;
      final spots = <ParkingSpot>[];

      for (final item in list) {
        if (item is Map<String, dynamic>) {
          spots.add(ParkingSpot.fromJson(item));
        }
      }

      return spots;
    } catch (e) {
      print('loadSpots error: $e');
      return [];
    }
  }

  /// Speichert Parkplätze atomar.
  Future<void> saveSpots(List<ParkingSpot> spots) async {
    try {
      final file = _spotsFile();
      final json = jsonEncode(spots.map((s) => s.toJson()).toList());
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(json);
      await tmpFile.rename(file.path);
    } catch (e) {
      print('saveSpots error: $e');
    }
  }

  /// Lädt gelöschte IDs.
  Future<Set<String>> loadDeletedIds() async {
    try {
      final file = _deletedFile();
      if (!await file.exists()) return {};

      final json = await file.readAsString();
      if (json.trim().isEmpty) return {};

      final list = jsonDecode(json) as List;
      return Set<String>.from(list.cast<String>());
    } catch (e) {
      print('loadDeletedIds error: $e');
      return {};
    }
  }

  /// Speichert gelöschte IDs atomar.
  Future<void> saveDeletedIds(Set<String> ids) async {
    try {
      final file = _deletedFile();
      final json = jsonEncode(ids.toList());
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(json);
      await tmpFile.rename(file.path);
    } catch (e) {
      print('saveDeletedIds error: $e');
    }
  }

  /// Speichert ein Foto für einen Parkplatz.
  Future<String?> savePhoto(String spotId, File photoFile) async {
    try {
      final photoPath = '${_photosDir.path}/$spotId.jpg';
      await photoFile.copy(photoPath);
      return photoPath;
    } catch (e) {
      print('savePhoto error: $e');
      return null;
    }
  }

  /// Löscht das Foto eines Parkplatzes.
  Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null) return;
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('deletePhoto error: $e');
    }
  }
}
