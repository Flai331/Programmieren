import 'dart:io';

import 'package:beebrain/services/pdf_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Hält die Schriftdateien, die Pfade in [PdfFonts] und den `assets:`-Block
/// in `pubspec.yaml` zusammen.
///
/// Warum das ein Test ist und keine Nebensache: Verschreibt sich ein Pfad,
/// wirft `rootBundle.load` erst auf dem Gerät — und vorher stand an
/// derselben Stelle `PdfGoogleFonts`, das bei einem falschen Pfad
/// stillschweigend wieder aus dem Netz lädt. Genau das soll nicht
/// zurückkommen, ohne dass es jemand merkt.
void main() {
  late List<String> imPubspec;

  setUpAll(() {
    final text = File('pubspec.yaml').readAsStringSync();
    final karte = loadYaml(text) as YamlMap;
    final flutterTeil = karte['flutter'] as YamlMap;
    imPubspec = (flutterTeil['assets'] as YamlList)
        .map((e) => e.toString())
        .toList(growable: false);
  });

  final pfade = <String, int>{
    // Pfad → Mindestgröße. Eine TTF unter 50 KB ist keine vollständige
    // Schrift, sondern ein Versehen.
    PdfFonts.regularAsset: 50000,
    PdfFonts.boldAsset: 50000,
    PdfFonts.italicAsset: 50000,
    PdfFonts.licenseAsset: 1000,
  };

  pfade.forEach((pfad, mindestens) {
    group(pfad, () {
      test('liegt im Projekt und ist vollständig', () {
        final datei = File(pfad);
        expect(datei.existsSync(), isTrue,
            reason: '$pfad fehlt — PdfFonts würde auf dem Gerät werfen');
        expect(datei.lengthSync(), greaterThan(mindestens));
      });

      test('steht im pubspec, kommt also mit ins Paket', () {
        expect(imPubspec, contains(pfad),
            reason: 'ohne Eintrag im pubspec ist die Datei im APK nicht da');
      });
    });
  });

  test('die drei Schnitte sind verschiedene Dateien', () {
    final inhalte = [
      PdfFonts.regularAsset,
      PdfFonts.boldAsset,
      PdfFonts.italicAsset,
    ].map((p) => File(p).lengthSync()).toSet();
    expect(inhalte.length, 3,
        reason: 'gleiche Größe heißt vermutlich dreimal dieselbe Datei');
  });

  test('die Lizenz ist die von Roboto', () {
    final text = File(PdfFonts.licenseAsset).readAsStringSync();
    expect(text, contains('Apache License'));
  });

  test('keine Schrift wird mehr aus dem Netz geholt', () {
    // Der Beweis, dass die Umstellung nicht halb geblieben ist: nirgends im
    // Programmcode darf noch PdfGoogleFonts aufgerufen werden.
    final treffer = <String>[];
    for (final datei in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final zeile in datei.readAsLinesSync()) {
        final blank = zeile.trimLeft();
        if (blank.startsWith('//') || blank.startsWith('///')) continue;
        if (blank.contains('PdfGoogleFonts')) treffer.add(datei.path);
      }
    }
    expect(treffer, isEmpty);
  });
}
