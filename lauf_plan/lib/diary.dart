import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'run_log.dart';
import 'weights.dart';

// Protokoll: Befinden, Puls und Beschwerden pro Einheit. Zusammen mit den
// Gewichten (Zusatzgewicht) und dem Lauf-Tagebuch lässt sich daraus ein
// Bericht erzeugen, den man teilen kann, um den Plan anzupassen.
// Gespeichert als JSON in 'diary': {Plan-Tag: Eintrag}.

const feelingLabels = ['sehr schlecht', 'schlecht', 'okay', 'gut', 'sehr gut'];

class DayEntry {
  final int day; // Plan-Tag (Slot)
  final DateTime date;
  final int? feeling; // 1 (sehr schlecht) … 5 (sehr gut)
  final int? pulseAvg;
  final int? pulseMax;
  final int pain; // Achillessehne / Knie, 0 = keine … 10
  final String note;
  const DayEntry(this.day, this.date,
      {this.feeling, this.pulseAvg, this.pulseMax, this.pain = 0, this.note = ''});

  Map<String, Object?> toJson() => {
        'day': day,
        'date': isoDate(date),
        if (feeling != null) 'feeling': feeling,
        if (pulseAvg != null) 'pulseAvg': pulseAvg,
        if (pulseMax != null) 'pulseMax': pulseMax,
        if (pain > 0) 'pain': pain,
        if (note.isNotEmpty) 'note': note,
      };

  static DayEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = parseIsoDate(j['date'] as String?);
    final day = j['day'];
    if (date == null || day is! num) return null;
    return DayEntry(
      day.toInt(),
      date,
      feeling: (j['feeling'] as num?)?.toInt(),
      pulseAvg: (j['pulseAvg'] as num?)?.toInt(),
      pulseMax: (j['pulseMax'] as num?)?.toInt(),
      pain: (j['pain'] as num?)?.toInt() ?? 0,
      note: (j['note'] as String?) ?? '',
    );
  }
}

class Diary {
  static const _key = 'diary';
  final SharedPreferences p;
  Diary(this.p);

  Map<int, DayEntry> _all() {
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      final out = <int, DayEntry>{};
      for (final e in m.values) {
        final d = DayEntry.fromJson(e);
        if (d != null) out[d.day] = d;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  DayEntry? forDay(int day) => _all()[day];

  /// Älteste zuerst.
  List<DayEntry> all() => _all().values.toList()..sort((a, b) => a.day.compareTo(b.day));

  /// Früheren Durchgang ablegen: Plan-Tage ≥ 0 rutschen um [shift] ins Negative.
  Future<void> archive(int shift) async => _save({
        for (final e in _all().values)
          if (e.day >= 0)
            e.day - shift: DayEntry(e.day - shift, e.date,
                feeling: e.feeling,
                pulseAvg: e.pulseAvg,
                pulseMax: e.pulseMax,
                pain: e.pain,
                note: e.note)
          else
            e.day: e
      });

  Future<void> set(DayEntry e) async {
    final all = _all()..[e.day] = e;
    await _save(all);
  }

  Future<void> remove(int day) async => _save(_all()..remove(day));

  Future<void> _save(Map<int, DayEntry> all) => p.setString(
      _key, jsonEncode({for (final e in all.entries) '${e.key}': e.value.toJson()}));
}

/// Körperwerte, unabhängig von den Einheiten: Ruhepuls und Körpergewicht
/// (am besten morgens nach dem Aufstehen). Gespeichert in 'vitals': {Datum: Eintrag}.
class VitalEntry {
  final DateTime date;
  final int? restingPulse;
  final double? bodyKg;
  const VitalEntry(this.date, {this.restingPulse, this.bodyKg});

  Map<String, Object?> toJson() => {
        'date': isoDate(date),
        if (restingPulse != null) 'rhr': restingPulse,
        if (bodyKg != null) 'bw': bodyKg,
      };

  static VitalEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = parseIsoDate(j['date'] as String?);
    if (date == null) return null;
    return VitalEntry(date,
        restingPulse: (j['rhr'] as num?)?.toInt(), bodyKg: (j['bw'] as num?)?.toDouble());
  }
}

class Vitals {
  static const _key = 'vitals';
  final SharedPreferences p;
  Vitals(this.p);

