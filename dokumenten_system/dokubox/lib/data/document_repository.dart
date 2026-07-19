import 'package:drift/drift.dart';

import 'database.dart';

/// Filter für die Dokumentenliste/-suche.
class DocumentFilter {
  final String query;
  final String? docType;
  final int? year;
  final String? tagId;
  final String? correspondentId;
  final String? storageLocation;

  const DocumentFilter({
    this.query = '',
    this.docType,
    this.year,
    this.tagId,
    this.correspondentId,
    this.storageLocation,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      docType == null &&
      year == null &&
      tagId == null &&
      correspondentId == null &&
      storageLocation == null;
}

/// Alles, was beim Bestätigen eines Scans gespeichert wird.
class DocumentDraft {
  String title;
  DateTime? docDate;
  String? correspondentName;
  String? docType;
  List<String> tagNames;
  String storageLocation;
  DateTime? retentionUntil;
  DateTime? reminderAt;
  String? reminderNote;

  DocumentDraft({
    this.title = '',
    this.docDate,
    this.correspondentName,
    this.docType,
    List<String>? tagNames,
    this.storageLocation = '',
    this.retentionUntil,
    this.reminderAt,
    this.reminderNote,
  }) : tagNames = tagNames ?? [];
}

class DocumentRepository {
  final AppDatabase db;

  DocumentRepository(this.db);

  // ---------------------------------------------------------------- Nummern

  /// Vergibt transaktionssicher die nächste Nummer für [year]: "JJJJ-NNNN".
  Future<String> nextDocNumber({DateTime? now}) async {
    final year = (now ?? DateTime.now()).year;
    return db.transaction(() async {
      final row = await (db.select(db.counters)
            ..where((c) => c.year.equals(year)))
          .getSingleOrNull();
      final next = (row?.lastNumber ?? 0) + 1;
      await db.into(db.counters).insertOnConflictUpdate(
            CountersCompanion(year: Value(year), lastNumber: Value(next)),
          );
      return formatDocNumber(year, next);
    });
  }

  static String formatDocNumber(int year, int number) =>
      '$year-${number.toString().padLeft(4, '0')}';

  /// Rollback für einen verworfenen Scan: War [docNumber] die zuletzt
  /// vergebene Nummer und wurde kein Dokument damit angelegt, wird der
  /// Zähler zurückgedreht, damit keine Lücke in der Box entsteht.
  Future<void> releaseDocNumberIfUnused(String docNumber) async {
    final parts = docNumber.split('-');
    if (parts.length != 2) return;
    final year = int.tryParse(parts[0]);
    final number = int.tryParse(parts[1]);
    if (year == null || number == null) return;
    await db.transaction(() async {
      final used = await (db.select(db.documents)
            ..where((d) => d.docNumber.equals(docNumber)))
          .getSingleOrNull();
      if (used != null) return;
      final counter = await (db.select(db.counters)
            ..where((c) => c.year.equals(year)))
          .getSingleOrNull();
      if (counter?.lastNumber == number) {
        await db.into(db.counters).insertOnConflictUpdate(
              CountersCompanion(
                  year: Value(year), lastNumber: Value(number - 1)),
            );
      }
    });
  }

  // -------------------------------------------------------------- Dokumente

  /// Legt ein Dokument samt Tags, Referenzen und Volltextindex an und
  /// aktualisiert die lernenden Standardwerte des Absenders.
  Future<Document> createDocument({
    required String docNumber,
    required DocumentDraft draft,
    required String pdfPath,
    required int pageCount,
    required String ocrText,
    Map<String, Set<String>> refs = const {},
  }) async {
    return db.transaction(() async {
      final correspondentId = draft.correspondentName == null ||
              draft.correspondentName!.trim().isEmpty
          ? null
          : (await _ensureCorrespondent(draft.correspondentName!.trim())).id;
      final tagIds = await _ensureTags(draft.tagNames);

      final companion = DocumentsCompanion.insert(
        docNumber: docNumber,
        title: Value(draft.title.trim()),
        docDate: Value(draft.docDate),
        correspondentId: Value(correspondentId),
        docType: Value(draft.docType),
        storageLocation: draft.storageLocation,
        pdfPath: pdfPath,
        pageCount: Value(pageCount),
        ocrText: Value(ocrText),
        retentionUntil: Value(draft.retentionUntil),
        reminderAt: Value(draft.reminderAt),
        reminderNote: Value(draft.reminderNote),
      );
      final doc =
          await db.into(db.documents).insertReturning(companion);

      for (final tagId in tagIds) {
        await db.into(db.documentTags).insert(
              DocumentTagsCompanion.insert(documentId: doc.id, tagId: tagId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final entry in refs.entries) {
        for (final value in entry.value) {
          await db.into(db.extractedRefs).insert(
                ExtractedRefsCompanion.insert(
                  documentId: doc.id,
                  kind: entry.key,
                  value: value,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
      await _writeFtsEntry(doc.id, docNumber, draft, ocrText, refs);
      if (correspondentId != null) {
        await _learnDefaults(correspondentId, draft.docType, tagIds);
      }
      return doc;
    });
  }

  /// Aktualisiert Metadaten eines bestehenden Dokuments (Bearbeiten-Flow).
  Future<void> updateDocument(String id, DocumentDraft draft) async {
    await db.transaction(() async {
      final correspondentId = draft.correspondentName == null ||
              draft.correspondentName!.trim().isEmpty
          ? null
          : (await _ensureCorrespondent(draft.correspondentName!.trim())).id;
      final tagIds = await _ensureTags(draft.tagNames);

      await (db.update(db.documents)..where((d) => d.id.equals(id))).write(
        DocumentsCompanion(
          title: Value(draft.title.trim()),
          docDate: Value(draft.docDate),
          correspondentId: Value(correspondentId),
          docType: Value(draft.docType),
          storageLocation: Value(draft.storageLocation),
          retentionUntil: Value(draft.retentionUntil),
          reminderAt: Value(draft.reminderAt),
          reminderNote: Value(draft.reminderNote),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (db.delete(db.documentTags)
            ..where((t) => t.documentId.equals(id)))
          .go();
      for (final tagId in tagIds) {
        await db.into(db.documentTags).insert(
              DocumentTagsCompanion.insert(documentId: id, tagId: tagId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      final doc = await getDocument(id);
      if (doc != null) {
        // Vorhandene Referenzen wieder mit in den Index nehmen.
        final refRows = await (db.select(db.extractedRefs)
              ..where((r) => r.documentId.equals(id)))
            .get();
        final refs = <String, Set<String>>{};
        for (final row in refRows) {
          refs.putIfAbsent(row.kind, () => {}).add(row.value);
        }
        await db.customStatement(
            'DELETE FROM document_fts WHERE document_id = ?', [id]);
        await _writeFtsEntry(id, doc.docNumber, draft, doc.ocrText, refs);
        if (correspondentId != null) {
          await _learnDefaults(correspondentId, draft.docType, tagIds);
        }
      }
    });
  }

  Future<Document?> getDocument(String id) =>
      (db.select(db.documents)..where((d) => d.id.equals(id)))
          .getSingleOrNull();

  /// Soft-Delete (für späteren Sync); Volltextindex-Eintrag wird entfernt.
  Future<void> softDeleteDocument(String id) async {
    await db.transaction(() async {
      await (db.update(db.documents)..where((d) => d.id.equals(id))).write(
        DocumentsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await db.customStatement(
          'DELETE FROM document_fts WHERE document_id = ?', [id]);
    });
  }

  /// Markiert das Original als vernichtet (Scan bleibt erhalten).
  Future<void> markDestroyed(String id) async {
    await (db.update(db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        storageLocation: const Value('vernichtet'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Dokumentenliste mit Filter + optionaler FTS5-Volltextsuche als Stream.
  Stream<List<Document>> watchDocuments(DocumentFilter filter) {
    final where = StringBuffer('d.deleted_at IS NULL');
    final args = <Variable>[];

    final query = _ftsQuery(filter.query);
    var from = 'documents d';
    if (query != null) {
      from =
          'documents d JOIN document_fts f ON f.document_id = d.id AND f.document_fts MATCH ?';
      args.add(Variable.withString(query));
    }
    if (filter.docType != null) {
      where.write(' AND d.doc_type = ?');
      args.add(Variable.withString(filter.docType!));
    }
    if (filter.correspondentId != null) {
      where.write(' AND d.correspondent_id = ?');
      args.add(Variable.withString(filter.correspondentId!));
    }
    if (filter.storageLocation != null) {
      where.write(' AND d.storage_location = ?');
      args.add(Variable.withString(filter.storageLocation!));
    }
    if (filter.year != null) {
      where.write(" AND d.doc_number LIKE ?");
      args.add(Variable.withString('${filter.year}-%'));
    }
    if (filter.tagId != null) {
      where.write(
          ' AND EXISTS (SELECT 1 FROM document_tags dt WHERE dt.document_id = d.id AND dt.tag_id = ?)');
      args.add(Variable.withString(filter.tagId!));
    }

    return db
        .customSelect(
          'SELECT d.* FROM $from WHERE $where ORDER BY d.doc_number DESC',
          variables: args,
          readsFrom: {db.documents, db.documentTags},
        )
        .watch()
        .map((rows) =>
            rows.map((r) => db.documents.map(r.data)).toList());
  }

  /// Ausmistliste: Aufbewahrungsfrist abgelaufen, Original noch vorhanden.
  Stream<List<Document>> watchCleanupCandidates() {
    final now = DateTime.now();
    return (db.select(db.documents)
          ..where((d) =>
              d.deletedAt.isNull() &
              d.retentionUntil.isNotNull() &
              d.retentionUntil.isSmallerOrEqualValue(now) &
              d.storageLocation.equals('vernichtet').not())
          ..orderBy([(d) => OrderingTerm.asc(d.retentionUntil)]))
        .watch();
  }

  /// Anstehende Erinnerungen (für die Neu-Planung nach App-Start).
  Future<List<Document>> upcomingReminders() {
    return (db.select(db.documents)
          ..where((d) =>
              d.deletedAt.isNull() &
              d.reminderAt.isNotNull() &
              d.reminderAt.isBiggerThanValue(DateTime.now())))
        .get();
  }

  Future<List<String>> tagNamesForDocument(String documentId) async {
    final rows = await db.customSelect(
      'SELECT t.name AS name FROM tags t '
      'JOIN document_tags dt ON dt.tag_id = t.id '
      'WHERE dt.document_id = ? ORDER BY t.name',
      variables: [Variable.withString(documentId)],
      readsFrom: {db.tags, db.documentTags},
    ).get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  // ------------------------------------------------- Tags & Korrespondenten

  Stream<List<Tag>> watchTags() => (db.select(db.tags)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  Stream<List<Correspondent>> watchCorrespondents() =>
      (db.select(db.correspondents)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<List<Correspondent>> allCorrespondents() =>
      (db.select(db.correspondents)..where((c) => c.deletedAt.isNull())).get();

  Future<Correspondent?> getCorrespondent(String id) =>
      (db.select(db.correspondents)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<Correspondent> _ensureCorrespondent(String name) async {
    final existing = await (db.select(db.correspondents)
          ..where((c) => c.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing;
    return db.into(db.correspondents).insertReturning(
          CorrespondentsCompanion.insert(name: name, aliases: Value(name)),
        );
  }

  Future<List<String>> _ensureTags(List<String> names) async {
    final ids = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final existing = await (db.select(db.tags)
            ..where((t) => t.name.lower().equals(name.toLowerCase())))
          .getSingleOrNull();
      if (existing != null) {
        ids.add(existing.id);
      } else {
        final tag = await db
            .into(db.tags)
            .insertReturning(TagsCompanion.insert(name: name));
        ids.add(tag.id);
      }
    }
    return ids;
  }

  /// Lernende Zuordnung: Der Absender merkt sich Typ und Tags des zuletzt
  /// bestätigten Dokuments und schlägt sie beim nächsten Mal vor.
  Future<void> _learnDefaults(
      String correspondentId, String? docType, List<String> tagIds) async {
    await (db.update(db.correspondents)
          ..where((c) => c.id.equals(correspondentId)))
        .write(CorrespondentsCompanion(
      defaultDocType: Value(docType),
      defaultTagIds: Value(tagIds.join(',')),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<List<Tag>> tagsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return (db.select(db.tags)..where((t) => t.id.isIn(ids))).get();
  }

  // ----------------------------------------------------------------- intern

  Future<void> _writeFtsEntry(String documentId, String docNumber,
      DocumentDraft draft, String ocrText, Map<String, Set<String>> refs) async {
    final content = [
      docNumber,
      draft.title,
      draft.correspondentName ?? '',
      draft.docType ?? '',
      draft.tagNames.join(' '),
      refs.values.expand((v) => v).join(' '),
      ocrText,
    ].join('\n');
    await db.customStatement(
      'INSERT INTO document_fts (document_id, content) VALUES (?, ?)',
      [documentId, content],
    );
  }

  /// Baut aus Nutzereingabe eine sichere FTS5-MATCH-Query:
  /// jedes Wort als Präfix-Suche, UND-verknüpft. `null` bei leerer Eingabe.
  static String? _ftsQuery(String input) {
    final terms = input
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('"', ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*')
        .toList();
    if (terms.isEmpty) return null;
    return terms.join(' AND ');
  }
}
