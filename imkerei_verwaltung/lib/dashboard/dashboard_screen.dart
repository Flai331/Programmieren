// ═══════════════════════════════════════════════════════════════
//  Dashboard Screen – Übersicht
//  lib/dashboard/dashboard_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/volk.dart';
import '../models/ernte.dart';
import '../models/inspektion.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';
import '../voelker/voelker_list_screen.dart';
import '../inspektionen/inspektionen_list_screen.dart';
import '../ernte/ernte_list_screen.dart';
import '../behandlungen/behandlungen_list_screen.dart';
import '../standorte/standorte_list_screen.dart';
import '../einstellungen/einstellungen_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Volk>       _voelker      = [];
  List<Standort>   _standorte    = [];
  List<Ernte>      _ernten       = [];
  List<Inspektion> _inspektionen = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final v = await StorageService.loadVoelker();
    final s = await StorageService.loadStandorte();
    final e = await StorageService.loadErnten();
    final i = await StorageService.loadInspektionen();
    if (!mounted) return;
    setState(() {
      _voelker      = v;
      _standorte    = s;
      _ernten       = e;
      _inspektionen = i;
      _loading      = false;
    });
  }

  double get _gesamternteKg =>
      _ernten.fold(0, (sum, e) => sum + e.mengeKg);

  int get _aktiveVoelker =>
      _voelker.where((v) => v.status == Volksstatus.aktiv).length;

  Inspektion? get _letzteInspektion {
    if (_inspektionen.isEmpty) return null;
    return _inspektionen.reduce((a, b) => a.datum.isAfter(b.datum) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🐝', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Imkerei Verwaltung',
              style: TextStyle(
                color: AppColors.honey,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.honey),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EinstellungenScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.honey))
          : RefreshIndicator(
              color: AppColors.honey,
              onRefresh: _laden,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _begruessung(),
                  const SizedBox(height: 16),
                  _statistikLeiste(),
                  const SizedBox(height: 24),
                  _sectionTitle('Schnellzugriff'),
                  const SizedBox(height: 12),
                  _schnellzugriffGrid(),
                  const SizedBox(height: 24),
                  if (_letzteInspektion != null) ...[
                    _sectionTitle('Letzte Inspektion'),
                    const SizedBox(height: 8),
                    _letzteInspektionKarte(),
                    const SizedBox(height: 24),
                  ],
                  if (_voelker.any((v) =>
                      v.naechsteInspektion != null &&
                      v.naechsteInspektion!.isAfter(DateTime.now().subtract(const Duration(days: 1))))) ...[
                    _sectionTitle('Anstehende Inspektionen'),
                    const SizedBox(height: 8),
                    _anstehendeInspektionen(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _begruessung() {
    final stunde = DateTime.now().hour;
    String gruss;
    if (stunde < 12) gruss = 'Guten Morgen';
    else if (stunde < 18) gruss = 'Guten Tag';
    else gruss = 'Guten Abend';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.honey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gruss + ', Imker!',
            style: const TextStyle(
              color: AppColors.honey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(DateTime.now()),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statistikLeiste() {
    return Row(
      children: [
        _statCard('Völker', _aktiveVoelker.toString(), Icons.hive, AppColors.honey),
        const SizedBox(width: 8),
        _statCard('Standorte', _standorte.length.toString(), Icons.location_on, AppColors.orange),
        const SizedBox(width: 8),
        _statCard('Ernte', '${_gesamternteKg.toStringAsFixed(1)} kg', Icons.water_drop, AppColors.amber),
      ],
    );
  }

  Widget _statCard(String label, String wert, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(wert,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _schnellzugriffGrid() {
    final items = [
      _NavItem('Bienenvölker', Icons.hive, AppColors.honey,
          () => _push(const VoelkerListScreen())),
      _NavItem('Inspektionen', Icons.assignment, AppColors.blue,
          () => _push(const InspektionenListScreen())),
      _NavItem('Ernte', Icons.water_drop, AppColors.amber,
          () => _push(const ErnteListScreen())),
      _NavItem('Behandlungen', Icons.medical_services, AppColors.red,
          () => _push(const BehandlungenListScreen())),
      _NavItem('Standorte', Icons.location_on, AppColors.orange,
          () => _push(const StandorteListScreen())),
      _NavItem('Einstellungen', Icons.settings, AppColors.textSecondary,
          () => _push(const EinstellungenScreen())),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: items.map((item) => _navTile(item)).toList(),
    );
  }

  Widget _navTile(_NavItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 28),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _letzteInspektionKarte() {
    final ins = _letzteInspektion!;
    final volk = _voelker.firstWhere(
      (v) => v.id == ins.volkId,
      orElse: () => Volk(
          id: '', name: 'Unbekanntes Volk', standortId: '',
          erstelltAm: DateTime.now()),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: AppColors.blue, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(volk.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                Text(
                  DateFormat('d. MMMM yyyy', 'de_DE').format(ins.datum),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                if (ins.beobachtungen.isNotEmpty)
                  Text(
                    ins.beobachtungen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anstehendeInspektionen() {
    final faellig = _voelker
        .where((v) =>
            v.naechsteInspektion != null &&
            v.naechsteInspektion!.isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.naechsteInspektion!.compareTo(b.naechsteInspektion!));

    return Column(
      children: faellig.take(3).map((v) {
        final tage = v.naechsteInspektion!.difference(DateTime.now()).inDays;
        final farbe = tage <= 0
            ? AppColors.red
            : tage <= 3
                ? AppColors.orange
                : AppColors.green;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: farbe.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: farbe, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(v.name,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
              Text(
                tage <= 0
                    ? 'Heute!'
                    : tage == 1
                        ? 'Morgen'
                        : 'in $tage Tagen',
                style: TextStyle(color: farbe, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _laden());
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NavItem(this.label, this.icon, this.color, this.onTap);
}
