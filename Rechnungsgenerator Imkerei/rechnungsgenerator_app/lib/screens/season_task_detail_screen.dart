import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/season_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import 'hive_action_edit_screen.dart';

/// Eine Saison-Aufgabe im Detail: Packliste zum Abhaken und die Völker,
/// bei denen sie noch offen ist.
class SeasonTaskDetailScreen extends StatefulWidget {
  final SeasonTaskStatus status;

  const SeasonTaskDetailScreen({Key? key, required this.status})
      : super(key: key);

  @override
  State<SeasonTaskDetailScreen> createState() =>
      _SeasonTaskDetailScreenState();
}

class _SeasonTaskDetailScreenState extends State<SeasonTaskDetailScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);

  final _db = DatabaseService();

  late SeasonTaskStatus _status;

  /// Abgehakte Packlisten-Posten. Nur für den laufenden Arbeitsgang gedacht
  /// und deshalb bewusst nicht gespeichert – beim nächsten Öffnen richtet
  /// sich die Liste ohnehin neu nach den dann offenen Völkern.
  final Set<String> _packed = {};

  /// Hat sich etwas geändert? Steuert das Neuladen der Saison-Übersicht.
  bool _changed = false;

  SeasonTask get _task => _status.task;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    FeedbackService.logScreenLoad('Saison-Aufgabe',
        additionalInfo: _task.id);
  }

  /// Stand dieser Aufgabe neu berechnen, nachdem eine Maßnahme erfasst wurde.
  Future<void> _refresh() async {
    final hives = await _db.getAllHives();
    final actions = await _db.getAllHiveActions();
    final alle = SeasonService.buildStatuses(
      hives: hives,
      actions: actions,
      reference: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _status = alle.firstWhere(
        (s) => s.task.id == _task.id,
        orElse: () => _status,
      );
    });
  }

  Future<void> _recordFor(HiveModel hive) async {
    final gespeichert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: hive.id,
          hiveLabel: hive.displayLabel,
          initialType: _task.actionType,
          seasonTask: _task.id,
        ),
      ),
    );
    if (gespeichert == true) {
      _changed = true;
      await _refresh();
    }
  }

  Future<void> _openExisting(HiveActionModel action, HiveModel hive) async {
    final gespeichert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: hive.id,
          hiveLabel: hive.displayLabel,
          actionId: action.id,
        ),
      ),
    );
    if (gespeichert == true) {
      _changed = true;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offen = _status.openHives;
    final erledigt = _status.doneHives;
    final packliste = _status.packList;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_task.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_task.description,
                style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),

            // ── Fortschritt ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_status.doneCount} von ${_status.total} Völkern',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (_status.isComplete)
                          const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: _green),
                              SizedBox(width: 4),
                              Text('abgeschlossen',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _green,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _status.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF26262c),
                        valueColor: AlwaysStoppedAnimation(
                            _status.isComplete ? _green : _peach),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Packliste ──
            if (packliste.isNotEmpty) ...[
              _section('Packliste'),
              Text(
                _status.openCount == 0
                    ? 'Nichts mehr offen – alle Völker sind versorgt.'
                    : 'Mengen für ${_status.openCount} offene '
                        '${_status.openCount == 1 ? "Volk" : "Völker"}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final e in packliste) _packRow(e),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Offene Völker ──
            _section('Offen (${offen.length})'),
            if (offen.isEmpty)
              _hint('Alle Völker erledigt')
            else
              for (final h in offen) _openHiveRow(h.hive),

            const SizedBox(height: 20),

            // ── Erledigte Völker ──
            _section('Erledigt (${erledigt.length})'),
            if (erledigt.isEmpty)
              _hint('Noch nichts erfasst')
            else
              for (final h in erledigt) _doneHiveRow(h),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: _muted)),
      );

  Widget _packRow(PackListEntry e) {
    final abgehakt = _packed.contains(e.item.name);
    return CheckboxListTile(
      value: abgehakt,
      onChanged: (v) => setState(() {
        if (v == true) {
          _packed.add(e.item.name);
        } else {
          _packed.remove(e.item.name);
        }
      }),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      activeColor: _peach,
      title: Text(
        e.label,
        style: TextStyle(
          fontSize: 13,
          decoration: abgehakt ? TextDecoration.lineThrough : null,
          color: abgehakt ? _muted : null,
        ),
      ),
      secondary: e.quantityLabel.isEmpty
          ? null
          : Text(e.quantityLabel,
              style: const TextStyle(
                  fontSize: 12, color: _peach, fontWeight: FontWeight.w600)),
    );
  }

  Widget _openHiveRow(HiveModel hive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.radio_button_unchecked,
            size: 20, color: _peach),
        title: Text(hive.displayLabel,
            style: const TextStyle(fontSize: 13)),
        subtitle: (hive.location ?? '').isEmpty
            ? null
            : Text(hive.location!,
                style: const TextStyle(fontSize: 11, color: _muted)),
        trailing: TextButton(
          onPressed: () => _recordFor(hive),
          child: const Text('Erfassen',
              style: TextStyle(color: _peach, fontSize: 12)),
        ),
        onTap: () => _recordFor(hive),
      ),
    );
  }

  Widget _doneHiveRow(SeasonHiveStatus h) {
    final action = h.fulfilledBy!;
    final summary = action.summary;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, size: 20, color: _green),
        title: Text(h.hive.displayLabel,
            style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          summary.isEmpty
              ? AppUtils.formatDate(action.date)
              : '${AppUtils.formatDate(action.date)} · $summary',
          style: const TextStyle(fontSize: 11, color: _muted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openExisting(action, h.hive),
      ),
    );
  }
}
