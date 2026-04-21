import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late APIService apiService;
  late Future<Map<String, dynamic>> statisticsFuture;

  @override
  void initState() {
    super.initState();
    apiService = APIService();
    statisticsFuture = _loadStatistics();
  }

  Future<Map<String, dynamic>> _loadStatistics() async {
    try {
      final invoices = await apiService.getInvoices();
      final customers = await apiService.getCustomers();

      // Berechne Statistiken
      double totalRevenue = 0;
      int totalInvoices = invoices.length;
      int paidInvoices = 0;
      int pendingInvoices = 0;

      for (var invoice in invoices) {
        totalRevenue += invoice.amount;
        if (invoice.status == 'paid') {
          paidInvoices++;
        } else {
          pendingInvoices++;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'totalInvoices': totalInvoices,
        'totalCustomers': customers.length,
        'paidInvoices': paidInvoices,
        'pendingInvoices': pendingInvoices,
        'invoices': invoices,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            statisticsFuture = _loadStatistics();
          });
        },
        child: FutureBuilder<Map<String, dynamic>>(
          future: statisticsFuture,
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          statisticsFuture = _loadStatistics();
                        });
                      },
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              );
            }

            final stats = snapshot.data!;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Statistik Cards
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'Gesamtumsatz',
                          value: '€${stats['totalRevenue'].toStringAsFixed(2)}',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                        _StatCard(
                          title: 'Rechnungen',
                          value: '${stats['totalInvoices']}',
                          icon: Icons.receipt,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          title: 'Kunden',
                          value: '${stats['totalCustomers']}',
                          icon: Icons.people,
                          color: Colors.purple,
                        ),
                        _StatCard(
                          title: 'Bezahlt',
                          value: '${stats['paidInvoices']}',
                          icon: Icons.check_circle,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Letzte Rechnungen
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Letzte Rechnungen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if ((stats['invoices'] as List).isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('Keine Rechnungen vorhanden'),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (stats['invoices'] as List).length,
                        itemBuilder: (context, index) {
                          final invoice = (stats['invoices'] as List)[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Rechnung #${invoice.invoiceNumber}'),
                              subtitle: Text(
                                '${invoice.customerName} - €${invoice.amount.toStringAsFixed(2)}',
                              ),
                              trailing: Chip(
                                label: Text(invoice.status),
                                backgroundColor: invoice.status == 'paid'
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
