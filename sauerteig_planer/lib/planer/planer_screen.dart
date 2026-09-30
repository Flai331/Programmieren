// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Haupt-Screen
//  lib/planer/planer_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import '../untils/discard_recipes.dart';
import 'planer_calculations.dart';
import 'planer_storage.dart';
import '../starter/my_starter_models.dart';
import '../starter/my_starter_storage.dart';


// ── Benachrichtigungen global ──────────────────────────────────
final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

// ── Toleranz für „Vergangenheit"-Prüfung ──────────────────────
const _pastTolerance = Duration(minutes: 15);

// ── Helper: Prüft ob Auffrischungsplan nicht möglich ist ──────
/// Prüft, ob ein Auffrischungsplan in der Vergangenheit liegt
/// (d.h. nicht realisierbar ist). Wird im Widget UND in _scheduleNotifications verwendet.
bool _isRefreshPlanPast(_RefreshPlan plan, DateTime? earliestStart) {
  if (plan.refreshes.isEmpty) return false;
  final first = plan.refreshes.first;
  final now = DateTime.now();
  final refPoint = earliestStart ?? now;
  return first.time.isBefore(refPoint.subtract(_pastTolerance));
}

// ═══════════════════════════════════════════════════════════════
//  HAUPT-SCREEN
// ═══════════════════════════════════════════════════════════════
class PlanerScreen extends StatefulWidget {
  const PlanerScreen({super.key});

  @override
  State<PlanerScreen> createState() => _PlanerScreenState();
}

class _PlanerScreenState extends State<PlanerScreen> {
  // Eingabewerte
  double _temp = 22;
  double _amount = 100;
  double _starter = 20;
  late DateTime _bakingTime;
  DateTime? _earliestStart; // optional: frühestmöglicher Beginn (1. Auffrischung)
  int _refreshCount = 0; // 0 = keine, 1–3 = Auffrischungen
  Map<int, DateTime> _customRefreshTimes = {}; // Schritt-Index → custom Zeit

  PlanerResult? _result;
  List<SavedPlan> _savedPlans = [];
  List<MyStarter> _myStarters = [];
  MyStarter? _selectedStarter;

  @override
  void initState() {
    super.initState();
    // Standard: in 8 Stunden backen
    _bakingTime = DateTime.now().add(const Duration(hours: 8));
    _initNotifications();
    _loadSavedPlans();
    _loadMyStarters();
  }

  Future<void> _loadSavedPlans() async {
    final plans = await PlanerStorage.loadAll();
    if (mounted) setState(() => _savedPlans = plans);
  }

  Future<void> _loadMyStarters() async {
    final starters = await MyStarterStorage.loadAll();
    if (mounted) setState(() => _myStarters = starters);
  }

