// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Berechnungs-Logik
//  lib/planer/planer_calculations.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  BERECHNUNGS-LOGIK
// ═══════════════════════════════════════════════════════════════

/// Berechnet Faktor f aus Zielzeit und Temperatur
/// Modell: t_22 = 5 × f^0.623  (an bekannte Datenpunkte angepasst)
double factorFromTime(double targetH, double temp) {
  final t22 = targetH / pow(2, (22 - temp) / 8);
  return pow(t22 / 5.0, 1 / 0.623).toDouble();
}

/// Berechnet geschätzte Zeit für Faktor f und Temperatur
double timeFromFactor(double f, double temp) {
  final t22 = 5.0 * pow(f, 0.623);
  return t22 * pow(2, (22 - temp) / 8);
}

/// Findet den besten (sinnvoll gerundeten) Faktor für Zielzeit + Temp
Map<String, dynamic> pickBestFactor(double targetH, double temp) {
  final fExact = factorFromTime(targetH, temp).clamp(0.5, 50.0);

  // Auf sinnvolle ganze Zahl runden
  double fRounded;
  if (fExact <= 1.3) {
    fRounded = 1.0;
  } else if (fExact <= 1.7) {
    fRounded = 1.5;
  } else {
    fRounded = fExact.round().toDouble();
  }

  // Nachbarn prüfen, besten wählen
  final candidates = {
    fExact.floor().toDouble(),
    fExact.ceil().toDouble(),
    fRounded,
  }.where((v) => v >= 1).toList();

  double best = fRounded;
  double bestDiff = double.infinity;
  for (final c in candidates) {
    final diff = (timeFromFactor(c, temp) - targetH).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = c;
    }
  }

  return {'factor': best, 'exact': fExact};
}

/// Erstellt lesbares Verhältnis-Label
String ratioLabel(double f) {
  if (f == 1.0) return '1 / 1 / 1';
  if (f == 1.5) return '1 / 1.5 / 1.5';
  return '1 / ${f.toInt()} / ${f.toInt()}';
}

/// Formatiert Stunden in lesbaren String
String formatH(double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  if (mm == 0) return '${hh}h';
  return '${hh}h ${mm}min';
}

/// Gibt Temperaturfarbe zurück
Color tempColor(double t) {
  if (t <= 10) return AppColors.blue;
  if (t <= 18) return AppColors.green;
  if (t <= 24) return const Color(0xFFCCE850);
  if (t <= 30) return AppColors.orange;
  if (t <= 37) return const Color(0xFFE85030);
  return AppColors.red;
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
    required this.dFeed,
    required this.dHalf,
    required this.dPeak,
    required this.tempLabel,
    required this.tempAdvice,
    required this.steps,
  });
}
