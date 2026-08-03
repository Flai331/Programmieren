import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/home_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  void stub({required bool locked, required bool accessibility}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getState':
          return {
            'locked': locked,
            'mode': 'TIMER',
            'endsAt': locked ? DateTime.now().millisecondsSinceEpoch + 60000 : null,
            'durationMinutes': 60,
            'blockedPackages': ['com.instagram.android'],
            'hasTag': true,
            'hasCode': true,
          };
        case 'isAccessibilityEnabled':
          return accessibility;
        case 'isAdminActive':
          return true;
      }
      return null;
    });
  }

  testWidgets('zeigt Frei-Status', (tester) async {
    stub(locked: false, accessibility: true);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riegel offen'), findsOneWidget);
  });

  testWidgets('zeigt Gesperrt-Status', (tester) async {
    stub(locked: true, accessibility: true);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riegel zu'), findsOneWidget);
  });

  testWidgets('warnt, wenn der Dienst aus ist', (tester) async {
    stub(locked: false, accessibility: false);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sperre nicht wirksam'), findsOneWidget);
  });
}
