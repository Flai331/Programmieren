import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/invoice_item_model.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({Key? key}) : super(key: key);

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late APIService apiService;
  late Future<List<InvoiceItem>> articlesFuture;
  final searchController = TextEditingController();
  List<InvoiceItem> filteredArticles = [];

  @override
  void initState() {
    super.initState();
    apiService = APIService();
    articlesFuture = _loadArticles();
    searchController.addListener(_filterArticles);
  }

  Future<List<InvoiceItem>> _loadArticles() async {
    try {
      // In einer echten App würde dies von der API kommen
      // Für jetzt verwenden wir lokale Daten
      return [];
    } catch (e) {
      rethrow;
    }
  }

  void _filterArticles() {
    setState(() {
      if (searchController.text.isEmpty) {
        // Alle Artikel anzeigen
      } else {
        // Artikel filtern
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel'),
        elevation: 0,
      ),
      body: FutureBuilder<List<InvoiceItem>>(
        future: articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Fehler: ${snapshot.error}'),
                ],
              ),
            );
          }

          final articles = snapshot.data ?? [];

          return Column(
            children: [
              // Suchleiste
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Artikel suchen...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              // Artikel Liste
              Expanded(
                child: articles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text('Keine Artikel vorhanden'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Artikel hinzufügen
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Artikel hinzufügen'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(article.description),
                              subtitle: Text('€${article.unitPrice.toStringAsFixed(2)}'),
                              trailing: const Icon(Icons.edit),
                              onTap: () {
                                // Artikel bearbeiten
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Neuer Artikel Dialog
        },
        tooltip: 'Artikel hinzufügen',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