  Future<void> _markStarterUsed() async {
    final r = _result;
    final s = _selectedStarter;
    if (r == null || s == null) return;

    final newAmount = (s.gramAmount - r.anstellgut).clamp(0, 99999);
    final updated = s.copyWith(gramAmount: newAmount);
    await MyStarterStorage.save(updated);
    setState(() {
      _selectedStarter = updated;
      final idx = _myStarters.indexWhere((x) => x.id == s.id);
      if (idx != -1) _myStarters[idx] = updated;
    });

    FeedbackService.log('MyStarter "${s.name}": ${r.anstellgut}g verwendet → noch ${newAmount}g');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '✅ ${r.anstellgut}g von „${s.name}" abgezogen → noch ${newAmount}g im Kühlschrank',
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _savePlan() async {
    final r = _result;
    if (r == null) return;
    final plan = SavedPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      savedAt: DateTime.now(),
      temp: _temp,
      bakingTime: _bakingTime,
      ratio: r.ratio,
      anstellgut: r.anstellgut,
      wasser: r.wasser,
      mehl: r.mehl,
      gesamt: r.gesamt,
      forRecipe: r.forRecipe,
      leftover: r.leftover,
      unusedStarter: r.unusedStarter,
      estTime: r.estTime,
      wasserTempC: r.wasserTempC,
      dFeed: r.dFeed,
      dHalf: r.dHalf,
      dPeak: r.dPeak,
    );
    await PlanerStorage.save(plan);
    await _loadSavedPlans();
    if (!mounted) return;
    FeedbackService.log('Planer: Zeitplan gespeichert (${r.ratio}, ${r.temp.toInt()}°C)');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Zeitplan gespeichert'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSavedPlans() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SavedPlansSheet(
        plans: _savedPlans,
        onDelete: (id) async {
          await PlanerStorage.delete(id);
          await _loadSavedPlans();
        },
        onLoad: (plan) {
          Navigator.pop(context);
          setState(() {
            _temp = plan.temp;
            _bakingTime = plan.bakingTime;
            final f = plan.anstellgut > 0 ? plan.mehl / plan.anstellgut : 2.0;
            _result = PlanerResult(
              temp: plan.temp,
              tempLabel: plan.temp < 20 ? 'Kühl' : plan.temp > 26 ? 'Warm' : 'Optimal',
              tempAdvice: '',
              ratio: plan.ratio,
              factor: f,
              fExact: f,
              timeDiff: 0.0,
              anstellgut: plan.anstellgut,
              wasser: plan.wasser,
              mehl: plan.mehl,
              gesamt: plan.gesamt,
              forRecipe: plan.forRecipe,
              leftover: plan.leftover,
              unusedStarter: plan.unusedStarter,
              estTime: plan.estTime,
              wasserTempC: plan.wasserTempC,
              dFeed: plan.dFeed,
              dHalf: plan.dHalf,
              dPeak: plan.dPeak,
              steps: const [],
            );
          });
          FeedbackService.log('Planer: Gespeicherten Zeitplan geladen (${plan.ratio}, ${plan.temp.toInt()}°C)');
        },
      ),
    );
  }

  double get _hours {
    final diff = _bakingTime.difference(DateTime.now()).inMinutes / 60.0;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _pickBakingTime() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _BakingTimeDialog(initial: _bakingTime),
    );
    if (result == null || !mounted) return;
    setState(() {
      _bakingTime = result;
      _customRefreshTimes.clear();
    });

    // Nach Änderung die Erinnerungen neu planen
    if (_result != null) {
      _scheduleNotifications(_result!);
    }
  }

  String _formatBakingTime() {
    final now = DateTime.now();
    final diff = _bakingTime.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final dayLabel = _bakingTime.day == now.day
        ? 'Heute'
        : _bakingTime.day == now.day + 1
            ? 'Morgen'
            : '${_bakingTime.day}.${_bakingTime.month}.';
    final timeStr =
        '${_bakingTime.hour.toString().padLeft(2, '0')}:${_bakingTime.minute.toString().padLeft(2, '0')} Uhr';
    final inStr = h > 0 ? 'in ${h}h${m > 0 ? ' ${m}min' : ''}' : 'in ${m}min';
    return '$dayLabel, $timeStr  ($inStr)';
  }

  Future<void> _pickEarliestStart() async {
    final now = DateTime.now();
    final initial = _earliestStart ?? DateTime(now.year, now.month, now.day, 8, 0);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: _bakingTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, onSurface: AppColors.text),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, onSurface: AppColors.text),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _earliestStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatEarliestStart(DateTime dt) {
    final now = DateTime.now();
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final wd = weekdays[dt.weekday - 1];
    final dayLabel = dt.day == now.day ? 'Heute' : '$wd ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} Uhr';
    return '$dayLabel, $timeStr';
  }

  Future<void> _editRefreshTime(int stepIndex, DateTime currentTime, List<_RefreshEntry> allEntries) async {
    // Zeit-Picker öffnen — KEINE Validierung, Benutzer wählt frei
    final date = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, onSurface: AppColors.text),
        ),
        child: child!,
      ),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, onSurface: AppColors.text),
        ),
        child: child!,
      ),
    );

    if (time == null || !mounted) return;

    final newTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      _customRefreshTimes[stepIndex] = newTime;
    });

    FeedbackService.log('Auffrischung $stepIndex: ${DateFormat('HH:mm').format(currentTime)} → ${DateFormat('HH:mm').format(newTime)}');

    // Nach Änderung die Erinnerungen neu planen
    if (_result != null) {
      _scheduleNotifications(_result!);
    }
  }

  /// Berechnet das beste Verhältnis für einen zeitlichen Abstand
  Map<String, dynamic> _calculatePossibleRatios(DateTime time1, DateTime time2) {
    final delta = time2.difference(time1).inMinutes / 60.0; // Stunden

    // Überprüfe welche Verhältnisse möglich sind
    final ratios = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0];
    final possible = <double>[];

    for (final f in ratios) {
      final timeNeeded = timeFromFactor(f, _temp);
      if (delta >= timeNeeded) {
        possible.add(f);
      }
    }

    final minTimeNeeded = timeFromFactor(1.0, _temp); // 1:1:1 ist minimum
    final isPossible = delta >= minTimeNeeded;

    return {
      'isPossible': isPossible,
      'delta': delta,
      'minTimeNeeded': minTimeNeeded,
      'possibleRatios': possible,
      'bestRatio': possible.isNotEmpty ? possible.last : null, // Höchstes Verhältnis
    };
  }

  DateTime minOf(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  Future<void> _initNotifications() async {
    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await notifications.initialize(initSettings);
    }
  }

  // ── Berechnen ─────────────────────────────────────────────
  void _calculate({bool skipShortageDialog = false}) {
    final hours = _hours;
    FeedbackService.log("Berechnung gestartet: Temp $_temp°C, Zielzeit ${hours.toStringAsFixed(1)} h (Backzeit: ${_formatBakingTime()})");
    if (hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Backzeit angeben.')),
      );
      return;
    }

    final best = pickBestFactor(hours, _temp);
    final factor = best['factor'] as double;
    final fExact = best['exact'] as double;
    final estTime = timeFromFactor(factor, _temp);
    final timeDiff = (estTime - hours).abs();
    final ratio = ratioLabel(factor);

    // TEMPERATUR-KOMPENSATION: ideale Wassertemperatur (Bäcker-DDT)
    final wasserTempC = wasserTemperatur(_temp, zielTemp: zielTeigTemp(estTime));

    final rW = factor, rM = factor;
    final total = 1.0 + rW + rM; // = 1 + 2*factor

    // Mindest-Anstellgut für _amount, gedeckelt auf Vorrat
    // Einkalkuliert die 5g-Rücklage: (_amount + 5) / total
    final anstellgutNeeded = ((_amount + 5) / total).ceil();
    final anstellgutMin    = anstellgutNeeded.clamp(1, _starter.toInt());
    // Wenn der Restvorrat (ungefüttert) zu klein wäre (< 10g), lieber
    // ALLES füttern → Rücklage kommt dann aus dem frischen Ansatz
    final unusedIfMinimum = _starter.toInt() - anstellgutMin;
    final anstellgut = unusedIfMinimum < 10
        ? _starter.toInt()   // alle füttern, Rest kommt aus Batch
        : anstellgutMin;     // nur Minimum nehmen, Rest bleibt im Kühlschrank
    final wasser = (anstellgut * rW).ceil();
    final mehl   = (anstellgut * rM).ceil();
    final gesamt = anstellgut + wasser + mehl;
    final forRecipeRaw    = _amount.toInt().clamp(0, gesamt);
    final naturalLeftover = gesamt - forRecipeRaw;
    // Unverbrauchter Vorrat: Starter der gar nicht in den Ansatz geflossen ist
    final unusedStarter = _starter.toInt() - anstellgut;
    // Wenn genug Vorrat im Kühlschrank bleibt (≥10g), braucht nichts aus dem
    // Batch zurückgelassen werden – der ganze Batch geht ins Rezept
    final int leftover;
    if (unusedStarter >= 10) {
      leftover = 0; // alles aus dem Batch für's Rezept, Kühlschrank-Vorrat = neues Anstellgut
    } else {
      // Mindest-Rücklage nur wenn kein natürlicher Rest + kein Restvorrat vorhanden
      final minKeep = (naturalLeftover == 0 && unusedStarter < 5) ? 5 : 0;
      leftover = naturalLeftover > minKeep ? naturalLeftover : minKeep.clamp(0, gesamt);
    }
    final forRecipe = gesamt - leftover;


    // Rückwärts von der Backzeit berechnen:
    // Backzeit = Peak, Fütterzeit = Backzeit - estTime
    final dPeak = _bakingTime;
    final dFeed = _bakingTime.subtract(Duration(minutes: (estTime * 60).round()));
    final dHalf = dFeed.add(Duration(minutes: (estTime * 0.5 * 60).round()));

    // Temperaturinfo
    String tempLabel, tempAdvice;
    if (_temp <= 6) {
      tempLabel = 'Kühlschrank-Temperatur';
      tempAdvice = 'Extrem langsam. Nur für Pausen geeignet. Starter erst auf Raumtemperatur bringen.';
    } else if (_temp <= 14) {
      tempLabel = 'Sehr kalt';
      tempAdvice = 'Langsam. Starter an wärmeren Ort stellen (Backofen mit Lampe, ~25°C).';
    } else if (_temp <= 20) {
      tempLabel = 'Kühl — kontrollierbar';
      tempAdvice = 'Gute Arbeitstemperatur. Starter entwickelt schönes Aroma.';
    } else if (_temp <= 25) {
      tempLabel = 'Ideal ✓';
      tempAdvice = 'Optimale Bedingungen. Gut vorhersagbar, volles Aroma.';
    } else if (_temp <= 30) {
      tempLabel = 'Warm — beobachten';
      tempAdvice = 'Schnell. Regelmäßig prüfen — Höhepunkt kommt und geht schnell.';
    } else if (_temp <= 35) {
      tempLabel = 'Heiß — Vorsicht';
      tempAdvice = 'Sehr schnell. Kaltes Wasser (8–12°C) nutzen. Gut im Auge behalten.';
    } else if (_temp <= 38) {
      tempLabel = '⚠️ Kritisch heiß';
      tempAdvice = 'Am Limit! Nach dem Füttern sofort in den Kühlschrank (4–6°C). Dort langsam fermentieren lassen.';
    } else {
      tempLabel = '☠️ Zu heiß!';
      tempAdvice = 'Ab 38°C sterben Milchsäurebakterien! Starter SOFORT kühlen. Backen verschieben.';
    }

    // Schritte
    List<String> steps;
    if (_temp >= 38) {
      steps = [
        'Starter sofort kühlen — Glas direkt in den Kühlschrank (4–6°C).',
        'Backen verschieben auf einen kühleren Zeitpunkt (unter 32°C).',
        'Nach dem Abkühlen: 1–2h akklimatisieren, dann mit 1/1/1 und kaltem Wasser füttern.',
        'Schwimmtest (Float-Test) nach Verdopplung. Wenn positiv → normal weitermachen.',
      ];
    } else if (_temp >= 35) {
      steps = [
        'Eiskaltes Wasser (8–10°C) abmessen: ${wasser}g',
        'Mehl: ${mehl}g — Anstellgut: ${anstellgut}g',
        'Verrühren, 15–20 Min. bei Raumtemperatur anspringen lassen, dann sofort in den Kühlschrank',
        'Im Kühlschrank nach ca. ${formatH(estTime * 2.5)}–${formatH(estTime * 3)} prüfen',
        'Nach Verdopplung ${forRecipe}g abnehmen → in den Teig',
        'Restliche ${leftover}g als neues Anstellgut im Kühlschrank aufbewahren',
      ];
    } else if (_temp <= 14) {
      steps = [
        'Wärmeren Ort suchen: Nähe Herd, Backofen mit Lampe (ca. 25°C)',
        'Wasser (leicht warm, max. 30°C): ${wasser}g',
        'Mehl: ${mehl}g — Anstellgut: ${anstellgut}g — verrühren',
        'An den wärmsten Ort stellen und regelmäßig prüfen',
        'Verdopplung abwarten — dauert bei ${_temp.toInt()}°C deutlich länger',
        '${forRecipe}g abnehmen → in den Teig. Rest als neues Anstellgut.',
      ];
    } else {
      steps = [
        'Wasser abmessen (Raumtemperatur): ${wasser}g',
        'Mehl: ${mehl}g + Anstellgut: ${anstellgut}g',
        'Alles in ein sauberes Glas geben und gut verrühren',
        'Glas mit Gummiband bei aktueller Füllhöhe markieren',
        'Bei ca. ${_temp.toInt()}°C stehen lassen — nach ca. ${formatH(estTime)} prüfen',
        'Bei Verdopplung: sofort ${forRecipe}g abnehmen und in den Teig',
        '${leftover}g als neues Anstellgut ${_temp > 28 ? 'sofort in den Kühlschrank' : 'weiterführen oder kühlen'}',
      ];
    }

    final result = PlanerResult(
      temp: _temp, factor: factor, fExact: fExact, ratio: ratio,
      estTime: estTime, timeDiff: timeDiff,
      anstellgut: anstellgut, wasser: wasser, mehl: mehl,
      gesamt: gesamt, forRecipe: forRecipe, leftover: leftover, unusedStarter: unusedStarter,
      wasserTempC: wasserTempC,
      dFeed: dFeed, dHalf: dHalf, dPeak: dPeak,
      tempLabel: tempLabel, tempAdvice: tempAdvice, steps: steps,
    );

    FeedbackService.log(
      'Ergebnis: Verhältnis $ratio, Anstellgut ${anstellgut}g + '
      'Wasser ${wasser}g + Mehl ${mehl}g = Gesamt ${gesamt}g → '
      'Rezept ${forRecipe}g, behalten ${leftover}g, '
      'geschätzte Gärzeit ${formatH(estTime)}',
    );

    if (forRecipe < _amount.toInt() && !skipShortageDialog && _refreshCount == 0) {
      FeedbackService.log(
        'Warnung Zu-wenig-Anstellgut: vorhanden ${_starter.toInt()}g, '
        'benötigt ${anstellgutNeeded}g für ${_amount.toInt()}g Sauerteig',
      );
      _showStarterShortageDialog(result, anstellgutNeeded);
    } else {
      _applyResult(result);
    }
  }

  void _applyResult(PlanerResult result) {
    setState(() => _result = result);
    _scheduleNotifications(result);
  }

  // ── Lösungs-Dialog bei zu wenig Anstellgut ────────────────
  void _showStarterShortageDialog(PlanerResult result, int anstellgutNeeded) {
    // Lösung B: Mindest-Faktor damit _starter für _amount reicht (mit 5g Rücklage)
    final fMin = ((_amount + 5) / _starter - 1.0) / 2.0;
    final timeForAmount = timeFromFactor(fMin.clamp(0.5, 50.0), _temp);
    // Lösung B nur anbieten wenn die benötigte Zeit ≤ 36h (Slider-Maximum)
    final solutionBPossible = timeForAmount <= 36.0;

    // Lösung C: Starter vorher mit 1:1:1 auffrischen
    final preFeedA = _starter.toInt();
    final preFeedGesamt = preFeedA * 3;
    final preFeedTime = timeFromFactor(1.0, _temp);
    final preFeedReicht = preFeedGesamt >= anstellgutNeeded;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Flexible(child: Text('Zu wenig Anstellgut',
              style: TextStyle(color: AppColors.gold, fontSize: 17,
                  fontWeight: FontWeight.w600))),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined,
                color: AppColors.text3, size: 20),
            tooltip: 'Fehler melden',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.showReportDialog(context);
            },
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Situation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Mit deinen ${_starter.toInt()}g Anstellgut kannst du bei diesem '
                  'Verhältnis maximal ${result.forRecipe}g Sauerteig fürs Rezept herstellen — '
                  'du brauchst aber ${_amount.toInt()}g.\n\n'
                  'Mindest-Anstellgut nötig: ${anstellgutNeeded}g.',
                  style: const TextStyle(color: AppColors.text2, fontSize: 13,
                      height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Mögliche Lösungen:',
                  style: TextStyle(color: AppColors.text3, fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 10),

              // Lösung A: Jetzt mit weniger fortfahren
              _SolutionTile(
                icon: '✅',
                title: 'Jetzt mit ${result.forRecipe}g fortfahren',
                body: 'Reduziere das Rezept auf ${result.forRecipe}g Sauerteig '
                    'oder passe die Zutaten entsprechend an.',
                onTap: () {
                  Navigator.pop(ctx);
                  _applyResult(result);
                },
              ),
              const SizedBox(height: 8),

              // Lösung B: Längere Zeit wählen
              _SolutionTile(
                icon: '⏱️',
                title: solutionBPossible
                    ? 'Zeit verlängern auf ~${formatH(timeForAmount)}'
                    : 'Zeit verlängern (nicht möglich)',
                body: solutionBPossible
                    ? 'Mit einem größeren Verhältnis (längere Gärzeit) reichen deine '
                        '${_starter.toInt()}g Anstellgut für ${_amount.toInt()}g. '
                        'Stelle die Zeit auf mindestens ${formatH(timeForAmount)} ein '
                        'und berechne neu.'
                    : 'Selbst bei maximalen 36h reichen ${_starter.toInt()}g Anstellgut '
                        'nicht für ${_amount.toInt()}g. Bitte Starter auffrischen '
                        'oder Menge reduzieren.',
                onTap: solutionBPossible
                    ? () {
                        Navigator.pop(ctx);
                        setState(() {
                          // Bucket-Grenze: 5 Min Puffer, damit _calculate() nicht knapp darunter rutscht
                          _bakingTime = DateTime.now().add(Duration(minutes: (timeForAmount.clamp(1.0, 36.0) * 60).round() + 5));
                          _customRefreshTimes.clear();
                        });
                        _calculate(skipShortageDialog: true);
                      }
                    : null,
              ),
              const SizedBox(height: 8),

              // Lösung C: Starter vorher auffrischen
              _SolutionTile(
                icon: '🔁',
                title: 'Starter vorher auffrischen (1:1:1)',
                body: preFeedReicht
                    ? 'Füttere jetzt ${preFeedA}g Anstellgut mit:\n'
                        '+ ${preFeedA}g Wasser  + ${preFeedA}g Mehl\n'
                        'Nach ca. ${formatH(preFeedTime)} hast du ~${preFeedGesamt}g '
                        'aktiven Starter — dann reicht es für ${_amount.toInt()}g. '
                        'Anschließend neu berechnen.'
                    : 'Füttere jetzt mit 1:1:1. Nach ca. ${formatH(preFeedTime)} '
                        'hast du ~${preFeedGesamt}g — für ${_amount.toInt()}g '
                        'brauchst du ${anstellgutNeeded}g. '
                        'Ggf. einen weiteren Fütterungszyklus einplanen.',
                onTap: () {
                  Navigator.pop(ctx);
                  // Anstellgut-Feld auf die Menge nach dem Füttern setzen
                  setState(() => _starter = preFeedGesamt.toDouble());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      'Füttere ${preFeedA}g Anstellgut mit ${preFeedA}g Wasser + ${preFeedA}g Mehl. '
                      'Nach ca. ${formatH(preFeedTime)} hier neu berechnen.',
                    ),
                    duration: const Duration(seconds: 6),
                  ));
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.text2)),
          ),
        ],
      ),
    );
  }

  // ── Benachrichtigungen ────────────────────────────────────
  Future<void> _scheduleNotifications(PlanerResult r) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ Erinnerungen nicht im Browser verfügbar')),
      );
      return;
    }

    // Nur Planer-IDs 1–29 löschen (nicht 200 = Starter, nicht 100+ = Baking, nicht 300+ = Timer)
    for (var id = 1; id < 30; id++) {
      try {
        await notifications.cancel(id);
      } catch (e) {
        // Ignorieren wenn ID nicht existiert
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'sauerteig', 'Sauerteig Planer',
      channelDescription: 'Erinnerungen für den Sauerteig',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final now = DateTime.now();
    final location = tz.local;

    // Hilfsfunktion: DateTime → TZDateTime in lokaler Zeitzone
    tz.TZDateTime toTZ(DateTime dt) => tz.TZDateTime.from(dt, location);

    // scheduleAt gibt true zurück wenn geplant, false wenn Zeit vorbei
    Future<bool> scheduleAt(int id, DateTime time, String title, String body) async {
      if (time.isAfter(now)) {
        try {
          await notifications.zonedSchedule(
            id, title, body,
            toTZ(time),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          return true;
        } on PlatformException catch (e) {
          if (e.code == 'exact_alarms_not_permitted') {
            FeedbackService.log('Benachrichtigungen: Exakte Benachrichtigungen nicht erlaubt, fallback auf inexactAllowWhileIdle');
            await notifications.zonedSchedule(
              id, title, body,
              toTZ(time),
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            return true;
          } else {
            rethrow;
          }
        }
      }
      return false;
    }

    int notificationCount = 0;

    // Auffrischungen planen (wenn _refreshCount > 0)
    if (_refreshCount > 0) {
      final plan = _buildRefreshPlan(r, _refreshCount, _temp, _bakingTime,
          recipeAmount: _amount.toInt(), customTimes: _customRefreshTimes, earliestStart: _earliestStart);

      // Prüfe ob Auffrischungsplan nicht möglich (in der Vergangenheit liegt)
      if (_isRefreshPlanPast(plan, _earliestStart)) {
        FeedbackService.log('Benachrichtigungen: Auffrischungsplan nicht möglich – keine Erinnerungen gesetzt');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Plan nicht möglich – keine Erinnerungen gesetzt'),
              backgroundColor: AppColors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Jede Auffrischung: ID 10 + Index
      for (var i = 0; i < plan.refreshes.length; i++) {
        final e = plan.refreshes[i];
        final id = 10 + i;
        final scheduled = await scheduleAt(
          id,
          e.time,
          '🔄 ${e.step}. Auffrischen',
          '${e.starter}g Anstellgut + ${e.water}g Wasser (${e.wasserTempC}°C) + ${e.flour}g Mehl (${ratioText(e.faktor)})',
        );
        if (scheduled) notificationCount++;
      }

      // Levain (letzte Fütterung): ID 20
      final lev = plan.levain;
      final levainScheduled = await scheduleAt(
        20,
        lev.time,
        '🍞 Letzte Fütterung (Levain)',
        '${lev.starter}g Anstellgut + ${lev.water}g Wasser (${lev.wasserTempC}°C) + ${lev.flour}g Mehl (${ratioText(lev.faktor)}) → ${_amount.toInt()}g fürs Rezept, ${plan.keptFromLevain}g aufheben',
      );
      if (levainScheduled) notificationCount++;

      // 15 Min Vorwarnung vor Peak (Backzeit): ID 2
      // Nutze _bakingTime statt r.dPeak, damit Änderungen der Backzeit berücksichtigt werden
      final preWarning = _bakingTime.subtract(const Duration(minutes: 15));
      final preWarningScheduled = await scheduleAt(
        2,
        preWarning,
        '⏰ Sauerteig fast fertig!',
        'In ~15 Minuten ist der Höhepunkt erreicht. Bereit machen!',
      );
      if (preWarningScheduled) notificationCount++;

      // Peak (Backzeit): ID 3
      // Nutze _bakingTime statt r.dPeak, damit Änderungen der Backzeit berücksichtigt werden
      final peakScheduled = await scheduleAt(
        3,
        _bakingTime,
        '🎯 HÖHEPUNKT — Sauerteig verwenden!',
        '${_amount.toInt()}g abnehmen → in den Teig. Schwimmtest (Float-Test) machen!',
      );
      if (peakScheduled) notificationCount++;
    } else {
      // Keine Auffrischungen: bisherige 3 Erinnerungen
      final halfScheduled = await scheduleAt(
        1,
        r.dHalf,
        '🫧 Sauerteig prüfen',
        'Bläschen sichtbar? Noch ${formatH(r.estTime * 0.5)} bis zum Höhepunkt.',
      );
      if (halfScheduled) notificationCount++;

      final preWarning = r.dPeak.subtract(const Duration(minutes: 15));
      final preWarningScheduled = await scheduleAt(
        2,
        preWarning,
        '⏰ Sauerteig fast fertig!',
        'In ~15 Minuten ist der Höhepunkt erreicht. Bereit machen!',
      );
      if (preWarningScheduled) notificationCount++;

      final peakScheduled = await scheduleAt(
        3,
        r.dPeak,
        '🎯 HÖHEPUNKT — Sauerteig verwenden!',
        '${r.forRecipe}g abnehmen → in den Teig. Schwimmtest (Float-Test) machen!',
      );
      if (peakScheduled) notificationCount++;
    }

    if (!mounted) return;

    if (notificationCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $notificationCount Erinnerungen gesetzt!'),
          backgroundColor: const Color(0xFF1A3020),
        ),
      );
    }
  }

  // ── ICS Export ────────────────────────────────────────────
  Future<void> _exportICS() async {
    final r = _result;
    if (r == null) return;

    // ── Auswahl-Dialog ───────────────────────────────────────
    final fmt2 = DateFormat('HH:mm');
    final events = [
      _ICSEvent(
        uid: 1,
        summary: '🍞 Sauerteig füttern (Feed)',
        desc: 'Verhältnis ${r.ratio}\nAnstellgut (Starter): ${r.anstellgut}g\nWasser: ${r.wasser}g (${r.wasserTempC}°C)\nMehl: ${r.mehl}g',
        start: r.dFeed,
        end: r.dFeed.add(const Duration(minutes: 10)),
        timeLabel: fmt2.format(r.dFeed),
      ),
      _ICSEvent(
        uid: 2,
        summary: '🫧 Erste Aktivität prüfen',
        desc: 'Bläschen sichtbar?\nNoch ${formatH(r.estTime * 0.5)} bis Höhepunkt (Peak).',
        start: r.dHalf,
        end: r.dHalf.add(const Duration(minutes: 10)),
        timeLabel: fmt2.format(r.dHalf),
      ),
      _ICSEvent(
        uid: 3,
        summary: '🎯 Höhepunkt (Peak) — jetzt verwenden!',
        desc: '${r.forRecipe}g abnehmen → in den Teig\nSchwimmtest (Float-Test) machen!\n${r.leftover}g als neues Anstellgut (Starter).',
        start: r.dPeak,
        end: r.dPeak.add(const Duration(minutes: 15)),
        timeLabel: fmt2.format(r.dPeak),
      ),
    ];

    final selected = await _showICSSelectionDialog(events);
    if (selected == null || selected.isEmpty) return;

    String icsDate(DateTime d) =>
        d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d{3}'), '');

    final icsUid = '${r.dFeed.millisecondsSinceEpoch}';

    final ics = StringBuffer();
    ics.write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Sauerteig Planer//DE\r\n');
    for (final e in selected) {
      ics.write(
        'BEGIN:VEVENT\r\n'
        'UID:sauerteig-$icsUid-${e.uid}@sauerteig-planer\r\n'
        'DTSTART:${icsDate(e.start)}\r\n'
        'DTEND:${icsDate(e.end)}\r\n'
        'SUMMARY:${e.summary}\r\n'
        'DESCRIPTION:${e.desc.replaceAll('\n', '\\n')}\r\n'
        'BEGIN:VALARM\r\nTRIGGER:-PT0M\r\nACTION:DISPLAY\r\nDESCRIPTION:${e.summary}\r\nEND:VALARM\r\n'
        'END:VEVENT\r\n',
      );
    }
    ics.write('END:VCALENDAR\r\n');

    final fmt = DateFormat('HH:mm dd.MM.');
    FeedbackService.log(
      'ICS-Export: ${selected.length} Termine → '
      '${selected.map((e) => "${e.summary.substring(0, 2)} ${fmt.format(e.start)}").join(", ")}',
    );

    if (kIsWeb) {
      final bytes = Uint8List.fromList(ics.toString().codeUnits);
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'Sauerteig_Zeitplan.ics', mimeType: 'text/calendar')],
        text: 'Sauerteig Zeitplan',
      );
    } else {
      final dir = await getTemporaryDirectory();
      final file = io.File('${dir.path}/Sauerteig_Zeitplan.ics');
      await file.writeAsString(ics.toString());
      await OpenFilex.open(file.path, type: 'text/calendar');
    }
  }

  Future<List<_ICSEvent>?> _showICSSelectionDialog(List<_ICSEvent> events) async {
    final selected = List<bool>.filled(events.length, true);
    return showDialog<List<_ICSEvent>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('📅 Kalender-Export',
              style: TextStyle(color: AppColors.gold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Welche Termine exportieren?',
                  style: TextStyle(color: AppColors.text2, fontSize: 13)),
              const SizedBox(height: 8),
              ...List.generate(events.length, (i) => CheckboxListTile(
                    value: selected[i],
                    onChanged: (v) => setLocal(() => selected[i] = v ?? false),
                    activeColor: AppColors.green,
                    title: Text(
                      events[i].summary,
                      style: const TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                    subtitle: Text(
                      events[i].timeLabel,
                      style: const TextStyle(color: AppColors.text3, fontSize: 11),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.text2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg),
              onPressed: () {
                final result = [
                  for (var i = 0; i < events.length; i++)
                    if (selected[i]) events[i]
                ];
                Navigator.pop(ctx, result);
              },
              child: const Text('Exportieren'),
            ),
          ],
        );
      }),
    );
  }

  // ── PDF Export ────────────────────────────────────────────
  Future<void> _exportPDF() async {
    final r = _result;
    if (r == null) return;

    final doc = pw.Document();
    final fmt = DateFormat('HH:mm');
    final gold = PdfColor.fromHex('#D4A84B');
    const dark = PdfColors.grey800;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // title
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: PdfColors.grey900),
            child: pw.Text('🍞 Sauerteig Zeitplan',
              style: pw.TextStyle(fontSize: 20, color: gold, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 12),

          // Zusammenfassung
          pw.Row(children: [
            _pdfBox('${r.temp.toInt()}°C', 'Temperatur', gold, ctx),
            pw.SizedBox(width: 8),
            _pdfBox(r.ratio, 'Verhältnis', gold, ctx),
            pw.SizedBox(width: 8),
            _pdfBox('~${formatH(r.estTime)}', 'bis Höhepunkt (Peak)', gold, ctx),
          ]),
          pw.SizedBox(height: 16),

          // Rezept
          _pdfSection('REZEPT', gold),
          _pdfRow('Anstellgut', '${r.anstellgut} g', dark),
          _pdfRow('Wasser', '${r.wasser} g', dark),
          _pdfRow('Wasser-Temperatur', '${r.wasserTempC} °C', dark),
          _pdfRow('Mehl', '${r.mehl} g', dark),
          _pdfRow('→ ins Rezept', '${r.forRecipe} g', dark, bold: true),
          _pdfRow('→ Anstellgut behalten', '${r.leftover} g', dark),
          pw.SizedBox(height: 12),

          // Zeitplan
          _pdfSection('ZEITPLAN', gold),
          _pdfTimeline(fmt.format(r.dFeed), 'Jetzt — Füttern',
              'Anstellgut ${r.anstellgut}g + Wasser ${r.wasser}g + Mehl ${r.mehl}g', gold),
          _pdfTimeline(fmt.format(r.dHalf), 'Erste Aktivität',
              'Bläschen sichtbar, Starter beginnt zu wachsen', dark),
          _pdfTimeline(fmt.format(r.dPeak), '🎯 HÖHEPUNKT — jetzt verwenden!',
              '${r.forRecipe}g abnehmen → in den Teig. Schwimmtest (Float-Test)!', gold),
          pw.SizedBox(height: 12),

          // Schritte
          _pdfSection('ANLEITUNG', gold),
          ...r.steps.asMap().entries.map((e) =>
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${e.key + 1}. ', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Expanded(child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 9, color: dark))),
              ]),
            )
          ),
          pw.SizedBox(height: 12),

          // Temperatur
          _pdfSection('TEMPERATURHINWEIS', gold),
          pw.Text(r.tempLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: dark)),
          pw.SizedBox(height: 4),
          pw.Text(r.tempAdvice, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ));

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Sauerteig_Zeitplan.pdf');
  }

  pw.Widget _pdfBox(String val, String lbl, PdfColor gold, pw.Context ctx) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(children: [
        pw.Text(val, style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 13), textAlign: pw.TextAlign.center),
        pw.Text(lbl, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
      ]),
    ));

  pw.Widget _pdfSection(String title, PdfColor gold) => pw.Container(
    width: double.infinity,
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    margin: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(title, style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 9)),
  );

  pw.Widget _pdfRow(String label, String val, PdfColor color, {bool bold = false}) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child:
      pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
        pw.Text(val, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]));

  pw.Widget _pdfTimeline(String time, String title, String desc, PdfColor color) =>
    pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8), child:
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(time, style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text(desc, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ])),
      ]));

  // ═══════════════════════════════════════════════════════════
  //  BUILD UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF1A1510),
            actions: [
              if (_savedPlans.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bookmark_outline, color: AppColors.gold),
                      tooltip: 'Gespeicherte Pläne',
                      onPressed: _showSavedPlans,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_savedPlans.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.bug_report, color: AppColors.red),
                tooltip: 'Fehler melden',
                onPressed: () => FeedbackService.showReportDialog(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('🍞 Sauerteig Planer',
                style: TextStyle(color: AppColors.gold2, fontSize: 16, fontWeight: FontWeight.w600)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1510), AppColors.bg],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── EINGABE-KARTE ──────────────────────────
                _Card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    const _SectionTitle('⚙️ Eingabe'),
                    const SizedBox(height: 16),

                    // Temperatur-Slider
                    const _FieldLabel('Raumtemperatur'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        Text('${_temp.toInt()}°C',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: tempColor(_temp),
                          )),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: tempColor(_temp),
                            thumbColor: AppColors.gold,
                            inactiveTrackColor: AppColors.surface3,
                            overlayColor: AppColors.gold.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _temp, min: 4, max: 42,
                            divisions: 38,
                            onChanged: (v) => setState(() => _temp = v),
                          ),
                        ),
                        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('4°C ❄️', style: TextStyle(color: AppColors.text3, fontSize: 11)),
                            Text('22°C ✓', style: TextStyle(color: AppColors.text3, fontSize: 11)),
                            Text('42°C 🔥', style: TextStyle(color: AppColors.text3, fontSize: 11)),
                          ]),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Starter-Auswahl (wenn gespeicherte Starter vorhanden)
                    if (_myStarters.isNotEmpty) ...[
                      const _FieldLabel('Starter wählen'),
                      DropdownButtonFormField<MyStarter?>(
                        value: _selectedStarter,
                        isExpanded: true,
                        dropdownColor: AppColors.surface2,
                        style: const TextStyle(color: AppColors.text, fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: AppColors.surface2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<MyStarter?>(
                            value: null,
                            child: Text('— manuell eingeben —',
                                style: TextStyle(color: AppColors.text3)),
                          ),
                          ..._myStarters.map((s) => DropdownMenuItem<MyStarter?>(
                                value: s,
                                child: Text('🫙 ${s.name}  (${s.gramAmount} g)'),
                              )),
                        ],
                        onChanged: (s) => setState(() {
                          _selectedStarter = s;
                          if (s != null) _starter = s.gramAmount.toDouble();
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Mengen
                    Row(children: [
                      Expanded(child: _NumInput(
                        label: 'Sauerteig benötigt',
                        unit: 'g',
                        value: _amount,
                        onChanged: (v) => setState(() => _amount = v),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _NumInput(
                        label: 'Anstellgut vorhanden',
                        unit: 'g',
                        value: _starter,
                        onChanged: (v) => setState(() => _starter = v),
                      )),
                    ]),
                    const SizedBox(height: 14),

                    // Frühester Start (optional)
                    Row(children: [
                      const Expanded(child: _FieldLabel('Frühester Start (optional)')),
                      if (_earliestStart != null)
                        GestureDetector(
                          onTap: () => setState(() => _earliestStart = null),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.close, color: AppColors.text3, size: 16),
                          ),
                        ),
                    ]),
                    InkWell(
                      onTap: _pickEarliestStart,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _earliestStart != null
                              ? const Color(0xFF1A1A2A)
                              : AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _earliestStart != null
                                ? AppColors.blue.withValues(alpha: 0.6)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.play_circle_outline,
                              color: _earliestStart != null ? AppColors.blue : AppColors.text3,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _earliestStart != null
                                  ? _formatEarliestStart(_earliestStart!)
                                  : 'Ab sofort (Standard)',
                              style: TextStyle(
                                color: _earliestStart != null ? AppColors.blue : AppColors.text3,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit, color: AppColors.text3, size: 16),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Beginn Rezept (Levain-Peak)
                    const _FieldLabel('Beginn Rezept — wann soll der Starter bereit sein?'),
                    InkWell(
                      onTap: _pickBakingTime,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2210),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Row(children: [
                          const Icon(Icons.schedule, color: AppColors.gold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _formatBakingTime(),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit, color: AppColors.text3, size: 16),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Auffrischungen
                    const _FieldLabel('Auffrischungen vor dem Backen'),
                    DropdownButtonFormField<int>(
                      value: _refreshCount,
                      dropdownColor: AppColors.surface2,
                      style: const TextStyle(color: AppColors.text, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Keine — direkt füttern & backen')),
                        DropdownMenuItem(value: 1, child: Text('1× auffrischen (Pizza, Waffeln …)')),
                        DropdownMenuItem(value: 2, child: Text('2× auffrischen (Brötchen, Focaccia …)')),
                        DropdownMenuItem(value: 3, child: Text('3× auffrischen (Sauerteigbrot …)')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _refreshCount = v ?? 0;
                          _customRefreshTimes.clear();
                        });
                        // Nach Änderung die Erinnerungen neu planen
                        if (_result != null) {
                          _scheduleNotifications(_result!);
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    // Berechnen-Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _calculate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A1E08),
                          foregroundColor: AppColors.gold2,
                          side: const BorderSide(color: AppColors.goldDim),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('🧮 Anleitung berechnen',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── ERGEBNIS ──────────────────────────────────
                if (_result != null) ...[
                  if (_refreshCount == 0)
                    _ResultView(
                      result: _result!,
                      onExportICS: _exportICS,
                      onExportPDF: _exportPDF,
                      onSavePlan: _savePlan,
                      selectedStarterName: _selectedStarter?.name,
                      onMarkUsed: _selectedStarter != null ? _markStarterUsed : null,
                      earliestStart: _earliestStart,
                    ),
                  if (_refreshCount > 0) ...[
                    const SizedBox(height: 8),
                    _InlineRefreshPlan(
                      result: _result!,
                      refreshCount: _refreshCount,
                      temp: _temp,
                      bakingTime: _bakingTime,
                      recipeAmount: _amount.toInt(),
                      starterAvailable: _starter.toInt(),
                      earliestStart: _earliestStart,
                      customRefreshTimes: _customRefreshTimes,
                      onEditRefreshTime: _editRefreshTime,
                      onCalculatePossibleRatios: _calculatePossibleRatios,
                    ),
                  ],
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: const Column(children: [
                      Text('🌾', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 10),
                      Text('Eingaben ausfüllen und\nBerechnen tippen',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.text3, fontSize: 14)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ERGEBNIS-WIDGET
// ═══════════════════════════════════════════════════════════════
class _ResultView extends StatelessWidget {
  final PlanerResult result;
  final VoidCallback onExportICS;
  final VoidCallback onExportPDF;
  final VoidCallback onSavePlan;
  final String? selectedStarterName;
  final VoidCallback? onMarkUsed;
  final DateTime? earliestStart;

  const _ResultView({
    required this.result,
    required this.onExportICS,
    required this.onExportPDF,
    required this.onSavePlan,
    this.selectedStarterName,
    this.onMarkUsed,
    this.earliestStart,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final fmt = DateFormat('HH:mm');
    final fmtFull = DateFormat('EE dd.MM. HH:mm');
    final timeDiffStr = formatH(r.timeDiff);
    final now = DateTime.now();

    // Prüfen ob Fütterzeit vor dem frühesten Start liegt
    final refPoint = earliestStart ?? now;
    final feedInPast = r.dFeed.isBefore(refPoint);
    final lateBy = feedInPast
        ? now.difference(r.dFeed).inMinutes / 60.0
        : 0.0;

    // Datum nur zeigen wenn nicht heute
    String feedLabel() {
      if (feedInPast) return '${fmt.format(r.dFeed)} ⚠️ (bereits vorbei)';
      if (r.dFeed.day == now.day) return '${fmt.format(r.dFeed)} Uhr — heute';
      return '${fmtFull.format(r.dFeed)} Uhr';
    }
    String peakLabel() {
      if (r.dPeak.day == now.day) return '${fmt.format(r.dPeak)} Uhr — heute';
      return '${fmtFull.format(r.dPeak)} Uhr';
    }
    String halfLabel() {
      if (r.dHalf.day == now.day) return '${fmt.format(r.dHalf)} (+${formatH(r.estTime * 0.5)})';
      return '${fmtFull.format(r.dHalf)} (+${formatH(r.estTime * 0.5)})';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── WARNUNG: Backzeit nicht erreichbar ───────────────
      if (feedInPast) ...[
        _InfoBox(
          color: AppColors.red,
          bgColor: const Color(0xFF200808),
          text: earliestStart != null
              ? '⚠️ Zu wenig Zeit! Mit frühestem Start ${DateFormat('E dd.MM. HH:mm').format(earliestStart!)} Uhr '
                'müsstest du den Beginn Rezept auf ${DateFormat('E dd.MM. HH:mm').format(earliestStart!.add(Duration(minutes: (r.estTime * 60).round())))} Uhr verschieben.'
              : '⚠️ Zu wenig Zeit! Du müsstest bereits vor ${formatH(lateBy)} gefüttert haben. '
                'Wähle einen späteren Beginn Rezept oder erhöhe die Temperatur.',
        ),
        const SizedBox(height: 12),
      ],

      // ── ZUSAMMENFASSUNG ──────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('📊 Zusammenfassung'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SummaryBox(value: '${r.temp.toInt()}°C', label: r.tempLabel, color: tempColor(r.temp))),
          const SizedBox(width: 8),
          Expanded(child: _SummaryBox(value: r.ratio, label: 'Verhältnis', color: AppColors.gold2)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryBox(value: '~${formatH(r.estTime)}', label: 'bis Höhepunkt (Peak)', color: AppColors.text)),
        ]),
        if (r.fExact != r.factor) ...[
          const SizedBox(height: 10),
          _InfoBox(
            color: AppColors.blue,
            bgColor: const Color(0xFF0E1820),
            text: '🔢 Exaktes Verhältnis: 1 / ${r.fExact.toStringAsFixed(1)} / ${r.fExact.toStringAsFixed(1)}'
                ' → gerundet auf ${r.ratio} (±$timeDiffStr)',
          ),
        ],
        const SizedBox(height: 10),
        _InfoBox(
          color: AppColors.blue,
          bgColor: const Color(0xFF0E1820),
          text: '🌡️ Ideale Wassertemperatur: ${r.wasserTempC} °C — gleicht ${r.temp.toInt()} °C Raumtemperatur aus (Bäcker-DDT).',
        ),
        const SizedBox(height: 14),
        _RecipeTable(r: r),
      ])),

      const SizedBox(height: 12),

      // ── ZEITPLAN ───────────────────────��─────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('🕐 Zeitplan'),
        const SizedBox(height: 14),
        _TimelineItem(
          time: feedLabel(),
          title: 'Füttern',
          desc: 'Anstellgut ${r.anstellgut}g + Wasser ${r.wasser}g (🌡️ ${r.wasserTempC}°C) + Mehl ${r.mehl}g verrühren. Höhe markieren.',
          isNow: !feedInPast,
          isWarning: feedInPast,
        ),
        _TimelineItem(
          time: halfLabel(),
          title: 'Erste Aktivität',
          desc: 'Bläschen sichtbar, Starter beginnt zu wachsen.',
        ),
        _TimelineItem(
          time: '${peakLabel()} 🎯',
          title: 'Höhepunkt — jetzt verwenden!',
          desc: 'Verdoppelt. ${r.forRecipe}g abnehmen → in den Teig. Schwimmtest (Float-Test)!',
          isHighlight: true,
        ),
        _TimelineItem(
          time: 'danach',
          title: 'Rest wegstellen',
          desc: '${r.leftover}g als neues Anstellgut. ${r.temp > 28 ? 'Sofort in den Kühlschrank.' : 'Kühlschrank oder weiterführen.'}',
        ),
        const SizedBox(height: 10),
        const _InfoBox(
          color: AppColors.green,
          bgColor: Color(0xFF0E2018),
          text: '🧪 Schwimmtest (Float-Test): 1 TL Starter ins Wasser — schwimmt er? → Bereit ✅   Sinkt er? → Noch warten.',
        ),
      ])),

      const SizedBox(height: 12),

      // ── MENGE VERWENDET ──────────────────────────────────
      if (onMarkUsed != null) ...[
        GestureDetector(
          onTap: onMarkUsed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2018),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              const Text('🫙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '$selectedStarterName — Menge verwendet',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.anstellgut}g Anstellgut vom Vorrat abziehen',
                    style: const TextStyle(color: AppColors.text2, fontSize: 12),
                  ),
                ]),
              ),
              const Icon(Icons.check_circle_outline, color: AppColors.green, size: 22),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],

      // ── SCHRITTE ─────────────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('📋 Schritt-für-Schritt'),
        const SizedBox(height: 12),
        ...r.steps.asMap().entries.map((e) => _StepItem(index: e.key + 1, text: e.value)),
      ])),

      const SizedBox(height: 12),

      // ── TEMPERATURHINWEISE ────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('🌡️ Temperaturhinweise'),
        const SizedBox(height: 10),
        Text(r.tempAdvice, style: const TextStyle(color: AppColors.text2, fontSize: 14, height: 1.6)),
        const Divider(color: AppColors.border, height: 24),
        const _TempLegend(),
      ])),

      const SizedBox(height: 16),

      // ── ÜBERSCHUSS-HINWEIS ───────────────────────────────
      if (r.unusedStarter > 0) ...[
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('♻️ Was tun mit dem Überschuss (Discard)?'),
          const SizedBox(height: 6),
          Text(
            '${r.unusedStarter}g Anstellgut (Starter) bleiben im Kühlschrank – '
            'das ist dein Überschuss (Discard). Nicht wegwerfen!',
            style: const TextStyle(color: AppColors.text2, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Builder(builder: (ctx) {
            final amount = r.unusedStarter;
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _SmallChip('🥞 Pfannkuchen', onTap: () => showDiscardRecipe(ctx, 'Pfannkuchen', amount)),
                _SmallChip('🧇 Waffeln', onTap: () => showDiscardRecipe(ctx, 'Waffeln', amount)),
                _SmallChip('🍕 Pizza-Teig', onTap: () => showDiscardRecipe(ctx, 'Pizza-Teig', amount)),
                _SmallChip('🍪 Kekse & Cracker', onTap: () => showDiscardRecipe(ctx, 'Kekse & Cracker', amount)),
                _SmallChip('🫓 Focaccia', onTap: () => showDiscardRecipe(ctx, 'Focaccia', amount)),
                _SmallChip('🍌 Bananenbrot', onTap: () => showDiscardRecipe(ctx, 'Bananenbrot', amount)),
                _SmallChip('🌮 Tortillas', onTap: () => showDiscardRecipe(ctx, 'Tortillas', amount)),
                _SmallChip('🍲 Soße andicken', onTap: () => showDiscardRecipe(ctx, 'Soße andicken', amount)),
              ],
            );
          }),
        ])),
        const SizedBox(height: 16),
      ],

      // ── EXPORT ───────────────────────────────────────────
      Row(children: [
        Expanded(child: _ExportButton(
          icon: '💾',
          label: 'In App\nspeichern',
          color: AppColors.green,
          onTap: onSavePlan,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ExportButton(
          icon: '📅',
          label: 'Kalender\n(.ics)',
          color: AppColors.blue,
          onTap: onExportICS,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ExportButton(
          icon: '📑',
          label: 'PDF\nexportieren',
          color: AppColors.gold,
          onTap: onExportPDF,
        )),
      ]),

      const SizedBox(height: 40),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  KLEINE WIEDERVERWENDBARE WIDGETS
// ═══════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontFamily: 'serif', fontSize: 16,
        fontWeight: FontWeight.bold, color: AppColors.gold));
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.text2, letterSpacing: 0.8)),
  );
}

