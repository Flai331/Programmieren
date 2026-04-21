import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/services.dart';
import 'screens/screens.dart';
import 'utils/utils.dart';
import 'utils/feedback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Fehler-Abfangen ──────────────────────────────────────────
  FlutterError.onError = (details) {
    FeedbackService.logError(
      details.exception.toString(),
      context: 'FlutterError',
      stackTrace: details.stack,
    );
    FeedbackService.showAutoErrorDialog();
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FeedbackService.logError(
      error.toString(),
      context: 'AsyncError',
      stackTrace: stack,
    );
    FeedbackService.showAutoErrorDialog();
    return true;
  };

  // ── Services initialisieren ──────────────────────────────────
  final dbService = DatabaseService();
  await dbService.database;
  FeedbackService.log('✓ Datenbank initialisiert');

  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  FeedbackService.log('✓ Connectivity-Service initialisiert');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  static final _repaintKey = GlobalKey();
  static final _navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeedbackService.setRepaintKey(MyApp._repaintKey);
      FeedbackService.setNavigatorKey(MyApp._navigatorKey);
      FeedbackService.log('✓ FeedbackService konfiguriert');
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: MyApp._repaintKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService(),
          ),
          ChangeNotifierProvider<SyncService>(
            create: (_) => SyncService(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: MyApp._navigatorKey,
          navigatorObservers: [FeedbackService.screenObserver],
          title: 'Rechnungsgenerator Pro',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFfda085),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Color(0xFFfda085),
              foregroundColor: Colors.white,
              centerTitle: false,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFFfda085),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfda085),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFfda085),
                side: const BorderSide(color: Color(0xFFfda085)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFfda085),
                  width: 2,
                ),
              ),
              labelStyle: const TextStyle(color: Color(0xFFfda085)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Color(0xFFfda085),
              unselectedItemColor: Colors.grey,
              elevation: 8,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Colors.grey,
              thickness: 0.5,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFfda085),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeMode.light,
          home: const MainNavigationScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
