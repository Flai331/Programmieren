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
}