  Map<String, VitalEntry> _all() {
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      final out = <String, VitalEntry>{};
      for (final e in m.values) {
        final v = VitalEntry.fromJson(e);
        if (v != null) out[isoDate(v.date)] = v;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  VitalEntry? forDate(DateTime d) => _all()[isoDate(d)];

  /// Älteste zuerst.
  List<VitalEntry> all() => _all().values.toList()..sort((a, b) => a.date.compareTo(b.date));

  Future<void> set(VitalEntry v) async {
    final all = _all()..[isoDate(v.date)] = v;
    await _save(all);
  }

  Future<void> remove(DateTime d) async => _save(_all()..remove(isoDate(d)));

  Future<void> _save(Map<String, VitalEntry> all) =>
      p.setString(_key, jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}));
}

String vitalSummary(VitalEntry v) => [
      if (v.restingPulse != null) 'Ruhepuls ${v.restingPulse}',
      if (v.bodyKg != null) kgLabel(v.bodyKg!),
    ].join(' · ');

/// Ruhepuls und Körpergewicht für [date] eintragen. Rückgabe: true = geändert.
Future<bool> showVitalsDialog(BuildContext context, Vitals vitals, DateTime date) async {
  final existing = vitals.forDate(date);
  final last = vitals.all().where((v) => v.date != date).lastOrNull;
  final rhrCtl = TextEditingController(text: existing?.restingPulse?.toString() ?? '');
  final bwCtl = TextEditingController(
      text: existing?.bodyKg == null ? '' : kgLabel(existing!.bodyKg!).replaceAll(' kg', ''));

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Körperwerte – ${dateLabel(date)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Am besten morgens nach dem Aufstehen, vor dem Frühstück – '
                'Körpergewicht reicht einmal pro Woche, immer unter gleichen Bedingungen. '
                'Ein steigender Ruhepuls oder fallendes Gewicht zeigt Überlastung.'),
            if (last != null) ...[
              const SizedBox(height: 8),
              Text('Zuletzt (${dateLabel(last.date)}): ${vitalSummary(last)}'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: rhrCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Ruhepuls', suffixText: 'bpm', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bwCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(
                  labelText: 'Körpergewicht', suffixText: 'kg', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Löschen')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Speichern')),
      ],
    ),
  );
  // Controller nicht sofort freigeben (Schließ-Animation des Dialogs).
  if (result == 'delete') {
    await vitals.remove(date);
    return true;
  }
  if (result != 'save') return false;
  final rhr = _parseInt(rhrCtl.text, 25, 200);
  final bw = parseKg(bwCtl.text);
  if (rhr == null && bw == null) return false;
  await vitals.set(VitalEntry(date, restingPulse: rhr, bodyKg: bw));
  return true;
}

String diarySummary(DayEntry e) {
  final parts = [
    if (e.feeling != null) 'Befinden ${e.feeling}/5 (${feelingLabels[e.feeling! - 1]})',
    if (e.pulseAvg != null || e.pulseMax != null)
      'Puls ${[
        if (e.pulseAvg != null) 'Ø ${e.pulseAvg}',
        if (e.pulseMax != null) 'max ${e.pulseMax}',
      ].join(' / ')}',
    if (e.pain > 0) 'Beschwerden ${e.pain}/10',
    if (e.note.isNotEmpty) '„${e.note}“',
  ];
  return parts.join(' · ');
}

/// Karte in der Einheit: zeigt den Eintrag oder lädt zum Eintragen ein.
class DiaryInfo extends StatelessWidget {
  final DayEntry? entry;
  final VoidCallback onTap;
  const DiaryInfo({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.secondaryContainer.withOpacity(0.5),
      child: ListTile(
        onTap: onTap,
        leading: Icon(entry == null ? Icons.sentiment_satisfied_alt : Icons.edit,
            color: cs.primary),
        title: Text(entry == null ? 'Wie war’s? Befinden & Puls eintragen' : 'Mein Protokoll'),
        subtitle: entry == null ? null : Text(diarySummary(entry!)),
      ),
    );
  }
}

