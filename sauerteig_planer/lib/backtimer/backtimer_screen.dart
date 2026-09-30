import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../untils/feedback_service.dart';

// ═══════════════════════════════════════════════════════════════
//  BACKTIMER — Schritt-für-Schritt Backbegleiter
// ═══════════════════════════════════════════════════════════════

class BakingStep {
  final String emoji;
  final String name;
  final String hint;
  int plannedMinutes;
  bool enabled;
  bool useNativeTimer; // per-Schritt: Handy-Timer stellen?
  int repeatCount;     // Wiederholungen (≥ 1)

  DateTime? startedAt;
  DateTime? completedAt;
  String note;
  List<String> photoPaths;

  BakingStep({
    required this.emoji,
    required this.name,
    required this.hint,
    required this.plannedMinutes,
    this.enabled = true,
    this.useNativeTimer = true,
    this.repeatCount = 1,
    this.note = '',
    List<String>? photoPaths,
  }) : photoPaths = photoPaths ?? [];

  BakingStep clone({String? nameOverride}) => BakingStep(
        emoji: emoji,
        name: nameOverride ?? name,
        hint: hint,
        plannedMinutes: plannedMinutes,
        enabled: enabled,
        useNativeTimer: useNativeTimer,
        repeatCount: repeatCount,
        note: note,
        photoPaths: List.from(photoPaths),
      );

  int get elapsedSeconds =>
      startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;
  int get remainingSeconds =>
      (plannedMinutes * 60 - elapsedSeconds).clamp(0, 999999);
  bool get isOverdue => elapsedSeconds > plannedMinutes * 60;
  bool get isCompleted => completedAt != null;
}

List<BakingStep> _defaultSteps() => [
      BakingStep(
        emoji: '💧',
        name: 'Autolyse',
        hint: 'Mehl + Wasser mischen, 20–60 Min. quellen lassen. '
            'Verbessert Glutenstruktur ohne Kneten.',
        plannedMinutes: 30,
        enabled: false,
      ),
      BakingStep(
        emoji: '🧬',
        name: 'Starter einrühren',
        hint: 'Anstellgut (Starter) und Salz in den Teig einarbeiten. '
            'Gleichmäßig verteilen.',
        plannedMinutes: 10,
      ),
      BakingStep(
        emoji: '🤲',
        name: 'Dehnen & Falten',
        hint: 'Teig von einer Seite dehnen und zur Mitte falten, '
            'Schüssel drehen, wiederholen. Je Runde ca. 4 Züge.',
        plannedMinutes: 30,
        repeatCount: 4,
      ),
      BakingStep(
        emoji: '🫁',
        name: 'Stockgare',
        hint: 'Teig abgedeckt bei Raumtemperatur ruhen lassen bis er '
            'sich verdoppelt hat (4–8 h je nach Temperatur).',
        plannedMinutes: 240,
      ),
      BakingStep(
        emoji: '🫱',
        name: 'Vorformen',
        hint: 'Teig auf bemehlte Fläche geben, grob formen, '
            '15–30 Min. abgedeckt ruhen lassen.',
        plannedMinutes: 20,
      ),
      BakingStep(
        emoji: '❄️',
        name: 'Stückgare',
        hint: 'Fertig geformten Teigling in Gärkorb, abdecken. '
            '1–4 h bei RT oder über Nacht im Kühlschrank.',
        plannedMinutes: 120,
      ),
      BakingStep(
        emoji: '🔥',
        name: 'Ofen vorheizen',
        hint: 'Ofen mit Gusseisentopf auf 250°C vorheizen. '
            'Mindestens 45 Min. damit der Topf gleichmäßig heiß ist.',
        plannedMinutes: 45,
      ),
      BakingStep(
        emoji: '🍞',
        name: 'Backen',
        hint: 'Teigling in heißen Topf, Deckel drauf: 20 Min. bei 250°C. '
            'Deckel ab, 20–25 Min. bei 220°C bis zur gewünschten Kruste.',
        plannedMinutes: 45,
      ),
    ];

// ═══════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════

enum _TimerState { setup, running, done }

class BacktimerScreen extends StatefulWidget {
  const BacktimerScreen({super.key});

  @override
  State<BacktimerScreen> createState() => _BacktimerScreenState();
}

