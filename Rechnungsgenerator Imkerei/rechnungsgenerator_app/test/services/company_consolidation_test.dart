import 'package:beebrain/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Das Aufräumen der mehrfach angelegten Firmen.
///
/// Entstanden sind sie so: `insertDesignSettings` warf, weil der Tabelle
/// sechs Spalten fehlten. Der Firmen-Bildschirm legte die Firma zwar an, brach
/// dann aber ab — und bekam die gespeicherte Firma nie zu sehen. Beim nächsten
/// „Speichern" zog er deshalb eine neue Kennung. Eine Firma je Versuch.
///
/// Beim Zusammenlegen darf nichts verloren gehen. Darum steht hier nicht nur
/// „am Ende ist es eine Firma", sondern auch: jede Zeile, die vorher auf eine
/// der Doppelgängerinnen zeigte, zeigt nachher auf die behaltene, und keine
/// einzige ist verschwunden.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> datenbank() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 8));
    await DatabaseService().createSchemaForTests(db);
    addTearDown(db.close);
    return db;
  }

  Future<void> firma(Database db, String id,
      {String name = '', String erstellt = '2026-11-28T08:00:00.000'}) async {
    await db.insert('companies', {
      'id': id,
      'name': name,
      'created_at': erstellt,
    });
  }

  /// Eine Zeile in jeder der vier Tabellen, die auf eine Firma zeigen.
  Future<void> anhaengsel(Database db, String companyId, String marke) async {
    await db.insert('invoices', {'id': 'r-$marke', 'company_id': companyId});
    await db.insert(
        'design_settings', {'id': 'd-$marke', 'company_id': companyId});
    await db.insert(
        'address_templates', {'id': 'v-$marke', 'company_id': companyId});
    await db.insert('letters', {'id': 'b-$marke', 'company_id': companyId});
  }

  Future<List<String>> firmenIds(Database db) async =>
      (await db.query('companies', orderBy: 'id'))
          .map((f) => f['id'] as String)
          .toList();

  Future<List<String>> zeigenAuf(Database db, String tabelle) async =>
      (await db.query(tabelle, orderBy: 'id'))
          .map((r) => r['company_id'] as String)
          .toList();

  test('eine einzelne Firma bleibt unangetastet', () async {
    final db = await datenbank();
    await firma(db, 'einzig', name: 'Imkerei Otte');
    await anhaengsel(db, 'einzig', '1');

    await DatabaseService.consolidateCompanies(db);

    expect(await firmenIds(db), ['einzig']);
    expect(await zeigenAuf(db, 'invoices'), ['einzig']);
  });

  test('gar keine Firma ist auch kein Problem', () async {
    final db = await datenbank();
    await DatabaseService.consolidateCompanies(db);
    expect(await firmenIds(db), isEmpty);
  });

  test('die Firma mit den meisten ausgefüllten Feldern bleibt', () async {
    final db = await datenbank();
    // Die leeren zuerst und mit älterem Datum: nur der Inhalt darf
    // entscheiden, nicht die Reihenfolge und nicht das Alter.
    await firma(db, 'leer-1', erstellt: '2026-11-28T08:00:00.000');
    await firma(db, 'leer-2', erstellt: '2026-11-28T08:30:00.000');
    await db.insert('companies', {
      'id': 'voll',
      'name': 'Imkerei Otte',
      'email': 'post@example.org',
      'street': 'Lindenweg 3',
      'city': 'Musterstadt',
      'zipcode': '12345',
      'phone': '0123',
      'created_at': '2026-11-28T09:00:00.000',
    });

    await DatabaseService.consolidateCompanies(db);

    expect(await firmenIds(db), ['voll']);
  });

  test('bei gleichem Inhalt bleibt die älteste', () async {
    final db = await datenbank();
    await firma(db, 'jung', name: 'A', erstellt: '2026-11-28T10:00:00.000');
    await firma(db, 'alt', name: 'A', erstellt: '2026-11-28T08:00:00.000');
    await firma(db, 'mittel', name: 'A', erstellt: '2026-11-28T09:00:00.000');

    await DatabaseService.consolidateCompanies(db);

    expect(await firmenIds(db), ['alt'],
        reason: 'an der ältesten hängt am ehesten schon etwas');
  });

  test('jede Zeile wird mitgenommen, keine geht verloren', () async {
    final db = await datenbank();
    await db.insert('companies', {
      'id': 'behalten',
      'name': 'Imkerei Otte',
      'email': 'post@example.org',
      'created_at': '2026-11-28T08:00:00.000',
    });
    await firma(db, 'doppel-1', erstellt: '2026-11-28T08:10:00.000');
    await firma(db, 'doppel-2', erstellt: '2026-11-28T08:20:00.000');

    await anhaengsel(db, 'behalten', 'a');
    await anhaengsel(db, 'doppel-1', 'b');
    await anhaengsel(db, 'doppel-2', 'c');

    await DatabaseService.consolidateCompanies(db);

    expect(await firmenIds(db), ['behalten']);

    for (final tabelle in DatabaseService.companyReferencingTables) {
      final verweise = await zeigenAuf(db, tabelle);
      expect(verweise.length, 3,
          reason: 'in $tabelle ist eine Zeile verschwunden');
      expect(verweise, everyElement('behalten'),
          reason: 'in $tabelle zeigt eine Zeile noch ins Leere');
    }
  });

  test('alle vier Tabellen sind wirklich erfasst', () async {
    // Hält die Liste im Dienst gegen das Schema: käme eine fünfte Tabelle mit
    // company_id dazu und niemand trüge sie ein, blieben ihre Zeilen beim
    // Zusammenlegen zurück und zeigten auf eine gelöschte Firma.
    final db = await datenbank();
    final tabellen = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'] as String);

    final mitFirma = <String>[];
    for (final t in tabellen) {
      final spalten = await db.rawQuery('PRAGMA table_info($t)');
      if (spalten.any((s) => s['name'] == 'company_id')) mitFirma.add(t);
    }

    expect(mitFirma..sort(),
        [...DatabaseService.companyReferencingTables]..sort());
  });
}
