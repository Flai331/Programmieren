import 'package:flutter/material.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({Key? key}) : super(key: key);

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerModel>>(
      future: _dbService.getAllCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final customers = snapshot.data ?? [];

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.contacts, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Adressbuch ist leer'),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _showAddressDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adresse hinzufügen'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(customer.name),
                  subtitle: Text(
                    '${customer.street}\n${customer.zipcode} ${customer.city}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _showDeleteConfirmation(context, customer);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Löschen'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddressDialog(BuildContext context) {
    final nameController = TextEditingController();
    final streetController = TextEditingController();
    final zipcodeController = TextEditingController();
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Adresse'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: streetController,
                decoration: const InputDecoration(labelText: 'Straße'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: zipcodeController,
                      decoration: const InputDecoration(labelText: 'PLZ'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'Stadt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty || cityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bitte alle Felder füllen')),
                );
                return;
              }

              final customer = CustomerModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                street: streetController.text,
                zipcode: zipcodeController.text,
                city: cityController.text,
                createdAt: DateTime.now(),
              );

              await _dbService.insertCustomer(customer);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Adresse gespeichert')),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adresse löschen'),
        content: Text('Wollen Sie die Adresse "${customer.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await _dbService.deleteCustomer(customer.id);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Adresse gelöscht')),
              );
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
