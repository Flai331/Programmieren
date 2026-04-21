import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
//  PDF SERVICE — generiert professionelle DIN-A4-Rechnungen
//  Ähnlich wie HTML-Referenz: Falzmarken, Header-Text, Bankinfos
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
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _buildPageHeader(company, invoice, designSettings),
        footer: (ctx) => _buildFooter(invoice, company, ctx),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 10),
                _buildCustomerSection(customer),
                pw.SizedBox(height: 8),
                if (invoice.additionalInfo != null &&
                    invoice.additionalInfo!.isNotEmpty) ...[
                  _buildAdditionalInfo(invoice.additionalInfo!),
                  pw.SizedBox(height: 10),
                ],
                _buildInvoiceInfo(invoice),
                pw.SizedBox(height: 20),
                _buildItemsTable(items, invoice),
                pw.SizedBox(height: 16),
                _buildSummary(invoice),
                pw.SizedBox(height: 24),
                _buildBankInfo(company),
                pw.SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ── Seiten-Header ────────────────────────────────────────────
  pw.Widget _buildPageHeader(
    CompanyModel company,
    InvoiceModel invoice,
    DesignSettingsModel designSettings,
  ) {
    final headerColor = _parseColor(designSettings.headerTextColor);
    final textSize = designSettings.headerTextSize.toDouble();

    return pw.Stack(
      children: [
        // DIN 5008 Falzmarken (links, 7mm lang)
        ..._buildDinFoldMarks(),

        // Eigentlicher Header-Inhalt (mit Padding damit Falzmarken sichtbar)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Firmenname + Adresse links
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Header-Text (Firmenname über Adresse)
                        if (invoice.headerText != null &&
                            invoice.headerText!.isNotEmpty)
                          pw.Text(
                            invoice.headerText!,
                            style: pw.TextStyle(
                              fontSize: invoice.headerTextSize
                                  .clamp(10, 30)
                                  .toDouble(),
                              fontWeight: pw.FontWeight.bold,
                              color: headerColor,
                            ),
                          )
                        else
                          pw.Text(
                            company.name,
                            style: pw.TextStyle(
                              fontSize: textSize,
                              fontWeight: pw.FontWeight.bold,
                              color: headerColor,
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${company.street} · ${company.zipcode} ${company.city}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Tel: ${company.phone}'
                          '${company.email.isNotEmpty ? ' · ${company.email}' : ''}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (company.website != null &&
                            company.website!.isNotEmpty)
                          pw.Text(
                            company.website!,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        if (company.taxId != null && company.taxId!.isNotEmpty)
                          pw.Text(
                            'St-Nr: ${company.taxId}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                height: 2,
                color: headerColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── DIN 5008 Falzmarken ──────────────────────────────────────
  List<pw.Widget> _buildDinFoldMarks() {
    // 105mm und 210mm von oben, 7mm lang, links am Rand
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
        top: 148.5 * PdfPageFormat.mm, // Lochmarke (länger)
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
  pw.Widget _buildCustomerSection(CustomerModel customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Rechnungsadresse',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          customer.name,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        if (customer.street.isNotEmpty)
          pw.Text(customer.street, style: const pw.TextStyle(fontSize: 10)),
        if (customer.zipcode.isNotEmpty || customer.city.isNotEmpty)
          pw.Text('${customer.zipcode} ${customer.city}',
              style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ── Zusatzinformationen ──────────────────────────────────────
  pw.Widget _buildAdditionalInfo(String info) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(info, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // ── Rechnungsdaten ───────────────────────────────────────────
  pw.Widget _buildInvoiceInfo(InvoiceModel invoice) {
    return pw.Row(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _infoRow('Rechnungsnummer:', invoice.invoiceNumber),
            _infoRow('Rechnungsdatum:', _formatDate(invoice.date)),
            _infoRow('Zahlbar bis:', _formatDate(invoice.dueDate)),
          ],
        ),
      ],
    );
  }

  // ── Positionen-Tabelle ───────────────────────────────────────
  pw.Widget _buildItemsTable(
    List<InvoiceItemModel> items,
    InvoiceModel invoice,
  ) {
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
      headerDecoration: pw.BoxDecoration(color: _peach),
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
  pw.Widget _buildSummary(InvoiceModel invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _summaryRow(
                invoice.isGrossPrice ? 'Netto (berechnet):' : 'Netto:',
                '${invoice.subtotal.toStringAsFixed(2)} €'),
            _summaryRow(
                'MwSt. (${invoice.taxRate.toStringAsFixed(0)}%):',
                '${invoice.vat.toStringAsFixed(2)} €'),
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
        ),
      ),
    );
  }

  // ── Bankinfos ────────────────────────────────────────────────
  pw.Widget _buildBankInfo(CompanyModel company) {
    final hasBank = company.iban != null && company.iban!.isNotEmpty;
    final hasPaypal = company.paypal != null && company.paypal!.isNotEmpty;
    if (!hasBank && !hasPaypal) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
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

  // ── Footer ───────────────────────────────────────────────────
  pw.Widget _buildFooter(
    InvoiceModel invoice,
    CompanyModel company,
    pw.Context ctx,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.fromLTRB(20, 5, 20, 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(company.name, style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Rechnung ${invoice.invoiceNumber}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8)),
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

  PdfColor _parseColor(String hexColor) {
    try {
      final color = int.parse(hexColor.replaceFirst('#', '0xff'));
      return PdfColor.fromInt(color);
    } catch (_) {
      return PdfColors.black;
    }
  }
}
