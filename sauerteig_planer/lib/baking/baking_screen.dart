import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'baking_models.dart';
import '../app_colors.dart';
import '../untils/feedback_service.dart';


// android_intent_plus wird nur auf Android verwendet
import 'package:android_intent_plus/android_intent.dart'
    if (dart.library.html) 'package:sauerteig_planer/baking/stub_intent.dart';

// ═══════════════════════════════════════════════════════════════
//  AKTIVER BACKMODUS
// ═══════════════════════════════════════════════════════════════

final _notifications = FlutterLocalNotificationsPlugin();

class BakingScreen extends StatefulWidget {
  final BakingRecipe recipe;
  const BakingScreen({super.key, required this.recipe});

  @override
  State<BakingScreen> createState() => _BakingScreenState();
}

class _BakingScreenState extends State<BakingScreen> with WidgetsBindingObserver {
  late List<BakingStep> _steps;
  Timer? _ticker;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    _steps = widget.recipe.freshSteps();
    _initNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Wird aufgerufen wenn die App aus dem Hintergrund zurückkommt.
  /// Korrigiert den Countdown anhand der echten Wanduhrzeit und
  /// löst _onTimerDone aus wenn der Timer inzwischen abgelaufen ist.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncTimerOnResume();
  }

  void _syncTimerOnResume() {
    if (_activeIndex < 0) return;
    final step = _steps[_activeIndex];
    if (step.startedAt == null || step.status != StepStatus.active) return;
    final elapsed = DateTime.now().difference(step.startedAt!);
    final remaining = step.duration - elapsed;
    if (remaining.inSeconds <= 0) {
      _ticker?.cancel();
      setState(() => _steps[_activeIndex].remaining = Duration.zero);
      _onTimerDone(_activeIndex);
    } else {
      setState(() => _steps[_activeIndex].remaining = remaining);
    }
  }

  Future<void> _initNotifications() async {
    if (!kIsWeb) {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      // Android 13+ (API 33): POST_NOTIFICATIONS ist Runtime-Permission —
      // ohne explizite Anfrage werden Benachrichtigungen still blockiert.
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  int get _completedCount =>
      _steps.where((s) => s.status == StepStatus.completed || s.status == StepStatus.skipped).length;

  bool get _hasActiveTimer => _activeIndex >= 0 && _steps[_activeIndex].status == StepStatus.active;

  // ── Abbruch-Bestätigung ───────────────────────────────────
  Future<void> _confirmExit() async {
    final hasProgress = _completedCount > 0 || _hasActiveTimer;
    if (!hasProgress) {
      Navigator.pop(context);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Backmodus beenden?',
            style: TextStyle(color: AppColors.gold)),
        content: const Text(
          'Der aktuelle Fortschritt geht verloren.',
          style: TextStyle(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weitermachen',
                style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if ((exit ?? false) && mounted) Navigator.pop(context);
  }

  void _startStep(int index) async {
    final step = _steps[index];

    FeedbackService.log('Backschritt gestartet: ${step.name} (${step.duration.inMinutes} min)');
    _ticker?.cancel();


    // Nativen Handy-Timer öffnen (optional, nur Android)
    // Bei Fehler: Fallback auf App-Timer
    bool nativeTimerLaunched = false;
    if (!kIsWeb && step.useNativeTimer) {
      final messenger = ScaffoldMessenger.of(context); // vor await sichern
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.SET_TIMER',
          arguments: {
            'android.intent.extra.alarm.LENGTH': step.duration.inSeconds,
            'android.intent.extra.alarm.MESSAGE': '${step.emoji} ${step.name}',
            'android.intent.extra.alarm.SKIP_UI': false,
          },
        );
        await intent.launch();
        nativeTimerLaunched = true;
      } catch (e, stack) {
        FeedbackService.log('SET_TIMER Intent fehlgeschlagen: $e\n$stack');
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Nativer Timer nicht verfügbar – App-Timer läuft stattdessen.'),
            backgroundColor: Color(0xFF2A1E08),
            duration: Duration(seconds: 4),
          ));
        }
      }
    }

    setState(() {
      _steps[index].status = StepStatus.active;
      _steps[index].remaining = _steps[index].duration;
      _steps[index].startedAt = DateTime.now();
      _steps[index].useNativeTimer = nativeTimerLaunched; // false → zeigt Countdown
      _activeIndex = index;
    });

    // App-Timer starten wenn kein nativer Timer erfolgreich gestartet wurde.
    // Wanduhr-basiert: remaining = duration - (now - startedAt)
    // → korrekt auch nach App-Pause / Display-aus, da keine Ticks gezählt werden.
    if (!nativeTimerLaunched) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final startedAt = _steps[index].startedAt;
        if (startedAt == null) return;
        final elapsed = DateTime.now().difference(startedAt);
        final remaining = _steps[index].duration - elapsed;
        setState(() {
          if (remaining.inSeconds <= 0) {
            _steps[index].remaining = Duration.zero;
            _ticker?.cancel();
            _onTimerDone(index);
          } else {
            _steps[index].remaining = remaining;
          }
        });
      });
    }
  }

  void _onTimerDone(int index) {
    final step = _steps[index];
    final nextName = index + 1 < _steps.length ? _steps[index + 1].name : null;
    FeedbackService.log('Backschritt abgeschlossen: ${step.name} → ${nextName != null ? 'weiter mit $nextName' : 'alle Schritte fertig'}');

    // Benachrichtigung
    if (!kIsWeb) {
      _notifications.show(
        100 + index,
        '${step.emoji} ${step.name} fertig!',
        nextName != null ? 'Nächster Schritt: $nextName' : 'Alle Schritte abgeschlossen! 🎉',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sauerteig_baking', 'Backmodus',
            channelDescription: 'Timer für Backschritte',
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    }

    // Dialog — nicht wegtippbar (barrierDismissible: false)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${step.emoji} ${step.name} fertig!',
            style: const TextStyle(color: AppColors.gold)),
        content: Text(
          nextName != null
              ? 'Nächster Schritt: $nextName'
              : '🎉 Alle Schritte abgeschlossen!',
          style: const TextStyle(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeStep(index);
            },
            child: const Text('Weiter', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  void _completeStep(int index) {
    setState(() {
      _steps[index].status = StepStatus.completed;
      _activeIndex = -1;
    });
  }

  void _skipStep(int index) {
    _ticker?.cancel();
    setState(() {
      _steps[index].status = StepStatus.skipped;
      if (_activeIndex == index) _activeIndex = -1;
    });
  }

  void _undoStep(int index) {
    setState(() {
      _steps[index].status = StepStatus.pending;
      _steps[index].remaining = _steps[index].duration;
      if (_activeIndex == index) _activeIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _steps.isEmpty ? 0.0 : _completedCount / _steps.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _confirmExit,
        ),
        title: Text(widget.recipe.name,
            style: const TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            color: AppColors.gold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Fortschritt-Text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_completedCount / ${_steps.length} Schritte erledigt',
                  style: const TextStyle(color: AppColors.text2, fontSize: 13),
                ),
                if (_completedCount == _steps.length && _steps.isNotEmpty)
                  const Text('🎉 Fertig!',
                      style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Schritte
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _steps.length,
              itemBuilder: (_, i) => _BakingStepCard(
                step: _steps[i],
                index: i,
                isBlockedByActive: _activeIndex >= 0 && _activeIndex != i,
                onStart: () => _startStep(i),
                onComplete: () => _completeStep(i),
                onSkip: () => _skipStep(i),
                onUndo: () => _undoStep(i),
                onNativeTimerToggle: (val) {
                  setState(() => _steps[i].useNativeTimer = val);
                },
              ),
            ),
          ),
        ],
      ),
      ), // PopScope
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SCHRITT-KACHEL
// ═══════════════════════════════════════════════════════════════

class _BakingStepCard extends StatelessWidget {
  final BakingStep step;
  final int index;
  final bool isBlockedByActive;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onUndo;
  final ValueChanged<bool> onNativeTimerToggle;

  const _BakingStepCard({
    required this.step,
    required this.index,
    required this.isBlockedByActive,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
    required this.onUndo,
    required this.onNativeTimerToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = step.status == StepStatus.active;
    final isDone = step.status == StepStatus.completed;
    final isSkipped = step.status == StepStatus.skipped;

    Color borderColor = AppColors.border;
    Color bgColor = AppColors.surface;
    if (isActive) borderColor = AppColors.gold;
    if (isDone) borderColor = AppColors.green;
    if (isSkipped) bgColor = const Color(0xFF141210);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isDone
                        ? AppColors.green
                        : isActive
                            ? AppColors.gold
                            : AppColors.text3,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(step.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.name,
                    style: TextStyle(
                      color: isSkipped
                          ? AppColors.text3
                          : AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isSkipped ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isDone)
                  const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                if (isSkipped)
                  const Icon(Icons.skip_next, color: AppColors.text3, size: 20),
              ],
            ),

            // Beschreibung
            if (step.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(step.description,
                  style: const TextStyle(color: AppColors.text2, fontSize: 13)),
            ],

            // Countdown (aktiv ohne nativen Timer)
            if (isActive && !step.useNativeTimer) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  formatCountdown(step.remaining),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],

            // Aktiver nativer Timer — kein Countdown, nur Info
            if (isActive && step.useNativeTimer) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '⏱ Handy-Timer läuft (${formatDuration(step.duration)})',
                  style: const TextStyle(color: AppColors.gold, fontSize: 14),
                ),
              ),
            ],

            // Dauer (pending)
            if (step.status == StepStatus.pending) ...[
              const SizedBox(height: 6),
              Text(
                formatDuration(step.duration),
                style: const TextStyle(color: AppColors.text3, fontSize: 12),
              ),
            ],

            // Nativer Timer Checkbox (pending + aktiv ohne native)
            if (!kIsWeb && (step.status == StepStatus.pending || (isActive && !step.useNativeTimer))) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: step.useNativeTimer,
                      onChanged: step.status == StepStatus.pending
                          ? (v) => onNativeTimerToggle(v ?? false)
                          : null,
                      activeColor: AppColors.gold,
                      checkColor: AppColors.bg,
                      side: const BorderSide(color: AppColors.text3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Nativen Handy-Timer verwenden',
                    style: TextStyle(color: AppColors.text2, fontSize: 12),
                  ),
                ],
              ),
            ],

            // Buttons
            const SizedBox(height: 12),
            if (step.status == StepStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBlockedByActive ? null : onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor: AppColors.border,
                      ),
                      child: const Text('Starten'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isBlockedByActive ? null : onSkip,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.text3),
                      foregroundColor: AppColors.text3,
                    ),
                    child: const Text('Überspringen'),
                  ),
                ],
              ),
            if (isActive)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.bg,
                      ),
                      child: const Text('Fertig ✓'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.text3),
                      foregroundColor: AppColors.text3,
                    ),
                    child: const Text('Überspringen'),
                  ),
                ],
              ),
            if (isDone || isSkipped)
              TextButton(
                onPressed: onUndo,
                child: const Text('↩ Rückgängig',
                    style: TextStyle(color: AppColors.text3, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
