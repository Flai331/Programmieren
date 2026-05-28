import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({Key? key}) : super(key: key);

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late DatabaseService _dbService;
  List<CustomerModel> _customers = [];
  bool _loading = true;

  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _load();
  }

  Future<void> _load() async {
    final list = await _dbService.getAllCustomers();
    if (mounted) setState(() { _customers = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 64, color: Color(0xFF8a8a94)),
            const SizedBox(height: 16),
            const Text('Adressbuch ist leer'),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCustomerDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Adresse hinzufügen'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final c = _customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _peach.withOpacity(0.15),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: _peach, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (c.customerNumber != null) 'Kd.-Nr. ${c.customerNumber}',
                      if (c.street.isNotEmpty) c.street,
                      '${c.zipcode} ${c.city}'.trim(),
                    ].where((s) => s.isNotEmpty).join('\n'),
                  ),
                  isThreeLine: c.customerNumber != null || c.street.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _showCustomerDialog(context, customer: c);
                      if (value == 'delete') _showDeleteConfirmation(context, c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Bearbeiten'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Löschen', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showCustomerDialog(context),
            backgroundColor: _peach,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showCustomerDialog(BuildContext context, {CustomerModel? customer}) {
    final isEdit = customer != null;
    final numberCtrl = TextEditingController(
        text: customer?.customerNumber?.toString() ?? '');
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final streetCtrl = TextEditingController(text: customer?.street ?? '');
    final zipCtrl = TextEditingController(text: customer?.zipcode ?? '');
    final cityCtrl = TextEditingController(text: customer?.city ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Kunde bearbeiten' : 'Neuer Kunde'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: deco('Kundennummer', hint: 'wird automatisch vergeben'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: deco('Firma / Name *'),
                  autofocus: !isEdit,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: streetCtrl,
                  decoration: deco('Straße & Hausnummer'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: zipCtrl,
                      keyboardType: TextInputType.number,
                      decoration: deco('PLZ'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: cityCtrl,
                      decoration: deco('Ort'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: deco('Telefon'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: deco('E-Mail'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _peach),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name erforderlich')),
                );
                return;
              }
              final updated = CustomerModel(
                id: customer?.id ?? const Uuid().v4(),
                customerNumber: int.tryParse(numberCtrl.text),
                name: nameCtrl.text,
                street: streetCtrl.text,
                zipcode: zipCtrl.text,
                city: cityCtrl.text,
                phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                createdAt: customer?.createdAt ?? DateTime.now(),
                updatedAt: isEdit ? DateTime.now() : null,
              );
              if (isEdit) {
                await _dbService.updateCustomer(updated);
              } else {
                await _dbService.insertCustomer(updated);
              }
              Navigator.pop(ctx);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? '✓ Gespeichert' : '✓ Kunde angelegt'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(isEdit ? 'Speichern' : 'Anlegen',
                style: const TextStyle(color: Color(0xFF1a0e08))),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kunde löschen'),
        content: Text('"${customer.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await _dbService.deleteCustomer(customer.id);
              Navigator.pop(ctx);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kunde gelöscht')),
                );
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
