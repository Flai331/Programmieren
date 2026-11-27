import 'package:beebrain/utils/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Stoppuhr am Protokoll.
///
/// Das Protokoll trug bisher Zeitstempel auf die Sekunde. Ein Bildschirm,
/// der zwei Sekunden braucht, sah darin aus wie einer, der sofort da ist —
/// und „lädt lange" war damit nicht nachweisbar, sondern nur zu glauben.
void main() {
  /// Die Zeilen, die eine Stoppuhr geschrieben hat.
  List<String> gemessen() =>
      FeedbackService.logEntries.where((z) => z.contains('⏱')).toList();

  setUp(FeedbackService.clearLogsForTests);

  group('measure', () {
    test('gibt zurück, was die Arbeit zurückgibt', () async {
      final ergebnis =
          await FeedbackService.measure('Rechnen', () async => 6 * 7);
      expect(ergebnis, 42);
    });

    test('schreibt eine Zeile mit Namen und Millisekunden', () async {
      await FeedbackService.measure('Kunden laden', () async {});
      expect(gemessen(), hasLength(1));
      expect(gemessen().single, contains('Kunden laden in '));
      expect(gemessen().single, matches(RegExp(r'in \d+ ms')));
    });

    test('eine echte Wartezeit steht auch so drin', () async {
      await FeedbackService.measure('Warten', () async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      final zahl = RegExp(r'in (\d+) ms').firstMatch(gemessen().single)!;
      expect(int.parse(zahl.group(1)!), greaterThanOrEqualTo(50));
    });

    test('ab einer Sekunde wird es benannt', () {
      FeedbackService.logDuration('Lange Sache', const Duration(seconds: 2));
      expect(gemessen().single, contains('das dauert'));
    });

    test('darunter nicht', () {
      FeedbackService.logDuration('Kurze Sache', const Duration(seconds: 1) -
          const Duration(milliseconds: 1));
      expect(gemessen().single, isNot(contains('das dauert')));
    });

    test('ein Fehler kommt durch — gemessen wird trotzdem', () async {
      await expectLater(
        FeedbackService.measure<void>(
            'Scheitern', () async => throw StateError('kaputt')),
        throwsStateError,
      );
      expect(gemessen(), hasLength(1),
          reason: 'ein Fehlschlag nach acht Sekunden ist der wichtigste Fall');
      expect(gemessen().single, contains('Scheitern in '));
    });
  });

  group('Bildschirm', () {
    test('logScreenLoad und logScreenReady ergeben eine Dauer', () async {
      FeedbackService.logScreenLoad('Einstellungen');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      FeedbackService.logScreenReady('Einstellungen');

      expect(gemessen(), hasLength(1));
      expect(gemessen().single, contains('Einstellungen geladen in '));
    });

    test('logScreenReady ohne Start schreibt nichts', () {
      FeedbackService.logScreenReady('Nie geöffnet');
      expect(gemessen(), isEmpty);
    });

    test('zwei Bildschirme halten ihre Uhren auseinander', () async {
      FeedbackService.logScreenLoad('Erster');
      FeedbackService.logScreenLoad('Zweiter');
      FeedbackService.logScreenReady('Zweiter');

      expect(gemessen(), hasLength(1));
      expect(gemessen().single, contains('Zweiter'));

      FeedbackService.logScreenReady('Erster');
      expect(gemessen(), hasLength(2));
      expect(gemessen().last, contains('Erster'));
    });

    test('die Uhr wird nach dem Ablesen weggelegt', () {
      FeedbackService.logScreenLoad('Einmal');
      FeedbackService.logScreenReady('Einmal');
      FeedbackService.logScreenReady('Einmal');
      expect(gemessen(), hasLength(1));
    });
  });
}
