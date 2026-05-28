import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
//  PDF LETTER SERVICE — DIN 5008 Geschäftsbrief
//  Port aus Briefgenerator/js/pdf-export.js (jsPDF → pdf package)
//  Maße in Millimetern via PdfPageFormat.mm
// ═══════════════════════════════════════════════════════════════

class PdfLetterService {
  static final PdfLetterService _instance = PdfLetterService._internal();
  PdfLetterService._internal();
  factory PdfLetterService() => _instance;

  // ── DIN 5008 Konstanten (mm) ──────────────────────────────────
  static const double _pageWidth = 210.0;
  static const double _marginLeft = 25.0;
  static const double _marginRightMin = 10.0;
  static const double _addrFieldLeft = 20.0;
  static const double _addrTextIndent = 5.0;
  static const double _infoBlockLeft = 125.0;
  static const double _punchMarkTop = 148.5;
  static const double _foldMarkWidth = 5.0;
  static const double _punchMarkWidth = 7.0;
  static const double _lineSpacing = 4.23; // 12pt single line
  static const double _spaceAfterAddress = 8.46;
  static const double _spaceAfterSubject = 8.46;
  static const double _spaceAfterSalutation = 4.23;
  static const double _spaceAfterBody = 4.23;
  static const int _signatureLines = 3;

  // Form-spezifisch
  static const Map<String, double> _formAddressTop = {'A': 27.0, 'B': 45.0};
  static const Map<String, double> _formVermerkTop = {'A': 27.0, 'B': 45.0};
  static const double _vermerkHeight = 17.7;
  static const Map<String, double> _formAnschriftTop = {'A': 44.7, 'B': 62.7};
  static const double _addressFieldHeight = 45.0;
  static const Map<String, double> _formInfoTop = {'A': 32.0, 'B': 50.0};

  // Faltmarken pro Umschlag + Form
  static const Map<String, Map<String, List<double?>>> _foldMarks = {
    'DL': {'A': [87, 192], 'B': [105, 210]},
    'C6': {'A': [105, null], 'B': [105, null]},
    'C5': {'A': [148.5, null], 'B': [148.5, null]},
    'C4': {'A': [null, null], 'B': [null, null]},
    'B6': {'A': [99, null], 'B': [99, null]},
    'B5': {'A': [148.5, null], 'B': [148.5, null]},
  };

  double _subjectTop(String form) =>
      _formAddressTop[form]! + _addressFieldHeight + _spaceAfterAddress;

  Future<pw.Document> generateLetterPdf({
    required LetterModel letter,
    required CompanyModel? company,
  }) async {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();

    final doc = pw.Document();
    final form = letter.letterForm;
    final marks = _foldMarks[letter.envelopeFormat]?[form] ?? [null, null];

    // Sender aus Firma
    final senderName = company?.name ?? '';
    final senderStreet = company?.street ?? '';
    final senderCity = '${company?.zipcode ?? ''} ${company?.city ?? ''}'.trim();
    final senderExtra = [
      if ((company?.phone ?? '').isNotEmpty) 'Tel: ${company!.phone}',
      if ((company?.email ?? '').isNotEmpty) company!.email,
    ].join(' · ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(children: [
          // ── Faltmarken ──
          if (letter.showFoldMarks && marks[0] != null)
            _line(0, marks[0]!, _foldMarkWidth, PdfColors.grey400),
          if (letter.showFoldMarks && marks[1] != null)
            _line(0, marks[1]!, _foldMarkWidth, PdfColors.grey400),

          // ── Lochmarke ──
          if (letter.showPunchMark)
            _line(0, _punchMarkTop, _punchMarkWidth, PdfColors.grey400),

          // ── Rücksendeangabe (über Empfänger-Anschrift) ──
          if (senderName.isNotEmpty || senderStreet.isNotEmpty || senderCity.isNotEmpty)
            pw.Positioned(
              left: (_addrFieldLeft + _addrTextIndent) * PdfPageFormat.mm,
              top: (_formVermerkTop[form]! + _vermerkHeight - 4) *
                  PdfPageFormat.mm,
              child: pw.Text(
                [senderName, senderStreet, senderCity]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: pw.TextStyle(
                  font: base,
                  fontSize: 7,
                  color: PdfColors.grey700,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),

          // ── Empfängeradresse ──
          pw.Positioned(
            left: (_addrFieldLeft + _addrTextIndent) * PdfPageFormat.mm,
            top: (_formAnschriftTop[form]!) * PdfPageFormat.mm,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final line in [
                  letter.recipientZusatz,
                  letter.recipientName,
                  letter.recipientStreet,
                  letter.recipientCity,
                  letter.recipientCountry,
                ].where((s) => s != null && s.isNotEmpty))
                  pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(bottom: 0.5 * PdfPageFormat.mm),
                    child: pw.Text(line!,
                        style: pw.TextStyle(font: base, fontSize: 11)),
                  ),
              ],
            ),
          ),

