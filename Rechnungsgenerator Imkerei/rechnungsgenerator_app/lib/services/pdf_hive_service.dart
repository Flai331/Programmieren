import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
//  PDF HIVE SERVICE — Stockkarte mit QR-Code
//  DIN A6 (105×148 mm) — passt auf Stockdeckel
// ═══════════════════════════════════════════════════════════════

class PdfHiveService {
  static final PdfHiveService _instance = PdfHiveService._internal();
  PdfHiveService._internal();
  factory PdfHiveService() => _instance;

  static const _peach = PdfColor(0.992, 0.627, 0.522);

  /// Stockkarte als PDF. [actions] erscheinen als Verlauf auf einer
  /// zweiten Seite – neueste zuerst.
  Future<pw.Document> generateStockkartePdf({
    required HiveModel hive,
    List<HiveActionModel> actions = const [],
  }) async {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Kopfzeile
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('STOCKKARTE',
                        style: pw.TextStyle(
                            font: bold, fontSize: 9, color: _peach)),
                    pw.SizedBox(height: 2),
                    pw.Text(hive.displayLabel,
                        style: pw.TextStyle(font: bold, fontSize: 16)),
                  ],
                ),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: hive.qrId,
                  width: 32 * PdfPageFormat.mm,
                  height: 32 * PdfPageFormat.mm,
                  drawText: false,
                ),
              ],
            ),
            pw.SizedBox(height: 6 * PdfPageFormat.mm),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4 * PdfPageFormat.mm),

            // Stammdaten
            _row(base, bold, 'Standort', hive.location ?? '—'),
            if ((hive.position ?? '').isNotEmpty)
              _row(base, bold, 'Platz', hive.position!),
            _row(base, bold, 'Königin',
                _queenInfo(hive.queenYear, hive.queenOrigin)),
            _row(base, bold, 'Status', _statusLabel(hive.status)),
            if ((hive.notes ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Text('Notizen:',
                  style: pw.TextStyle(font: bold, fontSize: 9)),
              pw.Text(hive.notes!,
                  style: pw.TextStyle(font: base, fontSize: 9)),
            ],

            pw.Spacer(),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('QR: ${hive.qrId}',
                    style: pw.TextStyle(
                        font: base, fontSize: 6, color: PdfColors.grey700)),
                pw.Text(
                    'Erstellt: ${DateFormat('dd.MM.yyyy').format(hive.createdAt)}',
                    style: pw.TextStyle(
                        font: base, fontSize: 6, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ),
    );

    if (actions.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a6,
          margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
          header: (ctx) => pw.Padding(
            padding:
                const pw.EdgeInsets.only(bottom: 3 * PdfPageFormat.mm),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('MASSNAHMEN',
                    style: pw.TextStyle(
                        font: bold, fontSize: 9, color: _peach)),
                pw.Text(hive.displayLabel,
                    style: pw.TextStyle(font: bold, fontSize: 11)),
                pw.SizedBox(height: 2 * PdfPageFormat.mm),
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              ],
            ),
          ),
          build: (ctx) => [
            for (final a in actions) _actionEntry(base, bold, a),
          ],
        ),
      );
    }

    return doc;
  }

  pw.Widget _actionEntry(pw.Font base, pw.Font bold, HiveActionModel a) {
    final summary = a.summary;
    final note = (a.note ?? '').trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3 * PdfPageFormat.mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 20 * PdfPageFormat.mm,
                child: pw.Text(DateFormat('dd.MM.yyyy').format(a.date),
                    style: pw.TextStyle(font: base, fontSize: 8)),
              ),
              pw.Expanded(
                child: pw.Text(a.typeLabel,
                    style: pw.TextStyle(font: bold, fontSize: 8)),
              ),
            ],
          ),
          if (summary.isNotEmpty)
            pw.Padding(
              padding:
                  const pw.EdgeInsets.only(left: 20 * PdfPageFormat.mm),
              child: pw.Text(summary,
                  style: pw.TextStyle(
                      font: base, fontSize: 8, color: PdfColors.grey700)),
            ),
          // Notiz nur zusätzlich zeigen, wenn sie nicht schon die
          // Zusammenfassung ist (bei Maßnahmen ohne Kennzahlen).
          if (note.isNotEmpty && note != summary)
            pw.Padding(
              padding:
                  const pw.EdgeInsets.only(left: 20 * PdfPageFormat.mm),
              child: pw.Text(note,
                  style: pw.TextStyle(font: base, fontSize: 8)),
            ),
        ],
      ),
    );
  }

  pw.Widget _row(pw.Font base, pw.Font bold, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2 * PdfPageFormat.mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 22 * PdfPageFormat.mm,
            child: pw.Text(label,
                style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(font: base, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  String _queenInfo(int? year, String? origin) {
    final parts = <String>[];
    if (year != null) parts.add(year.toString());
    if ((origin ?? '').isNotEmpty) parts.add(origin!);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'aktiv':       return 'Aktiv';
      case 'abgegeben':   return 'Abgegeben';
      case 'eingegangen': return 'Eingegangen';
      default:            return status;
    }
  }
}
