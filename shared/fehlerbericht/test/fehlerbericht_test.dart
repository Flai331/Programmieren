// Prüft die Kernversprechen des Drop-in-Moduls:
// Button erscheint von allein, Dialog geht auf, Protokoll wird geführt.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fehlerbericht/fehlerbericht.dart';

/// Minimale App, exakt so eingebunden wie im README beschrieben.
Widget _testApp({bool button = true}) => MaterialApp(
      navigatorKey: Fehlerbericht.navigatorKey,
      navigatorObservers: [Fehlerbericht.observer],
      builder: button ? Fehlerbericht.wrap : null,
      home: Scaffold(
        appBar: AppBar(title: const Text('Start')),
        body: const Center(child: Text('Inhalt')),
      ),
    );

void main() {
  testWidgets('Fehler-Button erscheint ohne weiteres Zutun', (tester) async {
    await tester.pumpWidget(_testApp());
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
  });

  /// Vor dem Dialog wird ein Screenshot erfasst. Klemmt dieser (im
  /// Test-Renderer scheitert die PNG-Kodierung), muss der Dialog
  /// trotzdem aufgehen — ein Button, der scheinbar nichts tut, wäre der
  /// schlimmste Fall. Deshalb wird hier über die Zeitgrenze hinweg
  /// gepumpt.
  Future<void> buttonTippen(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.bug_report));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Antippen öffnet den Melde-Dialog, auch ohne Screenshot',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await buttonTippen(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Fehler melden'), findsOneWidget);
    // Freitextfeld für die Beschreibung ist vorhanden
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Dialog lässt sich wieder schließen', (tester) async {
    await tester.pumpWidget(_testApp());
    await buttonTippen(tester);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Ohne builder gibt es keinen Overlay-Button', (tester) async {
    await tester.pumpWidget(_testApp(button: false));
    expect(find.byIcon(Icons.bug_report), findsNothing);
  });

  test('Protokoll ist ein Ring-Puffer und verliert die App nicht', () {
    for (var i = 0; i < 500; i++) {
      Fehlerbericht.log('Eintrag $i');
    }
    final p = Fehlerbericht.protokoll;
    expect(p.length, lessThanOrEqualTo(300));
    expect(p.last, contains('Eintrag 499'));
    // Älteste Einträge wurden verworfen, nicht die neuesten
    expect(p.first, isNot(contains('Eintrag 0')));
  });

  test('Protokoll-Liste ist von außen nicht veränderbar', () {
    expect(() => Fehlerbericht.protokoll.add('x'), throwsUnsupportedError);
  });

  testWidgets('Bekannte Störmeldungen landen nicht als Bericht',
      (tester) async {
    Fehlerbericht.runApp(
      appKey: 'test',
      appName: 'Test',
      ignorieren: const ['NetworkManager'],
      builder: () => _testApp(),
    );
    await tester.pumpAndSettle();

    Fehlerbericht.logFehler('NetworkManager meldet Unsinn');
    expect(
      Fehlerbericht.protokoll.where((z) => z.contains('Ignoriert')).length,
      1,
      reason:
          'gefilterte Meldung muss im Protokoll stehen, aber nicht gesendet werden',
    );
    expect(
      Fehlerbericht.protokoll.where((z) => z.contains('FEHLER [')).length,
      0,
    );

    // Ein nicht gefilterter Fehler wird dagegen normal erfasst.
    Fehlerbericht.logFehler('Echter Fehler');
    expect(
      Fehlerbericht.protokoll.where((z) => z.contains('FEHLER [')).length,
      1,
    );
  });
}
