import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animations.dart';
import 'main.dart';

// Plan bearbeiten: Der Plan besteht aus Bausteinen (Vorlagen), die an
// mehreren Tagen vorkommen. Änderungen an einem Baustein gelten für alle
// Tage mit diesem Baustein und werden als JSON gespeichert ('tpl_<key>').

final templateKeys = [
  'legA', 'upper', 'legB',
  for (var w = 0; w < planDays ~/ 7; w++) 'base$w',
  for (var w = 0; w < planDays ~/ 7; w++) 'quality$w',
  for (var w = 0; w < planDays ~/ 7; w++) 'long$w',
  'rest',
];

/// Welcher Baustein liegt an Plan-Tag [day]? Reihenfolge je Woche:
/// Grundlagenlauf, Qualität (Steigerungen/Bergsprints/Intervalle), Beine A,
/// Ruhetag, Beine B, Oberkörper, Langer Lauf. Die Qualitätseinheit liegt damit
/// immer 4 Einheiten nach Beine B (und 6 nach Beine A) – auch ohne Ruhetag.
String templateKeyFor(int day) {
  final week = day ~/ 7;
  switch (day % 7) {
    case 0:
      return 'base$week';
    case 1:
      return 'quality$week';
    case 2:
      return 'legA';
    case 3:
      return 'rest';
    case 4:
      return 'legB';
    case 5:
      return 'upper';
    default:
      return 'long$week';
  }
}

Session defaultTemplate(String key) {
  if (key.startsWith('base')) return baseRuns[int.parse(key.substring(4))];
  if (key.startsWith('quality')) return qualityRuns[int.parse(key.substring(7))];
  if (key.startsWith('long')) return longRuns[int.parse(key.substring(4))];
  return switch (key) {
    'legA' => legA,
    'upper' => upperBody,
    'legB' => legB,
    _ => restDay,
  };
}

String templateLabel(String key) {
  if (key.startsWith('base')) return 'Grundlagenlauf Woche ${int.parse(key.substring(4)) + 1}';
  if (key.startsWith('quality')) return 'Lauf Woche ${int.parse(key.substring(7)) + 1}';
  if (key.startsWith('long')) return 'Langer Lauf Woche ${int.parse(key.substring(4)) + 1}';
  return switch (key) {
    'legA' => 'Beine A',
    'upper' => 'Oberkörper',
    'legB' => 'Beine B',
    _ => 'Ruhetag',
  };
}

/// Geänderte Bausteine (geladen beim Start, siehe [loadPlanOverrides]).
final Map<String, Session> planOverrides = {};

void loadPlanOverrides(SharedPreferences p) {
  planOverrides.clear();
  for (final key in templateKeys) {
    final raw = p.getString('tpl_$key');
    if (raw == null) continue;
    try {
      final s = sessionFromJson(jsonDecode(raw), defaultTemplate(key));
      if (s != null) planOverrides[key] = s;
    } catch (_) {}
  }
}

Future<void> saveTemplate(Store store, String key, Session? s) async {
  if (s == null) {
    planOverrides.remove(key);
    await store.p.remove('tpl_$key');
  } else {
    planOverrides[key] = s;
    await store.p.setString('tpl_$key', jsonEncode(sessionToJson(s)));
  }
  // Übungs-Haken offener Tage mit diesem Baustein passen nicht mehr zur Liste.
  for (var d = 0; d < planDays; d++) {
    if (templateKeyFor(d) != key || store.done(d)) continue;
    for (var i = 0; i < 40; i++) {
      await store.p.remove('ex_${d}_$i');
    }
  }
}

// ---------------------------------------------------------------------------
// JSON
// ---------------------------------------------------------------------------

Map<String, Object?> exerciseToJson(Exercise e) => {
      'name': e.name,
      'detail': e.detail,
      if (e.timer != null)
        'timer': {
          'work': e.timer!.work,
          'rest': e.timer!.rest,
          'rounds': e.timer!.rounds,
          'label': e.timer!.workLabel,
        },
      'restAfter': e.restAfter,
      if (e.anim != null) 'anim': e.anim,
      if (e.video != null) 'video': e.video,
    };

