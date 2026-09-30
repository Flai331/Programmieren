// ═══════════════════════════════════════════════════════════════
//  HEFE / SAUERTEIG RECHNER
//  lib/planer/hefe_rechner_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import 'planer_calculations.dart';

class HefeRechnerScreen extends StatefulWidget {
  const HefeRechnerScreen({super.key});

  @override
  State<HefeRechnerScreen> createState() => _HefeRechnerScreenState();
}

class _HefeRechnerScreenState extends State<HefeRechnerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Hefe → Sauerteig ─────────────────────────────────────
  final _hefeCtrl   = TextEditingController(text: '10');
  bool _hFrisch     = true;
  _H2SResult? _h2s;

  // ── Sauerteig → Hefe ─────────────────────────────────────
  final _starterCtrl = TextEditingController(text: '100');
  _S2HResult? _s2h;

  // ── Zeitplanung (geteilt zwischen beiden Tabs) ────────────
  final _garzeitCtrl    = TextEditingController();   // Stunden (Hefe-Rezept)
  final _backzeitDurCtrl = TextEditingController();  // Minuten Backzeit
  final _gaertempCtrl   = TextEditingController(text: '22'); // Gärtemperatur °C
  DateTime? _wannBacken;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _hefeCtrl.dispose();
    _starterCtrl.dispose();
    _garzeitCtrl.dispose();
    _backzeitDurCtrl.dispose();
    _gaertempCtrl.dispose();
    super.dispose();
  }

  void _calcH2S() {
    final hefe = double.tryParse(_hefeCtrl.text) ?? 0;
    if (hefe <= 0) return;

    final frischEq = _hFrisch ? hefe : hefe * 3;

    // Zeitplanung (optional)
    final garzeit   = double.tryParse(_garzeitCtrl.text);
    final backDur   = double.tryParse(_backzeitDurCtrl.text);
    final gaertemp  = double.tryParse(_gaertempCtrl.text) ?? 22.0;

    // ─── Starter-Menge berechnen ───
    // Wenn Garzeit eingegeben: dynamisch, damit Sauerteig GLEICHE Gärzeit hat wie Hefe
    // Sonst: klassische 1:20 Formel
    double starter;
    bool dynamisch = false;
    if (garzeit != null && garzeit > 0) {
      // Annahme: 1g Frischhefe pro 100g Mehl (Standardverhältnis)
      // Standard-Sauerteig: 20% Starter, 8h Gärzeit bei 22°C
      // Prinzip: starter_prozent × garzeit ≈ konstant (bei gleicher Temp)
      // Temperaturkompensation: wärmer = schneller
      final mehlGeschaetzt = frischEq * 100;
      final tempFaktor = pow(2.0, (22.0 - gaertemp) / 8.0).toDouble();
      final effStandardZeit = 8.0 * tempFaktor; // Standard-Zeit bei aktueller Temp
      final verhaeltnis = effStandardZeit / garzeit;
      final starterProzent = (0.20 * verhaeltnis).clamp(0.05, 1.50).toDouble();
      starter = mehlGeschaetzt * starterProzent;
      dynamisch = true;
      FeedbackService.log(
        'HefeRechner H2S: ${garzeit}h@${gaertemp}°C → '
        '${(starterProzent * 100).toStringAsFixed(1)}% Starter = ${starter.round()}g '
        '(Mehl gesch.: ${mehlGeschaetzt.round()}g)',
      );
    } else {
      // Klassische 1:20 Regel (keine Garzeit angegeben)
      starter = frischEq * 20;
    }

    final abzugMehl   = starter / 2;
    final abzugWasser = starter / 2;

    _TimingResult? timing;
    if (garzeit != null && garzeit > 0) {
      timing = _calcTiming(
        hefeGarzeitH: garzeit,
        backzeitDurMin: backDur,
        gaertemp: gaertemp,
        wannBacken: _wannBacken,
        gleicheZeit: dynamisch,
      );
    }

    setState(() {
      _h2s = _H2SResult(
        hefe: hefe,
        frischEq: frischEq,
        starter: starter.round(),
        abzugMehl: abzugMehl.round(),
        abzugWasser: abzugWasser.round(),
        timing: timing,
        dynamisch: dynamisch,
      );
    });
    FeedbackService.log('HefeRechner: ${hefe}g ${_hFrisch ? 'Frischhefe' : 'Trockenhefe'} → ${starter.round()}g Starter${dynamisch ? ' (dynamisch für ${garzeit}h)' : ''}');
  }

  void _calcS2H() {
    final starter = double.tryParse(_starterCtrl.text) ?? 0;
    if (starter <= 0) return;

    // Zeitplanung (optional)
    final garzeit   = double.tryParse(_garzeitCtrl.text);
    final backDur   = double.tryParse(_backzeitDurCtrl.text);
    final gaertemp  = double.tryParse(_gaertempCtrl.text) ?? 22.0;

    // ─── Hefe-Menge berechnen ───
    // Wenn Garzeit eingegeben: dynamisch, damit Hefe-Teig GLEICHE Gärzeit hat wie Sauerteig-Teig
    // Sonst: klassische 1:20 Umkehrung
    double frisch;
    bool dynamisch = false;
    if (garzeit != null && garzeit > 0) {
      // Umkehrung: aus Starter-Menge und gewünschter Garzeit Mehlmenge rekonstruieren
      // Danach 1% Frischhefe/Mehl (Standard für Hefe-Gärung)
      final tempFaktor = pow(2.0, (22.0 - gaertemp) / 8.0).toDouble();
      final effStandardZeit = 8.0 * tempFaktor;
      final verhaeltnis = effStandardZeit / garzeit;
      final starterProzent = (0.20 * verhaeltnis).clamp(0.05, 1.50).toDouble();
      final mehlGeschaetzt = starter / starterProzent;
      frisch = mehlGeschaetzt * 0.01; // 1% Frischhefe vom Mehl
      dynamisch = true;
      FeedbackService.log(
        'HefeRechner S2H: ${garzeit}h@${gaertemp}°C → '
        '${(starterProzent * 100).toStringAsFixed(1)}% Starter, Mehl gesch.: ${mehlGeschaetzt.round()}g → ${frisch.toStringAsFixed(2)}g Frischhefe',
      );
    } else {
      // Klassische 1:20 Umkehrung
      frisch = starter / 20;
    }
    final trocken = frisch / 3;
    final zusatzMehl   = starter / 2;
    final zusatzWasser = starter / 2;

    _TimingResult? timing;
    if (garzeit != null && garzeit > 0) {
      timing = _calcTiming(
        hefeGarzeitH: garzeit,
        backzeitDurMin: backDur,
        gaertemp: gaertemp,
        wannBacken: _wannBacken,
        gleicheZeit: dynamisch,
      );
    }

    setState(() {
      _s2h = _S2HResult(
        starter: starter.round(),
        frisch: frisch,
        trocken: trocken,
        zusatzMehl: zusatzMehl.round(),
        zusatzWasser: zusatzWasser.round(),
        timing: timing,
        dynamisch: dynamisch,
      );
    });
    FeedbackService.log('HefeRechner: ${starter.round()}g Starter → ${frisch.toStringAsFixed(1)}g Frischhefe${dynamisch ? ' (dynamisch für ${garzeit}h)' : ''}');
  }

  /// Berechnet Hefe- und Sauerteig-Zeitplanung
  /// [gleicheZeit] = true: Die Starter-Menge wurde so angepasst, dass die
  /// Sauerteig-Garzeit GLEICH der Hefe-Garzeit ist (dynamische Berechnung).
  _TimingResult _calcTiming({
    required double hefeGarzeitH,
    required double? backzeitDurMin,
    required double gaertemp,
    required DateTime? wannBacken,
    bool gleicheZeit = false,
  }) {
    final double stGarzeit;
    final double stMin;
    final double stMax;
    if (gleicheZeit) {
      // Dynamische Berechnung: Menge so angepasst, dass Sauerteig gleich Hefe
      stGarzeit = hefeGarzeitH;
      stMin     = hefeGarzeitH * 0.9;
      stMax     = hefeGarzeitH * 1.15;
    } else {
      // Standard: Sauerteig ≈ 3× länger als Hefe, temperaturabhängig
      final stBase = hefeGarzeitH * 3.0;
      stGarzeit    = stBase * pow(2.0, (22.0 - gaertemp) / 8.0).toDouble();
      stMin        = stGarzeit * 0.7;
      stMax        = stGarzeit * 1.3;
    }

    // Zeitstempel wenn Backzeitpunkt bekannt
    final backDurH = (backzeitDurMin ?? 0) / 60.0;
    DateTime? hefeMixTime;
    DateTime? stMixTime;
    if (wannBacken != null) {
      hefeMixTime = wannBacken.subtract(
        Duration(minutes: (hefeGarzeitH * 60 + (backzeitDurMin ?? 0)).round()),
      );
      stMixTime = wannBacken.subtract(
        Duration(minutes: (stGarzeit * 60 + (backzeitDurMin ?? 0)).round()),
      );
    }

    return _TimingResult(
      hefeGarzeitH: hefeGarzeitH,
      sauerteigGarzeitH: stGarzeit,
      sauerteigGarzeitMinH: stMin,
      sauerteigGarzeitMaxH: stMax,
      gaertemp: gaertemp,
      backzeitDurH: backDurH,
      wannBacken: wannBacken,
      hefeMixTime: hefeMixTime,
      sauerteigMixTime: stMixTime,
      gleicheZeit: gleicheZeit,
    );
  }

  Future<void> _pickBackzeit() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _wannBacken ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _wannBacken != null
          ? TimeOfDay.fromDateTime(_wannBacken!)
          : const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _wannBacken = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: const BackButton(color: AppColors.text2),
        title: const Text('🧮 Hefe / Sauerteig Rechner',
            style: TextStyle(color: AppColors.gold, fontSize: 16)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text3,
          tabs: const [
            Tab(text: 'Hefe → Sauerteig'),
            Tab(text: 'Sauerteig → Hefe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildH2S(), _buildS2H()],
      ),
    );
  }

  // ── Tab 1: Hefe → Sauerteig ──────────────────────────────
  Widget _buildH2S() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _InfoBox(
          'Gib an, wie viel Hefe dein Rezept verlangt – du bekommst die '
          'äquivalente Menge Sauerteig-Starter.',
        ),
        const SizedBox(height: 20),

        // Mengen-Eingabe
        _Card(child: Column(children: [
          Row(children: [
            const Expanded(
              child: Text('Menge', style: TextStyle(color: AppColors.text2, fontSize: 13)),
            ),
            _NumField(ctrl: _hefeCtrl, unit: 'g'),
            const SizedBox(width: 12),
            _Toggle(
              options: const ['Frisch', 'Trocken'],
              selected: _hFrisch ? 0 : 1,
              onChanged: (i) => setState(() => _hFrisch = i == 0),
            ),
          ]),
        ])),
        const SizedBox(height: 12),

        // Optionale Zeitplanung
        _buildZeitplanungCard(),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _calcH2S,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Berechnen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),

        if (_h2s != null) ...[
          const SizedBox(height: 20),
          _ResultCard(children: [
            _Row(emoji: '🌾', label: 'Sauerteig-Starter verwenden',
                value: '${_h2s!.starter} g', big: true),
            if (_h2s!.dynamisch) ...[
              const SizedBox(height: 6),
              const _HintText(
                '✨ Menge dynamisch berechnet – damit der Sauerteig-Teig '
                'die GLEICHE Gärzeit hat wie das Hefe-Rezept.',
              ),
            ],
            const SizedBox(height: 16),
            const _Divider(),
            const SizedBox(height: 12),
            const Text('Rezept anpassen:',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            const SizedBox(height: 8),
            _Row(emoji: '🍞', label: 'Mehl reduzieren um', value: '${_h2s!.abzugMehl} g'),
            const SizedBox(height: 6),
            _Row(emoji: '💧', label: 'Wasser reduzieren um', value: '${_h2s!.abzugWasser} g'),
            const SizedBox(height: 12),
            const _HintText(
              'Der Starter enthält selbst Mehl und Wasser (je 50%). '
              'Damit die Hydration gleich bleibt, diese Mengen vom Rezept abziehen.',
            ),
            if (_h2s!.timing != null) ...[
              const SizedBox(height: 16),
              const _Divider(),
              const SizedBox(height: 12),
              _buildTimingResult(_h2s!.timing!, isH2S: true),
            ] else ...[
              const SizedBox(height: 12),
              const _Divider(),
              const SizedBox(height: 12),
              const _HintText(
                '⏱️ Gehzeit: 4–8 h bei Raumtemperatur (statt 1–2 h mit Hefe). '
                'Gib oben Garzeit + Temperatur ein für eine genaue Schätzung.',
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  // ── Tab 2: Sauerteig → Hefe ──────────────────────────────
  Widget _buildS2H() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _InfoBox(
          'Gib an, wie viel Sauerteig-Starter dein Rezept verwendet – du bekommst '
          'die äquivalente Hefe-Menge.',
        ),
        const SizedBox(height: 20),

        // Starter-Eingabe
        _Card(child: Row(children: [
          const Expanded(
            child: Text('Starter-Menge', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          ),
          _NumField(ctrl: _starterCtrl, unit: 'g'),
        ])),
        const SizedBox(height: 12),

        // Optionale Zeitplanung
        _buildZeitplanungCard(),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _calcS2H,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Berechnen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),

        if (_s2h != null) ...[
          const SizedBox(height: 20),
          _ResultCard(children: [
            _Row(emoji: '🧫', label: 'Frischhefe', value: '${_s2h!.frisch.toStringAsFixed(1)} g', big: true),
            const SizedBox(height: 6),
            _Row(emoji: '🧫', label: 'Trockenhefe', value: '${_s2h!.trocken.toStringAsFixed(1)} g'),
            if (_s2h!.dynamisch) ...[
              const SizedBox(height: 6),
              const _HintText(
                '✨ Menge dynamisch berechnet – damit der Hefe-Teig '
                'die GLEICHE Gärzeit hat wie das Sauerteig-Rezept.',
              ),
            ],
            const SizedBox(height: 16),
            const _Divider(),
            const SizedBox(height: 12),
            const Text('Rezept anpassen:',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            const SizedBox(height: 8),
            _Row(emoji: '🍞', label: 'Mehl erhöhen um', value: '${_s2h!.zusatzMehl} g'),
            const SizedBox(height: 6),
            _Row(emoji: '💧', label: 'Wasser erhöhen um', value: '${_s2h!.zusatzWasser} g'),
            const SizedBox(height: 12),
            const _HintText(
              'Der Starter brachte Mehl und Wasser mit (je 50%). '
              'Diese Mengen müssen nun wieder ins Rezept eingefügt werden.',
            ),
            if (_s2h!.timing != null) ...[
              const SizedBox(height: 16),
              const _Divider(),
              const SizedBox(height: 12),
              _buildTimingResult(_s2h!.timing!, isH2S: false),
            ] else ...[
              const SizedBox(height: 12),
              const _Divider(),
              const SizedBox(height: 12),
              const _HintText(
                '⏱️ Gehzeit: 1–2 h bei Raumtemperatur (statt 4–8 h mit Sauerteig).',
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  // ── Zeitplanung-Eingabe-Karte ─────────────────────────────
  Widget _buildZeitplanungCard() {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('⏱️ Zeitplanung (optional)',
          style: TextStyle(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),

      // Garzeit + Gärtemperatur
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Garzeit (Rezept)', style: TextStyle(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 4),
            _NumField(ctrl: _garzeitCtrl, unit: 'h'),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gärtemperatur', style: TextStyle(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 4),
            _NumField(ctrl: _gaertempCtrl, unit: '°C'),
          ]),
        ),
      ]),
      const SizedBox(height: 12),

      // Backzeit-Dauer + Wann backen?
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Backzeit (Dauer)', style: TextStyle(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 4),
            _NumField(ctrl: _backzeitDurCtrl, unit: 'min'),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Wann backen?', style: TextStyle(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _pickBackzeit,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _wannBacken != null ? AppColors.gold : AppColors.border,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _wannBacken != null
                      ? _formatDt(_wannBacken!)
                      : 'Tippen …',
                  style: TextStyle(
                    color: _wannBacken != null ? AppColors.gold : AppColors.text3,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    ]));
  }

  // ── Ergebnis der Zeitplanung ─────────────────────────────
  Widget _buildTimingResult(_TimingResult t, {required bool isH2S}) {
    final stMin = t.sauerteigGarzeitMinH;
    final stMax = t.sauerteigGarzeitMaxH;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Zeitplanung:', style: TextStyle(color: AppColors.text3, fontSize: 12)),
      const SizedBox(height: 10),

      // Vergleichstabelle
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          _TimingRow(
            label: 'Garzeit mit Hefe',
            value: formatH(t.hefeGarzeitH),
            color: AppColors.text2,
          ),
          const Divider(color: AppColors.border, height: 1),
          _TimingRow(
            label: t.gleicheZeit
                ? 'Garzeit mit Sauerteig\n(gleich – durch angepasste Menge)'
                : 'Garzeit mit Sauerteig\nbei ${t.gaertemp.toStringAsFixed(0)}°C',
            value: t.gleicheZeit
                ? '≈ ${formatH(t.hefeGarzeitH)}'
                : '${formatH(stMin)} – ${formatH(stMax)}',
            color: t.gleicheZeit ? AppColors.green : AppColors.orange,
          ),
          if (t.backzeitDurH > 0) ...[
            const Divider(color: AppColors.border, height: 1),
            _TimingRow(
              label: 'Backzeit',
              value: '${(t.backzeitDurH * 60).round()} min',
              color: AppColors.text2,
            ),
          ],
        ]),
      ),

      if (t.wannBacken != null) ...[
        const SizedBox(height: 12),
        const Text('Teig ansetzen:', style: TextStyle(color: AppColors.text3, fontSize: 12)),
        const SizedBox(height: 8),
        if (t.gleicheZeit) ...[
          // Dynamische Berechnung: Beide Teige haben die gleiche Gärzeit
          _MixTimeRow(
            emoji: '🧫',
            label: 'Mit Hefe',
            time: t.hefeMixTime!,
            color: AppColors.blue,
          ),
          const SizedBox(height: 6),
          _MixTimeRow(
            emoji: '🌾',
            label: 'Mit Sauerteig (angepasste Menge)',
            time: t.sauerteigMixTime!,
            color: AppColors.green,
          ),
        ] else ...[
          _MixTimeRow(
            emoji: '🧫',
            label: 'Mit Hefe',
            time: t.hefeMixTime!,
            color: AppColors.blue,
          ),
          const SizedBox(height: 6),
          _MixTimeRow(
            emoji: '🌾',
            label: 'Mit Sauerteig (frühestens)',
            time: t.sauerteigMixTime!.subtract(
              Duration(minutes: ((t.sauerteigGarzeitMaxH - t.sauerteigGarzeitH) * 60).round()),
            ),
            color: AppColors.green,
          ),
          const SizedBox(height: 6),
          _MixTimeRow(
            emoji: '🌾',
            label: 'Mit Sauerteig (spätestens)',
            time: t.sauerteigMixTime!.add(
              Duration(minutes: ((t.sauerteigGarzeitH - t.sauerteigGarzeitMinH) * 60).round()),
            ),
            color: AppColors.orange,
          ),
        ],
      ],

      const SizedBox(height: 10),
      _HintText(
        t.gleicheZeit
            ? 'Die Starter-Menge ist so angepasst, dass beide Teige etwa '
              'zur gleichen Zeit fertig sind. Beobachte den Teig – Sauerteig '
              'kann bei Temperaturabweichungen schneller/langsamer reagieren.'
            : 'Sauerteig-Garzeit ≈ 3× länger als Hefe, temperaturabhängig. '
              'Die angegebene Spanne ist eine Schätzung – beobachte den Teig.',
      ),
    ]);
  }

  String _formatDt(DateTime dt) {
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final wd = weekdays[dt.weekday - 1];
    return '$wd ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}. '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Ergebnis-Datenklassen ────────────────────────────────────────

class _H2SResult {
  final double hefe;
  final double frischEq;
  final int starter;
  final int abzugMehl;
  final int abzugWasser;
  final _TimingResult? timing;
  final bool dynamisch;
  const _H2SResult({
    required this.hefe,
    required this.frischEq,
    required this.starter,
    required this.abzugMehl,
    required this.abzugWasser,
    this.timing,
    this.dynamisch = false,
  });
}

class _S2HResult {
  final int starter;
  final double frisch;
  final double trocken;
  final int zusatzMehl;
  final int zusatzWasser;
  final _TimingResult? timing;
  final bool dynamisch;
  const _S2HResult({
    required this.starter,
    required this.frisch,
    required this.trocken,
    required this.zusatzMehl,
    required this.zusatzWasser,
    this.timing,
    this.dynamisch = false,
  });
}

class _TimingResult {
  final double hefeGarzeitH;
  final double sauerteigGarzeitH;
  final double sauerteigGarzeitMinH;
  final double sauerteigGarzeitMaxH;
  final double gaertemp;
  final double backzeitDurH;
  final DateTime? wannBacken;
  final DateTime? hefeMixTime;
  final DateTime? sauerteigMixTime;
  final bool gleicheZeit;
  const _TimingResult({
    required this.hefeGarzeitH,
    required this.sauerteigGarzeitH,
    required this.sauerteigGarzeitMinH,
    required this.sauerteigGarzeitMaxH,
    required this.gaertemp,
    required this.backzeitDurH,
    required this.wannBacken,
    required this.hefeMixTime,
    required this.sauerteigMixTime,
    this.gleicheZeit = false,
  });
}

// ── UI-Hilfswidgets ──────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text,
            style: const TextStyle(color: AppColors.text2, fontSize: 12, height: 1.5)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _ResultCard extends StatelessWidget {
  final List<Widget> children;
  const _ResultCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String unit;
  const _NumField({required this.ctrl, required this.unit});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 90,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            suffixText: unit,
            suffixStyle: const TextStyle(color: AppColors.text3, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
        ),
      );
}

class _Toggle extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const _Toggle({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surface2,
                borderRadius: BorderRadius.horizontal(
                  left: i == 0 ? const Radius.circular(8) : Radius.zero,
                  right: i == options.length - 1 ? const Radius.circular(8) : Radius.zero,
                ),
                border: Border.all(color: active ? AppColors.gold : AppColors.border),
              ),
              child: Text(options[i],
                  style: TextStyle(
                    color: active ? AppColors.gold : AppColors.text3,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
          );
        }),
      );
}

class _Row extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final bool big;
  const _Row({required this.emoji, required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                color: big ? AppColors.text : AppColors.text2,
                fontSize: big ? 14 : 13,
                fontWeight: big ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
        Text(value,
            style: TextStyle(
              color: big ? AppColors.gold : AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: big ? 16 : 13,
            )),
      ]);
}

class _TimingRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TimingRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4)),
          ),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );
}

class _MixTimeRow extends StatelessWidget {
  final String emoji;
  final String label;
  final DateTime time;
  final Color color;
  const _MixTimeRow({
    required this.emoji,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final wd = weekdays[time.weekday - 1];
    final timeStr = '$wd '
        '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}. '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} Uhr';

    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
      ),
      Text(timeStr, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.border, height: 1);
}

class _HintText extends StatelessWidget {
  final String text;
  const _HintText(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.text3, fontSize: 11, height: 1.5));
}
