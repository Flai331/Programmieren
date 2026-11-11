import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Eine Zeile der Nummernliste.
class NumberListRow {
  final String docNumber;

  /// Vorläufige Nummer aus der Ersterfassung (V-0012), falls vorhanden.
  final String? oldNumber;
  final DateTime? docDate;
  final String sender;
  final String title;

  /// Kleines Bild der ersten Seite (JPEG/PNG) oder null.
  final Uint8List? thumbnail;

  const NumberListRow({
    required this.docNumber,
    this.oldNumber,
    this.docDate,
    this.sender = '',
    this.title = '',
    this.thumbnail,
  });
}

final _date = DateFormat('dd.MM.yyyy');

/// PDF „Nummern aufs Original schreiben“: je Dokument Vorschaubild, große
/// Nummer, Datum, Absender, Titel – zum Abhaken beim Beschriften.
Future<Uint8List> buildNumberListPdf(List<NumberListRow> rows,
    {ByteData? font, DateTime? created}) async {
  final doc = pw.Document(
    title: 'Nummernliste',
    creator: 'DokuBox',
    theme: font == null ? null : pw.ThemeData.withFont(base: pw.Font.ttf(font)),
  );
  created ??= DateTime.now();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Nummern aufs Original schreiben',
                style: const pw.TextStyle(fontSize: 16)),
            pw.Text('${rows.length} Dokumente · ${_date.format(created!)}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (_) => [
        for (final r in rows)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 14,
                  height: 14,
                  margin: const pw.EdgeInsets.only(right: 8, top: 4),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey700)),
                ),
                pw.SizedBox(
                  width: 56,
                  height: 78,
                  child: r.thumbnail == null
                      ? pw.Container(color: PdfColors.grey200)
                      : pw.Image(pw.MemoryImage(r.thumbnail!),
                          fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        pw.Text(r.docNumber,
                            style: pw.TextStyle(
                                fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        if (r.oldNumber != null)
                          pw.Text('   (war ${r.oldNumber})',
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey700)),
                      ]),
                      pw.SizedBox(height: 2),
                      pw.Text([
                        r.docDate == null ? 'ohne Datum' : _date.format(r.docDate!),
                        if (r.sender.isNotEmpty) r.sender,
                      ].join(' · ')),
                      if (r.title.isNotEmpty)
                        pw.Text(r.title,
                            style: const pw.TextStyle(color: PdfColors.grey800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  return doc.save();
}