Exercise? exerciseFromJson(Object? j) {
  if (j is! Map) return null;
  final name = j['name'];
  if (name is! String || name.trim().isEmpty) return null;
  final t = j['timer'];
  int n(Object? v, int def) => v is num ? v.toInt() : def;
  return Exercise(
    name,
    (j['detail'] as String?) ?? '',
    t is Map
        ? TimerConfig(
            work: n(t['work'], 0),
            rest: n(t['rest'], 0),
            rounds: n(t['rounds'], 1).clamp(1, 99),
            workLabel: (t['label'] as String?) ?? 'Satz',
          )
        : null,
    n(j['restAfter'], 0),
    j['anim'] as String?,
    j['video'] as String?,
  );
}

Map<String, Object?> sessionToJson(Session s) => {
      'title': s.title,
      'minutes': s.minutes,
      if (s.hint != null) 'hint': s.hint,
      'exercises': [for (final e in s.exercises) exerciseToJson(e)],
    };

/// Icon und Ruhetag-Eigenschaft kommen vom Original-Baustein.
Session? sessionFromJson(Object? j, Session base) {
  if (j is! Map) return null;
  final list = j['exercises'];
  return Session(
    (j['title'] as String?) ?? base.title,
    base.icon,
    (j['minutes'] is num) ? (j['minutes'] as num).toInt() : base.minutes,
    list is List ? list.map(exerciseFromJson).whereType<Exercise>().toList() : const [],
    hint: j['hint'] as String?,
    isRest: base.isRest,
  );
}

// ---------------------------------------------------------------------------
// Übersicht: alle Bausteine
// ---------------------------------------------------------------------------

class PlanEditorScreen extends StatefulWidget {
  final Store store;
  const PlanEditorScreen({super.key, required this.store});
  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
              'Der Plan besteht aus Bausteinen. Änderst du einen Baustein, gilt das '
              'für alle Tage, an denen er im Plan steht.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (final key in templateKeys)
            Builder(builder: (_) {
              final s = planOverrides[key] ?? defaultTemplate(key);
              final count = [
                for (var d = 0; d < planDays; d++)
                  if (templateKeyFor(d) == key) d
              ].length;
              final changed = planOverrides.containsKey(key);
              return Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                child: ListTile(
                  leading: Icon(s.icon, color: cs.primary),
                  title: Text(s.title),
                  subtitle: Text('${templateLabel(key)} · ${count}× im Plan · '
                      '${s.exercises.length} Übungen'
                      '${changed ? ' · geändert' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SessionEditorScreen(store: widget.store, templateKey: key)));
                    setState(() {});
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Einen Baustein bearbeiten
// ---------------------------------------------------------------------------

class _Item {
  static int _next = 0;
  final int id = _next++;
  Exercise e;
  _Item(this.e);
}

class SessionEditorScreen extends StatefulWidget {
  final Store store;
  final String templateKey;
  const SessionEditorScreen({super.key, required this.store, required this.templateKey});
  @override
  State<SessionEditorScreen> createState() => _SessionEditorScreenState();
}

class _SessionEditorScreenState extends State<SessionEditorScreen> {
  late Session base = planOverrides[widget.templateKey] ?? defaultTemplate(widget.templateKey);
  late final title = TextEditingController(text: base.title);
  late final hint = TextEditingController(text: base.hint ?? '');
  late int minutes = base.minutes;
  late List<_Item> items = [for (final e in base.exercises) _Item(e)];
  bool dirty = false;

  @override
  void dispose() {
    title.dispose();
    hint.dispose();
    super.dispose();
  }

  void _changed(VoidCallback f) => setState(() {
        f();
        dirty = true;
      });

  Session get current {
    final b = defaultTemplate(widget.templateKey);
    return Session(
      title.text.trim().isEmpty ? b.title : title.text.trim(),
      b.icon,
      minutes,
      [for (final i in items) i.e],
      hint: hint.text.trim().isEmpty ? null : hint.text.trim(),
      isRest: b.isRest,
    );
  }

  Future<void> _edit([_Item? item]) async {
    final e = await Navigator.push<Exercise>(
        context, MaterialPageRoute(builder: (_) => ExerciseEditorScreen(initial: item?.e)));
    if (e == null) return;
    _changed(() {
      if (item == null) {
        items.add(_Item(e));
      } else {
        item.e = e;
      }
    });
  }

  void _remove(_Item item) {
    final index = items.indexOf(item);
    _changed(() => items.remove(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('„${item.e.name}“ entfernt'),
        action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () => _changed(() => items.insert(index.clamp(0, items.length), item))),
      ));
  }

  Future<void> _save() async {
    await saveTemplate(widget.store, widget.templateKey, current);
    if (!mounted) return;
    dirty = false;
    Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auf Original zurücksetzen?'),
        content: const Text('Alle Änderungen an diesem Baustein gehen verloren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (ok != true) return;
    await saveTemplate(widget.store, widget.templateKey, null);
    if (!mounted) return;
    dirty = false;
    Navigator.pop(context, true);
  }

  Future<bool> _confirmDiscard() async {
    if (!dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Weiter bearbeiten')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verwerfen')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final changed = planOverrides.containsKey(widget.templateKey);
    final count = [
      for (var d = 0; d < planDays; d++)
        if (templateKeyFor(d) == widget.templateKey) d
    ].length;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(templateLabel(widget.templateKey)),
          actions: [
            if (changed)
              IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: 'Auf Original zurücksetzen',
                  onPressed: _reset),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Übung'),
        ),
        body: ReorderableListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gilt für $count Tag${count == 1 ? '' : 'e'} im Plan.', style: tt.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                onChanged: (_) => dirty = true,
              ),
              const SizedBox(height: 12),
              NumberStepper(
                label: 'Geschätzte Dauer',
                value: minutes,
                step: 5,
                min: 5,
                max: 240,
                format: (v) => '$v Min.',
                onChanged: (v) => _changed(() => minutes = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hint,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Hinweis (optional)', border: OutlineInputBorder()),
                onChanged: (_) => dirty = true,
              ),
              const SizedBox(height: 16),
              Text('Übungen – zum Sortieren gedrückt halten und ziehen', style: tt.titleSmall),
              const SizedBox(height: 4),
            ],
          ),
          onReorder: (from, to) => _changed(() {
            if (to > from) to--;
            items.insert(to, items.removeAt(from));
          }),
          children: [
            for (final item in items)
              Card(
                key: ValueKey(item.id),
                elevation: 0,
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                child: ListTile(
                  title: Text(item.e.name),
                  subtitle: Text([
                    if (item.e.detail.isNotEmpty) item.e.detail,
                    timerSummary(item.e),
                  ].join('\n')),
                  isThreeLine: item.e.detail.isNotEmpty,
                  onTap: () => _edit(item),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Entfernen',
                    onPressed: () => _remove(item),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: _save, child: const Text('Speichern')),
          ),
        ),
      ),
    );
  }
}

