import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'animations.dart';
import 'calendar.dart';
import 'free_sessions.dart';
import 'videos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TrainingApp(store: Store(prefs)));
}

// ---------------------------------------------------------------------------
// Plan-Daten
// ---------------------------------------------------------------------------

final DateTime planStart = DateTime.utc(2026, 10, 1); // Donnerstag
const int planDays = 28;
const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const weekdaysLong = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'
];
const weekFocus = ['Gewöhnung', 'Bergsprints', 'Intervalle', 'Tempo'];

class TimerConfig {
  /// Sekunden aktiv. 0 = manuell (Satz/Lauf selbst beenden, dann Pause).
  final int work;
  final int rest;
  final int rounds;
  final String workLabel;
  const TimerConfig({
    this.work = 0,
    this.rest = 0,
    this.rounds = 1,
    this.workLabel = 'Satz',
  });
}

class Exercise {
  final String name;
  final String detail;
  final TimerConfig? timer;

  /// Geschätzte Wechselpause bis zur nächsten Übung in Sekunden
  /// (Durchatmen, Gewichte/Station umbauen). 0 = keine.
  final int restAfter;
  const Exercise(this.name, this.detail, [this.timer, this.restAfter = 0]);
}

class Session {
  final String title;
  final IconData icon;
  final int minutes;
  final List<Exercise> exercises;
  final String? hint;
  final bool isRest;
  const Session(this.title, this.icon, this.minutes, this.exercises,
      {this.hint, this.isRest = false});
}

const upperBody = Session('Oberkörper', Icons.fitness_center, 45, [
  Exercise('Aufwärmen', '5 Min. Rudern locker, Schultern mobilisieren',
      TimerConfig(work: 300, workLabel: 'Aufwärmen'), 60),
  Exercise('Dips EMOM', '10 Min. – jede Minute 10 Wdh.',
      TimerConfig(work: 60, rounds: 10, workLabel: 'Minute'), 120),
  Exercise('Klimmzüge EMOM', '10 Min. – jede Minute 7 Wdh.',
      TimerConfig(work: 60, rounds: 10, workLabel: 'Minute'), 120),
  Exercise('Toes to Bar', '3 × 10–12', TimerConfig(rest: 90, rounds: 3), 90),
  Exercise('Liegestütze', '40 breit, 20 eng, 15 Diamond',
      TimerConfig(rest: 60, rounds: 3, workLabel: 'Variante')),
]);

const legA = Session('Beine A – Kraft', Icons.fitness_center, 60, [
  Exercise('Aufwärmen', '8 Min. Rudern + Glute Bridges, Ausfallschritte',
      TimerConfig(work: 480, workLabel: 'Aufwärmen'), 60),
  Exercise('Kniebeuge (Langhantel)', '4 × 5, 2 Wdh. im Tank lassen',
      TimerConfig(rest: 150, rounds: 4), 180),
  Exercise('Rumänisches Kreuzheben', '3 × 8', TimerConfig(rest: 120, rounds: 3), 150),
  Exercise('Bulgarian Split Squat', '3 × 8 pro Bein',
      TimerConfig(rest: 90, rounds: 3), 120),
  Exercise('Wadenheben einbeinig halten',
      '5 × 45 Sek. pro Bein, abwechselnd. Schmerz max. 3/10',
      TimerConfig(work: 45, rest: 30, rounds: 10, workLabel: 'Halten'), 60),
  Exercise('Copenhagen Plank', '3 × 20 Sek. pro Seite, abwechselnd',
      TimerConfig(work: 20, rest: 20, rounds: 6, workLabel: 'Halten')),
]);

const legB = Session('Beine B – Stabilität', Icons.accessibility_new, 50, [
  Exercise('Aufwärmen', '8 Min. Rudern + Mobilisation',
      TimerConfig(work: 480, workLabel: 'Aufwärmen'), 60),
  Exercise('Hip Thrust', '3 × 8', TimerConfig(rest: 90, rounds: 3), 120),
  Exercise('Einbeiniges Kreuzheben (KH)', '3 × 8 pro Bein',
      TimerConfig(rest: 90, rounds: 3), 90),
  Exercise('Monster Walks mit Band', '3 × 15 Schritte pro Richtung',
      TimerConfig(rest: 45, rounds: 3), 60),
  Exercise('Tibialis Raises', '2 × 15', TimerConfig(rest: 45, rounds: 2), 90),
  Exercise('Finisher', '3 Runden locker: 20 m Schlitten + 250 m Rudern',
      TimerConfig(rest: 60, rounds: 3, workLabel: 'Runde')),
]);

