// ═══════════════════════════════════════════════════════════════
//  Behandlungen Liste
//  lib/behandlungen/behandlungen_list_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/behandlung.dart';
import '../models/volk.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';
import 'behandlung_form_screen.dart';

class BehandlungenListScreen extends StatefulWidget {
  const BehandlungenListScreen({super.key});

  @override
  State<BehandlungenListScreen> createState() => _BehandlungenListScreenState();
}

class _BehandlungenListScreenState extends State<BehandlungenListScreen> {
  List<Behandlung> _behandlungen = [];
  List<Volk>       _voelker      = [];
  List<Standort>   _standorte    = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final b = await StorageService.loadBehandlungen();
    final v = await StorageService.loadVoelker();
    final s = await StorageService.loadStandorte();
    if (!mounted) return;
    setState(() {
      _behandlungen = b..sort((a, b) => b.datum.compareTo(a.datum));
      _voelker      = v;
      _standorte    = s;
      _loading      = false;
    });
  }

  String _standortName(String id) {
    try {
      return _standorte.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return 'Unbekannt';
    }
  }

  String _volkName(String id) {
    if (id.isEmpty) return 'Alle Völker';
    try {
      return _voelker.firstWhere((v) => v.id == id).name;
    } catch (_) {
      return 'Unbekannt';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Behandlungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : _behandlungen.isEmpty
              ? _leereAnzeige()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _behandlungen.length,
                  itemBuilder: (_, i) => _karte(_behandlungen[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BehandlungFormScreen()),
        ).then((_) => _laden()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _karte(Behandlung b) {
    final isVarroa = b.typ.isVarroa;
    final color = isVarroa ? AppColors.red : AppColors.orange;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d. MMMM yyyy', 'de_DE').format(b.datum),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                if (b.bisDate != null) ...[
                  Text(
                    ' – ${DateFormat('d.M.yy').format(b.bisDate!)}',
                    style: TextStyle(color: color.withOpacity(0.7)),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  color: AppColors.surface,
                  onSelected: (val) {
                    if (val == 'delete') _loeschen(b);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Löschen',
                            style: TextStyle(color: AppColors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              b.typ.label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            if (b.mittel.isNotEmpty)
              Text('Mittel: ${b.mittel}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            if (b.dosis.isNotEmpty)
              Text('Dosis: ${b.dosis}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${_volkName(b.volkId)} · ${_standortName(b.standortId)}',
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 12),
            ),
            if (b.ergebnis.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ergebnis: ${b.ergebnis}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _leereAnzeige() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_services, color: AppColors.red, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Behandlungen eingetragen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BehandlungFormScreen())).then((_) => _laden()),
            icon: const Icon(Icons.add),
            label: const Text('Behandlung eintragen'),
          ),
        ],
      ),
    );
  }

  Future<void> _loeschen(Behandlung b) async {
    _behandlungen.remove(b);
    await StorageService.saveBehandlungen(_behandlungen);
    _laden();
  }
}
