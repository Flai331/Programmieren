// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Haupt-Screen
//  lib/planer/planer_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'planer_calculations.dart';


// ── Benachrichtigungen global ──────────────────────────────────
final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

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
  double _hours = 12;
  int _selectedTimeIndex = 3; // "in 12h"

  PlanerResult? _result;

  // Zeit-Buttons
  final List<Map<String, dynamic>> _timeOptions = [
    {'label': 'in 4h',  'h': 4.0},
    {'label': 'in 6h',  'h': 6.0},
    {'label': 'in 8h',  'h': 8.0},
    {'label': 'in 12h', 'h': 12.0},
    {'label': 'in 16h', 'h': 16.0},
    {'label': 'in 24h', 'h': 24.0},
    {'label': 'in 36h', 'h': 36.0},
    {'label': 'individuell', 'h': 0.0},
  ];

  bool _showCustomTime = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await notifications.initialize(initSettings);
    }
  }

  // ── Berechnen ─────────────────────────────────────────────
  void _calculate() {
     FeedbackService.log("Berechnung gestartet: Temp $_temp°C, Zielzeit $_hours h");
    final hours = _hours;
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

    final rW = factor, rM = factor;
    final total = 1.0 + rW + rM; // = 1 + 2*factor

    // Mindest-Anstellgut für _amount, gedeckelt auf Vorrat
    final anstellgutNeeded = (_amount / total).ceil();
    final anstellgut = anstellgutNeeded.clamp(1, _starter.toInt());
    final wasser     = (anstellgut * rW).ceil();
    final mehl       = (anstellgut * rM).ceil();
    final gesamt     = anstellgut + wasser + mehl;
    // Mindestens 5g behalten damit der Starter sicher weitergeführt werden kann
    const minKeep    = 5;
    final forRecipeRaw = _amount.toInt().clamp(0, gesamt);
    final leftover   = (gesamt - forRecipeRaw).clamp(minKeep, gesamt);
    final forRecipe  = gesamt - leftover;


    final now   = DateTime.now();
    final dFeed = now;
    final dHalf = now.add(Duration(minutes: (estTime * 0.5 * 60).round()));
    final dPeak = now.add(Duration(minutes: (estTime * 60).round()));

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
        'Float-Test nach Verdopplung. Wenn positiv → normal weitermachen.',
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
      gesamt: gesamt, forRecipe: forRecipe, leftover: leftover,
      dFeed: dFeed, dHalf: dHalf, dPeak: dPeak,
      tempLabel: tempLabel, tempAdvice: tempAdvice, steps: steps,
    );

    if (anstellgut < anstellgutNeeded) {
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
    // Lösung B: Mindest-Faktor damit _starter für _amount reicht
    final fMin = (_amount / _starter - 1.0) / 2.0;
    final timeForAmount = timeFromFactor(fMin.clamp(0.5, 50.0), _temp);

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
        title: const Row(children: [
          Text('⚠️', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Flexible(child: Text('Zu wenig Anstellgut',
              style: TextStyle(color: AppColors.gold, fontSize: 17,
                  fontWeight: FontWeight.w600))),
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
                  'Verhältnis maximal ${result.gesamt}g Sauerteig herstellen — '
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
                title: 'Jetzt mit ${result.gesamt}g fortfahren',
                body: 'Reduziere das Rezept auf ${result.gesamt}g Sauerteig '
                    'oder passe die Zutaten entsprechend an.',
              ),
              const SizedBox(height: 8),

              // Lösung B: Längere Zeit wählen
              _SolutionTile(
                icon: '⏱️',
                title: 'Zeit verlängern auf ~${formatH(timeForAmount)}',
                body: 'Mit einem größeren Verhältnis (längere Gärzeit) reichen deine '
                    '${_starter.toInt()}g Anstellgut für ${_amount.toInt()}g. '
                    'Stelle die Zeit auf mindestens ${formatH(timeForAmount)} ein '
                    'und berechne neu.',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A1E08),
              foregroundColor: AppColors.gold2,
              side: const BorderSide(color: AppColors.goldDim),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _applyResult(result);
            },
            child: const Text('Trotzdem berechnen'),
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
    await notifications.cancelAll();

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

    Future<void> scheduleAt(int id, DateTime time, String title, String body) async {
      if (time.isAfter(now)) {
        await notifications.zonedSchedule(
          id, title, body,
          toTZ(time),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    await scheduleAt(1, r.dHalf,
      '🫧 Sauerteig prüfen',
      'Bläschen sichtbar? Noch ${formatH(r.estTime * 0.5)} bis zum Höhepunkt.');

    // 15 Min Vorwarnung vor Peak
    final preWarning = r.dPeak.subtract(const Duration(minutes: 15));
    await scheduleAt(2, preWarning,
      '⏰ Sauerteig fast fertig!',
      'In ~15 Minuten ist der Höhepunkt erreicht. Bereit machen!');

    await scheduleAt(3, r.dPeak,
      '🎯 HÖHEPUNKT — Sauerteig verwenden!',
      '${r.forRecipe}g abnehmen → in den Teig. Float-Test machen!');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 3 Erinnerungen gesetzt!'),
        backgroundColor: Color(0xFF1A3020),
      ),
    );
  }

  // ── ICS Export ────────────────────────────────────────────
  Future<void> _exportICS() async {
    final r = _result;
    if (r == null) return;

    String icsDate(DateTime d) =>
        d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d{3}'), '');

    String makeEvent(DateTime start, DateTime end, String summary, String desc) {
      return 'BEGIN:VEVENT\r\n'
          'UID:${DateTime.now().millisecondsSinceEpoch}@sauerteig\r\n'
          'DTSTART:${icsDate(start)}\r\n'
          'DTEND:${icsDate(end)}\r\n'
          'SUMMARY:$summary\r\n'
          'DESCRIPTION:${desc.replaceAll('\n', '\\n')}\r\n'
          'BEGIN:VALARM\r\nTRIGGER:-PT0M\r\nACTION:DISPLAY\r\nDESCRIPTION:$summary\r\nEND:VALARM\r\n'
          'END:VEVENT\r\n';
    }

    final ics = StringBuffer();
    ics.write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Sauerteig Planer//DE\r\n');
    ics.write(makeEvent(r.dFeed, r.dFeed.add(const Duration(minutes: 10)),
        '🍞 Sauerteig füttern',
        'Verhältnis ${r.ratio}\nAnstellgut: ${r.anstellgut}g\nWasser: ${r.wasser}g\nMehl: ${r.mehl}g'));
    ics.write(makeEvent(r.dHalf, r.dHalf.add(const Duration(minutes: 10)),
        '🫧 Erste Aktivität prüfen', 'Bläschen sichtbar?\nNoch ${formatH(r.estTime * 0.5)} bis Höhepunkt.'));
    ics.write(makeEvent(r.dPeak, r.dPeak.add(const Duration(minutes: 15)),
        '🎯 HÖHEPUNKT — jetzt verwenden!',
        '${r.forRecipe}g abnehmen → in den Teig\nFloat-Test machen!\n${r.leftover}g als neues Anstellgut.'));
    ics.write('END:VCALENDAR\r\n');

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
            _pdfBox('~${formatH(r.estTime)}', 'bis Peak', gold, ctx),
          ]),
          pw.SizedBox(height: 16),

          // Rezept
          _pdfSection('REZEPT', gold),
          _pdfRow('Anstellgut', '${r.anstellgut} g', dark),
          _pdfRow('Wasser', '${r.wasser} g', dark),
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
              '${r.forRecipe}g abnehmen → in den Teig. Float-Test!', gold),
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

                    // Zeit-Buttons
                    const _FieldLabel('Wann willst du backen?'),
                    GridView.count(
                      crossAxisCount: 4, shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 7, crossAxisSpacing: 7,
                      childAspectRatio: 2.2,
                      children: _timeOptions.asMap().entries.map((e) {
                        final i = e.key; final opt = e.value;
                        final active = i == _selectedTimeIndex;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedTimeIndex = i;
                            if (opt['h'] == 0.0) {
                              _showCustomTime = true;
                            } else {
                              _showCustomTime = false;
                              _hours = opt['h'];
                            }
                          }),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF2A2210) : AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active ? AppColors.gold : AppColors.border,
                              ),
                            ),
                            child: Text(opt['label'],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: active ? AppColors.gold : AppColors.text2,
                              )),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_showCustomTime) ...[
                      const SizedBox(height: 10),
                      _NumInput(
                        label: 'In wie vielen Stunden?',
                        unit: 'h',
                        value: _hours,
                        onChanged: (v) => setState(() => _hours = v),
                      ),
                    ],

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

                // ── ERGEBNIS ─────────────────────────────────
                if (_result != null) ...[
                  _ResultView(result: _result!, onExportICS: _exportICS, onExportPDF: _exportPDF),
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

  const _ResultView({required this.result, required this.onExportICS, required this.onExportPDF});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final fmt = DateFormat('HH:mm');
    final timeDiffStr = formatH(r.timeDiff);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── ZUSAMMENFASSUNG ──────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('📊 Zusammenfassung'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SummaryBox(value: '${r.temp.toInt()}°C', label: r.tempLabel, color: tempColor(r.temp))),
          const SizedBox(width: 8),
          Expanded(child: _SummaryBox(value: r.ratio, label: 'Verhältnis', color: AppColors.gold2)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryBox(value: '~${formatH(r.estTime)}', label: 'bis Peak', color: AppColors.text)),
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
        const SizedBox(height: 14),
        // Tabelle
        _RecipeTable(r: r),
      ])),

      const SizedBox(height: 12),

      // ── ZEITPLAN ─────────────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('🕐 Zeitplan'),
        const SizedBox(height: 14),
        _TimelineItem(
          time: '${fmt.format(r.dFeed)} — Jetzt',
          title: 'Füttern',
          desc: 'Anstellgut ${r.anstellgut}g + Wasser ${r.wasser}g + Mehl ${r.mehl}g verrühren. Höhe markieren.',
          isNow: true,
        ),
        _TimelineItem(
          time: '${fmt.format(r.dHalf)} (+${formatH(r.estTime * 0.5)})',
          title: 'Erste Aktivität',
          desc: 'Bläschen sichtbar, Starter beginnt zu wachsen.',
        ),
        _TimelineItem(
          time: '${fmt.format(r.dPeak)} (+${formatH(r.estTime)}) 🎯',
          title: 'Höhepunkt — jetzt verwenden!',
          desc: 'Verdoppelt. ${r.forRecipe}g abnehmen → in den Teig. Float-Test!',
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
          text: '🧪 Float-Test: 1 TL Starter ins Wasser — schwimmt er? → Bereit ✅   Sinkt er? → Noch warten.',
        ),
      ])),

      const SizedBox(height: 12),

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

      // ── EXPORT ───────────────────────────────────────────
      Row(children: [
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

class _NumInput extends StatelessWidget {
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      TextFormField(
        initialValue: value.toInt().toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: AppColors.text),
        decoration: InputDecoration(
          suffixText: unit,
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
            onChanged(parsed);
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
      _tableRow('Wasser', '${r.wasser} g',
          r.temp >= 35 ? '❄️ eiskaltes Wasser' : r.temp >= 28 ? 'kühles Wasser' : 'Raumtemperatur'),
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
  final bool isNow, isHighlight;
  const _TimelineItem({required this.time, required this.title, required this.desc,
    this.isNow = false, this.isHighlight = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: isHighlight ? const EdgeInsets.all(10) : EdgeInsets.zero,
    decoration: isHighlight ? BoxDecoration(
      color: const Color(0xFF1E1C10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.goldDim),
    ) : null,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 10, height: 10, margin: const EdgeInsets.only(top: 4, right: 12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isNow ? AppColors.gold : Colors.transparent,
          border: Border.all(color: isNow ? AppColors.gold : AppColors.goldDim, width: 2),
          boxShadow: isNow ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 6)] : null,
        ),
      ),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(time, style: TextStyle(
          fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold,
          color: isHighlight ? AppColors.gold2 : AppColors.gold)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5)),
      ])),
    ]),
  );
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
  const _SolutionTile({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
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
    ]),
  );
}
