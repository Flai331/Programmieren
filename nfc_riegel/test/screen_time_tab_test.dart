import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/riegel_channel.dart';
import 'package:nfc_riegel/screen_time_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  void stub({
    required bool granted,
    List<Map<String, dynamic>> apps = const [],
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'usageAccessGranted':
              return granted;
            case 'screenTimeToday':
              return apps;
            case 'openUsageAccessSettings':
              return true;
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget tab() => MaterialApp(
    home: Scaffold(body: ScreenTimeTab(channel: RiegelChannel(channel))),
  );

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub(granted: false);
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nutzungsdaten'), findsOneWidget);
    expect(find.text('Zugriff erlauben'), findsOneWidget);
  });

  testWidgets('mit Daten erscheinen Tagessumme und Liste', (tester) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 3600000},
        {'name': 'Gmail', 'packageName': 'com.google.android.gm', 'millis': 1200000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
    // 60 min + 20 min
    expect(find.text('1 h 20 min'), findsOneWidget);
  });

  testWidgets('Apps unter einer Minute fehlen, die Fusszeile nennt ihre Zahl', (
    tester,
  ) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 600000},
        {'name': 'Uhr', 'packageName': 'com.google.android.deskclock', 'millis': 20000},
        {'name': 'Karten', 'packageName': 'com.google.android.apps.maps', 'millis': 5000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Uhr'), findsNothing);
    expect(find.text('2 weitere unter 1 Minute'), findsOneWidget);
  });

  testWidgets('ohne kurze Apps fehlt die Fusszeile', (tester) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 600000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.textContaining('unter 1 Minute'), findsNothing);
  });

  testWidgets('Hintergrundzeit steht in der Kopfzeile und an der App', (
    tester,
  ) async {
    stub(
      granted: true,
      apps: [
        {
          'name': 'Spotify',
          'packageName': 'com.spotify.music',
          'millis': 600000,
          'backgroundMillis': 3600000,
        },
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    // Die grosse Zahl bleibt die Zeit am Schirm — zweimal zu finden, weil bei
    // einer einzigen App die Tagessumme und ihre Zeile denselben Wert tragen.
    expect(find.text('10 min'), findsNWidgets(2));
    expect(find.text('+ 1 h 0 min im Hintergrund'), findsOneWidget);
    expect(find.text('+ 1 h 0 min Hintergrund'), findsOneWidget);
  });

  testWidgets('App nur im Hintergrund bleibt in der Liste', (tester) async {
    stub(
      granted: true,
      apps: [
        {
          'name': 'Radio',
          'packageName': 'com.radio',
          'millis': 0,
          'backgroundMillis': 1800000,
        },
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
    expect(find.textContaining('unter 1 Minute'), findsNothing);
  });

  testWidgets('Betreten des Reiters liest neu', (tester) async {
    var abrufe = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'usageAccessGranted':
              return true;
            case 'screenTimeToday':
              abrufe++;
              return <Map<String, dynamic>>[];
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: const TabBar(
              tabs: [Tab(text: 'Sperre'), Tab(text: 'Screenzeit')],
            ),
            body: TabBarView(
              children: [
                const Text('Sperre'),
                ScreenTimeTab(channel: RiegelChannel(channel), tabIndex: 1),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nachDemBau = abrufe;

    await tester.tap(find.text('Screenzeit'));
    await tester.pumpAndSettle();

    expect(abrufe, greaterThan(nachDemBau));
  });
}
