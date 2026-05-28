import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/feedback_actions.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({Key? key}) : super(key: key);

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late DatabaseService _dbService;
  late SyncService _syncService;

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _zipcodeController;
  late TextEditingController _phoneController;
  late TextEditingController _taxIdController;
  late TextEditingController _websiteController;
  late TextEditingController _accountHolderController;
  late TextEditingController _ibanController;
  late TextEditingController _bicController;
  late TextEditingController _bankController;
  late TextEditingController _paypalController;

  CompanyModel? _company;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _zipcodeController = TextEditingController();
    _phoneController = TextEditingController();
    _taxIdController = TextEditingController();
    _websiteController = TextEditingController();
    _accountHolderController = TextEditingController();
    _ibanController = TextEditingController();
    _bicController = TextEditingController();
    _bankController = TextEditingController();
    _paypalController = TextEditingController();

    _loadCompany();
  }

  Future<void> _loadCompany() async {
    try {
      final companies = await _dbService.getAllCompanies();
      if (companies.isNotEmpty) {
        _company = companies.first;
        _populateForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateForm() {
    if (_company == null) return;

    _nameController.text = _company!.name;
    _emailController.text = _company!.email;
    _streetController.text = _company!.street;
    _cityController.text = _company!.city;
    _zipcodeController.text = _company!.zipcode;
    _phoneController.text = _company!.phone;
    _taxIdController.text = _company!.taxId ?? '';
    _websiteController.text = _company!.website ?? '';
    _accountHolderController.text = _company!.accountHolder ?? '';
    _ibanController.text = _company!.iban ?? '';
    _bicController.text = _company!.bic ?? '';
    _bankController.text = _company!.bank ?? '';
    _paypalController.text = _company!.paypal ?? '';
  }

  Future<void> _saveCompany() async {
    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    try {
      final company = CompanyModel(
        id: _company?.id ?? const Uuid().v4(),
        name: _nameController.text,
        email: _emailController.text,
        street: _streetController.text,
        city: _cityController.text,
        zipcode: _zipcodeController.text,
        phone: _phoneController.text,
        taxId: _taxIdController.text.isEmpty ? null : _taxIdController.text,
        website: _websiteController.text.isEmpty ? null : _websiteController.text,
        accountHolder: _accountHolderController.text.isEmpty
            ? null
            : _accountHolderController.text,
        iban: _ibanController.text.isEmpty ? null : _ibanController.text,
        bic: _bicController.text.isEmpty ? null : _bicController.text,
        bank: _bankController.text.isEmpty ? null : _bankController.text,
        paypal: _paypalController.text.isEmpty ? null : _paypalController.text,
        createdAt: _company?.createdAt ?? DateTime.now(),
      );

      await _dbService.insertCompany(company);

      // Create default design settings if not exists
      final existingDesign = await _dbService.getDesignSettings(company.id);
      if (existingDesign == null) {
        final defaultDesign = DesignSettingsModel(
          id: const Uuid().v4(),
          companyId: company.id,
          createdAt: DateTime.now(),
        );
        await _dbService.insertDesignSettings(defaultDesign);
      }

      // Add to sync queue
      _syncService.addToQueue(
        operation: _company == null ? 'CREATE' : 'UPDATE',
        entityType: 'COMPANY',
        data: company.toMap(),
      );

      _company = company;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firmendaten gespeichert')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty) {
      _showError('Firmennamen erforderlich');
      return false;
    }
    if (_emailController.text.isEmpty) {
      _showError('Email erforderlich');
      return false;
    }
    if (!AppUtils.isValidEmail(_emailController.text)) {
      _showError('Ungültige Email-Adresse');
      return false;
    }
    if (_streetController.text.isEmpty || _cityController.text.isEmpty) {
      _showError('Adresse erforderlich');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firmendaten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmendaten'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveCompany,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
            ),
          ),
          const FeedbackActions(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic info section
            _buildSectionHeader('Grundinformationen'),
            _buildTextField('Firmenname *', _nameController),
            const SizedBox(height: 12),
            _buildTextField('Email *', _emailController,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildTextField('Telefon *', _phoneController,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildTextField('Website', _websiteController,
                keyboardType: TextInputType.url),
            const SizedBox(height: 24),

            // Address section
            _buildSectionHeader('Adresse'),
            _buildTextField('Straße *', _streetController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextField('PLZ *', _zipcodeController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextField('Stadt *', _cityController),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tax info section
            _buildSectionHeader('Steuern'),
            _buildTextField('Steuernummer / USt-IdNr.', _taxIdController),
            const SizedBox(height: 24),

            // Bank info section
            _buildSectionHeader('Bankverbindung'),
            _buildTextField('Kontoinhaber', _accountHolderController),
            const SizedBox(height: 12),
            _buildTextField('IBAN', _ibanController),
            const SizedBox(height: 12),
            _buildTextField('BIC', _bicController),
            const SizedBox(height: 12),
            _buildTextField('Bank', _bankController),
            const SizedBox(height: 24),

            // Payment section
            _buildSectionHeader('Zahlungsmethoden'),
            _buildTextField('PayPal Email', _paypalController,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 32),

            // Save button at bottom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveCompany,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Firmendaten speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFFfda085),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipcodeController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _websiteController.dispose();
    _accountHolderController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _bankController.dispose();
    _paypalController.dispose();
    super.dispose();
  }
}
