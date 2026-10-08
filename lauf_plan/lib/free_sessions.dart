import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar.dart';
import 'main.dart' show dateLabel, isoDate, parseIsoDate, todayDate;

// Freie Einheiten (z. B. Dehnen): selbst angelegt, mit Datum und Uhrzeit,
// einzeln als .ics exportierbar. Unabhängig vom 4-Wochen-Plan.

const freeSuggestions = ['Dehnen', 'Mobility', 'Blackroll', 'Yoga', 'Spaziergang'];
const freeDurations = [10, 15, 20, 30, 45, 60];

class FreeSession {
  final String id;
  final String title;
  final DateTime date; // Kalendertag (UTC, 00:00)
  final int startMinutes; // Minuten ab Mitternacht
  final int minutes;
  final String notes;
  final bool done;

  const FreeSession({
    required this.id,
    required this.title,
    required this.date,
    this.startMinutes = 7 * 60,
    this.minutes = 15,
    this.notes = '',
    this.done = false,
  });

  FreeSession copyWith({
    String? title,
    DateTime? date,
    int? startMinutes,
    int? minutes,
    String? notes,
    bool? done,
  }) =>
      FreeSession(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        startMinutes: startMinutes ?? this.startMinutes,
        minutes: minutes ?? this.minutes,
        notes: notes ?? this.notes,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': isoDate(date),
        'start': startMinutes,
        'minutes': minutes,
        'notes': notes,
        'done': done,
      };

  static FreeSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final date = parseIsoDate(j['date'] as String?);
    final id = j['id'];
    if (date == null || id is! String) return null;
    return FreeSession(
      id: id,
      title: (j['title'] as String?) ?? 'Einheit',
      date: date,
      startMinutes: (j['start'] as num?)?.toInt() ?? 7 * 60,
      minutes: (j['minutes'] as num?)?.toInt() ?? 15,
      notes: (j['notes'] as String?) ?? '',
      done: j['done'] == true,
    );
  }

  CalEvent toEvent() => CalEvent(
        uid: 'laufplan-frei-$id@klaas.de',
        title: title,
        day: date,
        startMinutes: startMinutes,
        minutes: minutes,
        description: notes,
      );
}

class FreeStore {
  static const _key = 'free_sessions';
  final SharedPreferences p;
  FreeStore(this.p);

  List<FreeSession> all() {
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(FreeSession.fromJson).whereType<FreeSession>().toList()
        ..sort(_byTime);
    } catch (_) {
      return [];
    }
  }

  static int _byTime(FreeSession a, FreeSession b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.startMinutes.compareTo(b.startMinutes);
  }

  Future<void> _save(List<FreeSession> list) =>
      p.setString(_key, jsonEncode([for (final s in list) s.toJson()]));

  Future<void> upsert(FreeSession s) async {
    final list = all()..removeWhere((x) => x.id == s.id);
    await _save(list..add(s));
  }

  Future<void> remove(String id) async => _save(all()..removeWhere((x) => x.id == id));
}

Future<void> exportFree(BuildContext context, FreeSession s) =>
    shareIcs(context, [s.toEvent()], icsFileName(s.title, s.date));

class FreeSessionTile extends StatelessWidget {
  final FreeSession session;
  final VoidCallback onTap;
  const FreeSessionTile({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final past = session.date.isBefore(todayDate());
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(past ? 0.25 : 0.5),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
            session.done ? Icons.check_circle : Icons.self_improvement,
            color: past && !session.done ? cs.outline : cs.primary),
        title: Text(session.title),
        subtitle: Text('${dateLabel(session.date)}  ${timeLabel(session.startMinutes)}'
            ' · ${session.minutes} Min.'),
        trailing: IconButton(
          icon: const Icon(Icons.event_available),
          tooltip: 'Als Kalenderdatei (.ics) exportieren',
          onPressed: () => exportFree(context, session),
        ),
      ),
    );
  }
}

class FreeSessionScreen extends StatefulWidget {
  final FreeStore store;
  final FreeSession? session; // null = neu
  const FreeSessionScreen({super.key, required this.store, this.session});

  @override
  State<FreeSessionScreen> createState() => _FreeSessionScreenState();
}

class _FreeSessionScreenState extends State<FreeSessionScreen> {
  late final bool isNew = widget.session == null;
  late FreeSession s = widget.session ??
      FreeSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Dehnen',
        date: todayDate(),
      );
  late final title = TextEditingController(text: s.title);
  late final notes = TextEditingController(text: s.notes);

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  FreeSession get current => s.copyWith(
        title: title.text.trim().isEmpty ? 'Einheit' : title.text.trim(),
        notes: notes.text.trim(),
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(s.date.year, s.date.month, s.date.day),
      firstDate: DateTime(2026),
      lastDate: DateTime(2030, 12, 31),
    );
    if (d != null) setState(() => s = s.copyWith(date: DateTime.utc(d.year, d.month, d.day)));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.startMinutes ~/ 60, minute: s.startMinutes % 60),
    );
    if (t != null) setState(() => s = s.copyWith(startMinutes: t.hour * 60 + t.minute));
  }

  Future<void> _save() async {
    await widget.store.upsert(current);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einheit löschen?'),
        content: Text('„${s.title}“ am ${dateLabel(s.date)} wird entfernt. '
            'Einen schon exportierten Kalendertermin musst du im Kalender selbst löschen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.remove(s.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Freie Einheit' : 'Einheit bearbeiten'),
        actions: [
          if (!isNew)
            IconButton(
                icon: const Icon(Icons.delete_outline), tooltip: 'Löschen', onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Was?', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final t in freeSuggestions)
              ChoiceChip(
                label: Text(t),
                selected: title.text.trim() == t,
                onSelected: (_) => setState(() => title.text = t),
              ),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Datum'),
                trailing: Text(dateLabel(s.date), style: tt.titleMedium),
                onTap: _pickDate,
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Beginn'),
                trailing: Text(timeLabel(s.startMinutes), style: tt.titleMedium),
                onTap: _pickTime,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Dauer', style: tt.titleSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            for (final m in freeDurations)
              ChoiceChip(
                label: Text('$m Min.'),
                selected: s.minutes == m,
                onSelected: (_) => setState(() => s = s.copyWith(minutes: m)),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
                labelText: 'Notizen (kommen mit in den Kalender)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Erledigt'),
            value: s.done,
            onChanged: (v) => setState(() => s = s.copyWith(done: v)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => exportFree(context, current),
            icon: const Icon(Icons.event_available),
            label: const Text('Als Kalenderdatei (.ics) exportieren'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _save, child: const Text('Speichern')),
        ),
      ),
    );
  }
}
