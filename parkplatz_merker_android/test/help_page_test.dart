import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/pages/help_page.dart';

void main() {
  testWidgets('Anleitung zeigt alle Abschnitte und öffnet den gewünschten', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage(open: HelpTopic.closeApp)));
    await tester.pumpAndSettle();
    expect(find.text('Anleitung'), findsOneWidget);
    expect(find.text('Erste Schritte'), findsOneWidget);
    expect(find.text('Apps beim Aussteigen komplett beenden'), findsOneWidget);
    // Aufgeklappter Abschnitt zeigt seinen Text.
    expect(find.textContaining('Benachrichtigungszugriff'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Anleitung enthält neuen Abschnitt „Lautstärke"', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage(open: HelpTopic.volume)));
    await tester.pumpAndSettle();
    expect(find.text('Lautstärke im Auto anpassen'), findsOneWidget);
    expect(find.textContaining('Lautstärke-Profil'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Anleitung enthält Abschnitt Energiesparmodus (Samsung)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage(open: HelpTopic.powerSaving)));
    await tester.pumpAndSettle();
    expect(find.text('Energiesparmodus im Auto (Samsung)'), findsOneWidget);
    expect(find.textContaining('Modi und Routinen'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
