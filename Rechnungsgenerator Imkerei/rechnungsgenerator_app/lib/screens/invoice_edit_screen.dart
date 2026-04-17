import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/invoice_item_widget.dart';
import 'pdf_preview_screen.dart';

class InvoiceEditScreen extends StatefulWidget {
  final String? invoiceId;

  const InvoiceEditScreen({
    Key? key,
    this.invoiceId,
  }) : super(key: key);

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  late DatabaseService _dbService;
  late SyncService _syncService;

  // Form controllers
  late TextEditingController _invoiceNumberController;
  late TextEditingController _invoiceDateController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerStreetController;
  late TextEditingController _customerZipcodeController;
  late TextEditingController _customerCityController;
  late TextEditingController _paymentTermsController;
  late TextEditingController _additionalInfoController;
  late TextEditingController _taxRateController;

  InvoiceModel? _currentInvoice;
  CompanyModel? _company;
  List<InvoiceItemModel> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();

    _invoiceNumberController = TextEditingController();
    _invoiceDateController = TextEditingController();
    _customerNameController = TextEditingController();
    _customerStreetController = TextEditingController();
    _customerZipcodeController = TextEditingController();
    _customerCityController = TextEditingController();
    _paymentTermsController = TextEditingController(text: '14');
    _additionalInfoController = TextEditingController();
    _taxRateController = TextEditingController(text: '19');

    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // Load company data
      final companies = await _dbService.getAllCompanies();
      if (companies.isNotEmpty) {
        _company = companies.first;
      }

      // Load existing invoice if editing
      if (widget.invoiceId != null) {
        _currentInvoice = await _dbService.getInvoice(widget.invoiceId!);
        _items = await _dbService.getInvoiceItems(widget.invoiceId!);
        _populateForm();
      } else {
        // New invoice - generate number
        final lastNumber = await _dbService.getLastInvoiceNumber();
        final nextNumber = _parseInvoiceNumber(lastNumber) + 1;
        _invoiceNumberController.text =
            AppUtils.generateInvoiceNumber(AppConstants.defaultInvoiceNumberPrefix, nextNumber);
        _invoiceDateController.text = AppUtils.formatDate(DateTime.now());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _parseInvoiceNumber(String? number) {
    if (number == null) return 0;
    final parts = number.split('-');
    return int.tryParse(parts.last) ?? 0;
  }

  void _populateForm() {
    if (_currentInvoice == null) return;

    _invoiceNumberController.text = _currentInvoice!.invoiceNumber;
    _invoiceDateController.text = AppUtils.formatDate(_currentInvoice!.date);
    _paymentTermsController.text = _currentInvoice!.paymentTerms.toString();
    _additionalInfoController.text = _currentInvoice!.additionalInfo ?? '';
    _taxRateController.text = _currentInvoice!.taxRate.toString();

    // Load customer data
    _loadCustomerData(_currentInvoice!.customerId);
  }

  Future<void> _loadCustomerData(String customerId) async {
    final customer = await _dbService.getCustomer(customerId);
    if (customer != null) {
      _customerNameController.text = customer.name;
      _customerStreetController.text = customer.street;
      _customerZipcodeController.text = customer.zipcode;
      _customerCityController.text = customer.city;
    }
  }

  Future<void> _saveInvoice() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // Create or update customer
      final customerId = _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        name: _customerNameController.text,
        street: _customerStreetController.text,
        zipcode: _customerZipcodeController.text,
        city: _customerCityController.text,
        createdAt: _currentInvoice != null
            ? (await _dbService.getCustomer(customerId))?.createdAt ?? DateTime.now()
            : DateTime.now(),
      );
      await _dbService.insertCustomer(customer);

      // Calculate totals
      double subtotal = 0;
      for (var item in _items) {
        subtotal += item.total;
      }
      final taxRate = double.tryParse(_taxRateController.text) ?? 19;
      final tax = AppUtils.calculateTax(subtotal, taxRate);
      final total = AppUtils.calculateTotal(subtotal, tax);

      // Create or update invoice
      final invoice = InvoiceModel(
        id: _currentInvoice?.id ?? const Uuid().v4(),
        invoiceNumber: _invoiceNumberController.text,
        companyId: _company?.id ?? 'default',
        customerId: customerId,
        date: AppUtils.parseDate(_invoiceDateController.text) ?? DateTime.now(),
        paymentTerms: int.tryParse(_paymentTermsController.text) ?? 14,
        additionalInfo: _additionalInfoController.text.isEmpty ? null : _additionalInfoController.text,
        taxRate: taxRate,
        subtotal: subtotal,
        vat: tax,
        total: total,
        createdAt: _currentInvoice?.createdAt ?? DateTime.now(),
      );

      await _dbService.insertInvoice(invoice);

      // Save items
      for (var item in _items) {
        await _dbService.insertInvoiceItem(item);
      }

