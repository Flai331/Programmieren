// Live-Test gegen das echte Notion — prüft den vollständigen Sendeweg
// des Moduls in einer echten Dart-Laufzeit mit echten HTTP-Aufrufen.
//
// Läuft nur mit Token, sonst überspringt er sich selbst:
//
//   flutter test test/notion_live_test.dart --dart-define=NOTION_TOKEN=…
//
// Er legt Berichte unter dem Wegwerf-App-Key `livetest` an. Beim ersten
// Lauf richtet das Modul dafür selbst eine Seite samt Datenbank unter der
// Fehlerzentrale ein — genau der Weg, den auch jede neue App geht.
// Die Testseite darf danach in Notion archiviert werden.

import 'dart:io';

import 'package:fehlerbericht/fehlerbericht.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = String.fromEnvironment('NOTION_TOKEN', defaultValue: '');

/// Nur für Testumgebungen hinter einem Proxy (Firmennetz, CI-Sandbox).
///
/// Dart nutzt HTTPS_PROXY nicht von allein — anders als etwa Python. Ohne
/// diese Weiche laufen die Aufrufe am Proxy vorbei und die Antwort ist
/// irreführend (hier kam HTTP 400 zurück, was wie ein Fehler im Modul
/// aussah). Die App selbst braucht das nicht: auf Telefonen gibt es
/// keinen solchen Proxy.
class _ProxyOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final ctx = context ?? SecurityContext(withTrustedRoots: true);
    final bundle =
        Platform.environment['SSL_CERT_FILE'] ?? '/root/.ccr/ca-bundle.crt';
    if (File(bundle).existsSync()) {
      try {
        ctx.setTrustedCertificates(bundle);
      } catch (_) {
        // Schon gesetzt oder nicht lesbar — dann bleibt es beim Standard.
      }
    }
    return super.createHttpClient(ctx)
      ..findProxy = (uri) => HttpClient.findProxyFromEnvironment(
            uri,
            environment: Platform.environment,
          );
  }
}

void main() {
  setUpAll(() {
    final proxy = Platform.environment['HTTPS_PROXY'] ??
        Platform.environment['https_proxy'] ??
        '';
    if (proxy.isNotEmpty) {
      HttpOverrides.global = _ProxyOverrides();
      debugPrint('LIVE: nutze Proxy $proxy');
    }
  });

  testWidgets('Bericht landet wirklich in Notion',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    if (_token.isEmpty) {
      markTestSkipped('Kein NOTION_TOKEN gesetzt — Live-Test übersprungen.');
      return;
    }

    // Fehlerbericht.runApp hängt sich in FlutterError.onError ein. Das
    // muss vor den expect()-Aufrufen zurückgesetzt werden: sonst meldet
    // das Modul den fehlgeschlagenen Test als Absturz und das Binding
    // bricht mit einer unverständlichen Assertion ab, statt die
    // eigentliche Ursache zu zeigen.
    final urspruenglicherFehlerkanal = FlutterError.onError;

    Fehlerbericht.runApp(
      appKey: 'livetest',
      appName: 'Live-Test (automatisch)',
      version: '0.0.0',
      builder: () => const MaterialApp(home: Scaffold(body: Text('Live'))),
    );
    await tester.pumpAndSettle();

    final marke = DateTime.now().millisecondsSinceEpoch;
    Fehlerbericht.logSeite('Live-Test');
    Fehlerbericht.logAktion('Testlauf gestartet', kontext: {'marke': '$marke'});

    // runAsync: echte Zeit und echte Netzwerk-Ein-/Ausgabe. Ohne das
    // liefe der Test in der Fake-Zeit des Test-Bindings und die
    // HTTP-Aufrufe kämen nie zurück.
    final erfolg = await tester.runAsync(() async {
          Fehlerbericht.logFehler(
            'Live-Test $marke — automatisch erzeugt, darf gelöscht werden',
            kontext: 'notion_live_test',
            stack: StackTrace.current,
          );
          for (var i = 0; i < 60; i++) {
            if (i % 10 == 0) {
              debugPrint('LIVE: warte ${i}s …');
            }
            await Future<void>.delayed(const Duration(seconds: 1));
            final p = Fehlerbericht.protokoll;
            if (p.any((z) => z.contains('Notion: Bericht angelegt'))) {
              return true;
            }
            if (p.any(
                (z) => z.contains('fehlgeschlagen') && z.contains('Notion'))) {
              return false;
            }
          }
          return false;
        }) ??
        false;

    FlutterError.onError = urspruenglicherFehlerkanal;

    final protokoll = Fehlerbericht.protokoll.join('\n');
    expect(erfolg, isTrue,
        reason: 'Kein Bericht in Notion angelegt. Protokoll:\n$protokoll');

    // Der Weg muss über Notion gegangen sein, nicht über E-Mail.
    expect(protokoll, isNot(contains('Kein NOTION_TOKEN gesetzt')));
    expect(protokoll, isNot(contains('errno = 7')));

    // Die Erfolgszeile enthält die URL des angelegten Berichts.
    final zeile = Fehlerbericht.protokoll
        .firstWhere((z) => z.contains('Notion: Bericht angelegt'));
    expect(zeile, contains('notion.'));
    debugPrint('LIVE-ERGEBNIS: $zeile');
  });
}
