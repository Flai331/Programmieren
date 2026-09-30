import 'dart:typed_data';

import 'package:dokubox/scan/blank_pages.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List page(int w, int h, int paper) =>
    Uint8List(w * h)..fillRange(0, w * h, paper);

void main() {
  group('groupPagesAtBlanks', () {
    test('trennt an Leerseiten', () {
      final g = groupPagesAtBlanks(
          [false, false, true, false, false, false, true, false]);
      expect(g, [
        [0, 1],
        [3, 4, 5],
        [7],
      ]);
    });

    test('mehrere Leerseiten sind ein Trenner', () {
      expect(groupPagesAtBlanks([false, true, true, true, false]), [
        [0],
        [4],
      ]);
    });

    test('Leerseiten am Anfang und Ende erzeugen keine leeren Dokumente', () {
      expect(groupPagesAtBlanks([true, false, false, true]), [
        [1, 2],
      ]);
    });

    test('nur Leerseiten ergibt keine Dokumente', () {
      expect(groupPagesAtBlanks([true, true]), isEmpty);
    });

    test('ohne Trennen bleibt es ein Dokument ohne die Leerseiten', () {
      expect(groupPagesAtBlanks([false, true, false], split: false), [
        [0, 2],
      ]);
    });
  });

  group('isBlankGray', () {
    const w = 400, h = 566;

    test('weißes Blatt ist leer', () {
      expect(isBlankGray(page(w, h, 245), w, h), isTrue);
    });

    test('gelbliches Papier mit Randschatten ist leer', () {
      final g = page(w, h, 225);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < 20; x++) {
          g[y * w + x] = 120; // Schatten im ignorierten Rand
        }
      }
      expect(isBlankGray(g, w, h), isTrue);
    });

    test('Seite mit einer Textzeile ist nicht leer', () {
      final g = page(w, h, 245);
      for (var y = 280; y < 284; y++) {
        for (var x = 60; x < 200; x++) {
          g[y * w + x] = 40;
        }
      }
      expect(isBlankGray(g, w, h), isFalse);
    });

    test('vereinzelte Staubkörner bleiben leer', () {
      final g = page(w, h, 245);
      for (final p in [
        [100, 150], [220, 300], [300, 400], [150, 480], [250, 200],
      ]) {
        g[p[1] * w + p[0]] = 90;
      }
      expect(isBlankGray(g, w, h), isTrue);
    });

    test('dunkle Fläche (Foto) ist nie leer', () {
      expect(isBlankGray(page(w, h, 60), w, h), isFalse);
    });

    test('Empfindlichkeit „vorsichtig" behält schwache Inhalte', () {
      final g = page(w, h, 245);
      for (var x = 100; x < 200; x++) {
        g[300 * w + x] = 40; // 100 Pixel ≈ 0,06 %
      }
      expect(
          isBlankGray(g, w, h,
              inkThreshold: BlankSensitivity.careful.inkThreshold),
          isFalse);
      expect(
          isBlankGray(g, w, h,
              inkThreshold: BlankSensitivity.generous.inkThreshold),
          isTrue);
    });
  });
}
