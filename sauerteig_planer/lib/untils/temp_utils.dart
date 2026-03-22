import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Gibt eine Farbe passend zur Temperatur zurück
Color tempColor(double t) {
  if (t <= 10) return AppColors.blue;
  if (t <= 18) return AppColors.green;
  if (t <= 24) return const Color(0xFFCCE850);
  if (t <= 30) return AppColors.orange;
  if (t <= 37) return const Color(0xFFE85030);
  return AppColors.red;
}
