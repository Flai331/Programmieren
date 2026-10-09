import 'package:akku_schoner/save_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sparen-Seite zeigt Einstellungen und Tipps', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SavePage())));
    expect(find.text('Energiesparmodus'), findsOneWidget);
    expect(find.text('Bildschirm'), findsOneWidget);
  });

  testWidgets('Hilfe-Seite lässt sich öffnen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    expect(find.text('Reiter „Apps“ – drei Stufen'), findsOneWidget);
  });
}
