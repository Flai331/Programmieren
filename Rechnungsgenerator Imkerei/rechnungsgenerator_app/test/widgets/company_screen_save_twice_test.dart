import 'package:beebrain/screens/company_screen.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Zweimal „Speichern" darf keine zweite Firma anlegen.
///
/// Der Bericht vom Gerät zeigte zwei Kennungen für dieselbe Imkerei:
/// `INSERT [companies] id=f910f81c-…`, und auf dem Bildschirm daneben
/// `7242e1bb-…`. Die Ursache war nicht das Anlegen, sondern die Reihenfolge:
/// `_company` wurde erst **nach** den Design-Einstellungen gemerkt. Und deren
/// Schreiben warf auf jedem Gerät, weil der Tabelle sechs Spalten fehlten.
/// Also blieb `_company` leer, der nächste Druck auf „Speichern" zog eine
/// neue Kennung — eine Firma je Versuch.
///
/// Darum arbeitet dieser Test mit genau der kaputten Tabelle von Build 19:
/// ohne sie würde er auch ohne die Korrektur bestehen und nichts beweisen.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final datenbank = DatabaseService();

  /// Das Schema von Build 19: v8-Tabellen, aber `design_settings` noch
  /// unvollständig. Jedes `insertDesignSettings` wirft hier.
  Future<Database> datenbankVonBuild19() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 8));
    await datenbank.createSchemaForTests(db);
    await db.execute('DROP TABLE design_settings');
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
    datenbank.databaseForTests = db;
    addTearDown(() async {
      datenbank.databaseForTests = null;
      await db.close();
    });
    return db;
  }

  Future<void> ausfuellen(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Firmenname *'), 'Imkerei Otte');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email *'), 'post@example.org');
    await tester.enterText(
        find.widgetWithText(TextField, 'Straße *'), 'Am Bienenstand 1');
    await tester.enterText(find.widgetWithText(TextField, 'Stadt *'), 'Soltau');
    await tester.pump();
  }

  /// Einmal auf „Speichern" drücken — und warten, bis es wirklich durch ist.
  ///
  /// Das Warten ist hier keine Höflichkeit, sondern der Kern: `_isSaving`
  /// schaltet den Knopf ab, solange gespeichert wird. Ein zweiter Druck auf
  /// den abgeschalteten Knopf täte nichts, und der Test prüfte nichts. Darum
  /// steht vor jedem Druck die Zusicherung, dass der Knopf bereit ist.
  ///
  /// Jede Datenbank-Abfrage braucht eine Runde echte Zeit (das Isolat von
  /// sqflite) und danach ein Bild, damit die Fortsetzung in der gestellten
  /// Welt ankommt. Speichern macht mehrere Abfragen hintereinander, also
  /// mehrere Runden.
  Future<void> speichern(WidgetTester tester) async {
    final knopf = find.widgetWithText(ElevatedButton, 'Speichern');
    expect(tester.widget<ElevatedButton>(knopf).onPressed, isNotNull,
        reason: 'der Knopf war noch abgeschaltet — ein Druck darauf wäre '
            'wirkungslos und der Test wertlos');
    await tester.tap(knopf);
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (tester.widget<ElevatedButton>(knopf).onPressed != null) return;
    }
    fail('das Speichern wurde nicht fertig');
  }

  testWidgets('zweimal speichern legt nur eine Firma an', (tester) async {
    final db = await tester.runAsync(datenbankVonBuild19);

    await tester.pumpWidget(const MaterialApp(home: CompanyScreen()));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    await ausfuellen(tester);
    await speichern(tester);
    await speichern(tester);

    final firmen = await tester.runAsync(() => db!.query('companies'));
    expect(firmen, hasLength(1),
        reason: 'genau das stand im Bericht: zwei Kennungen für eine Imkerei');
  });

  testWidgets('und auch auf einer heilen Datenbank bleibt es eine',
      (tester) async {
    // Gegenprobe: ohne den Fehler im Schema soll sich nichts ändern.
    final db = await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 8));
      await datenbank.createSchemaForTests(db);
      datenbank.databaseForTests = db;
      addTearDown(() async {
        datenbank.databaseForTests = null;
        await db.close();
      });
      return db;
    });

    await tester.pumpWidget(const MaterialApp(home: CompanyScreen()));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    await ausfuellen(tester);
    await speichern(tester);
    await speichern(tester);

    expect(await tester.runAsync(() => db!.query('companies')), hasLength(1));
    // Und die Design-Einstellungen sind diesmal wirklich angekommen — das war
    // bis v8 auf keinem Gerät der Fall.
    expect(await tester.runAsync(() => db!.query('design_settings')),
        hasLength(1));
  });
}
