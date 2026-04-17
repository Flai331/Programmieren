import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();

  PdfService._internal();

  factory PdfService() {
    return _instance;
  }

  /// Generate PDF from invoice data
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
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeader(company, designSettings),
        footer: (context) => _buildFooter(invoice, company),
        build: (context) => [
          _buildCustomerSection(invoice, customer),
          pw.SizedBox(height: 20),
          _buildInvoiceInfo(invoice),
          pw.SizedBox(height: 20),
          _buildItemsTable(items, invoice),
          pw.SizedBox(height: 20),
          _buildSummary(invoice),
          pw.SizedBox(height: 20),
          _buildBankInfo(company),
          pw.SizedBox(height: 40),
          _buildDinFoldMarks(),
        ],
      ),
    );

    return pdf;
  }

  /// Build header with company logo and info
  pw.Widget _buildHeader(
    CompanyModel company,
    DesignSettingsModel designSettings,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: _parseColor(designSettings.headerTextColor),
            width: 2,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.name,
                      style: pw.TextStyle(
                        fontSize: designSettings.headerTextSize.toDouble(),
                        fontWeight: pw.FontWeight.bold,
                        color: _parseColor(designSettings.headerTextColor),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '${company.street} | ${company.zipcode} ${company.city}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Tel: ${company.phone} | ${company.email}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    if (company.website != null)
                      pw.Text(
                        'Web: ${company.website}',
                        style: pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build customer address section
  pw.Widget _buildCustomerSection(
    InvoiceModel invoice,
    CustomerModel customer,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Rechnungsadresse:',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          customer.name,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          customer.street,
          style: pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          '${customer.zipcode} ${customer.city}',
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  /// Build invoice number, date, and due date
  pw.Widget _buildInvoiceInfo(InvoiceModel invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Rechnungsnummer:', invoice.invoiceNumber),
            _buildInfoRow('Rechnungsdatum:', _formatDate(invoice.date)),
            _buildInfoRow('Zahlbar bis:', _formatDate(invoice.dueDate)),
          ],
        ),
      ],
    );
  }

  /// Build items table with borders
  pw.Widget _buildItemsTable(
    List<InvoiceItemModel> items,
    InvoiceModel invoice,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Pos.', 'Beschreibung', 'Menge', 'Einheit', 'Preis', 'Gesamt'],
      data: [
        for (int i = 0; i < items.length; i++)
          [
            '${i + 1}',
            items[i].description,
            items[i].quantity.toString(),
            items[i].unit,
            '${items[i].price.toStringAsFixed(2)} €',
            '${items[i].total.toStringAsFixed(2)} €',
          ]
      ],
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 1,
      ),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey700,
      ),
      cellHeight: 25,
      cellPadding: const pw.EdgeInsets.all(5),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
    );
  }

  /// Build summary section (subtotal, tax, total)
  pw.Widget _buildSummary(InvoiceModel invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildSummaryRow(
            'Zwischensumme:',
            invoice.subtotal.toStringAsFixed(2),
          ),
          _buildSummaryRow(
            'USt. (${invoice.taxRate.toStringAsFixed(0)}%):',
            invoice.vat.toStringAsFixed(2),
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.black, width: 1),
                bottom: pw.BorderSide(color: PdfColors.black, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Gesamtbetrag: ',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${invoice.total.toStringAsFixed(2)} €',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build bank information
  pw.Widget _buildBankInfo(CompanyModel company) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Zahlungsinformationen:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          if (company.iban != null) ...[
            pw.Text(
              'IBAN: ${company.iban}',
              style: pw.TextStyle(fontSize: 9),
            ),
            if (company.bic != null)
              pw.Text(
                'BIC: ${company.bic}',
                style: pw.TextStyle(fontSize: 9),
              ),
            if (company.bank != null)
              pw.Text(
                'Bank: ${company.bank}',
                style: pw.TextStyle(fontSize: 9),
              ),
            pw.SizedBox(height: 5),
          ],
          if (company.paypal != null) ...[
            pw.Text(
              'PayPal: ${company.paypal}',
              style: pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  /// Build DIN 5008 fold marks for window envelope
  pw.Widget _buildDinFoldMarks() {
    return pw.Stack(
      children: [
        // Vertical fold marks (105mm and 210mm from top)
        pw.Positioned(
          left: 0,
          top: 105 * PdfPageFormat.mm,
          child: pw.Container(
            width: 595,
            height: 0.5,
            color: PdfColors.grey300,
          ),
        ),
        pw.Positioned(
          left: 0,
          top: 210 * PdfPageFormat.mm,
          child: pw.Container(
            width: 595,
            height: 0.5,
            color: PdfColors.grey300,
          ),
        ),
      ],
    );
  }

  /// Build footer with page numbers
  pw.Widget _buildFooter(
    InvoiceModel invoice,
    CompanyModel company,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            company.name,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Seite ${1}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  /// Helper to build info row
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(width: 50),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Helper to build summary row
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(width: 30),
        pw.Text(
          '$value €',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  /// Format date for PDF
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  /// Parse color from hex string
  PdfColor _parseColor(String hexColor) {
    try {
      final color = int.parse(hexColor.replaceFirst('#', '0xff'));
      return PdfColor.fromInt(color);
    } catch (e) {
      return PdfColors.black;
    }
  }
}
