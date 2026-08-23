import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'hive_edit_screen.dart';

class HiveListScreen extends StatefulWidget {
  const HiveListScreen({Key? key}) : super(key: key);

  @override
  State<HiveListScreen> createState() => _HiveListScreenState();
}

class _HiveListScreenState extends State<HiveListScreen> {
  final _db = DatabaseService();
  static const _peach = Color(0xFFfda085);

  late Future<_HiveOverview> _future;
  String _filter = 'aktiv'; // aktiv | alle | abgegeben | eingegangen

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Völker und die jeweils jüngste Maßnahme in einem Zug laden, damit
  /// Liste und Zusatzzeile immer denselben Stand zeigen.
  Future<_HiveOverview> _load() async {
    final hives = await _db.getAllHives();
    final latest = await _db.getLatestActionPerHive();
    return _HiveOverview(hives, latest);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  /// „heute", „gestern", „vor 5 Tagen" – Abstand zur letzten Maßnahme.
  String _relativeDays(DateTime date) {
    final heute = DateUtils.dateOnly(DateTime.now());
    final tage = heute.difference(DateUtils.dateOnly(date)).inDays;
    if (tage <= 0) return 'heute';
    if (tage == 1) return 'gestern';
    if (tage < 7) return 'vor $tage Tagen';
    if (tage < 14) return 'vor 1 Woche';
    if (tage < 70) return 'vor ${(tage / 7).round()} Wochen';
    return 'vor ${(tage / 30).round()} Monaten';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'aktiv':       return const Color(0xFF22c55e);
      case 'abgegeben':   return const Color(0xFF8a8a94);
      case 'eingegangen': return const Color(0xFFff6b7a);
      default:            return const Color(0xFF8a8a94);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'aktiv':       return 'Aktiv';
      case 'abgegeben':   return 'Abgegeben';
      case 'eingegangen': return 'Eingegangen';
      default:            return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_HiveOverview>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final overview = snap.data ?? const _HiveOverview([], {});
          final all = overview.hives;

          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hive_outlined,
                      size: 64, color: Color(0xFF8a8a94)),
                  const SizedBox(height: 16),
                  const Text('Noch keine Völker erfasst'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HiveEditScreen()),
                      );
                      _reload();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Erstes Volk anlegen'),
                  ),
                ],
              ),
            );
          }

          final filtered = _filter == 'alle'
              ? all
              : all.where((h) => h.status == _filter).toList();

          return Column(
            children: [
              // Filter-Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    for (final f in ['aktiv', 'alle', 'abgegeben', 'eingegangen'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == 'alle'
                              ? 'Alle (${all.length})'
                              : '${_statusLabel(f)} (${all.where((h) => h.status == f).length})'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: f == 'alle'
                              ? _peach
                              : _statusColor(f).withAlpha(204),
                          labelStyle: TextStyle(
                            color: _filter == f ? Colors.white : null,
                            fontWeight:
                                _filter == f ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Keine ${_statusLabel(_filter)}',
                            style:
                                const TextStyle(color: Color(0xFF8a8a94)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final h = filtered[i];
                            final color = _statusColor(h.status);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            HiveEditScreen(hiveId: h.id)),
                                  );
                                  _reload();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Nummer-Badge
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _peach.withAlpha(38),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border:
                                              Border.all(color: _peach),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          h.number?.toString() ?? '–',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _peach),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              h.effectiveName,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 14),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            if ((h.location ?? '').isNotEmpty &&
                                                !h.usesDerivedName)
                                              Text(h.location!,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(
                                                          0xFF8a8a94))),
                                            if (h.queenYear != null)
                                              Text(
                                                'Königin ${h.queenYear}'
                                                '${(h.queenOrigin ?? "").isNotEmpty ? " · ${h.queenOrigin}" : ""}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF8a8a94)),
                                              ),
                                            if (overview.latestAction[h.id]
                                                case final letzte?)
                                              Text(
                                                '${letzte.typeLabel} · ${_relativeDays(letzte.date)}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _peach),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(38),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: color, width: 1),
                                        ),
                                        child: Text(
                                          _statusLabel(h.status),
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _peach,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HiveEditScreen()),
          );
          _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Neues Volk'),
      ),
    );
  }
}

/// Völker samt jeweils jüngster Maßnahme – ein gemeinsamer Ladestand.
class _HiveOverview {
  final List<HiveModel> hives;
  final Map<String, HiveActionModel> latestAction;
  const _HiveOverview(this.hives, this.latestAction);
}
