import 'package:beebrain/screens/settings_screen.dart';
import 'package:beebrain/services/connectivity_service.dart';
import 'package:beebrain/services/database_service.dart';
import 'package:beebrain/services/personalization_service.dart';
import 'package:beebrain/services/sync_service.dart';
import 'package:beebrain/utils/invoice_number_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Die Karte „Rechnungsnummern" in den Einstellungen — am echten Bildschirm.
///
/// Der gemeldete Fehler, wörtlich: „Das läd ewig". Die Karte zeigte ein
/// Rädchen, solange `_company == null` war — und gesetzt wurde `_company` nur,
/// wenn die Datenbank eine Firma hergab. Ohne angelegte Firmendaten drehte es
/// sich also für immer. Dass die Abfrage selbst schnell war, stand im
/// Protokoll: `⏱ Einstellungen: Firma laden in 36 ms`. Sie fand nur nichts.
///
/// Darum prüft dieser Test nicht „die Karte erscheint", sondern: **ohne Firma
/// ist kein Rädchen da.**
///
/// Zum `runAsync` überall: `testWidgets` läuft in einer Welt mit gestellter
/// Uhr. sqflite redet mit einem echten Hintergrund-Isolat und echten Uhren —
/// dessen Antwort kommt in der gestellten Welt nie an, der Test hing. Alles,
/// was die Datenbank anfasst, muss also durch `runAsync`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final datenbank = DatabaseService();
  final einstellungen = PersonalizationService();

  /// Legt die Datenbank an und zeigt den Bildschirm. `vorher` darf noch Zeilen
  /// einfügen, bevor der Bildschirm sie liest.
  Future<void> zeige(
    WidgetTester tester, {
    Future<void> Function(Database db)? vorher,
  }) async {
    await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 8));
      addTearDown(() async {
        datenbank.databaseForTests = null;
        einstellungen.databaseOverride = null;
        einstellungen.resetForTests();
        // Ohne das Schließen trägt der nächste Test seine Tabellen in
        // dieselbe Datenbank ein und scheitert an „table already exists".
        await db.close();
      });
      await datenbank.createSchemaForTests(db);
      datenbank.databaseForTests = db;
      einstellungen.databaseOverride = db;
      await vorher?.call(db);
      await einstellungen.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>.value(
              value: ConnectivityService()),
          ChangeNotifierProvider<SyncService>.value(value: SyncService()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // Der Firmen-Abfrage im initState echte Zeit geben, dann neu zeichnen.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 200)));
    await tester.pump();
  }

  // Alle Felder, nicht nur die interessanten: `CompanyModel.fromMap` liest
  // Straße, Ort, PLZ und Telefon als `as String` — eine fehlende Spalte wirft
  // dort, und `getAllCompanies` käme nie zurück.
  Future<void> firma(Database db) => db.insert('companies', {
        'id': 'f1',
        'name': 'Imkerei Otte',
        'email': 'post@example.org',
        'street': 'Am Bienenstand 1',
        'city': 'Neuenkirchen',
        'zipcode': '29643',
        'phone': '05195 1234',
        'created_at': '2026-11-28T08:00:00.000',
      }).then((_) {});

  Future<void> Function(Database) format(String wert) =>
      (db) => db.insert('app_settings', {
            'name': AppTexts.invoiceNumberPattern,
            'value': wert,
          }).then((_) {});

  testWidgets('ohne Firmendaten dreht sich kein Rädchen mehr', (tester) async {
    await zeige(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'genau das war der gemeldete Fehler: „Das läd ewig"');
    // Und die Karte ist wirklich benutzbar, nicht bloß leer.
    expect(find.text('Format-Vorlage'), findsOneWidget);
  });

  testWidgets('ohne Firmendaten sagt die App das auch', (tester) async {
    await zeige(tester);

    expect(find.textContaining('Firmendaten sind noch nicht angelegt'),
        findsOneWidget);
  });

  testWidgets('mit Firmendaten verschwindet der Hinweis', (tester) async {
    await zeige(tester, vorher: firma);

    expect(find.textContaining('Firmendaten sind noch nicht angelegt'),
        findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('das eingestellte Format steht im Feld', (tester) async {
    await zeige(tester, vorher: format('IM-{JAHR}-{NR:4}'));

    // Keine Firma angelegt — und das Format steht trotzdem da. Das ist der
    // ganze Grund für den Umzug in die App-Einstellungen.
    expect(find.widgetWithText(TextField, 'IM-{JAHR}-{NR:4}'), findsOneWidget);
  });

  testWidgets('ein untaugliches Format wird angemahnt', (tester) async {
    await zeige(tester, vorher: format('RE-{YEAR}-{SEQ:3}'));

    expect(find.textContaining('{YEAR}'), findsWidgets,
        reason: 'der unbekannte Platzhalter muss beim Namen genannt werden');
    expect(find.textContaining('Solange das so ist, wird die Vorgabe benutzt'),
        findsOneWidget);

    // Und die Vorschau zeigt trotzdem eine richtige Nummer, keine Klammern.
    final jahr = DateTime.now().year;
    expect(find.textContaining('RE-$jahr-001'), findsWidgets);
  });

  testWidgets('ein taugliches Format wird nicht angemahnt', (tester) async {
    await zeige(tester, vorher: format(InvoiceNumberGenerator.defaultPattern));

    expect(find.textContaining('Solange das so ist'), findsNothing);
  });
}
