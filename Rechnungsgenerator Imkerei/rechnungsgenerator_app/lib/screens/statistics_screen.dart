import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late APIService apiService;
  late Future<Map<String, dynamic>> statisticsFuture;

  @override
  void initState() {
    super.initState();
    apiService = APIService();
    statisticsFuture = _loadDetailedStatistics();
  }

  Future<Map<String, dynamic>> _loadDetailedStatistics() async {
    try {
      final invoices = await apiService.getInvoices();

      double totalRevenue = 0;
      double paidAmount = 0;
      double pendingAmount = 0;
      Map<String, double> monthlyRevenue = {};

      for (var invoice in invoices) {
        totalRevenue += invoice.amount;

        if (invoice.status == 'paid') {
          paidAmount += invoice.amount;
        } else {
          pendingAmount += invoice.amount;
        }

        // Gruppiere nach Monat
        final month = invoice.createdAt.substring(0, 7); // YYYY-MM
        monthlyRevenue[month] = (monthlyRevenue[month] ?? 0) + invoice.amount;
      }

      return {
        'totalRevenue': totalRevenue,
        'paidAmount': paidAmount,
        'pendingAmount': pendingAmount,
        'monthlyRevenue': monthlyRevenue,
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
        title: const Text('Statistiken'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            statisticsFuture = _loadDetailedStatistics();
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
                  ],
                ),
              );
            }

            final stats = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Umsatz Übersicht
                    Text(
                      'Umsatzübersicht',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bezahlt'),
                                  const SizedBox(height: 8),
                                  Text(
                                    '€${(stats['paidAmount'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Ausstehend'),
                                  const SizedBox(height: 8),
                                  Text(
                                    '€${(stats['pendingAmount'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Kreisdiagramm
                    Text(
                      'Zahlungsstatus',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  color: Colors.green,
                                  value: stats['paidAmount'] as double,
                                  title: 'Bezahlt',
                                  radius: 80,
                                ),
                                PieChartSectionData(
                                  color: Colors.orange,
                                  value: stats['pendingAmount'] as double,
                                  title: 'Ausstehend',
                                  radius: 80,
                                ),
                              ],
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Leistungstabelle
                    Text(
                      'Top Kunden',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const ListTile(
                              title: Text('Kunde 1'),
                              trailing: Text('€1,234.56'),
                            ),
                            const Divider(),
                            const ListTile(
                              title: Text('Kunde 2'),
                              trailing: Text('€987.65'),
                            ),
                            const Divider(),
                            const ListTile(
                              title: Text('Kunde 3'),
                              trailing: Text('€654.32'),
                            ),
                          ],
                        ),
                      ),
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
