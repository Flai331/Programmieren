import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controller.dart';
import 'native.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController();
  runApp(MyApp(controller: controller));
  // Laden läuft im Hintergrund; die Startseite zeigt solange einen Kreis.
  controller.initialize();
}

@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final c = AppController();
    await c.initialize(background: true);
  } catch (e) {
    debugPrint('backgroundMain: $e');
  } finally {
    await NativeBridge.backgroundDone();
  }
}

class MyApp extends StatelessWidget {
  final AppController controller;

  const MyApp({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppController>.value(value: controller),
      ],
      child: MaterialApp(
        title: 'Parkplatz-Merker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
        home: const HomePage(),
      ),
    );
  }
}
