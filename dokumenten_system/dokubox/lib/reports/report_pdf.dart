import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final _date = DateFormat('dd.MM.yyyy');

/// Gemeinsamer Rahmen für Ausdrucke (Box-Liste, Vernichtungs-Protokoll,
/// Steuer-Deckblatt, Deckblatt …): A4, Kopf mit Titel, Fuß mit Datum und
/// Seitenzahl, DejaVu-Schrift für Umlaute/€.
Future<Uint8List> buildReport({
  required String title,
  String subtitle = '',
  required List<pw.Widget> Function() content,
  ByteData? font,
  DateTime? created,
}) async {
  created ??= DateTime.now();
  final doc = pw.Document(
    title: title,
    creator: 'DokuBox',
    theme: font == null ? null : pw.ThemeData.withFont(base: pw.Font.ttf(font)),
  );
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    header: (_) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
            if (subtitle.isNotEmpty)
              pw.Text(subtitle,
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
          pw.Text('DokuBox', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    ),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Erstellt am ${_date.format(created!)}',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (_) => content(),
  ));
  return doc.save();
}

/// Einfache Tabelle mit Kopfzeile.
pw.Widget reportTable(List<String> headers, List<List<String>> rows,
        {Map<int, pw.TableColumnWidth>? widths}) =>
    pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: widths,
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );

String reportDate(DateTime? d) => d == null ? '–' : _date.format(d);
