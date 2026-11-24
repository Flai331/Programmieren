import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/services/update_service.dart';

/// Eine Antwort von `releases/latest`, so wie GitHub sie schickt — nur auf
/// die Felder gekürzt, die gelesen werden.
Map<String, dynamic> veroeffentlichung({
  Object? tag = 'build-13',
  Object? body = 'Neu: Eimer mit der Kamera lesen.',
  List<Map<String, Object?>>? anhaenge,
}) {
  return <String, dynamic>{
    'tag_name': tag,
    'name': 'BeeBrain Build #13',
    'draft': false,
    'prerelease': false,
    'body': body,
    'assets': anhaenge ??
        [
          {
            'name': 'BeeBrain-build-13.apk',
            'browser_download_url':
                'https://github.com/Flai331/Programmieren/releases/download/'
                    'build-13/BeeBrain-build-13.apk',
            'size': 39845632,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
  };
}

void main() {
  group('Aus einer GitHub-Veröffentlichung eine Fassung lesen', () {
    test('build-13 wird als Build 13 gelesen', () {
      final fassung = UpdateInfo.fromRelease(veroeffentlichung());

      expect(fassung, isNotNull);
      expect(fassung!.buildNumber, 13);
      expect(fassung.tag, 'build-13');
      expect(fassung.downloadUrl, endsWith('BeeBrain-build-13.apk'));
      expect(fassung.sizeInBytes, 39845632);
      expect(fassung.notes, 'Neu: Eimer mit der Kamera lesen.');
    });

    test('Leerraum um den Tag stört nicht', () {
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(tag: ' build-7 '));

      expect(fassung?.buildNumber, 7);
      expect(fassung?.tag, 'build-7');
    });

    test('dreistellige Nummern werden ganz gelesen', () {
      // Nicht bloß Zierde: Ein Lesefehler, der aus 104 die 4 macht, würde
      // eine neuere Fassung für älter halten und nie aktualisieren.
      expect(
        UpdateInfo.fromRelease(veroeffentlichung(tag: 'build-104'))?.buildNumber,
        104,
      );
    });

    test('ein fremd benannter Tag ergibt keine Fassung', () {
      // Lieber nichts anbieten als eine Nummer erraten.
      for (final tag in [
        'v1.0.0',
        '13',
        'build-',
        'build-abc',
        'build-13-hotfix',
        'release-13',
        'Build-13', // Großschreibung ist ein anderer Tag
        '',
      ]) {
        expect(
          UpdateInfo.fromRelease(veroeffentlichung(tag: tag)),
          isNull,
          reason: 'Tag „$tag" sollte nicht als Fassung gelten',
        );
      }
    });

    test('ein Tag, der gar kein Text ist, ergibt keine Fassung', () {
      expect(UpdateInfo.fromRelease(veroeffentlichung(tag: 13)), isNull);
      expect(UpdateInfo.fromRelease(veroeffentlichung(tag: null)), isNull);
    });

    test('eine Veröffentlichung ohne Anhang ergibt keine Fassung', () {
      expect(UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [])), isNull);
    });

    test('nur ein .aab ergibt keine Fassung', () {
      // Ein App Bundle lässt sich auf dem Gerät nicht installieren.
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
        {
          'name': 'app-release.aab',
          'browser_download_url': 'https://example.invalid/app-release.aab',
          'size': 30000000,
        },
      ]));

      expect(fassung, isNull);
    });

    test('zwischen mehreren Anhängen wird das APK gefunden', () {
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
        {
          'name': 'mapping.txt',
          'browser_download_url': 'https://example.invalid/mapping.txt',
          'size': 4096,
        },
        {
          'name': 'BeeBrain-build-13.apk',
          'browser_download_url': 'https://example.invalid/BeeBrain.apk',
          'size': 39845632,
        },
        {
          'name': 'app-release.aab',
          'browser_download_url': 'https://example.invalid/app-release.aab',
          'size': 30000000,
        },
      ]));

      expect(fassung?.downloadUrl, 'https://example.invalid/BeeBrain.apk');
      expect(fassung?.sizeInBytes, 39845632);
    });

    test('zwei APKs ergeben keine Fassung, statt eines zu raten', () {
      // Dieselbe Regel wie beim Eimer-Code: Steht es gleichauf, wird nicht
      // geraten. Das falsche Paket zu installieren wäre schlimmer, als zu
      // sagen, dass es nicht geht.
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
        {
          'name': 'BeeBrain-build-13.apk',
          'browser_download_url': 'https://example.invalid/a.apk',
          'size': 1,
        },
        {
          'name': 'BeeBrain-build-13-arm64.apk',
          'browser_download_url': 'https://example.invalid/b.apk',
          'size': 2,
        },
      ]));

      expect(fassung, isNull);
    });

    test('die Endung wird ohne Rücksicht auf Groß- und Kleinschreibung erkannt',
        () {
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
        {
          'name': 'BeeBrain.APK',
          'browser_download_url': 'https://example.invalid/BeeBrain.APK',
          'size': 100,
        },
      ]));

      expect(fassung, isNotNull);
    });

    test('ein APK ohne Adresse ergibt keine Fassung', () {
      expect(
        UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
          {'name': 'BeeBrain.apk', 'size': 100},
        ])),
        isNull,
      );
      expect(
        UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
          {'name': 'BeeBrain.apk', 'browser_download_url': '', 'size': 100},
        ])),
        isNull,
      );
    });

    test('eine fehlende Größe wird zu 0, nicht zum Absturz', () {
      final fassung = UpdateInfo.fromRelease(veroeffentlichung(anhaenge: [
        {
          'name': 'BeeBrain.apk',
          'browser_download_url': 'https://example.invalid/BeeBrain.apk',
        },
      ]));

      expect(fassung?.sizeInBytes, 0);
      expect(fassung?.readableSize, 'Größe unbekannt');
    });

    test('fehlende oder unbrauchbare Felder führen nicht zum Absturz', () {
      expect(UpdateInfo.fromRelease(<String, dynamic>{}), isNull);
      expect(
        UpdateInfo.fromRelease(<String, dynamic>{'tag_name': 'build-13'}),
        isNull,
        reason: 'ohne assets-Liste',
      );
      expect(
        UpdateInfo.fromRelease(
            <String, dynamic>{'tag_name': 'build-13', 'assets': 'nichts'}),
        isNull,
        reason: 'assets ist keine Liste',
      );
      expect(
        UpdateInfo.fromRelease(<String, dynamic>{
          'tag_name': 'build-13',
          'assets': [
            'Unsinn',
            {
              'name': 42,
              'browser_download_url': 'https://example.invalid/x.apk',
            },
          ],
        }),
        isNull,
        reason: 'ein Anhang ohne Namen aus Text',
      );
    });

    test('ohne Beschreibung bleiben die Hinweise leer', () {
      expect(UpdateInfo.fromRelease(veroeffentlichung(body: null))?.notes, '');
      expect(UpdateInfo.fromRelease(veroeffentlichung(body: 42))?.notes, '');
      expect(
        UpdateInfo.fromRelease(veroeffentlichung(body: '  Kleinigkeiten.  '))
            ?.notes,
        'Kleinigkeiten.',
      );
    });
  });

  group('Ist die Veröffentlichung neuer als das Installierte?', () {
    final dreizehn = UpdateInfo.fromRelease(veroeffentlichung())!;

    test('eine höhere Nummer ist neuer', () {
      expect(dreizehn.isNewerThan(12), isTrue);
      expect(dreizehn.isNewerThan(1), isTrue);
    });

    test('die gleiche Nummer ist nicht neuer', () {
      expect(dreizehn.isNewerThan(13), isFalse);
    });

    test('eine kleinere Nummer ist nicht neuer', () {
      // Android verweigert einen Rückschritt ohnehin; die App soll ihn
      // deshalb gar nicht erst anbieten.
      expect(dreizehn.isNewerThan(14), isFalse);
      expect(dreizehn.isNewerThan(99), isFalse);
    });
  });

  group('Größe für die Anzeige', () {
    UpdateInfo mitGroesse(int bytes) => UpdateInfo(
          buildNumber: 13,
          tag: 'build-13',
          downloadUrl: 'https://example.invalid/x.apk',
          sizeInBytes: bytes,
          notes: '',
        );

    test('Dutzende Megabyte werden ganzzahlig gezeigt', () {
      expect(mitGroesse(39845632).readableSize, '38 MB');
    });

    test('unter zehn Megabyte mit einer Stelle und Komma', () {
      // Deutsches Dezimalkomma, nicht der Punkt aus toStringAsFixed.
      expect(mitGroesse(5 * 1024 * 1024).readableSize, '5,0 MB');
      expect(mitGroesse(1536 * 1024).readableSize, '1,5 MB');
    });

    test('ohne Angabe wird das auch gesagt', () {
      expect(mitGroesse(0).readableSize, 'Größe unbekannt');
      expect(mitGroesse(-1).readableSize, 'Größe unbekannt');
    });
  });
}
