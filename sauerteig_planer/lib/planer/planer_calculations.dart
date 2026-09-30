// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Berechnungs-Logik
//  lib/planer/planer_calculations.dart
//
//  Modell: Verhältnis-Buckets (1:1:1 … 1:5:5) statt Kurvenfit.
//  Zeitfenster + Temperatur → Verhältnis → Mengen (rückwärts) → Wassertemp.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  BERECHNUNGS-LOGIK
// ═══════════════════════════════════════════════════════════════

/// Temperatur-Faktor: Gärung verdoppelt sich ~je 8 °C (Basis 22 °C).
/// >1 = langsamer (kühl), <1 = schneller (warm).
double _tempFactor(double temp) => pow(2, (22 - temp) / 8).toDouble();

/// VERHÄLTNIS-AUTOMATISIERUNG
/// Wählt den Faktor f (Verhältnis 1:f:f) für ein Zeitfenster bei gegebener Temp.
/// Das Fenster wird auf 22 °C normiert, dann der GRÖSSTE Faktor gewählt,
/// dessen Reifezeit (siehe [_baseHours]) noch ins Fenster passt.
/// Damit gilt immer: Peak ≤ nächste Fütterung/Backzeit — der Starter ist
/// beim nächsten Schritt reif (leicht überreif ist ok, unreif nicht).
/// Warme Räume verkürzen das normierte Fenster automatisch → kleineres f.
double waehleFaktor(double fensterStunden, double temp) {
  final h = fensterStunden / _tempFactor(temp); // auf 22 °C normiert
  if (h < 7) return 1.0;   // 1:1:1 reift in ~5 h
  if (h < 10) return 1.5;  // 1:1.5:1.5 → ~7 h
  if (h < 14) return 2.0;  // 1:2:2 → ~10 h
  if (h < 18) return 3.0;  // 1:3:3 → ~14 h
  if (h < 22) return 4.0;  // 1:4:4 → ~18 h
  return 5.0;              // 1:5:5 → ~22 h
}

/// Repräsentative Reifezeit (h) je Faktor bei 22 °C — invers zu [waehleFaktor].
double _baseHours(double f) {
  if (f <= 1.0) return 5;
  if (f <= 1.5) return 7;
  if (f <= 2.0) return 10;
  if (f <= 3.0) return 14;
  if (f <= 4.0) return 18;
  return 22;
}

/// Geschätzte Zeit bis zum Peak für Faktor f bei Temperatur.
/// Ersetzt das alte 5·f^0.623-Modell durch die Bucket-Tabelle.
double timeFromFactor(double f, double temp) => _baseHours(f) * _tempFactor(temp);

/// Ziel-Teigtemperatur je Phasenlänge.
/// Kurzes Fenster muss schnell peaken → wärmer anschieben.
/// Langes Fenster → moderat, sonst übersäuert es.
double zielTeigTemp(double fensterStunden) {
  if (fensterStunden < 6) return 28; // kurz → warm
  if (fensterStunden <= 8) return 27;
  return 25; // lang → moderat
}

/// TEMPERATUR-KOMPENSATION — Bäcker-DDT (3-Faktor):
///   T_Wasser = 3 × Zieltemp − Raumtemp − Mehltemp − Reibung
/// Begrenzt auf [4, 50] °C (Hefe stirbt > ~50 °C, < 4 °C sinnlos).
int wasserTemperatur(
  double raumTemp, {
  double zielTemp = 26,
  double mehlTemp = 20,
  double reibung = 1,
}) {
  final t = 3 * zielTemp - raumTemp - mehlTemp - reibung;
  return t.round().clamp(4, 50);
}

/// Findet das beste (sinnvoll gebucketete) Verhältnis für Zielzeit + Temp.
/// Rückgabe: {'factor': gewählter Faktor, 'exact': identisch (Buckets sind exakt)}.
Map<String, dynamic> pickBestFactor(double targetH, double temp) {
  final f = waehleFaktor(targetH, temp);
  return {'factor': f, 'exact': f};
}

/// Erstellt lesbares Verhältnis-Label (z. B. "1 / 2 / 2").
String ratioLabel(double f) {
  if (f == 1.0) return '1 / 1 / 1';
  if (f == 1.5) return '1 / 1.5 / 1.5';
  return '1 / ${f.toInt()} / ${f.toInt()}';
}

