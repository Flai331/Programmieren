// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Flutter App
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'untils/feedback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FeedbackService.log('FLUTTER FEHLER: ${details.exception}');
    FeedbackService.showAutoErrorDialog();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FeedbackService.log('ASYNC FEHLER: $error');
    FeedbackService.showAutoErrorDialog();
    return true;
  };

  tz_data.initializeTimeZones();
  runApp(const SauerteigApp());
}

class SauerteigApp extends StatelessWidget {
  static final _repaintKey    = GlobalKey();
  static final _navigatorKey  = GlobalKey<NavigatorState>();

  const SauerteigApp({super.key});

  @override
  Widget build(BuildContext context) {
    FeedbackService.setRepaintKey(_repaintKey);
    FeedbackService.setNavigatorKey(_navigatorKey);
    return RepaintBoundary(
      key: _repaintKey,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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
      ),
    );
  }
}
