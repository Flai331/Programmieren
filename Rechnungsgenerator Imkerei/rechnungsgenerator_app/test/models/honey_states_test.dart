import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/models/models.dart';

/// Die Hakenliste rechnet aus EINEM gespeicherten Wert, welche Haken sitzen.
/// Hier steht, dass diese Rechnung stimmt – und dass alte Werte aus früheren
/// Fassungen nicht als unbekannter Zustand durchfallen.
void main() {
  group('Haken aus dem erreichten Schritt', () {
    test('vier Haken in der Reihenfolge der Arbeit', () {
      expect(HoneyStates.steps, [
        HoneyStates.extracted,
        HoneyStates.seeded,
        HoneyStates.stirred,
        HoneyStates.readyToBottle,
      ]);
      // 'leer' ist kein Haken, gehört aber zu den möglichen Werten.
      expect(HoneyStates.all, [...HoneyStates.steps, HoneyStates.empty]);
    });

    test('jeder Schritt zählt seine Haken', () {
      for (var i = 0; i < HoneyStates.steps.length; i++) {
        expect(HoneyStates.ticksOf(HoneyStates.steps[i]), i + 1);
      }
    });

    test('ein Haken nimmt die vorherigen mit', () {
      // Der Kern der Umstellung: wer „fertig gerührt" hakt, hat geimpft.
      for (final schritt in HoneyStates.steps) {
        expect(
          HoneyStates.isDone(HoneyStates.stirred, schritt),
          schritt != HoneyStates.readyToBottle,
          reason: 'bei „fertig gerührt" sitzen genau die ersten drei Haken',
        );
      }
    });

    test('ein leerer Eimer ist durch', () {
      expect(HoneyStates.ticksOf(HoneyStates.empty), HoneyStates.steps.length);
      for (final schritt in HoneyStates.steps) {
        expect(HoneyStates.isDone(HoneyStates.empty, schritt), isTrue);
      }
    });

    test('Haken 1 lässt sich nicht abhaken', () {
      // Der Eimer existiert, weil geschleudert wurde.
      for (final anzahl in [1, 0, -1, -99]) {
        expect(HoneyStates.stateForTicks(anzahl), HoneyStates.extracted);
      }
    });

    test('über das Ende hinaus geht es auch nicht', () {
      for (final anzahl in [4, 5, 99]) {
        expect(HoneyStates.stateForTicks(anzahl), HoneyStates.readyToBottle);
      }
    });

    test('abhaken setzt genau einen Schritt zurück', () {
      // Haken 3 wegnehmen heißt: der Eimer steht auf Haken 2.
      for (var i = HoneyStates.steps.length; i > 1; i--) {
        final jetzt = HoneyStates.stateForTicks(i);
        expect(HoneyStates.stateForTicks(HoneyStates.ticksOf(jetzt) - 1),
            HoneyStates.steps[i - 2]);
      }
    });

    test('Haken und Striche am Eimer wachsen gemeinsam', () {
      // Die Striche dürfen nur dazukommen – sonst müsste etwas weggewischt
      // werden, was mit Permanentmarker geschrieben ist.
      var zuletzt = -1;
      for (final schritt in HoneyStates.steps) {
        final striche = HoneyStates.strokeHint(schritt).length;
        expect(striche, greaterThan(zuletzt));
        zuletzt = striche;
      }
    });
  });

  group('Werte aus früheren Fassungen', () {
    test('jeder alte Wert landet auf einem heute gültigen', () {
      HoneyStates.legacy.forEach((alt, neu) {
        expect(HoneyStates.all, contains(neu), reason: '$alt → $neu');
        expect(HoneyStates.normalize(alt), neu);
      });
    });

    test('die beiden Abzweige kommen auf den ersten Haken', () {
      // Grob und kandiert sind keine Schritte mehr. Dass die Markierung dabei
      // verloren geht, kann eine Abbildung von Text auf Text nicht ändern –
      // dafür ist die Migration da.
      expect(HoneyStates.normalize('grob'), HoneyStates.extracted);
      expect(HoneyStates.normalize('fest'), HoneyStates.extracted);
    });

    test('„noch zu rühren" ist heute „geimpft – täglich rühren"', () {
      expect(HoneyStates.normalize('zu_ruehren'), HoneyStates.seeded);
      expect(HoneyStates.labelOf('zu_ruehren'),
          HoneyStates.labelOf(HoneyStates.seeded));
    });

    test('heutige Werte bleiben, wie sie sind', () {
      for (final zustand in HoneyStates.all) {
        expect(HoneyStates.normalize(zustand), zustand);
      }
    });

    test('Unbekanntes behauptet nie, es sei etwas getan', () {
      for (final unsinn in ['', 'quatsch', 'GESCHLEUDERT', ' geimpft']) {
        expect(HoneyStates.normalize(unsinn), HoneyStates.extracted,
            reason: '„$unsinn" darf keine Arbeit als erledigt ausgeben');
        expect(HoneyStates.ticksOf(unsinn), 1);
      }
    });

    test('kein alter Wert gewinnt Haken dazu', () {
      // Der böse Fehler wäre ein stilles Umkippen nach vorn.
      const alteRaenge = {
        'frisch': 1,
        'zu_impfen': 1,
        'zu_ruehren': 2,
        'grob': 1,
        'fest': 1,
      };
      alteRaenge.forEach((alt, hoechstens) {
        expect(HoneyStates.ticksOf(alt), lessThanOrEqualTo(hoechstens),
            reason: '$alt');
      });
    });
  });

  group('Markierung grob und kandiert', () {
    test('steht neben der Liste, nicht darin', () {
      for (final markierung in HoneyCrystallization.all) {
        expect(HoneyStates.all, isNot(contains(markierung)));
        expect(HoneyCrystallization.isKnown(markierung), isTrue);
      }
    });

    test('hat eine lesbare Beschriftung', () {
      expect(HoneyCrystallization.labelOf(HoneyCrystallization.coarse),
          'grob kristallin');
      expect(HoneyCrystallization.labelOf(HoneyCrystallization.solid),
          'kandiert / fest');
      // Unbekanntes wird gezeigt, nicht verschluckt.
      expect(HoneyCrystallization.labelOf('weissnicht'), 'weissnicht');
    });
  });

  group('Antippen eines Kästchens', () {
    final n = HoneyStates.steps.length;

    test('ein leeres Kästchen hakt alles bis dorthin an', () {
      // Der Wunsch in einem Satz: „alle anharken wenn man das erste
      // anharkt" – wer hinten hakt, hakt vorn mit.
      for (var stand = 1; stand <= n; stand++) {
        for (var tipp = stand + 1; tipp <= n; tipp++) {
          expect(
            HoneyStates.ticksAfterTap(current: stand, tapped: tipp),
            tipp,
            reason: 'Stand $stand, getippt $tipp',
          );
        }
      }
    });

    test('der eigene Stand nimmt genau einen Haken zurück', () {
      for (var stand = 2; stand <= n; stand++) {
        expect(HoneyStates.ticksAfterTap(current: stand, tapped: stand),
            stand - 1);
      }
    });

    test('ein früherer Haken nimmt sich selbst und alles danach weg', () {
      // Stand 4, Kästchen 2 angetippt: 2, 3 und 4 fallen, 1 bleibt.
      expect(HoneyStates.ticksAfterTap(current: 4, tapped: 2), 1);
      expect(HoneyStates.ticksAfterTap(current: 4, tapped: 3), 2);
      expect(HoneyStates.ticksAfterTap(current: 3, tapped: 2), 1);
    });

    test('Kästchen 1 lässt sich nie abhaken', () {
      for (var stand = 1; stand <= n; stand++) {
        expect(HoneyStates.ticksAfterTap(current: stand, tapped: 1), isNull,
            reason: 'Stand $stand');
      }
    });

    test('jedes Ergebnis ist ein Zustand der Kette', () {
      for (var stand = 1; stand <= n; stand++) {
        for (var tipp = 1; tipp <= n; tipp++) {
          final ziel =
              HoneyStates.ticksAfterTap(current: stand, tapped: tipp);
          if (ziel == null) continue;
          expect(ziel, inInclusiveRange(1, n));
          final zustand = HoneyStates.stateForTicks(ziel);
          expect(HoneyStates.steps, contains(zustand));
          // Und die Rechnung ist in sich geschlossen: der Zustand zählt
          // genau die Haken, die er bekommen sollte.
          expect(HoneyStates.ticksOf(zustand), ziel);
        }
      }
    });

    test('der letzte Schritt ist erreichbar und das Ende', () {
      expect(HoneyStates.ticksAfterTap(current: 1, tapped: n), n);
      expect(HoneyStates.stateForTicks(n), HoneyStates.readyToBottle);
      expect(HoneyStates.next(HoneyStates.readyToBottle), isNull);
    });
  });
}
