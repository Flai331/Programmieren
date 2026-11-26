import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/models/models.dart';

/// Die Wärmeschrank-Uhr. Gespeichert wird nur, wann der Eimer hineinkam;
/// alles andere ist Rechnung – und genau die steht hier.
void main() {
  final rein = DateTime(2026, 11, 24, 9, 0);

  HoneyWarmer uhr({required bool schonMalDrin}) => HoneyWarmer(
        startedAt: rein,
        requiredHours: HoneyWarmer.hoursFor(wasInBefore: schonMalDrin),
      );

  group('Wie lange der Eimer braucht', () {
    test('beim ersten Mal 48 Stunden', () {
      expect(HoneyWarmer.hoursFor(wasInBefore: false), 48);
      expect(uhr(schonMalDrin: false).dueAt, DateTime(2026, 11, 26, 9, 0));
    });

    test('war er schon einmal drin, genügen 24', () {
      // Durchgewärmt braucht er weniger – das ist der ganze Grund für die
      // Unterscheidung.
      expect(HoneyWarmer.hoursFor(wasInBefore: true), 24);
      expect(uhr(schonMalDrin: true).dueAt, DateTime(2026, 11, 25, 9, 0));
    });

    test('der zweite Durchgang ist kürzer als der erste', () {
      expect(HoneyWarmer.repeatHours, lessThan(HoneyWarmer.firstHours));
    });
  });

  group('Stand der Uhr', () {
    final u = uhr(schonMalDrin: false); // fertig am 26.11. um 9:00

    test('nennt die verstrichene Zeit', () {
      expect(u.elapsed(DateTime(2026, 11, 24, 23, 0)).inHours, 14);
    });

    test('nennt die Restzeit', () {
      expect(u.remaining(DateTime(2026, 11, 24, 23, 0)).inHours, 34);
    });

    test('ist vor der Zeit nicht fällig', () {
      expect(u.isDue(DateTime(2026, 11, 26, 8, 59)), isFalse);
    });

    test('ist auf die Minute genau fällig', () {
      expect(u.isDue(DateTime(2026, 11, 26, 9, 0)), isTrue);
    });

    test('bleibt danach fällig', () {
      expect(u.isDue(DateTime(2026, 12, 1)), isTrue);
      expect(u.remaining(DateTime(2026, 12, 1)).isNegative, isTrue);
    });
  });

  group('Was am Eimer steht', () {
    final u = uhr(schonMalDrin: false); // fertig am 26.11. um 9:00

    test('Stunden, solange es Stunden sind', () {
      expect(u.readableRemaining(DateTime(2026, 11, 24, 23, 0)), 'noch 34 h');
      expect(u.readableRemaining(DateTime(2026, 11, 26, 7, 30)), 'noch 1 h');
    });

    test('Minuten in der letzten Stunde', () {
      expect(u.readableRemaining(DateTime(2026, 11, 26, 8, 15)), 'noch 45 min');
      expect(u.readableRemaining(DateTime(2026, 11, 26, 8, 59)), 'noch 1 min');
    });

    test('„fällig", sobald die Zeit um ist', () {
      // Genau bei null nicht „noch 0 min" – das wäre eine Zumutung.
      expect(u.readableRemaining(DateTime(2026, 11, 26, 9, 0)), 'fällig');
      expect(u.readableRemaining(DateTime(2026, 11, 26, 9, 30)), 'fällig');
    });

    test('nennt die Überfälligkeit in Stunden', () {
      expect(u.readableRemaining(DateTime(2026, 11, 26, 12, 0)),
          'seit 3 h fällig');
      expect(u.readableRemaining(DateTime(2026, 11, 27, 9, 0)),
          'seit 24 h fällig');
    });
  });

  group('Die Uhr aus dem Verlauf', () {
    // Der Verlauf kommt aus der Datenbank nach Datum absteigend – die
    // Rechnung darf sich darauf nicht verlassen, also steht hier bewusst
    // beides durcheinander.
    HoneyBucketEventModel ereignis(String kind, DateTime wann) =>
        HoneyBucketEventModel(
          id: '$kind-${wann.millisecondsSinceEpoch}',
          bucketId: 'b1',
          date: wann,
          kind: kind,
          createdAt: wann,
        );

    final ein1 = ereignis(HoneyEventKinds.warmerIn, DateTime(2026, 11, 20, 8));
    final aus1 = ereignis(HoneyEventKinds.warmerOut, DateTime(2026, 11, 22, 8));
    final ein2 = ereignis(HoneyEventKinds.warmerIn, DateTime(2026, 11, 24, 9));
    final aus2 = ereignis(HoneyEventKinds.warmerOut, DateTime(2026, 11, 25, 9));
    final anderes =
        ereignis(HoneyEventKinds.state, DateTime(2026, 11, 23, 12));

    tearDown(HoneyWarmer.useDefaults);

    test('ohne Zeilen läuft keine Uhr', () {
      expect(HoneyWarmer.fromEvents(const []), isNull);
      expect(HoneyWarmer.fromEvents([anderes]), isNull);
    });

    test('ein Hineinstellen startet 48 Stunden', () {
      final uhr = HoneyWarmer.fromEvents([anderes, ein1]);
      expect(uhr, isNotNull);
      expect(uhr!.startedAt, ein1.date);
      expect(uhr.requiredHours, HoneyWarmer.defaultFirstHours);
      expect(uhr.dueAt, DateTime(2026, 11, 22, 8));
    });

    test('nach dem Herausnehmen läuft keine', () {
      expect(HoneyWarmer.fromEvents([aus1, ein1]), isNull);
      expect(HoneyWarmer.fromEvents([aus2, ein2, aus1, ein1]), isNull);
    });

    test('der zweite Durchgang braucht nur 24 Stunden', () {
      // Genau das ist die Entscheidung dahinter: 48 beim ersten Mal, 24
      // wenn der Eimer schon einmal drin war.
      final uhr = HoneyWarmer.fromEvents([ein2, aus1, ein1]);
      expect(uhr, isNotNull);
      expect(uhr!.startedAt, ein2.date);
      expect(uhr.requiredHours, HoneyWarmer.defaultRepeatHours);
      expect(uhr.dueAt, DateTime(2026, 11, 25, 9));
    });

    test('die Reihenfolge der Zeilen ist gleichgültig', () {
      final vorwaerts = HoneyWarmer.fromEvents([ein1, aus1, anderes, ein2]);
      final rueckwaerts = HoneyWarmer.fromEvents([ein2, anderes, aus1, ein1]);
      expect(vorwaerts!.startedAt, rueckwaerts!.startedAt);
      expect(vorwaerts.requiredHours, rueckwaerts.requiredHours);
    });

    test('war er schon einmal drin?', () {
      expect(HoneyWarmer.wasInBeforeFrom(const []), isFalse);
      expect(HoneyWarmer.wasInBeforeFrom([ein1]), isFalse,
          reason: 'drin, aber noch nie durchgewärmt heraus');
      expect(HoneyWarmer.wasInBeforeFrom([ein1, aus1]), isTrue);
    });
  });

  group('Die Stundenzahlen sind einstellbar', () {
    tearDown(HoneyWarmer.useDefaults);

    test('von Haus aus 48 und 24', () {
      expect(HoneyWarmer.firstHours, 48);
      expect(HoneyWarmer.repeatHours, 24);
    });

    test('eigene Zahlen gelten überall', () {
      HoneyWarmer.apply(firstHours: 12, repeatHours: 6);
      expect(HoneyWarmer.firstHours, 12);
      expect(HoneyWarmer.repeatHours, 6);
      expect(HoneyWarmer.hoursFor(wasInBefore: false), 12);
      expect(HoneyWarmer.hoursFor(wasInBefore: true), 6);

      final uhr = HoneyWarmer.fromEvents([
        HoneyBucketEventModel(
          id: 'e1',
          bucketId: 'b1',
          date: DateTime(2026, 11, 26, 8),
          kind: HoneyEventKinds.warmerIn,
          createdAt: DateTime(2026, 11, 26, 8),
        ),
      ]);
      expect(uhr!.requiredHours, 12);
      expect(uhr.dueAt, DateTime(2026, 11, 26, 20));
    });

    test('Unbrauchbares fällt auf die Vorgabe zurück', () {
      // Eine Uhr mit null Stunden wäre keine.
      for (final wert in [0.0, -5.0, 9999.0, double.nan]) {
        HoneyWarmer.apply(firstHours: wert, repeatHours: wert);
        expect(HoneyWarmer.firstHours, HoneyWarmer.defaultFirstHours,
            reason: '$wert');
        expect(HoneyWarmer.repeatHours, HoneyWarmer.defaultRepeatHours,
            reason: '$wert');
      }
    });

    test('nichts eingestellt heißt Vorgabe', () {
      HoneyWarmer.apply();
      expect(HoneyWarmer.firstHours, HoneyWarmer.defaultFirstHours);
      expect(HoneyWarmer.repeatHours, HoneyWarmer.defaultRepeatHours);
    });

    test('krumme Zahlen werden gerundet', () {
      HoneyWarmer.apply(firstHours: 36.6, repeatHours: 18.2);
      expect(HoneyWarmer.firstHours, 37);
      expect(HoneyWarmer.repeatHours, 18);
    });
  });
}
