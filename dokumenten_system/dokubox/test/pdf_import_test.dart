import 'package:dokubox/scan/pdf_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('textLayerUsable', () {
    test('leere Textebene (reiner Bild-Scan) → OCR nötig', () {
      expect(textLayerUsable(''), isFalse);
      expect(textLayerUsable('   \n\n  '), isFalse);
    });

    test('nur Seitenzahl oder Scanner-Stempel → OCR nötig', () {
      expect(textLayerUsable('Seite 1 von 2'), isFalse);
      expect(textLayerUsable('Scanned with HP 2026-11-09 08:15'), isFalse);
    });

    test('echter Brieftext wird übernommen', () {
      const brief = 'Techniker Krankenkasse · Postfach 12 34 · 22000 Hamburg\n'
          'Ihr Beitragsbescheid für das Jahr 2026';
      expect(textLayerUsable(brief), isTrue);
    });

    test('Umlaute und Ziffern zählen als Zeichen', () {
      expect(textLayerUsable('Ä' * 20 + '1' * 20), isTrue);
      expect(textLayerUsable('.' * 100), isFalse);
    });
  });
}
