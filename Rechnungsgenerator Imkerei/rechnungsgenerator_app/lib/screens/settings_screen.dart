import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'company_screen.dart';
import 'design_customizer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verbindungsstatus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ConnectivityService>(
              builder: (context, connectivity, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: connectivity.isOnline
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              connectivity.isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          connectivity.isOnline
                              ? 'Die App ist mit dem Internet verbunden'
                              : 'Die App funktioniert offline. Änderungen werden später synchronisiert.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Synchronisierung',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer2<ConnectivityService, SyncService>(
              builder: (context, connectivity, sync, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sync.pendingSyncCount} Einträge warten auf Synchronisierung',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (sync.lastSyncTime != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Zuletzt synchronisiert: ${AppUtils.formatDateTime(sync.lastSyncTime!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (sync.lastSyncError != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fehler: ${sync.lastSyncError}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: sync.isSyncing
                                ? null
                                : () async {
                                    await sync.syncInvoicesManual();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Synchronisierung abgeschlossen'),
                                      ),
                                    );
                                  },
                            icon: sync.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: const Text('Jetzt synchronisieren'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Unternehmenseinstellungen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CompanyScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.business),
                label: const Text('Firmendaten'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FutureBuilder<List<CompanyModel>>(
                future: DatabaseService().getAllCompanies(),
                builder: (context, snapshot) {
                  final companyId = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!.first.id
                      : 'default';

                  return ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DesignCustomizerScreen(
                            companyId: companyId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.palette),
                    label: const Text('Design & Vorlagen'),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'App-Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Anwendung', AppConstants.appName),
                    const SizedBox(height: 8),
                    _buildInfoRow('Version', AppConstants.appVersion),
                    const SizedBox(height: 8),
                    _buildInfoRow('Datenbankversion', AppConstants.dbVersion.toString()),
                    const SizedBox(height: 8),
                    _buildInfoRow('API-Version', AppConstants.apiVersion),
                    const SizedBox(height: 8),
                    _buildInfoRow('Status', '✓ Einsatzbereit'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
