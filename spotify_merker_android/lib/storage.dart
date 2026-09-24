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
}
