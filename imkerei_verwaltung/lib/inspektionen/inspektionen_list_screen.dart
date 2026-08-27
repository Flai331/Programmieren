// ═══════════════════════════════════════════════════════════════
//  Inspektionen Liste
//  lib/inspektionen/inspektionen_list_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/inspektion.dart';
import '../models/volk.dart';
import '../utils/storage_service.dart';
import 'inspektion_form_screen.dart';

class InspektionenListScreen extends StatefulWidget {
  const InspektionenListScreen({super.key});

  @override
  State<InspektionenListScreen> createState() => _InspektionenListScreenState();
}

class _InspektionenListScreenState extends State<InspektionenListScreen> {
  List<Inspektion> _inspektionen = [];
  List<Volk>       _voelker      = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final i = await StorageService.loadInspektionen();
    final v = await StorageService.loadVoelker();
    if (!mounted) return;
    setState(() {
      _inspektionen = i..sort((a, b) => b.datum.compareTo(a.datum));
      _voelker      = v;
      _loading      = false;
    });
  }

  String _volkName(String id) {
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
      appBar: AppBar(title: const Text('Inspektionen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : _inspektionen.isEmpty
              ? _leereAnzeige()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _inspektionen.length,
                  itemBuilder: (_, i) => _karte(_inspektionen[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InspektionFormScreen()))
            .then((_) => _laden()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _karte(Inspektion ins) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: ins.schwarmstimmung
                ? AppColors.red.withOpacity(0.5)
                : AppColors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppColors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d. MMMM yyyy', 'de_DE').format(ins.datum),
                  style: const TextStyle(
                      color: AppColors.honey, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (ins.schwarmstimmung)
                  const Text('⚠ Schwarm',
                      style: TextStyle(color: AppColors.red, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _volkName(ins.volkId),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chip('Stärke ${ins.staerke}', AppColors.honey),
                _chip(ins.brutStatus.label, AppColors.blue),
                if (ins.varroaSchaetzung > 0)
                  _chip('${ins.varroaSchaetzung}% Varroa',
                      ins.varroaSchaetzung >= 3 ? AppColors.red : AppColors.orange),
                if (ins.futterMenge > 0)
                  _chip('${ins.futterMenge}L Futter', AppColors.green),
              ],
            ),
            if (ins.beobachtungen.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ins.beobachtungen,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _leereAnzeige() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, color: AppColors.blue, size: 64),
          const SizedBox(height: 16),
          const Text('Noch keine Inspektionen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InspektionFormScreen())).then((_) => _laden()),
            icon: const Icon(Icons.add),
            label: const Text('Inspektion eintragen'),
          ),
        ],
      ),
    );
  }
}