class _NumInput extends StatefulWidget {
  final String label, unit;
  final double value;
  final void Function(double) onChanged;

  const _NumInput({
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toInt().toString());
  }

  @override
  void didUpdateWidget(_NumInput old) {
    super.didUpdateWidget(old);
    // Wenn Wert von außen geändert wurde (z.B. Lösung C), Feld aktualisieren
    if (old.value != widget.value) {
      final newText = widget.value.toInt().toString();
      if (_ctrl.text != newText) _ctrl.text = newText;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(widget.label),
      TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: AppColors.text),
        decoration: InputDecoration(
          suffixText: widget.unit,
          suffixStyle: const TextStyle(color: AppColors.text3, fontSize: 13),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.goldDim),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null && parsed >= 1 && parsed <= 10000) {
            widget.onChanged(parsed);
          }
        },
      ),
    ],
  );
}

class _SummaryBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SummaryBox({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(value, textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'monospace', fontSize: 16,
            fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: AppColors.text3)),
    ]),
  );
}

class _RecipeTable extends StatelessWidget {
  final PlanerResult r;
  const _RecipeTable({required this.r});
  @override
  Widget build(BuildContext context) => Table(
    columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2)},
    children: [
      _tableHeader(),
      _tableRow('Anstellgut', '${r.anstellgut} g', 'aus vorhandenem Starter'),
      _tableRow('Wasser', '${r.wasser} g', '🌡️ ${r.wasserTempC} °C ideal'),
      _tableRow('Mehl', '${r.mehl} g', 'Weizen 550 oder Roggen'),
      _tableRowBold('Gesamt', '${r.gesamt} g', ''),
      _tableRowGreen('→ ins Rezept', '${r.forRecipe} g', 'nach Verdopplung'),
      _tableRow(
        '→ behalten',
        '${r.leftover} g',
        r.leftover < 10 ? '⚠️ wenig – sicher aufbewahren' : 'neues Anstellgut',
      ),
    ],
  );

  TableRow _tableHeader() => TableRow(children: [
    'Zutat', 'Menge', 'Hinweis'
  ].map((t) => Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.text3, letterSpacing: 0.5)))).toList());

  TableRow _tableRow(String a, String b, String c) => TableRow(children: [
    _cell(a, AppColors.text2), _cell(b, AppColors.gold2, mono: true), _cell(c, AppColors.text3, small: true),
  ]);
  TableRow _tableRowBold(String a, String b, String c) => TableRow(children: [
    _cell(a, AppColors.text, bold: true), _cell(b, AppColors.text, mono: true), _cell(c, AppColors.text3),
  ]);
  TableRow _tableRowGreen(String a, String b, String c) => TableRow(children: [
    _cell(a, AppColors.text2), _cell(b, AppColors.green, mono: true), _cell(c, AppColors.text3, small: true),
  ]);

  Widget _cell(String t, Color c, {bool mono=false, bool bold=false, bool small=false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Text(t, style: TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontSize: small ? 11 : 13,
        color: c,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )));
}

