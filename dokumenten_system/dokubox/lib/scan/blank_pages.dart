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

/// Einstellungen für die Leerseiten-Erkennung beim Scannen.
class BlankPageSettings {
  static const _enabledKey = 'blank_pages_enabled';
  static const _sensitivityKey = 'blank_pages_sensitivity';

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;

  static Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, value);

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
