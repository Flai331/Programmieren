import 'package:flutter/material.dart';
import '../widgets/feedback_actions.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/services.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class PdfPreviewScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final CompanyModel company;
  final CustomerModel customer;
  final List<InvoiceItemModel> items;
  final DesignSettingsModel designSettings;

  const PdfPreviewScreen({
    Key? key,
    required this.invoice,
    required this.company,
    required this.customer,
    required this.items,
    required this.designSettings,
  }) : super(key: key);

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late Future<pw.Document> _pdfFuture;
  late PdfService _pdfService;
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    _pdfService = PdfService();
    _dbService = DatabaseService();
    _pdfFuture = _generatePdf();
  }

  Future<pw.Document> _generatePdf() async {
    return await _pdfService.generateInvoicePdf(
      invoice: widget.invoice,
      company: widget.company,
      customer: widget.customer,
      items: widget.items,
      designSettings: widget.designSettings,
    );
  }

  Future<void> _savePdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF wird gespeichert...'),
        ),
      );

      final pdf = await _pdfFuture;
      final bytes = await pdf.save();

      // Get the documents directory
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Rechnung_${widget.invoice.invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');

      // Write the PDF bytes to file
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ PDF gespeichert: $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    try {
      final pdf = await _pdfFuture;
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final isQuote = widget.invoice.isQuote;
      final label = isQuote ? 'Angebot' : 'Rechnung';
      final fileName = '${label}_${widget.invoice.invoiceNumber}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      final dateStr = AppUtils.formatDate(widget.invoice.date);
      final subject = isQuote
          ? 'Angebot: ${widget.invoice.invoiceNumber} vom $dateStr'
          : 'Rechnungsnummer: ${widget.invoice.invoiceNumber} vom $dateStr';
      final body = isQuote
          ? 'Moin,\n\nanbei unser Angebot.'
          : 'Moin,\n\nanbei die Rechnung für die letzte Honiglieferung.';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
        text: body,
      );
      await _dbService.updateInvoiceStatus(widget.invoice.id, 'sent');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      final pdf = await _pdfFuture;
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rechnung ${widget.invoice.invoiceNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Speichern',
                  onPressed: _savePdf,
                ),
                IconButton(
                  icon: const Icon(Icons.mail_outline),
                  tooltip: 'Per Mail senden',
                  onPressed: _sharePdf,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Teilen',
                  onPressed: _sharePdf,
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Drucken',
                  onPressed: _printPdf,
                ),
              ],
            ),
          ),
          const FeedbackActions(),
        ],
      ),
      body: FutureBuilder<pw.Document>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('PDF wird generiert...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Fehler: ${snapshot.error}'),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _pdfFuture = _generatePdf()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Neu versuchen'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Keine PDF-Daten'));
          }

          final pdf = snapshot.data!;

          return PdfPreview(
            build: (_) => pdf.save(),
            previewPageMargin: const EdgeInsets.all(16),
            allowSharing: true,
            allowPrinting: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            scrollViewDecoration: const BoxDecoration(
              color: Color(0xFF050507), // bg-stage per design system
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF111114),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _savePdf,
              icon: const Icon(Icons.download),
              label: const Text('Speichern'),
            ),
            ElevatedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Senden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _printPdf,
              icon: const Icon(Icons.print),
              label: const Text('Drucken'),
            ),
          ],
        ),
      ),
    );
  }
}
