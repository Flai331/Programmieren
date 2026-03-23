// ═══════════════════════════════════════════════════════════════
//  Standorte Liste
//  lib/standorte/standorte_list_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/standort.dart';
import '../models/volk.dart';
import '../utils/storage_service.dart';
import 'standort_form_screen.dart';

class StandorteListScreen extends StatefulWidget {
  const StandorteListScreen({super.key});

  @override
  State<StandorteListScreen> createState() => _StandorteListScreenState();
}

class _StandorteListScreenState extends State<StandorteListScreen> {
  List<Standort> _standorte = [];
  List<Volk>     _voelker   = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final s = await StorageService.loadStandorte();
    final v = await StorageService.loadVoelker();
    if (!mounted) return;
    setState(() {
      _standorte = s;
      _voelker   = v;
      _loading   = false;
    });
  }

  int _anzahlVoelker(String standortId) =>
      _voelker.where((v) => v.standortId == standortId).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Standorte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _oeffneFormular(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : _standorte.isEmpty
              ? _leereAnzeige()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _standorte.length,
                  itemBuilder: (_, i) => _karte(_standorte[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _oeffneFormular(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _karte(Standort s) {
    final anzahl = _anzahlVoelker(s.id);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.location_on, color: AppColors.orange),
        ),
        title: Text(s.name,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.adresse.isNotEmpty)
              Text(s.adresse,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            if (s.trachtpflanzen.isNotEmpty)
              Text('Tracht: ${s.trachtpflanzen}',
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 11)),
            Text(
              '$anzahl ${anzahl == 1 ? "Volk" : "Völker"}',
              style: const TextStyle(color: AppColors.honey, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: AppColors.surface,
          onSelected: (val) {
            if (val == 'edit') _oeffneFormular(s);
            if (val == 'delete') _loeschen(s);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit',
                child: Text('Bearbeiten',
                    style: TextStyle(color: AppColors.textPrimary))),
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
          const Icon(Icons.location_on, color: AppColors.orange, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Standorte angelegt',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _oeffneFormular(null),
            icon: const Icon(Icons.add),
            label: const Text('Standort anlegen'),
          ),
        ],
      ),
    );
  }

  Future<void> _oeffneFormular(Standort? s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StandortFormScreen(standort: s)),
    );
    _laden();
  }

  Future<void> _loeschen(Standort s) async {
    final anzahl = _anzahlVoelker(s.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Standort löschen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          anzahl > 0
              ? '"${s.name}" hat noch $anzahl Volk/Völker. Wirklich löschen?'
              : '"${s.name}" wirklich löschen?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      _standorte.remove(s);
      await StorageService.saveStandorte(_standorte);
      _laden();
    }
  }
}