class _TimelineItem extends StatelessWidget {
  final String time, title, desc;
  final bool isNow, isHighlight, isWarning;
  const _TimelineItem({required this.time, required this.title, required this.desc,
    this.isNow = false, this.isHighlight = false, this.isWarning = false});
  @override
  Widget build(BuildContext context) {
    final dotColor = isWarning ? AppColors.red : (isNow ? AppColors.gold : Colors.transparent);
    final dotBorder = isWarning ? AppColors.red : (isNow ? AppColors.gold : AppColors.goldDim);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: (isHighlight || isWarning) ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: (isHighlight || isWarning) ? BoxDecoration(
        color: isWarning ? const Color(0xFF200808) : const Color(0xFF1E1C10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isWarning ? AppColors.red.withValues(alpha: 0.6) : AppColors.goldDim),
      ) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 10, height: 10, margin: const EdgeInsets.only(top: 4, right: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: Border.all(color: dotBorder, width: 2),
            boxShadow: (isNow || isWarning) ? [BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 6)] : null,
          ),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(time, style: TextStyle(
            fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold,
            color: isWarning ? AppColors.red : (isHighlight ? AppColors.gold2 : AppColors.gold))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5)),
        ])),
      ]),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String text;
  const _StepItem({required this.index, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24, height: 24,
        margin: const EdgeInsets.only(right: 12, top: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface3,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text('$index',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.gold))),
      ),
      Expanded(child: Text(text,
        style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6))),
    ]),
  );
}

