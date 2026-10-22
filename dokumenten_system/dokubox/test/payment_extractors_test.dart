import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/finance.dart';
import 'package:dokubox/extract/payment_extractors.dart';
import 'package:dokubox/extract/suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);

  const stadtwerke = '''
Stadtwerke Musterstadt GmbH · Hauptstr. 1 · 12345 Musterstadt
Rechnung Nr. 2026-4711
Datum: 15.10.2026
Position 1  Strom Oktober           80,00 €
MwSt 19 %                            15,20 €
Rechnungsbetrag                      95,20 €
Bitte überweisen Sie den Betrag bis zum 05.11.2026 auf unser Konto.
''';

  const goae = '''
Dr. med. Anna Beispiel · Fachärztin für Innere Medizin · 54321 Ort
Privatliquidation
Rechnungsdatum 01.10.2026
Leistungen nach GOÄ
Ziffer 1  Beratung     10,72
Ziffer 5  Untersuchung 15,15
Gesamtbetrag: 1.234,56 EUR
Zahlbar innerhalb von 30 Tagen nach Rechnungsdatum.
''';

  group('extractAmountCents', () {
    test('nimmt den beschrifteten Endbetrag, nicht MwSt oder Positionen', () {
      expect(extractAmountCents(stadtwerke), 9520);
    });
    test('versteht Tausenderpunkte', () {
      expect(extractAmountCents(goae), 123456);
    });
    test('fällt auf Euro-Beträge zurück', () {
      expect(extractAmountCents('Kosten insgesamt EUR 42,10 netto'), 4210);
    });
    test('null ohne Betrag', () {
      expect(extractAmountCents('Sehr geehrte Damen und Herren'), isNull);
    });
  });

  group('extractDueDate', () {
    test('ausdrückliches Datum hinter "bis zum"', () {
      expect(extractDueDate(stadtwerke, now: now), DateTime(2026, 11, 5));
    });
    test('"zahlbar bis" mit ausgeschriebenem Monat', () {
      expect(extractDueDate('Zahlbar bis 3. Dezember 2026', now: now),
          DateTime(2026, 12, 3));
    });
    test('Frist in Tagen ab Rechnungsdatum', () {
      expect(
          extractDueDate(goae, docDate: DateTime(2026, 10, 1), now: now),
          DateTime(2026, 10, 31));
    });
    test('bei Skonto gewinnt das Netto-Ziel', () {
      const text = 'Zahlbar innerhalb von 10 Tagen mit 2 % Skonto, '
          '30 Tage netto.';
      expect(extractDueDate(text, docDate: DateTime(2026, 10, 1), now: now),
          DateTime(2026, 10, 31));
    });
    test('sofort fällig = Rechnungsdatum', () {
      expect(
          extractDueDate('Der Betrag ist sofort fällig.',
              docDate: DateTime(2026, 10, 1), now: now),
          DateTime(2026, 10, 1));
    });
    test('null ohne Hinweis', () {
      expect(extractDueDate('Vielen Dank für Ihren Einkauf', now: now),
          isNull);
    });
  });

  group('guessPaymentStatus', () {
    test('Rechnung mit Betrag → zu bezahlen', () {
      expect(guessPaymentStatus(stadtwerke), PaymentStatus.open);
    });
    test('Lastschrift → wird abgebucht', () {
      expect(
          guessPaymentStatus('Rechnung 12,00 €. Der Betrag wird am '
              '01.11.2026 von Ihrem Konto abgebucht.'),
          PaymentStatus.directDebit);
    });
    test('Kassenbon/Quittung → bezahlt', () {
      expect(guessPaymentStatus('Summe 12,40 EUR\nGegeben bar 20,00\nRückgeld 7,60'),
          PaymentStatus.paid);
      expect(guessPaymentStatus('Rechnung 50,00 € – Betrag dankend erhalten'),
          PaymentStatus.paid);
    });
    test('Guthaben → Gutschrift', () {
      expect(
          guessPaymentStatus('Ihre Jahresabrechnung: Ihr Guthaben von '
              '84,00 € überweisen wir Ihnen.'),
          PaymentStatus.credit);
    });
    test('normaler Brief → keine Zahlung', () {
      expect(guessPaymentStatus('Wir informieren Sie über neue AGB.'), isNull);
    });
  });

  group('Erstattung', () {
    test('Arztrechnung wird erkannt', () {
      expect(isMedicalBill(goae), isTrue);
      expect(isMedicalBill(stadtwerke), isFalse);
      expect(isMedicalBill('Rechnung GOZ Zahnreinigung 90,00 €'), isTrue);
    });
    test('Einreichung an die eingestellten Stellen', () {
      const finance =
          FinanceSettings(claimTargets: ['Beihilfe', 'Private Krankenversicherung']);
      expect(suggestClaimTargets(goae, finance),
          ['Beihilfe', 'Private Krankenversicherung']);
      expect(suggestClaimTargets(stadtwerke, finance), isEmpty);
    });
    test('Heilfürsorge', () {
      const finance = FinanceSettings(claimTargets: ['Heilfürsorge']);
      expect(suggestClaimTargets(goae, finance), ['Heilfürsorge']);
    });
    test('Handwerkerrechnung → Steuererklärung', () {
      const text = 'Rechnung Malerarbeiten\nArbeitskosten 400,00 €\n'
          'Gesamtbetrag 650,00 €';
      expect(isTaxRelevant(text), isTrue);
      expect(suggestClaimTargets(text, const FinanceSettings()),
          [kTaxTarget]);
    });
  });

  group('Hilfsfunktionen', () {
    test('parseEuro / formatEuro', () {
      expect(parseEuro('1.234,56'), 123456);
      expect(parseEuro('12,5'), 1250);
      expect(parseEuro('12 €'), 1200);
      expect(parseEuro('1.000'), 100000);
      expect(parseEuro(''), isNull);
      expect(parseEuro('abc'), isNull);
      expect(parseEuro(formatEuro(9520)), 9520);
    });
    test('Zahlungserinnerung X Tage vorher um 9 Uhr', () {
      expect(paymentReminderFor(DateTime(2026, 11, 5), 3, now: now),
          DateTime(2026, 11, 2, 9));
    });
    test('zu spät gescannt → Erinnerung in zwei Stunden', () {
      expect(paymentReminderFor(DateTime(2026, 10, 23), 3, now: now),
          now.add(const Duration(hours: 2)));
    });
  });

  group('applyPaymentSuggestions', () {
    test('füllt Rechnungsdaten und Erinnerung vor', () {
      final draft = DocumentDraft(docDate: DateTime(2026, 10, 15));
      applyPaymentSuggestions(draft, stadtwerke,
          finance: const FinanceSettings(leadDays: 2), now: now);
      expect(draft.paymentStatus, PaymentStatus.open);
      expect(draft.amountCents, 9520);
      expect(draft.dueDate, DateTime(2026, 11, 5));
      expect(draft.paymentReminderAt, DateTime(2026, 11, 3, 9));
      expect(draft.claims, isEmpty);
    });
    test('Arztrechnung: zu bezahlen + einreichen + Tag Gesundheit', () {
      final draft = DocumentDraft(docDate: DateTime(2026, 10, 1));
      applyPaymentSuggestions(draft, goae,
          finance: const FinanceSettings(claimTargets: ['Heilfürsorge']),
          now: now);
      expect(draft.paymentStatus, PaymentStatus.open);
      expect(draft.dueDate, DateTime(2026, 10, 31));
      expect(draft.claims.map((c) => c.target), ['Heilfürsorge']);
      expect(draft.claims.single.status, ClaimStatus.toSubmit);
      expect(draft.tagNames, contains('Gesundheit'));
    });
    test('kein Rechnungsbezug → nichts gesetzt', () {
      final draft = DocumentDraft();
      applyPaymentSuggestions(draft, 'Ihre neue Versichertenkarte', now: now);
      expect(draft.paymentStatus, isNull);
      expect(draft.amountCents, isNull);
    });
  });
}
