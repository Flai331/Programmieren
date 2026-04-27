import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../utils/feedback_service.dart';
import '../widgets/invoice_item_widget.dart';
import '../widgets/gradient_button.dart';
import 'pdf_preview_screen.dart';
import 'design_customizer_screen.dart';
import 'address_book_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  INVOICE EDIT SCREEN — 4-Tab-Wizard (wie HTML-Referenz)
//  Tabs: Design | Absender | Empfänger | Rechnung
// ═══════════════════════════════════════════════════════════════

class InvoiceEditScreen extends StatefulWidget {
  final String? invoiceId;

  const InvoiceEditScreen({Key? key, this.invoiceId}) : super(key: key);

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen>
    with SingleTickerProviderStateMixin {
  late DatabaseService _dbService;
  late SyncService _syncService;
  late TabController _tabController;

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
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerStreetCtrl;
  late TextEditingController _customerZipcodeCtrl;
  late TextEditingController _customerCityCtrl;

  // ── Tab 4: Rechnung ──────────────────────────────────────────
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _invoiceDateCtrl;
  late TextEditingController _paymentTermsCtrl;
  late TextEditingController _taxRateCtrl;
  late TextEditingController _headerTextCtrl;
  late TextEditingController _headerTextSizeCtrl;
  late TextEditingController _additionalInfoCtrl;

  bool _isGrossPrice = true;
  List<InvoiceItemModel> _items = [];

  InvoiceModel? _currentInvoice;
  CompanyModel? _company;
  DesignSettingsModel? _designSettings;
  bool _isLoading = false;

  static const Color _peach = Color(0xFFfda085);

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

    _customerNameCtrl = TextEditingController();
    _customerStreetCtrl = TextEditingController();
    _customerZipcodeCtrl = TextEditingController();
    _customerCityCtrl = TextEditingController();

    _invoiceNumberCtrl = TextEditingController();
    _invoiceDateCtrl = TextEditingController();
    _paymentTermsCtrl = TextEditingController(text: '14');
    _taxRateCtrl = TextEditingController(text: '19');
    _headerTextCtrl = TextEditingController();
    _headerTextSizeCtrl = TextEditingController(text: '24');
    _additionalInfoCtrl = TextEditingController();

    FeedbackService.logScreenLoad('InvoiceEdit',
        additionalInfo: widget.invoiceId == null ? 'neu' : 'bearbeiten');
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      // Firmendaten laden
      final companies = await _dbService.getAllCompanies();
      if (companies.isNotEmpty) {
        _company = companies.first;
        _fillCompanyFields(_company!);
      }

      // Design-Einstellungen laden
      if (_company != null) {
        _designSettings = await _dbService.getDesignSettings(_company!.id);
      }

      if (widget.invoiceId != null) {
        // Bestehende Rechnung laden
        _currentInvoice = await _dbService.getInvoice(widget.invoiceId!);
        _items = await _dbService.getInvoiceItems(widget.invoiceId!);
        _populateForm();
      } else {
        // Neue Rechnung – Nummer generieren
        final lastNumber = await _dbService.getLastInvoiceNumber();
        final nextNumber = _parseInvoiceNumber(lastNumber) + 1;
        _invoiceNumberCtrl.text = AppUtils.generateInvoiceNumber(
            AppConstants.defaultInvoiceNumberPrefix, nextNumber);
        _invoiceDateCtrl.text = AppUtils.formatDate(DateTime.now());
      }
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'InvoiceEdit._initialize');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    _headerTextCtrl.text = _currentInvoice!.headerText ?? '';
    _headerTextSizeCtrl.text = _currentInvoice!.headerTextSize.toString();
    _isGrossPrice = _currentInvoice!.isGrossPrice;
    _loadCustomerData(_currentInvoice!.customerId);
  }

  Future<void> _loadCustomerData(String customerId) async {
    final customer = await _dbService.getCustomer(customerId);
    if (customer != null && mounted) {
      setState(() {
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
      final customerId = _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
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
        taxRate: double.tryParse(_taxRateCtrl.text) ?? 19,
        subtotal: totals['subtotal']!,
        vat: totals['vat']!,
        total: totals['total']!,
        createdAt: _currentInvoice?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        headerText: _headerTextCtrl.text.isEmpty ? null : _headerTextCtrl.text,
        headerTextSize: int.tryParse(_headerTextSizeCtrl.text) ?? 24,
        isGrossPrice: _isGrossPrice,
      );

      await _dbService.insertInvoice(invoice);
      for (var item in _items) {
        await _dbService.insertInvoiceItem(item);
      }

      _syncService.addToQueue(
        operation: _currentInvoice == null ? 'CREATE' : 'UPDATE',
        entityType: 'INVOICE',
        data: invoice.toMap(),
      );

      FeedbackService.logUserAction('Rechnung gespeichert',
          context: {'nr': invoice.invoiceNumber});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Rechnung gespeichert')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'saveInvoice');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PDF-Vorschau ─────────────────────────────────────────────
  Future<void> _previewPdf() async {
    if (!_validateForm()) return;
    try {
      final customerId = _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        name: _customerNameCtrl.text,
        street: _customerStreetCtrl.text,
        zipcode: _customerZipcodeCtrl.text,
        city: _customerCityCtrl.text,
        createdAt: DateTime.now(),
      );
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
        taxRate: double.tryParse(_taxRateCtrl.text) ?? 19,
        subtotal: totals['subtotal']!,
        vat: totals['vat']!,
        total: totals['total']!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        headerText: _headerTextCtrl.text.isEmpty ? null : _headerTextCtrl.text,
        headerTextSize: int.tryParse(_headerTextSizeCtrl.text) ?? 24,
        isGrossPrice: _isGrossPrice,
      );

      final companyForPdf = _buildCompanyFromFields();
      final ds = _designSettings ??
          DesignSettingsModel(
            id: const Uuid().v4(),
            companyId: _company?.id ?? 'default',
            headerTextColor: '#fda085',
            headerTextSize: 18,
            createdAt: DateTime.now(),
          );

      FeedbackService.logUserAction('PDF-Vorschau geöffnet');
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
      FeedbackService.logError(e.toString(), context: 'previewPdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  CompanyModel _buildCompanyFromFields() {
    return CompanyModel(
      id: _company?.id ?? 'default',
      name: _companyNameCtrl.text.isEmpty ? 'Meine Imkerei' : _companyNameCtrl.text,
      email: _companyEmailCtrl.text,
      street: _companyStreetCtrl.text,
      city: _companyCityCtrl.text,
      zipcode: _companyZipcodeCtrl.text,
      phone: _companyPhoneCtrl.text,
      taxId: _companyTaxIdCtrl.text.isEmpty ? null : _companyTaxIdCtrl.text,
      website: _companyWebsiteCtrl.text.isEmpty ? null : _companyWebsiteCtrl.text,
      iban: _companyIbanCtrl.text.isEmpty ? null : _companyIbanCtrl.text,
      bic: _companyBicCtrl.text.isEmpty ? null : _companyBicCtrl.text,
      bank: _companyBankCtrl.text.isEmpty ? null : _companyBankCtrl.text,
      accountHolder: _companyAccountHolderCtrl.text.isEmpty
          ? null
          : _companyAccountHolderCtrl.text,
      paypal: _companyPaypalCtrl.text.isEmpty ? null : _companyPaypalCtrl.text,
      createdAt: _company?.createdAt ?? DateTime.now(),
    );
  }

  Map<String, double> _calculateTotals() {
    double subtotal = 0;
    for (var item in _items) {
      subtotal += _isGrossPrice
          ? item.total / (1 + (double.tryParse(_taxRateCtrl.text) ?? 19) / 100)
          : item.total;
    }
    final taxRate = double.tryParse(_taxRateCtrl.text) ?? 19;
    final vat = AppUtils.calculateTax(subtotal, taxRate);
    final total = AppUtils.calculateTotal(subtotal, vat);
    return {'subtotal': subtotal, 'vat': vat, 'total': total};
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

  void _addItem() {
    final newItem = InvoiceItemModel(
      id: const Uuid().v4(),
      invoiceId: _currentInvoice?.id ?? '',
      description: '',
      quantity: 1,
      unit: 'Stk.',
      price: 0,
      taxRate: double.tryParse(_taxRateCtrl.text) ?? 19,
      createdAt: DateTime.now(),
    );
    setState(() => _items.add(newItem));
    FeedbackService.logUserAction('Position hinzugefügt');
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateItem(int index, InvoiceItemModel item) {
    setState(() => _items[index] = item);
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rechnung')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentInvoice == null ? 'Neue Rechnung' : 'Rechnung bearbeiten'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.palette_outlined), text: 'Design'),
            Tab(icon: Icon(Icons.business_outlined), text: 'Absender'),
            Tab(icon: Icon(Icons.person_outline), text: 'Empfänger'),
            Tab(icon: Icon(Icons.receipt_outlined), text: 'Rechnung'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_outlined),
            tooltip: 'Vorschau',
            onPressed: _previewPdf,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Speichern',
            onPressed: _saveInvoice,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDesignTab(),
          _buildSenderTab(),
          _buildRecipientTab(),
          _buildInvoiceTab(),
        ],
      ),
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

          // Logo Status
          _assetStatusCard(
            icon: Icons.image_outlined,
            label: 'Logo',
            active: hasLogo,
            activeText: 'Logo hochgeladen ✓',
            inactiveText: 'Kein Logo – optional',
          ),
          const SizedBox(height: 12),

          // Header-Bild Status
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
                    // Design-Einstellungen neu laden
                    final ds =
                        await _dbService.getDesignSettings(_company!.id);
                    if (mounted) setState(() => _designSettings = ds);
                    FeedbackService.logUserAction('Design bearbeitet');
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
            Expanded(child: _field(_companyBicCtrl, 'BIC', hint: 'COBADEFFXXX')),
            const SizedBox(width: 12),
            Expanded(child: _field(_companyBankCtrl, 'Bank', hint: 'Commerzbank')),
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

          // Aus Adressbuch wählen
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDialog<CustomerModel>(
                context: context,
                builder: (_) => const _AddressPickerDialog(),
              );
              if (selected != null && mounted) {
                setState(() {
                  _customerNameCtrl.text = selected.name;
                  _customerStreetCtrl.text = selected.street;
                  _customerZipcodeCtrl.text = selected.zipcode;
                  _customerCityCtrl.text = selected.city;
                });
                FeedbackService.logSelection('Kunde', selected.name);
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

          _field(_customerNameCtrl, 'Firma / Name *', required: true),
          const SizedBox(height: 12),
          _field(_customerStreetCtrl, 'Straße & Hausnummer'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_customerZipcodeCtrl, 'PLZ')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _field(_customerCityCtrl, 'Ort')),
          ]),
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
            Expanded(child: _field(_invoiceNumberCtrl, 'Rechnungsnummer',
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
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _field(_paymentTermsCtrl, 'Zahlungsziel (Tage)',
              keyboardType: TextInputType.number, hint: '14'),
          const SizedBox(height: 24),

          _sectionTitle('Firmenname über Adresse'),
          const SizedBox(height: 4),
          Text('Erscheint auf der Rechnung über der Absender-Adresse (max. 2 Zeilen)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          TextField(
            controller: _headerTextCtrl,
            maxLines: 2,
            maxLength: 120,
            decoration: _inputDeco('Firmenname / Slogan',
                hint: 'z.B. Imkerei Mustermann\nNatürlicher Honig aus der Region'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Schriftgröße: ', style: TextStyle(fontSize: 13)),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _headerTextSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('Pt').copyWith(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const Text(' pt (10–30)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 24),

          _sectionTitle('Zusatzinformationen'),
          const SizedBox(height: 4),
          Text('z.B. Lieferhinweise, Bestellnummer (max. 4 Zeilen)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          TextField(
            controller: _additionalInfoCtrl,
            maxLines: 4,
            maxLength: 300,
            decoration: _inputDeco('Zusatzinformationen',
                hint: 'z.B. Lieferung erfolgt innerhalb von 3 Werktagen'),
          ),
          const SizedBox(height: 24),

          _sectionTitle('Steuer & Preismodus'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_taxRateCtrl, 'MwSt.-Satz (%)',
                keyboardType: TextInputType.number, hint: '19')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preiseingabe', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
            onPressed: _addItem,
          ),
          const SizedBox(height: 24),

          // Zusammenfassung
          _buildSummary(),
          const SizedBox(height: 24),

          // PDF-Button
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Zusammenfassung ──────────────────────────────────────────
  Widget _buildSummary() {
    double subtotal = 0;
    final taxRate = double.tryParse(_taxRateCtrl.text) ?? 19;
    for (var item in _items) {
      subtotal += _isGrossPrice
          ? item.total / (1 + taxRate / 100)
          : item.total;
    }
    final vat = AppUtils.calculateTax(subtotal, taxRate);
    final total = AppUtils.calculateTotal(subtotal, vat);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        _summaryRow('Netto (${_isGrossPrice ? 'berechnet' : 'eingegeben'}):', AppUtils.formatCurrency(subtotal)),
        const SizedBox(height: 6),
        _summaryRow('MwSt. ($taxRate%):', AppUtils.formatCurrency(vat)),
        const Divider(height: 20),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value,
            style: style.copyWith(
                color: valueColor,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  // ── Brutto/Netto Toggle ──────────────────────────────────────
  Widget _priceToggle() {
    return Row(children: [
      _radioOption('Brutto', true),
      const SizedBox(width: 12),
      _radioOption('Netto', false),
    ]);
  }

  Widget _radioOption(String label, bool value) {
    return InkWell(
      onTap: () => setState(() => _isGrossPrice = value),
      child: Row(children: [
        Radio<bool>(
          value: value,
          groupValue: _isGrossPrice,
          activeColor: _peach,
          onChanged: (v) => setState(() => _isGrossPrice = v!),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  // ── Helper-Widgets ───────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _peach));
  }

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
      labelStyle: const TextStyle(color: Colors.grey),
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
    final color = active ? AppConstants.successColor : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? AppConstants.successColor.withAlpha(20)
            : Colors.grey.shade100,
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
    _customerNameCtrl.dispose();
    _customerStreetCtrl.dispose();
    _customerZipcodeCtrl.dispose();
    _customerCityCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _taxRateCtrl.dispose();
    _headerTextCtrl.dispose();
    _headerTextSizeCtrl.dispose();
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
