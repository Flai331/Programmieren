// ═══════════════════════════════════════════════════════════════
//  IMKEREI VERWALTUNG — Farbpalette (Honig & Biene)
//  lib/app_colors.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

abstract class AppColors {
  // Primärfarben – Honig & Amber
  static const Color honey      = Color(0xFFF9A825); // Honiggelb
  static const Color amber      = Color(0xFFFF8F00); // Dunkles Amber
  static const Color wax        = Color(0xFFFFF8E1); // Wachsgelb (hell)

  // Hintergrund & Oberfläche (Dark Mode)
  static const Color bg         = Color(0xFF1A1400); // Fast Schwarz mit Braun
  static const Color surface    = Color(0xFF2C2000); // Dunkles Braun
  static const Color cardBg     = Color(0xFF3A2C00); // Karte

  // Akzentfarben
  static const Color green      = Color(0xFF66BB6A); // Gesund/Gut
  static const Color red        = Color(0xFFEF5350);  // Warnung/Problem
  static const Color orange     = Color(0xFFFF7043); // Achtung
  static const Color blue       = Color(0xFF42A5F5);  // Info

  // Text
  static const Color textPrimary   = Color(0xFFFFF8E1);
  static const Color textSecondary = Color(0xFFBCAA8A);
  static const Color textHint      = Color(0xFF8D7B5A);
}