const qualityRuns = [
  Session('Lauf: Steigerungen', Icons.directions_run, 45, [
    Exercise('Locker laufen', '6 km im Plaudertempo'),
    Exercise('Steigerungen',
        '6 × 20 Sek.: langsam anlaufen, auf ca. 80 % steigern, 60 Sek. traben',
        TimerConfig(work: 20, rest: 60, rounds: 6, workLabel: 'Steigerung')),
  ]),
  Session('Lauf: Bergsprints', Icons.terrain, 45, [
    Exercise('Einlaufen', '2 km locker'),
    Exercise('Bergsprints', '6 × 10 Sek. bergauf (80–90 %), zurückgehen als Pause',
        TimerConfig(work: 10, rest: 80, rounds: 6, workLabel: 'Sprint')),
    Exercise('Locker laufen', '3–4 km'),
  ], hint: 'Achillessehne über 3/10? Dann flache Steigerungen statt Bergsprints.'),
  Session('Lauf: Intervalle', Icons.speed, 40, [
    Exercise('Einlaufen', '2 km locker'),
    Exercise('Intervalle',
        '6 × 400 m schnell, 90 Sek. traben. Die letzte so schnell wie die erste.',
        TimerConfig(rest: 90, rounds: 6, workLabel: '400 m')),
    Exercise('Auslaufen', '1–2 km locker'),
  ]),
  Session('Lauf: Tempo', Icons.timer, 45, [
    Exercise('Einlaufen', '2 km locker'),
    Exercise('Tempo', '4 × 1 km zügig (nur einzelne Wörter möglich), 2 Min. traben',
        TimerConfig(rest: 120, rounds: 4, workLabel: 'Kilometer')),
    Exercise('Auslaufen', '1–2 km locker'),
  ]),
];

const _longHint = 'Nur steigern, wenn das Knie in der Woche davor ruhig war.';
const longRuns = [
  Session('Langer Lauf', Icons.route, 50,
      [Exercise('Locker laufen', '8 km im Plaudertempo')], hint: _longHint),
  Session('Langer Lauf', Icons.route, 55,
      [Exercise('Locker laufen', '9 km im Plaudertempo')], hint: _longHint),
  Session('Langer Lauf', Icons.route, 55,
      [Exercise('Locker laufen', '9 km im Plaudertempo')], hint: _longHint),
  Session('Langer Lauf', Icons.route, 60,
      [Exercise('Locker laufen', '10 km im Plaudertempo')], hint: _longHint),
];

const restDay = Session('Ruhetag', Icons.self_improvement, 15, [
  Exercise('Blackroll (optional)', 'Hüfte, Oberschenkel, Waden'),
], hint: 'Puffer: Fällt eine Einheit wegen Schicht aus, hier nachholen.', isRest: true);

// Reihenfolge ab Donnerstag
Session sessionFor(int day) {
  final week = day ~/ 7;
  switch (day % 7) {
    case 0:
      return legA;
    case 1:
      return upperBody;
    case 2:
      return qualityRuns[week];
    case 3:
      return legB;
    case 4:
      return upperBody;
    case 5:
      return longRuns[week];
    default:
      return restDay;
  }
}

DateTime dateOf(int day) => planStart.add(Duration(days: day));
String dateLabel(DateTime d) => '${weekdays[d.weekday - 1]}, ${d.day}.${d.month}.';
DateTime todayDate() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime? parseIsoDate(String? s) => s == null ? null : DateTime.tryParse('${s}T00:00:00Z');

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Ein Tag des Plans mit dem tatsächlichen (ggf. verschobenen) Datum.
class PlanDay {
  final int slot;

  /// Datum, an dem die Einheit liegt (bzw. erledigt wurde).
  final DateTime date;

  /// Datum, an dem die Einheit ohne Nachrücken auf heute fällig gewesen wäre.
  final DateTime due;
  const PlanDay(this.slot, this.date, this.due);

  /// Tage, um die die Einheit gegenüber dem ursprünglichen Plan verschoben ist.
  int get shiftDays => date.difference(dateOf(slot)).inDays;
}

/// Verschiebbarer Plan: Die Einheiten bleiben in ihrer Reihenfolge. Eine nicht
/// erledigte Trainingseinheit rückt auf heute vor, alle folgenden Tage
/// verschieben sich mit. Erledigte Einheiten bleiben an ihrem Erledigt-Datum,
/// Ruhetage verschieben nichts. Tage in [blocked] sind durch eine freie
/// Einheit "statt Plan-Einheit" belegt – offene Trainingseinheiten weichen aus.
List<PlanDay> computeSchedule(DateTime today, bool Function(int) isDone,
    DateTime? Function(int) doneOn,
    {Set<DateTime> blocked = const {}}) {
  final result = <PlanDay>[];
  var cursor = planStart;
  for (var slot = 0; slot < planDays; slot++) {
    final DateTime date;
    if (isDone(slot)) {
      // Ohne gespeichertes Datum (ältere App-Version): wie ursprünglich geplant.
      date = doneOn(slot) ?? dateOf(slot);
    } else if (sessionFor(slot).isRest) {
      date = cursor;
    } else {
      var d = _later(cursor, today);
      while (blocked.contains(d)) {
        d = d.add(const Duration(days: 1));
      }
      date = d;
    }
    result.add(PlanDay(slot, date, cursor));
    cursor = _later(cursor, date.add(const Duration(days: 1)));
  }
  return result;
}

/// Bildschirm anlassen; Fehler (z. B. ohne Plugin im Test) sind egal.
void keepScreenOn(bool on) {
  WakelockPlus.toggle(enable: on).catchError((_) {});
}

String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

