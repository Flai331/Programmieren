import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show Exercise, dateLabel, isoDate, parseIsoDate, todayDate;
import 'plan_edit.dart' show templateKeyFor;

// Gewichte-Tagebuch: pro Übungsname ein Eintrag je Plan-Tag (Gewicht + Notiz).
// Beim nächsten Vorkommen der Übung wird der letzte Eintrag angezeigt.
// Gespeichert als JSON in 'weight_log': {Übungsname: [Einträge]}.

class WeightEntry {
  final int day; // Plan-Tag (Slot)
  final DateTime date;
  final double kg;
  final String note;
  const WeightEntry(this.day, this.date, this.kg, [this.note = '']);

  Map<String, Object?> toJson() =>
      {'day': day, 'date': isoDate(date), 'kg': kg, if (note.isNotEmpty) 'note': note};

  static WeightEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = parseIsoDate(j['date'] as String?);
    final kg = j['kg'];
    final day = j['day'];
    if (date == null || kg is! num || day is! num) return null;
    return WeightEntry(day.toInt(), date, kg.toDouble(), (j['note'] as String?) ?? '');
  }
}

class WeightLog {
  static const _key = 'weight_log';
  final SharedPreferences p;
  WeightLog(this.p);

  Map<String, List<WeightEntry>> _all() {
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is List)
            '${e.key}': (e.value as List).map(WeightEntry.fromJson).whereType<WeightEntry>().toList()
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, List<WeightEntry>> all) => p.setString(_key,
      jsonEncode({for (final e in all.entries) e.key: [for (final w in e.value) w.toJson()]}));

  /// Alle Übungen mit Einträgen.
  List<String> get names => _all().keys.toList()..sort();

  /// Neueste zuerst.
  List<WeightEntry> history(String name) => [...?_all()[name]]..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.day.compareTo(a.day);
    });

  WeightEntry? forDay(String name, int day) =>
      history(name).where((w) => w.day == day).firstOrNull;

  /// Letzter Eintrag von einem anderen Plan-Tag (= „letztes Mal“).
  WeightEntry? lastBefore(String name, int day) =>
      history(name).where((w) => w.day != day).firstOrNull;

  Future<void> set(String name, WeightEntry entry) async {
    final all = _all();
    final list = all[name] ?? [];
    list.removeWhere((w) => w.day == entry.day);
    list.add(entry);
    all[name] = list;
    await _save(all);
  }

  Future<void> remove(String name, int day) async {
    final all = _all();
    all[name]?.removeWhere((w) => w.day == day);
    if (all[name]?.isEmpty ?? false) all.remove(name);
    await _save(all);
  }
}

/// Gewicht nur bei Kraft-Bausteinen (Beine A/B, Oberkörper), nicht beim Aufwärmen.
bool tracksWeight(int day, Exercise e) =>
    const {'legA', 'legB', 'upper'}.contains(templateKeyFor(day)) && e.name != 'Aufwärmen';

/// „62,5 kg“, „60 kg“
String kgLabel(double kg) {
  // 60.00 -> 60, 62.50 -> 62,5, 61.25 -> 61,25
  final s = kg.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  return '${s.replaceAll('.', ',')} kg';
}

/// Akzeptiert „62,5“, „62.5“, „62,5 kg“. null = keine Zahl.
double? parseKg(String s) {
  final t = s.toLowerCase().replaceAll('kg', '').replaceAll(',', '.').trim();
  final v = double.tryParse(t);
  return v == null || v < 0 || v > 1000 ? null : v;
}

String weightSummary(WeightEntry w) =>
    '${kgLabel(w.kg)}${w.note.isEmpty ? '' : ' · ${w.note}'} (${dateLabel(w.date)})';

/// Kurzinfo unter einer Übung: letztes Mal + heute.
class WeightInfo extends StatelessWidget {
  final WeightEntry? last, today;
  final VoidCallback onTap;
  const WeightInfo({super.key, required this.last, required this.today, required this.onTap});

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
            Text('Letztes Mal: ${weightSummary(last!)}',
                style: tt.bodySmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 2),
          ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(today == null ? Icons.add : Icons.edit, size: 16),
            label: Text(today == null
                ? 'Gewicht eintragen'
                : 'Heute: ${kgLabel(today!.kg)}${today!.note.isEmpty ? '' : ' · ${today!.note}'}'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Eingabe für eine Übung an Plan-Tag [day]. Rückgabe: true = geändert.
Future<bool> showWeightDialog(BuildContext context, WeightLog log, String name, int day,
    {DateTime? date}) async {
  final existing = log.forDay(name, day);
  final last = log.lastBefore(name, day);
  final history = log.history(name).where((w) => w.day != day).take(5).toList();
  final kgCtl = TextEditingController(
      text: existing != null
          ? kgLabel(existing.kg).replaceAll(' kg', '')
          : last != null
              ? kgLabel(last.kg).replaceAll(' kg', '')
              : '');
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  String? error;

  void step(double delta, StateSetter setState) {
    final v = (parseKg(kgCtl.text) ?? 0) + delta;
    setState(() {
      kgCtl.text = kgLabel(v < 0 ? 0 : v).replaceAll(' kg', '');
      error = null;
    });
  }

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (last != null) ...[
                Text('Letztes Mal: ${weightSummary(last)}'),
                const SizedBox(height: 12),
              ],
              Row(children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  tooltip: '2,5 kg weniger',
                  onPressed: () => step(-2.5, setState),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: kgCtl,
                    autofocus: existing == null && last == null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Gewicht',
                      suffixText: 'kg',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  tooltip: '2,5 kg mehr',
                  onPressed: () => step(2.5, setState),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  hintText: 'z. B. 4×5, letzter Satz schwer',
                  border: OutlineInputBorder(),
                ),
              ),
              if (history.length > 1) ...[
                const SizedBox(height: 12),
                Text('Verlauf', style: Theme.of(ctx).textTheme.titleSmall),
                for (final w in history)
                  Text('${dateLabel(w.date)}: ${kgLabel(w.kg)}'
                      '${w.note.isEmpty ? '' : ' · ${w.note}'}'),
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
              if (parseKg(kgCtl.text) == null) {
                setState(() => error = 'Bitte eine Zahl eingeben, z. B. 62,5');
                return;
              }
              Navigator.pop(ctx, 'save');
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
  final kg = parseKg(kgCtl.text);
  final note = noteCtl.text.trim();
  // Controller nicht sofort freigeben: Die Schließ-Animation des Dialogs
  // baut die Felder noch einmal auf.
  if (result == 'delete') {
    await log.remove(name, day);
    return true;
  }
  if (result != 'save' || kg == null) return false;
  final today = todayDate();
  final d = date == null || date.isAfter(today) ? today : date;
  await log.set(name, WeightEntry(day, d, kg, note));
  return true;
}
