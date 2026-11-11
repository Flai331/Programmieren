import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/reports/cover_letter.dart';
import 'package:dokubox/share/templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Platzhalter', () {
    final v = templateValues(
        docNumber: '2026-0042',
        title: 'Antrag Beihilfe',
        docDate: DateTime(2026, 11, 5),
        firm: 'Beihilfestelle',
        refs: {
          'KDNR': {'12345'}
        },
        name: 'Max Müller');
    expect(fillTemplate('{titel} – Nr. {kdnr}', v), 'Antrag Beihilfe – Nr. 12345');
    expect(fillTemplate('{titel} – {az}', v), 'Antrag Beihilfe');
    expect(defaultMailBody(v), contains('anbei erhalten Sie Antrag Beihilfe (Kundennummer 12345).'));
    expect(defaultMailBody(v), endsWith('Max Müller'));
  });

  test('Anschreiben-PDF', () async {
    final bytes = await buildCoverLetter(
      senderLines: 'Max Müller\nHauptstr. 1\n04109 Leipzig',
      recipientLines: 'Beihilfestelle\nPostfach 1\n01001 Dresden',
      subject: 'Antrag auf Beihilfe – Kd 12345',
      body: 'Sehr geehrte Damen und Herren,\n\nanbei …',
      enclosures: ['Arztrechnung vom 05.11.2026'],
      fax: '0351 123',
      totalPages: 3,
      font: ByteData.sublistView(File('assets/fonts/DejaVuSans.ttf').readAsBytesSync()),
    );
    expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF'), isTrue);
  });
}