const rules = [
  'Schmerz beim Training bis 3 von 10 ist okay. Ist es am nächsten Morgen schlimmer, Belastung reduzieren.',
  'Achillessehne nicht stark dehnen.',
  'Woche 1: Gewichte bei den Beinen bewusst leicht wählen.',
  'Locker = du kannst dich unterhalten. Zügig = nur einzelne Wörter. Schnell = fast Vollgas, aber gleichmäßig.',
  'Fällt ein Tag aus: Einheit einen Tag schieben, der Mittwoch ist Puffer.',
];

// ---------------------------------------------------------------------------
// Speicher
// ---------------------------------------------------------------------------

class Store {
  final SharedPreferences p;
  Store(this.p);
  bool done(int d) => p.getBool('done_$d') ?? false;
  DateTime? doneOn(int d) => parseIsoDate(p.getString('doneOn_$d'));
  Future<void> setDone(int d, bool v, {DateTime? on}) async {
    await p.setBool('done_$d', v);
    if (v) {
      await p.setString('doneOn_$d', isoDate(on ?? todayDate()));
    } else {
      await p.remove('doneOn_$d');
    }
  }

  FreeStore get free => FreeStore(p);

  /// Zuletzt gewählte Uhrzeit für den Kalender-Export.
  int get exportStart => p.getInt('export_start') ?? 18 * 60;
  Future<void> setExportStart(int m) => p.setInt('export_start', m);

  /// [exceptFree]: diese freie Einheit nicht berücksichtigen (beim Bearbeiten).
  List<PlanDay> schedule([DateTime? today, String? exceptFree]) =>
      computeSchedule(today ?? todayDate(), done, doneOn,
          blocked: free.blockedDates(exceptId: exceptFree));

