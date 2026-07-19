import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'data/database.dart';
import 'lock/lock_gate.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  // Engine für das optionale lokale KI-Modell (Qwen3, .litertlm).
  await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  await _applyPendingRestore();

  services = AppServices(AppDatabase.open());
  // Anstehende Fristen neu planen (deckt Geräteneustarts ab).
  services.notifications.rescheduleAll(services.repository);

  runApp(const DokuBoxApp());
}

/// Falls ein wiederhergestelltes Backup bereitliegt (Einstellungen →
/// Wiederherstellen), wird es vor dem Öffnen der Datenbank eingewechselt.
Future<void> _applyPendingRestore() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final pending = File(p.join(docsDir.path, 'dokubox_restore.sqlite'));
    if (await pending.exists()) {
      final target = File(p.join(docsDir.path, 'dokubox.sqlite'));
      if (await target.exists()) await target.delete();
      await pending.rename(target.path);
    }
  } catch (_) {
    // Im Zweifel mit der bestehenden Datenbank starten.
  }
}

class DokuBoxApp extends StatelessWidget {
  const DokuBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DokuBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LockGate(child: HomeScreen()),
    );
  }
}