      // Add to sync queue
      _syncService.addToQueue(
        operation: _currentInvoice == null ? 'CREATE' : 'UPDATE',
        entityType: 'INVOICE',
        data: invoice.toMap(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rechnung gespeichert')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateForm()) return;

    try {
      // Create customer data from form
      final customerId = _currentInvoice?.customerId ?? const Uuid().v4();
      final customer = CustomerModel(
        id: customerId,
        name: _customerNameController.text,
        street: _customerStreetController.text,
        zipcode: _customerZipcodeController.text,
        city: _customerCityController.text,
        phone: '',
        email: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Calculate totals
      double subtotal = 0;
      for (var item in _items) {
        subtotal += item.total;
      }
      final taxRate = double.tryParse(_taxRateController.text) ?? 19;
      final tax = AppUtils.calculateTax(subtotal, taxRate);
      final total = AppUtils.calculateTotal(subtotal, tax);

      // Create invoice data
      final invoice = InvoiceModel(
        id: _currentInvoice?.id ?? const Uuid().v4(),
        invoiceNumber: _invoiceNumberController.text,
        companyId: _company?.id ?? 'default',
        customerId: customerId,
        date: AppUtils.parseDate(_invoiceDateController.text) ?? DateTime.now(),
        paymentTerms: int.tryParse(_paymentTermsController.text) ?? 14,
        additionalInfo: _additionalInfoController.text.isEmpty ? null : _additionalInfoController.text,
        taxRate: taxRate,
        subtotal: subtotal,
        vat: tax,
        total: total,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        synced: false,
      );

      // Get design settings
      late DesignSettingsModel designSettings;
      if (_company != null) {
        final settings = await _dbService.getDesignSettings(_company!.id);
        designSettings = settings ?? DesignSettingsModel(
          id: const Uuid().v4(),
          companyId: _company!.id,
          headerTextColor: '#fda085',
          headerTextSize: 18,
          createdAt: DateTime.now(),
        );
      } else {
        designSettings = DesignSettingsModel(
          id: const Uuid().v4(),
          companyId: 'default',
          headerTextColor: '#fda085',
          headerTextSize: 18,
          createdAt: DateTime.now(),
        );
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              invoice: invoice,
              company: _company ?? CompanyModel(
                id: 'default',
                name: 'Meine Imkerei',
                street: '',
                city: '',
                zipcode: '',
                phone: '',
                email: '',
                createdAt: DateTime.now(),
              ),
              customer: customer,
              items: _items,
              designSettings: designSettings,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _validateForm() {
    if (_invoiceNumberController.text.isEmpty) {
      _showError('Rechnungsnummer erforderlich');
      return false;
    }
    if (_customerNameController.text.isEmpty) {
      _showError('Kundennamen erforderlich');
      return false;
    }
    if (_items.isEmpty) {
      _showError('Mindestens ein Artikel erforderlich');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _addItem() {
    final newItem = InvoiceItemModel(
      id: const Uuid().v4(),
      invoiceId: _currentInvoice?.id ?? '',
      description: '',
      quantity: 1,
      unit: 'Stk.',
      price: 0,
      taxRate: double.tryParse(_taxRateController.text) ?? 19,
      createdAt: DateTime.now(),
    );

    setState(() {
      _items.add(newItem);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, InvoiceItemModel item) {
    setState(() {
      _items[index] = item;
    });
  }

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
        title: Text(_currentInvoice == null ? 'Neue Rechnung' : 'Rechnung bearbeiten'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.preview),
                  label: const Text('Vorschau'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _saveInvoice,
                  icon: const Icon(Icons.save),
                  label: const Text('Speichern'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic invoice info
            const Text('Rechnungsinformationen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Rechnungsnummer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _invoiceDateController,
                    decoration: const InputDecoration(
                      labelText: 'Datum',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        _invoiceDateController.text = AppUtils.formatDate(date);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer info
            const Text('Kundendaten',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Kundenname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerStreetController,
              decoration: const InputDecoration(
                labelText: 'Straße',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _customerZipcodeController,
                    decoration: const InputDecoration(
                      labelText: 'PLZ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _customerCityController,
                    decoration: const InputDecoration(
                      labelText: 'Stadt',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Items
            const Text('Rechnungspositionen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return InvoiceItemWidget(
                  item: _items[index],
                  index: index,
                  onUpdate: _updateItem,
                  onRemove: _removeItem,
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Artikel hinzufügen'),
              ),
            ),
            const SizedBox(height: 24),

            // Additional info
            const Text('Weitere Informationen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Steuersatz (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _paymentTermsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Zahlungsziel (Tage)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _additionalInfoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Zusätzliche Informationen',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildSummary(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    double subtotal = 0;
    for (var item in _items) {
      subtotal += item.total;
    }
    final taxRate = double.tryParse(_taxRateController.text) ?? 19;
    final tax = AppUtils.calculateTax(subtotal, taxRate);
    final total = AppUtils.calculateTotal(subtotal, tax);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zusammenfassung',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Zwischensumme:'),
            Text(AppUtils.formatCurrency(subtotal)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('USt. ($taxRate%):'),
            Text(AppUtils.formatCurrency(tax)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: Colors.grey,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Gesamtbetrag:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              AppUtils.formatCurrency(total),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFfda085),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _customerNameController.dispose();
    _customerStreetController.dispose();
    _customerZipcodeController.dispose();
    _customerCityController.dispose();
    _paymentTermsController.dispose();
    _additionalInfoController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }
}
