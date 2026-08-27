// ═══════════════════════════════════════════════════════════════
//  IMKEREI VERWALTUNG — Flutter App
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'app_colors.dart';
import 'dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  runApp(const ImkereiApp());
}

class ImkereiApp extends StatelessWidget {
  static final _navigatorKey = GlobalKey<NavigatorState>();

  const ImkereiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Imkerei Verwaltung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.honey,
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.surface,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.honey,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.honey,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honey,
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
