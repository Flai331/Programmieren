import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/riegel_channel.dart';
import 'package:nfc_riegel/setup_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  Map<dynamic, dynamic>? angelernt;

  void stub() {
    angelernt = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getState':
              return {
                'profiles': [
                  {
                    'id': 'p1',
                    'name': 'Standard',
                    'blockedPackages': <String>[],
                    'defaultMode': 'OPEN',
                    'durationMinutes': 60,
                    'untilAt': null,
                    'pinCalendarEnd': false,
                    'timedRelease': false,
                  },
                ],
                'tags': <Map<String, dynamic>>[],
                'chipLock': null,
                'release': null,
                'timeLocks': <Map<String, dynamic>>[],
                'hasMasterTag': false,
                'hasCode': false,
              };
            case 'startTagEnrollment':
              angelernt = call.arguments as Map<dynamic, dynamic>;
              return null;
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupWizard(
          onFinished: () {},
          channel: const RiegelChannel(channel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('der erste Chip wird ohne Sondermerkmal angelernt', (
    tester,
  ) async {
    // Alle Chips sind gleich; einen Generalschluessel gibt es nicht mehr. Der
    // Assistent darf deshalb kein Sondermerkmal mitschicken.
    stub();
    await zeige(tester);

    // Zum dritten Schritt durchklicken. „Weiter" steht fuer jeden Schritt im
    // Baum, der erste Treffer gehoert zum gerade offenen.
    await tester.tap(find.text('Weiter').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter').first);
    await tester.pumpAndSettle();

    // Ueber den Knopftyp suchen: „Chip anlernen" heisst auch die Schrittzeile.
    final knopf = find.widgetWithText(OutlinedButton, 'Chip anlernen');
    await tester.ensureVisible(knopf);
    await tester.pumpAndSettle();
    await tester.tap(knopf);
    await tester.pumpAndSettle();

    expect(angelernt, isNotNull);
    expect(angelernt!['profileId'], 'p1');
    expect(angelernt!.containsKey('isMaster'), isFalse);
  });
}
