import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/db.dart';
import 'state/city_store.dart';
import 'ui/book_screens.dart';
import 'ui/chronicle_screen.dart';
import 'ui/city_screen.dart';
import 'ui/sprites.dart';
import 'ui/common.dart';
import 'ui/year_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  try {
    Sprites.instance = await Sprites.load();
  } catch (_) {
    // Ohne Bilder wird die Stadt gezeichnet.
  }
  final store = CityStore(AppDatabase());
  runApp(LeseStadtApp(store: store));
  await store.load();
}

class LeseStadtApp extends StatelessWidget {
  const LeseStadtApp({super.key, required this.store});
  final CityStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Lese-Stadt',
        debugShowCheckedModeBanner: false,
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A9E5A)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7A9E5A),
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      // Nur der sichtbare Tab darf animieren (spart Akku).
      body: IndexedStack(
        index: _tab,
        children: [
          for (final (i, screen) in const [
            CityScreen(),
            ShelfScreen(),
            YearScreen(),
            ChronicleScreen(),
          ].indexed)
            TickerMode(enabled: i == _tab, child: screen),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.location_city),
            label: 'Stadt',
          ),
          NavigationDestination(icon: Icon(Icons.shelves), label: 'Regal'),
          NavigationDestination(icon: Icon(Icons.flag), label: 'Jahr'),
          NavigationDestination(
            icon: Icon(Icons.history_edu),
            label: 'Chronik',
          ),
        ],
      ),
    );
  }
}
