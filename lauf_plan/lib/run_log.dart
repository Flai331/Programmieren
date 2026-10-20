import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show Exercise, dateLabel, isoDate, parseIsoDate, todayDate;
import 'plan_edit.dart' show templateKeyFor;
import 'weights.dart' show parseKg;

// Lauf-Tagebuch: pro Übungsname (z. B. „Locker laufen“, „Intervalle“) ein
// Eintrag je Plan-Tag mit Strecke, Zeit, Zeiten pro Wiederholung und Notiz.
// Gespeichert als JSON in 'run_log': {Übungsname: [Einträge]}.

class RunEntry {
  final int day; // Plan-Tag (Slot)
  final DateTime date;
  final double? km;
  final int? secs;
  final List<int> splits; // Sekunden je Wiederholung (Intervalle, Tempo-km)
  final String note;
  const RunEntry(this.day, this.date,
      {this.km, this.secs, this.splits = const [], this.note = ''});

  bool get isEmpty => km == null && secs == null && splits.isEmpty && note.isEmpty;

  Map<String, Object?> toJson() => {
        'day': day,
        'date': isoDate(date),
        if (km != null) 'km': km,
        if (secs != null) 'secs': secs,
        if (splits.isNotEmpty) 'splits': splits,
        if (note.isNotEmpty) 'note': note,
      };

  static RunEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = parseIsoDate(j['date'] as String?);
    final day = j['day'];
    if (date == null || day is! num) return null;
    final sp = j['splits'];
    return RunEntry(
      day.toInt(),
      date,
      km: (j['km'] as num?)?.toDouble(),
      secs: (j['secs'] as num?)?.toInt(),
      splits: sp is List ? [for (final s in sp) if (s is num) s.toInt()] : const [],
      note: (j['note'] as String?) ?? '',
    );
  }
}

class RunLog {
  static const _key = 'run_log';
  final SharedPreferences p;
  RunLog(this.p);

  Map<String, List<RunEntry>> _all() {
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is List)
            '${e.key}': (e.value as List).map(RunEntry.fromJson).whereType<RunEntry>().toList()
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, List<RunEntry>> all) => p.setString(_key,
      jsonEncode({for (final e in all.entries) e.key: [for (final r in e.value) r.toJson()]}));

  /// Neueste zuerst.
  List<RunEntry> history(String name) => [...?_all()[name]]..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.day.compareTo(a.day);
    });

  RunEntry? forDay(String name, int day) =>
      history(name).where((r) => r.day == day).firstOrNull;

  /// Letzter Eintrag von einem anderen Plan-Tag (= „letztes Mal“).
  RunEntry? lastBefore(String name, int day) =>
      history(name).where((r) => r.day != day).firstOrNull;

  Future<void> set(String name, RunEntry entry) async {
    final all = _all();
    final list = all[name] ?? [];
    list.removeWhere((r) => r.day == entry.day);
    list.add(entry);
    all[name] = list;
    await _save(all);
  }

  Future<void> remove(String name, int day) async {
    final all = _all();
    all[name]?.removeWhere((r) => r.day == day);
    if (all[name]?.isEmpty ?? false) all.remove(name);
    await _save(all);
  }
}

/// Alle Abschnitte der Lauf-Bausteine (Läufe je Woche, lange Läufe).
bool tracksRun(int day, Exercise e) {
  final k = templateKeyFor(day);
  return k.startsWith('quality') || k.startsWith('long');
}

/// Wiederholungen mit eigener Zeit: manuell beendete Runden (400 m, Tempo-km).
bool hasSplits(Exercise e) => e.timer != null && e.timer!.work == 0 && e.timer!.rounds > 1;

/// „34:10“, „1:05:30“; eine Zahl allein = Minuten („45“ -> 45:00).
int? parseDuration(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final parts = t.split(RegExp(r'[:.]'));
  if (parts.any((p) => p.isEmpty || int.tryParse(p) == null)) return null;
  final n = parts.map(int.parse).toList();
  return switch (n.length) {
    1 => n[0] * 60,
    2 when n[1] < 60 => n[0] * 60 + n[1],
    3 when n[1] < 60 && n[2] < 60 => n[0] * 3600 + n[1] * 60 + n[2],
    _ => null,
  };
}