class _InfoBox extends StatelessWidget {
  final Color color, bgColor;
  final String text;
  const _InfoBox({required this.color, required this.bgColor, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.6)),
  );
}

class _TempLegend extends StatelessWidget {
  const _TempLegend();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LegendRow('❄️ Kühlschrank (4–6°C):', '1–2 Wochen, 1× pro Woche füttern', AppColors.blue),
      _LegendRow('🌿 18–24°C:', 'Ideal — gut vorhersagbar', AppColors.green),
      _LegendRow('🌡️ 28–32°C:', 'Schnell — aufmerksam beobachten', Color(0xFFE8C050)),
      _LegendRow('🔥 35°C+:', 'Eiskaltes Wasser + Kühlschrank-Strategie', AppColors.orange),
      _LegendRow('☠️ 38°C+:', 'Bakterien sterben — sofort kühlen!', AppColors.red),
    ],
  );
}

class _LegendRow extends StatelessWidget {
  final String label, desc;
  final Color color;
  const _LegendRow(this.label, this.desc, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: '$label ', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      TextSpan(text: desc, style: const TextStyle(color: AppColors.text3, fontSize: 12)),
    ])),
  );
}

class _ExportButton extends StatelessWidget {
  final String icon, label;
  final Color color;
  final VoidCallback onTap;
  const _ExportButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  LÖSUNGS-KACHEL (für Starter-Shortage-Dialog)
// ═══════════════════════════════════════════════════════════════
class _SolutionTile extends StatelessWidget {
  final String icon, title, body;
  final VoidCallback? onTap;
  const _SolutionTile({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tappable ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border,
            width: tappable ? 1.5 : 1,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: AppColors.gold2, fontSize: 13,
                    fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(color: AppColors.text2, fontSize: 12,
                    height: 1.5)),
          ])),
          if (tappable) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.gold, size: 18),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BACKZEIT-DIALOG — Uhrzeit primär, Datum optional änderbar
