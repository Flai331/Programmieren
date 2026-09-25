import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'logic.dart';

class Storage {
  static Future<File> get _historyFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/history.json');
  }

  static Future<List<Entry>> loadHistory() async {
    try {
      final file = await _historyFile;
      if (!file.existsSync()) {
        return [];
      }

      final content = file.readAsStringSync();
      if (content.isEmpty) {
        return [];
      }

      final jsonData = jsonDecode(content) as List;
      return jsonData
          .map((item) => Entry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading history: $e');
      return [];
    }
  }

  static Future<void> saveHistory(List<Entry> history) async {
    try {
      final file = await _historyFile;
      final dir = file.parent;

      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final tmpFile = File('${dir.path}/history.json.tmp');
      final jsonData = history.map((e) => e.toJson()).toList();
      final content = jsonEncode(jsonData);

      tmpFile.writeAsStringSync(content);

      // Atomic rename
      if (file.existsSync()) {
        file.deleteSync();
      }
      tmpFile.renameSync(file.path);
    } catch (e) {
      // ignore: avoid_print
      print('Error saving history: $e');
      rethrow;
    }
  }

  static Future<void> exportHistory(List<Entry> history) async {
    try {
      final jsonData = history.map((e) => e.toJson()).toList();
      final content = jsonEncode(jsonData);

      await Share.shareXFiles([
        XFile.fromData(
          utf8.encode(content),
          mimeType: 'application/json',
          name: 'spotify-merker-export.json',
        ),
      ], text: 'Spotify-Merker Verlauf Export');
    } catch (e) {
      // ignore: avoid_print
      print('Error exporting history: $e');
      rethrow;
    }
  }

  static Future<void> clearHistory() async {
    try {
      final file = await _historyFile;
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error clearing history: $e');
      rethrow;
    }
  }

  static Future<File> get _activityFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/activity.json');
  }

  static Future<List<ActivityEvent>> loadActivity() async {
    try {
      final file = await _activityFile;
      if (!file.existsSync()) {
        return [];
      }

      final content = file.readAsStringSync();
      if (content.isEmpty) {
        return [];
      }

      final jsonData = jsonDecode(content) as List;
      return jsonData
          .map((item) => ActivityEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading activity: $e');
      return [];
    }
  }

  static Future<void> saveActivity(List<ActivityEvent> activity) async {
    try {
      final file = await _activityFile;
      final dir = file.parent;

      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final tmpFile = File('${dir.path}/activity.json.tmp');
      final jsonData = activity.map((e) => e.toJson()).toList();
      final content = jsonEncode(jsonData);

      tmpFile.writeAsStringSync(content);

      // Atomic rename
      if (file.existsSync()) {
        file.deleteSync();
      }
      tmpFile.renameSync(file.path);
    } catch (e) {
      // ignore: avoid_print
      print('Error saving activity: $e');
      rethrow;
    }
  }

  /// Zeitpunkt des zuletzt ausgeblendeten „Eingeschlafen?“-Vorschlags.
  static Future<File> get _dismissFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sleep_dismissed.txt');
  }

  static Future<int?> loadDismissedSleepAt() async {
    try {
      final f = await _dismissFile;
      if (!f.existsSync()) return null;
      return int.tryParse(f.readAsStringSync().trim());
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDismissedSleepAt(int ts) async {
    try {
      final f = await _dismissFile;
      f.writeAsStringSync('$ts');
    } catch (_) {}
  }

  static Future<File> get _sleepMarksFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sleep_marks.json');
  }

  /// Gefundene Einschlaf-Stellen (bleiben erhalten, auch wenn die
  /// Wachzeichen nach 14 Tagen gelöscht werden).
  static Future<List<SleepGuess>> loadSleepMarks() async {
    try {
      final f = await _sleepMarksFile;
      if (!f.existsSync()) return [];
      final data = jsonDecode(f.readAsStringSync()) as List;
      return [
        for (final m in data)
          SleepGuess.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSleepMarks(List<SleepGuess> marks) async {
    try {
      final f = await _sleepMarksFile;
      final tmp = File('${f.path}.tmp');
      tmp.writeAsStringSync(jsonEncode([for (final m in marks) m.toJson()]));
      tmp.renameSync(f.path);
    } catch (_) {}
  }
}
