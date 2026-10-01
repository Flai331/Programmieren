import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'animations.dart';
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
int todayIndex() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day).difference(planStart).inDays;
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
  Future<void> setDone(int d, bool v) => p.setBool('done_$d', v);
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
    final ti = todayIndex();
    final trainingDays = [for (var d = 0; d < planDays; d++) if (!sessionFor(d).isRest) d];
    final doneCount = trainingDays.where(widget.store.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laufplan'),
        actions: [
          IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Regeln',
              onPressed: _showRules),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TodayCard(ti: ti, onOpen: _open, done: ti >= 0 && ti < planDays && widget.store.done(ti)),
          const SizedBox(height: 12),
          Text('$doneCount von ${trainingDays.length} Einheiten erledigt',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: doneCount / trainingDays.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          for (var w = 0; w < 4; w++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text('Woche ${w + 1}: ${weekFocus[w]}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (var d = w * 7; d < w * 7 + 7; d++)
              _DayTile(
                day: d,
                isToday: d == ti,
                done: widget.store.done(d),
                onTap: () => _open(d),
                cs: cs,
              ),
          ],
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int ti;
  final bool done;
  final void Function(int) onOpen;
  const _TodayCard({required this.ti, required this.onOpen, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (ti < 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Der Plan startet am ${dateLabel(planStart)}', style: tt.titleMedium),
        ),
      );
    }
    if (ti >= planDays) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Plan abgeschlossen. Zeit für die nächsten 4 Wochen!',
              style: tt.titleMedium),
        ),
      );
    }
    final s = sessionFor(ti);
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heute', style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(s.icon, color: cs.onPrimaryContainer, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.title,
                    style: tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(done ? 'Erledigt ✓' : 'ca. ${s.minutes} Min.',
                style: tt.bodyLarge?.copyWith(color: cs.onPrimaryContainer)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => onOpen(ti), child: const Text('Training öffnen')),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final int day;
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
    final s = sessionFor(day);
    final d = dateOf(day);
    return Card(
      elevation: 0,
      color: isToday ? cs.secondaryContainer : cs.surfaceContainerHighest.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: onTap,
        leading: Icon(s.icon, color: s.isRest ? cs.outline : cs.primary),
        title: Text(s.title),
        subtitle: Text(s.isRest ? dateLabel(d) : '${dateLabel(d)}  ca. ${s.minutes} Min.'),
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
    await widget.store.setDone(widget.day, v);
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
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text(dateLabel(dateOf(widget.day)), style: tt.bodyMedium),
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
