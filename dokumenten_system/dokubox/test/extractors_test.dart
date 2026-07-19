import 'package:dokubox/extract/extractors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 19);

  group('extractDates', () {
    test('erkennt numerische deutsche Daten', () {
      final dates = extractDates('Köln, den 14.03.2026\nBetrag: 12.50', now: now);
      expect(dates, [DateTime(2026, 3, 14)]);
    });

    test('erkennt ausgeschriebene Monate', () {
      final dates = extractDates('Berlin, 3. März 2026', now: now);
      expect(dates, [DateTime(2026, 3, 3)]);
    });

    test('erkennt ISO-Daten und zweistellige Jahre', () {
      expect(extractDates('Stand 2026-01-31', now: now),
          [DateTime(2026, 1, 31)]);
      expect(extractDates('am 05.06.24 erhalten', now: now),
          [DateTime(2024, 6, 5)]);
    });

    test('verwirft unplausible Daten', () {
      expect(extractDates('31.02.2026 und 12.13.2026', now: now), isEmpty);
      expect(extractDates('01.01.1980', now: now), isEmpty); // zu alt
      expect(extractDates('01.01.2035', now: now), isEmpty); // zu weit weg
    });

    test('guessDocDate nimmt das erste Datum (Briefkopf)', () {
      const text = 'Musterstadt, 02.05.2026\n\nIhr Schreiben vom 28.04.2026';
      expect(guessDocDate(text, now: now), DateTime(2026, 5, 2));
    });
  });

  group('guessDocType', () {
    test('spezifische Typen gewinnen gegen allgemeine', () {
      expect(guessDocType('Ihre Beitragsrechnung zur Police'),
          'Versicherungspolice');
      expect(guessDocType('Kontoauszug Nr. 7'), 'Kontoauszug');
      expect(guessDocType('RECHNUNG Nr. 4711'), 'Rechnung');
      expect(guessDocType('Bescheid über Leistungen'), 'Bescheid');
      expect(guessDocType('Kündigung Ihres Vertrags'), 'Kündigung');
    });

    test('null wenn nichts passt', () {
      expect(guessDocType('Hallo Welt'), isNull);
    });
  });

  group('IBAN', () {
    test('validiert korrekte IBAN', () {
      expect(isValidIban('DE89370400440532013000'), isTrue);
      expect(isValidIban('DE89 3704 0044 0532 0130 00'), isTrue);
    });

    test('verwirft falsche Prüfsumme', () {
      expect(isValidIban('DE89370400440532013001'), isFalse);
    });

    test('extractRefs findet IBAN im Text', () {
      final refs =
          extractRefs('Bitte überweisen an DE89 3704 0044 0532 0130 00.');
      expect(refs['IBAN'], {'DE89370400440532013000'});
    });
  });

  group('extractRefs (beschriftet)', () {
    test('findet Versicherungsschein- und Kundennummer', () {
      const text = 'Versicherungsschein-Nr.: KFZ-123456789\n'
          'Kundennummer: 987654';
      final refs = extractRefs(text);
      expect(refs['VSNR'], contains('KFZ-123456789'));
      expect(refs['KDNR'], contains('987654'));
    });

    test('ignoriert Treffer ohne Ziffern', () {
      final refs = extractRefs('Der Vertrag über die Leistung');
      expect(refs['VSNR'], isNull);
    });
  });

  group('matchKnownCorrespondent', () {
    test('findet Absender im Briefkopf, längster Treffer gewinnt', () {
      const text = 'HUK-COBURG Allgemeine Versicherung AG\nSehr geehrter…';
      final id = matchKnownCorrespondent(text, {
        'HUK-COBURG': 'huk',
        'HUK-COBURG Allgemeine Versicherung': 'huk-allg',
      });
      expect(id, 'huk-allg');
    });

    test('null wenn kein Alias vorkommt', () {
      expect(matchKnownCorrespondent('Stadtwerke', {'HUK': 'huk'}), isNull);
    });
  });

  group('suggestTitle', () {
    test('Typ + Absender', () {
      expect(
        suggestTitle(
            docType: 'Rechnung',
            correspondentName: 'Stadtwerke',
            ocrText: ''),
        'Rechnung Stadtwerke',
      );
    });

    test('fällt auf erste brauchbare Zeile zurück', () {
      expect(
        suggestTitle(ocrText: 'xy\nWillkommen bei Ihrer Bank\nmehr Text'),
        'Willkommen bei Ihrer Bank',
      );
    });
  });
}
