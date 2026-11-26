import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/honey_service.dart';

HoneyBucketModel _bucket({
  String id = 'b1',
  String code = 'SO-042',
  int number = 42,
  String variety = HoneyVarieties.summer,
  String? varietyName,
  double filledKg = 25,
  double? bucketSizeKg = 25,
  String state = HoneyStates.extracted,
  String? crystallization,
  String? location,
}) =>
    HoneyBucketModel(
      id: id,
      code: code,
      number: number,
      variety: variety,
      varietyName: varietyName,
      harvestDate: DateTime(2026, 7, 14),
      bucketSizeKg: bucketSizeKg,
      filledKg: filledKg,
      waterContent: 17.2,
      state: state,
      crystallization: crystallization,
      location: location,
      createdAt: DateTime(2026, 7, 14, 18),
    );

void main() {
  group('Der Inhalt wird abgeleitet, nicht gespeichert', () {
    test('ein frischer Eimer enthält seine Einwaage', () {
      final stand = HoneyBucketStatus(bucket: _bucket(filledKg: 25));
      expect(stand.currentKg, 25);
      expect(stand.isEmptied, isFalse);
      expect(stand.remainingShare, 1.0);
    });

    test('Inhalt nach zwei Abfüllungen', () {
      // 25 kg eingewogen, 5 kg und 7,5 kg abgefüllt → 12,5 kg übrig.
      final stand =
          HoneyBucketStatus(bucket: _bucket(filledKg: 25), bottledKg: 12.5);

      expect(stand.currentKg, 12.5);
      expect(stand.remainingShare, 0.5);
      expect(stand.isEmptied, isFalse);
      expect(stand.currentLabel, contains('12,5'));
    });

    test('vollständig abgefüllt ergibt genau 0, nicht −0,0000001', () {
      // Der Rundungsschutz: 25 − (3 × 8,333…) soll nicht als Restmenge
      // stehen bleiben.
      final stand = HoneyBucketStatus(
          bucket: _bucket(filledKg: 25), bottledKg: 8.3333333 * 3);

      expect(stand.currentKg, 0);
      expect(stand.isEmptied, isTrue);
    });

    test('mehr abgefüllt als eingewogen bleibt sichtbar', () {
      final stand =
          HoneyBucketStatus(bucket: _bucket(filledKg: 25), bottledKg: 26);
      expect(stand.currentKg, lessThan(0));
      expect(stand.isEmptied, isTrue);
    });

    test('ordnet jedem Eimer seine abgefüllte Menge zu', () {
      final staende = HoneyService.buildStatuses(
        buckets: [
          _bucket(id: 'b1', filledKg: 25),
          _bucket(id: 'b2', code: 'FR-017', number: 17, filledKg: 12),
        ],
        bottled: {'b1': 5},
      );

      expect(staende.first.currentKg, 20);
      // Ohne Abfüllung fehlt der Eintrag – das ist kein Fehler, sondern 0.
      expect(staende.last.currentKg, 12);
    });
  });

  group('kg ↔ Gläser', () {
    test('rechnet Gläser aus kg, abgerundet', () {
      // Ein halb volles Glas kommt nicht ins Regal.
      final plan = HoneyService.planBottling(jarSizeG: 500, kg: 5);
      expect(plan.jars, 10);
      expect(plan.kg, 5);

      expect(HoneyService.planBottling(jarSizeG: 500, kg: 5.4).jars, 10);
      expect(HoneyService.planBottling(jarSizeG: 500, kg: 5.5).jars, 11);
      expect(HoneyService.planBottling(jarSizeG: 250, kg: 5).jars, 20);
    });

    test('rechnet kg aus Gläsern', () {
      // Ein 500-g-Glas wiegt 0,5 kg – Honig wird nach Gewicht verkauft.
      final plan = HoneyService.planBottling(jarSizeG: 500, jars: 10);
      expect(plan.kg, 5);
      expect(plan.jars, 10);
    });

    test('lässt beide Angaben stehen, wenn beide da sind', () {
      // Die Differenz ist dann der Verlust beim Abfüllen und soll nicht
      // wegrechnet werden.
      final plan = HoneyService.planBottling(jarSizeG: 500, kg: 5.2, jars: 10);
      expect(plan.kg, 5.2);
      expect(plan.jars, 10);
      expect(plan.nominalKg, 5);
      expect(plan.difference, closeTo(0.2, 0.0001));
      expect(plan.isPlausible, isTrue);
    });

    test('erkennt eine unplausible Eingabe', () {
      // 20 kg in 10 Gläser à 500 g geht nicht auf.
      final plan = HoneyService.planBottling(jarSizeG: 500, kg: 20, jars: 10);
      expect(plan.isPlausible, isFalse);
    });

    test('kommt ohne Angaben und ohne Glasgröße zurecht', () {
      expect(HoneyService.planBottling(jarSizeG: 500).jars, 0);
      expect(HoneyService.planBottling(jarSizeG: 0, kg: 5).jars, 0);
    });
  });

  group('Zustände – die Hakenliste', () {
    test('„Weiter" läuft die vier Haken ab und hört dann auf', () {
      final kette = <String>[HoneyStates.extracted];
      var aktuell = HoneyStates.extracted;
      for (var i = 0; i < 10; i++) {
        final naechster = HoneyStates.next(aktuell);
        if (naechster == null) break;
        kette.add(naechster);
        aktuell = naechster;
      }

      expect(kette, HoneyStates.steps);
      // Nach 'abfüllfertig' kommt kein Haken mehr: es folgt das Abfüllen, und
      // 'leer' setzt der Dienst selbst.
      expect(HoneyStates.next(HoneyStates.readyToBottle), isNull);
      expect(HoneyStates.next(HoneyStates.empty), isNull);
    });

    test('geschleudert und täglich rühren warten auf mich', () {
      // 'geschleudert' heißt: noch zu impfen. 'geimpft' heißt: täglich rühren.
      for (final zustand in [HoneyStates.extracted, HoneyStates.seeded]) {
        expect(HoneyStates.needsAttention(zustand), isTrue,
            reason: '$zustand sollte Handlungsbedarf anzeigen');
      }
      for (final zustand in [
        HoneyStates.stirred,
        HoneyStates.readyToBottle,
        HoneyStates.empty,
      ]) {
        expect(HoneyStates.needsAttention(zustand), isFalse,
            reason: '$zustand sollte ruhen');
      }
    });

    test('eine Markierung fordert Handlung, auf welchem Haken auch immer', () {
      expect(_bucket(state: HoneyStates.stirred).needsAttention, isFalse);
      expect(
        _bucket(
          state: HoneyStates.stirred,
          crystallization: HoneyCrystallization.coarse,
        ).needsAttention,
        isTrue,
      );
    });
  });

  group('Was auf den Eimer zu malen ist', () {
    test('nennt Code und Strichzahl', () {
      expect(_bucket(state: HoneyStates.seeded).labelHint, 'SO-042  [|]');
      expect(_bucket(state: HoneyStates.stirred).labelHint, 'SO-042  [||]');
      expect(
          _bucket(state: HoneyStates.readyToBottle).labelHint, 'SO-042  [|||]');
      expect(_bucket(state: HoneyStates.empty).labelHint, 'SO-042  [✕]');
    });

    test('beim geschleuderten Eimer steht nur der Code', () {
      // Vor dem Impfen ist noch kein Strich zu malen.
      expect(_bucket(state: HoneyStates.extracted).labelHint, 'SO-042');
    });

    test('ein Strich mehr heißt ein Schritt weiter', () {
      // Die Strichzahl darf auf dem Eimer nur wachsen – sonst müsste der
      // Imker etwas wegwischen.
      final folge = [
        HoneyStates.seeded,
        HoneyStates.stirred,
        HoneyStates.readyToBottle,
      ];
      var zuletzt = 0;
      for (final zustand in folge) {
        final striche = HoneyStates.strokeHint(zustand).length;
        expect(striche, greaterThanOrEqualTo(zuletzt));
        zuletzt = striche;
      }
    });
  });

  group('Auswertungen über alle Eimer', () {
    final staende = HoneyService.buildStatuses(
      buckets: [
        _bucket(id: 'b1', filledKg: 25, state: HoneyStates.seeded),
        _bucket(
            id: 'b2',
            code: 'FR-017',
            number: 17,
            variety: HoneyVarieties.spring,
            filledKg: 12,
            state: HoneyStates.readyToBottle),
        _bucket(
            id: 'b3',
            code: 'SO-043',
            number: 43,
            filledKg: 25,
            // Ruhender Haken, aber kristallin: allein die Markierung macht
            // hier den Handlungsbedarf.
            state: HoneyStates.stirred,
            crystallization: HoneyCrystallization.coarse),
        // Leer – darf in keiner Menge mitzählen.
        _bucket(
            id: 'b4',
            code: 'SO-044',
            number: 44,
            filledKg: 25,
            state: HoneyStates.empty),
      ],
      bottled: {'b1': 5, 'b4': 25},
    );

    test('summiert kg je Sorte, ohne die leeren', () {
      final jeSorte = HoneyService.kgPerVariety(staende);
      expect(jeSorte[HoneyVarieties.summer], 45); // 20 + 25
      expect(jeSorte[HoneyVarieties.spring], 12);
      expect(jeSorte.values.fold<double>(0, (s, v) => s + v), 57);
    });

    test('nennt die Gesamtmenge', () {
      expect(HoneyService.totalKg(staende), 57);
    });

    test('nennt die Eimer mit Handlungsbedarf', () {
      final offen = HoneyService.needingAttention(staende);
      expect(offen.map((s) => s.bucket.id), ['b1', 'b3']);
    });

    test('ein leerer Eimer fordert keine Handlung mehr', () {
      final leerUndGrob = HoneyService.buildStatuses(
        buckets: [
          _bucket(
              id: 'x',
              state: HoneyStates.empty,
              crystallization: HoneyCrystallization.coarse)
        ],
        bottled: {'x': 25},
      );
      expect(HoneyService.needingAttention(leerUndGrob), isEmpty);
    });

    test('gruppiert nach Zustand', () {
      final nachZustand = HoneyService.byState(staende);
      expect(nachZustand[HoneyStates.seeded]!.single.bucket.id, 'b1');
      expect(nachZustand[HoneyStates.readyToBottle]!.single.bucket.id, 'b2');
    });
  });

  group('Sortenname', () {
    test('kommt aus dem Verzeichnis', () {
      expect(_bucket(variety: HoneyVarieties.summer).varietyLabel,
          'Sommerblüte');
      expect(_bucket(variety: HoneyVarieties.lime).varietyLabel, 'Linde');
    });

    test('bei „Sonstige" steht der freie Name am Eimer', () {
      expect(
          _bucket(variety: HoneyVarieties.other, varietyName: 'Phacelia')
              .varietyLabel,
          'Phacelia');
      // Ohne eigenen Namen bleibt die Bezeichnung des Verzeichnisses.
      expect(_bucket(variety: HoneyVarieties.other).varietyLabel, 'Sonstige');
    });
  });
}
