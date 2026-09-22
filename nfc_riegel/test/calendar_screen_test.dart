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

  void stub() {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
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

  Map<String, dynamic> profil(String id, String name) => {
    'id': id,
    'name': name,
    'blockedPackages': <dynamic>[],
    'defaultMode': 'TIMER',
    'durationMinutes': 60,
    'pinCalendarEnd': false,
  };

  LockStatus status({
    bool enabled = false,
    bool permission = true,
    List<Map<String, dynamic>> windows = const [],
  }) => LockStatus.fromMap({
    'profiles': [profil('p1', 'Arbeit'), profil('p2', 'Nacht')],
    'tags': <dynamic>[],
    'timeLocks': <dynamic>[],
    'calendar': {
      'enabled': enabled,
      'permissionGranted': permission,
      'keywordMarker': '[Riegel]',
      'windows': windows,
      'activeWindows': <dynamic>[],
    },
  });

  Widget screen(LockStatus s) => MaterialApp(
    home: CalendarScreen(status: s, channel: RiegelChannel(channel)),
  );

  Map<String, dynamic> fenster(String eventId, String profileId) {
    final jetzt = DateTime.now();
    return {
      'eventId': eventId,
      'title': 'Konzept schreiben',
      'startsAt': jetzt.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'endsAt': jetzt.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      'profileId': profileId,
    };
  }

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub();
    await tester.pumpWidget(screen(status(permission: false)));

    expect(find.textContaining('Berechtigung'), findsOneWidget);
  });

  testWidgets('ausgeschaltet bleibt das Stichwort verborgen', (tester) async {
    stub();
    await tester.pumpWidget(screen(status()));

    expect(find.text('Stichwort im Termintitel'), findsNothing);
  });

  testWidgets('eingeschaltet zeigt Stichwort und Verweis aufs Profil, keine Zuordnung', (
    tester,
  ) async {
    stub();
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('Stichwort im Termintitel'), findsOneWidget);
    expect(find.textContaining('im jeweiligen Profil'), findsOneWidget);
    expect(find.text('KALENDER DES GERÄTS'), findsNothing);
    expect(find.text('STICHWORTREGEL'), findsNothing);
  });

  testWidgets('Stichwort speichern schickt nur Schalter und Stichwort', (
    tester,
  ) async {
    stub();
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '[Fokus]');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(gespeichert, {'enabled': true, 'keywordMarker': '[Fokus]'});
  });

  testWidgets('Vorschau nennt Termin einmal mit allen Profilen', (tester) async {
    stub();
    await tester.pumpWidget(
      screen(
        status(enabled: true, windows: [fenster('e1', 'p1'), fenster('e1', 'p2')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konzept schreiben'), findsOneWidget);
    expect(find.textContaining('Arbeit, Nacht'), findsOneWidget);
  });
}
