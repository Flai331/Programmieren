import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/import_service.dart';

/// So sieht der Export des Rechnungsgenerators aus.
String _export({
  Map<String, dynamic>? design,
  String? lastInvoiceNumber,
  Map<String, dynamic>? topHeader,
  List<Map<String, dynamic>>? customers,
}) =>
    jsonEncode({
      'beebrain_import': 1,
      'exported_at': '2026-08-23T10:00:00.000Z',
      'source': 'RECHNUNGSGENERATOR WebApp',
      'design': design ??
          {
            'senderName': 'Imkerei Otte',
            'senderEmail': 'imker@example.de',
            'senderStreet': 'Blütenweg 3',
            'senderCity': '26123 Oldenburg',
            'senderPhone': '0441 123456',
            'senderTaxId': 'DE123456789',
            'senderWebsite': 'imkerei-otte.de',
            'senderAccountHolder': 'Klaas Otte',
            'senderIban': 'DE02120300000000202051',
            'senderBic': 'BYLADEM1001',
            'senderBank': 'Beispielbank',
            'senderPaypal': 'paypal.me/imker',
            'headerTextColor': '#fda085',
            'headerTextSize': '24',
          },
      if (lastInvoiceNumber != null) 'lastInvoiceNumber': lastInvoiceNumber,
      if (topHeader != null) 'topHeader': topHeader,
      if (customers != null) 'customers': customers,
    });