int? _parseInt(String s, int min, int max) {
  final v = int.tryParse(s.trim());
  return v == null || v < min || v > max ? null : v;
}

/// Eingabe für Plan-Tag [day]. Rückgabe: true = geändert.
Future<bool> showDiaryDialog(
    BuildContext context, Diary diary, String title, int day, DateTime date) async {
  final existing = diary.forDay(day);
  final avgCtl = TextEditingController(text: existing?.pulseAvg?.toString() ?? '');
  final maxCtl = TextEditingController(text: existing?.pulseMax?.toString() ?? '');
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  int? feeling = existing?.feeling;
  var pain = existing?.pain ?? 0;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Wie war’s? – $title'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Befinden', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 0, children: [
                for (var i = 1; i <= 5; i++)
                  ChoiceChip(
                    label: Text('$i · ${feelingLabels[i - 1]}'),
                    selected: feeling == i,
                    onSelected: (v) => setState(() => feeling = v ? i : null),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: avgCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Ø Puls', suffixText: 'bpm', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Max. Puls', suffixText: 'bpm', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text('Beschwerden Achillessehne / Knie: ${pain == 0 ? 'keine' : '$pain/10'}',
                  style: Theme.of(ctx).textTheme.titleSmall),
              Slider(
                value: pain.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: pain == 0 ? 'keine' : '$pain',
                onChanged: (v) => setState(() => pain = v.round()),
              ),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  hintText: 'z. B. schwere Beine, gut geschlafen',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Löschen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(existing == null ? 'Später' : 'Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Speichern')),
        ],
      ),
    ),
  );
  // Controller nicht sofort freigeben: Die Schließ-Animation des Dialogs
  // baut die Felder noch einmal auf.
  if (result == 'delete') {
    await diary.remove(day);
    return true;
  }
  if (result != 'save') return false;
  final today = todayDate();
  await diary.set(DayEntry(
    day,
    date.isAfter(today) ? today : date,
    feeling: feeling,
    pulseAvg: _parseInt(avgCtl.text, 30, 250),
    pulseMax: _parseInt(maxCtl.text, 30, 250),
    pain: pain,
    note: noteCtl.text.trim(),
  ));
  return true;
}

// ---------------------------------------------------------------------------
// Bericht
// ---------------------------------------------------------------------------

String _kgNum(double kg) => kgLabel(kg);