// ═══════════════════════════════════════════════════════════════
class _BakingTimeDialog extends StatefulWidget {
  final DateTime initial;
  const _BakingTimeDialog({required this.initial});

  @override
  State<_BakingTimeDialog> createState() => _BakingTimeDialogState();
}

class _BakingTimeDialogState extends State<_BakingTimeDialog> {
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _date = widget.initial;
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
  }

  DateTime get _result {
    var dt = DateTime(_date.year, _date.month, _date.day, _hour, _minute);
    if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  Future<void> _changeDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel() {
    final now = DateTime.now();
    if (_date.year == now.year && _date.month == now.month && _date.day == now.day) return 'Heute';
    if (_date.day == now.day + 1 && _date.month == now.month) return 'Morgen';
    return '${_date.day}.${_date.month}.${_date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final h = _hour.toString().padLeft(2, '0');
    final m = _minute.toString().padLeft(2, '0');

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Wann willst du backen?',
          style: TextStyle(color: AppColors.gold, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Datum-Zeile (optional ändern)
          InkWell(
            onTap: _changeDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, color: AppColors.text3, size: 16),
                const SizedBox(width: 8),
                Text(_dateLabel(),
                    style: const TextStyle(color: AppColors.text, fontSize: 14)),
                const Spacer(),
                const Text('ändern',
                    style: TextStyle(color: AppColors.orange, fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Uhrzeit — große Darstellung mit +/−
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeColumn(
                label: 'Stunde',
                value: _hour,
                onInc: () => setState(() => _hour = (_hour + 1) % 24),
                onDec: () => setState(() => _hour = (_hour - 1 + 24) % 24),
                display: h,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: TextStyle(
                    color: AppColors.gold, fontSize: 40, fontWeight: FontWeight.bold)),
              ),
              _TimeColumn(
                label: 'Minute',
                value: _minute,
                onInc: () => setState(() => _minute = (_minute + 5) % 60),
                onDec: () => setState(() => _minute = (_minute - 5 + 60) % 60),
                display: m,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Schritte: ±5 Minuten',
            style: TextStyle(color: AppColors.text3, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.text2)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _result),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.bg,
          ),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

class _TimeColumn extends StatelessWidget {
  final String label, display;
  final VoidCallback onInc, onDec;
  final int value;

  const _TimeColumn({
    required this.label,
    required this.value,
    required this.onInc,
    required this.onDec,
    required this.display,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onInc,
          icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.gold, size: 32),
          padding: EdgeInsets.zero,
        ),
        Text(display,
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
        IconButton(
          onPressed: onDec,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold, size: 32),
          padding: EdgeInsets.zero,
        ),
        Text(label, style: const TextStyle(color: AppColors.text3, fontSize: 10)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GEBÄCK & AUFFRISCHEN — Daten
// ═══════════════════════════════════════════════════════════════


// ── Auffrisch-Zeiteintrag ────────────────────────────────────────
class _RefreshEntry {
  final int step;          // 1, 2, 3, …
  final DateTime time;     // wann füttern
  final int starter;       // Anstellgut-Menge (g)
  final int water;         // Wasser (g)
  final int flour;         // Mehl (g)
  final int total;         // Gesamt (g)
  final double faktor;     // Verhältnis-Faktor (1:f:f)
  final int wasserTempC;   // ideale Wassertemperatur (°C)
  final DateTime peakTime; // wann peaked dieser Schritt

  const _RefreshEntry({
    required this.step,
    required this.time,
    required this.starter,
    required this.water,
    required this.flour,
    required this.total,
    required this.faktor,
    required this.wasserTempC,
    required this.peakTime,
  });
}

/// Kompletter Auffrischungsplan: n Auffrischungen + Levain (letzte Fütterung).
/// Alle Werte (Zeiten, Verhältnisse, Mengen, Wassertemp) stammen aus EINER
/// konsistenten Rückwärts-Berechnung.
class _RefreshPlan {
  final List<_RefreshEntry> refreshes; // Schritt 1..n
  final _RefreshEntry levain;          // letzte Fütterung (Schritt n+1)
  final int keptFromLevain;            // g als neues Anstellgut aufheben
  const _RefreshPlan({
    required this.refreshes,
    required this.levain,
    required this.keptFromLevain,
  });
}

/// Baut den kompletten Plan aus den Fütterungszeiten.
///
/// Zeit-Logik (das ist die eigentliche „Zeit-Berechnung"):
///  - n Auffrischungen + 1 Levain = n+1 Fütterungen.
///  - Default-Zeiten:
///      • Mit [earliestStart]: gleichmäßig über [earliestStart, bakingTime]
///        verteilt → große Fenster nutzen die verfügbare Zeit (höheres f).
///      • Ohne: rückwärts von der Backzeit, je Phase tR (1:1:1-Zeit) →
///        minimaler 1:1:1-Plan.
///  - [customTimes] überschreibt einzelne Fütterungen (Index 0..n, n = Levain).
///  - Fenster einer Phase = Abstand bis zur nächsten Fütterung (Levain: bis
///    Backzeit). Daraus wählt [waehleFaktor] das Verhältnis so, dass der Peak
///    noch ins Fenster passt.
///  - Mengen rückwärts: Levain liefert forRecipe + 20g; jede Auffrischung
///    liefert das ASG der Folgephase + 20g Kultur.
_RefreshPlan _buildRefreshPlan(
    PlanerResult r, int n, double temp, DateTime bakingTime,
    {required int recipeAmount, Map<int, DateTime> customTimes = const {}, DateTime? earliestStart}) {
  final tR = timeFromFactor(1.0, temp); // Stunden pro 1:1:1-Zyklus

  // ── 1) Fütterungszeiten bestimmen (n Auffrischungen + Levain) ──
  final feeds = List<DateTime>.generate(n + 1, (i) {
    if (customTimes[i] != null) return customTimes[i]!;
    if (earliestStart != null) {
      // Gleichmäßig über den verfügbaren Zeitraum verteilen
      final totalMin = bakingTime.difference(earliestStart).inMinutes;
      final stepMin = totalMin / (n + 1);
      return earliestStart.add(Duration(minutes: (i * stepMin).round()));
    }
    // Rückwärts von der Backzeit, je Phase tR
    final stepsFromBake = (n + 1) - i;
    return bakingTime.subtract(Duration(minutes: (stepsFromBake * tR * 60).round()));
  });

  // ── 2) Fenster + Verhältnisse ──
  final windows = List<double>.generate(n + 1, (i) {
    final next = (i < n) ? feeds[i + 1] : bakingTime;
    final w = next.difference(feeds[i]).inMinutes / 60.0;
    return w > 0 ? w : tR;
  });
  final factors = windows.map((w) => waehleFaktor(w, temp)).toList();

  // ── 3) Rückwärts-Mengen ──
  // Levain (letzte Phase) produziert recipeAmount + 20g Puffer.
  final levainF = factors[n];
  final levainTotal = recipeAmount + 20;
  final levainAsg = (levainTotal / (1 + 2 * levainF)).ceil().clamp(10, 9999);
  final levainWater = (levainAsg * levainF).round();
  final levainFlour = (levainAsg * levainF).round();
  final levainGesamt = levainAsg + levainWater + levainFlour;

  // Auffrischungen rückwärts: jede liefert ASG der Folgephase + 20g Kultur.
  final starter = List<int>.filled(n, 0);
  final water = List<int>.filled(n, 0);
  final flour = List<int>.filled(n, 0);
  var benoetigt = (levainAsg + 20).toDouble();
  for (var i = n - 1; i >= 0; i--) {
    final f = factors[i];
    final asg = (benoetigt / (1 + 2 * f)).ceil().clamp(5, 9999);
    starter[i] = asg;
    water[i] = (asg * f).round();
    flour[i] = (asg * f).round();
    benoetigt = (asg + 20).toDouble();
  }

  // ── 4) Einträge bauen ──
  final refreshes = <_RefreshEntry>[];
  for (var i = 0; i < n; i++) {
    final f = factors[i];
    final peak = feeds[i]
        .add(Duration(minutes: (timeFromFactor(f, temp) * 60).round()));
    refreshes.add(_RefreshEntry(
      step: i + 1,
      time: feeds[i],
      starter: starter[i],
      water: water[i],
      flour: flour[i],
      total: starter[i] + water[i] + flour[i],
      faktor: f,
      wasserTempC: wasserTemperatur(temp, zielTemp: zielTeigTemp(windows[i])),
      peakTime: peak,
    ));
  }

  final levainPeak = feeds[n]
      .add(Duration(minutes: (timeFromFactor(levainF, temp) * 60).round()));
  final levain = _RefreshEntry(
    step: n + 1,
    time: feeds[n],
    starter: levainAsg,
    water: levainWater,
    flour: levainFlour,
    total: levainGesamt,
    faktor: levainF,
    wasserTempC: wasserTemperatur(temp, zielTemp: zielTeigTemp(windows[n])),
    peakTime: levainPeak,
  );

  return _RefreshPlan(
    refreshes: refreshes,
    levain: levain,
    keptFromLevain: (levainGesamt - recipeAmount).clamp(0, levainGesamt),
  );
}

// ═══════════════════════════════════════════════════════════════
//  AUFFRISCHUNGSPLAN — Inline-Widget
// ═══════════════════════════════════════════════════════════════

class _InlineRefreshPlan extends StatelessWidget {
  final PlanerResult result;
  final int refreshCount;
  final double temp;
  final DateTime bakingTime;
  final DateTime? earliestStart;
  final Map<int, DateTime> customRefreshTimes;
  final Function(int, DateTime, List<_RefreshEntry>)? onEditRefreshTime;
  final Map<String, dynamic> Function(DateTime, DateTime)? onCalculatePossibleRatios;
  final int recipeAmount;
  final int starterAvailable;

  const _InlineRefreshPlan({
    required this.result,
    required this.refreshCount,
    required this.temp,
    required this.bakingTime,
    required this.recipeAmount,
    required this.starterAvailable,
    this.earliestStart,
    this.customRefreshTimes = const {},
    this.onEditRefreshTime,
    this.onCalculatePossibleRatios,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final n = refreshCount;
    final fmt = DateFormat('E dd.MM. HH:mm');
    final fmtShort = DateFormat('HH:mm');
    final tR = timeFromFactor(1.0, temp);
    final plan = _buildRefreshPlan(r, n, temp, bakingTime,
        recipeAmount: recipeAmount, customTimes: customRefreshTimes, earliestStart: earliestStart);
    final entries = plan.refreshes;
    final first = entries.first;

    final now = DateTime.now();
    final refPoint = earliestStart ?? now;

    // Nutze die gleiche Prüfung wie in _scheduleNotifications
    final isPast = _isRefreshPlanPast(plan, earliestStart);

    // Levain-Daten aus dem konsistenten Plan
    final lev = plan.levain;
    final levainFeedTime   = lev.time;
    final levainFaktor     = lev.faktor;
    final levainTimeNeeded = timeFromFactor(levainFaktor, temp);
    final levainPeakTime   = lev.peakTime;
    final levainAsg        = lev.starter;
    final levainWater      = lev.water;
    final levainFlour      = lev.flour;
    final levainWasserTemp = lev.wasserTempC;
    final isLevainCustom   = customRefreshTimes[n] != null;

    // Früheste Backzeit: frühester Start + (n+1) × 1:1:1-Zeit
    final earliestBake = refPoint.add(Duration(minutes: (((n + 1) * tR) * 60).round()));

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '🔄 Auffrischungsplan — $n× auffrischen',
          style: const TextStyle(
              color: AppColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Fehlermeldung wenn Auffrischplan nicht realisierbar
        if (isPast) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('❌ Nicht möglich — zu wenig Zeit',
                  style: TextStyle(
                      color: AppColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '$n× Auffrischen + letzte Fütterung = ${n + 1}× ~${formatH(tR)} '
                '= ~${formatH((n + 1) * tR)} gesamt.\n\n'
                '${earliestStart != null ? 'Ab frühestem Start ${DateFormat('E dd.MM. HH:mm').format(earliestStart!)} Uhr — ' : ''}'
                'Frühester Beginn Rezept:\n'
                '🕐 ${DateFormat('EEEE, dd.MM. – HH:mm \'Uhr\'').format(earliestBake)}',
                style: const TextStyle(color: AppColors.text2, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 10),
              const Text(
                'Optionen:\n'
                '• Backzeit nach hinten verschieben\n'
                '• Weniger Auffrischungen wählen',
                style: TextStyle(color: AppColors.text3, fontSize: 11, height: 1.6),
              ),
            ]),
          ),
        ],

        // Auffrischplan nur zeigen wenn realisierbar
        if (!isPast) ...[

        // Starte-mit-Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📋 Dein Auffrischungsplan:',
                style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '▸ Starte am ${fmt.format(customRefreshTimes[0] ?? first.time)} Uhr',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (onEditRefreshTime != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: () => onEditRefreshTime!(0, customRefreshTimes[0] ?? first.time, entries),
                    color: AppColors.text3,
                    padding: const EdgeInsets.all(0),
                    constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                  ),
              ],
            ),
            Text(
              '  mit ${first.starter}g Anstellgut + ${first.water}g Wasser (🌡️ ${first.wasserTempC}°C) + ${first.flour}g Mehl → ${first.total}g gesamt (${ratioText(first.faktor)})',
              style: const TextStyle(color: AppColors.text2, fontSize: 12),
            ),
            if (first.starter > starterAvailable) ...[
              const SizedBox(height: 4),
              Text(
                '⚠️ Du brauchst ${first.starter}g Anstellgut, hast aber nur ${starterAvailable}g. Mehr Auffrischungen oder längere Abstände wählen.',
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '▸ Letzte Fütterung (Levain): ${fmt.format(levainFeedTime)} Uhr${isLevainCustom ? ' ✏️' : ''}\n'
                    '  ${levainAsg}g Anstellgut + ${levainWater}g Wasser (🌡️ ${levainWasserTemp}°C) + ${levainFlour}g Mehl → ${levainAsg + levainWater + levainFlour}g gesamt (${ratioText(levainFaktor)})\n'
                    '▸ 🎯 Peak = Backzeit: ${fmt.format(bakingTime)} Uhr',
                    style: const TextStyle(
                        color: AppColors.text2, fontSize: 12, height: 1.5),
                  ),
                ),
                if (onEditRefreshTime != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: () => onEditRefreshTime!(n, levainFeedTime, entries),
                    color: AppColors.text3,
                    padding: const EdgeInsets.all(0),
                    constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                  ),
              ],
            ),
          ]),
        ),

        const SizedBox(height: 12),

        const Text('Detaillierter Zeitplan:',
            style: TextStyle(
                color: AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          '💡 Wähle Datum & Uhrzeit frei. Bei ${temp.toStringAsFixed(1)}°C: Mindestens ${formatH(tR)} Abstand für 1:1:1\n'
          'Das System schlägt das beste Verhältnis vor.',
          style: const TextStyle(
              color: AppColors.text3,
              fontSize: 11,
              height: 1.4),
        ),
        const SizedBox(height: 8),

        ...entries.asMap().entries.map((mapE) {
              final idx = mapE.key;
              final e = mapE.value;
              final isLast = idx == entries.length - 1;
              final customTime = customRefreshTimes[idx];
              final displayTime = customTime ?? e.time;
              final isCustom = customTime != null;
              final entryIsPast = displayTime.isBefore(now.subtract(_pastTolerance));
              final forNextStep = e.total - 20;
              final nextLabel = isLast
                  ? '→ ${levainAsg}g für Levain-Fütterung, 20g als Kultur aufheben'
                  : '→ ${forNextStep}g für nächstes Auffrischen, 20g als Kultur aufheben';

              // Verhältnis + Peak kommen direkt aus der Phase (Bucket-Modell)
              final ratioTimeNeeded = timeFromFactor(e.faktor, temp);
              final peakTime = displayTime.add(Duration(minutes: (ratioTimeNeeded * 60).round()));

              // Warnung: Abstand zum nächsten Schritt zu kurz?
              String? warningText;
              bool hasWarning = false;
              if (onCalculatePossibleRatios != null) {
                final nextTime = isLast ? levainFeedTime : (customRefreshTimes[idx + 1] ?? entries[idx + 1].time);
                final ratios = onCalculatePossibleRatios!(displayTime, nextTime);
                if (!(ratios['isPossible'] as bool)) {
                  hasWarning = true;
                  final minNeeded = ratios['minTimeNeeded'] as double;
                  warningText = '⚠️ Zu kurz bis ${isLast ? 'Levain-Fütterung' : 'nächster Schritt'}! Mindestens ${formatH(minNeeded)} nötig.';
                }
              }

              final lines = [
                '${e.starter}g Anstellgut + ${e.water}g Wasser (🌡️ ${e.wasserTempC}°C) + ${e.flour}g Mehl = ${e.total}g  (${ratioText(e.faktor)})',
                nextLabel,
                '⏱️ Peak nach ~${formatH(ratioTimeNeeded)} → ${fmtShort.format(peakTime)} Uhr',
                if (warningText != null) warningText,
              ];

              return _EditableTimelineRow(
                icon: hasWarning ? '❌' : (entryIsPast ? '⚠️' : '🌱'),
                color: hasWarning ? AppColors.red : (entryIsPast ? AppColors.red : (isCustom ? AppColors.blue : AppColors.text2)),
                bgColor: hasWarning
                    ? AppColors.red.withValues(alpha: 0.08)
                    : (entryIsPast
                        ? AppColors.red.withValues(alpha: 0.08)
                        : (isCustom ? AppColors.blue.withValues(alpha: 0.08) : AppColors.surface2.withValues(alpha: 0.5))),
                borderColor: hasWarning
                    ? AppColors.red.withValues(alpha: 0.5)
                    : (entryIsPast ? AppColors.red.withValues(alpha: 0.4) : (isCustom ? AppColors.blue.withValues(alpha: 0.5) : AppColors.border)),
                title: '${e.step}. Auffrischen — ${fmt.format(displayTime)} Uhr'
                    '${entryIsPast ? ' (Vergangenheit!)' : ''}${isCustom ? ' ✏️' : ''}',
                lines: lines,
                onTap: onEditRefreshTime != null
                    ? () => onEditRefreshTime!(idx, displayTime, entries)
                    : null,
                isEditable: onEditRefreshTime != null,
              );
            }),

        // Levain-Warnung prüfen
        Builder(
          builder: (context) {
            // Prüfe Abstand zwischen Levain und Backzeit
            String? levainWarning;
            Color levainColor = isLevainCustom ? AppColors.blue : AppColors.gold;
            Color levainBgColor = isLevainCustom ? AppColors.blue.withValues(alpha: 0.08) : const Color(0xFF2A1E08);
            Color levainBorderColor = isLevainCustom ? AppColors.blue.withValues(alpha: 0.5) : AppColors.goldDim;

            if (onCalculatePossibleRatios != null) {
              final ratios = onCalculatePossibleRatios!(levainFeedTime, bakingTime);
              if (!(ratios['isPossible'] as bool)) {
                levainWarning = '⚠️ Zu kurz bis zur Backzeit! Mindestens ${formatH(ratios['minTimeNeeded'] as double)} nötig.';
                levainColor = AppColors.red;
                levainBgColor = AppColors.red.withValues(alpha: 0.08);
                levainBorderColor = AppColors.red.withValues(alpha: 0.5);
              }
            }

            final levainLines = [
              '${levainAsg}g Anstellgut + ${levainWater}g Wasser (🌡️ ${levainWasserTemp}°C) + ${levainFlour}g Mehl = ${levainAsg + levainWater + levainFlour}g  (${ratioText(levainFaktor)})',
              '→ ${recipeAmount}g fürs Rezept, ${levainAsg + levainWater + levainFlour - recipeAmount}g als neues Anstellgut aufheben',
              '⏱️ Peak nach ~${formatH(levainTimeNeeded)} → ${fmtShort.format(levainPeakTime)} Uhr',
              if (levainWarning != null) levainWarning,
            ];

            return _EditableTimelineRow(
              icon: '🍞',
              color: levainColor,
              bgColor: levainBgColor,
              borderColor: levainBorderColor,
              title: 'Letzte Fütterung (Levain) — ${fmt.format(levainFeedTime)} Uhr${isLevainCustom ? ' ✏️' : ''}',
              lines: levainLines,
              onTap: onEditRefreshTime != null ? () => onEditRefreshTime!(n, levainFeedTime, entries) : null,
              isEditable: onEditRefreshTime != null,
            );
          },
        ),

        _TimelineRow(
          icon: '🎯',
          color: AppColors.green,
          bgColor: const Color(0xFF1A2010),
          borderColor: AppColors.green.withValues(alpha: 0.5),
          title: 'Backzeit — ${fmt.format(bakingTime)} Uhr',
          lines: [
            '${recipeAmount}g Starter in den Teig geben',
            'Schwimmtest: kleines Stück in Wasser — schwimmt es? Perfekt!',
          ],
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () => _exportRefreshICS(context, entries, lev, r, bakingTime),
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Als Kalender-Termine exportieren (.ics)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blue,
            side: const BorderSide(color: AppColors.blue),
            minimumSize: const Size(double.infinity, 40),
          ),
        ),

        ], // end if (!isPast)
      ]),
    );
  }

  Future<void> _exportRefreshICS(BuildContext context, List<_RefreshEntry> entries,
      _RefreshEntry levain, PlanerResult r, DateTime bakingTime) async {
    final fmt = DateFormat('HH:mm dd.MM.');

    final allEvents = <_ICSEvent>[
      ...entries.map((e) => _ICSEvent(
            uid: e.step,
            summary: '🌱 ${e.step}. Auffrischen (Refresh)',
            desc: 'Verhältnis: ${ratioText(e.faktor)}\n'
                'Anstellgut: ${e.starter}g + Wasser: ${e.water}g (${e.wasserTempC}°C) + Mehl: ${e.flour}g = ${e.total}g\n'
                '→ 20g als Kultur behalten, Peak um ${DateFormat("HH:mm").format(e.peakTime)} Uhr',
            start: e.time,
            end: e.time.add(const Duration(minutes: 10)),
            timeLabel: fmt.format(e.time),
          )),
      _ICSEvent(
        uid: entries.length + 1,
        summary: '🍞 Letzte Fütterung (Levain)',
        desc: 'Verhältnis: ${ratioText(levain.faktor)}\n'
            'Anstellgut: ${levain.starter}g + Wasser: ${levain.water}g (${levain.wasserTempC}°C) + Mehl: ${levain.flour}g = ${levain.total}g\n'
            '→ ${recipeAmount}g fürs Rezept\nPeak um ${DateFormat("HH:mm").format(levain.peakTime)} Uhr',
        start: levain.time,
        end: levain.time.add(const Duration(minutes: 10)),
        timeLabel: fmt.format(levain.time),
      ),
      _ICSEvent(
        uid: entries.length + 2,
        summary: '🎯 Backen — Starter bereit!',
        desc: '${recipeAmount}g Starter in den Teig geben.\nSchwimmtest machen!',
        start: bakingTime,
        end: bakingTime.add(const Duration(hours: 3)),
        timeLabel: fmt.format(bakingTime),
      ),
    ];

    final selected = List<bool>.filled(allEvents.length, true);
    final toExport = await showDialog<List<_ICSEvent>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('📅 Kalender-Export',
              style: TextStyle(color: AppColors.gold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Welche Termine exportieren?',
                  style: TextStyle(color: AppColors.text2, fontSize: 13)),
              const SizedBox(height: 8),
              ...List.generate(allEvents.length, (i) => CheckboxListTile(
                    value: selected[i],
                    onChanged: (v) => setLocal(() => selected[i] = v ?? false),
                    activeColor: AppColors.green,
                    title: Text(allEvents[i].summary,
                        style: const TextStyle(color: AppColors.text, fontSize: 13)),
                    subtitle: Text(allEvents[i].timeLabel,
                        style: const TextStyle(color: AppColors.text3, fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.text2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
              onPressed: () => Navigator.pop(ctx, [
                for (var i = 0; i < allEvents.length; i++)
                  if (selected[i]) allEvents[i]
              ]),
              child: const Text('Exportieren'),
            ),
          ],
        );
      }),
    );

    if (toExport == null || toExport.isEmpty) return;

    String icsDate(DateTime d) =>
        d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d{3}'), '');

    final uid = r.dFeed.millisecondsSinceEpoch;
    final ics = StringBuffer()
      ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Sauerteig Planer//DE\r\n');
    for (final e in toExport) {
      ics.write(
        'BEGIN:VEVENT\r\n'
        'UID:auffrischen-$uid-${e.uid}@sauerteig-planer\r\n'
        'DTSTART:${icsDate(e.start)}\r\n'
        'DTEND:${icsDate(e.end)}\r\n'
        'SUMMARY:${e.summary}\r\n'
        'DESCRIPTION:${e.desc.replaceAll('\n', '\\n')}\r\n'
        'BEGIN:VALARM\r\nTRIGGER:-PT0M\r\nACTION:DISPLAY\r\nDESCRIPTION:${e.summary}\r\nEND:VALARM\r\n'
        'END:VEVENT\r\n',
      );
    }
    ics.write('END:VCALENDAR\r\n');

    FeedbackService.log('Auffrischen ICS-Export: ${toExport.length} Termine');
    try {
      if (kIsWeb) {
        final bytes = Uint8List.fromList(ics.toString().codeUnits);
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: 'Auffrischungsplan.ics', mimeType: 'text/calendar')],
          text: 'Auffrischungsplan',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/Auffrischungsplan.ics');
        await file.writeAsString(ics.toString());
        await OpenFilex.open(file.path, type: 'text/calendar');
      }
    } catch (e) {
      FeedbackService.log('Auffrischen ICS Fehler: $e');
    }
  }
}

