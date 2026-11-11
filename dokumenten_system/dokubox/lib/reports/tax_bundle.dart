import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../data/database.dart';
import '../data/finance.dart';
import '../data/tax.dart';
import 'report_pdf.dart';

typedef TaxRow = ({Document doc, String sender});

/// Betrag für die Steuer: anrechenbarer Anteil, sonst Rechnungsbetrag.
int taxAmount(Document d) => d.taxAmountCents ?? d.amountCents ?? 0;

/// Gruppiert nach Kategorie in der Reihenfolge von [kTaxCategories].
Map<String, List<TaxRow>> groupTax(List<TaxRow> rows) {
  final groups = <String, List<TaxRow>>{};
  for (final k in kTaxCategories.keys) {
    final list = rows.where((r) => r.doc.taxCategory == k).toList();
    if (list.isNotEmpty) groups[k] = list;
  }
  return groups;
}

Future<Uint8List> _tocPdf(int year, Map<String, List<TaxRow>> groups,
    Map<String, int> startPage, ByteData? font) {
  final total = groups.values.expand((r) => r).fold(0, (a, r) => a + taxAmount(r.doc));
  return buildReport(
    title: 'Steuer-Mappe $year',
    subtitle: '${groups.values.fold(0, (a, l) => a + l.length)} Belege · '
        'Summe ${formatEuro(total)}',
    font: font,
    content: () => [
      pw.Text('Zusammenstellung für Steuererklärung/Steuerberater. '
          'Kategorien sind Vorschläge – bitte prüfen.',
          style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 8),
      for (final e in groups.entries) ...[
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text(kTaxCategories[e.key]!,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Text(formatEuro(e.value.fold(0, (a, r) => a + taxAmount(r.doc)))),
          pw.SizedBox(width: 12),
          pw.Text('S. ${startPage[e.key] ?? 0}'),
        ]),
        reportTable(
          ['Nr.', 'Datum', 'Absender', 'Titel', 'Betrag', 'Seite'],
          [
            for (final r in e.value)
              [
                r.doc.docNumber,
                reportDate(r.doc.docDate),
                r.sender,
                r.doc.title,
                taxAmount(r.doc) == 0 ? '–' : formatEuro(taxAmount(r.doc)),
                '${startPage['doc:${r.doc.id}'] ?? 0}',
              ],
          ],
        ),
      ],
    ],
  );
}

Future<Uint8List> _dividers(Map<String, List<TaxRow>> groups, ByteData? font) {
  final doc = pw.Document(
      theme: font == null ? null : pw.ThemeData.withFont(base: pw.Font.ttf(font)));
  for (final e in groups.entries) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Center(
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(kTaxCategories[e.key]!,
              textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 22)),
          pw.SizedBox(height: 8),
          pw.Text('${e.value.length} Beleg(e) · '
              '${formatEuro(e.value.fold(0, (a, r) => a + taxAmount(r.doc)))}'),
        ]),
      ),
    ));
  }
  return doc.save();
}

/// Steuer-Mappe als eine PDF: Inhaltsverzeichnis mit Seitenzahlen und
/// Summen, je Kategorie ein Trennblatt, danach die Original-Seiten
/// (verlustfrei, Text bleibt markierbar).
Future<Uint8List> buildTaxBundle({
  required int year,
  required List<TaxRow> rows,
  required Future<String> Function(Document doc) pdfPathOf,
  ByteData? font,
  required Directory tempDir,
}) async {
  final groups = groupTax(rows);
  final opened = <PdfDocument>[];
  try {
    // Seitenzahlen der Belege ermitteln.
    final docPages = <String, PdfDocument>{};
    for (final r in groups.values.expand((l) => l)) {
      final path = await pdfPathOf(r.doc);
      if (!await File(path).exists()) continue;
      final d = await PdfDocument.openFile(path);
      opened.add(d);
      docPages[r.doc.id] = d;
    }
    // 1. Durchlauf: Länge des Inhaltsverzeichnisses bestimmen.
    final probe = await PdfDocument.openData(await _tocPdf(year, groups, {}, font));
    opened.add(probe);
    final tocLen = probe.pages.length;
    final start = <String, int>{};
    var page = tocLen + 1;
    for (final e in groups.entries) {
      start[e.key] = page;
      page++; // Trennblatt
      for (final r in e.value) {
        start['doc:${r.doc.id}'] = page;
        page += docPages[r.doc.id]?.pages.length ?? 0;
      }
    }
    final toc = await PdfDocument.openData(await _tocPdf(year, groups, start, font));
    final dividers = await PdfDocument.openData(await _dividers(groups, font));
    opened.addAll([toc, dividers]);

    final out = await PdfDocument.createNew(sourceName: 'steuer-$year');
    opened.add(out);
    final pages = <PdfPage>[...toc.pages];
    var i = 0;
    for (final e in groups.entries) {
      pages.add(dividers.pages[i++]);
      for (final r in e.value) {
        pages.addAll(docPages[r.doc.id]?.pages ?? const []);
      }
    }
    out.pages = pages;
    return await out.encodePdf();
  } finally {
    for (final d in opened.reversed) {
      await d.dispose();
    }
  }
}
