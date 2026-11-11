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

  // ---- Schema v6 ----
  /// SHA-256 der PDF (Dubletten-Erkennung).
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get warrantyUntil => dateTime().nullable()();

  /// `garantie` oder `gewaehrleistung`.
  TextColumn get warrantyKind => text().nullable()();
  DateTimeColumn get objectionDeadline => dateTime().nullable()();

  /// Steuer-Mappe: Kategorie, Jahr, anrechenbarer Betrag (Cent).
  TextColumn get taxCategory => text().nullable()();
  IntColumn get taxYear => integer().nullable()();
  IntColumn get taxAmountCents => integer().nullable()();

  /// Vernichtungs-Protokoll.
  DateTimeColumn get destroyedAt => dateTime().nullable()();
  TextColumn get destroyedFrom => text().nullable()();

  /// Verwendungszweck für Überweisung (GiroCode).
  TextColumn get paymentReference => text().nullable()();
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

  /// Automatisch erzeugt? z. B. `widerspruch`, `garantie`,
  /// `kuendigung:<contractId>` (Schema v6).
  TextColumn get origin => text().nullable()();
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

  // ---- Schema v6: Kontakt & Vorlagen ----
  TextColumn get email => text().nullable()();
  TextColumn get fax => text().nullable()();
  TextColumn get postalAddress => text().nullable()();
  TextColumn get mailSubjectTemplate => text().nullable()();
  TextColumn get mailBodyTemplate => text().nullable()();
  TextColumn get iban => text().nullable()();
  TextColumn get bic => text().nullable()();

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


// ---------------------------------------------------------------- Schema v6

/// Vorgang/Mappe: mehrere Dokumente zu einer Sache (Antrag → Bescheid …).
class Cases extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get title => text()();

  /// `offen`, `wartet`, `erledigt`.
  TextColumn get status => text().withDefault(const Constant('offen'))();
  TextColumn get correspondentId =>
      text().nullable().references(Correspondents, #id)();
  TextColumn get refKind => text().nullable()();
  TextColumn get refValue => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CaseDocuments extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get caseId => text().references(Cases, #id)();
  TextColumn get documentId => text().references(Documents, #id)();

  /// `antrag`, `rueckfrage`, `bescheid`, `widerspruch`, `sonstiges`.
  TextColumn get role => text().withDefault(const Constant('sonstiges'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vertrag/Versicherung mit Kosten und Kündigungsfrist.
class Contracts extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get documentId => text().nullable().references(Documents, #id)();
  TextColumn get correspondentId =>
      text().nullable().references(Correspondents, #id)();
  TextColumn get title => text()();
  IntColumn get amountCents => integer().nullable()();

  /// `monatlich`, `vierteljaehrlich`, `halbjaehrlich`, `jaehrlich`, `einmalig`.
  TextColumn get interval => text().withDefault(const Constant('monatlich'))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get minTermUntil => dateTime().nullable()();
  IntColumn get noticeValue => integer().nullable()();

  /// `tage`, `wochen`, `monate`.
  TextColumn get noticeUnit => text().nullable()();

  /// `laufzeitende` oder `monatsende`.
  TextColumn get noticeToEndOf => text().nullable()();
  IntColumn get autoRenewMonths => integer().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Foto/Datei an einem Dokument (Ordner `anhaenge/`).
class Attachments extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get documentId => text().references(Documents, #id)();

  /// `foto` oder `datei`.
  TextColumn get kind => text()();
  TextColumn get relPath => text()();
  TextColumn get mime => text().withDefault(const Constant(''))();
  TextColumn get caption => text().withDefault(const Constant(''))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// „Meine Daten“ zum Einsetzen beim Ausfüllen, mehrere Personen.
class PersonalData extends Table {
  TextColumn get id => text().clientDefault(_uuid.v4)();
  TextColumn get person => text()();

  /// Vordefinierter Schlüssel (vorname, iban …) oder `frei`.
  TextColumn get key => text()();
  TextColumn get label => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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
    Cases,
    CaseDocuments,
    Contracts,
    Attachments,
    PersonalData,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Produktions-Datenbank im App-Datenverzeichnis.
  AppDatabase.open() : super(driftDatabase(name: 'dokubox'));

  @override
  int get schemaVersion => 6;

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
          await _createIndexes();
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
          if (from < 6) {
            for (final c in [
              documents.contentHash,
              documents.warrantyUntil,
              documents.warrantyKind,
              documents.objectionDeadline,
              documents.taxCategory,
              documents.taxYear,
              documents.taxAmountCents,
              documents.destroyedAt,
              documents.destroyedFrom,
              documents.paymentReference,
            ]) {
              await m.addColumn(documents, c);
            }
            for (final c in [
              correspondents.email,
              correspondents.fax,
              correspondents.postalAddress,
              correspondents.mailSubjectTemplate,
              correspondents.mailBodyTemplate,
              correspondents.iban,
              correspondents.bic,
            ]) {
              await m.addColumn(correspondents, c);
            }
            // doc_tasks entsteht bei from < 5 schon mit dieser Spalte.
            if (from >= 5) await m.addColumn(docTasks, docTasks.origin);
            await m.createTable(cases);
            await m.createTable(caseDocuments);
            await m.createTable(contracts);
            await m.createTable(attachments);
            await m.createTable(personalData);
          }
          await _createIndexes();
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

  /// Indizes für Verknüpfen (Referenzen), Vorgänge und Dubletten.
  Future<void> _createIndexes() async {
    for (final sql in const [
      'CREATE INDEX IF NOT EXISTS idx_refs_value ON extracted_refs (kind, value)',
      'CREATE INDEX IF NOT EXISTS idx_case_docs_case ON case_documents (case_id)',
      'CREATE INDEX IF NOT EXISTS idx_case_docs_doc ON case_documents (document_id)',
      'CREATE INDEX IF NOT EXISTS idx_docs_hash ON documents (content_hash)',
    ]) {
      await customStatement(sql);
    }
  }
}
