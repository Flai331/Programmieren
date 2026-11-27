import 'dart:io';
import 'dart:typed_data';

import 'package:beebrain/services/image_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein paar erkennbare Bytes. Ob es ein gültiges PNG ist, interessiert den
/// Dienst nicht — er beschafft Bytes, er zeigt sie nicht an.
final Uint8List _bild = Uint8List.fromList([1, 2, 3, 4, 5]);
final Uint8List _anderes = Uint8List.fromList([9, 9, 9]);

void main() {
  late Directory ordner;
  late ImageCacheService dienst;

  setUp(() async {
    ordner = await Directory.systemTemp.createTemp('bildspeicher_test');
    dienst = ImageCacheService()
      ..directoryForTests = ordner
      ..downloads = 0
      ..downloaderForTests = null;
  });

  tearDown(() async {
    // Der Dienst ist ein Singleton: die Testhaken müssen weg, sonst nimmt
    // der nächste Test sie mit.
    dienst
      ..directoryForTests = null
      ..downloaderForTests = null
      ..downloads = 0;
    if (await ordner.exists()) await ordner.delete(recursive: true);
  });

  group('Pfad auf dem Gerät', () {
    // Das ist bei dieser App der Normalfall: `design_settings.logo_url`
    // enthält den Pfad, den der Bildwähler zurückgegeben hat.

    test('wird gelesen, ohne zu funken', () async {
      final datei = File('${ordner.path}/logo_1700000000.png');
      await datei.writeAsBytes(_bild);
      dienst.downloaderForTests = (_) async => throw StateError('nicht funken');

      expect(await dienst.bytes(datei.path), _bild);
      expect(dienst.downloads, 0);
    });

    test('als file://-Adresse ebenso', () async {
      final datei = File('${ordner.path}/kopf.jpg');
      await datei.writeAsBytes(_bild);
      dienst.downloaderForTests = (_) async => throw StateError('nicht funken');

      expect(await dienst.bytes(datei.uri.toString()), _bild);
      expect(dienst.downloads, 0);
    });

    test('ein Pfad, hinter dem nichts liegt, gibt null — und wirft nicht',
        () async {
      expect(await dienst.bytes('${ordner.path}/gibtsnicht.png'), isNull);
      expect(dienst.downloads, 0);
    });

    test('eine leere Datei gilt als nicht vorhanden', () async {
      final datei = File('${ordner.path}/leer.png');
      await datei.writeAsBytes(const []);
      expect(await dienst.bytes(datei.path), isNull);
    });
  });

  group('Netzadresse', () {
    const adresse = 'https://example.org/logo.png';

    test('wird einmal geholt und dann aufbewahrt', () async {
      dienst.downloaderForTests = (_) async => _bild;

      expect(await dienst.bytes(adresse), _bild);
      expect(dienst.downloads, 1);

      // Zweiter Aufruf: jetzt muss die Ablage antworten. Der Lader würde
      // andere Bytes liefern — kommen die zurück, war es kein Treffer.
      dienst.downloaderForTests = (_) async => _anderes;
      expect(await dienst.bytes(adresse), _bild);
      expect(dienst.downloads, 1);
    });

    test('die Ablage übersteht einen App-Start', () async {
      dienst.downloaderForTests = (_) async => _bild;
      await dienst.bytes(adresse);

      // Ein neuer App-Start hat kein Gedächtnis im Arbeitsspeicher, aber
      // dieselbe Ablage. Das ist genau der Unterschied zu PdfMemoryCache.
      final frisch = ImageCacheService()
        ..directoryForTests = ordner
        ..downloads = 0
        ..downloaderForTests = (_) async => throw StateError('nicht funken');

      expect(await frisch.bytes(adresse), _bild);
      expect(frisch.downloads, 0);
    });

    test('eine Zeitgrenze gibt null statt zu hängen', () async {
      dienst.downloaderForTests = (_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return _bild;
      };

      final uhr = Stopwatch()..start();
      final ergebnis = await dienst.bytes(
        adresse,
        timeout: const Duration(milliseconds: 50),
      );
      uhr.stop();

      expect(ergebnis, isNull);
      expect(uhr.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('ein Fehler beim Laden gibt null und wirft nicht', () async {
      dienst.downloaderForTests = (_) async => throw const SocketException('x');
      expect(await dienst.bytes(adresse), isNull);
    });

    test('nichts geladen heißt nichts abgelegt', () async {
      dienst.downloaderForTests = (_) async => throw const SocketException('x');
      await dienst.bytes(adresse);

      dienst.downloaderForTests = (_) async => _bild;
      expect(await dienst.bytes(adresse), _bild,
          reason: 'der Fehlschlag darf nicht als leere Datei liegen bleiben');
      expect(dienst.downloads, 2);
    });

    test('leere Antwort gibt null', () async {
      dienst.downloaderForTests = (_) async => Uint8List(0);
      expect(await dienst.bytes(adresse), isNull);
    });

    test('forget lässt neu holen', () async {
      dienst.downloaderForTests = (_) async => _bild;
      await dienst.bytes(adresse);

      await dienst.forget(adresse);
      dienst.downloaderForTests = (_) async => _anderes;
      expect(await dienst.bytes(adresse), _anderes);
      expect(dienst.downloads, 2);
    });

    test('clear räumt alles weg', () async {
      dienst.downloaderForTests = (_) async => _bild;
      await dienst.bytes(adresse);
      await dienst.bytes('https://example.org/kopf.png');

      await dienst.clear();
      dienst.downloads = 0;
      expect(await dienst.bytes(adresse), _bild);
      expect(dienst.downloads, 1);
    });
  });

  group('leere Angaben', () {
    test('null und Leerzeichen geben null, ohne zu funken', () async {
      dienst.downloaderForTests = (_) async => throw StateError('nicht funken');
      expect(await dienst.bytes(null), isNull);
      expect(await dienst.bytes(''), isNull);
      expect(await dienst.bytes('   '), isNull);
      expect(dienst.downloads, 0);
    });
  });

  group('dateinameFor', () {
    test('ist für dieselbe Adresse immer derselbe Name', () {
      const a = 'https://example.org/bilder/logo.png';
      expect(ImageCacheService.dateinameFor(a),
          ImageCacheService.dateinameFor(a));
    });

    test('unterscheidet Adressen', () {
      expect(
        ImageCacheService.dateinameFor('https://example.org/a.png'),
        isNot(ImageCacheService.dateinameFor('https://example.org/b.png')),
      );
    });

    test('behält eine brauchbare Endung und wirft den Rest weg', () {
      expect(ImageCacheService.dateinameFor('https://x.de/a.PNG'),
          endsWith('.png'));
      expect(ImageCacheService.dateinameFor('https://x.de/a.jpeg'),
          endsWith('.jpeg'));
      expect(ImageCacheService.dateinameFor('https://x.de/a.exe'),
          isNot(contains('.')));
      expect(ImageCacheService.dateinameFor('https://x.de/ohne'),
          isNot(contains('.')));
    });

    test('ist ein fester Wert, nicht String.hashCode', () {
      // Der Name muss über App-Starts hinweg gleich bleiben, sonst wäre die
      // Ablage nach jedem Start wertlos. `String.hashCode` ist in Dart
      // ausdrücklich nicht stabil, also wird selbst gerechnet — und genau
      // dieser Wert hier ist der Vertrag. Er stammt nicht aus dem Code,
      // sondern aus FNV-1a über 64 Bit, unabhängig nachgerechnet:
      //   h = 0xcbf29ce484222325; je Zeichen: h ^= c; h *= 0x100000001b3
      expect(ImageCacheService.dateinameFor('https://example.org/logo.png'),
          'fac9531c3ee39793.png');
    });
  });
}