  /// Offene Plan-Einheit, die (ohne [exceptFree]) an [date] liegt.
  String? planTitleOn(DateTime date, {String? exceptFree}) {
    for (final d in schedule(null, exceptFree)) {
      if (d.date == date && !sessionFor(d.slot).isRest && !done(d.slot)) {
        return sessionFor(d.slot).title;
      }
    }
    return null;
  }
  bool exDone(int d, int i) => p.getBool('ex_${d}_$i') ?? false;
  Future<void> setExDone(int d, int i, bool v) => p.setBool('ex_${d}_$i', v);
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class TrainingApp extends StatelessWidget {
  final Store store;
  const TrainingApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D5B);
    return MaterialApp(
      title: 'Laufplan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeScreen(store: store),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Store store;
  const HomeScreen({super.key, required this.store});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _open(int day) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SessionScreen(day: day, store: widget.store)));
    setState(() {});
  }

  Future<void> _backfill(int slot, DateTime due) async {
    final on = await pickDoneDate(context, due: due);
    if (on == null) return;
    await widget.store.setDone(slot, true, on: on);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${sessionFor(slot).title} für ${dateLabel(on)} abgehakt – '
            'der Plan ist angepasst.')));
  }

  Future<void> _openFree([FreeSession? f]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FreeSessionScreen(
                store: widget.store.free,
                session: f,
                planTitleOn: (date, id) => widget.store.planTitleOn(date, exceptFree: id))));
    setState(() {});
  }

  Future<void> _exportAll() async {
    final today = todayDate();
    final open = [
      for (final d in widget.store.schedule(today))
        if (!sessionFor(d.slot).isRest &&
            !widget.store.done(d.slot) &&
            !d.date.isBefore(today))
          d
    ];
    await exportPlanDays(context, widget.store, open,
        title: 'Plan in den Kalender',
        fileName: 'laufplan-einheiten.ics',
        info: '${open.length} offene Einheiten ab heute. Verschiebt sich der Plan, '
            'einfach erneut exportieren – die Termine werden aktualisiert.');
  }

  void _showRules() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regeln'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('• $r'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = todayDate();
    final plan = widget.store.schedule(today);
    // Freie Einheiten: ab einer Woche zurück, ältere ausblenden.
    final free = widget.store.free
        .all()
        .where((f) => !f.date.isBefore(today.subtract(const Duration(days: 7))))
        .toList();
    final trainingDays = [for (var d = 0; d < planDays; d++) if (!sessionFor(d).isRest) d];
    final doneCount = trainingDays.where(widget.store.done).length;

    // Freie Einheiten stehen im Plan beim jeweiligen Datum.
    final pending = [...free];
    List<Widget> takeFree(bool Function(FreeSession) test) {
      final out = <Widget>[];
      pending.removeWhere((f) {
        if (!test(f)) return false;
        out.add(FreeSessionTile(session: f, onTap: () => _openFree(f)));
        return true;
      });
      return out;
    }

    final todayFree = [
      for (final f in free)
        if (f.date == today) FreeSessionTile(session: f, onTap: () => _openFree(f))
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFree(),
        icon: const Icon(Icons.add),
        label: const Text('Freie Einheit'),
      ),
      appBar: AppBar(
        title: const Text('Laufplan'),
        actions: [
          IconButton(
              icon: const Icon(Icons.event_available),
              tooltip: 'Alle Einheiten in den Kalender (.ics)',
              onPressed: _exportAll),
          IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Regeln',
              onPressed: _showRules),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _TodayCard(
              plan: plan,
              today: today,
              store: widget.store,
              onOpen: _open,
              onBackfill: _backfill),
          ...todayFree,
          const SizedBox(height: 12),
          Text('$doneCount von ${trainingDays.length} Einheiten erledigt',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: doneCount / trainingDays.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 4),
            child: Row(children: [
              Expanded(
                child: Text('Freie Einheiten',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => _openFree(),
                icon: const Icon(Icons.add),
                label: const Text('Neu'),
              ),
            ]),
          ),
          Text(
              'Z. B. Dehnen mit Uhrzeit und Dauer anlegen – zusätzlich zur Plan-Einheit '
              'oder statt ihr. Sie steht dann im Plan beim jeweiligen Tag und lässt sich '
              'einzeln als Kalenderdatei exportieren.',
              style: Theme.of(context).textTheme.bodySmall),
          for (var w = 0; w < 4; w++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text('Woche ${w + 1}: ${weekFocus[w]}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (var d = w * 7; d < w * 7 + 7; d++) ...[
              ...takeFree((f) => f.date.isBefore(plan[d].date)),
              _DayTile(
                day: plan[d],
                isToday: plan[d].date == today,
                done: widget.store.done(d),
                onTap: () => _open(plan[d].slot),
                cs: cs,
              ),
              ...takeFree((f) => f.date == plan[d].date),
            ],
          ],
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text('Nach dem Plan', style: Theme.of(context).textTheme.titleMedium),
            ),
          ...takeFree((_) => true),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final List<PlanDay> plan;
  final DateTime today;
  final Store store;
  final void Function(int) onOpen;
  final void Function(int slot, DateTime due) onBackfill;
  const _TodayCard(
      {required this.plan,
      required this.today,
      required this.store,
      required this.onOpen,
      required this.onBackfill});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget info(String text) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(text, style: tt.titleMedium),
          ),
        );

    if (today.isBefore(planStart)) {
      return info('Der Plan startet am ${dateLabel(planStart)}');
    }
    final allDone = [
      for (final p in plan)
        if (!sessionFor(p.slot).isRest) p
    ].every((p) => store.done(p.slot));
    if (allDone) return info('Plan abgeschlossen. Zeit für die nächsten 4 Wochen!');

    // Heute: zuerst eine offene Trainingseinheit, sonst was sonst heute liegt.
    final todays = plan.where((p) => p.date == today).toList()
      ..sort((a, b) {
        int rank(PlanDay p) =>
            (store.done(p.slot) ? 2 : 0) + (sessionFor(p.slot).isRest ? 1 : 0);
        return rank(a).compareTo(rank(b));
      });
    final PlanDay p;
    final bool isToday;
    if (todays.isNotEmpty) {
      p = todays.first;
      isToday = true;
    } else {
      final upcoming = plan.where((x) => x.date.isAfter(today)).toList();
      if (upcoming.isEmpty) return info('Plan abgeschlossen. Zeit für die nächsten 4 Wochen!');
      p = upcoming.first;
      isToday = false;
    }
    final s = sessionFor(p.slot);
    final done = store.done(p.slot);
    final on = cs.onPrimaryContainer;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isToday ? 'Heute' : 'Als Nächstes: ${dateLabel(p.date)}',
                style: tt.labelLarge?.copyWith(color: on)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(s.icon, color: on, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.title, style: tt.headlineSmall?.copyWith(color: on)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(done ? 'Erledigt ✓' : 'ca. ${s.minutes} Min.',
                style: tt.bodyLarge?.copyWith(color: on)),
            if (!done && p.shiftDays > 0)
              Text(shiftText(p.shiftDays), style: tt.bodyMedium?.copyWith(color: on)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => onOpen(p.slot), child: const Text('Training öffnen')),
            if (isToday && !done && !s.isRest && p.due.isBefore(today)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: on),
                onPressed: () => onBackfill(p.slot, p.due),
                icon: const Icon(Icons.history),
                label: const Text('Vergessen abzuhaken? Nachträglich abhaken'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

CalEvent planEvent(PlanDay d, ExportChoice c) {
  final s = sessionFor(d.slot);
  final lines = [
    for (final e in s.exercises) '• ${e.name}: ${e.detail}',
    if (s.hint != null) '',
    if (s.hint != null) s.hint!,
    '',
    'Woche ${d.slot ~/ 7 + 1}: ${weekFocus[d.slot ~/ 7]} · ca. ${s.minutes} Min.',
  ];
  return CalEvent(
    uid: 'laufplan-tag-${d.slot}@klaas.de',
    title: s.title,
    day: d.date,
    startMinutes: c.startMinutes,
    minutes: s.minutes,
    allDay: c.allDay,
    description: lines.join('\n'),
  );
}

/// Eine oder mehrere Plan-Einheiten mit Uhrzeit-Abfrage exportieren.
Future<void> exportPlanDays(BuildContext context, Store store, List<PlanDay> days,
    {required String title, required String fileName, String? info}) async {
  final choice = await askExportTime(context,
      title: title, initialMinutes: store.exportStart, info: info);
  if (choice == null || !context.mounted) return;
  if (!choice.allDay) await store.setExportStart(choice.startMinutes);
  if (!context.mounted) return;
  await shareIcs(context, [for (final d in days) planEvent(d, choice)], fileName);
}

/// Nachtragen: Fragt, an welchem Tag eine Einheit gemacht wurde.
/// Der Plan richtet sich danach (Folgetage rücken entsprechend nach).
/// null = abgebrochen.
Future<DateTime?> pickDoneDate(BuildContext context, {required DateTime due}) async {
  final today = todayDate();
  final yesterday = today.subtract(const Duration(days: 1));
  // Die letzten 7 Tage direkt zur Auswahl (z. B. „Freitag“), ältere über
  // „Anderes Datum“.
  final options = <DateTime>[
    for (var i = 0; i < 7; i++)
      if (!today.subtract(Duration(days: i)).isBefore(planStart))
        today.subtract(Duration(days: i)),
  ];
  if (!due.isBefore(planStart) && !options.contains(due) && due.isBefore(today)) {
    options.add(due);
  }
  String label(DateTime d) {
    final name = d == today
        ? 'Heute'
        : d == yesterday
            ? 'Gestern'
            : weekdaysLong[d.weekday - 1];
    final planned = d == due ? ' – wie geplant' : '';
    return '$name, ${d.day}.${d.month}.$planned';
  }
  final choice = await showDialog<Object>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Wann hast du trainiert?'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Geplant war ${dateLabel(due)}. Der Plan passt sich an das Datum an.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: DateTextField(
            first: planStart,
            last: today,
            onDate: (d) => Navigator.pop(ctx, d),
          ),
        ),
        for (final d in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, d),
            child: Text(label(d), style: Theme.of(ctx).textTheme.titleMedium),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'pick'),
          child: Text('Anderes Datum …', style: Theme.of(ctx).textTheme.titleMedium),
        ),
      ],
    ),
  );
  if (choice is DateTime) return choice;
  if (choice != 'pick' || !context.mounted) return null;
  DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
  final initial = yesterday.isBefore(planStart) ? planStart : yesterday;
  final d = await showDatePicker(
    context: context,
    helpText: 'Wann hast du trainiert?',
    initialDate: local(initial.isAfter(today) ? today : initial),
    firstDate: local(planStart.isAfter(today) ? today : planStart),
    lastDate: local(today),
    initialEntryMode: DatePickerEntryMode.input,
  );
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