String timerSummary(Exercise e) {
  final t = e.timer;
  final parts = <String>[
    if (t == null) 'Kein Timer',
    if (t != null && t.work == 0)
      '${t.rounds} ${t.workLabel}${t.rounds == 1 ? '' : '(e)'}'
          '${t.rest > 0 ? ', Pause ${fmt(t.rest)}' : ''}',
    if (t != null && t.work > 0)
      '${t.rounds} × ${fmt(t.work)} ${t.workLabel}'
          '${t.rest > 0 ? ', Pause ${fmt(t.rest)}' : ''}',
    if (e.restAfter > 0) 'danach ${fmt(e.restAfter)} Wechsel',
  ];
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Eine Übung bearbeiten
// ---------------------------------------------------------------------------

enum TimerKind { none, sets, interval }

class ExerciseEditorScreen extends StatefulWidget {
  final Exercise? initial;
  const ExerciseEditorScreen({super.key, this.initial});
  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late final Exercise? e0 = widget.initial;
  late final name = TextEditingController(text: e0?.name ?? '');
  late final detail = TextEditingController(text: e0?.detail ?? '');
  late final label = TextEditingController(text: e0?.timer?.workLabel ?? 'Satz');
  late final video = TextEditingController(text: e0?.video ?? '');
  late TimerKind kind = e0?.timer == null
      ? (e0 == null ? TimerKind.sets : TimerKind.none)
      : (e0!.timer!.work > 0 ? TimerKind.interval : TimerKind.sets);
  late int rounds = e0?.timer?.rounds ?? 3;
  late int work = (e0?.timer?.work ?? 0) > 0 ? e0!.timer!.work : 30;
  late int rest = e0?.timer?.rest ?? 90;
  late int restAfter = e0?.restAfter ?? 90;

  /// null = automatisch nach Name, '' = keine, sonst Name einer Strichfigur.
  late String? anim = e0?.anim;

  @override
  void dispose() {
    name.dispose();
    detail.dispose();
    label.dispose();
    video.dispose();
    super.dispose();
  }

  Exercise? get result {
    final n = name.text.trim();
    if (n.isEmpty) return null;
    final l = label.text.trim().isEmpty ? 'Satz' : label.text.trim();
    final v = video.text.trim();
    return Exercise(
      n,
      detail.text.trim(),
      switch (kind) {
        TimerKind.none => null,
        TimerKind.sets => TimerConfig(rest: rest, rounds: rounds, workLabel: l),
        TimerKind.interval => TimerConfig(work: work, rest: rest, rounds: rounds, workLabel: l),
      },
      restAfter,
      anim,
      v.isEmpty ? null : v,
    );
  }

  void _done() {
    final r = result;
    if (r == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bitte einen Namen eingeben.')));
      return;
    }
    Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final preview = result == null ? null : animFor(result!);
    return Scaffold(
      appBar: AppBar(title: Text(e0 == null ? 'Neue Übung' : 'Übung bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detail,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Sätze / Wiederholungen / Hinweis',
                hintText: 'z. B. 3 × 8, 2 Wdh. im Tank',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('Timer', style: tt.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<TimerKind>(
            segments: const [
              ButtonSegment(value: TimerKind.none, label: Text('Keiner')),
              ButtonSegment(value: TimerKind.sets, label: Text('Sätze')),
              ButtonSegment(value: TimerKind.interval, label: Text('Intervall')),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setState(() => kind = v.first),
          ),
          const SizedBox(height: 4),
          Text(
              switch (kind) {
                TimerKind.none => 'Nur abhaken, ohne Timer.',
                TimerKind.sets => 'Satz selbst beenden, danach läuft die Pause automatisch.',
                TimerKind.interval => 'Arbeit und Pause laufen automatisch (z. B. Halten, Sprints).',
              },
              style: tt.bodySmall),
          if (kind != TimerKind.none) ...[
            const SizedBox(height: 8),
            NumberStepper(
              label: kind == TimerKind.sets ? 'Sätze' : 'Runden',
              value: rounds,
              step: 1,
              min: 1,
              max: 30,
              format: (v) => '$v',
              onChanged: (v) => setState(() => rounds = v),
            ),
            if (kind == TimerKind.interval)
              NumberStepper(
                label: 'Arbeit',
                value: work,
                step: 5,
                min: 5,
                max: 1800,
                format: fmt,
                onChanged: (v) => setState(() => work = v),
              ),
            NumberStepper(
              label: 'Pause zwischen den Sätzen',
              value: rest,
              step: 15,
              min: 0,
              max: 600,
              format: (v) => v == 0 ? 'keine' : fmt(v),
              onChanged: (v) => setState(() => rest = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: label,
              decoration: const InputDecoration(
                  labelText: 'Bezeichnung im Timer',
                  hintText: 'Satz, Halten, Runde …',
                  border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          NumberStepper(
            label: 'Wechselpause danach',
            value: restAfter,
            step: 15,
            min: 0,
            max: 600,
            format: (v) => v == 0 ? 'keine' : fmt(v),
            onChanged: (v) => setState(() => restAfter = v),
          ),
          const SizedBox(height: 16),
          Text('Strichfigur', style: tt.titleSmall),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: anim,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Automatisch (nach Name)')),
              const DropdownMenuItem(value: '', child: Text('Keine')),
              for (final k in exerciseAnims.keys)
                DropdownMenuItem(value: k, child: Text('wie „$k“')),
            ],
            onChanged: (v) => setState(() => anim = v),
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            Center(child: ExerciseAnimation(anim: preview, size: 160)),
            Text(preview.cue, textAlign: TextAlign.center, style: tt.bodySmall),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: video,
            decoration: const InputDecoration(
                labelText: 'Erklärvideo (optional)',
                hintText: 'YouTube-Link oder Suchbegriff',
                border: OutlineInputBorder()),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _done, child: const Text('Übernehmen')),
        ),
      ),
    );
  }
}

/// Zahl mit −/+ (z. B. Sätze, Sekunden, Minuten).
class NumberStepper extends StatelessWidget {
  final String label;
  final int value, step, min, max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(child: Text(label, style: tt.bodyLarge)),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        tooltip: '$label weniger',
        onPressed: value - step >= min ? () => onChanged(value - step) : null,
      ),
      SizedBox(
        width: 72,
        child: Text(format(value), textAlign: TextAlign.center, style: tt.titleMedium),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        tooltip: '$label mehr',
        onPressed: value + step <= max ? () => onChanged(value + step) : null,
      ),
    ]);
  }
}