class _BacktimerScreenState extends State<BacktimerScreen> {
  _TimerState _state = _TimerState.setup;
  late List<BakingStep> _steps;
  List<BakingStep> _runningSteps = []; // expandierte Schritte (inkl. Wiederholungen)
  int _currentIndex = 0;
  String? _selectedStarter;
  bool _useNativeTimer = true; // Handy-Timer stellen
  Timer? _ticker;
  int _tickSeconds = 0;
  final _notifPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _steps = _defaultSteps();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifPlugin.initialize(const InitializationSettings(android: android));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Für Setup: aktive Schritte (noch nicht expandiert, für Anzeige)
  List<BakingStep> get _activeSteps => _steps.where((s) => s.enabled).toList();

  // Für den Timer: expandierte Schritte mit Wiederholungen
  List<BakingStep> _buildRunningSteps() {
    final result = <BakingStep>[];
    for (final step in _steps) {
      if (!step.enabled) continue;
      if (step.repeatCount <= 1) {
        result.add(step.clone());
      } else {
        for (var r = 1; r <= step.repeatCount; r++) {
          result.add(step.clone(
            nameOverride: '${step.name} ($r/${step.repeatCount})',
          ));
        }
      }
    }
    return result;
  }

  // ── Nativer Handy-Timer ──────────────────────────────────────
  Future<void> _launchNativeTimer(BakingStep step) async {
    if (!step.useNativeTimer || kIsWeb) return;
    final seconds = step.plannedMinutes * 60;
    final name = Uri.encodeComponent(step.name);
    final uri = Uri.parse(
      'intent://timer'
      '#Intent;'
      'action=android.intent.action.SET_TIMER;'
      'S.android.intent.extra.alarm.MESSAGE=$name;'
      'i.android.intent.extra.alarm.TIMER_LENGTH_SECONDS=$seconds;'
      'S.android.intent.extra.alarm.SKIP_UI=false;'
      'end',
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      FeedbackService.log('Handy-Timer Start fehlgeschlagen: $e');
    }
  }