/// Kompaktes Verhältnis (z. B. "1:2:2").
String ratioText(double f) {
  if (f == 1.5) return '1:1.5:1.5';
  return '1:${f.toInt()}:${f.toInt()}';
}

/// Formatiert Stunden in lesbaren String.
String formatH(double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  if (mm == 0) return '${hh}h';
  return '${hh}h ${mm}min';
}

/// Gibt Temperaturfarbe zurück.
Color tempColor(double t) {
  if (t <= 10) return AppColors.blue;
  if (t <= 18) return AppColors.green;
  if (t <= 24) return const Color(0xFFCCE850);
  if (t <= 30) return AppColors.orange;
  if (t <= 37) return const Color(0xFFE85030);
  return AppColors.red;
}

// ═══════════════════════════════════════════════════════════════
//  RÜCKWÄRTS-KASKADE (Spec-Modell)
// ═══════════════════════════════════════════════════════════════

/// Eine berechnete Auffrischungsphase.
class RefreshPhase {
  final int phase;
  final double dauerStunden;
  final double faktor;
  final String verhaeltnis; // "1:2:2"
  final int asg;
  final int mehl;
  final int wasser;
  final int gesamt;
  final int wasserTempC;

  const RefreshPhase({
    required this.phase,
    required this.dauerStunden,
    required this.faktor,
    required this.verhaeltnis,
    required this.asg,
    required this.mehl,
    required this.wasser,
    required this.gesamt,
    required this.wasserTempC,
  });
}

/// RÜCKWÄRTS-KALKULATION der Mengen.
/// Die letzte Phase produziert [zielMenge]; das benötigte ASG einer Phase
/// bestimmt die Gesamtmenge der vorherigen Phase.
/// [zeitFenster] ist chronologisch (erste Auffrischung zuerst).
List<RefreshPhase> berechneKaskade({
  required double zielMenge,
  required double raumTemp,
  required List<double> zeitFenster,
}) {
  final n = zeitFenster.length;
  if (n == 0) return const [];

  final phasen = List<RefreshPhase?>.filled(n, null);
  var benoetigteGesamtmenge = zielMenge;

  for (var i = n - 1; i >= 0; i--) {
    final fenster = zeitFenster[i];
    final f = waehleFaktor(fenster, raumTemp);

    // total = ASG × (1 + 2f)  →  ASG = total / (1 + 2f); aufrunden = genug Seed
    final asg = (benoetigteGesamtmenge / (1 + 2 * f)).ceil();
    final mehl = (asg * f).round();
    final wasser = (asg * f).round();

    phasen[i] = RefreshPhase(
      phase: i + 1,
      dauerStunden: fenster,
      faktor: f,
      verhaeltnis: ratioText(f),
      asg: asg,
      mehl: mehl,
      wasser: wasser,
      gesamt: asg + mehl + wasser,
      wasserTempC: wasserTemperatur(raumTemp, zielTemp: zielTeigTemp(fenster)),
    );

    benoetigteGesamtmenge = asg.toDouble();
  }

  return phasen.cast<RefreshPhase>();
}

// ═══════════════════════════════════════════════════════════════
//  ERGEBNIS-DATENKLASSE
// ═══════════════════════════════════════════════════════════════
class PlanerResult {
  final double temp;
  final double factor;
  final double fExact;
  final String ratio;
  final double estTime;
  final double timeDiff;
  final int anstellgut;
  final int wasser;
  final int mehl;
  final int gesamt;
  final int forRecipe;
  final int leftover;
  final int unusedStarter;
  final int wasserTempC;
  final DateTime dFeed;
  final DateTime dHalf;
  final DateTime dPeak;
  final String tempLabel;
  final String tempAdvice;
  final List<String> steps;

  PlanerResult({
    required this.temp,
    required this.factor,
    required this.fExact,
    required this.ratio,
    required this.estTime,
    required this.timeDiff,
    required this.anstellgut,
    required this.wasser,
    required this.mehl,
    required this.gesamt,
    required this.forRecipe,
    required this.leftover,
    required this.unusedStarter,
    required this.wasserTempC,
    required this.dFeed,
    required this.dHalf,
    required this.dPeak,
    required this.tempLabel,
    required this.tempAdvice,
    required this.steps,
  });
}
