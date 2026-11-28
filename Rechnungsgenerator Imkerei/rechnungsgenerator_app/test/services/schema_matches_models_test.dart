import 'dart:io';

import 'package:beebrain/models/design_settings_model.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hält jedes Modell gegen seine Tabelle.
///
/// Der Anlass: `design_settings` fehlten sechs Spalten — `logo_width`,
/// `logo_height` und die vier Spiegel-Schalter —, die
/// `DesignSettingsModel.toMap()` schreibt. Nicht ein vergessener Umbau,
/// sondern eine von Anfang an unvollständige Tabelle. Damit schlug
/// `insertDesignSettings` auf **jedem** Gerät fehl, auch bei frischer
/// Installation, und zwar erst zur Laufzeit: beim Speichern der Firmendaten.
/// Der Übersetzer kann das nicht sehen, die statische Analyse auch nicht —
/// zwischen `'logo_width': logoWidth` und der Tabelle liegt nur eine
/// Zeichenkette.
///
/// Darum dieser Test. Er vergleicht nicht gegen abgeschriebene Listen,
/// sondern gegen die *wirklich angelegte* Datenbank (`PRAGMA table_info`) und
/// gegen die *wirklichen* Quelltexte der Modelle.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Welches Modell gehört zu welcher Tabelle. Absichtlich von Hand: ein neues
  /// Modell ohne Eintrag lässt den Test unten durchfallen, statt stillschweigend
  /// ungeprüft zu bleiben.
  const zuordnung = <String, String>{
    'address_template_model.dart': 'address_templates',
    'catalog_entry_model.dart': 'catalog_entries',
    'company_model.dart': 'companies',
    'customer_model.dart': 'customers',
    'design_settings_model.dart': 'design_settings',
    'hive_action_model.dart': 'hive_actions',
    'hive_model.dart': 'hives',
    'honey_bucket_model.dart': 'honey_buckets',
    'invoice_item_model.dart': 'invoice_items',
    'invoice_model.dart': 'invoices',
    'letter_model.dart': 'letters',
    'stock_item_model.dart': 'stock_items',
    'stock_movement_model.dart': 'stock_movements',
  };

  /// Die Schlüssel aus dem `toMap()` einer Modelldatei.
  Set<String> geschriebeneSpalten(File datei) {
    final text = datei.readAsStringSync();
    final start = text.indexOf('Map<String, dynamic> toMap()');
    if (start < 0) return const {};
    // Bis zur schließenden Klammer der Methode: die steht als einzige auf
    // zwei Leerzeichen Einrückung.
    final rest = text.substring(start);
    final ende = rest.indexOf('\n  }');
    final rumpf = ende < 0 ? rest : rest.substring(0, ende);
    return RegExp(r"'([a-z_][a-z0-9_]*)':")
        .allMatches(rumpf)
        .map((m) => m.group(1)!)
        .toSet();
  }

  /// Die Spalten, die eine Tabelle wirklich hat.
  Future<Set<String>> spaltenVon(Database db, String tabelle) async {
    final reihen = await db.rawQuery('PRAGMA table_info($tabelle)');
    return reihen.map((r) => r['name'] as String).toSet();
  }

  /// Eine Datenbank mit dem frischen Schema, wie beim ersten Start.
  Future<Database> frisch() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 8));
    await DatabaseService().createSchemaForTests(db);
    addTearDown(db.close);
    return db;
  }

  final modellDateien = Directory('lib/models')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_model.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('es gibt überhaupt Modelle zu prüfen', () {
    expect(modellDateien, isNotEmpty);
  });

  test('jedes Modell mit toMap steht in der Zuordnung', () {
    final ungeprueft = <String>[];
    for (final datei in modellDateien) {
      final name = datei.uri.pathSegments.last;
      if (geschriebeneSpalten(datei).isEmpty) continue;
      if (!zuordnung.containsKey(name)) ungeprueft.add(name);
    }
    expect(ungeprueft, isEmpty,
        reason: 'Diese Modelle schreiben in eine Tabelle, werden hier aber '
            'nicht geprüft. Trag sie in die Zuordnung ein — sonst fällt eine '
            'fehlende Spalte erst auf dem Gerät auf.');
  });

  for (final eintrag in zuordnung.entries) {
    test('${eintrag.key} passt zu ${eintrag.value}', () async {
      final datei = File('lib/models/${eintrag.key}');
      expect(datei.existsSync(), isTrue, reason: '${eintrag.key} fehlt');

      final geschrieben = geschriebeneSpalten(datei);
      expect(geschrieben, isNotEmpty,
          reason: 'kein toMap() gefunden — ist die Zuordnung noch richtig?');

      final db = await frisch();
      final vorhanden = await spaltenVon(db, eintrag.value);
      expect(vorhanden, isNotEmpty,
          reason: 'die Tabelle ${eintrag.value} wird gar nicht angelegt');

      expect(geschrieben.difference(vorhanden), isEmpty,
          reason: '${eintrag.key} schreibt in Spalten, die es in '
              '${eintrag.value} nicht gibt. Genau so war der Fehler, der das '
              'Speichern der Firmendaten unmöglich machte.');
    });
  }

  group('design_settings — der Fehler, der dazu geführt hat', () {
    /// Die Werte sind absichtlich alle verschieden: so fällt auf, wenn beim
    /// Schreiben oder Lesen zwei Spalten vertauscht sind.
    DesignSettingsModel beispiel(String companyId) => DesignSettingsModel(
          id: 'd1',
          companyId: companyId,
          headerTextColor: '#112233',
          headerTextSize: 18,
          logoUrl: '/pfad/logo.png',
          topHeaderUrl: '/pfad/kopf.png',
          logoX: 1,
          logoY: 2,
          logoWidth: 3,
          logoHeight: 4,
          headerX: 5,
          headerY: 6,
          headerWidth: 7,
          headerHeight: 8,
          logoFlipH: true,
          logoFlipV: false,
          headerFlipH: false,
          headerFlipV: true,
          tableHeaderColor: '#445566',
          layoutJson: '{"a":1}',
          createdAt: DateTime(2026, 11, 28, 9),
        );

    test('speichern und wieder lesen, Wert für Wert', () async {
      final db = await frisch();
      final dienst = DatabaseService();
      dienst.databaseForTests = db;
      addTearDown(() => dienst.databaseForTests = null);

      await dienst.insertDesignSettings(beispiel('firma-1'));
      final gelesen = await dienst.getDesignSettings('firma-1');

      expect(gelesen, isNotNull, reason: 'nichts gespeichert');
      expect(gelesen!.logoWidth, 3);
      expect(gelesen.logoHeight, 4);
      expect(gelesen.headerWidth, 7);
      expect(gelesen.headerHeight, 8);
      // Die vier Schalter einzeln: zwei an, zwei aus. Wären sie vertauscht
      // oder alle gleich, fiele es hier auf.
      expect(gelesen.logoFlipH, isTrue);
      expect(gelesen.logoFlipV, isFalse);
      expect(gelesen.headerFlipH, isFalse);
      expect(gelesen.headerFlipV, isTrue);
      expect(gelesen.logoUrl, '/pfad/logo.png');
      expect(gelesen.tableHeaderColor, '#445566');
    });

    test('die alte, unvollständige Tabelle wird beim Update nachgerüstet',
        () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 7));
      addTearDown(db.close);

      // Genau das Schema, das vor v8 auf den Geräten lag.
      await db.execute('''
        CREATE TABLE design_settings (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          header_text_color TEXT,
          header_text_size INTEGER,
          logo_url TEXT,
          top_header_url TEXT,
          logo_x REAL,
          logo_y REAL,
          header_x REAL,
          header_y REAL,
          header_width REAL,
          header_height REAL,
          layout_json TEXT,
          table_header_color TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.insert('design_settings', {
        'id': 'alt',
        'company_id': 'firma-1',
        'header_text_color': '#000000',
        'layout_json': '{"alt":true}',
      });

      // Vorher scheitert das Schreiben — das ist der gemeldete Fehler.
      await expectLater(
        db.insert('design_settings', beispiel('firma-1').toMap()),
        throwsA(anything),
      );

      await DatabaseService.repairDesignSettings(db);

      expect(await spaltenVon(db, 'design_settings'),
          containsAll(DatabaseService.designSettingsRepairColumns.keys));

      // Und jetzt geht es.
      await db.insert('design_settings', beispiel('firma-1').toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      final reihen = await db
          .query('design_settings', where: 'id = ?', whereArgs: ['d1']);
      expect(reihen.single['logo_width'], 3);

      // Die alte Zeile ist noch da: nachrüsten heißt nicht wegwerfen.
      final alt =
          await db.query('design_settings', where: 'id = ?', whereArgs: ['alt']);
      expect(alt.single['layout_json'], '{"alt":true}');
    });

    test('zweimal nachrüsten tut nicht weh', () async {
      final db = await frisch();
      await DatabaseService.repairDesignSettings(db);
      await DatabaseService.repairDesignSettings(db);
      expect(await spaltenVon(db, 'design_settings'),
          containsAll(DatabaseService.designSettingsRepairColumns.keys));
    });
  });
}
