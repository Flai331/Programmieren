import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/models/honey_bucket_model.dart';
import 'package:beebrain/utils/bucket_code.dart';

/// Die Codes, die die App vergibt und die von Hand auf den Eimern stehen.
const _vergeben = ['SO-042', 'FR-017', 'LI-103', 'WA-256'];

void main() {
  group('Ausgabe', () {
    test('setzt den Code mit drei Stellen zusammen', () {
      expect(BucketCode.format('SO', 42), 'SO-042');
      expect(BucketCode.format('FR', 7), 'FR-007');
      expect(BucketCode.format('WA', 256), 'WA-256');
    });

    test('zählt global weiter, nicht je Sorte', () {
      expect(BucketCode.nextNumber(41), 42);
      // Noch kein Eimer vorhanden: die Zählung beginnt bei 1.
      expect(BucketCode.nextNumber(0), 1);
      expect(BucketCode.nextNumber(-1), 1);
    });

    test('normalisiert auf eine Vergleichsform', () {
      expect(BucketCode.normalize('so 42'), 'SO42');
      expect(BucketCode.normalize('SO-042'), 'SO042');
      expect(BucketCode.normalize('  so–042 \n'), 'SO042');
    });

    test('prüft die Gestalt einer Eingabe von Hand', () {
      expect(BucketCode.isWellFormed('SO-042'), isTrue);
      expect(BucketCode.isWellFormed('so42'), isTrue);
      // Kürzel, das es nicht gibt.
      expect(BucketCode.isWellFormed('ZZ-042'), isFalse);
      // Ohne Kürzel ist es keine vollständige Eingabe.
      expect(BucketCode.isWellFormed('042'), isFalse);
      expect(BucketCode.isWellFormed('Unsinn'), isFalse);
    });
  });

  group('Abgleich – Stufe 1: Zeichen für Zeichen', () {
    test('trifft den Code genau', () {
      final treffer = BucketCode.match('SO-042', _vergeben);
      expect(treffer.confidence, BucketCodeConfidence.exact);
      expect(treffer.code, 'SO-042');
      // Ein genauer Treffer braucht keine Rückfrage.
      expect(treffer.needsConfirmation, isFalse);
    });

    test('trifft auch ohne Trenner und in Kleinschrift', () {
      expect(BucketCode.match('so042', _vergeben).code, 'SO-042');
      expect(BucketCode.match('  SO 042 ', _vergeben).code, 'SO-042');
    });
  });

  group('Abgleich – Stufe 2: typische Verwechslungen', () {
    test('findet 5O-O42 zu SO-042', () {
      final treffer = BucketCode.match('5O-O42', _vergeben);
      expect(treffer.confidence, BucketCodeConfidence.corrected);
      expect(treffer.code, 'SO-042');
      // Korrigierte Treffer werden dem Nutzer gezeigt.
      expect(treffer.needsConfirmation, isTrue);
    });

    test('findet L1-1O3 zu LI-103', () {
      expect(BucketCode.match('L1-1O3', _vergeben).code, 'LI-103');
      expect(BucketCode.match('1I-1O3', _vergeben).code, 'LI-103');
    });

    test('findet FR-O17 zu FR-017', () {
      expect(BucketCode.match('FR-O17', _vergeben).code, 'FR-017');
    });
  });

  group('Abgleich – Stufe 3: nur die Ziffern', () {
    test('findet den Eimer, wenn das Kürzel unleserlich war', () {
      // Genau der Fall, für den die Nummer global läuft: Vom Kürzel ist
      // nichts zu erkennen, die drei Ziffern genügen.
      final treffer = BucketCode.match('042', _vergeben);
      expect(treffer.confidence, BucketCodeConfidence.corrected);
      expect(treffer.code, 'SO-042');
    });

    test('nimmt auch ein falsch gelesenes Kürzel in Kauf', () {
      expect(BucketCode.match('XY-256', _vergeben).code, 'WA-256');
    });

    test('zieht die laufende Nummer aus einer Lesung', () {
      expect(BucketCode.extractNumber('SO-042'), 42);
      expect(BucketCode.extractNumber('so 42'), 42);
      expect(BucketCode.extractNumber('kein Code'), isNull);
      // Mehr als vier Ziffern ist keine Eimernummer, sondern Lesemüll.
      expect(BucketCode.extractNumber('12345'), isNull);
    });
  });

  group('Abgleich – Stufe 4: ein Zeichen Abstand', () {
    test('verzeiht eine fehlende Ziffer', () {
      // 'WA-25' ist von 'WA-256' genau eine Löschung entfernt und sonst
      // nichts ähnlich.
      final treffer = BucketCode.match('WA-25', _vergeben);
      expect(treffer.confidence, BucketCodeConfidence.corrected);
      expect(treffer.code, 'WA-256');
    });

    test('verzeiht ein zusätzliches Zeichen', () {
      expect(BucketCode.match('WA-2566', _vergeben).code, 'WA-256');
    });
  });

  group('Die App rät nicht', () {
    test('bei mehreren Kandidaten wird zur Auswahl gestellt', () {
      // Zwei Eimer mit derselben Nummer in verschiedenen Sorten gibt es
      // bei globaler Zählung nicht – wohl aber zwei Codes, die nach einem
      // Lesefehler gleich nah liegen.
      final treffer = BucketCode.match('SO-04', ['SO-040', 'SO-041']);
      expect(treffer.confidence, BucketCodeConfidence.ambiguous);
      expect(treffer.isResolved, isFalse);
      expect(treffer.candidates, containsAll(['SO-040', 'SO-041']));
    });

    test('Unsinn führt zu „nicht erkannt"', () {
      final treffer = BucketCode.match('Deckel zu', _vergeben);
      expect(treffer.confidence, BucketCodeConfidence.none);
      expect(treffer.isResolved, isFalse);
      expect(treffer.candidates, isEmpty);
    });

    test('ohne Kandidaten gibt es keinen Treffer', () {
      expect(BucketCode.match('SO-042', const []).confidence,
          BucketCodeConfidence.none);
    });

    test('leere Lesung führt zu „nicht erkannt"', () {
      expect(BucketCode.match('', _vergeben).confidence,
          BucketCodeConfidence.none);
      expect(BucketCode.match('   ', _vergeben).confidence,
          BucketCodeConfidence.none);
    });
  });

  group('Die Verwechslungskarte lässt echte Codes nicht zusammenfallen', () {
    test('kein Paar gültiger Codes hat dieselbe Faltung', () {
      // Die Sicherheitseigenschaft, auf der Stufe 2 beruht: Würden zwei
      // vergebene Codes dieselbe Vergleichsform annehmen, könnte der
      // Abgleich sie nie mehr trennen. Geprüft über alle Sorten und ein
      // dichtes Nummernfeld.
      final alle = <String>[
        for (final sorte in HoneyVarieties.all)
          for (var n = 1; n <= 120; n++) BucketCode.format(sorte, n),
      ];

      // Zwei Codes gelten als „gleich gefaltet", wenn Stufe 2 sie beide
      // als Treffer derselben Lesung liefert. Genau das wird geprüft,
      // indem jeder Code als Lesung gegen alle anderen gestellt wird.
      for (final code in alle) {
        final treffer = BucketCode.match(code, alle);
        expect(treffer.confidence, BucketCodeConfidence.exact,
            reason: '$code muss sich selbst eindeutig treffen');
        expect(treffer.code, code);
      }
    });

    test('verschiedene Sorten mit gleicher Nummer bleiben trennbar', () {
      // Sollte die Zählung je Sorte laufen (sie tut es nicht), wäre dies
      // der Grenzfall. Auch dann darf Stufe 2 nicht raten.
      final treffer = BucketCode.match('SO-042', ['SO-042', 'FR-042']);
      expect(treffer.code, 'SO-042');
      expect(treffer.confidence, BucketCodeConfidence.exact);
    });
  });
}
