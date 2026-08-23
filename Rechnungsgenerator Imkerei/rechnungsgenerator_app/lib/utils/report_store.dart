import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'feedback_report.dart';

/// Lokale Ablage der Fehlerberichte.
///
/// Ein Bericht wird immer zuerst hier gespeichert und erst danach geteilt.
/// Bricht der Nutzer das Teilen ab oder gibt es keine passende App, ist der
/// Bericht trotzdem erhalten und kann später erneut geteilt werden.
///
/// Als einfache JSON-Dateien statt in der Datenbank: Berichte sollen auch
/// ein „Alle Daten löschen" überstehen und beim Untersuchen eines Absturzes
/// nicht von derselben Datenbank abhängen, die vielleicht gerade das Problem
/// ist.
class ReportStore {
  static const String _folder = 'feedback_reports';

  /// Verzeichnis für Tests überschreibbar.
  static Directory? _overrideDir;

  static void overrideDirectoryForTest(Directory? dir) => _overrideDir = dir;

  static Future<Directory> directory() async {
    final base = _overrideDir ??
        Directory(p.join((await getApplicationDocumentsDirectory()).path,
            _folder));
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  static File _fileFor(Directory dir, String id) =>
      File(p.join(dir.path, '$id.json'));

  /// Bericht speichern (neu oder aktualisiert).
  static Future<void> save(FeedbackReport report) async {
    final dir = await directory();
    await _fileFor(dir, report.id).writeAsString(report.toJsonString());
  }

  /// Alle Berichte, neueste zuerst. Unlesbare Dateien werden übersprungen –
  /// ein kaputter Bericht darf die Liste nicht unbrauchbar machen.
  static Future<List<FeedbackReport>> list() async {
    final dir = await directory();
    final reports = <FeedbackReport>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        reports.add(FeedbackReport.fromJsonString(await entity.readAsString()));
      } catch (_) {
        continue;
      }
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  static Future<FeedbackReport?> byId(String id) async {
    final dir = await directory();
    final file = _fileFor(dir, id);
    if (!await file.exists()) return null;
    try {
      return FeedbackReport.fromJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Bericht samt Bildern löschen.
  static Future<void> delete(String id) async {
    final dir = await directory();
    final report = await byId(id);
    for (final name in report?.photoNames ?? const <String>[]) {
      try {
        final bild = File(p.join(dir.path, name));
        if (await bild.exists()) await bild.delete();
      } catch (_) {
        // Ein nicht löschbares Bild darf das Löschen nicht verhindern.
      }
    }
    try {
      final file = _fileFor(dir, id);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> deleteAll() async {
    for (final r in await list()) {
      await delete(r.id);
    }
  }

  /// Bild in die Berichts-Ablage übernehmen und den Dateinamen liefern.
  ///
  /// Screenshots landen zunächst im temporären Verzeichnis, das das System
  /// jederzeit leeren darf.
  static Future<String?> adoptPhoto(String sourcePath, String reportId,
      int index) async {
    try {
      final dir = await directory();
      final ext = p.extension(sourcePath).isEmpty
          ? '.png'
          : p.extension(sourcePath);
      final name = '$reportId-$index$ext';
      await File(sourcePath).copy(p.join(dir.path, name));
      return name;
    } catch (_) {
      return null;
    }
  }

  /// Vollständige Pfade der Bilder eines Berichts, nur vorhandene Dateien.
  static Future<List<String>> photoPaths(FeedbackReport report) async {
    final dir = await directory();
    final pfade = <String>[];
    for (final name in report.photoNames) {
      final f = File(p.join(dir.path, name));
      if (await f.exists()) pfade.add(f.path);
    }
    return pfade;
  }

  /// Älteste Berichte entfernen, damit die Ablage nicht unbegrenzt wächst.
  static Future<void> pruneTo(int maxReports) async {
    final alle = await list();
    if (alle.length <= maxReports) return;
    for (final r in alle.skip(maxReports)) {
      await delete(r.id);
    }
  }
}
