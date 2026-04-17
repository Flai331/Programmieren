import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/services.dart';
import '../models/models.dart';

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

  @override
  void initState() {
    super.initState();
    _pdfService = PdfService();
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

      // Create temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Rechnung_${widget.invoice.invoiceNumber}.pdf';
      final file = File('${tempDir.path}/$fileName');

      // Write the PDF bytes to temporary file
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Rechnung ${widget.invoice.invoiceNumber}',
      );
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
            scrollViewDecoration: BoxDecoration(
              color: Colors.grey[100],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _savePdf,
              icon: const Icon(Icons.download),
              label: const Text('Speichern'),
            ),
            ElevatedButton.icon(
              onPressed: _printPdf,
              icon: const Icon(Icons.print),
              label: const Text('Drucken'),
            ),
            ElevatedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share),
              label: const Text('Teilen'),
            ),
          ],
        ),
      ),
    );
  }
}
