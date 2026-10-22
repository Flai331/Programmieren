import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/services.dart';
import 'screens/screens.dart';
import 'fehlerbericht.dart';

void main() {
  Fehlerbericht.runApp(
    appKey: 'rechnungsgenerator',
    appName: 'BeeBrain (Rechnungsgenerator)',
    version: '1.0.0',
    // Bekannte, harmlose Platform-Meldungen nicht nach Notion schicken
    // (waren vorher direkt in FlutterError.onError herausgefiltert).
    ignorieren: const ['NetworkManager', 'connectivity_plus'],
    builder: () => const MyApp(),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _hintergrundInitialisierung();
  }

  // Läuft nach dem ersten Frame im Hintergrund — läuft dank
  // Fehlerbericht.runApp() bereits in der richtigen (guarded) Zone.
  Future<void> _hintergrundInitialisierung() async {
    // ── Lokale SQLite-Datenbank initialisieren ───────────────────
    final dbService = DatabaseService();
    await dbService.database;
    Fehlerbericht.log('✓ Lokale Datenbank initialisiert');

    final connectivityService = ConnectivityService();
    await connectivityService.initialize();
    Fehlerbericht.log('✓ Connectivity-Service initialisiert');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProvider<SyncService>(
          create: (_) => SyncService(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: Fehlerbericht.navigatorKey,
        navigatorObservers: [Fehlerbericht.observer],
        builder: Fehlerbericht.wrap,
        title: 'BeeBrain',
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
            colorScheme: const ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFFfda085),
              onPrimary: Color(0xFF1a0e08),
              primaryContainer: Color(0xFF2a1810),
              onPrimaryContainer: Color(0xFFfda085),
              secondary: Color(0xFFf6d365),
              onSecondary: Color(0xFF1a0e08),
              secondaryContainer: Color(0xFF2a2410),
              onSecondaryContainer: Color(0xFFf6d365),
              tertiary: Color(0xFF60a5fa),
              onTertiary: Color(0xFF0a1a2a),
              tertiaryContainer: Color(0xFF0a1a2a),
              onTertiaryContainer: Color(0xFF60a5fa),
              error: Color(0xFFff6b7a),
              onError: Color(0xFF1a0e08),
              errorContainer: Color(0xFF3a0f15),
              onErrorContainer: Color(0xFFff6b7a),
              surface: Color(0xFF18181c),
              onSurface: Color(0xFFf5f5f7),
              onSurfaceVariant: Color(0xFFc4c4cc),
              outline: Color(0x29ffffff),
              outlineVariant: Color(0x14ffffff),
              shadow: Color(0xFF000000),
              scrim: Color(0xFF000000),
              inverseSurface: Color(0xFFf5f5f7),
              onInverseSurface: Color(0xFF18181c),
              inversePrimary: Color(0xFFe07060),
              surfaceTint: Color(0x00000000),
            ),
            scaffoldBackgroundColor: const Color(0xFF111114),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Color(0xFF111114),
              foregroundColor: Color(0xFFf5f5f7),
              centerTitle: false,
              surfaceTintColor: Color(0x00000000),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xFF111114),
              surfaceTintColor: const Color(0x00000000),
              shadowColor: const Color(0x00000000),
              indicatorColor: const Color(0x33fda085),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: Color(0xFFfda085),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  );
                }
                return const TextStyle(
                  color: Color(0xFF8a8a94),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFFfda085));
                }
                return const IconThemeData(color: Color(0xFF8a8a94));
              }),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFFfda085),
              foregroundColor: Color(0xFF1a0e08),
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfda085),
                foregroundColor: const Color(0xFF1a0e08),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFfda085),
                side: const BorderSide(
                  color: Color(0x66fda085),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFfda085),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF18181c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x29ffffff)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x29ffffff)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFfda085),
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFff6b7a)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFff6b7a),
                  width: 1,
                ),
              ),
              labelStyle: const TextStyle(color: Color(0xFF8a8a94)),
              hintStyle: const TextStyle(color: Color(0xFF5a5a64)),
              floatingLabelStyle: const TextStyle(color: Color(0xFFfda085)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF18181c),
              surfaceTintColor: const Color(0x00000000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: Color(0x14ffffff),
                  width: 1,
                ),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0x14ffffff),
              thickness: 0.5,
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF202024),
              side: const BorderSide(color: Color(0x1affffff)),
              labelStyle: const TextStyle(
                color: Color(0xFFc4c4cc),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color(0xFFfda085),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF202024),
              contentTextStyle: const TextStyle(color: Color(0xFFf5f5f7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0x14ffffff)),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF18181c),
              surfaceTintColor: const Color(0x00000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x14ffffff)),
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF18181c),
              surfaceTintColor: Color(0x00000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFF8a8a94),
              textColor: Color(0xFFf5f5f7),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1a0e08);
                }
                return const Color(0xFF8a8a94);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFfda085);
                }
                return const Color(0xFF2a2a30);
              }),
            ),
          ),
        themeMode: ThemeMode.dark,
        home: const MainNavigationScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
