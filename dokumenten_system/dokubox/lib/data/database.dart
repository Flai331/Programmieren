import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'categories.dart';

part 'database.g.dart';

const _uuid = Uuid();

/// Alle Tabellen nutzen UUID-Primärschlüssel, `updatedAt` und Soft-Deletes
/// (`deletedAt`), damit später ein Cloud-Sync ergänzt werden kann, ohne das
/// Schema umzubauen.
class Documents extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();

  /// Fortlaufende Nummer im Schema JJJJ-NNNN, steht auch auf dem Original.
  TextColumn get docNumber => text().unique()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Datum des Dokuments (nicht des Scans).
  DateTimeColumn get docDate => dateTime().nullable()();
  DateTimeColumn get scannedAt => dateTime().clientDefault(DateTime.now)();
  TextColumn get correspondentId =>
      text().nullable().references(Correspondents, #id)();
  TextColumn get docType => text().nullable()();

  /// Wo liegt das Original: "Box 2026", Mappe, digital, vernichtet.
  TextColumn get storageLocation => text()();

  /// Pfad der PDF relativ zum App-Dokumentenverzeichnis.
  TextColumn get pdfPath => text()();
  IntColumn get pageCount => integer().withDefault(const Constant(1))();
  TextColumn get ocrText => text().withDefault(const Constant(''))();

  /// Aufbewahren bis — danach erscheint das Dokument in der Ausmistliste.
  DateTimeColumn get retentionUntil => dateTime().nullable()();

  /// Wiedervorlage/Kündigungsfrist mit Benachrichtigung.
  DateTimeColumn get reminderAt => dateTime().nullable()();
  TextColumn get reminderNote => text().nullable()();

  // ---- Rechnungen (Schema v2) ----

  /// Endbetrag in Cent.
  IntColumn get amountCents => integer().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Siehe `PaymentStatus`: zu bezahlen, wird abgebucht, bezahlt,
  /// Gutschrift. `null` = keine Zahlung betroffen.
  TextColumn get paymentStatus => text().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();

  /// Zahlungserinnerung (eigene Benachrichtigung, unabhängig von
  /// [reminderAt]).
  DateTimeColumn get paymentReminderAt => dateTime().nullable()();

  // ---- Ausfüllen (Schema v4) ----

  /// Ausgefüllte Kopie (PDF, relativ zum App-Verzeichnis). Das Original in
  /// [pdfPath] bleibt unverändert.
  TextColumn get filledPdfPath => text().nullable()();

  /// Eingetragene Texte/Haken/Unterschriften als JSON (siehe FillDocument),
  /// damit man später weiter ausfüllen kann.
  TextColumn get fillData => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unterschrift, Kürzel oder handschriftliche Vorlage (PNG mit
/// transparentem Hintergrund), z. B. am PC im Scan-Trenner gezeichnet und per
/// WLAN übertragen (Schema v4).
class SignatureTemplates extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get name => text()();

  /// Pfad der PNG relativ zum App-Verzeichnis.
  TextColumn get imagePath => text()();

  /// Höhe / Breite des Bildes.
  RealColumn get aspect => real().withDefault(const Constant(0.35))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Aufgabe/Erinnerung zu einem Dokument: was ist wann zu tun (ausfüllen,
/// versenden, bezahlen …), optional wiederkehrend (Schema v5).
class DocTasks extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get documentId => text().references(Documents, #id)();

  /// Siehe `TaskAction` (lib/data/tasks.dart), z. B. `versenden`.
  TextColumn get action => text()();

  /// Was genau zu tun ist, z. B. „an Beihilfestelle per Mail“.
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get dueAt => dateTime()();

  /// '' (einmalig), `monatlich`, `vierteljaehrlich`, `jaehrlich`.
  TextColumn get repeat => text().withDefault(const Constant(''))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Einreichung einer Rechnung bei einer Erstattungsstelle (Krankenkasse,
/// Beihilfe, Heilfürsorge, Steuererklärung …). Mehrere pro Dokument
/// möglich, z. B. Beihilfe + Private Krankenversicherung.
class Claims extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get target => text()();

  /// Siehe `ClaimStatus`.
  TextColumn get status => text()();
  DateTimeColumn get submittedAt => dateTime().nullable()();

  /// Erstatteter Betrag in Cent.
  IntColumn get reimbursedCents => integer().nullable()();
  DateTimeColumn get settledAt => dateTime().nullable()();

  /// Nachfassen, falls die Erstattung ausbleibt.
  DateTimeColumn get followUpAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Correspondents extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get name => text().unique()();

  /// Erkennungs-Keywords, mit Zeilenumbruch getrennt. Wird eines davon im
  /// OCR-Text gefunden, wird dieser Absender vorgeschlagen.
  TextColumn get aliases => text().withDefault(const Constant(''))();

  /// Kategorie der Firma (z. B. „Bank & Geldanlage“). Dokumente lassen sich
  /// darüber filtern (Schema v3).
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();

  /// Zuletzt bestätigte Werte — Grundlage der „lernenden Zuordnungen".
  TextColumn get defaultDocType => text().nullable()();
  TextColumn get defaultTagIds => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eigene Kategorien für Firmen/Absender, z. B. „Versicherung“ oder
/// „Energie & Wohnen“ (Schema v3).
class Categories extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get name => text().unique()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get name => text().unique()();
  IntColumn get color => integer().withDefault(const Constant(0xFF607D8B))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DocumentTags extends Table {
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {documentId, tagId};
}

/// Aus dem OCR-Text erkannte Referenzen (IBAN, Versicherungsschein-Nr, …),
/// damit man ein Dokument auch über z. B. die Kundennummer findet.
class ExtractedRefs extends Table {
  TextColumn get documentId => text().references(Documents, #id)();

  /// Art der Referenz: IBAN, VSNR, KDNR, RGNR, STNR, AZ …
  TextColumn get kind => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {documentId, kind, value};
}

/// Nummernvergabe: ein Zähler pro Jahr.
class Counters extends Table {
  IntColumn get year => integer()();
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {year};
}

@DriftDatabase(
  tables: [
    Documents,
    Correspondents,
    Tags,
    DocumentTags,
    ExtractedRefs,
    Counters,
    Claims,
    Categories,
    SignatureTemplates,
    DocTasks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Produktions-Datenbank im App-Datenverzeichnis.
  AppDatabase.open() : super(driftDatabase(name: 'dokubox'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Volltextindex. Wird vom Repository befüllt (kein Trigger, damit
          // Inhalt und Index immer in derselben Transaktion geschrieben werden).
          await customStatement(
            'CREATE VIRTUAL TABLE document_fts USING fts5('
            'document_id UNINDEXED, content, tokenize="unicode61")',
          );
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(documents, documents.amountCents);
            await m.addColumn(documents, documents.dueDate);
            await m.addColumn(documents, documents.paymentStatus);
            await m.addColumn(documents, documents.paidAt);
            await m.addColumn(documents, documents.paymentReminderAt);
            await m.createTable(claims);
          }
          if (from < 3) {
            await m.createTable(categories);
            await m.addColumn(correspondents, correspondents.categoryId);
            await _seedCategories();
          }
          if (from < 4) {
            await m.addColumn(documents, documents.filledPdfPath);
            await m.addColumn(documents, documents.fillData);
            await m.createTable(signatureTemplates);
          }
          if (from < 5) {
            await m.createTable(docTasks);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Standard-Kategorien und Beispiel-Firmen anlegen. Bestehende Firmen
  /// gleichen Namens bekommen nur die Kategorie, wenn sie noch keine haben.
  Future<void> _seedCategories() async {
    final ids = <String, String>{};
    for (final name in kDefaultCategories) {
      final row = await into(categories).insertReturning(
        CategoriesCompanion.insert(name: name),
      );
      ids[name] = row.id;
    }
    for (final firm in kDefaultFirms) {
      final categoryId = ids[firm.category];
      final existing = await (select(correspondents)
            ..where((c) => c.name.lower().equals(firm.name.toLowerCase())))
          .getSingleOrNull();
      if (existing == null) {
        await into(correspondents).insert(CorrespondentsCompanion.insert(
          name: firm.name,
          aliases: Value(firm.aliases.join('\n')),
          categoryId: Value(categoryId),
        ));
      } else if (existing.categoryId == null) {
        await (update(correspondents)..where((c) => c.id.equals(existing.id)))
            .write(CorrespondentsCompanion(categoryId: Value(categoryId)));
      }
    }
  }
}
