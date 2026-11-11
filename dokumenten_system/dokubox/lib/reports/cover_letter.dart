import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Anschreiben/Deckblatt nach DIN 5008 (Form B, Fensterumschlag) – für
/// Brief oder Fax an Behörden/Firmen.
Future<Uint8List> buildCoverLetter({
  required String senderLines,
  required String recipientLines,
  required String subject,
  String reference = '',
  required String body,
  List<String> enclosures = const [],
  String? fax,
  int? totalPages,
  Uint8List? signature,
  String signerName = '',
  String place = '',
  DateTime? date,
  ByteData? font,
}) async {
  date ??= DateTime.now();
  final mm = PdfPageFormat.mm;
  final doc = pw.Document(
    title: subject,
    creator: 'DokuBox',
    theme: font == null ? null : pw.ThemeData.withFont(base: pw.Font.ttf(font)),
  );
  final sender1 = senderLines.split('\n').where((l) => l.trim().isNotEmpty).join(' · ');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.fromLTRB(25 * mm, 0, 20 * mm, 15 * mm),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 15 * mm),
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(senderLines, textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9)),
        ),
        // Anschriftfeld Form B: 45 mm von oben, 85 × 45 mm
        pw.SizedBox(height: 45 * mm - 15 * mm - 22 * mm),
        pw.SizedBox(
          width: 85 * mm,
          height: 45 * mm,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(sender1,
                  style: const pw.TextStyle(fontSize: 7, decoration: pw.TextDecoration.underline)),
              pw.SizedBox(height: 3 * mm),
              pw.Text(recipientLines, style: const pw.TextStyle(fontSize: 11)),
              if (fax != null && fax.isNotEmpty)
                pw.Text('Fax: $fax', style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        ),
        pw.SizedBox(height: 8 * mm),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              '${place.isEmpty ? '' : '$place, '}${DateFormat('dd.MM.yyyy').format(date!)}'),
        ),
        if (reference.isNotEmpty) ...[
          pw.SizedBox(height: 4 * mm),
          pw.Text(reference, style: const pw.TextStyle(fontSize: 9)),
        ],
        pw.SizedBox(height: 6 * mm),
        pw.Text(subject, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6 * mm),
        pw.Text(body, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        pw.SizedBox(height: 4 * mm),
        if (signature != null)
          pw.SizedBox(height: 16 * mm, child: pw.Image(pw.MemoryImage(signature))),
        if (signerName.isNotEmpty) pw.Text(signerName),
        pw.Spacer(),
        if (enclosures.isNotEmpty) ...[
          pw.Text('Anlagen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final e in enclosures) pw.Text('– $e'),
        ],
        if (totalPages != null)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Seiten insgesamt (inkl. Deckblatt): $totalPages',
                style: const pw.TextStyle(fontSize: 9)),
          ),
      ],
    ),
  ));
  return doc.save();
}
