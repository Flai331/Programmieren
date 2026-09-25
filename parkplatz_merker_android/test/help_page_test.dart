import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkplatz_merker/pages/help_page.dart';

void main() {
  testWidgets('Anleitung zeigt alle Abschnitte und öffnet den gewünschten', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage(open: HelpTopic.closeApp)));
    await tester.pumpAndSettle();
    expect(find.text('Anleitung'), findsOneWidget);
    expect(find.text('Erste Schritte'), findsOneWidget);
    expect(find.text('App beim Aussteigen komplett beenden'), findsOneWidget);
    // Aufgeklappter Abschnitt zeigt seinen Text.
    expect(find.textContaining('Benachrichtigungszugriff'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
