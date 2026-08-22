import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Ablage für Fotos, die an Maßnahmen hängen.
///
/// Gespeichert wird nur der Dateiname, nicht der vollständige Pfad: Das
/// App-Verzeichnis bekommt bei iOS-Updates eine neue UUID, gespeicherte
/// absolute Pfade zeigen danach ins Leere.
class PhotoStorage {
  static const String _folder = 'hive_photos';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Kopiert [sourcePath] in die App-Ablage und liefert den Dateinamen.
  static Future<String> save(String sourcePath) async {
    final dir = await _dir();
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final name = '${const Uuid().v4()}$ext';
    await File(sourcePath).copy(p.join(dir.path, name));
    return name;
  }

  /// Vollständiger Pfad zu einem gespeicherten Dateinamen.
  static Future<String> resolve(String fileName) async {
    final dir = await _dir();
    return p.join(dir.path, fileName);
  }

  /// Vollständige Pfade zu mehreren Dateinamen, in derselben Reihenfolge.
  static Future<List<String>> resolveAll(List<String> fileNames) async {
    if (fileNames.isEmpty) return const [];
    final dir = await _dir();
    return [for (final n in fileNames) p.join(dir.path, n)];
  }

  /// Löscht ein gespeichertes Foto. Fehlt die Datei, passiert nichts.
  static Future<void> delete(String fileName) async {
    try {
      final file = File(await resolve(fileName));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ein nicht löschbares Foto darf das Speichern nicht verhindern.
    }
  }
}
