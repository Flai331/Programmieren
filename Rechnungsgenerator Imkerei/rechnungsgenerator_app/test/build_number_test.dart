import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/build_info.dart';

/// Die Build-Nummer steht an zwei Orten, und sie müssen übereinstimmen.
///
/// `kBuildNumber` ist die Zahl, die die App anzeigt und die ein Release als
/// Tag `build-<N>` trägt. Androids `versionCode` kommt dagegen aus dem
/// pubspec (`version: 1.0.0+N`), über `flutter.versionCode`.
///
/// Laufen die beiden auseinander, passiert das Unangenehmste, was hier
/// passieren kann: Das System hält zwei verschiedene Fassungen für dieselbe
/// und verweigert die Aktualisierung — während die App eine neuere Nummer
/// anzeigt und das Veröffentlichte auch wirklich neuer ist. Der Fehler wäre
/// also nicht nur still, er würde in die Irre führen.
void main() {
  test('pubspec.yaml und build_info.dart nennen dieselbe Build-Nummer', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final zeile =
        RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);

    expect(
      zeile,
      isNotNull,
      reason: 'pubspec.yaml braucht eine Zeile der Form '
          '"version: 1.0.0+<Build-Nummer>". Ohne das +N steht Androids '
          'versionCode für immer auf 1.',
    );
    expect(
      int.parse(zeile!.group(2)!),
      kBuildNumber,
      reason: 'Androids versionCode kommt aus dem pubspec, Anzeige und '
          'Release-Tag aus kBuildNumber. Beim Erhöhen beide ändern.',
    );
  });
}
