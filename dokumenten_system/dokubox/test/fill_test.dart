import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/fill/fill_export.dart';
import 'package:dokubox/fill/fill_model.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1-PNG (weiß) als Seiten-Hintergrund bzw. Vorlage.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC');

void main() {
  group('FillDocument', () {
    test('speichern und wieder laden (JSON)', () {
      final doc = FillDocument([
        FillItem(
            kind: FillKind.text,
            page: 0,
            x: 0.1,
            y: 0.2,
            text: 'Max Müller\nHauptstr. 1',
            color: kFillColors[1]),
        FillItem(kind: FillKind.check, page: 1, x: 0.5, y: 0.5),
        FillItem(
            kind: FillKind.image,
            page: 1,
            x: 0.6,
            y: 0.8,
            templateId: 'sig-1',
            aspect: 0.4),
      ]);
      final back = FillDocument.decode(doc.encode());
      expect(back.items.length, 3);
      expect(back.items[0].text, 'Max Müller\nHauptstr. 1');
      expect(back.items[0].color, kFillColors[1]);
      expect(back.items[0].id, doc.items[0].id);
      expect(back.onPage(1).map((i) => i.kind),
          [FillKind.check, FillKind.image]);
      expect(back.items[2].templateId, 'sig-1');
      expect(back.items[2].aspect, 0.4);
    });

    test('kaputte oder leere Daten ergeben ein leeres Formular', () {
      expect(FillDocument.decode(null).items, isEmpty);
      expect(FillDocument.decode('').items, isEmpty);
      expect(FillDocument.decode('{kaputt').items, isEmpty);
      expect(
          FillDocument.decode('{"items":[{"kind":"unbekannt"}]}').items, isEmpty);
    });

    test('Größe wird begrenzt, Position auf die Seite', () {
      expect(FillItem(kind: FillKind.text, page: 0, x: 0, y: 0, size: 5).size,
          clampSize(FillKind.text, 5));
      expect(clampSize(FillKind.image, 0), greaterThan(0));
      final item = FillItem.fromJson(
          {'kind': 'check', 'page': 0, 'x': 3.0, 'y': -1.0})!;
      expect([item.x, item.y], [1.0, 0.0]);
    });
  });

  test('Rückgängig stellt frühere Zustände wieder her', () {
    final history = FillHistory();
    var doc = FillDocument();
    expect(history.canUndo, isFalse);

    history.remember(doc);
    doc.items.add(FillItem(kind: FillKind.text, page: 0, x: 0, y: 0, text: 'A'));
    history.remember(doc);
    doc.items.first.x = 0.5;

    doc = history.undo()!;
    expect(doc.items.single.x, 0);
    doc = history.undo()!;
    expect(doc.items, isEmpty);
    expect(history.undo(), isNull);
  });

  test('pngSize liest Breite/Höhe aus dem Kopf', () {
    expect(pngSize(Uint8List.fromList(_png)), (width: 1, height: 1));
    expect(pngSize(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('ausgefüllte PDF enthält alle Seiten und die Eintragungen', () async {
    final pages = [
      PageBackground(_png, 595, 842),
      PageBackground(_png, 595, 842),
    ];
    final fill = FillDocument([
      FillItem(
          kind: FillKind.text, page: 0, x: 0.1, y: 0.1, text: 'Größe: 12 €'),
      FillItem(kind: FillKind.check, page: 0, x: 0.2, y: 0.3),
      FillItem(kind: FillKind.cross, page: 1, x: 0.2, y: 0.3),
      FillItem(
          kind: FillKind.image, page: 1, x: 0.5, y: 0.8, templateId: 'sig'),
      // Fehlende Vorlage wird ausgelassen statt abzustürzen.
      FillItem(
          kind: FillKind.image, page: 1, x: 0.5, y: 0.5, templateId: 'weg'),
    ]);
    final font = ByteData.sublistView(
        File('assets/fonts/DejaVuSans.ttf').readAsBytesSync());
    final bytes = await buildFilledPdf(
      pages: pages,
      fill: fill,
      templateImages: {'sig': _png},
      font: font,
    );
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 2);
  });
}
