import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

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

  /// Zuletzt bestätigte Werte — Grundlage der „lernenden Zuordnungen".
  TextColumn get defaultDocType => text().nullable()();
  TextColumn get defaultTagIds => text().withDefault(const Constant(''))();
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Produktions-Datenbank im App-Datenverzeichnis.
  AppDatabase.open() : super(driftDatabase(name: 'dokubox'));

  @override
  int get schemaVersion => 1;

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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
