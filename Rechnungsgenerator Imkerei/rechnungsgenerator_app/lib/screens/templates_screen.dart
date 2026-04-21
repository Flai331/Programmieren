import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({Key? key}) : super(key: key);

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late APIService apiService;
  late Future<List<Map<String, dynamic>>> templatesFuture;

  @override
  void initState() {
    super.initState();
    apiService = APIService();
    templatesFuture = _loadTemplates();
  }

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    try {
      // Beispiel Templates
      return [
        {
          'id': '1',
          'name': 'Standard',
          'description': 'Einfache weiße Vorlage',
          'color': Colors.white,
        },
        {
          'id': '2',
          'name': 'Modern',
          'description': 'Moderne Designvorlage',
          'color': Colors.blue.shade50,
        },
        {
          'id': '3',
          'name': 'Premium',
          'description': 'Elegante Premium-Vorlage',
          'color': Colors.purple.shade50,
        },
      ];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorlagen'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}'),
            );
          }

          final templates = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      color: template['color'],
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template['description'],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  // Template anwenden
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${template['name']} angewandt'),
                                    ),
                                  );
                                },
                                child: const Text('Anwenden'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  // Template bearbeiten
                                },
                                child: const Text('Bearbeiten'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Neue Vorlage erstellen
        },
        tooltip: 'Neue Vorlage',
        child: const Icon(Icons.add),
      ),
    );
  }
}
