// ═══════════════════════════════════════════════════════════════
//  Volk Detail Screen
//  lib/voelker/volk_detail_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/volk.dart';
import '../models/inspektion.dart';
import '../utils/storage_service.dart';
import '../inspektionen/inspektion_form_screen.dart';

class VolkDetailScreen extends StatefulWidget {
  final Volk volk;
  final String standortName;

  const VolkDetailScreen({
    super.key,
    required this.volk,
    required this.standortName,
  });

  @override
  State<VolkDetailScreen> createState() => _VolkDetailScreenState();
}

class _VolkDetailScreenState extends State<VolkDetailScreen> {
  List<Inspektion> _inspektionen = [];

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final all = await StorageService.loadInspektionen();
    if (!mounted) return;
    setState(() {
      _inspektionen = all
          .where((i) => i.volkId == widget.volk.id)
          .toList()
        ..sort((a, b) => b.datum.compareTo(a.datum));
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.volk;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(v.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Inspektion hinzufügen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InspektionFormScreen(volkId: v.id),
              ),
            ).then((_) => _laden()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoKarte(v),
          const SizedBox(height: 20),
          const Text(
            'Inspektionen',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_inspektionen.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Noch keine Inspektionen',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ..._inspektionen.map((i) => _inspektionKarte(i)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => InspektionFormScreen(volkId: v.id)),
        ).then((_) => _laden()),
        icon: const Icon(Icons.add),
        label: const Text('Inspektion'),
      ),
    );
  }

  Widget _infoKarte(Volk v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.honey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _zeile(Icons.location_on, 'Standort', widget.standortName),
          _zeile(Icons.bug_report, 'Rasse', v.rasse.label),
          _zeile(Icons.info, 'Status', v.status.label),
          _zeile(Icons.people, 'Volksstärke', '${v.staerke} / 10'),
          if (v.koeninginJahr.isNotEmpty)
            _zeile(Icons.star, 'Königin',
                '${v.koeninginJahr}${v.koeninginMarkiert ? " · ${v.koeninginFarbe} markiert" : ""}'),
          if (v.naechsteInspektion != null)
            _zeile(Icons.calendar_today, 'Nächste Inspektion',
                DateFormat('d. MMMM yyyy', 'de_DE').format(v.naechsteInspektion!)),
          if (v.notizen.isNotEmpty)
            _zeile(Icons.note, 'Notizen', v.notizen),
        ],
      ),
    );
  }

  Widget _zeile(IconData icon, String label, String wert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.honey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(
                          color: AppColors.textSecondary)),
                  TextSpan(
                      text: wert,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspektionKarte(Inspektion ins) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.blue.withOpacity(0.3))),
      child: ListTile(
        leading: const Icon(Icons.assignment, color: AppColors.blue),
        title: Text(
          DateFormat('d. MMMM yyyy', 'de_DE').format(ins.datum),
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Stärke: ${ins.staerke} · Brut: ${ins.brutStatus.label}'
          '${ins.schwarmstimmung ? " · ⚠ Schwarm" : ""}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: ins.varroaSchaetzung > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ins.varroaSchaetzung >= 3
                      ? AppColors.red.withOpacity(0.2)
                      : AppColors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ins.varroaSchaetzung}% Varroa',
                  style: TextStyle(
                      color: ins.varroaSchaetzung >= 3
                          ? AppColors.red
                          : AppColors.orange,
                      fontSize: 11),
                ),
              )
            : null,
      ),
    );
  }
}
