import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/calendar_screen.dart';
import 'package:nfc_riegel/lock_status.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  /// Zuletzt an `setCalendarSettings` übergebene Argumente.
  Map<dynamic, dynamic>? gespeichert;

  void stub({List<Map<String, String>> kalender = const []}) {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'deviceCalendars':
              return kalender;
            case 'setCalendarSettings':
              gespeichert = call.arguments as Map<dynamic, dynamic>;
              return true;
            case 'requestCalendarPermission':
              return true;
            case 'refreshCalendar':
              return true;
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  LockStatus status({
    bool enabled = false,
    bool permission = true,
    Map<String, dynamic> rules = const {},
    List<Map<String, dynamic>> windows = const [],
  }) => LockStatus.fromMap({
    'profiles': [
      {
        'id': 'p1',
        'name': 'Arbeit',
        'blockedPackages': <dynamic>[],
        'defaultMode': 'TIMER',
        'durationMinutes': 60,
        'pinCalendarEnd': false,
      },
    ],
    'tags': <dynamic>[],
    'timeLocks': <dynamic>[],
    'calendar': {
      'enabled': enabled,
      'permissionGranted': permission,
      'calendarRules': rules,
      'keywordMarker': '[Riegel]',
      'keywordCalendarIds': <dynamic>[],
      'windows': windows,
      'activeWindows': <dynamic>[],
    },
  });

  Widget screen(LockStatus s) =>
      MaterialApp(home: CalendarScreen(status: s, channel: RiegelChannel(channel)));

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub();
    await tester.pumpWidget(screen(status(permission: false)));

    expect(find.textContaining('Berechtigung'), findsOneWidget);
  });

  testWidgets('ausgeschaltet bleibt die Kalenderliste verborgen', (tester) async {
    stub();
    await tester.pumpWidget(screen(status()));

    expect(find.text('KALENDER DES GERÄTS'), findsNothing);
  });

  testWidgets('eingeschaltet zeigt Kalenderliste und Stichwortabschnitt', (
    tester,
  ) async {
    stub(
      kalender: [
        {'id': 'cal1', 'name': 'Privat', 'account': 'ich@example.com'},
      ],
    );
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('KALENDER DES GERÄTS'), findsOneWidget);
    // Zweimal: in der Zuordnungsliste und als Ankreuzfeld der Stichwortregel.
    expect(find.text('Privat'), findsNWidgets(2));
    expect(find.text('STICHWORTREGEL'), findsOneWidget);
  });

  testWidgets('zugeordneter Kalender zeigt die Wahl der Trefferart', (
    tester,
  ) async {
    stub(
      kalender: [
        {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
      ],
    );
    await tester.pumpWidget(
      screen(
        status(
          enabled: true,
          rules: {
            'cal1': {'profileId': 'p1', 'match': 'ALL'},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alle Termine'), findsOneWidget);
    expect(find.text('nur Stichwort'), findsOneWidget);
  });

  testWidgets('nicht zugeordneter Kalender zeigt keine Trefferart', (
    tester,
  ) async {
    stub(
      kalender: [
        {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
      ],
    );
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('alle Termine'), findsNothing);
  });

  testWidgets('Umschalten auf nur Stichwort wird gespeichert', (tester) async {
    stub(
      kalender: [
        {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
      ],
    );
    await tester.pumpWidget(
      screen(
        status(
          enabled: true,
          rules: {
            'cal1': {'profileId': 'p1', 'match': 'ALL'},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('nur Stichwort'));
    await tester.pumpAndSettle();

    final regeln = gespeichert!['calendarRules'] as Map<dynamic, dynamic>;
    expect((regeln['cal1'] as Map<dynamic, dynamic>)['match'], 'KEYWORD');
  });

  testWidgets('Vorschau nennt die naechsten Termine', (tester) async {
    stub();
    final jetzt = DateTime.now();
    await tester.pumpWidget(
      screen(
        status(
          enabled: true,
          windows: [
            {
              'eventId': 'e1',
              'title': 'Konzept schreiben',
              'startsAt': jetzt.add(const Duration(hours: 1)).millisecondsSinceEpoch,
              'endsAt': jetzt.add(const Duration(hours: 2)).millisecondsSinceEpoch,
              'profileId': 'p1',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konzept schreiben'), findsOneWidget);
  });
}