// ── Wiederverwendbare Timeline-Zeile ─────────────────────────────
class _TimelineRow extends StatelessWidget {
  final String icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final List<String> lines;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 4),
          ...lines.map((l) => Text(l,
              style: const TextStyle(
                  color: AppColors.text2, fontSize: 11, height: 1.4))),
        ]),
      );
}

// ── Bearbeitbare Timeline-Zeile (mit Click-Handler) ─────────────────────────────
class _EditableTimelineRow extends StatelessWidget {
  final String icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final List<String> lines;
  final VoidCallback? onTap;
  final bool isEditable;

  const _EditableTimelineRow({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.lines,
    this.onTap,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isEditable ? onTap : null,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
          if (isEditable)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.edit, size: 14, color: AppColors.blue),
            ),
        ]),
        const SizedBox(height: 4),
        ...lines.map((l) => Text(l,
            style: const TextStyle(
                color: AppColors.text2, fontSize: 11, height: 1.4))),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  ICS Event Modell
// ═══════════════════════════════════════════════════════════════
class _ICSEvent {
  final int uid;
  final String summary;
  final String desc;
  final DateTime start;
  final DateTime end;
  final String timeLabel;

  const _ICSEvent({
    required this.uid,
    required this.summary,
    required this.desc,
    required this.start,
    required this.end,
    required this.timeLabel,
  });
}

