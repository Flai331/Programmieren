import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/data/batch_numbering.dart';
import 'package:dokubox/reports/number_list_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nach Datum, ältestes zuerst; ohne Datum ans Ende; stabil', () {
    final docs = [
      ('Rechnung März', DateTime(2026, 3, 10)),
      ('ohne Datum 1', null),
      ('Bescheid Januar', DateTime(2026, 1, 5)),
      ('Brief März (gleicher Tag, später im Stapel)', DateTime(2026, 3, 10, 18)),
      ('ohne Datum 2', null),
      ('Vorjahr', DateTime(2025, 12, 31)),
    ];
    final sorted = sortForNumbering(docs, (d) => d.$2).map((d) => d.$1);
    expect(sorted, [
      'Vorjahr',
      'Bescheid Januar',
      'Rechnung März',
      'Brief März (gleicher Tag, später im Stapel)',
      'ohne Datum 1',
      'ohne Datum 2',
    ]);
  });

  test('leer und ein Element', () {
    expect(sortForNumbering(<int>[], (_) => null), isEmpty);
    expect(sortForNumbering([1], (_) => null), [1]);
  });

  test('Nummernliste als PDF (mit und ohne Vorschaubild, Umlaute)', () async {
    // 1×1-PNG
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC');
    final rows = [
      for (var i = 1; i <= 25; i++)
        NumberListRow(
          docNumber: '2026-${i.toString().padLeft(4, '0')}',
          docDate: i.isEven ? DateTime(2026, 1, i) : null,
          sender: 'Größenwahn & Söhne GmbH',
          title: 'Beitragsrechnung – 12,50 €',
          thumbnail: i % 3 == 0 ? Uint8List.fromList(png) : null,
        ),
    ];
    final bytes = await buildNumberListPdf(rows,
        font: ByteData.sublistView(
            File('assets/fonts/DejaVuSans.ttf').readAsBytesSync()),
        created: DateTime(2026, 11, 11));
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.startsWith('%PDF'), isTrue);
    // 25 Einträge passen nicht auf eine Seite → mehrere Seiten.
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length,
        greaterThan(1));
  });
}
