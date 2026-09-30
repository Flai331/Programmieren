import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../services/pdf_service.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../fehlerbericht.dart';
import '../widgets/invoice_item_widget.dart';
import '../widgets/invoice_layout_canvas.dart';
import '../widgets/gradient_button.dart';
import 'pdf_preview_screen.dart';
import 'design_customizer_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  INVOICE EDIT SCREEN — 4-Tab-Wizard + Live-Vorschau
//  Breite Screens (≥720px): Formular links | PDF-Vorschau rechts
//  Schmale Screens: Nur Tabs (Vorschau per Button)
// ═══════════════════════════════════════════════════════════════

class InvoiceEditScreen extends StatefulWidget {
  final String? invoiceId;
  /// 'invoice' = Rechnung | 'quote' = Angebot (nur für neue Dokumente relevant)
  final String documentType;

  const InvoiceEditScreen({
    Key? key,
    this.invoiceId,
    this.documentType = 'invoice',
  }) : super(key: key);

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen>
    with SingleTickerProviderStateMixin {
  late DatabaseService _dbService;
  late SyncService _syncService;
  late TabController _tabController;

  // ── Live-Vorschau ────────────────────────────────────────────
  Timer? _previewDebounce;
  int _previewVersion = 0;

  // ── Dokumenttyp (Rechnung / Angebot) ─────────────────────────
  String get _docType => _currentInvoice?.documentType ?? widget.documentType;
  bool get _isQuote => _docType == 'quote';
  String get _docLabel => _isQuote ? 'Angebot' : 'Rechnung';

  /// Nummern-Pattern je Dokumenttyp.
  /// Angebot = 'AN-' + Firmen-Pattern → AN-Prefix, gleiche KUNDENNR-Logik,
  /// eigene laufende Zählung (AN-Prefix isoliert die {NR}-Sequenz von Rechnungen).
  String _numberPattern() {
    final base = _company?.invoiceNumberPattern ??
        InvoiceNumberGenerator.defaultPattern;
    return _isQuote ? 'AN-$base' : base;
  }

  // ── Tab 2: Absender ─────────────────────────────────────────
  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyEmailCtrl;
  late TextEditingController _companyStreetCtrl;
  late TextEditingController _companyZipcodeCtrl;
  late TextEditingController _companyCityCtrl;
  late TextEditingController _companyPhoneCtrl;
  late TextEditingController _companyTaxIdCtrl;
  late TextEditingController _companyWebsiteCtrl;
  late TextEditingController _companyIbanCtrl;
  late TextEditingController _companyBicCtrl;
  late TextEditingController _companyBankCtrl;
  late TextEditingController _companyAccountHolderCtrl;
  late TextEditingController _companyPaypalCtrl;

  // ── Tab 3: Empfänger ─────────────────────────────────────────
  late TextEditingController _customerNumberCtrl;
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerStreetCtrl;
  late TextEditingController _customerZipcodeCtrl;
  late TextEditingController _customerCityCtrl;

  // ── Tab 4: Rechnung ──────────────────────────────────────────
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _invoiceDateCtrl;
  late TextEditingController _paymentTermsCtrl;
  late TextEditingController _taxRateCtrl;
  late TextEditingController _additionalInfoCtrl;

  bool _isGrossPrice = true;
  List<InvoiceItemModel> _items = [];
  String? _selectedCustomerId;

  InvoiceModel? _currentInvoice;
  CompanyModel? _company;
  DesignSettingsModel? _designSettings;
  bool _isLoading = false;

  static const Color _peach = Color(0xFFfda085);

  // Alle Controller, die Preview-Updates auslösen
  List<TextEditingController> get _previewControllers => [
        _companyNameCtrl, _companyEmailCtrl, _companyStreetCtrl,
        _companyZipcodeCtrl, _companyCityCtrl, _companyPhoneCtrl,
        _companyTaxIdCtrl, _companyWebsiteCtrl, _companyIbanCtrl,
        _companyBicCtrl, _companyBankCtrl, _companyAccountHolderCtrl,
        _companyPaypalCtrl, _customerNumberCtrl, _customerNameCtrl, _customerStreetCtrl,
        _customerZipcodeCtrl, _customerCityCtrl, _invoiceNumberCtrl,
        _invoiceDateCtrl, _paymentTermsCtrl, _taxRateCtrl,
        _additionalInfoCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();
    _tabController = TabController(length: 4, vsync: this);

    _companyNameCtrl = TextEditingController();
    _companyEmailCtrl = TextEditingController();
    _companyStreetCtrl = TextEditingController();
    _companyZipcodeCtrl = TextEditingController();
    _companyCityCtrl = TextEditingController();
    _companyPhoneCtrl = TextEditingController();
    _companyTaxIdCtrl = TextEditingController();
    _companyWebsiteCtrl = TextEditingController();
    _companyIbanCtrl = TextEditingController();
    _companyBicCtrl = TextEditingController();
    _companyBankCtrl = TextEditingController();
    _companyAccountHolderCtrl = TextEditingController();
    _companyPaypalCtrl = TextEditingController();
    _customerNumberCtrl = TextEditingController();
    _customerNameCtrl = TextEditingController();
    _customerStreetCtrl = TextEditingController();
    _customerZipcodeCtrl = TextEditingController();
    _customerCityCtrl = TextEditingController();
    _invoiceNumberCtrl = TextEditingController();
    _invoiceDateCtrl = TextEditingController();
    _paymentTermsCtrl = TextEditingController(text: '14');
    _taxRateCtrl = TextEditingController(text: '19');
    _additionalInfoCtrl = TextEditingController();

    // Preview-Listener registrieren
    for (final ctrl in _previewControllers) {
      ctrl.addListener(_schedulePreviewRefresh);
    }

    Fehlerbericht.logSeite('InvoiceEdit',
        info: widget.invoiceId == null ? 'neu' : 'bearbeiten');
    _initialize();
  }

  // ── Live-Vorschau: debounced refresh ─────────────────────────
  void _schedulePreviewRefresh() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _previewVersion++);
    });
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final companies = await _dbService.getAllCompanies();
      if (companies.isNotEmpty) {
        _company = companies.first;
        _fillCompanyFields(_company!);
      }
      if (_company != null) {
        _designSettings = await _dbService.getDesignSettings(_company!.id);
      }
      if (widget.invoiceId != null) {
        _currentInvoice = await _dbService.getInvoice(widget.invoiceId!);
        _items = await _dbService.getInvoiceItems(widget.invoiceId!);
        _selectedCustomerId = _currentInvoice?.customerId;
        _populateForm();
      } else {
        // Nummer aus konfiguriertem Pattern generieren (Angebot = AN-Prefix)
        final pattern = _numberPattern();
        final existingNumbers = await _dbService.getAllInvoiceNumbers();
        _invoiceNumberCtrl.text = InvoiceNumberGenerator.generate(
          pattern: pattern,
          existingNumbers: existingNumbers,
        );
        _invoiceDateCtrl.text = AppUtils.formatDate(DateTime.now());
      }
    } catch (e) {
      Fehlerbericht.logFehler(e.toString(), kontext: 'InvoiceEdit._initialize');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _schedulePreviewRefresh(); // Initiale Vorschau
      }
    }
  }

  void _fillCompanyFields(CompanyModel c) {
    _companyNameCtrl.text = c.name;
    _companyEmailCtrl.text = c.email;
    _companyStreetCtrl.text = c.street;
    _companyZipcodeCtrl.text = c.zipcode;
    _companyCityCtrl.text = c.city;
    _companyPhoneCtrl.text = c.phone;
    _companyTaxIdCtrl.text = c.taxId ?? '';
    _companyWebsiteCtrl.text = c.website ?? '';
    _companyIbanCtrl.text = c.iban ?? '';
    _companyBicCtrl.text = c.bic ?? '';
    _companyBankCtrl.text = c.bank ?? '';
    _companyAccountHolderCtrl.text = c.accountHolder ?? '';
    _companyPaypalCtrl.text = c.paypal ?? '';
  }

  void _populateForm() {
    if (_currentInvoice == null) return;
    _invoiceNumberCtrl.text = _currentInvoice!.invoiceNumber;
    _invoiceDateCtrl.text = AppUtils.formatDate(_currentInvoice!.date);
    _paymentTermsCtrl.text = _currentInvoice!.paymentTerms.toString();
    _taxRateCtrl.text = _currentInvoice!.taxRate.toString();
    _additionalInfoCtrl.text = _currentInvoice!.additionalInfo ?? '';
    _isGrossPrice = _currentInvoice!.isGrossPrice;
    _loadCustomerData(_currentInvoice!.customerId);
  }

  Future<void> _loadCustomerData(String customerId) async {
    final customer = await _dbService.getCustomer(customerId);
    if (customer != null && mounted) {
      setState(() {
        _customerNumberCtrl.text = customer.customerNumber?.toString() ?? '';
        _customerNameCtrl.text = customer.name;
        _customerStreetCtrl.text = customer.street;
        _customerZipcodeCtrl.text = customer.zipcode;
        _customerCityCtrl.text = customer.city;
      });
    }
  }

  int _parseInvoiceNumber(String? number) {
    if (number == null) return 0;
    final parts = number.split('-');
    return int.tryParse(parts.last) ?? 0;
  }

  // ── Speichern ────────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final customerId = _selectedCustomerId ?? _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        customerNumber: int.tryParse(_customerNumberCtrl.text),
        name: _customerNameCtrl.text,
        street: _customerStreetCtrl.text,
        zipcode: _customerZipcodeCtrl.text,
        city: _customerCityCtrl.text,
        createdAt: DateTime.now(),
      );
      await _dbService.insertCustomer(customer);

      final totals = _calculateTotals();
      final invoice = InvoiceModel(
        id: _currentInvoice?.id ?? const Uuid().v4(),
        invoiceNumber: _invoiceNumberCtrl.text,
        companyId: _company?.id ?? 'default',
        customerId: customerId,
        date: AppUtils.parseDate(_invoiceDateCtrl.text) ?? DateTime.now(),
        paymentTerms: int.tryParse(_paymentTermsCtrl.text) ?? 14,
        additionalInfo: _additionalInfoCtrl.text.isEmpty
            ? null
            : _additionalInfoCtrl.text,
        taxRate: _parseTaxRate(),
        subtotal: totals['subtotal']!,
        vat: totals['vat']!,
        total: totals['total']!,
        createdAt: _currentInvoice?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        headerText: null,
        headerTextSize: 24,
        isGrossPrice: _isGrossPrice,
        documentType: _docType,
      );

      await _dbService.insertInvoice(invoice);
      for (var item in _items) {
        final itemWithInvoiceId = item.invoiceId.isEmpty
            ? item.copyWith(invoiceId: invoice.id)
            : item;
        await _dbService.insertInvoiceItem(itemWithInvoiceId);
      }

      _syncService.addToQueue(
        operation: _currentInvoice == null ? 'CREATE' : 'UPDATE',
        entityType: 'INVOICE',
        data: invoice.toMap(),
      );

      Fehlerbericht.logAktion('Rechnung gespeichert',
          kontext: {'nr': invoice.invoiceNumber});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Rechnung gespeichert')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      Fehlerbericht.logFehler(e.toString(), kontext: 'saveInvoice');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Speichern & Senden ───────────────────────────────────────
  Future<void> _saveAndSend() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final customerId = _selectedCustomerId ?? _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        customerNumber: int.tryParse(_customerNumberCtrl.text),
        name: _customerNameCtrl.text,
        street: _customerStreetCtrl.text,
        zipcode: _customerZipcodeCtrl.text,
        city: _customerCityCtrl.text,
        createdAt: DateTime.now(),
      );
      await _dbService.insertCustomer(customer);

      final totals = _calculateTotals();
      final invoice = InvoiceModel(
        id: _currentInvoice?.id ?? const Uuid().v4(),
        invoiceNumber: _invoiceNumberCtrl.text,
        companyId: _company?.id ?? 'default',
        customerId: customerId,
        date: AppUtils.parseDate(_invoiceDateCtrl.text) ?? DateTime.now(),
        paymentTerms: int.tryParse(_paymentTermsCtrl.text) ?? 14,
        additionalInfo: _additionalInfoCtrl.text.isEmpty ? null : _additionalInfoCtrl.text,
        taxRate: _parseTaxRate(),
        subtotal: totals['subtotal']!,
        vat: totals['vat']!,
        total: totals['total']!,
        createdAt: _currentInvoice?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        headerText: null,
        headerTextSize: 24,
        isGrossPrice: _isGrossPrice,
        status: 'sent',
        documentType: _docType,
      );
      await _dbService.insertInvoice(invoice);
      for (var item in _items) {
        final itemWithInvoiceId = item.invoiceId.isEmpty
            ? item.copyWith(invoiceId: invoice.id)
            : item;
        await _dbService.insertInvoiceItem(itemWithInvoiceId);
      }

      if (_company != null) {
        final design = await _dbService.getDesignSettings(_company!.id) ??
            DesignSettingsModel(
              id: 'default',
              companyId: _company!.id,
              createdAt: DateTime.now(),
            );
        final pdf = await PdfService().generateInvoicePdf(
          invoice: invoice,
          company: _company!,
          customer: customer,
          items: _items,
          designSettings: design,
        );
        final bytes = await pdf.save();
        final tempDir = await getTemporaryDirectory();
        final docLabel = _isQuote ? 'Angebot' : 'Rechnung';
        final file = File('${tempDir.path}/${docLabel}_${invoice.invoiceNumber}.pdf');
        await file.writeAsBytes(bytes);
        final dateStr = AppUtils.formatDate(invoice.date);
        final subject = _isQuote
            ? 'Angebot: ${invoice.invoiceNumber} vom $dateStr'
            : 'Rechnungsnummer: ${invoice.invoiceNumber} vom $dateStr';
        final body = _isQuote
            ? 'Moin,\n\nanbei unser Angebot.'
            : 'Moin,\n\nanbei die Rechnung für die letzte Honiglieferung.';
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
          text: body,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ $_docLabel gespeichert & gesendet')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      Fehlerbericht.logFehler(e.toString(), kontext: 'saveAndSend');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PDF-Vorschau (separater Screen) ─────────────────────────
  Future<void> _previewPdf() async {
    if (!_validateForm()) return;
    try {
      final customerId = _selectedCustomerId ?? _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        customerNumber: int.tryParse(_customerNumberCtrl.text),
        name: _customerNameCtrl.text,
        street: _customerStreetCtrl.text,
        zipcode: _customerZipcodeCtrl.text,
        city: _customerCityCtrl.text,
        createdAt: DateTime.now(),
      );
      final totals = _calculateTotals();
      final invoice = _buildInvoiceFromFields(
          id: _currentInvoice?.id ?? const Uuid().v4(),
          customerId: customerId,
          totals: totals);
      final companyForPdf = _buildCompanyFromFields();
      final ds = _designSettings ?? _defaultDesignSettings();

      Fehlerbericht.logAktion('PDF-Vorschau geöffnet');
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            invoice: invoice,
            company: companyForPdf,
            customer: customer,
            items: _items,
            designSettings: ds,
          ),
        ));
      }
    } catch (e) {
      Fehlerbericht.logFehler(e.toString(), kontext: 'previewPdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Live-Preview PDF-Bytes bauen ─────────────────────────────
  Future<Uint8List> _buildPreviewPdf(PdfPageFormat format) async {
    try {
      final company = _buildCompanyFromFields();
      final customer = CustomerModel(
        id: 'preview',
        name: _customerNameCtrl.text.isEmpty
            ? 'Musterkunde GmbH'
            : _customerNameCtrl.text,
        street: _customerStreetCtrl.text.isEmpty
            ? 'Musterstraße 1'
            : _customerStreetCtrl.text,
        zipcode: _customerZipcodeCtrl.text.isEmpty
            ? '12345'
            : _customerZipcodeCtrl.text,
        city: _customerCityCtrl.text.isEmpty
            ? 'Musterstadt'
            : _customerCityCtrl.text,
        createdAt: DateTime.now(),
      );
      final ds = _designSettings ?? _defaultDesignSettings();
      final items = _items.isEmpty ? _demoItems() : _items;
      final totals = _calculateTotals(items: items);
      final invoice = _buildInvoiceFromFields(
          id: 'preview', customerId: 'preview', totals: totals);

      final doc = await PdfService().generateInvoicePdf(
        invoice: invoice,
        company: company,
        customer: customer,
        items: items,
        designSettings: ds,
      );
      return doc.save();
    } catch (e) {
      Fehlerbericht.logFehler(e.toString(), kontext: 'LivePreview');
      // Fallback: leeres PDF mit Fehlermeldung
      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (_) => pw.Center(
          child: pw.Text('Vorschau nicht verfügbar:\n$e',
              style: const pw.TextStyle(fontSize: 12)),
        ),
      ));
      return doc.save();
    }
  }

  InvoiceModel _buildInvoiceFromFields({
    required String id,
    required String customerId,
    required Map<String, double> totals,
  }) {
    return InvoiceModel(
      id: id,
      invoiceNumber: _invoiceNumberCtrl.text.isEmpty
          ? 'RE-2024-001'
          : _invoiceNumberCtrl.text,
      companyId: _company?.id ?? 'default',
      customerId: customerId,
      date: AppUtils.parseDate(_invoiceDateCtrl.text) ?? DateTime.now(),
      paymentTerms: int.tryParse(_paymentTermsCtrl.text) ?? 14,
      additionalInfo:
          _additionalInfoCtrl.text.isEmpty ? null : _additionalInfoCtrl.text,
      taxRate: _parseTaxRate(),
      subtotal: totals['subtotal']!,
      vat: totals['vat']!,
      total: totals['total']!,
      createdAt: _currentInvoice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      headerText: null,
      headerTextSize: 24,
      isGrossPrice: _isGrossPrice,
      documentType: _docType,
    );
  }

  CompanyModel _buildCompanyFromFields() {
    return CompanyModel(
      id: _company?.id ?? 'default',
      name: _companyNameCtrl.text.isEmpty
          ? 'Meine Imkerei'
          : _companyNameCtrl.text,
      email: _companyEmailCtrl.text,
      street: _companyStreetCtrl.text,
      city: _companyCityCtrl.text,
      zipcode: _companyZipcodeCtrl.text,
      phone: _companyPhoneCtrl.text,
      taxId:
          _companyTaxIdCtrl.text.isEmpty ? null : _companyTaxIdCtrl.text,
      website: _companyWebsiteCtrl.text.isEmpty
          ? null
          : _companyWebsiteCtrl.text,
      iban: _companyIbanCtrl.text.isEmpty ? null : _companyIbanCtrl.text,
      bic: _companyBicCtrl.text.isEmpty ? null : _companyBicCtrl.text,
      bank: _companyBankCtrl.text.isEmpty ? null : _companyBankCtrl.text,
      accountHolder: _companyAccountHolderCtrl.text.isEmpty
          ? null
          : _companyAccountHolderCtrl.text,
      paypal: _companyPaypalCtrl.text.isEmpty
          ? null
          : _companyPaypalCtrl.text,
      createdAt: _company?.createdAt ?? DateTime.now(),
    );
  }

  DesignSettingsModel _defaultDesignSettings() {
    return DesignSettingsModel(
      id: const Uuid().v4(),
      companyId: _company?.id ?? 'default',
      headerTextColor: '#fda085',
      headerTextSize: 18,
      createdAt: DateTime.now(),
    );
  }

  List<InvoiceItemModel> _demoItems() {
    return [
      InvoiceItemModel(
        id: 'demo',
        invoiceId: 'preview',
        description: 'Blütenhonig 500g',
        quantity: 2,
        unit: 'Gläser',
        price: 8.50,
        taxRate: _parseTaxRate(),
        createdAt: DateTime.now(),
      ),
    ];
  }

  Map<String, double> _calculateTotals({List<InvoiceItemModel>? items}) {
    final list = items ?? _items;
    double subtotal = 0;
    double vat = 0;
    for (var item in list) {
      final itemNet = _isGrossPrice
          ? item.total / (1 + item.taxRate / 100)
          : item.total;
      subtotal += itemNet;
      vat += itemNet * (item.taxRate / 100);
    }
    final total = subtotal + vat;
    return {'subtotal': subtotal, 'vat': vat, 'total': total};
  }

  /// Gibt Map<taxRate, {netto, vat}> zurück — für gruppierte Zusammenfassung.
  Map<double, Map<String, double>> _calculateTotalsByRate({List<InvoiceItemModel>? items}) {
    final list = items ?? _items;
    final result = <double, Map<String, double>>{};
    for (var item in list) {
      final itemNet = _isGrossPrice
          ? item.total / (1 + item.taxRate / 100)
          : item.total;
      final itemVat = itemNet * (item.taxRate / 100);
      result[item.taxRate] ??= {'netto': 0, 'vat': 0};
      result[item.taxRate]!['netto'] = result[item.taxRate]!['netto']! + itemNet;
      result[item.taxRate]!['vat'] = result[item.taxRate]!['vat']! + itemVat;
    }
    return result;
  }

  bool _validateForm() {
    if (_companyNameCtrl.text.isEmpty) {
      _showError('Firmenname (Absender) erforderlich');
      _tabController.animateTo(1);
      return false;
    }
    if (_customerNameCtrl.text.isEmpty) {
      _showError('Empfänger-Name erforderlich');
      _tabController.animateTo(2);
      return false;
    }
    if (_items.isEmpty) {
      _showError('Mindestens eine Position erforderlich');
      _tabController.animateTo(3);
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _addItem({InvoiceItemModel? fromArticle}) {
    final newItem = fromArticle != null
        ? fromArticle.copyWith(
            id: const Uuid().v4(),
            invoiceId: _currentInvoice?.id ?? '',
            // taxRate NICHT überschreiben — Artikel behält eigenen MwSt-Satz
            createdAt: DateTime.now(),
          )
        : InvoiceItemModel(
            id: const Uuid().v4(),
            invoiceId: _currentInvoice?.id ?? '',
            description: '',
            quantity: 1,
            unit: 'Stk.',
            price: 0,
            taxRate: _parseTaxRate(),
            createdAt: DateTime.now(),
          );
    setState(() => _items.add(newItem));
    _schedulePreviewRefresh();
    Fehlerbericht.logAktion('Position hinzugefügt');
  }

  Future<void> _showAddItemSheet() async {
    // Artikel laden
    final articles = await _dbService.getAllArticles();

    // Keine Artikel → direkt leere Position
    if (articles.isEmpty) {
      _addItem();
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1c1c22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ArticlePickerSheet(
        articles: articles,
        onArticleSelected: (article) {
          _addItem(fromArticle: article);
        },
        onEmptyItem: () {
          _addItem();
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    _schedulePreviewRefresh();
  }

  void _updateItem(int index, InvoiceItemModel item) {
    setState(() => _items[index] = item);
    _schedulePreviewRefresh();
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_docLabel)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tabContent = TabBarView(
      controller: _tabController,
      children: [
        _buildDesignTab(),
        _buildSenderTab(),
        _buildRecipientTab(),
        _buildInvoiceTab(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentInvoice == null
            ? 'Neues $_docLabel'
            : '$_docLabel bearbeiten'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFfda085),
          labelColor: const Color(0xFFfda085),
          unselectedLabelColor: const Color(0xFF8a8a94),
          tabs: [
            const Tab(icon: Icon(Icons.palette_outlined), text: 'Design'),
            const Tab(icon: Icon(Icons.business_outlined), text: 'Absender'),
            const Tab(icon: Icon(Icons.person_outline), text: 'Empfänger'),
            Tab(icon: const Icon(Icons.receipt_outlined), text: _docLabel),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_outlined),
            tooltip: 'Vorschau (Vollbild)',
            onPressed: _previewPdf,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Speichern',
            onPressed: _saveInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Speichern & Senden',
            onPressed: _isLoading ? null : _saveAndSend,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // Ab 720px: Split-Layout (Formular links | Vorschau rechts)
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(flex: 5, child: tabContent),
                Container(width: 1, color: const Color(0x14ffffff)),
                Expanded(flex: 5, child: _buildLivePreviewPanel()),
              ],
            );
          }
          // Schmale Screens: nur Tabs
          return tabContent;
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LIVE-VORSCHAU PANEL (rechte Seite)
  // ══════════════════════════════════════════════════════════════
  Widget _buildLivePreviewPanel() {
    return Column(
      children: [
        // Header-Leiste
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF18181c),
            border: const Border(bottom: BorderSide(color: Color(0x14ffffff))),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 16, color: _peach),
              const SizedBox(width: 8),
              const Text(
                'Live-Vorschau',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _peach,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _previewVersion++),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 14, color: Color(0xFF8a8a94)),
                      const SizedBox(width: 4),
                      const Text(
                        'Aktualisieren',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF8a8a94)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Canvas-Vorschau (identisch mit Design-Customizer)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AbsorbPointer(
              child: _buildInvoicePreviewCanvas(),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INVOICE PREVIEW CANVAS
  // ══════════════════════════════════════════════════════════════
  Color _previewParseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFfda085);
    }
  }

  Widget _previewText(
    String text, {
    Color color = Colors.black,
    bool bold = false,
    bool italic = false,
    double size = 10,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _previewTableItems() {
    final ds = _designSettings;
    final tableColor = ds != null
        ? _previewParseColor(ds.tableHeaderColor)
        : const Color(0xFFfda085);
    final items = _items.isEmpty ? _demoItems() : _items;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: tableColor,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text('Pos.', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 4, child: Text('Beschreibung', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Menge', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Preis', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Gesamt', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 8, color: Colors.black87))),
                  Expanded(flex: 4, child: Text(items[i].description, style: const TextStyle(fontSize: 8, color: Colors.black87))),
                  Expanded(flex: 1, child: Text(AppUtils.formatNumber(items[i].quantity), style: const TextStyle(fontSize: 8, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('${items[i].price.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 8, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('${items[i].total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 8, color: Colors.black87))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreviewCanvas() {
    final ds = _designSettings;
    if (ds == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

    final layout = InvoiceLayoutCanvas.decodeLayout(ds.layoutJson);
    final textOverrides = InvoiceLayoutCanvas.decodeTexts(ds.layoutJson);
    final headerColor = _previewParseColor(ds.headerTextColor);
    final headerSize = ds.headerTextSize.toDouble();

    String t(String id, String fallback) => textOverrides[id] ?? fallback;

    final cName = _companyNameCtrl.text.isEmpty ? 'Meine Imkerei' : _companyNameCtrl.text;
    final cStreet = _companyStreetCtrl.text;
    final cZip = _companyZipcodeCtrl.text;
    final cCity = _companyCityCtrl.text;
    final cIban = _companyIbanCtrl.text;
    final cBic = _companyBicCtrl.text;
    final cHolder = _companyAccountHolderCtrl.text;

    // DIN 5008: Absender nur briefwichtige Daten (Name + Adresse). Kein Tel/Mail.
    final companyAddrDefault = '$cName'
        '${cStreet.isNotEmpty ? '\n$cStreet · $cZip $cCity' : ''}';

    // Angebot: keine Bankdaten
    final bankDefault = _isQuote
        ? ''
        : (cIban.isNotEmpty
            ? 'Bankverbindung: ${cHolder.isNotEmpty ? cHolder : cName} · $cIban${cBic.isNotEmpty ? ' · $cBic' : ''}'
            : 'Bankverbindung: –');

    final custName = _customerNameCtrl.text.isEmpty ? 'Musterkunde GmbH' : _customerNameCtrl.text;
    final custStreet = _customerStreetCtrl.text.isEmpty ? 'Musterstraße 1' : _customerStreetCtrl.text;
    final custZip = _customerZipcodeCtrl.text.isEmpty ? '12345' : _customerZipcodeCtrl.text;
    final custCity = _customerCityCtrl.text.isEmpty ? 'Musterstadt' : _customerCityCtrl.text;
    final custAddr = '$custName\n$custStreet\n$custZip $custCity';

    final invoiceNr = _invoiceNumberCtrl.text.isEmpty ? 'RE-2024-001' : _invoiceNumberCtrl.text;
    final invoiceDate = _invoiceDateCtrl.text.isEmpty ? AppUtils.formatDate(DateTime.now()) : _invoiceDateCtrl.text;
    final payDays = int.tryParse(_paymentTermsCtrl.text) ?? 14;
    final parsedDate = AppUtils.parseDate(invoiceDate) ?? DateTime.now();
    final dueDate = AppUtils.formatDate(parsedDate.add(Duration(days: payDays)));
    final invoiceMeta = 'Rechnungsnummer:  $invoiceNr\nRechnungsdatum:   $invoiceDate\nZahlbar bis:      $dueDate';

    final totals = _calculateTotals();
    final summaryText = 'Netto:        ${AppUtils.formatCurrency(totals['subtotal'] ?? 0)}\n'
        'MwSt. (${_taxRateCtrl.text}%):  ${AppUtils.formatCurrency(totals['vat'] ?? 0)}\n'
        '_______________________\n'
        'Gesamt:       ${AppUtils.formatCurrency(totals['total'] ?? 0)}';

    final elements = <LayoutElement>[
      if (ds.topHeaderUrl != null && ds.topHeaderUrl!.isNotEmpty)
        LayoutElement(
          id: 'header_image',
          label: 'Header-Bild',
          isImage: true,
          builder: (_) => Image.network(ds.topHeaderUrl!,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.red.shade100)),
        ),
      if (ds.logoUrl != null && ds.logoUrl!.isNotEmpty)
        LayoutElement(
          id: 'logo',
          label: 'Logo',
          isImage: true,
          builder: (_) => Image.network(ds.logoUrl!,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.red.shade100)),
        ),
      LayoutElement(
        id: 'company_header',
        label: 'Firmenname',
        builder: (_) => _previewText(t('company_header', cName), color: headerColor, bold: true, size: headerSize),
      ),
      LayoutElement(
        id: 'company_address',
        label: 'Absender',
        builder: (_) => _previewText(t('company_address', companyAddrDefault), size: 7),
      ),
      LayoutElement(
        id: 'customer_address',
        label: 'Empfänger',
        builder: (_) => _previewText(custAddr, size: 10),
      ),
      LayoutElement(
        id: 'invoice_meta',
        label: 'Rechnungs-Info',
        builder: (_) => _previewText(t('invoice_meta', invoiceMeta), size: 10),
      ),
      LayoutElement(
        id: 'items_table',
        label: 'Positionen',
        builder: (_) => _previewTableItems(),
      ),
      LayoutElement(
        id: 'additional_info',
        label: 'Zusatzinfo',
        builder: (_) => _previewText(
          _additionalInfoCtrl.text,
          size: 8,
          italic: true,
          color: Colors.grey.shade600,
        ),
      ),
      LayoutElement(
        id: 'summary',
        label: 'Summe',
        builder: (_) => _previewText(t('summary', summaryText), size: 10, bold: true),
      ),
      LayoutElement(
        id: 'bank_info',
        label: 'Bankdaten',
        builder: (_) => _previewText(t('bank_info', bankDefault), size: 9),
      ),
      LayoutElement(
        id: 'footer',
        label: 'Fußzeile',
        builder: (_) => _previewText(t('footer', 'Vielen Dank für Ihren Auftrag!'), size: 9, italic: true),
      ),
    ];

    return InvoiceLayoutCanvas(
      elements: elements,
      initialLayout: layout,
      onLayoutChanged: (_) {},
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 1: DESIGN
  // ══════════════════════════════════════════════════════════════
  Widget _buildDesignTab() {
    final hasLogo = _designSettings?.logoUrl != null &&
        _designSettings!.logoUrl!.isNotEmpty;
    final hasHeader = _designSettings?.topHeaderUrl != null &&
        _designSettings!.topHeaderUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Logo & Header'),
          const SizedBox(height: 16),
          _assetStatusCard(
            icon: Icons.image_outlined,
            label: 'Logo',
            active: hasLogo,
            activeText: 'Logo hochgeladen ✓',
            inactiveText: 'Kein Logo – optional',
          ),
          const SizedBox(height: 12),
          _assetStatusCard(
            icon: Icons.panorama_outlined,
            label: 'Header-Bild',
            active: hasHeader,
            activeText: 'Header-Bild hochgeladen ✓',
            inactiveText: 'Kein Header-Bild – optional',
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Design bearbeiten',
            icon: Icons.edit_outlined,
            onPressed: _company != null
                ? () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DesignCustomizerScreen(companyId: _company!.id),
                    ));
                    final ds =
                        await _dbService.getDesignSettings(_company!.id);
                    if (mounted) {
                      setState(() => _designSettings = ds);
                      _schedulePreviewRefresh();
                    }
                    Fehlerbericht.logAktion('Design bearbeitet');
                  }
                : null,
          ),
          const SizedBox(height: 32),
          NextTabButton(
            label: 'Weiter zu Absenderdaten',
            onPressed: () => _tabController.animateTo(1),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 2: ABSENDER
  // ══════════════════════════════════════════════════════════════
  Widget _buildSenderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Firmendaten'),
          const SizedBox(height: 16),
          _field(_companyNameCtrl, 'Name / Firma *', required: true),
          const SizedBox(height: 12),
          _field(_companyEmailCtrl, 'E-Mail',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(_companyStreetCtrl, 'Straße & Hausnummer'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_companyZipcodeCtrl, 'PLZ')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _field(_companyCityCtrl, 'Ort')),
          ]),
          const SizedBox(height: 12),
          _field(_companyPhoneCtrl, 'Telefon',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_companyTaxIdCtrl, 'Steuernummer / USt-IdNr.'),
          const SizedBox(height: 12),
          _field(_companyWebsiteCtrl, 'Webseite',
              hint: 'www.imkerei-beispiel.de',
              keyboardType: TextInputType.url),
          const SizedBox(height: 24),
          _sectionTitle('Zahlungsinformationen'),
          const SizedBox(height: 16),
          _field(_companyAccountHolderCtrl, 'Kontoinhaber',
              hint: 'Falls abweichend vom Absender'),
          const SizedBox(height: 12),
          _field(_companyIbanCtrl, 'IBAN',
              hint: 'DE89 3704 0044 0532 0130 00'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_companyBicCtrl, 'BIC', hint: 'COBADEFFXXX')),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _field(_companyBankCtrl, 'Bank', hint: 'Commerzbank')),
          ]),
          const SizedBox(height: 12),
          _field(_companyPaypalCtrl, 'PayPal',
              hint: 'paypal@beispiel.de',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 32),
          NextTabButton(
            label: 'Weiter zu Empfänger',
            onPressed: () => _tabController.animateTo(2),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 3: EMPFÄNGER
  // ══════════════════════════════════════════════════════════════
  Widget _buildRecipientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Kundendaten'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDialog<CustomerModel>(
                context: context,
                builder: (_) => const _AddressPickerDialog(),
              );
              if (selected != null && mounted) {
                setState(() {
                  _selectedCustomerId = selected.id;
                  _customerNumberCtrl.text = selected.customerNumber?.toString() ?? '';
                  _customerNameCtrl.text = selected.name;
                  _customerStreetCtrl.text = selected.street;
                  _customerZipcodeCtrl.text = selected.zipcode;
                  _customerCityCtrl.text = selected.city;
                });
                // Neues Dokument → Nummer mit Kundendaten neu generieren
                // (Angebot behält AN-Prefix via _numberPattern)
                if (widget.invoiceId == null) {
                  final pattern = _numberPattern();
                  if (pattern.contains('{KUNDE')) {
                    final existingNumbers =
                        await _dbService.getAllInvoiceNumbers();
                    if (mounted) {
                      _invoiceNumberCtrl.text =
                          InvoiceNumberGenerator.generate(
                        pattern: pattern,
                        existingNumbers: existingNumbers,
                        customerName: selected.name,
                        customerNumber: selected.customerNumber,
                      );
                    }
                  }
                }
                _schedulePreviewRefresh();
                Fehlerbericht.logAuswahl('Kunde', selected.name);
              }
            },
            icon: const Icon(Icons.contacts_outlined, color: _peach),
            label: const Text('Aus Adressbuch auswählen',
                style: TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customerNumberCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDeco('Kundennummer', hint: 'wird automatisch vergeben'),
            onChanged: (_) async {
              _schedulePreviewRefresh();
              if (widget.invoiceId != null) return;
              final pattern = _numberPattern();
              if (!pattern.contains('{KUNDENNR')) return;
              final existingNumbers = await _dbService.getAllInvoiceNumbers();
              if (!mounted) return;
              setState(() {
                _invoiceNumberCtrl.text = InvoiceNumberGenerator.generate(
                  pattern: pattern,
                  existingNumbers: existingNumbers,
                  customerName: _customerNameCtrl.text,
                  customerNumber: int.tryParse(_customerNumberCtrl.text),
                );
              });
            },
          ),
          const SizedBox(height: 12),
          _field(_customerNameCtrl, 'Firma / Name *', required: true),
          const SizedBox(height: 12),
          _field(_customerStreetCtrl, 'Straße & Hausnummer'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_customerZipcodeCtrl, 'PLZ')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _field(_customerCityCtrl, 'Ort')),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              if (_customerNameCtrl.text.isEmpty) {
                _showError('Name erforderlich');
                return;
              }
              try {
                final customer = CustomerModel(
                  id: const Uuid().v4(),
                  customerNumber: int.tryParse(_customerNumberCtrl.text),
                  name: _customerNameCtrl.text,
                  street: _customerStreetCtrl.text,
                  zipcode: _customerZipcodeCtrl.text,
                  city: _customerCityCtrl.text,
                  createdAt: DateTime.now(),
                );
                await _dbService.insertCustomer(customer);
                // Kundennummer aus DB zurücklesen wenn auto-vergeben
                if (_customerNumberCtrl.text.isEmpty && mounted) {
                  final saved = await _dbService.getCustomer(customer.id);
                  if (saved?.customerNumber != null && mounted) {
                    setState(() {
                      _customerNumberCtrl.text = saved!.customerNumber.toString();
                    });
                  }
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Kunde im Adressbuch gespeichert'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) _showError('Speichern fehlgeschlagen: $e');
              }
            },
            icon: const Icon(Icons.save_outlined, color: _peach),
            label: const Text('Im Adressbuch speichern',
                style: TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
            ),
          ),
          const SizedBox(height: 32),
          NextTabButton(
            label: 'Weiter zur Rechnung',
            onPressed: () => _tabController.animateTo(3),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 4: RECHNUNG
  // ══════════════════════════════════════════════════════════════
  Widget _buildInvoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Rechnungsinformationen'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _field(_invoiceNumberCtrl, 'Rechnungsnummer',
                    hint: 'z.B. RE-2024-001')),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _invoiceDateCtrl,
                readOnly: true,
                decoration: _inputDeco('Datum *'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    _invoiceDateCtrl.text = AppUtils.formatDate(date);
                    _schedulePreviewRefresh();
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _field(_paymentTermsCtrl, 'Zahlungsziel (Tage)',
              keyboardType: TextInputType.number, hint: '14'),
          const SizedBox(height: 24),

          _sectionTitle('Zusatzinformationen'),
          const SizedBox(height: 4),
          Text('z.B. Lieferhinweise, Bestellnummer (max. 4 Zeilen)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8a8a94))),
          const SizedBox(height: 10),
          TextField(
            controller: _additionalInfoCtrl,
            maxLines: 4,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco('Zusatzinformationen',
                hint: 'z.B. Lieferung erfolgt innerhalb von 3 Werktagen'),
          ),
          const SizedBox(height: 24),

          _sectionTitle('Preismodus & Standard-MwSt.'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                  controller: _taxRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('Standard-MwSt. (%)', hint: '19'),
                  onChanged: (_) => setState(() {}),
                )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preiseingabe',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8a8a94))),
                  const SizedBox(height: 4),
                  _priceToggle(),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          _sectionTitle('Rechnungspositionen'),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (ctx, i) => InvoiceItemWidget(
              key: ValueKey(_items[i].id),
              item: _items[i],
              index: i,
              onUpdate: _updateItem,
              onRemove: _removeItem,
            ),
          ),
          const SizedBox(height: 12),
          GradientButton.success(
            label: '+ Position hinzufügen',
            icon: Icons.add,
            onPressed: _showAddItemSheet,
          ),
          const SizedBox(height: 24),

          _buildSummary(),
          const SizedBox(height: 24),

          GradientButton.success(
            label: '📄 PDF generieren',
            onPressed: _previewPdf,
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Speichern',
            icon: Icons.save_outlined,
            onPressed: _saveInvoice,
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Speichern & Senden',
            icon: Icons.mail_outline,
            onPressed: _isLoading ? null : _saveAndSend,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Zusammenfassung ──────────────────────────────────────────
  Widget _buildSummary() {
    final totals = _calculateTotals();
    final byRate = _calculateTotalsByRate();
    final subtotal = totals['subtotal']!;
    final total = totals['total']!;
    final sortedRates = byRate.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181c),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14ffffff)),
      ),
      child: Column(children: [
        _summaryRow(
            'Netto (${_isGrossPrice ? 'berechnet' : 'eingegeben'}):',
            AppUtils.formatCurrency(subtotal)),
        const SizedBox(height: 6),
        // Eine MwSt-Zeile pro Steuersatz
        for (final rate in sortedRates) ...[
          _summaryRow(
            'MwSt. (${rate == rate.truncateToDouble() ? rate.toInt() : rate.toString().replaceAll('.', ',')} %):',
            AppUtils.formatCurrency(byRate[rate]!['vat']!),
          ),
          const SizedBox(height: 4),
        ],
        const Divider(height: 16),
        _summaryRow('Gesamtbetrag:', AppUtils.formatCurrency(total),
            bold: true, valueColor: _peach, fontSize: 16),
      ]),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor, double fontSize = 13}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: fontSize);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 8),
        Text(value,
            style: style.copyWith(
                color: valueColor,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  // ── Brutto/Netto Toggle ──────────────────────────────────────
  Widget _priceToggle() {
    return ToggleButtons(
      isSelected: [_isGrossPrice, !_isGrossPrice],
      onPressed: (i) {
        setState(() => _isGrossPrice = i == 0);
        _schedulePreviewRefresh();
      },
      borderRadius: BorderRadius.circular(8),
      selectedColor: Colors.white,
      fillColor: _peach,
      color: const Color(0xFF8a8a94),
      constraints: const BoxConstraints(minHeight: 32, minWidth: 56),
      textStyle: const TextStyle(fontSize: 13),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Brutto'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Netto'),
        ),
      ],
    );
  }

  // ── Helper-Widgets ───────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: _peach));
  }

  double _parseTaxRate() =>
      double.tryParse(_taxRateCtrl.text.replaceAll(',', '.')) ?? 19;

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: _inputDeco(label, hint: hint, required: required),
    );
  }

  InputDecoration _inputDeco(String label,
      {String? hint, bool required = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _peach, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF8a8a94)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _assetStatusCard({
    required IconData icon,
    required String label,
    required bool active,
    required String activeText,
    required String inactiveText,
  }) {
    final color =
        active ? AppConstants.successColor : const Color(0xFF5a5a64);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? AppConstants.successColor.withAlpha(20)
            : const Color(0xFF202024),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Icon(active ? Icons.check_circle : icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(active ? activeText : inactiveText,
              style: TextStyle(color: color, fontSize: 13)),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final ctrl in _previewControllers) {
      ctrl.removeListener(_schedulePreviewRefresh);
    }
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyStreetCtrl.dispose();
    _companyZipcodeCtrl.dispose();
    _companyCityCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyTaxIdCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _companyIbanCtrl.dispose();
    _companyBicCtrl.dispose();
    _companyBankCtrl.dispose();
    _companyAccountHolderCtrl.dispose();
    _companyPaypalCtrl.dispose();
    _customerNumberCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerStreetCtrl.dispose();
    _customerZipcodeCtrl.dispose();
    _customerCityCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _taxRateCtrl.dispose();
    _additionalInfoCtrl.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADRESSBUCH-PICKER (Dialog)
// ═══════════════════════════════════════════════════════════════
class _AddressPickerDialog extends StatefulWidget {
  const _AddressPickerDialog({Key? key}) : super(key: key);

  @override
  State<_AddressPickerDialog> createState() => _AddressPickerDialogState();
}

class _AddressPickerDialogState extends State<_AddressPickerDialog> {
  final _db = DatabaseService();
  List<CustomerModel> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getAllCustomers();
    if (mounted) setState(() { _customers = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kunde auswählen'),
      content: SizedBox(
        width: 320,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _customers.isEmpty
                ? const Text('Noch keine Kunden vorhanden.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _customers.length,
                    itemBuilder: (_, i) {
                      final c = _customers[i];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(c.name),
                        subtitle: Text('${c.zipcode} ${c.city}'),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

// ── Artikel-Picker Bottom Sheet ───────────────────────────────────────────────

class _ArticlePickerSheet extends StatefulWidget {
  final List<InvoiceItemModel> articles;
  final void Function(InvoiceItemModel) onArticleSelected;
  final VoidCallback onEmptyItem;

  const _ArticlePickerSheet({
    required this.articles,
    required this.onArticleSelected,
    required this.onEmptyItem,
  });

  @override
  State<_ArticlePickerSheet> createState() => _ArticlePickerSheetState();
}

class _ArticlePickerSheetState extends State<_ArticlePickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<InvoiceItemModel> _filtered;
  final Map<String, int> _addedCount = {};

  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.articles);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.articles)
          : widget.articles
              .where((a) => a.description.toLowerCase().contains(q))
              .toList();
    });
  }

  void _pick(InvoiceItemModel article) {
    setState(() {
      _addedCount[article.id] = (_addedCount[article.id] ?? 0) + 1;
    });
    widget.onArticleSelected(article);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF8a8a94),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Titel
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Artikel wählen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Suche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Artikel-Liste
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final a = _filtered[i];
                final count = _addedCount[a.id] ?? 0;
                return ListTile(
                  dense: true,
                  title: Text(a.description,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${a.price.toStringAsFixed(2).replaceAll('.', ',')} € · ${a.unit}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8a8a94)),
                  ),
                  trailing: GestureDetector(
                    onTap: () => _pick(a),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? _peach
                            : _peach.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _peach),
                      ),
                      child: Center(
                        child: count > 0
                            ? Text(
                                '+$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              )
                            : const Icon(Icons.add,
                                color: _peach, size: 20),
                      ),
                    ),
                  ),
                  onTap: () => _pick(a),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Leere Position
          ListTile(
            leading: const Icon(Icons.add_box_outlined,
                color: Color(0xFF8a8a94)),
            title: const Text('Leere Position',
                style: TextStyle(color: Color(0xFF8a8a94))),
            onTap: () {
              widget.onEmptyItem();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
