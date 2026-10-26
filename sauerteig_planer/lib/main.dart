// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Flutter App
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'fehlerbericht.dart';

void main() {
  tz_data.initializeTimeZones();
  Fehlerbericht.runApp(
    appKey: 'sauerteig',
    appName: 'Sauerteig Planer',
    version: '1.0.0',
    builder: () => const SauerteigApp(),
  );
}

class SauerteigApp extends StatelessWidget {
  const SauerteigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Fehlerbericht.navigatorKey,
      navigatorObservers: [Fehlerbericht.observer],
      builder: Fehlerbericht.wrap,
      title: 'Sauerteig Planer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.gold,
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.surface,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}