/// Datum als Freitext: „7.10.“, „7,10“, „7/10/26“, „07.10.2026“ (Jahr optional,
/// dann das Jahr von [today]). null = nicht lesbar oder kein echtes Datum.
DateTime? parseUserDate(String input, DateTime today) {
  // Trenner: Punkt, Komma, Schrägstrich oder Bindestrich (je nach Tastatur).
  final m = RegExp(r'^(\d{1,2})[.,/-](\d{1,2})[.,/-]?(\d{2}|\d{4})?$').firstMatch(input.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  var year = today.year;
  final y = m.group(3);
  if (y != null) year = y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  final d = DateTime.utc(year, month, day);
  if (d.day != day || d.month != month) return null; // z. B. 31.2.
  return d;
}

/// Eingabefeld für ein Datum als Freitext mit Prüfung auf [first]..[last].
class DateTextField extends StatefulWidget {
  final DateTime first, last;
  final ValueChanged<DateTime> onDate;
  const DateTextField({super.key, required this.first, required this.last, required this.onDate});
  @override
  State<DateTextField> createState() => _DateTextFieldState();
}

class _DateTextFieldState extends State<DateTextField> {
  final c = TextEditingController();
  String? error;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _submit() {
    final d = parseUserDate(c.text, widget.last);
    if (d == null) {
      setState(() => error = 'Bitte so eingeben: 7.10. oder 07.10.2026');
    } else if (d.isBefore(widget.first) || d.isAfter(widget.last)) {
      setState(() => error =
          'Nur zwischen ${dateLabel(widget.first)} und ${dateLabel(widget.last)} möglich');
    } else {
      widget.onDate(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Datum eintippen',
        hintText: 'z. B. 7.10.',
        errorText: error,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Übernehmen',
          onPressed: _submit,
        ),
      ),
    );
  }
}

String shiftText(int days) =>
    'Verschoben um $days ${days == 1 ? 'Tag' : 'Tage'} – der Plan rückt nach.';

