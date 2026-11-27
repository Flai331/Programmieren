import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beebrain/services/image_cache_service.dart';
import 'package:beebrain/widgets/cached_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zwei gültige PNGs, je 1×1 Pixel — eines rot, eines blau. Echt müssen sie
/// sein, weil Flutter sie entschlüsselt, und **verschieden**, weil sonst ein
/// Test nicht merken könnte, ob überhaupt neu geladen wurde.
final _rot = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4z8AAAAMB'
    'AQD3A0FDAAAAAElFTkSuQmCC');
final _blau = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNgYPgPAAED'
    'AQA2dBFAAAAAAElFTkSuQmCC');

/// Welche Bytes gerade angezeigt werden — nicht nur, *ob* ein Bild da ist.
Uint8List _gezeigteBytes(WidgetTester tester) {
  final bild = tester.widget<Image>(find.byType(Image));
  return (bild.image as MemoryImage).bytes;
}

void main() {
  late Directory ordner;
  late File logo;
  late File a;
  late File b;
  late String fehlt;

  // Alle Dateien entstehen hier und nicht im Testkörper: der läuft in der
  // Zone der Testuhr, und echte Ein-/Ausgabe wird darin nie fertig — ein
  // `await datei.writeAsBytes(...)` im Test bliebe stehen, ohne Fehler.
  setUp(() async {
    ordner = await Directory.systemTemp.createTemp('cached_picture_test');
    logo = File('${ordner.path}/logo.png');
    a = File('${ordner.path}/a.png');
    b = File('${ordner.path}/b.png');
    fehlt = '${ordner.path}/gibtsnicht.png';
    await logo.writeAsBytes(_rot);
    await a.writeAsBytes(_rot);
    await b.writeAsBytes(_blau);
    CachedPicture.forgetAllForTests();
    ImageCacheService()
      ..directoryForTests = ordner
      ..downloads = 0
      ..downloaderForTests = null;
  });

  tearDown(() async {
    CachedPicture.forgetAllForTests();
    ImageCacheService()
      ..directoryForTests = null
      ..downloaderForTests = null
      ..downloads = 0;
    if (await ordner.exists()) await ordner.delete(recursive: true);
  });

  /// Einbauen und warten, bis das Bild da ist.
  ///
  /// Das Lesen einer Datei ist echte Ein-/Ausgabe, und die läuft in einem
  /// Widget-Test nur innerhalb von [WidgetTester.runAsync] weiter — die
  /// Testuhr allein bewegt sie nicht. Zeichnen darf dagegen *nicht* in
  /// `runAsync` passieren: `pumpWidget` ruft selbst `pump`, und das bleibt
  /// dort hängen. Also der Dreischritt: einbauen, echte Zeit vergehen
  /// lassen, neu zeichnen.
  ///
  /// Gewartet wird nicht auf die Uhr, sondern auf genau den Ladevorgang,
  /// den das Widget selbst abwartet. Der Weg zum Bild hat mehrere Stufen
  /// (ist die Datei da, wie groß ist sie, Bytes lesen), jede läuft in der
  /// echten Zeit; wie viele Runden das auf einer belasteten Maschine
  /// braucht, ist nicht vorhersagbar. Feste Wartezeiten flattern deshalb —
  /// das war hier schon einmal zu sehen.
  Future<void> zeige(WidgetTester tester, String adresse, Widget kind) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: kind)));

    // Abwarten geht nicht durch `await`: der Ladevorgang ist in der Zone
    // der Testuhr entstanden, seine Fortsetzungen laufen erst bei `pump` —
    // ein `await` in `runAsync` verklemmt sich gegenseitig. Also wird nur
    // *vermerkt*, wann er fertig ist, und abwechselnd echte Zeit und
    // Zeichnen durchgelassen, bis das so ist.
    var fertig = false;
    final laufend = CachedPicture.pendingForTests(adresse);
    if (laufend == null) {
      fertig = true;
    } else {
      laufend.whenComplete(() => fertig = true);
    }

    for (var runde = 0; runde < 200 && !fertig; runde++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    expect(fertig, isTrue, reason: 'der Ladevorgang wurde nie fertig');
    await tester.pump();
  }

  testWidgets('ein Bild vom Gerät erscheint', (tester) async {
    await zeige(tester, logo.path,
        CachedPicture(logo.path, width: 40, height: 40));

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ein Pfad, hinter dem nichts liegt, zeigt den Ersatz',
      (tester) async {
    await zeige(
      tester,
      fehlt,
      CachedPicture(fehlt, error: const Text('Bild nicht ladbar')),
    );

    expect(find.text('Bild nicht ladbar'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('ohne Ersatz bleibt die Fläche leer, ohne Fehler',
      (tester) async {
    await zeige(
        tester, fehlt, CachedPicture(fehlt, width: 30, height: 30));

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('dieselbe Adresse wird nur einmal geholt', (tester) async {
    const adresse = 'https://example.org/logo.png';
    ImageCacheService().downloaderForTests = (_) async => _rot;

    await zeige(
      tester,
      adresse,
      const Column(children: [
        CachedPicture(adresse, width: 20, height: 20),
        CachedPicture(adresse, width: 20, height: 20),
      ]),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(ImageCacheService().downloads, 1,
        reason: 'zwei Bilder, eine Adresse — einmal holen genügt');
  });

  testWidgets('eine neue Adresse wird neu geholt', (tester) async {
    await zeige(
        tester, a.path, CachedPicture(a.path, width: 20, height: 20));
    expect(_gezeigteBytes(tester), _rot);

    // Derselbe Platz im Baum, andere Adresse: didUpdateWidget muss
    // nachladen, sonst klebt das alte Bild dort. Geprüft wird deshalb
    // nicht, *dass* ein Bild zu sehen ist, sondern **welches** — die
    // Dateien unterscheiden sich genau dafür.
    await zeige(
        tester, b.path, CachedPicture(b.path, width: 20, height: 20));
    expect(_gezeigteBytes(tester), _blau);
    expect(tester.takeException(), isNull);
  });
}
