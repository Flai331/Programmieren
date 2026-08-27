// ═══════════════════════════════════════════════════════════════
//  Völker-Liste
//  lib/voelker/voelker_list_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/volk.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';
import 'volk_form_screen.dart';
import 'volk_detail_screen.dart';

class VoelkerListScreen extends StatefulWidget {
  const VoelkerListScreen({super.key});

  @override
  State<VoelkerListScreen> createState() => _VoelkerListScreenState();
}

class _VoelkerListScreenState extends State<VoelkerListScreen> {
  List<Volk>     _voelker   = [];
  List<Standort> _standorte = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final v = await StorageService.loadVoelker();
    final s = await StorageService.loadStandorte();
    if (!mounted) return;
    setState(() {
      _voelker   = v;
      _standorte = s;
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

  Color _statusFarbe(Volksstatus s) {
    switch (s) {
      case Volksstatus.aktiv:    return AppColors.green;
      case Volksstatus.schwach:  return AppColors.orange;
      case Volksstatus.erloschen: return AppColors.red;
      case Volksstatus.verkauft: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Bienenvölker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _oeffneFormular(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : _voelker.isEmpty
              ? _leereAnzeige()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _voelker.length,
                  itemBuilder: (_, i) => _volkKarte(_voelker[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _oeffneFormular(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _volkKarte(Volk v) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _statusFarbe(v.status).withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _statusFarbe(v.status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${v.staerke}',
              style: TextStyle(
                color: _statusFarbe(v.status),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(v.name,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${v.rasse.label} · ${_standortName(v.standortId)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusFarbe(v.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(v.status.label,
                      style: TextStyle(
                          color: _statusFarbe(v.status), fontSize: 11)),
                ),
                if (v.naechsteInspektion != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Inspektion: ${DateFormat('d.M.yy').format(v.naechsteInspektion!)}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VolkDetailScreen(
              volk: v,
              standortName: _standortName(v.standortId),
            ),
          ),
        ).then((_) => _laden()),
        trailing: PopupMenuButton<String>(
          color: AppColors.surface,
          onSelected: (val) {
            if (val == 'edit') _oeffneFormular(v);
            if (val == 'delete') _loeschen(v);
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
          const Icon(Icons.hive, color: AppColors.honey, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Völker eingetragen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _oeffneFormular(null),
            icon: const Icon(Icons.add),
            label: const Text('Erstes Volk anlegen'),
          ),
        ],
      ),
    );
  }

  Future<void> _oeffneFormular(Volk? volk) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolkFormScreen(
          volk: volk,
          standorte: _standorte,
        ),
      ),
    );
    _laden();
  }

  Future<void> _loeschen(Volk v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Volk löschen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
            '"${v.name}" wirklich löschen? Alle zugehörigen Inspektionen bleiben erhalten.',
            style: const TextStyle(color: AppColors.textSecondary)),
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
      _voelker.remove(v);
      await StorageService.saveVoelker(_voelker);
      _laden();
    }
  }
}