class _DayTile extends StatelessWidget {
  final PlanDay day;
  final bool isToday;
  final bool done;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _DayTile(
      {required this.day,
      required this.isToday,
      required this.done,
      required this.onTap,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final s = sessionFor(day.slot);
    final d = day.date;
    final shifted = !s.isRest && day.shiftDays > 0;
    return Card(
      elevation: 0,
      color: isToday ? cs.secondaryContainer : cs.surfaceContainerHighest.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: onTap,
        leading: Icon(s.icon, color: s.isRest ? cs.outline : cs.primary),
        title: Text(s.title),
        subtitle: Text(s.isRest
            ? dateLabel(d)
            : '${dateLabel(d)}  ca. ${s.minutes} Min.'
                '${shifted ? '  (+${day.shiftDays} ${day.shiftDays == 1 ? 'Tag' : 'Tage'})' : ''}'),
        trailing: done
            ? Icon(Icons.check_circle, color: cs.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Einheit
// ---------------------------------------------------------------------------

class SessionScreen extends StatefulWidget {
  final int day;
  final Store store;
  const SessionScreen({super.key, required this.day, required this.store});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final sw = Stopwatch();
  Timer? ticker;
  late final Session s = sessionFor(widget.day);
  late final List<bool> checks = List.generate(
      s.exercises.length, (i) => widget.store.exDone(widget.day, i));
  late bool done = widget.store.done(widget.day);

  @override
  void dispose() {
    ticker?.cancel();
    keepScreenOn(false);
    super.dispose();
  }

  void _toggleStopwatch() {
    if (sw.isRunning) {
      sw.stop();
      ticker?.cancel();
      keepScreenOn(false);
    } else {
      sw.start();
      keepScreenOn(true);
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  void _setCheck(int i, bool v) {
    setState(() => checks[i] = v);
    widget.store.setExDone(widget.day, i, v);
  }

  Exercise? _next(int i) => i + 1 < s.exercises.length ? s.exercises[i + 1] : null;

  Future<void> _openTimer(int i) async {
    final result = await Navigator.push<TimerResult>(
        context,
        MaterialPageRoute(
            builder: (_) => TimerScreen(exercise: s.exercises[i], next: _next(i))));
    if (sw.isRunning) keepScreenOn(true);
    if (result != null) _setCheck(i, true);
    if (result == TimerResult.rest) await _openRest(i);
  }

  /// Wechselpause nach Übung [i]; danach direkt den Timer der nächsten Übung öffnen.
  Future<void> _openRest(int i) async {
    final next = _next(i);
    if (next == null || !mounted) return;
    final go = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => RestScreen(seconds: s.exercises[i].restAfter, next: next)));
    if (sw.isRunning) keepScreenOn(true);
    if (go == true && next.timer != null && mounted) await _openTimer(i + 1);
  }

  bool _hasInfo(Exercise e) =>
      exerciseAnims.containsKey(e.name) || exerciseVideos.containsKey(e.name);

  void _showAnim(Exercise e) {
    final a = exerciseAnims[e.name];
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.name, style: tt.titleLarge),
            if (a != null) ...[
              const SizedBox(height: 8),
              ExerciseAnimation(anim: a, size: 240),
              const SizedBox(height: 12),
              Text(a.cue, textAlign: TextAlign.center, style: tt.bodyLarge),
            ],
            const SizedBox(height: 4),
            Text(e.detail, textAlign: TextAlign.center, style: tt.bodyMedium),
            if (exerciseVideos.containsKey(e.name)) ...[
              const SizedBox(height: 16),
              VideoButton(exerciseName: e.name),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDone() async {
    final v = !done;
    DateTime? on;
    if (v) {
      final today = todayDate();
      final due = widget.store.schedule(today)[widget.day].due;
      // Nachgerückte Einheit: vielleicht doch am geplanten Tag gemacht, nur
      // vergessen abzuhaken – dann soll sich nichts verschieben.
      if (!s.isRest && due.isBefore(today)) {
        on = await pickDoneDate(context, due: due);
        if (on == null) return;
      }
    }
    await widget.store.setDone(widget.day, v, on: on);
    if (v && sw.isRunning) _toggleStopwatch();
    setState(() => done = v);
    if (v && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final elapsed = sw.elapsed.inSeconds;
    final week = widget.day ~/ 7;
    final slot = widget.day % 7;
    final hints = [
      if (s.hint != null) s.hint!,
      if (week == 0 && (slot == 0 || slot == 3)) 'Woche 1: Gewichte bewusst leicht wählen.',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.title), actions: [
        IconButton(
          icon: const Icon(Icons.event_available),
          tooltip: 'In den Kalender (.ics)',
          onPressed: () {
            final pd = widget.store.schedule()[widget.day];
            exportPlanDays(context, widget.store, [pd],
                title: 'In den Kalender',
                fileName: icsFileName(s.title, pd.date),
                info: '${s.title} am ${dateLabel(pd.date)}');
          },
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Builder(builder: (_) {
            final pd = widget.store.schedule()[widget.day];
            if (done) {
              return Row(children: [
                Expanded(
                  child: Text('Erledigt am ${dateLabel(pd.date)}', style: tt.bodyMedium),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final on = await pickDoneDate(context, due: pd.due);
                    if (on == null) return;
                    await widget.store.setDone(widget.day, true, on: on);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Datum ändern'),
                ),
              ]);
            }
            final shifted = !s.isRest && pd.shiftDays > 0;
            return Text(
                shifted
                    ? '${dateLabel(pd.date)} – ursprünglich ${dateLabel(dateOf(widget.day))}'
                    : dateLabel(pd.date),
                style: tt.bodyMedium);
          }),
          if (!s.isRest) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmt(elapsed),
                                  style: tt.displaySmall?.copyWith(
                                      fontFeatures: const [FontFeature.tabularFigures()])),
                              Text('Geschätzt: ca. ${s.minutes} Min.', style: tt.bodyMedium),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _toggleStopwatch,
                          icon: Icon(sw.isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(sw.isRunning
                              ? 'Pause'
                              : elapsed == 0
                                  ? 'Start'
                                  : 'Weiter'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (elapsed / (s.minutes * 60)).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final h in hints)
            Card(
              color: cs.tertiaryContainer,
              child: ListTile(
                leading: Icon(Icons.info_outline, color: cs.onTertiaryContainer),
                title: Text(h, style: TextStyle(color: cs.onTertiaryContainer)),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < s.exercises.length; i++) ...[
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 4, right: 8),
                leading: Checkbox(
                    value: checks[i], onChanged: (v) => _setCheck(i, v ?? false)),
                title: Text(s.exercises[i].name,
                    style: checks[i]
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough, color: cs.outline)
                        : null),
                subtitle: Text(s.exercises[i].detail),
                onTap: !_hasInfo(s.exercises[i])
                    ? null
                    : () => _showAnim(s.exercises[i]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasInfo(s.exercises[i]))
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: 'Ausführung ansehen',
                        onPressed: () => _showAnim(s.exercises[i]),
                      ),
                    if (s.exercises[i].timer != null)
                      IconButton.filledTonal(
                        icon: const Icon(Icons.timer_outlined),
                        tooltip: 'Timer',
                        onPressed: () => _openTimer(i),
                      ),
                  ],
                ),
              ),
            ),
            if (s.exercises[i].restAfter > 0 && _next(i) != null)
              _RestTile(seconds: s.exercises[i].restAfter, onTap: () => _openRest(i)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: done
              ? OutlinedButton(
                  onPressed: _toggleDone, child: const Text('Als offen markieren'))
              : FilledButton(
                  onPressed: _toggleDone, child: const Text('Einheit abschließen')),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer
// ---------------------------------------------------------------------------

enum Phase { ready, work, rest, done }

/// Rückgabe des Übungs-Timers: nur abhaken oder abhaken + Wechselpause starten.
enum TimerResult { done, rest }

class TimerScreen extends StatefulWidget {
  final Exercise exercise;
  final Exercise? next;
  const TimerScreen({super.key, required this.exercise, this.next});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Phase phase = Phase.ready;
  int round = 1;
  int remaining = 0;
  bool running = false;
  Timer? ticker;

  TimerConfig get c => widget.exercise.timer!;
  bool get manual => c.work == 0;

  @override
  void initState() {
    super.initState();
    keepScreenOn(true);
  }

  @override
  void dispose() {
    ticker?.cancel();
    keepScreenOn(false);
    super.dispose();
  }

  void _signal() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _run() {
    ticker?.cancel();
    running = true;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => remaining--);
    if (remaining > 0 && remaining <= 3) SystemSound.play(SystemSoundType.click);
    if (remaining <= 0) {
      ticker?.cancel();
      if (phase == Phase.work) {
        _afterWork();
      } else if (phase == Phase.rest) {
        round++;
        _startWork();
      }
    }
  }

  void _startWork() {
    phase = Phase.work;
    if (manual) {
      ticker?.cancel();
      running = false;
      remaining = 0;
    } else {
      remaining = c.work;
      _run();
    }
    _signal();
    setState(() {});
  }

  void _afterWork() {
    if (round >= c.rounds) {
      _finish();
    } else if (c.rest > 0) {
      phase = Phase.rest;
      remaining = c.rest;
      _run();
      _signal();
      setState(() {});
    } else {
      round++;
      _startWork();
    }
  }

  void _skipRest() {
    ticker?.cancel();
    round++;
    _startWork();
  }

  void _finish() {
    ticker?.cancel();
    running = false;
    phase = Phase.done;
    _signal();
    HapticFeedback.vibrate();
    setState(() {});
  }

  void _togglePause() {
    if (running) {
      ticker?.cancel();
      setState(() => running = false);
    } else {
      _run();
      setState(() {});
    }
  }

  void _reset() {
    ticker?.cancel();
    setState(() {
      phase = Phase.ready;
      round = 1;
      remaining = 0;
      running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final anim = exerciseAnims[widget.exercise.name];

    final (Color bg, Color fg) = switch (phase) {
      Phase.work => (cs.primaryContainer, cs.onPrimaryContainer),
      Phase.rest => (cs.tertiaryContainer, cs.onTertiaryContainer),
      Phase.done => (cs.secondaryContainer, cs.onSecondaryContainer),
      Phase.ready => (cs.surface, cs.onSurface),
    };

    final roundText = c.rounds > 1 ? ' $round/${c.rounds}' : '';
    final status = switch (phase) {
      Phase.ready => 'Bereit',
      Phase.work => '${c.workLabel}$roundText',
      Phase.rest => 'Pause – gleich ${c.workLabel} ${round + 1}',
      Phase.done => 'Fertig!',
    };
    final big = switch (phase) {
      Phase.ready => manual ? '${c.rounds}×' : fmt(c.work),
      Phase.work => manual ? 'Los' : fmt(remaining),
      Phase.rest => fmt(remaining),
      Phase.done => '✓',
    };

    final List<Widget> buttons = switch (phase) {
      Phase.ready => [
          FilledButton(onPressed: _startWork, child: const Text('Start')),
        ],
      Phase.work when manual => [
          FilledButton(
              onPressed: _afterWork,
              child: Text(round >= c.rounds ? 'Fertig' : '${c.workLabel} fertig')),
        ],
      Phase.work => [
          FilledButton(
              onPressed: _togglePause, child: Text(running ? 'Pause' : 'Weiter')),
        ],
      Phase.rest => [
          FilledButton(
              onPressed: _togglePause, child: Text(running ? 'Anhalten' : 'Weiter')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _skipRest, child: const Text('Pause überspringen')),
        ],
      Phase.done => [
          if (widget.next != null && widget.exercise.restAfter > 0) ...[
            FilledButton.icon(
                onPressed: () => Navigator.pop(context, TimerResult.rest),
                icon: const Icon(Icons.hourglass_bottom),
                label: Text('Abhaken + Pause ${fmt(widget.exercise.restAfter)}')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: () => Navigator.pop(context, TimerResult.done),
                child: const Text('Abhaken und zurück')),
          ] else
            FilledButton(
                onPressed: () => Navigator.pop(context, TimerResult.done),
                child: const Text('Abhaken und zurück')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _reset, child: const Text('Neu starten')),
        ],
    };

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        title: Text(widget.exercise.name),
        actions: [
          if (exerciseVideos.containsKey(widget.exercise.name))
            IconButton(
                icon: const Icon(Icons.smart_display_outlined),
                tooltip: 'Erklärvideo',
                onPressed: () => openVideo(context, widget.exercise.name)),
          IconButton(
              icon: const Icon(Icons.restart_alt), tooltip: 'Zurücksetzen', onPressed: _reset),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(widget.exercise.detail,
                  textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: fg)),
              if (anim != null) ...[
                const SizedBox(height: 8),
                Expanded(child: ExerciseAnimation(anim: anim)),
                Text(anim.cue,
                    textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: fg)),
                const SizedBox(height: 12),
              ] else
                const Spacer(),
              Text(status, style: tt.headlineSmall?.copyWith(color: fg)),
              const SizedBox(height: 8),
              FittedBox(
                child: Text(big,
                    style: tt.displayLarge?.copyWith(
                        color: fg,
                        fontSize: anim == null ? 120 : 88,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              if (c.rest > 0 && phase != Phase.done)
                Text('Pause: ${fmt(c.rest)}', style: tt.bodyLarge?.copyWith(color: fg)),
              if (anim == null) const Spacer() else const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buttons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wechselpause zwischen zwei Übungen
// ---------------------------------------------------------------------------

class _RestTile extends StatelessWidget {
  final int seconds;
  final VoidCallback onTap;
  const _RestTile({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.hourglass_bottom, size: 18, color: cs.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Pause ca. ${fmt(seconds)} bis zur nächsten Übung',
                    style: TextStyle(color: cs.tertiary)),
              ),
              Icon(Icons.play_arrow, size: 20, color: cs.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class RestScreen extends StatefulWidget {
  final int seconds;
  final Exercise next;
  const RestScreen({super.key, required this.seconds, required this.next});
  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  late int remaining = widget.seconds;
  bool running = true;
  Timer? ticker;

  bool get finished => remaining <= 0;

  @override
  void initState() {
    super.initState();
    keepScreenOn(true);
    _run();
  }

  @override
  void dispose() {
    ticker?.cancel();
    keepScreenOn(false);
    super.dispose();
  }

  void _run() {
    ticker?.cancel();
    running = true;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => remaining--);
    if (remaining > 0 && remaining <= 3) SystemSound.play(SystemSoundType.click);
    if (remaining <= 0) {
      ticker?.cancel();
      running = false;
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _togglePause() {
    if (running) {
      ticker?.cancel();
      setState(() => running = false);
    } else {
      _run();
      setState(() {});
    }
  }

  void _add30() {
    setState(() => remaining += 30);
    if (!running) _run();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final anim = exerciseAnims[widget.next.name];
    final bg = finished ? cs.primaryContainer : cs.tertiaryContainer;
    final fg = finished ? cs.onPrimaryContainer : cs.onTertiaryContainer;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        title: const Text('Pause'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Als Nächstes', style: tt.labelLarge?.copyWith(color: fg)),
              Text(widget.next.name,
                  textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(color: fg)),
              Text(widget.next.detail,
                  textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: fg)),
              if (anim != null) ...[
                const SizedBox(height: 8),
                Expanded(child: ExerciseAnimation(anim: anim)),
                Text(anim.cue,
                    textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: fg)),
                const SizedBox(height: 12),
              ] else
                const Spacer(),
              Text(finished ? 'Pause vorbei' : 'Durchatmen, Station vorbereiten',
                  style: tt.titleMedium?.copyWith(color: fg)),
              FittedBox(
                child: Text(finished ? 'Los' : fmt(remaining),
                    style: tt.displayLarge?.copyWith(
                        color: fg,
                        fontSize: anim == null ? 120 : 88,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              if (anim == null) const Spacer() else const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(widget.next.timer != null
                          ? 'Nächste Übung starten'
                          : 'Weiter zur nächsten Übung'),
                    ),
                    if (!finished) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                              onPressed: _togglePause,
                              child: Text(running ? 'Anhalten' : 'Weiter')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                              onPressed: _add30, child: const Text('+30 Sek.')),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