/// Zeiten pro Wiederholung, getrennt durch Leerzeichen, Komma oder Semikolon.
/// „1:32 1:30 1:31“. null = etwas nicht lesbar.
List<int>? parseSplits(String s) {
  final parts = s.split(RegExp(r'[\s;,/]+')).where((p) => p.isNotEmpty).toList();
  final out = <int>[];
  for (final p in parts) {
    final v = p.contains(':') ? parseDuration(p) : int.tryParse(p); // „92“ = 92 Sek.
    if (v == null) return null;
    out.add(v);
  }
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDuration(int secs) {
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

String kmLabel(double km) =>
    '${km.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} km';

/// Tempo „5:31 /km“, null wenn Strecke oder Zeit fehlt.
String? paceLabel(double? km, int? secs) {
  if (km == null || secs == null || km <= 0) return null;
  return '${fmtDuration((secs / km).round())} /km';
}

String runSummary(RunEntry r, {bool withDate = true}) {
  final parts = <String>[
    if (r.km != null && r.secs != null) '${kmLabel(r.km!)} in ${fmtDuration(r.secs!)}'
    else if (r.km != null) kmLabel(r.km!)
    else if (r.secs != null) fmtDuration(r.secs!),
    if (paceLabel(r.km, r.secs) != null) paceLabel(r.km, r.secs)!,
    if (r.splits.isNotEmpty)
      '${r.splits.length}× Ø ${fmtDuration((r.splits.reduce((a, b) => a + b) / r.splits.length).round())}',
    if (r.note.isNotEmpty) r.note,
  ];
  return '${parts.join(' · ')}${withDate ? ' (${dateLabel(r.date)})' : ''}';
}

/// Kurzinfo unter einem Lauf-Abschnitt: letztes Mal + heute.
class RunInfo extends StatelessWidget {
  final RunEntry? last, today;
  final VoidCallback onTap;
  const RunInfo({super.key, required this.last, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (last != null)
            Text('Letztes Mal: ${runSummary(last!)}',
                style: tt.bodySmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 2),
          ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(today == null ? Icons.add : Icons.edit, size: 16),
            label: Text(today == null
                ? 'Strecke / Zeit eintragen'
                : 'Heute: ${runSummary(today!, withDate: false)}'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Eingabe für einen Lauf-Abschnitt an Plan-Tag [day]. Rückgabe: true = geändert.
Future<bool> showRunDialog(BuildContext context, RunLog log, Exercise e, int day,
    {DateTime? date}) async {
  final existing = log.forDay(e.name, day);
  final last = log.lastBefore(e.name, day);
  final history = log.history(e.name).where((r) => r.day != day).take(5).toList();
  final splitsWanted = hasSplits(e);
  final kmCtl = TextEditingController(
      text: existing?.km == null ? '' : kmLabel(existing!.km!).replaceAll(' km', ''));
  final timeCtl =
      TextEditingController(text: existing?.secs == null ? '' : fmtDuration(existing!.secs!));
  final splitsCtl = TextEditingController(
      text: existing == null ? '' : existing.splits.map(fmtDuration).join(' '));
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  String? error;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final km = parseKg(kmCtl.text);
      final secs = parseDuration(timeCtl.text);
      final pace = paceLabel(km, secs);
      final splits = parseSplits(splitsCtl.text) ?? const <int>[];
      return AlertDialog(
        title: Text(e.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.detail, style: Theme.of(ctx).textTheme.bodySmall),
              if (last != null) ...[
                const SizedBox(height: 8),
                Text('Letztes Mal: ${runSummary(last)}'),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: kmCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(
                        labelText: 'Strecke', suffixText: 'km', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() => error = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: timeCtl,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                        labelText: 'Zeit', hintText: '34:10', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() => error = null),
                  ),
                ),
              ]),
              if (pace != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Tempo: $pace', style: Theme.of(ctx).textTheme.titleSmall),
                ),
              if (splitsWanted) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: splitsCtl,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Zeiten pro Wiederholung (optional)',
                    hintText: '1:32 1:30 1:31 …',
                    helperText: splits.isEmpty
                        ? 'Mit Leerzeichen trennen'
                        : '${splits.length}× · Ø ${fmtDuration((splits.reduce((a, b) => a + b) / splits.length).round())}'
                            ' · schnellste ${fmtDuration(splits.reduce((a, b) => a < b ? a : b))}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => error = null),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  hintText: 'z. B. Knie ruhig, Wind',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
              if (history.length > 1) ...[
                const SizedBox(height: 12),
                Text('Verlauf', style: Theme.of(ctx).textTheme.titleSmall),
                for (final r in history) Text('${dateLabel(r.date)}: ${runSummary(r, withDate: false)}'),
              ],
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Löschen')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (kmCtl.text.trim().isNotEmpty && parseKg(kmCtl.text) == null) {
                setState(() => error = 'Strecke bitte als Zahl, z. B. 6,2');
              } else if (timeCtl.text.trim().isNotEmpty && parseDuration(timeCtl.text) == null) {
                setState(() => error = 'Zeit bitte so: 34:10 oder 1:05:30');
              } else if (splitsCtl.text.trim().isNotEmpty && parseSplits(splitsCtl.text) == null) {
                setState(() => error = 'Zeiten pro Wiederholung bitte so: 1:32 1:30 1:31');
              } else {
                Navigator.pop(ctx, 'save');
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      );
    }),
  );
  final entryKm = parseKg(kmCtl.text);
  final entrySecs = parseDuration(timeCtl.text);
  final entrySplits = parseSplits(splitsCtl.text) ?? const <int>[];
  final note = noteCtl.text.trim();
  for (final c in [kmCtl, timeCtl, splitsCtl, noteCtl]) {
    c.dispose();
  }
  if (result == 'delete') {
    await log.remove(e.name, day);
    return true;
  }
  if (result != 'save') return false;
  final today = todayDate();
  final d = date == null || date.isAfter(today) ? today : date;
  final entry = RunEntry(day, d,
      km: entryKm == 0 ? null : entryKm, secs: entrySecs, splits: entrySplits, note: note);
  if (entry.isEmpty) {
    if (existing != null) await log.remove(e.name, day);
    return existing != null;
  }
  await log.set(e.name, entry);
  return true;
}
