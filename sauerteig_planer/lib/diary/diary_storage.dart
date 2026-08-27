import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diary_models.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY STORAGE
// ═══════════════════════════════════════════════════════════════

class DiaryStorage {
  static const _key = 'diary_entries';

  static Future<List<DiaryEntry>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      // Newest first
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (e, st) {
      debugPrint('DiaryStorage.loadAll error: $e\n$st');
      return [];
    }
  }

  static Future<void> save(DiaryEntry entry) async {
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.insert(0, entry);
    }
    await _persist(entries);
  }

  static Future<void> delete(DiaryEntry entry) async {
    // Foto löschen
    if (entry.photoPath != null) {
      await deletePhoto(entry.photoPath!);
    }
    final entries = await loadAll();
    entries.removeWhere((e) => e.id == entry.id);
    await _persist(entries);
  }

  static Future<void> _persist(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Kopiert Foto ins App-Dokumentenverzeichnis und gibt neuen Pfad zurück.
  static Future<String?> savePhoto(String sourcePath) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/diary_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = File('${photosDir.path}/$fileName');
      await File(sourcePath).copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> deletePhoto(String path) async {
    if (kIsWeb) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
