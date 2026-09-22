import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/calendar_screen.dart';
import 'package:nfc_riegel/lock_status.dart';
import 'package:nfc_riegel/profile_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  Map<dynamic, dynamic>? gespeichert;

  void stub({
    required bool usageGranted,
    List<Map<String, String>> kalender = const [],
    Map<String, dynamic>? chipLock,
  }) {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'usageAccessGranted':
              return usageGranted;
            case 'updateProfile':
              gespeichert = call.arguments as Map<dynamic, dynamic>;
              return true;
            case 'openUsageAccessSettings':
              return true;
            case 'deviceCalendars':
              return kalender;
            case 'getState':
              // `_oeffneKalender` fragt den Zustand ab, bevor sie den
              // Kalender-Schirm öffnet — ohne diesen Fall bliebe er null.
              return {
                'profiles': <dynamic>[],
                'tags': <dynamic>[],
                'timeLocks': <dynamic>[],
                'chipLock': chipLock,
              };
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// `ensureVisible` allein reicht bei der langen Liste nicht: Elemente weit
  /// unten (etwa im Abschnitt RUHE) sind ausserhalb der Vorbau-Reichweite der
  /// Sliver-Liste noch gar nicht im Baum. Erst dorthin scrollen, dann sichtbar
  /// machen.
  Future<void> scrolleZu(WidgetTester tester, Finder finder) async {
    final scrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  const profil = ProfileInfo(
    id: 'p1',
    name: 'Arbeit',
    blockedPackages: [],
    mode: LockMode.timer,
    durationMinutes: 60,
    untilAt: null,
    pinCalendarEnd: false,
        timedRelease: false,
    pauseEnabled: false,
    pauseStepMinutes: 15,
    pauseBaseSeconds: 5,
    pauseResetMinutes: 15,
    quietEnabled: false,
    quietScope: QuietScope.alle,
    quietNumbers: [],
    quietAfterEventMinutes: 0,
    quietWhileLocked: true,
    quietSchedules: [],
  );

  /// Dasselbe Profil im Modus „Offen" — nur dort gibt es die Freigabe.
  Widget offenerSchirm() => MaterialApp(
    home: ProfileScreen(
      profile: const ProfileInfo(
        id: 'p1',
        name: 'Arbeit',
        blockedPackages: [],
        mode: LockMode.open,
        durationMinutes: 60,
        untilAt: null,
        pinCalendarEnd: false,
        timedRelease: false,
        pauseEnabled: false,
        pauseStepMinutes: 15,
        pauseBaseSeconds: 5,
        pauseResetMinutes: 15,
        quietEnabled: false,
        quietScope: QuietScope.alle,
        quietNumbers: [],
        quietAfterEventMinutes: 0,
        quietWhileLocked: true,
        quietSchedules: [],
      ),
      channel: RiegelChannel(channel),
    ),
  );

  Widget screen() => MaterialApp(
    home: ProfileScreen(profile: profil, channel: RiegelChannel(channel)),
  );

  Widget kalenderSchirm({
    bool an = true,
    ProfileInfo profile = profil,
  }) => MaterialApp(
    home: ProfileScreen(
      profile: profile,
      channel: RiegelChannel(channel),
      calendar: CalendarInfo.fromMap({
        'enabled': an,
        'permissionGranted': true,
        'keywordMarker': '[Riegel]',
      }),
    ),
  );

  const privat = {'id': 'cal1', 'name': 'Privat', 'account': 'ich@example.com'};

  testWidgets('mit Berechtigung erscheint der Schalter', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Der neue Abschnitt KALENDER schiebt die Atempause aus dem
    // Anfangsfenster der Liste — ohne Scrollen ist der Schalter noch gar
    // nicht aufgebaut.
    await scrolleZu(tester, find.text('Atempause'));
    expect(find.text('Atempause'), findsOneWidget);
  });

  testWidgets('ohne Berechtigung erscheint der Hinweis statt der Regler', (
    tester,
  ) async {
    stub(usageGranted: false);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Wie oben: der Abschnitt KALENDER davor schiebt den Hinweis aus dem
    // Anfangsfenster der Liste.
    await scrolleZu(tester, find.textContaining('Nutzungsdaten'));
    expect(find.textContaining('Nutzungsdaten'), findsOneWidget);
    expect(find.text('Zugriff erlauben'), findsOneWidget);
    // Nicht auf `Slider` prüfen: das Profil steht auf „Auf Zeit" und zeigt
    // deshalb ohnehin den Dauer-Regler. Fehlen muss der Schalter der Atempause.
    expect(find.text('Atempause'), findsNothing);
  });

  testWidgets('eingeschaltete Atempause landet im Kanalaufruf', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Der Profilschirm ist laenger als das 800x600-Fenster des Tests; ohne
    // Scrollen liegt der Schalter ausserhalb und der Tipp geht ins Leere.
    // Den Schalter ueber seinen Titel suchen: unter der Atempause stehen
    // inzwischen die Schalter der Ruhe.
    final pause = find.widgetWithText(SwitchListTile, 'Atempause');
    await scrolleZu(tester, pause);
    await tester.tap(pause);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['pauseEnabled'], isTrue);
    expect(gespeichert!['pauseStepMinutes'], 15);
  });

  testWidgets('Zahl laesst sich tippen statt schieben', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Das Profil steht auf „Auf Zeit"; der erste Stift gehoert zur Dauer.
    await tester.ensureVisible(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '37');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    expect(find.text('37 Minuten'), findsOneWidget);
  });

  testWidgets('unmoegliche Zahl wird auf die Grenze geklemmt', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '9999');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    expect(find.text('480 Minuten'), findsOneWidget);
  });

  testWidgets('bei Modus Offen erscheint der Schalter der Freigabe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(offenerSchirm());
    await tester.pumpAndSettle();

    expect(find.text('Freigabe auf Zeit'), findsOneWidget);
  });

  testWidgets('bei Modus Auf Zeit fehlt der Schalter der Freigabe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Freigabe auf Zeit'), findsNothing);
  });

  testWidgets('eingeschaltete Freigabe landet im Kanalaufruf', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(offenerSchirm());
    await tester.pumpAndSettle();

    final schalter = find.widgetWithText(SwitchListTile, 'Freigabe auf Zeit');
    await tester.ensureVisible(schalter);
    await tester.pumpAndSettle();
    await tester.tap(schalter);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['timedRelease'], isTrue);
  });

  testWidgets('der Klingelmodus erscheint erst mit eingeschalteter Ruhe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Klingelmodus während der Ruhe'), findsNothing);

    final ruheSchalter = find.widgetWithText(
      SwitchListTile,
      'Anrufe stumm schalten',
    );
    await scrolleZu(tester, ruheSchalter);
    await tester.tap(ruheSchalter);
    await tester.pumpAndSettle();

    expect(find.text('Klingelmodus während der Ruhe'), findsOneWidget);
  });

  testWidgets('der gewaehlte Klingelmodus wird gespeichert', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          profile: const ProfileInfo(
            id: 'p1',
            name: 'Arbeit',
            blockedPackages: [],
            mode: LockMode.timer,
            durationMinutes: 60,
            untilAt: null,
            pinCalendarEnd: false,
            timedRelease: false,
            pauseEnabled: false,
            pauseStepMinutes: 15,
            pauseBaseSeconds: 5,
            pauseResetMinutes: 15,
            quietEnabled: true,
            quietScope: QuietScope.alle,
            quietNumbers: [],
            quietAfterEventMinutes: 0,
            quietWhileLocked: true,
            quietSchedules: [],
          ),
          channel: RiegelChannel(channel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final auswahl = find.byType(DropdownButton<RingerMode>);
    await scrolleZu(tester, auswahl);
    await tester.tap(auswahl);
    await tester.pumpAndSettle();
    // Der geöffnete Klapp-Vorhang zeigt jeden Eintrag ein zweites Mal; der
    // letzte Treffer gehört zum Vorhang, nicht zum geschlossenen Knopf.
    await tester.tap(find.text('Vibrieren').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['quietRinger'], 'VIBRIEREN');
  });

  testWidgets('ausgeschalteter Kalender zeigt nur den Hinweis', (tester) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(kalenderSchirm(an: false));
    await tester.pumpAndSettle();

    await scrolleZu(tester, find.text('Die Kalenderfunktion ist aus.'));
    expect(find.text('Zum Kalender'), findsOneWidget);
    expect(find.text('Privat'), findsNothing);
  });

  testWidgets('gespeicherte Auswahl steht in der Kalenderzeile', (tester) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(
      kalenderSchirm(
        profile: const ProfileInfo(
          id: 'p1',
          name: 'Arbeit',
          blockedPackages: [],
          mode: LockMode.timer,
          durationMinutes: 60,
          untilAt: null,
          pinCalendarEnd: false,
          timedRelease: false,
          pauseEnabled: false,
          pauseStepMinutes: 15,
          pauseBaseSeconds: 5,
          pauseResetMinutes: 15,
          quietEnabled: false,
          quietScope: QuietScope.alle,
          quietNumbers: [],
          quietAfterEventMinutes: 0,
          quietWhileLocked: true,
          quietSchedules: [],
          calendars: {'cal1': CalendarMatch.all},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrolleZu(tester, find.byKey(const ValueKey('kalender-cal1')));
    expect(find.text('Privat'), findsOneWidget);
    expect(find.text('alle Termine'), findsOneWidget);
  });

  testWidgets('Kalenderauswahl und Stichwort ueberall werden gesichert', (
    tester,
  ) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(kalenderSchirm());
    await tester.pumpAndSettle();

    final auswahl = find.byKey(const ValueKey('kalender-cal1'));
    await scrolleZu(tester, auswahl);
    await tester.tap(auswahl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('nur Stichwort').last);
    await tester.pumpAndSettle();

    final ueberall = find.textContaining('in jedem Kalender');
    await scrolleZu(tester, ueberall);
    await tester.tap(ueberall);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['calendars'], {'cal1': 'KEYWORD'});
    expect(gespeichert!['keywordEverywhere'], isTrue);
  });

  testWidgets(
    'waehrend einer Sperre oeffnet "Zum Kalender" den Kalender-Schirm nicht',
    (tester) async {
      // Der Hauptschirm schaltet den Kalender-Eintrag waehrend jeder Sperre
      // ab; dieser Knopf im Profil darf das nicht umgehen.
      stub(usageGranted: true, chipLock: {'profileId': 'p1'});
      await tester.pumpWidget(kalenderSchirm(an: false));
      await tester.pumpAndSettle();

      await scrolleZu(tester, find.text('Zum Kalender'));
      await tester.tap(find.text('Zum Kalender'));
      await tester.pumpAndSettle();

      expect(find.text('Während einer Sperre nicht möglich'), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);
    },
  );
}