/// Textbericht mit allem, was für eine Plananpassung wichtig ist.
String buildReport(Store store, {DateTime? today}) {
  final now = today ?? todayDate();
  final plan = store.schedule(now);
  final diary = store.diary;
  final b = StringBuffer();

  final training = [for (var d = 0; d < planDays; d++) if (!sessionFor(d).isRest) d];
  final doneDays = training.where(store.done).toList();
  b.writeln('# Laufplan – Trainingsprotokoll');
  b.writeln('Stand: ${dateLabel(now)}${now.year} · Plan gestartet ${dateLabel(planStart)}${planStart.year} (der Reihe nach, ohne feste Termine)');
  b.writeln('Schwerpunkt: Grundlagenausdauer + Beine, Intervalle/Bergsprints 1×/Woche kurz, '
      'Oberkörper nur Erhalt 1×/Woche.');
  b.writeln();
  b.writeln('## Überblick');
  b.writeln('- Erledigt: ${doneDays.length} von ${training.length} Trainingseinheiten');
  final entries = diary.all();
  final feelings = [for (final e in entries) if (e.feeling != null) e.feeling!];
  if (feelings.isNotEmpty) {
    final avg = feelings.reduce((a, c) => a + c) / feelings.length;
    b.writeln('- Ø Befinden: ${avg.toStringAsFixed(1).replaceAll('.', ',')}/5 '
        '(${feelings.length} Einträge)');
  }
  final pulses = [for (final e in entries) if (e.pulseAvg != null) e.pulseAvg!];
  if (pulses.isNotEmpty) {
    b.writeln('- Ø Puls über alle Einheiten: ${(pulses.reduce((a, c) => a + c) / pulses.length).round()} bpm');
  }
  final maxPain = entries.fold<int>(0, (m, e) => e.pain > m ? e.pain : m);
  b.writeln('- Höchste Beschwerden Achillessehne/Knie: ${maxPain == 0 ? 'keine' : '$maxPain/10'}');
  b.writeln();

  b.writeln('## Einheiten');
  for (var d = 0; d < planDays; d++) {
    final s = sessionFor(d);
    if (s.isRest) continue;
    final e = diary.forDay(d);
    final done = store.done(d);
    if (!done && e == null) continue;
    final when = done ? 'erledigt ${dateLabel(plan[d].date)}' : 'offen';
    b.writeln('- Woche ${d ~/ 7 + 1} · ${s.title} · $when'
        '${e == null ? '' : ' · ${diarySummary(e)}'}');
  }
  b.writeln();

  final earlier = entries.where((e) => e.day < 0).toList();
  if (earlier.isNotEmpty) {
    b.writeln('## Früherer Durchgang (vor dem Neustart)');
    for (final e in earlier) {
      b.writeln('- ${dateLabel(e.date)}: ${diarySummary(e)}');
    }
    b.writeln();
  }

  final wlog = store.weights;
  if (wlog.names.isNotEmpty) {
    b.writeln('## Gewichte (Zusatzgewicht), älteste zuerst');
    for (final name in wlog.names) {
      final h = wlog.history(name).reversed.toList();
      b.writeln('- $name: ${h.map((w) => '${dateLabel(w.date)} ${_kgNum(w.kg)}'
          '${w.note.isEmpty ? '' : ' (${w.note})'}').join(' → ')}');
    }
    b.writeln();
  }

  final rlog = store.runs;
  if (rlog.names.isNotEmpty) {
    b.writeln('## Läufe, älteste zuerst');
    for (final name in rlog.names) {
      b.writeln('- $name:');
      for (final r in rlog.history(name).reversed) {
        b.writeln('  - ${runSummary(r)}');
      }
    }
    b.writeln();
  }

  final vitals = Vitals(store.p).all();
  if (vitals.isNotEmpty) {
    b.writeln('## Körperwerte (Ruhepuls, Körpergewicht), älteste zuerst');
    for (final v in vitals) {
      b.writeln('- ${dateLabel(v.date)}: ${vitalSummary(v)}');
    }
    b.writeln();
  }

  final free = store.free.all();
  if (free.isNotEmpty) {
    b.writeln('## Freie Einheiten');
    for (final f in free) {
      b.writeln('- ${dateLabel(f.date)} · ${f.title} · ${f.minutes} Min. · '
          '${f.replacesPlan ? 'statt Plan' : 'zusätzlich'}${f.done ? ' · erledigt' : ''}');
    }
    b.writeln();
  }

  return b.toString().trimRight();
}

class ReportScreen extends StatefulWidget {
  final Store store;
  const ReportScreen({super.key, required this.store});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Store get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final report = buildReport(store);
    final name = 'laufplan-protokoll-${isoDate(todayDate())}.txt';

    Future<void> share() async {
      try {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(utf8.encode(report), mimeType: 'text/plain')],
          fileNameOverrides: [name],
          subject: 'Laufplan – Trainingsprotokoll',
        ));
      } catch (_) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('Teilen fehlgeschlagen. Bitte erneut versuchen.')));
      }
    }

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: report));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Kopiert – jetzt im Chat einfügen.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Protokoll / Auswertung')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          const Text('Alles auf einen Blick: Befinden, Puls, Beschwerden, Zusatzgewichte '
              'und Läufe. Teile den Bericht nach Ende des Plans oder zwischendurch, '
              'um den Plan anpassen zu lassen.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              if (await showVitalsDialog(context, Vitals(store.p), todayDate()) && mounted) {
                setState(() {});
              }
            },
            icon: const Icon(Icons.monitor_weight_outlined),
            label: const Text('Ruhepuls & Körpergewicht heute eintragen'),
          ),
          const SizedBox(height: 12),
          SelectableText(report, style: const TextStyle(fontSize: 13, height: 1.35)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: copy,
                icon: const Icon(Icons.copy),
                label: const Text('Kopieren'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Teilen'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
