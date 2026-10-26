// Minimalbeispiel für die Einbindung von Fehlerbericht in eine neue App.
//
// Start (mit gesetztem Notion-Token):
//   flutter run --dart-define=NOTION_TOKEN=ntn_...
//
// Ohne Token läuft alles genauso, Berichte gehen dann per mailto: raus.

import 'package:flutter/material.dart';

// In einer echten App liegt fehlerbericht.dart direkt in lib/ und der
// Import lautet dann schlicht: import 'fehlerbericht.dart';
import 'package:fehlerbericht/fehlerbericht.dart';

void main() => Fehlerbericht.runApp(
      appKey: 'beispiel_app', // stabiler, klein geschriebener Schlüssel
      appName: 'Beispiel App', // Anzeigename in Notion
      version: '1.0.0', // optional, taucht in jedem Bericht auf
      builder: () => const MyApp(),
    );

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beispiel App',
      navigatorKey: Fehlerbericht.navigatorKey,
      navigatorObservers: [Fehlerbericht.observer],
      builder: Fehlerbericht.wrap,
      home: const StartSeite(),
    );
  }
}

class StartSeite extends StatelessWidget {
  const StartSeite({super.key});

  @override
  Widget build(BuildContext context) {
    Fehlerbericht.logSeite('StartSeite');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beispiel App'),
        // Alternative zum schwebenden Overlay-Button (z. B. wenn
        // Fehlerbericht.runApp(..., button: false) gesetzt wurde):
        actions: const [FehlerButton()],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Fehlerbericht.logAktion('Testfehler-Button gedrückt');
            throw Exception('Absichtlicher Testfehler');
          },
          child: const Text('Testfehler auslösen'),
        ),
      ),
    );
  }
}
