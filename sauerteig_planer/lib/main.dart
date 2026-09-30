// ═══════════════════════════════════════════════════════════════
//  SAUERTEIG PLANER — Flutter App
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'untils/feedback_service.dart';
import 'widget/quick_idea_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FeedbackService.log('FLUTTER FEHLER: ${details.exception}');
    // Erste 3 relevante Stack-Zeilen loggen (Widget-Klassen sichtbar machen)
    final frames = details.stack.toString().split('\n')
        .where((l) => l.contains('backtimer') || l.contains('sauerteig') || l.contains('_Step') || l.contains('_build'))
        .take(3)
        .toList();
    if (frames.isNotEmpty) FeedbackService.log('  → ${frames.join(' | ')}');
    FeedbackService.showAutoErrorDialog();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    // Bekannter flutter_local_notifications Fehler beim Lesen alter
    // Benachrichtigungsdaten → nicht kritisch, kein Dialog nötig
    if (msg.contains('Missing type parameter')) {
      FeedbackService.log('Ignorierter Benachrichtigungs-Fehler: $msg');
      return true;
    }
    FeedbackService.log('ASYNC FEHLER: $msg');
    FeedbackService.showAutoErrorDialog();
    return true;
  };

  tz_data.initializeTimeZones();

  // Deutsche Datums-/Zeitformate für alle DateFormat-Aufrufe
  await initializeDateFormatting('de_DE');
  Intl.defaultLocale = 'de_DE';

  runApp(const SauerteigApp());
}

class SauerteigApp extends StatefulWidget {
  static final _repaintKey   = GlobalKey();
  static final _navigatorKey = GlobalKey<NavigatorState>();

  const SauerteigApp({super.key});

  @override
  State<SauerteigApp> createState() => _SauerteigAppState();
}

class _SauerteigAppState extends State<SauerteigApp> {
  static const _widgetChannel =
      MethodChannel('com.example.sauerteig_planer/widget');

  @override
  void initState() {
    super.initState();
    // Widget-Tap: App wurde kalt gestartet → einmalig beim Start prüfen
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWidgetIntent());
    // Widget-Tap: App läuft bereits im Hintergrund → Channel-Handler
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'openScreen' && call.arguments == 'quick_idea') {
        _openQuickIdea();
      }
    });
  }

  Future<void> _checkWidgetIntent() async {
    try {
      final screen =
          await _widgetChannel.invokeMethod<String>('getPendingScreen');
      if (screen == 'quick_idea') _openQuickIdea();
    } catch (_) {}
  }

  void _openQuickIdea() {
    final nav = SauerteigApp._navigatorKey.currentState;
    if (nav == null) return;
    showQuickIdeaSheet(nav.overlay!.context);
  }

  @override
  Widget build(BuildContext context) {
    FeedbackService.setRepaintKey(SauerteigApp._repaintKey);
    FeedbackService.setNavigatorKey(SauerteigApp._navigatorKey);
    return RepaintBoundary(
      key: SauerteigApp._repaintKey,
      child: MaterialApp(
        navigatorKey: SauerteigApp._navigatorKey,
        navigatorObservers: [FeedbackService.screenObserver],
        title: 'Sauerteig Planer',
        debugShowCheckedModeBanner: false,
        locale: const Locale('de'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
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
