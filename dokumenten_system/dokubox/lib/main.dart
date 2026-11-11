import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app_services.dart';
import 'data/database.dart';
import 'lock/lock_gate.dart';
import 'ui/document_detail_screen.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  // Engine für das optionale lokale KI-Modell (Qwen3, .litertlm).
  try {
    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  } catch (_) {
    // KI ist optional (z. B. am PC nicht verfügbar).
  }
  // PDF-Engine für Import und Vorschau des Originals.
  await pdfrxFlutterInitialize();
  await _applyPendingRestore();

  services = AppServices(AppDatabase.open());
  // Benachrichtigung angetippt → Dokument öffnen.
  services.notifications.onOpenDocument = _openDocument;
  // Anstehende Fristen neu planen (deckt Geräteneustarts ab).
  services.notifications.rescheduleAll();

  runApp(const DokuBoxApp());
  // App wurde über eine Benachrichtigung gestartet → Dokument öffnen.
  final launchDoc = await services.notifications.launchDocumentId();
  if (launchDoc != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDocument(launchDoc));
  }
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

/// Für Navigation von außerhalb der Widgets (Benachrichtigungen).
final navigatorKey = GlobalKey<NavigatorState>();

void _openDocument(String documentId) {
  navigatorKey.currentState?.push(MaterialPageRoute(
    builder: (_) => DocumentDetailScreen(documentId: documentId),
  ));
}

class DokuBoxApp extends StatelessWidget {
  const DokuBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      // LockGate umschließt den gesamten Navigator, damit das Sperr-Overlay
      // auch über gerade geöffnete Bildschirme (z. B. Bestätigen) legt und
      // kein Bildschirm dafür verworfen wird.
      builder: (context, child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}
