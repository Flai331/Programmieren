import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../widgets/invoice_layout_canvas.dart';

// ═══════════════════════════════════════════════════════════════
//  PDF SERVICE — generiert professionelle DIN-A4-Rechnungen
//  WYSIWYG: Nutzt layout_json aus DesignSettings für Positionen
// ═══════════════════════════════════════════════════════════════

class PdfService {
  static final PdfService _instance = PdfService._internal();
  PdfService._internal();
  factory PdfService() => _instance;

  static const _peach = PdfColor(0.992, 0.627, 0.522); // #fda085

  Future<pw.Document> generateInvoicePdf({
    required InvoiceModel invoice,
    required CompanyModel company,
    required CustomerModel customer,
    required List<InvoiceItemModel> items,
    required DesignSettingsModel designSettings,
  }) async {
    // Roboto-Font laden (Unicode-fähig, kennt €)
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final italic = await PdfGoogleFonts.robotoItalic();

    // Logo + Header-Bild laden (falls URL gesetzt)
    pw.ImageProvider? logoImg;
    pw.ImageProvider? headerImg;
    try {
      if (designSettings.logoUrl != null &&
          designSettings.logoUrl!.isNotEmpty) {
        logoImg = await networkImage(designSettings.logoUrl!);
      }
    } catch (_) {}
    try {
      if (designSettings.topHeaderUrl != null &&
          designSettings.topHeaderUrl!.isNotEmpty) {
        headerImg = await networkImage(designSettings.topHeaderUrl!);
      }
    } catch (_) {}

    // Layout-Positionen aus JSON (oder Default)
    final layout = InvoiceLayoutCanvas.decodeLayout(designSettings.layoutJson);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: base,
        bold: bold,
        italic: italic,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) {
          return pw.Stack(
            children: [
              // DIN 5008 Falz- und Lochmarken (kurze Striche links)
              ..._buildDinFoldMarks(),

              // ── Header-Bild ──
              if (headerImg != null)
                _positioned(
                  layout['header_image'],
                  pw.Transform(
                    alignment: pw.Alignment.center,
                    transform: _flipMatrix(
                        layout['header_image']?.flipH ?? designSettings.headerFlipH,
                        layout['header_image']?.flipV ?? designSettings.headerFlipV),
                    child: pw.Image(headerImg, fit: pw.BoxFit.fill),
                  ),
                ),

              // ── Logo ──
              if (logoImg != null)
                _positioned(
                  layout['logo'],
                  pw.Transform(
                    alignment: pw.Alignment.center,
                    transform: _flipMatrix(
                        layout['logo']?.flipH ?? designSettings.logoFlipH,
                        layout['logo']?.flipV ?? designSettings.logoFlipV),
                    child: pw.Image(logoImg, fit: pw.BoxFit.fill),
                  ),
                ),

              // ── Firmenname-Überschrift ──
              _positionedClamped(
                layout['company_header'],
                pw.Text(
                  company.name,
                  softWrap: false,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: designSettings.headerTextSize.toDouble(),
                    fontWeight: pw.FontWeight.bold,
                    color: _parseColor(designSettings.headerTextColor),
                  ),
                ),
              ),

              // ── Absender / Rücksendeangabe (DIN 5008 Form B) ──
              // Einzeilige Mini-Zeile in der Rücksendezone (17.7mm hoch),
              // 7pt mit Unterstreichung. Kein Firmenname.
              _positionedClamped(
                layout['company_address'],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                              color: PdfColors.grey700, width: 0.4),
                        ),
                      ),
                      child: pw.Text(
                        '${company.name} · ${company.street} · ${company.zipcode} ${company.city}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Empfänger ──
              _positionedClamped(
                layout['customer_address'],
                _buildCustomerSection(customer, invoice),
              ),

              // ── Rechnungs-Meta ──
              _positionedClamped(
                layout['invoice_meta'],
                _buildInvoiceInfo(invoice),
              ),

              // ── Positionen-Tabelle ──
              _positionedClamped(
                layout['items_table'],
                _buildItemsTable(items, invoice,
                    tableHeaderColor: _parseColor(designSettings.tableHeaderColor)),
              ),

              // ── Zusatzinformationen ──
              if (invoice.additionalInfo != null &&
                  invoice.additionalInfo!.isNotEmpty)
                _positionedClamped(
                  layout['additional_info'],
                  pw.Text(
                    invoice.additionalInfo!,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),

              // ── Zusammenfassung ──
              _positionedClamped(
                layout['summary'],
                _buildSummary(invoice, items),
              ),

              // ── Bankdaten (nur Rechnung, nicht Angebot) ──
              _positionedClamped(
                layout['bank_info'],
                invoice.isQuote ? pw.SizedBox() : _buildBankInfo(company),
              ),

              // ── Fußzeile (DIN 5008 Kommunikationsangaben) ──
              _positionedClamped(
                layout['footer'],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(
                              color: PdfColors.grey400, width: 0.4),
                        ),
                      ),
                      padding: const pw.EdgeInsets.only(top: 3),
                      // DIN 5008: nur briefwichtige Daten. Tel/Mail entfernt.
                      child: pw.Text(company.name,
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          [
                            if (company.website != null &&
                                company.website!.isNotEmpty)
                              company.website!,
                            if (company.taxId != null &&
                                company.taxId!.isNotEmpty)
                              'St-Nr: ${company.taxId}',
                          ].join(' · '),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                            '${invoice.isQuote ? 'Angebot' : 'Rechnung'} ${invoice.invoiceNumber} · Seite ${ctx.pageNumber}/${ctx.pagesCount}',
                            style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // ── Absolut positioniertes Element laut Layout ───────────────
  pw.Widget _positioned(ElementPos? pos, pw.Widget child) {
    final p = pos ?? const ElementPos(x: 20, y: 20, w: 200, h: 50);
    return pw.Positioned(
      left: p.x,
      top: p.y,
      child: pw.SizedBox(
        width: p.w,
        height: p.h,
        child: child,
      ),
    );
  }

  // Wie _positioned aber x darf Lochrand (55pt ≈ 17mm+Puffer) nicht unterschreiten
  pw.Widget _positionedClamped(ElementPos? pos, pw.Widget child) {
    const holeMarginPt = 55.0; // 17mm + Sicherheitsabstand
    final p = pos ?? const ElementPos(x: 55, y: 20, w: 200, h: 50);
    final clampedX = p.x < holeMarginPt ? holeMarginPt : p.x;
    // Breite anpassen damit rechter Rand nicht rauswächst
    final clampedW = p.w - (clampedX - p.x);
    return pw.Positioned(
      left: clampedX,
      top: p.y,
      child: pw.SizedBox(
        width: clampedW,
        height: p.h,
        child: child,
      ),
    );
  }

  // ── Flip-Matrix für PDF Transform ────────────────────────────
  Matrix4 _flipMatrix(bool h, bool v) {
    return Matrix4.diagonal3Values(
        h ? -1.0 : 1.0, v ? -1.0 : 1.0, 1.0);
  }

  // ── DIN 5008 Falz- und Lochmarken ────────────────────────────
  // Kurze solide Striche am linken Rand:
  //  - Falzmarke 1: 105mm (1. Falz für Briefumschlag)
  //  - Lochmarke:  148.5mm (Mittelpunkt für Lochung)
  //  - Falzmarke 2: 210mm (2. Falz)
  List<pw.Widget> _buildDinFoldMarks() {
    const markWidth = 7.0 * PdfPageFormat.mm;
    const markThickness = 0.5;
    const markColor = PdfColors.grey400;

    return [
      pw.Positioned(
        left: 0,
        top: 105 * PdfPageFormat.mm,
        child: pw.Container(
          width: markWidth,
          height: markThickness,
          color: markColor,
        ),
      ),
      pw.Positioned(
        left: 0,
        top: 148.5 * PdfPageFormat.mm,
        child: pw.Container(
          width: markWidth * 1.5,
          height: markThickness,
          color: markColor,
        ),
      ),
      pw.Positioned(
        left: 0,
        top: 210 * PdfPageFormat.mm,
        child: pw.Container(
          width: markWidth,
          height: markThickness,
          color: markColor,
        ),
      ),
    ];
  }

  // ── Empfänger-Adresse ────────────────────────────────────────
  pw.Widget _buildCustomerSection(CustomerModel customer, InvoiceModel invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(customer.name, style: const pw.TextStyle(fontSize: 11)),
        if (customer.street.isNotEmpty)
          pw.Text(customer.street, style: const pw.TextStyle(fontSize: 11)),
        if (customer.zipcode.isNotEmpty || customer.city.isNotEmpty)
          pw.Text('${customer.zipcode} ${customer.city}',
              style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // ── Rechnungs-/Angebotsdaten ─────────────────────────────────
  pw.Widget _buildInvoiceInfo(InvoiceModel invoice) {
    final isQuote = invoice.isQuote;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _infoRow(isQuote ? 'Angebotsnummer:' : 'Rechnungsnummer:',
            invoice.invoiceNumber),
        _infoRow(isQuote ? 'Angebotsdatum:' : 'Rechnungsdatum:',
            _formatDate(invoice.date)),
        _infoRow(isQuote ? 'Gültig bis:' : 'Zahlbar bis:',
            _formatDate(invoice.dueDate)),
      ],
    );
  }

  // ── Positionen-Tabelle ───────────────────────────────────────
  pw.Widget _buildItemsTable(
    List<InvoiceItemModel> items,
    InvoiceModel invoice, {
    PdfColor? tableHeaderColor,
  }) {
    final priceLabel =
        invoice.isGrossPrice ? 'Preis (Brutto)' : 'Preis (Netto)';
    final totalLabel =
        invoice.isGrossPrice ? 'Gesamt (Brutto)' : 'Gesamt (Netto)';

    return pw.TableHelper.fromTextArray(
      headers: ['Pos.', 'Beschreibung', 'Menge', 'Einheit', priceLabel, totalLabel],
      data: [
        for (int i = 0; i < items.length; i++)
          [
            '${i + 1}',
            items[i].description,
            _formatNumber(items[i].quantity),
            items[i].unit,
            '${items[i].price.toStringAsFixed(2)} €',
            '${items[i].total.toStringAsFixed(2)} €',
          ]
      ],
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: tableHeaderColor ?? _peach),
      cellHeight: 22,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      oddRowDecoration:
          const pw.BoxDecoration(color: PdfColor(0.98, 0.98, 0.98)),
    );
  }

  // ── Zusammenfassung ──────────────────────────────────────────
  pw.Widget _buildSummary(InvoiceModel invoice, List<InvoiceItemModel> items) {
    // Netto + MwSt pro Steuersatz berechnen
    final byRate = <double, Map<String, double>>{};
    for (final item in items) {
      final itemNet = invoice.isGrossPrice
          ? item.total / (1 + item.taxRate / 100)
          : item.total;
      final itemVat = itemNet * (item.taxRate / 100);
      byRate[item.taxRate] ??= {'netto': 0, 'vat': 0};
      byRate[item.taxRate]!['netto'] = byRate[item.taxRate]!['netto']! + itemNet;
      byRate[item.taxRate]!['vat'] = byRate[item.taxRate]!['vat']! + itemVat;
    }
    final sortedRates = byRate.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _summaryRow(
            invoice.isGrossPrice ? 'Netto (berechnet):' : 'Netto:',
            '${invoice.subtotal.toStringAsFixed(2)} €'),
        ...sortedRates.map((rate) => _summaryRow(
              'MwSt. (${_formatTaxRate(rate)}%):',
              '${byRate[rate]!['vat']!.toStringAsFixed(2)} €',
            )),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 1),
              bottom: pw.BorderSide(color: PdfColors.black, width: 2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Gesamtbetrag:',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                '${invoice.total.toStringAsFixed(2)} €',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bankinfos ────────────────────────────────────────────────
  pw.Widget _buildBankInfo(CompanyModel company) {
    final hasBank = company.iban != null && company.iban!.isNotEmpty;
    final hasPaypal = company.paypal != null && company.paypal!.isNotEmpty;
    if (!hasBank && !hasPaypal) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Zahlungsinformationen',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (hasBank) ...[
            if (company.accountHolder != null &&
                company.accountHolder!.isNotEmpty)
              pw.Text('Kontoinhaber: ${company.accountHolder}',
                  style: const pw.TextStyle(fontSize: 9)),
            pw.Text('IBAN: ${company.iban}',
                style: const pw.TextStyle(fontSize: 9)),
            if (company.bic != null && company.bic!.isNotEmpty)
              pw.Text('BIC: ${company.bic}',
                  style: const pw.TextStyle(fontSize: 9)),
            if (company.bank != null && company.bank!.isNotEmpty)
              pw.Text('Bank: ${company.bank}',
                  style: const pw.TextStyle(fontSize: 9)),
          ],
          if (hasPaypal) ...[
            if (hasBank) pw.SizedBox(height: 4),
            pw.Text('PayPal: ${company.paypal}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 20),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

  String _formatNumber(double n) =>
      n == n.truncateToDouble() ? n.toInt().toString() : n.toString();

  String _formatTaxRate(double rate) {
    if (rate == rate.truncateToDouble()) return rate.toInt().toString();
    return rate.toString().replaceAll('.', ',');
  }

  PdfColor _parseColor(String hexColor) {
    try {
      final color = int.parse(hexColor.replaceFirst('#', '0xff'));
      return PdfColor.fromInt(color);
    } catch (_) {
      return PdfColors.black;
    }
  }
}