// ═══════════════════════════════════════════════════════════════
//  Gespeicherte Pläne — Bottom Sheet
// ═══════════════════════════════════════════════════════════════
class _SavedPlansSheet extends StatefulWidget {
  final List<SavedPlan> plans;
  final Future<void> Function(String id) onDelete;
  final void Function(SavedPlan plan) onLoad;

  const _SavedPlansSheet({
    required this.plans,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  State<_SavedPlansSheet> createState() => _SavedPlansSheetState();
}

class _SavedPlansSheetState extends State<_SavedPlansSheet> {
  late List<SavedPlan> _plans;

  @override
  void initState() {
    super.initState();
    _plans = List.from(widget.plans);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yy HH:mm');
    final fmtTime = DateFormat('HH:mm');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text(
                '💾 Gespeicherte Pläne',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_plans.length} Plan${_plans.length != 1 ? "e" : ""}',
                style:
                    const TextStyle(color: AppColors.text3, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          if (_plans.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Noch keine Pläne gespeichert.',
                    style: TextStyle(color: AppColors.text3)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _plans.length,
                itemBuilder: (_, i) {
                  final p = _plans[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: InkWell(
                      onTap: () => widget.onLoad(p),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.ratio} · ${p.temp.toInt()}°C · ${p.gesamt}g',
                                  style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '🍞 Backen: ${fmtTime.format(p.bakingTime)} · '
                                  '🌱 Füttern: ${fmtTime.format(p.dFeed)}',
                                  style: const TextStyle(
                                      color: AppColors.green, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gespeichert: ${fmt.format(p.savedAt)}',
                                  style: const TextStyle(
                                      color: AppColors.text3,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red, size: 20),
                            onPressed: () async {
                              await widget.onDelete(p.id);
                              setState(() =>
                                  _plans.removeWhere((x) => x.id == p.id));
                            },
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SmallChip(this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: const TextStyle(color: AppColors.text2, fontSize: 11)),
      ),
    );
  }
}