  // ── Timer starten ────────────────────────────────────────────
  Future<void> _startTimer() async {
    final expanded = _buildRunningSteps();
    if (expanded.isEmpty) return;
    FeedbackService.log(
      'Backtimer gestartet: ${expanded.length} Schritte'
      '${_selectedStarter != null ? ", Starter: $_selectedStarter" : ""}',
    );
    expanded[0].startedAt = DateTime.now();
    setState(() {
      _runningSteps = expanded;
      _state = _TimerState.running;
      _currentIndex = 0;
    });
    await _launchNativeTimer(expanded[0]);
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() => _tickSeconds++); });
  }

  // ── Nächster Schritt ─────────────────────────────────────────
  Future<void> _nextStep() async {
    final active = _runningSteps;
    final current = active[_currentIndex];
    current.completedAt = DateTime.now();
    FeedbackService.log('Backtimer: "${current.name}" abgeschlossen');

    if (_currentIndex + 1 >= active.length) {
      _ticker?.cancel();
      setState(() => _state = _TimerState.done);
      FeedbackService.log('Backtimer: alle Schritte abgeschlossen');
      return;
    }

    final next = active[_currentIndex + 1];
    next.startedAt = DateTime.now();

    if (!kIsWeb) {
      await _notify(
        '✅ ${current.emoji} ${current.name} fertig!',
        'Nächster Schritt: ${next.emoji} ${next.name} (${_fmtMin(next.plannedMinutes)})',
      );
    }

    setState(() => _currentIndex++);
    await _launchNativeTimer(next);
  }

  Future<void> _notify(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'backtimer', 'Backtimer',
        channelDescription: 'Schritt-Benachrichtigungen beim Backen',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notifPlugin.show(300 + _currentIndex, title, body, details);
  }

  // ── Notiz ────────────────────────────────────────────────────
  Future<void> _addNote(BakingStep step) async {
    final ctrl = TextEditingController(text: step.note);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${step.emoji} Notiz',
            style: const TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Beobachtungen, Anpassungen …',
            hintStyle: const TextStyle(color: AppColors.text3),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => step.note = result);
  }

  // ── Foto ─────────────────────────────────────────────────────
  Future<void> _addPhoto(BakingStep step) async {
    if (kIsWeb) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Foto hinzufügen', style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt, color: AppColors.gold),
            label: const Text('Kamera', style: TextStyle(color: AppColors.text)),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library, color: AppColors.gold),
            label: const Text('Galerie', style: TextStyle(color: AppColors.text)),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => step.photoPaths.add(picked.path));
  }

  // ── ICS Export ───────────────────────────────────────────────
  Future<void> _exportICS() async {
    final active = _runningSteps.where((s) => s.startedAt != null).toList();
    if (active.isEmpty) return;
    final selected = await _showICSSelection(active);
    if (selected == null || selected.isEmpty) return;

    FeedbackService.log('Backtimer ICS-Export: ${selected.length} Schritte');

    String icsDate(DateTime d) => d.toUtc().toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .replaceAll(RegExp(r'\.\d{3}'), '');

    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    final ics = StringBuffer('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Sauerteig Planer//DE\r\n');

    for (var i = 0; i < selected.length; i++) {
      final step = selected[i];
      final start = step.startedAt ?? DateTime.now();
      final end = start.add(Duration(minutes: step.plannedMinutes));
      ics.write(
        'BEGIN:VEVENT\r\n'
        'UID:backtimer-$uid-$i@sauerteig-planer\r\n'
        'DTSTART:${icsDate(start)}\r\n'
        'DTEND:${icsDate(end)}\r\n'
        'SUMMARY:${step.emoji} ${step.name}\r\n'
        'DESCRIPTION:${step.hint.replaceAll('\n', '\\n')}\r\n'
        'END:VEVENT\r\n',
      );
    }
    ics.write('END:VCALENDAR\r\n');

    if (!kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Backtimer.ics');
        await file.writeAsString(ics.toString());
        await OpenFilex.open(file.path, type: 'text/calendar');
      } catch (e) {
        FeedbackService.log('Backtimer ICS Fehler: $e');
      }
    }
  }

  Future<List<BakingStep>?> _showICSSelection(List<BakingStep> steps) async {
    final selected = List<bool>.filled(steps.length, true);
    return showDialog<List<BakingStep>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('📅 Kalender-Export', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welche Schritte exportieren?',
                style: TextStyle(color: AppColors.text2, fontSize: 13)),
            const SizedBox(height: 8),
            ...List.generate(steps.length, (i) => CheckboxListTile(
                  value: selected[i],
                  onChanged: (v) => setLocal(() => selected[i] = v ?? false),
                  activeColor: AppColors.green,
                  title: Text('${steps[i].emoji} ${steps[i].name}',
                      style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            onPressed: () => Navigator.pop(ctx, [
              for (var i = 0; i < steps.length; i++) if (selected[i]) steps[i]
            ]),
            child: const Text('Exportieren'),
          ),
        ],
      )),
    );
  }

  // ── Zurücksetzen ─────────────────────────────────────────────
  void _reset() {
    _ticker?.cancel();
    setState(() {
      _steps = _defaultSteps();
      _runningSteps = [];
      _currentIndex = 0;
      _selectedStarter = null;
      _tickSeconds = 0;
      _state = _TimerState.setup;
    });
  }

  // ── AppBar ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('⏱️ Backtimer',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          if (_state == _TimerState.running || _state == _TimerState.done)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: AppColors.text2),
              tooltip: 'Neu starten',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Timer zurücksetzen?',
                        style: TextStyle(color: AppColors.text)),
                    content: const Text('Alle Fortschritte gehen verloren.',
                        style: TextStyle(color: AppColors.text2)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Abbrechen',
                              style: TextStyle(color: AppColors.text2))),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('Zurücksetzen',
                              style: TextStyle(color: AppColors.red))),
                    ],
                  ),
                );
                if (ok == true) _reset();
              },
            ),
          if (_state == _TimerState.done)
            IconButton(
              icon: const Icon(Icons.calendar_today, color: AppColors.text2),
              tooltip: 'Als .ics exportieren',
              onPressed: _exportICS,
            ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: AppColors.text2),
            tooltip: 'Fehler melden',
            onPressed: () => FeedbackService.showReportDialog(context),
          ),
        ],
      ),
      body: switch (_state) {
        _TimerState.setup => _buildSetup(),
        _TimerState.running => _buildRunning(),
        _TimerState.done => _buildDone(),
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SETUP
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSetup() {
    final active = _activeSteps;
    final totalMin = active.fold(0, (s, e) => s + e.plannedMinutes);

    return Column(
      children: [
        // ── Optionen-Banner ──────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              // Starter
              Row(children: [
                const Text('🌱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    onChanged: (v) =>
                        _selectedStarter = v.trim().isEmpty ? null : v.trim(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Starter-Name (optional)',
                      hintStyle: TextStyle(color: AppColors.text3, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ]),
              const Divider(color: AppColors.border, height: 16),
              // Handy-Timer Toggle
              Row(children: [
                const Text('📱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Handy-Timer stellen',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text('Öffnet automatisch die Uhr-App beim Start',
                          style:
                              TextStyle(color: AppColors.text3, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: _useNativeTimer,
                  onChanged: (v) => setState(() {
                    _useNativeTimer = v;
                    for (final s in _steps) { s.useNativeTimer = v; }
                  }),
                  activeThumbColor: AppColors.green,
                ),
              ]),
            ],
          ),
        ),

        // ── Schritt-Liste ────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            itemCount: _steps.length,
            itemBuilder: (_, i) => _StepSetupCard(
              step: _steps[i],
              onToggle: (v) => setState(() => _steps[i].enabled = v),
              onDurationChanged: (min) =>
                  setState(() => _steps[i].plannedMinutes = min),
              onNativeTimerToggle: (v) =>
                  setState(() => _steps[i].useNativeTimer = v),
              onRepeatChanged: (n) =>
                  setState(() => _steps[i].repeatCount = n),
            ),
          ),
        ),

        // ── Start-Button ─────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: active.isEmpty ? null : _startTimer,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                active.isEmpty
                    ? 'Mindestens einen Schritt wählen'
                    : 'Starten — ${_buildRunningSteps().length} Schritte · ${_fmtMin(totalMin)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.text3,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LAUFEND
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRunning() {
    final active = _runningSteps;
    final step = active[_currentIndex];
    final remaining = step.remainingSeconds;
    final total = step.plannedMinutes * 60;
    final progress = ((total - remaining) / total).clamp(0.0, 1.0);
    final overdue = step.isOverdue;

    return Column(
      children: [
        // ── Gesamt-Fortschritt + Schritt-Dots ───────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              Row(children: [
                Text(
                  'Schritt ${_currentIndex + 1} von ${active.length}',
                  style: const TextStyle(color: AppColors.text3, fontSize: 12),
                ),
                const Spacer(),
                if (_selectedStarter != null)
                  Text('🌱 $_selectedStarter',
                      style: const TextStyle(
                          color: AppColors.green, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              // Step-Dots
              Row(
                children: List.generate(active.length, (i) {
                  final done = i < _currentIndex;
                  final current = i == _currentIndex;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.green
                            : current
                                ? (overdue ? AppColors.orange : AppColors.gold)
                                : AppColors.surface2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Schritt-Info ─────────────────────────────
                Text(step.emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  step.name,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  step.hint,
                  style: const TextStyle(
                      color: AppColors.text2, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // ── Countdown-Box ─────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: overdue
                          ? AppColors.orange.withValues(alpha: 0.6)
                          : AppColors.green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(children: [
                    Text(
                      _fmtCountdown(remaining),
                      style: TextStyle(
                        color: overdue ? AppColors.orange : AppColors.green,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overdue
                          ? '⚠️ ${_fmtMin(step.elapsedSeconds ~/ 60)} überzogen'
                          : 'von ${_fmtMin(step.plannedMinutes)}',
                      style: TextStyle(
                          color: overdue ? AppColors.orange : AppColors.text3,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.surface2,
                        color:
                            overdue ? AppColors.orange : AppColors.green,
                        minHeight: 5,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Notiz + Foto ──────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addNote(step),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text(step.note.isEmpty ? 'Notiz' : 'Notiz ✓'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: step.note.isEmpty
                            ? AppColors.text2
                            : AppColors.green,
                        side: BorderSide(
                            color: step.note.isEmpty
                                ? AppColors.border
                                : AppColors.green),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPhoto(step),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: Text(step.photoPaths.isEmpty
                            ? 'Foto'
                            : '${step.photoPaths.length} Foto(s)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: step.photoPaths.isEmpty
                              ? AppColors.text2
                              : AppColors.green,
                          side: BorderSide(
                              color: step.photoPaths.isEmpty
                                  ? AppColors.border
                                  : AppColors.green),
                        ),
                      ),
                    ),
                  ],
                ]),

                // Fotos
                if (!kIsWeb && step.photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: step.photoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(step.photoPaths[i]),
                            width: 80, height: 80, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],

                // Notiz-Anzeige
                if (step.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('📝 ${step.note}',
                        style: const TextStyle(
                            color: AppColors.text2, fontSize: 12)),
                  ),
                ],

                // ── Handy-Timer manuell stellen ───────────────
                if (!kIsWeb) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchNativeTimer(step),
                      icon: const Icon(Icons.phone_android, size: 16),
                      label: const Text('📱 Handy-Timer für diesen Schritt stellen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text2,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],

                // ── Vorschau nächster Schritt ─────────────────
                if (_currentIndex + 1 < active.length) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      Text(active[_currentIndex + 1].emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Danach',
                                style: TextStyle(
                                    color: AppColors.text3, fontSize: 10)),
                            Text(active[_currentIndex + 1].name,
                                style: const TextStyle(
                                    color: AppColors.text2, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text(
                          _fmtMin(active[_currentIndex + 1].plannedMinutes),
                          style: const TextStyle(
                              color: AppColors.text3, fontSize: 12)),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Weiter-Button ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: Icon(
                      _currentIndex + 1 >= active.length
                          ? Icons.check_circle_rounded
                          : Icons.skip_next_rounded,
                      size: 22,
                    ),
                    label: Text(
                      _currentIndex + 1 >= active.length
                          ? '🎉 Fertig!'
                          : 'Weiter: ${active[_currentIndex + 1].emoji} ${active[_currentIndex + 1].name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: overdue
                          ? AppColors.orange
                          : AppColors.green,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FERTIG
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDone() {
    final active = _runningSteps;
    final start = active.first.startedAt;
    final end = active.last.completedAt;
    final totalMin = start != null && end != null
        ? end.difference(start).inMinutes
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('🎉', style: TextStyle(fontSize: 60))),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Fertig gebacken!',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Gesamtzeit: ${_fmtMin(totalMin)}'
              '${_selectedStarter != null ? " · 🌱 $_selectedStarter" : ""}',
              style: const TextStyle(color: AppColors.text2, fontSize: 13),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'PROTOKOLL',
            style: TextStyle(
                color: AppColors.text3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          ...active.map((step) => _StepSummaryCard(
                step: step,
                onAddNote: () => _addNote(step),
                onAddPhoto: () => _addPhoto(step),
              )),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportICS,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Als Kalender (.ics) exportieren'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt, size: 20),
              label: const Text('Neues Backen starten',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Formatierung ─────────────────────────────────────────────
  String _fmtCountdown(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

String _fmtMin(int minutes) {
  if (minutes < 60) return '$minutes Min.';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}

// ═══════════════════════════════════════════════════════════════
//  Setup-Karte — alles inline, kein Aufklappen
// ═══════════════════════════════════════════════════════════════
class _StepSetupCard extends StatelessWidget {
  final BakingStep step;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onNativeTimerToggle;
  final ValueChanged<int> onRepeatChanged;

  const _StepSetupCard({
    required this.step,
    required this.onToggle,
    required this.onDurationChanged,
    required this.onNativeTimerToggle,
    required this.onRepeatChanged,
  });

  // Schrittgröße je nach aktuellem Wert
  int get _step => step.plannedMinutes < 60 ? 5 : 15;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Verfügbare Breite bestimmt Abstände + Schriftgröße
        final w = constraints.maxWidth;
        final compact = w < 300;
        final gap   = compact ? 4.0  : 6.0;
        final gap2  = compact ? 6.0  : 8.0;
        final indent = compact ? 24.0 : 32.0;
        final fontSize = compact ? 12.0 : 13.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: step.enabled ? AppColors.surface : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: step.enabled
                  ? AppColors.green.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                // ── Zeile 1: Aktivieren + Name ──────────────────
                Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(!step.enabled),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: step.enabled
                            ? AppColors.green.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: step.enabled ? AppColors.green : AppColors.text3,
                          width: 1.5,
                        ),
                      ),
                      child: step.enabled
                          ? const Icon(Icons.check, size: 14, color: AppColors.green)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(step.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.name,
                      style: TextStyle(
                        color: step.enabled ? AppColors.text : AppColors.text3,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ]),

                if (step.enabled) ...[
                  const SizedBox(height: 8),
                  // ── Zeile 2: Dauer ────────────────────────────
                  Row(children: [
                    SizedBox(width: indent),
                    _DurationButton(
                      icon: Icons.remove,
                      onTap: step.plannedMinutes > 5
                          ? () => onDurationChanged(
                              (step.plannedMinutes - _step).clamp(5, 480))
                          : null,
                    ),
                    SizedBox(width: gap),
                    GestureDetector(
                      onTap: () => _showDurationPicker(context),
                      child: Text(
                        _fmtMin(step.plannedMinutes),
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    _DurationButton(
                      icon: Icons.add,
                      onTap: step.plannedMinutes < 480
                          ? () => onDurationChanged(
                              (step.plannedMinutes + _step).clamp(5, 480))
                          : null,
                    ),
                  ]),

                  // ── Zeile 3: Wiederholungen + Handy-Timer ────
                  SizedBox(height: gap),
                  Row(children: [
                    SizedBox(width: indent),
                    const Icon(Icons.repeat, size: 15, color: AppColors.text3),
                    SizedBox(width: gap),
                    _DurationButton(
                      icon: Icons.remove,
                      onTap: step.repeatCount > 1
                          ? () => onRepeatChanged(step.repeatCount - 1)
                          : null,
                    ),
                    SizedBox(width: gap2),
                    Text(
                      '×${step.repeatCount}',
                      style: TextStyle(
                        color: step.repeatCount > 1 ? AppColors.blue : AppColors.text3,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                      ),
                    ),
                    SizedBox(width: gap2),
                    _DurationButton(
                      icon: Icons.add,
                      onTap: step.repeatCount < 8
                          ? () => onRepeatChanged(step.repeatCount + 1)
                          : null,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onNativeTimerToggle(!step.useNativeTimer),
                      child: Icon(
                        step.useNativeTimer
                            ? Icons.phone_android
                            : Icons.phone_android_outlined,
                        size: 18,
                        color: step.useNativeTimer ? AppColors.green : AppColors.text3,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDurationPicker(BuildContext context) async {
    final presets = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300, 480];
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${step.emoji} ${step.name} — Dauer wählen',
                style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((min) {
                final active = min == step.plannedMinutes;
                return GestureDetector(
                  onTap: () {
                    onDurationChanged(min);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.gold.withValues(alpha: 0.2)
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? AppColors.gold
                              : AppColors.border),
                    ),
                    child: Text(
                      _fmtMin(min),
                      style: TextStyle(
                        color: active ? AppColors.gold : AppColors.text2,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dauer-Button ─────────────────────────────────────────────────
class _DurationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _DurationButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: onTap != null
                ? AppColors.surface2
                : AppColors.bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? AppColors.text2 : AppColors.text3,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  Zusammenfassungs-Karte
// ═══════════════════════════════════════════════════════════════
class _StepSummaryCard extends StatelessWidget {
  final BakingStep step;
  final VoidCallback onAddNote;
  final VoidCallback onAddPhoto;

  const _StepSummaryCard({
    required this.step,
    required this.onAddNote,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final start = step.startedAt;
    final end = step.completedAt;
    final actualMin = (start != null && end != null)
        ? end.difference(start).inMinutes
        : step.plannedMinutes;
    final late = actualMin > step.plannedMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(step.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(step.name,
                style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Text(
            late
                ? '${_fmtMin(actualMin)} (${_fmtMin(step.plannedMinutes)} geplant)'
                : _fmtMin(actualMin),
            style: TextStyle(
              color: late ? AppColors.orange : AppColors.green,
              fontSize: 11,
            ),
          ),
        ]),
        if (step.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('📝 ${step.note}',
              style: const TextStyle(
                  color: AppColors.text2, fontSize: 12, height: 1.4)),
        ],
        if (!kIsWeb && step.photoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: step.photoPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(step.photoPaths[i]),
                    width: 70, height: 70, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(
            onTap: onAddNote,
            child: Text(
              step.note.isEmpty ? '+ Notiz' : '✏️ Notiz bearbeiten',
              style: const TextStyle(color: AppColors.text3, fontSize: 11),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onAddPhoto,
              child: const Text('+ Foto',
                  style: TextStyle(color: AppColors.text3, fontSize: 11)),
            ),
          ],
        ]),
      ]),
    );
  }
}
