import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import 'report_pdf.dart';

typedef DocRow = ({Document doc, String sender});

/// Box-Inhaltsliste: was liegt in „Box 2026“? Nummer, Datum, Absender,
/// Titel, Typ.
Future<Uint8List> buildBoxListPdf(String location, List<DocRow> rows,
        {ByteData? font, DateTime? created}) =>
    buildReport(
      title: 'Inhalt: $location',
      subtitle: rows.isEmpty
          ? 'leer'
          : '${rows.length} Dokumente · ${rows.first.doc.docNumber} bis '
              '${rows.last.doc.docNumber}',
      font: font,
      created: created,
      content: () => [
        reportTable(
          ['Nummer', 'Datum', 'Absender', 'Titel', 'Typ'],
          [
            for (final r in rows)
              [
                r.doc.docNumber,
                reportDate(r.doc.docDate),
                r.sender,
                r.doc.title,
                r.doc.docType ?? '',
              ],
          ],
          widths: const {
            0: pw.FixedColumnWidth(62),
            1: pw.FixedColumnWidth(58),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(3),
            4: pw.FlexColumnWidth(1.4),
          },
        ),
      ],
    );

/// Vernichtungs-Protokoll mit Unterschriftszeile (optional eigene
/// Unterschrift als Bild).
Future<Uint8List> buildDestructionLogPdf(List<DocRow> rows,
        {ByteData? font,
        DateTime? created,
        Uint8List? signature,
        String period = ''}) =>
    buildReport(
      title: 'Vernichtungs-Protokoll',
      subtitle: [
        if (period.isNotEmpty) period,
        '${rows.length} Originale',
      ].join(' · '),
      font: font,
      created: created,
      content: () => [
        pw.Text(
          'Die folgenden Originale wurden nach Ablauf der Aufbewahrungsfrist '
          'vernichtet. Die digitale Kopie bleibt in DokuBox erhalten.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 10),
        reportTable(
          ['Nummer', 'Titel', 'Absender', 'Datum', 'Aufbewahrung bis',
              'Vernichtet am', 'Lagerort vorher'],
          [
            for (final r in rows)
              [
                r.doc.docNumber,
                r.doc.title,
                r.sender,
                reportDate(r.doc.docDate),
                reportDate(r.doc.retentionUntil),
                r.doc.destroyedAt == null
                    ? 'Datum unbekannt'
                    : reportDate(r.doc.destroyedAt),
                r.doc.destroyedFrom ?? '–',
              ],
          ],
        ),
        pw.SizedBox(height: 40),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (signature != null)
                  pw.SizedBox(
                      height: 40,
                      child: pw.Image(pw.MemoryImage(signature),
                          fit: pw.BoxFit.contain)),
                pw.Container(
                    height: 0.5, width: 220, color: PdfColors.grey700),
                pw.Text('Datum, Unterschrift',
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ]),
      ],
    );