          // ── Informationsblock (rechts: Sender, Bezugszeichen, Datum) ──
          pw.Positioned(
            left: _infoBlockLeft * PdfPageFormat.mm,
            top: _formInfoTop[form]! * PdfPageFormat.mm,
            child: pw.SizedBox(
              width: (210 - _infoBlockLeft - _marginRightMin) *
                  PdfPageFormat.mm,
              child: _buildInfoBlock(letter, base, bold, senderName,
                  senderStreet, senderCity, senderExtra),
            ),
          ),

          // ── Betreff + Anrede + Brieftext + Gruß + Unterschrift ──
          pw.Positioned(
            left: _marginLeft * PdfPageFormat.mm,
            top: _subjectTop(form) * PdfPageFormat.mm,
            child: pw.SizedBox(
              width: (_pageWidth - _marginLeft - _marginRightMin) *
                  PdfPageFormat.mm,
              child: _buildBody(letter, base, bold),
            ),
          ),
        ]),
      ),
    );

    return doc;
  }

  // ── Info-Block: Sender-Details + Bezugszeichen + Datum ──
  pw.Widget _buildInfoBlock(
    LetterModel letter,
    pw.Font base,
    pw.Font bold,
    String senderName,
    String senderStreet,
    String senderCity,
    String senderExtra,
  ) {
    final infoLines = [senderName, senderStreet, senderCity, senderExtra]
        .where((s) => s.isNotEmpty)
        .toList();
    final refPairs = <(String, String?)>[
      ('IHR ZEICHEN', letter.refYour),
      ('IHRE NACHRICHT VOM', letter.refYourDate),
      ('UNSER ZEICHEN', letter.refOur),
      ('UNSERE NACHRICHT VOM', letter.refOurDate),
    ].where((p) => (p.$2 ?? '').isNotEmpty).toList();

    String? dateLine;
    if ((letter.location ?? '').isNotEmpty || letter.letterDate != null) {
      final parts = <String>[];
      if ((letter.location ?? '').isNotEmpty) parts.add(letter.location!);
      if (letter.letterDate != null) {
        parts.add(DateFormat('dd.MM.yyyy').format(letter.letterDate!));
      }
      dateLine = parts.join(', den ');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in infoLines)
          pw.Text(line, style: pw.TextStyle(font: base, fontSize: 9)),
        if (refPairs.isNotEmpty) pw.SizedBox(height: 4 * PdfPageFormat.mm),
        for (final (label, value) in refPairs) ...[
          pw.Text(label,
              style: pw.TextStyle(
                  font: base, fontSize: 7, color: PdfColors.grey700)),
          pw.Text(value!,
              style: pw.TextStyle(font: base, fontSize: 9)),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
        ],
        if (dateLine != null) ...[
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Text(dateLine, style: pw.TextStyle(font: base, fontSize: 9)),
        ],
      ],
    );
  }

  // ── Body: Betreff bold → Anrede → Text → Gruß → Unterschrift ──
  pw.Widget _buildBody(LetterModel letter, pw.Font base, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if ((letter.subject ?? '').isNotEmpty)
          pw.Text(letter.subject!,
              style: pw.TextStyle(font: bold, fontSize: 11)),
        pw.SizedBox(height: _spaceAfterSubject * PdfPageFormat.mm),
        if ((letter.salutation ?? '').isNotEmpty) ...[
          pw.Text(letter.salutation!,
              style: pw.TextStyle(font: base, fontSize: 11)),
          pw.SizedBox(height: _spaceAfterSalutation * PdfPageFormat.mm),
        ],
        if ((letter.body ?? '').isNotEmpty) ...[
          pw.Text(letter.body!,
              style: pw.TextStyle(font: base, fontSize: 11, lineSpacing: 2)),
          pw.SizedBox(height: _spaceAfterBody * PdfPageFormat.mm),
        ],
        if ((letter.closing ?? '').isNotEmpty)
          pw.Text(letter.closing!,
              style: pw.TextStyle(font: base, fontSize: 11)),
        pw.SizedBox(
            height: _lineSpacing * _signatureLines * PdfPageFormat.mm),
        if ((letter.signerName ?? '').isNotEmpty)
          pw.Text(letter.signerName!,
              style: pw.TextStyle(font: base, fontSize: 11)),
      ],
    );
  }

  pw.Widget _line(double xMm, double yMm, double widthMm, PdfColor color) {
    return pw.Positioned(
      left: xMm * PdfPageFormat.mm,
      top: yMm * PdfPageFormat.mm,
      child: pw.Container(
        width: widthMm * PdfPageFormat.mm,
        height: 0.2 * PdfPageFormat.mm,
        color: color,
      ),
    );
  }
}
