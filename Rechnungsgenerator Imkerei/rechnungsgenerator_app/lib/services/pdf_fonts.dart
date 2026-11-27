import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Die Schriften für alle PDFs — aus dem Paket, nicht aus dem Netz.
///
/// Vorher stand an jeder PDF-Stelle `PdfGoogleFonts.robotoRegular()`. Das
/// sieht nach einer eingebauten Schrift aus, lädt aber bei jedem Aufruf von
/// fonts.gstatic.com: die URL steht wörtlich im printing-Paket. Und der
/// Zwischenspeicher dort ist `PdfMemoryCache`, also nach jedem App-Start
/// leer. Drei Downloads je Rechnung, ohne Zeitgrenze — bei schlechtem
/// Empfang wartet die App, bis Android aufgibt.
///
/// Geladen wird ausdrücklich über [rootBundle] und nicht über die
/// Asset-Abkürzung, die `PdfGoogleFonts` selbst kennt: die fällt bei einem
/// Tippfehler im Pfad stillschweigend auf den Download zurück, und genau
/// das soll hier niemandem mehr passieren. `rootBundle.load` wirft
/// stattdessen, und `test/assets_test.dart` hält Pfade und Dateien
/// zusammen.
///
/// Die geladenen Schriften werden gemerkt — eine [Future] je Schnitt, nicht
/// die fertige Schrift, damit zwei gleichzeitige PDFs die Datei auch nur
/// einmal lesen. Rund 500 KB bleiben dafür im Speicher; das ist der Preis
/// dafür, die TTF nicht bei jeder Rechnung neu zu zerlegen.
class PdfFonts {
  PdfFonts._();

  static const String _ordner = 'assets/fonts';

  /// Die Asset-Pfade, damit der Test sie nicht abschreiben muss.
  static const String regularAsset = '$_ordner/Roboto-Regular.ttf';
  static const String boldAsset = '$_ordner/Roboto-Bold.ttf';
  static const String italicAsset = '$_ordner/Roboto-Italic.ttf';
  static const String licenseAsset = '$_ordner/Roboto_LICENSE.txt';

  static Future<pw.Font>? _normal;
  static Future<pw.Font>? _fett;
  static Future<pw.Font>? _kursiv;

  static Future<pw.Font> regular() => _normal ??= _laden(regularAsset);
  static Future<pw.Font> bold() => _fett ??= _laden(boldAsset);
  static Future<pw.Font> italic() => _kursiv ??= _laden(italicAsset);

  /// Alle drei auf einmal, wie die PDF-Dienste sie brauchen.
  static Future<pw.ThemeData> theme() async => pw.ThemeData.withFont(
        base: await regular(),
        bold: await bold(),
        italic: await italic(),
      );

  static Future<pw.Font> _laden(String pfad) async {
    final daten = await rootBundle.load(pfad);
    return pw.Font.ttf(daten);
  }

  /// Nur für Tests: einen beliebigen Pfad laden, um zu zeigen, dass ein
  /// falscher Pfad wirft und nicht stillschweigend ins Netz ausweicht.
  @visibleForTesting
  static Future<pw.Font> loadForTests(String pfad) => _laden(pfad);

  /// Nur für Tests: die gemerkten Schriften vergessen, damit ein Test den
  /// ersten Ladevorgang beobachten kann.
  @visibleForTesting
  static void forgetForTests() {
    _normal = null;
    _fett = null;
    _kursiv = null;
  }
}
