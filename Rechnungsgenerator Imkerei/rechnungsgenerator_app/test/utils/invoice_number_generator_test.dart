import 'package:beebrain/models/company_model.dart';
import 'package:beebrain/utils/invoice_number_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Rechnungsnummer-Generator — und vor allem das, was passiert, wenn das
/// eingestellte Format nicht taugt.
///
/// Der Anlass: die Vorgabe im `CompanyModel` stand auf `RE-{YEAR}-{SEQ:3}`,
/// also auf englischen Platzhaltern. Der Generator kennt nur deutsche. Was er
/// nicht kennt, ließ er wörtlich stehen — jede Rechnung einer frisch
/// angelegten Firma hätte also „RE-{YEAR}-{SEQ:3}" geheißen, und zwar **jede
/// dieselbe**. Für Rechnungsnummern ist das kein Schönheitsfehler.
///
/// Dass es nie auffiel, lag daran, dass es für diese Datei vorher kein
/// Gegenstück im Testordner gab.
void main() {
  const jahr2026 = 2026;
  final imJahr2026 = DateTime(jahr2026, 5, 17);

  group('unbekannte Platzhalter erkennen', () {
    test('die englischen aus der alten Vorgabe', () {
      expect(InvoiceNumberGenerator.unknownPlaceholders('RE-{YEAR}-{SEQ:3}'),
          ['{YEAR}', '{SEQ:3}']);
    });

    test('die eigene Vorgabe ist sauber', () {
      expect(
          InvoiceNumberGenerator.unknownPlaceholders(
              InvoiceNumberGenerator.defaultPattern),
          isEmpty);
      expect(
          InvoiceNumberGenerator.unknownPlaceholders(
              InvoiceNumberGenerator.quoteDefaultPattern),
          isEmpty);
    });

    test('jede angebotene Variable gilt als bekannt', () {
      // Sonst böte die Oberfläche Bausteine an, die der Generator ablehnt.
      for (final v in InvoiceNumberGenerator.variables) {
        expect(InvoiceNumberGenerator.unknownPlaceholders('X${v.variable}'),
            isEmpty,
            reason: '${v.variable} steht zur Auswahl, gilt aber als unbekannt');
      }
    });

    test('KUNDENNR wird nicht mit KUNDE verwechselt', () {
      expect(InvoiceNumberGenerator.unknownPlaceholders('{KUNDENNR:4}'),
          isEmpty);
      expect(InvoiceNumberGenerator.unknownPlaceholders('{KUNDENNRX}'),
          ['{KUNDENNRX}']);
    });

    test('Text ohne Platzhalter stört nicht', () {
      expect(InvoiceNumberGenerator.unknownPlaceholders('RE-2026-{NR:3}'),
          isEmpty);
    });
  });

  group('Beanstandungen in Klartext', () {
    test('ein taugliches Format hat keine', () {
      expect(
          InvoiceNumberGenerator.problems(InvoiceNumberGenerator.defaultPattern),
          isEmpty);
    });

    test('die alte englische Vorgabe hat gleich zwei', () {
      final gefunden =
          InvoiceNumberGenerator.problems('RE-{YEAR}-{SEQ:3}');
      expect(gefunden, hasLength(2));
      expect(gefunden.first, contains('{YEAR}'));
      expect(gefunden.first, contains('{SEQ:3}'));
      expect(gefunden.last, contains('{NR}'));
    });

    test('ohne Laufnummer bekäme jede Rechnung dieselbe Nummer', () {
      final gefunden = InvoiceNumberGenerator.problems('RE-{JAHR}');
      expect(gefunden, hasLength(1));
      expect(gefunden.single, contains('dieselbe Nummer'));
    });

    test('ein einzelner unbekannter Platzhalter wird einzeln benannt', () {
      final gefunden = InvoiceNumberGenerator.problems('RE-{JAHRX}-{NR:3}');
      expect(gefunden.single, contains('{JAHRX}'));
      expect(gefunden.single, isNot(contains('Diese Platzhalter')));
    });

    test('leer ist auch eine Beanstandung', () {
      expect(InvoiceNumberGenerator.problems('   ').single, contains('leer'));
    });

    test('isUsable sagt dasselbe wie problems', () {
      for (final format in [
        InvoiceNumberGenerator.defaultPattern,
        'RE-{YEAR}-{SEQ:3}',
        'RE-{JAHR}',
        '',
        '{KUNDE:3}-{JAHR}-{NR:4}',
      ]) {
        expect(InvoiceNumberGenerator.isUsable(format),
            InvoiceNumberGenerator.problems(format).isEmpty,
            reason: 'für „$format"');
      }
    });
  });

  group('erzeugen', () {
    test('ein taugliches Format bleibt unangetastet', () {
      expect(
        InvoiceNumberGenerator.generate(
            pattern: 'RE-{JAHR}-{NR:3}',
            existingNumbers: const [],
            date: imJahr2026),
        'RE-2026-001',
      );
    });

    test('zählt über die vorhandenen Nummern weiter', () {
      expect(
        InvoiceNumberGenerator.generate(
            pattern: 'RE-{JAHR}-{NR:3}',
            existingNumbers: const ['RE-2026-001', 'RE-2026-007'],
            date: imJahr2026),
        'RE-2026-008',
      );
    });

    test('ein untaugliches Format weicht auf die Vorgabe aus', () {
      expect(
        InvoiceNumberGenerator.generate(
            pattern: 'RE-{YEAR}-{SEQ:3}',
            existingNumbers: const [],
            date: imJahr2026),
        'RE-2026-001',
        reason: 'lieber eine richtige Nummer als geschweifte Klammern',
      );
    });

    test('und zwei Rechnungen bekommen dann verschiedene Nummern', () {
      // Das ist der eigentliche Schaden gewesen: nicht die hässliche Nummer,
      // sondern zweimal dieselbe.
      final erste = InvoiceNumberGenerator.generate(
          pattern: 'RE-{YEAR}-{SEQ:3}',
          existingNumbers: const [],
          date: imJahr2026);
      final zweite = InvoiceNumberGenerator.generate(
          pattern: 'RE-{YEAR}-{SEQ:3}',
          existingNumbers: [erste],
          date: imJahr2026);
      expect(zweite, isNot(erste));
      expect(zweite, 'RE-2026-002');
    });

    test('beim Angebot bleibt das AN- erhalten', () {
      expect(
        InvoiceNumberGenerator.generate(
          pattern: 'AN-RE-{YEAR}-{SEQ:3}',
          fallback: InvoiceNumberGenerator.quoteDefaultPattern,
          existingNumbers: const [],
          date: imJahr2026,
        ),
        'AN-2026-001',
      );
    });

    test('nie bleiben geschweifte Klammern in der Nummer stehen', () {
      for (final kaputt in [
        'RE-{YEAR}-{SEQ:3}',
        '{MONTH}-{NR:3}',
        'RE-{JAHR}',
        '',
        '{}',
      ]) {
        final nummer = InvoiceNumberGenerator.generate(
            pattern: kaputt, existingNumbers: const [], date: imJahr2026);
        expect(nummer, isNot(contains('{')), reason: 'aus „$kaputt"');
        expect(nummer, isNot(contains('}')), reason: 'aus „$kaputt"');
      }
    });

    test('Kunde und Kundennummer kommen durch', () {
      expect(
        InvoiceNumberGenerator.generate(
          pattern: '{KUNDE:3}-K{KUNDENNR:4}-{JAHR2}-{NR:2}',
          existingNumbers: const [],
          customerName: 'Mustermann',
          customerNumber: 42,
          date: imJahr2026,
        ),
        'MUS-K0042-26-01',
      );
    });
  });

  group('Vorschau', () {
    test('zeigt, was wirklich herauskäme — auch beim Ausweichen', () {
      final jetzt = DateTime.now().year;
      expect(InvoiceNumberGenerator.preview('RE-{YEAR}-{SEQ:3}'),
          'RE-$jetzt-001');
      expect(InvoiceNumberGenerator.preview('RE-{JAHR}-{NR:4}'),
          'RE-$jetzt-0001');
    });

    test('nie geschweifte Klammern in der Vorschau', () {
      expect(InvoiceNumberGenerator.preview('{MONTH}/{SEQ}'),
          isNot(contains('{')));
    });
  });

  test('die Vorgabe im Firmen-Modell taugt', () {
    // Genau hier lag der Fehler: das Modell gab ein Format vor, das der
    // Generator nicht lesen konnte.
    final firma = CompanyModel(
      id: 'x',
      name: 'Imkerei',
      email: '',
      street: '',
      city: '',
      zipcode: '',
      phone: '',
      createdAt: DateTime(jahr2026),
    );
    expect(InvoiceNumberGenerator.isUsable(firma.invoiceNumberPattern), isTrue,
        reason: 'eine frisch angelegte Firma muss brauchbare Nummern bekommen');
    expect(
      InvoiceNumberGenerator.generate(
          pattern: firma.invoiceNumberPattern,
          existingNumbers: const [],
          date: imJahr2026),
      'RE-2026-001',
    );
  });
}
