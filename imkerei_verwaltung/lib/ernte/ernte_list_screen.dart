// ═══════════════════════════════════════════════════════════════
//  Ernte Liste
//  lib/ernte/ernte_list_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/ernte.dart';
import '../models/standort.dart';
import '../models/volk.dart';
import '../utils/storage_service.dart';
import 'ernte_form_screen.dart';

class ErnteListScreen extends StatefulWidget {
  const ErnteListScreen({super.key});

  @override
  State<ErnteListScreen> createState() => _ErnteListScreenState();
}

class _ErnteListScreenState extends State<ErnteListScreen> {
  List<Ernte>    _ernten    = [];
  List<Standort> _standorte = [];
  List<Volk>     _voelker   = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final e = await StorageService.loadErnten();
    final s = await StorageService.loadStandorte();
    final v = await StorageService.loadVoelker();
    if (!mounted) return;
    setState(() {
      _ernten    = e..sort((a, b) => b.datum.compareTo(a.datum));
      _standorte = s;
      _voelker   = v;
      _loading   = false;
    });
  }

  String _standortName(String id) {
    try {
      return _standorte.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return 'Unbekannt';
    }
  }

  double get _gesamtKg =>
      _ernten.fold(0.0, (sum, e) => sum + e.mengeKg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Honigernte')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : _ernten.isEmpty
              ? _leereAnzeige()
              : Column(
                  children: [
                    _gesamtBanner(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _ernten.length,
                        itemBuilder: (_, i) => _karte(_ernten[i]),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ErnteFormScreen()))
            .then((_) => _laden()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _gesamtBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop, color: AppColors.amber, size: 28),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                '${_gesamtKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Gesamternte',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 32),
          Column(
            children: [
              Text(
                '${_ernten.length}',
                style: const TextStyle(
                  color: AppColors.honey,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Ernten',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _karte(Ernte e) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.amber.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.water_drop, color: AppColors.amber),
        ),
        title: Row(
          children: [
            Text(
              '${e.mengeKg.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(e.sorte.label,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_standortName(e.standortId)} · ${DateFormat('d. MMMM yyyy', 'de_DE').format(e.datum)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            if (e.wassergehalt > 0)
              Text(
                'Wassergehalt: ${e.wassergehalt.toStringAsFixed(1)}%'
                '${e.wassergehalt > 18 ? " ⚠ zu hoch!" : " ✓"}',
                style: TextStyle(
                  color: e.wassergehalt > 18 ? AppColors.red : AppColors.green,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: AppColors.surface,
          onSelected: (val) {
            if (val == 'delete') _loeschen(e);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'delete',
                child: Text('Löschen',
                    style: TextStyle(color: AppColors.red))),
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
          const Icon(Icons.water_drop, color: AppColors.amber, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Ernten eingetragen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ErnteFormScreen())).then((_) => _laden()),
            icon: const Icon(Icons.add),
            label: const Text('Ernte eintragen'),
          ),
        ],
      ),
    );
  }

  Future<void> _loeschen(Ernte e) async {
    _ernten.remove(e);
    await StorageService.saveErnten(_ernten);
    _laden();
  }
}
