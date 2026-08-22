import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/season_service.dart';
import '../utils/feedback_service.dart';
import 'season_task_detail_screen.dart';

/// Saisonale Arbeitslisten: Was steht im Imkerjahr gerade an, und bei wie
/// vielen Völkern ist es schon erledigt?
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({Key? key}) : super(key: key);

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);

  final _service = SeasonService();
  late Future<List<SeasonTaskStatus>> _future;

  static const _monthNames = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Saison');
    _future = _service.loadAll();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _service.loadAll();
    });
  }

  Future<void> _openTask(SeasonTaskStatus status) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SeasonTaskDetailScreen(status: status),
      ),
    );
    if (changed == true) _reload();
  }

  String _monthLabel(int month) => _monthNames[month - 1];

  String _windowLabel(SeasonTask t) => t.startMonth == t.endMonth
      ? _monthLabel(t.startMonth)
      : '${_monthLabel(t.startMonth)} – ${_monthLabel(t.endMonth)}';

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();

    return FutureBuilder<List<SeasonTaskStatus>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text('${snap.error}'),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: _reload, child: const Text('Neu laden')),
              ],
            ),
          );
        }

        final alle = snap.data ?? const <SeasonTaskStatus>[];
        final anstehend = SeasonService.due(alle);
        final kommend = SeasonService.upcoming(alle, heute);
        final voelker = alle.isEmpty ? 0 : alle.first.total;

        if (voelker == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_outlined, size: 64, color: _muted),
                  SizedBox(height: 16),
                  Text('Noch keine aktiven Völker',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    'Lege zuerst ein Volk an. Die Arbeitslisten richten sich '
                    'nach deinem Bestand.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text('${_monthLabel(heute.month)} · $voelker Völker',
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 12),

              _header('Jetzt dran', anstehend.length),
              if (anstehend.isEmpty)
                _hint('In diesem Monat steht nichts an')
              else
                for (final s in anstehend) _taskCard(s),

              const SizedBox(height: 20),
              _header('Als Nächstes', kommend.length),
              if (kommend.isEmpty)
                _hint('Nichts in den nächsten zwei Monaten')
              else
                for (final s in kommend) _taskCard(s, dimmed: true),
            ],
          ),
        );
      },
    );
  }

  Widget _header(String title, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text('$title ($count)',
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: _muted)),
        ),
      );

  Widget _taskCard(SeasonTaskStatus s, {bool dimmed = false}) {
    final fertig = s.isComplete;
    final farbe = fertig ? _green : _peach;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openTask(s),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    fertig
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: dimmed ? _muted : farbe,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dimmed ? _muted : null,
                      ),
                    ),
                  ),
                  Text(_windowLabel(s.task),
                      style: const TextStyle(fontSize: 10, color: _muted)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF26262c),
                  valueColor: AlwaysStoppedAnimation(
                      dimmed ? _muted : farbe),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    fertig
                        ? 'Alle ${s.total} Völker erledigt'
                        : '${s.doneCount} von ${s.total} Völkern erledigt',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  const Spacer(),
                  if (!fertig)
                    Text('${s.openCount} offen',
                        style: TextStyle(
                            fontSize: 11,
                            color: dimmed ? _muted : _peach,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
