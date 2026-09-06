import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/home_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  /// Zuletzt an `startLock` übergebenes Profil — so lässt sich prüfen, ob
  /// der Knopf wirklich bis zur nativen Seite durchschlägt.
  String? gestartetesProfil;

  void stub({
    required bool accessibility,
    String defaultMode = 'TIMER',
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>> timeLocks = const [],
    bool hasMasterTag = true,
    bool hasCode = true,
    Map<String, dynamic>? calendar,
    Map<String, dynamic>? release,
  }) {
    gestartetesProfil = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getState':
              return {
                'profiles': [
                  {
                    'id': 'p1',
                    'name': 'Arbeit',
                    'blockedPackages': ['com.instagram.android'],
                    'defaultMode': defaultMode,
                    'durationMinutes': 60,
                    'untilAt': null,
                    'pinCalendarEnd': false,
                  },
                ],
                'tags': [
                  {
                    'uid': '04AA',
                    'label': 'Schreibtisch',
                    'profileId': 'p1',
                    'isMaster': hasMasterTag,
                  },
                ],
                'chipLock': chipLock,
                'release': release,
                'timeLocks': timeLocks,
                'hasMasterTag': hasMasterTag,
                'hasCode': hasCode,
                // Fehlt der Block, fällt LockStatus.fromMap auf CalendarInfo.empty —
                // deshalb laufen alle Tests ohne Kalender unverändert weiter.
                'calendar': calendar,
              };
            case 'isAccessibilityEnabled':
              return accessibility;
            case 'isAdminActive':
              return true;
            case 'startLock':
              gestartetesProfil = call.arguments['profileId'] as String?;
              return 'STARTED';
          }
          return null;
        });
  }

  List<Map<String, dynamic>> laufendeSperre() => [
    {
      'profileId': 'p1',
      'mode': 'TIMER',
      'endsAt': DateTime.now().millisecondsSinceEpoch + 60000,
    },
  ];

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Frei-Status', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    expect(find.text('Riegel offen'), findsOneWidget);
  });

  testWidgets('zeigt Gesperrt-Status mit Profilnamen', (tester) async {
    stub(accessibility: true, timeLocks: laufendeSperre());
    await zeige(tester);

    expect(find.text('Riegel zu'), findsOneWidget);
    expect(find.textContaining('Arbeit'), findsWidgets);
  });

  testWidgets('warnt, wenn der Dienst aus ist', (tester) async {
    stub(accessibility: false);
    await zeige(tester);

    expect(find.text('Sperre nicht wirksam'), findsOneWidget);
  });

  testWidgets('TIMER-Profil zeigt Sperren-Knopf', (tester) async {
    stub(accessibility: true, defaultMode: 'TIMER');
    await zeige(tester);

    expect(find.text('Sperren'), findsOneWidget);
  });

  testWidgets('OPEN-Profil laesst sich ohne Chip sperren', (tester) async {
    stub(accessibility: true, defaultMode: 'OPEN');
    await zeige(tester);

    await tester.tap(find.text('Sperren'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('bis du den Chip erneut scannst'),
      findsOneWidget,
    );

    await tester.tap(find.text('Sperren').last);
    await tester.pumpAndSettle();

    expect(gestartetesProfil, 'p1');
  });

  testWidgets('laufende Chipsperre zeigt keinen Sperren-Knopf', (tester) async {
    stub(
      accessibility: true,
      defaultMode: 'OPEN',
      chipLock: {'profileId': 'p1'},
    );
    await zeige(tester);

    expect(find.text('Sperren'), findsNothing);
  });

  testWidgets('laufende Zeitsperre bietet Verlaengern an', (tester) async {
    stub(accessibility: true, timeLocks: laufendeSperre());
    await zeige(tester);

    expect(find.text('Verlängern'), findsOneWidget);
  });

  testWidgets('Bestaetigung warnt ohne Generalschluessel', (tester) async {
    stub(accessibility: true, hasMasterTag: false);
    await zeige(tester);

    await tester.tap(find.text('Sperren'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kein Generalschlüssel'), findsOneWidget);
  });

  testWidgets('Bestaetigen startet die Zeitsperre', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    await tester.tap(find.text('Sperren'));
    await tester.pumpAndSettle();
    // „Sperren" steht jetzt zweimal auf dem Schirm: in der Profilzeile und im
    // Dialog. Der zuletzt gefundene liegt im Dialog.
    await tester.tap(find.text('Sperren').last);
    await tester.pumpAndSettle();

    expect(gestartetesProfil, 'p1');
  });

  testWidgets('laufender Termin steht in der Statuskachel', (tester) async {
    final jetzt = DateTime.now();
    stub(
      accessibility: true,
      calendar: {
        'enabled': true,
        'permissionGranted': true,
        'calendarRules': <dynamic, dynamic>{},
        'keywordMarker': '[Riegel]',
        'keywordCalendarIds': <dynamic>[],
        'windows': <dynamic>[],
        'activeWindows': [
          {
            'eventId': 'e1',
            'title': 'Konzept schreiben',
            'startsAt': jetzt.millisecondsSinceEpoch,
            'endsAt': jetzt
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            'profileId': 'p1',
          },
        ],
      },
    );
    await zeige(tester);

    expect(find.textContaining('Konzept schreiben'), findsOneWidget);
  });

  testWidgets('zweiter Reiter zeigt die Screenzeit', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    expect(find.text('Sperre'), findsOneWidget);
    expect(find.text('Screenzeit'), findsOneWidget);

    await tester.tap(find.text('Screenzeit'));
    await tester.pumpAndSettle();

    // Ohne Berechtigung — der Mock kennt 'usageAccessGranted' nicht und liefert
    // null, was zu false wird.
    expect(find.text('Zugriff erlauben'), findsOneWidget);
  });

  testWidgets('laufende Freigabe steht in der Statuskachel', (tester) async {
    final ende = DateTime.now().add(const Duration(minutes: 12));
    stub(
      accessibility: true,
      defaultMode: 'OPEN',
      chipLock: {'profileId': 'p1'},
      release: {
        'profileId': 'p1',
        'endsAt': ende.millisecondsSinceEpoch,
      },
    );
    await zeige(tester);

    expect(find.textContaining('frei bis'), findsOneWidget);
    expect(find.text('Riegel offen'), findsOneWidget);
    expect(find.text('Riegel zu'), findsNothing);
  });

}
