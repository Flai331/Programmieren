import 'package:beebrain/services/database_service.dart';
import 'package:beebrain/services/personalization_service.dart';
import 'package:beebrain/utils/invoice_number_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Das Rechnungsnummer-Format zieht von der Firma in die App-Einstellungen.
///
/// Warum: an der Firma war es am falschen Ort. Ohne angelegte Firmendaten war
/// es nicht einzustellen — die Karte in den Einstellungen zeigte dann ein
/// Rädchen, das sich nie beruhigte —, und jedes Speichern der Firmendaten
/// setzte es still zurück, weil der Firmen-Bildschirm die Firma ohne das
/// Format neu aufbaute.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final dienst = PersonalizationService();

  Future<Database> frischeDb() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 8));
    await DatabaseService().createSchemaForTests(db);
    dienst.databaseOverride = db;
    addTearDown(() async {
      dienst.databaseOverride = null;
      dienst.resetForTests();
      await db.close();
    });
    return db;
  }

  Future<void> firmaMitFormat(Database db, String id, String format) async {
    await db.insert('companies', {
      'id': id,
      'name': 'Imkerei $id',
      'invoice_number_pattern': format,
      'created_at': '2026-11-28T08:00:00.000',
    });
  }

  Future<String?> gespeichertesFormat(Database db) async {
    final reihen = await db.query('app_settings',
        where: 'name = ?', whereArgs: [AppTexts.invoiceNumberPattern]);
    return reihen.isEmpty ? null : reihen.single['value'] as String;
  }

  group('Texte in den App-Einstellungen', () {
    test('ohne Eintrag kommt die Vorgabe', () async {
      await frischeDb();
      await dienst.load();
      expect(dienst.text(AppTexts.invoiceNumberPattern, 'RE-{JAHR}-{NR:3}'),
          'RE-{JAHR}-{NR:3}');
    });

    test('gesetzt, gelesen — und nach einem Neustart noch da', () async {
      final db = await frischeDb();
      await dienst.load();
      await dienst.setText(AppTexts.invoiceNumberPattern, 'IM-{JAHR2}-{NR:4}');
      expect(
          dienst.text(AppTexts.invoiceNumberPattern, 'egal'), 'IM-{JAHR2}-{NR:4}');

      // Neu laden heißt: aus der Datenbank, nicht aus dem Gedächtnis.
      dienst.resetForTests();
      dienst.databaseOverride = db;
      await dienst.load();
      expect(dienst.text(AppTexts.invoiceNumberPattern, 'egal'),
          'IM-{JAHR2}-{NR:4}');
    });

    test('ein leer gespeicherter Wert zählt als nicht gesetzt', () async {
      await frischeDb();
      await dienst.load();
      await dienst.setText(AppTexts.invoiceNumberPattern, '   ');
      expect(dienst.text(AppTexts.invoiceNumberPattern, 'RE-{JAHR}-{NR:3}'),
          'RE-{JAHR}-{NR:3}',
          reason: 'sonst käme eine Rechnung ganz ohne Nummer heraus');
    });

    test('Zahlen und Texte kommen sich nicht in die Quere', () async {
      await frischeDb();
      await dienst.load();
      await dienst.setNumber(AppNumbers.warmerFirstHours, 36);
      await dienst.setText(AppTexts.invoiceNumberPattern, 'RE-{JAHR}-{NR:3}');

      expect(dienst.number(AppNumbers.warmerFirstHours, 48), 36);
      expect(dienst.text(AppTexts.invoiceNumberPattern, 'x'),
          'RE-{JAHR}-{NR:3}');
      // Die Stunden sind auch als Text lesbar — eine Tabelle, zwei Sichten.
      expect(dienst.text(AppNumbers.warmerFirstHours, 'x'), '36.0');
    });
  });

  group('Umzug beim Update auf v8', () {
    test('ein eigenes Format wird übernommen', () async {
      final db = await frischeDb();
      await firmaMitFormat(db, 'f1', 'IM-{JAHR}-{NR:4}');

      await DatabaseService.moveInvoiceNumberPattern(db);

      expect(await gespeichertesFormat(db), 'IM-{JAHR}-{NR:4}');
    });

    test('die kaputte englische Vorgabe wird NICHT übernommen', () async {
      final db = await frischeDb();
      await firmaMitFormat(db, 'f1', 'RE-{YEAR}-{SEQ:3}');

      await DatabaseService.moveInvoiceNumberPattern(db);

      expect(await gespeichertesFormat(db), isNull,
          reason: 'einen Unfall zur Einstellung zu erheben wäre das Letzte');
    });

    test('die normale Vorgabe landet nicht als Einstellung', () async {
      final db = await frischeDb();
      await firmaMitFormat(db, 'f1', InvoiceNumberGenerator.defaultPattern);

      await DatabaseService.moveInvoiceNumberPattern(db);

      expect(await gespeichertesFormat(db), isNull);
    });

    test('ein schon eingestelltes Format wird nicht überschrieben', () async {
      final db = await frischeDb();
      await db.insert('app_settings', {
        'name': AppTexts.invoiceNumberPattern,
        'value': 'SCHON-{JAHR}-{NR:3}',
      });
      await firmaMitFormat(db, 'f1', 'IM-{JAHR}-{NR:4}');

      await DatabaseService.moveInvoiceNumberPattern(db);

      expect(await gespeichertesFormat(db), 'SCHON-{JAHR}-{NR:3}');
    });

    test('ohne Firma passiert nichts', () async {
      final db = await frischeDb();
      await DatabaseService.moveInvoiceNumberPattern(db);
      expect(await gespeichertesFormat(db), isNull);
    });

    test('von mehreren Firmen zählt die erste mit brauchbarem Format',
        () async {
      final db = await frischeDb();
      await firmaMitFormat(db, 'f1', 'RE-{YEAR}-{SEQ:3}');
      await firmaMitFormat(db, 'f2', 'GUT-{JAHR}-{NR:3}');

      await DatabaseService.moveInvoiceNumberPattern(db);

      expect(await gespeichertesFormat(db), 'GUT-{JAHR}-{NR:3}');
    });

    test('zweimal umziehen ändert nichts mehr', () async {
      final db = await frischeDb();
      await firmaMitFormat(db, 'f1', 'IM-{JAHR}-{NR:4}');

      await DatabaseService.moveInvoiceNumberPattern(db);
      await DatabaseService.moveInvoiceNumberPattern(db);

      final alle = await db.query('app_settings',
          where: 'name = ?', whereArgs: [AppTexts.invoiceNumberPattern]);
      expect(alle, hasLength(1));
    });
  });

  test('der ganze Weg: altes Format an der Firma → Dienst liest es',
      () async {
    final db = await frischeDb();
    await firmaMitFormat(db, 'f1', 'IM-{JAHR}-{NR:4}');

    await DatabaseService.moveInvoiceNumberPattern(db);
    await dienst.load();

    final format = dienst.text(
        AppTexts.invoiceNumberPattern, InvoiceNumberGenerator.defaultPattern);
    expect(format, 'IM-{JAHR}-{NR:4}');
    expect(
      InvoiceNumberGenerator.generate(
          pattern: format,
          existingNumbers: const [],
          date: DateTime(2026, 5, 17)),
      'IM-2026-0001',
    );
  });
}
