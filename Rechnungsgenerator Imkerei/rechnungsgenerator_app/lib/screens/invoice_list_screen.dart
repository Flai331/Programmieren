import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../services/pdf_service.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'invoice_edit_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late DatabaseService _dbService;
  late SyncService _syncService;
  String _filter = 'all';
  String _docType = 'invoice'; // 'invoice' | 'quote'

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'accepted': return const Color(0xFF22c55e);
      case 'sent':     return const Color(0xFFf59e0b);
      case 'rejected': return const Color(0xFFff6b7a);
      default:         return const Color(0xFF8a8a94);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':     return 'Bezahlt';
      case 'accepted': return 'Angenommen';
      case 'sent':     return _docType == 'quote' ? 'Versendet' : 'Gestellt';
      case 'rejected': return 'Abgelehnt';
      default:         return 'Entwurf';
    }
  }

  // Status-Reihenfolge je Dokumenttyp
  List<String> get _statusOrder => _docType == 'quote'
      ? ['draft', 'sent', 'accepted', 'rejected']
      : ['draft', 'sent', 'paid'];

  Future<void> _shareInvoice(InvoiceModel invoice) async {
    try {
      final companies = await _dbService.getAllCompanies();
      if (companies.isEmpty) return;
      final company = companies.first;
      final customer = await _dbService.getCustomer(invoice.customerId);
      if (customer == null) return;
      final items = await _dbService.getInvoiceItems(invoice.id);
      final design = await _dbService.getDesignSettings(company.id) ??
          DesignSettingsModel(
            id: 'default',
            companyId: company.id,
            createdAt: DateTime.now(),
          );

      final pdf = await PdfService().generateInvoicePdf(
        invoice: invoice,
        company: company,
        customer: customer,
        items: items,
        designSettings: design,
      );
      final bytes = await pdf.save();
      final label = invoice.isQuote ? 'Angebot' : 'Rechnung';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${label}_${invoice.invoiceNumber}.pdf');
      await file.writeAsBytes(bytes);
      final dateStr = AppUtils.formatDate(invoice.date);
      final subject = invoice.isQuote
          ? 'Angebot: ${invoice.invoiceNumber} vom $dateStr'
          : 'Rechnungsnummer: ${invoice.invoiceNumber} vom $dateStr';
      final body = invoice.isQuote
          ? 'Moin,\n\nanbei unser Angebot.'
          : 'Moin,\n\nanbei die Rechnung für die letzte Honiglieferung.';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
        text: body,
      );
      await _dbService.updateInvoiceStatus(invoice.id, 'sent');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cycleStatus(InvoiceModel invoice) async {
    // Zyklus je Dokumenttyp
    final order = invoice.isQuote
        ? ['draft', 'sent', 'accepted', 'rejected']
        : ['draft', 'sent', 'paid'];
    final idx = order.indexOf(invoice.status);
    final next = order[(idx + 1) % order.length];
    await _dbService.updateInvoiceStatus(invoice.id, next);
    if (mounted) setState(() {});
  }

  // Angebot → Rechnung umwandeln
  Future<void> _convertToInvoice(InvoiceModel quote) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('In Rechnung umwandeln'),
        content: Text(
            'Angebot ${quote.invoiceNumber} als neue Rechnung übernehmen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Umwandeln'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // Neue Rechnungsnummer aus Pattern
      final companies = await _dbService.getAllCompanies();
      final pattern = companies.isNotEmpty
          ? companies.first.invoiceNumberPattern
          : InvoiceNumberGenerator.defaultPattern;
      final existing = await _dbService.getAllInvoiceNumbers();
      final customer = await _dbService.getCustomer(quote.customerId);
      final newNumber = InvoiceNumberGenerator.generate(
        pattern: pattern,
        existingNumbers: existing,
        customerName: customer?.name,
        customerNumber: customer?.customerNumber,
      );

      final newId = const Uuid().v4();
      final invoice = quote.copyWith(
        id: newId,
        invoiceNumber: newNumber,
        documentType: 'invoice',
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _dbService.insertInvoice(invoice);

      // Positionen kopieren
      final items = await _dbService.getInvoiceItems(quote.id);
      for (final item in items) {
        await _dbService.insertInvoiceItem(
          item.copyWith(id: const Uuid().v4(), invoiceId: newId),
        );
      }

      if (mounted) {
        setState(() => _docType = 'invoice');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Rechnung $newNumber erstellt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvoiceModel>>(
      future: _dbService.getAllInvoices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Fehler beim Laden der Rechnungen'),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu laden'),
                ),
              ],
            ),
          );
        }

        final allInvoices = snapshot.data ?? [];
        final typeInvoices = allInvoices
            .where((i) => i.documentType == _docType)
            .toList();
        final isQuote = _docType == 'quote';
        final docPlural = isQuote ? 'Angebote' : 'Rechnungen';

        final filtered = _filter == 'all'
            ? typeInvoices
            : typeInvoices.where((i) => i.status == _filter).toList();

        return Column(
          children: [
            // ── Umschalter Rechnungen / Angebote ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'invoice',
                    label: Text('Rechnungen'),
                    icon: Icon(Icons.receipt_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: 'quote',
                    label: Text('Angebote'),
                    icon: Icon(Icons.description_outlined, size: 18),
                  ),
                ],
                selected: {_docType},
                onSelectionChanged: (s) => setState(() {
                  _docType = s.first;
                  _filter = 'all';
                }),
              ),
            ),

            // ── Filter-Tabs (Status) ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  for (final f in ['all', ..._statusOrder])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == 'all'
                            ? 'Alle (${typeInvoices.length})'
                            : '${_statusLabel(f)} (${typeInvoices.where((i) => i.status == f).length})'),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: f == 'all'
                            ? const Color(0xFFfda085)
                            : _statusColor(f).withOpacity(0.8),
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : null,
                          fontWeight: _filter == f ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Liste ──
            Expanded(
              child: typeInvoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              isQuote
                                  ? Icons.description_outlined
                                  : Icons.receipt,
                              size: 64,
                              color: const Color(0xFF8a8a94)),
                          const SizedBox(height: 16),
                          Text('Keine $docPlural vorhanden'),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InvoiceEditScreen(
                                      documentType: _docType),
                                ),
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.add),
                            label: Text(isQuote
                                ? 'Erstes Angebot erstellen'
                                : 'Erste Rechnung erstellen'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                        await _syncService.syncInvoicesManual();
                      },
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Keine ${_statusLabel(_filter)}-$docPlural',
                                style: const TextStyle(
                                    color: Color(0xFF8a8a94)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final invoice = filtered[index];
                                return InvoiceListCard(
                                  invoice: invoice,
                                  statusColor: _statusColor(invoice.status),
                                  statusLabel: _statusLabel(invoice.status),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceEditScreen(
                                            invoiceId: invoice.id),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  onDelete: () =>
                                      _showDeleteConfirmation(context, invoice),
                                  onShare: () => _shareInvoice(invoice),
                                  onStatusTap: () => _cycleStatus(invoice),
                                  onConvert: invoice.isQuote
                                      ? () => _convertToInvoice(invoice)
                                      : null,
                                );
                              },
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, InvoiceModel invoice) {
    final label = invoice.isQuote ? 'Angebot' : 'Rechnung';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label löschen'),
        content: Text('$label ${invoice.invoiceNumber} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await _dbService.deleteInvoice(invoice.id);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label gelöscht')),
              );
            },
            child: const Text('Löschen', style: TextStyle(color: Color(0xFFff6b7a))),
          ),
        ],
      ),
    );
  }
}

class InvoiceListCard extends StatelessWidget {
  final InvoiceModel invoice;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onStatusTap;
  final VoidCallback? onConvert; // nur für Angebote

  const InvoiceListCard({
    Key? key,
    required this.invoice,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    required this.onStatusTap,
    this.onConvert,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Datum: ${AppUtils.formatDate(invoice.date)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppUtils.formatCurrency(invoice.total),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFfda085),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Status-Chip (tappable)
                      GestureDetector(
                        onTap: onStatusTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.swap_horiz, size: 11, color: statusColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Bearbeiten'),
                  ),
                  TextButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.mail_outline, size: 16),
                    label: const Text('Senden'),
                  ),
                  if (onConvert != null)
                    TextButton.icon(
                      onPressed: onConvert,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('→ Rechnung'),
                    ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Löschen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
