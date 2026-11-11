import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

/// Wie streng Leerseiten erkannt werden (Anteil „dunkler" Pixel, unter dem
/// eine Seite als leer gilt).
enum BlankSensitivity {
  /// Nur wirklich leere Blätter — eine Seite mit nur einer Unterschrift
  /// bleibt sicher erhalten.
  careful('Vorsichtig', 0.0002),
  normal('Normal', 0.0005),

  /// Auch Seiten mit Staub, Falten oder leichten Flecken.
  generous('Großzügig', 0.0015);

  final String label;
  final double inkThreshold;
  const BlankSensitivity(this.label, this.inkThreshold);
}

/// Was mit leeren Seiten beim Scannen passiert.
enum BlankMode {
  /// Leeres Blatt trennt Dokumente, leere Seiten werden gelöscht.
  splitAndDelete('Trennen & löschen',
      'Ein leeres Blatt trennt die Dokumente, leere Seiten werden gelöscht'),

  /// Alles bleibt ein Dokument, nur leere Seiten fliegen raus (z. B. leere
  /// Rückseiten).
  deleteOnly('Nur löschen',
      'Alles bleibt ein Dokument, nur leere Seiten werden entfernt'),

  /// Nichts erkennen: alle Seiten bleiben, wie gescannt.
  off('Aus', 'Alle Seiten bleiben, auch leere');

  final String label;
  final String description;
  const BlankMode(this.label, this.description);

  bool get detect => this != off;
  bool get split => this == splitAndDelete;
}

/// Einstellungen für die Leerseiten-Erkennung beim Scannen.
class BlankPageSettings {
  static const _modeKey = 'blank_pages_mode';
  static const _enabledKey = 'blank_pages_enabled'; // alte Ein/Aus-Einstellung
  static const _sensitivityKey = 'blank_pages_sensitivity';

  static Future<BlankMode> mode() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_modeKey);
    if (name != null) {
      return BlankMode.values.firstWhere((m) => m.name == name,
          orElse: () => BlankMode.splitAndDelete);
    }
    // Übernahme aus früheren Versionen (nur ein/aus).
    return (p.getBool(_enabledKey) ?? true)
        ? BlankMode.splitAndDelete
        : BlankMode.off;
  }

  static Future<void> setMode(BlankMode mode) async =>
      (await SharedPreferences.getInstance()).setString(_modeKey, mode.name);

  static Future<BlankSensitivity> sensitivity() async {
    final name =
        (await SharedPreferences.getInstance()).getString(_sensitivityKey);
    return BlankSensitivity.values.firstWhere(
      (s) => s.name == name,
      orElse: () => BlankSensitivity.normal,
    );
  }

  static Future<void> setSensitivity(BlankSensitivity value) async =>
      (await SharedPreferences.getInstance())
          .setString(_sensitivityKey, value.name);
}

/// Breite, auf die Seiten für die Prüfung verkleinert werden. Reicht, um
/// eine einzelne Textzeile noch zu erkennen, und ist auch bei 12-MP-Scans
/// schnell (der Decoder skaliert direkt beim Laden).
const blankCheckWidth = 400;

/// Rand, der bei der Prüfung ignoriert wird (Schatten, Kanten).
const blankMarginFraction = 0.08;

/// Ein Pixel zählt als Tinte, wenn es um mehr als diesen Wert dunkler ist
/// als das Papier.
const blankInkDelta = 40;

/// Ist das Papier dunkler als das, ist es kein weißes Blatt (Foto, farbige
/// Fläche) — nie als leer werten.
const blankMinPaperLuma = 150;

/// Prüft eine Graustufen-Seite (0–255 je Pixel, zeilenweise) auf „leer".
///
/// Papierhelligkeit = 75. Perzentil der Helligkeit (Text überdeckt nie mehr
/// als ein Viertel einer Seite). Tinte = Pixel deutlich dunkler als Papier.
/// So bleiben gelbliches Papier und Randschatten unschädlich.
bool isBlankGray(
  Uint8List gray,
  int width,
  int height, {
  double inkThreshold = 0.0005,
}) {
  final mx = (width * blankMarginFraction).floor();
  final my = (height * blankMarginFraction).floor();
  if (width - 2 * mx <= 0 || height - 2 * my <= 0) return false;

  final histogram = List<int>.filled(256, 0);
  var total = 0;
  for (var y = my; y < height - my; y++) {
    final row = y * width;
    for (var x = mx; x < width - mx; x++) {
      histogram[gray[row + x]]++;
      total++;
    }
  }

  final target = (total * 0.75).ceil();
  var seen = 0;
  var paper = 255;
  for (var v = 0; v < 256; v++) {
    seen += histogram[v];
    if (seen >= target) {
      paper = v;
      break;
    }
  }
  if (paper < blankMinPaperLuma) return false;

  final limit = paper - blankInkDelta;
  var dark = 0;
  for (var v = 0; v < limit && v < 256; v++) {
    dark += histogram[v];
  }
  return dark / total < inkThreshold;
}

/// Prüft eine Bilddatei auf „leer". Im Zweifel (Lesefehler) gilt die Seite
/// als **nicht** leer — es darf nie ein Inhalt verloren gehen.
Future<bool> isBlankImageFile(
  String path, {
  double inkThreshold = 0.0005,
}) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: blankCheckWidth);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    codec.dispose();
    if (data == null) return false;

    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final gray = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final o = i * 4;
      gray[i] = (rgba[o] * 299 + rgba[o + 1] * 587 + rgba[o + 2] * 114) ~/ 1000;
    }
    return isBlankGray(gray, w, h, inkThreshold: inkThreshold);
  } catch (_) {
    return false;
  }
}

/// Teilt Seiten (0-basierte Indizes) an Leerseiten in Dokumente. Leerseiten
/// selbst kommen in keinem Dokument vor; mehrere hintereinander zählen als
/// ein einziger Trenner. Ist [split] false, bleibt alles ein Dokument (nur
/// ohne die Leerseiten).
List<List<int>> groupPagesAtBlanks(List<bool> blank, {bool split = true}) {
  final groups = <List<int>>[];
  var current = <int>[];
  for (var i = 0; i < blank.length; i++) {
    if (blank[i]) {
      if (split && current.isNotEmpty) {
        groups.add(current);
        current = <int>[];
      }
    } else {
      current.add(i);
    }
  }
  if (current.isNotEmpty) groups.add(current);
  return groups;
}

/// Wie [groupPagesAtBlanks], aber für doppelseitig gescannte Stapel: Die
/// Seiten kommen als Paare (Vorder-/Rückseite je Blatt). Nur ein Blatt, das
/// auf **beiden** Seiten leer ist, trennt Dokumente. Eine leere Rückseite
/// (einseitig bedrucktes Blatt) wird nur entfernt, das Dokument läuft weiter.
/// So lassen sich ein- und doppelseitige Blätter beliebig mischen.
List<List<int>> groupDuplexAtBlankSheets(List<bool> blank, {bool split = true}) {
  final groups = <List<int>>[];
  var current = <int>[];
  for (var sheet = 0; sheet * 2 < blank.length; sheet++) {
    final front = sheet * 2;
    final back = front + 1;
    final frontBlank = blank[front];
    final backBlank = back >= blank.length || blank[back];
    if (frontBlank && backBlank) {
      if (split && current.isNotEmpty) {
        groups.add(current);
        current = <int>[];
      }
      continue;
    }
    if (!frontBlank) current.add(front);
    if (back < blank.length && !blank[back]) current.add(back);
  }
  if (current.isNotEmpty) groups.add(current);
  return groups;
}