void main() {
  group('Datei einlesen', () {
    test('gültiger Export wird angenommen', () {
      final data = ImportParser.decode(_export());
      expect(data['design'], isA<Map>());
    });

    test('leere Datei wird abgelehnt', () {
      expect(() => ImportParser.decode('   '),
          throwsA(isA<ImportFormatException>()));
    });

    test('kein JSON wird mit Erklärung abgelehnt', () {
      expect(
        () => ImportParser.decode('<html>kein json</html>'),
        throwsA(predicate((e) =>
            e is ImportFormatException &&
            e.message.contains('kein gültiges JSON'))),
      );
    });

    test('JSON ohne übernehmbare Daten wird abgelehnt', () {
      expect(() => ImportParser.decode('{"irgendwas": 1}'),
          throwsA(isA<ImportFormatException>()));
    });

    test('roh kopiertes invoiceDesign wird auch angenommen', () {
      // Falls jemand den Wert direkt aus den Entwicklerwerkzeugen kopiert.
      final data = ImportParser.decode(
          '{"senderName":"Imkerei Otte","senderCity":"26123 Oldenburg"}');
      final firma = ImportParser.toCompany(data);
      expect(firma?.name, 'Imkerei Otte');
    });

    test('JSON-Liste wird abgelehnt', () {
      expect(() => ImportParser.decode('[1,2,3]'),
          throwsA(isA<ImportFormatException>()));
    });
  });

  group('Absenderdaten werden zur Firma', () {
    test('alle Felder landen richtig', () {
      final firma = ImportParser.toCompany(ImportParser.decode(_export()))!;
      expect(firma.name, 'Imkerei Otte');
      expect(firma.email, 'imker@example.de');
      expect(firma.street, 'Blütenweg 3');
      expect(firma.phone, '0441 123456');
      expect(firma.taxId, 'DE123456789');
      expect(firma.website, 'imkerei-otte.de');
      expect(firma.accountHolder, 'Klaas Otte');
      expect(firma.iban, 'DE02120300000000202051');
      expect(firma.bic, 'BYLADEM1001');
      expect(firma.bank, 'Beispielbank');
      expect(firma.paypal, 'paypal.me/imker');
    });

    test('PLZ wird vom Ort getrennt', () {
      // Der Generator führt beides in einem Feld.
      final firma = ImportParser.toCompany(ImportParser.decode(_export()))!;
      expect(firma.zipcode, '26123');
      expect(firma.city, 'Oldenburg');
    });

    test('Ort ohne PLZ bleibt unverändert', () {
      final data = ImportParser.decode(_export(design: {
        'senderName': 'Imkerei Otte',
        'senderCity': 'Oldenburg',
      }));
      final firma = ImportParser.toCompany(data)!;
      expect(firma.zipcode, '');
      expect(firma.city, 'Oldenburg');
    });

    test('ohne Absendername und ohne Bestand kein Datensatz', () {
      final data = ImportParser.decode(_export(design: {'senderCity': 'X'}));
      expect(ImportParser.toCompany(data), isNull);
    });

    test('bestehende Angaben werden ergänzt, nicht gelöscht', () {
      final bestehend = CompanyModel(
        id: 'c1',
        name: 'Alt',
        email: 'alt@example.de',
        street: 'Altstraße 1',
        city: 'Altstadt',
        zipcode: '11111',
        phone: '999',
        iban: 'DE-ALT',
        invoiceNumberPattern: 'ALT-{SEQ:4}',
        createdAt: DateTime(2026, 1, 1),
      );
      // Quelle kennt nur den Namen
      final data = ImportParser.decode(
          _export(design: {'senderName': 'Imkerei Otte'}));
      final firma = ImportParser.toCompany(data, existing: bestehend)!;

      expect(firma.id, 'c1', reason: 'Firma wird ersetzt, nicht verdoppelt');
      expect(firma.name, 'Imkerei Otte', reason: 'neuer Wert gewinnt');
      expect(firma.email, 'alt@example.de', reason: 'Bestand bleibt');
      expect(firma.iban, 'DE-ALT');
      expect(firma.zipcode, '11111');
      expect(firma.invoiceNumberPattern, 'ALT-{SEQ:4}',
          reason: 'Nummernmuster gehört nicht zur Vorlage');
      expect(firma.createdAt, DateTime(2026, 1, 1));
    });
  });

  group('Design', () {
    test('Farbe und Schriftgröße werden übernommen', () {
      final data = ImportParser.decode(_export());
      final design = ImportParser.toDesignSettings(data, companyId: 'c1');
      expect(design.headerTextColor, '#fda085');
      expect(design.headerTextSize, 24);
      expect(design.companyId, 'c1');
    });

    test('fehlende Angaben behalten die Vorgaben', () {
      final data =
          ImportParser.decode(_export(design: {'senderName': 'Nur Name'}));
      final design = ImportParser.toDesignSettings(data, companyId: 'c1');
      expect(design.headerTextColor, '#000000');
      expect(design.headerTextSize, 16);
    });

    test('Position des Briefkopfs wird übernommen', () {
      final data = ImportParser.decode(_export(topHeader: {
        'x': '10',
        'y': '20',
        'width': '300',
        'height': '80',
      }));
      final design = ImportParser.toDesignSettings(data, companyId: 'c1');
      expect(design.headerX, 10);
      expect(design.headerY, 20);
      expect(design.headerWidth, 300);
      expect(design.headerHeight, 80);
    });

    test('fehlende Position lässt bestehende Werte stehen', () {
      final bestehend = DesignSettingsModel(
        id: 'd1',
        companyId: 'c1',
        headerX: 5,
        headerWidth: 100,
        createdAt: DateTime(2026, 1, 1),
      );
      final design = ImportParser.toDesignSettings(
        ImportParser.decode(_export()),
        companyId: 'c1',
        existing: bestehend,
      );
      expect(design.id, 'd1');
      expect(design.headerX, 5);
      expect(design.headerWidth, 100);
    });
  });

  group('Bilder', () {
    const einPixelPng =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    test('Logo als Data-URL wird erkannt', () {
      final data = ImportParser.decode(_export(design: {
        'senderName': 'X',
        'logo': einPixelPng,
      }));
      expect(ImportParser.logoDataUrl(data), einPixelPng);
      expect(ImportParser.bytesFromDataUrl(einPixelPng), isNotEmpty);
      expect(ImportParser.extensionFromDataUrl(einPixelPng), '.png');
    });

    test('Briefkopf als Data-URL wird erkannt', () {
      final data = ImportParser.decode(_export(design: {
        'senderName': 'X',
        'topHeader': einPixelPng,
      }));
      expect(ImportParser.headerDataUrl(data), einPixelPng);
    });

    test('Nicht-Bild-Werte werden ignoriert', () {
      final data = ImportParser.decode(_export(design: {
        'senderName': 'X',
        'logo': 'https://example.de/logo.png',
      }));
      expect(ImportParser.logoDataUrl(data), isNull);
    });

    test('kaputte Base64-Daten werfen nicht', () {
      expect(ImportParser.bytesFromDataUrl('data:image/png;base64,###'),
          isNull);
      expect(ImportParser.bytesFromDataUrl('ohnekomma'), isNull);
    });

    test('Dateiendung folgt dem Bildtyp', () {
      expect(ImportParser.extensionFromDataUrl('data:image/jpeg;base64,AA'),
          '.jpg');
      expect(ImportParser.extensionFromDataUrl('data:image/webp;base64,AA'),
          '.webp');
      expect(ImportParser.extensionFromDataUrl('data:image/unbekannt;base64,AA'),
          '.png');
    });
  });

  group('Optionale Kunden', () {
    test('werden übernommen, wenn vorhanden', () {
      final data = ImportParser.decode(_export(customers: [
        {
          'id': 'k1',
          'name': 'Hofladen Meier',
          'street': 'Dorfstraße 7',
          'city': '26123 Oldenburg',
          'email': 'meier@example.de',
        },
      ]));
      final kunden = ImportParser.toCustomers(data);
      expect(kunden, hasLength(1));
      expect(kunden.single.name, 'Hofladen Meier');
      expect(kunden.single.zipcode, '26123');
      expect(kunden.single.city, 'Oldenburg');
    });

    test('Einträge ohne Namen werden übersprungen', () {
      final data = ImportParser.decode(_export(customers: [
        {'street': 'ohne Namen'},
        {'name': 'Gültig'},
      ]));
      expect(ImportParser.toCustomers(data).map((k) => k.name), ['Gültig']);
    });

    test('ohne Kundenliste bleibt es leer', () {
      expect(ImportParser.toCustomers(ImportParser.decode(_export())),
          isEmpty);
    });
  });

  group('Vorschau und Rechnungsnummer', () {
    test('Vorschau nennt Absender und Inhalte', () {
      final data = ImportParser.decode(_export(
        lastInvoiceNumber: 'RE-2026-005',
        customers: [
          {'name': 'A'},
          {'name': 'B'}
        ],
      ));
      final zeilen = ImportParser.describe(data);
      expect(zeilen.join('\n'), contains('Imkerei Otte'));
      expect(zeilen.join('\n'), contains('2 Kunden'));
      expect(zeilen.join('\n'), contains('RE-2026-005'));
    });

    test('letzte Rechnungsnummer wird gelesen', () {
      final data =
          ImportParser.decode(_export(lastInvoiceNumber: 'RE-2026-005'));
      expect(ImportParser.lastInvoiceNumber(data), 'RE-2026-005');
    });

    test('ohne Nummer null', () {
      expect(ImportParser.lastInvoiceNumber(ImportParser.decode(_export())),
          isNull);
    });
  });

  group('Echte Ausgabe der WebApp', () {
    // Wortwörtlich das, was exportForBeeBrain() im Rechnungsgenerator
    // erzeugt. Ändert sich dort das Format, schlägt dieser Test fehl.
    const ausWebApp = r'''
{
  "beebrain_import": 1,
  "exported_at": "2026-08-23T10:00:00.000Z",
  "source": "RECHNUNGSGENERATOR WebApp",
  "design": {
    "senderName": "Imkerei Otte",
    "senderCity": "26123 Oldenburg",
    "senderIban": "DE02120300000000202051",
    "headerTextColor": "#fda085",
    "headerTextSize": "24",
    "logo": "data:image/png;base64,iVBORw0KGgo="
  },
  "lastInvoiceNumber": "RE-2026-005",
  "topHeader": {
    "x": "10",
    "y": "20",
    "width": "300",
    "height": "80"
  }
}
''';

    test('lässt sich einlesen', () {
      final data = ImportParser.decode(ausWebApp);
      expect(data['source'], 'RECHNUNGSGENERATOR WebApp');
    });

    test('Absender und Bankverbindung kommen an', () {
      final firma = ImportParser.toCompany(ImportParser.decode(ausWebApp))!;
      expect(firma.name, 'Imkerei Otte');
      expect(firma.zipcode, '26123');
      expect(firma.city, 'Oldenburg');
      expect(firma.iban, 'DE02120300000000202051');
    });

    test('Design und Briefkopf-Position kommen an', () {
      final data = ImportParser.decode(ausWebApp);
      final design = ImportParser.toDesignSettings(data, companyId: 'c1');
      expect(design.headerTextColor, '#fda085');
      expect(design.headerTextSize, 24);
      expect(design.headerX, 10);
      expect(design.headerY, 20);
      expect(design.headerWidth, 300);
      expect(design.headerHeight, 80);
    });

    test('Logo wird als Bild erkannt', () {
      final data = ImportParser.decode(ausWebApp);
      expect(ImportParser.logoDataUrl(data), isNotNull);
      expect(ImportParser.extensionFromDataUrl(
          ImportParser.logoDataUrl(data)!), '.png');
    });

    test('letzte Rechnungsnummer wird gemeldet', () {
      expect(ImportParser.lastInvoiceNumber(ImportParser.decode(ausWebApp)),
          'RE-2026-005');
    });
  });

  group('ImportResult', () {
    test('leeres Ergebnis wird erkannt', () {
      expect(const ImportResult().isEmpty, isTrue);
      expect(const ImportResult(companyImported: true).isEmpty, isFalse);
      expect(const ImportResult(customers: 3).isEmpty, isFalse);
    });
  });
}
