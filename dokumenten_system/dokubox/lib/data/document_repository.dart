import 'package:drift/drift.dart';

import 'database.dart';
import 'finance.dart';

/// Filter für die Dokumentenliste/-suche.
class DocumentFilter {
  final String query;
  final String? docType;
  final int? year;
  final String? tagId;
  final String? correspondentId;
  final String? storageLocation;

  /// Ein `PaymentStatus` oder ein `ClaimStatus` (offene Einreichungen).
  final String? financeStatus;

  const DocumentFilter({
    this.query = '',
    this.docType,
    this.year,
    this.tagId,
    this.correspondentId,
    this.storageLocation,
    this.financeStatus,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      docType == null &&
      year == null &&
      tagId == null &&
      correspondentId == null &&
      storageLocation == null &&
      financeStatus == null;
}

/// Eine Einreichung im Bearbeiten-Flow. [id] ist bei neuen `null`.
class ClaimDraft {
  String? id;
  String target;
  String status;
  DateTime? submittedAt;
  int? reimbursedCents;
  DateTime? settledAt;
  DateTime? followUpAt;

  ClaimDraft({
    this.id,
    required this.target,
    this.status = ClaimStatus.toSubmit,
    this.submittedAt,
    this.reimbursedCents,
    this.settledAt,
    this.followUpAt,
  });

  factory ClaimDraft.fromClaim(Claim c) => ClaimDraft(
        id: c.id,
        target: c.target,
        status: c.status,
        submittedAt: c.submittedAt,
        reimbursedCents: c.reimbursedCents,
        settledAt: c.settledAt,
        followUpAt: c.followUpAt,
      );
}

/// Dokument mit offener Einreichung (für „Offene Posten").
class OpenClaim {
  final Claim claim;
  final Document document;

  const OpenClaim(this.claim, this.document);
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
  int? amountCents;
  DateTime? dueDate;
  String? paymentStatus;
  DateTime? paidAt;
  DateTime? paymentReminderAt;
  List<ClaimDraft> claims;

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
    this.amountCents,
    this.dueDate,
    this.paymentStatus,
    this.paidAt,
    this.paymentReminderAt,
    List<ClaimDraft>? claims,
  })  : tagNames = tagNames ?? [],
        claims = claims ?? [];
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
        amountCents: Value(draft.amountCents),
        dueDate: Value(draft.dueDate),
        paymentStatus: Value(draft.paymentStatus),
        paidAt: Value(draft.paidAt),
        paymentReminderAt: Value(draft.paymentReminderAt),
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
      await _writeClaims(doc.id, draft.claims);
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
          amountCents: Value(draft.amountCents),
          dueDate: Value(draft.dueDate),
          paymentStatus: Value(draft.paymentStatus),
          paidAt: Value(draft.paidAt),
          paymentReminderAt: Value(draft.paymentReminderAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _writeClaims(id, draft.claims);
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
    final finance = filter.financeStatus;
    if (finance != null) {
      if (ClaimStatus.all.contains(finance)) {
        where.write(' AND EXISTS (SELECT 1 FROM claims c WHERE '
            'c.document_id = d.id AND c.deleted_at IS NULL AND c.status = ?)');
      } else {
        where.write(' AND d.payment_status = ?');
      }
      args.add(Variable.withString(finance));
    }

    return db
        .customSelect(
          'SELECT d.* FROM $from WHERE $where ORDER BY d.doc_number DESC',
          variables: args,
          readsFrom: {db.documents, db.documentTags, db.claims},
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

  /// Anstehende Zahlungserinnerungen offener Rechnungen.
  Future<List<Document>> upcomingPaymentReminders() {
    return (db.select(db.documents)
          ..where((d) =>
              d.deletedAt.isNull() &
              d.paymentStatus.equals(PaymentStatus.open) &
              d.paymentReminderAt.isNotNull() &
              d.paymentReminderAt.isBiggerThanValue(DateTime.now())))
        .get();
  }

  // ------------------------------------------------- Rechnungen/Erstattung

  /// Offene Rechnungen, früheste Fälligkeit zuerst (ohne Datum ans Ende).
  Stream<List<Document>> watchOpenPayments() {
    return (db.select(db.documents)
          ..where((d) =>
              d.deletedAt.isNull() &
              d.paymentStatus.equals(PaymentStatus.open))
          ..orderBy([
            (d) => OrderingTerm(
                expression: d.dueDate.isNull(), mode: OrderingMode.asc),
            (d) => OrderingTerm.asc(d.dueDate),
            (d) => OrderingTerm.asc(d.docNumber),
          ]))
        .watch();
  }

  /// Einreichungen mit Status einzureichen/eingereicht, samt Dokument.
  Stream<List<OpenClaim>> watchOpenClaims() {
    final query = db.select(db.claims).join([
      innerJoin(db.documents, db.documents.id.equalsExp(db.claims.documentId)),
    ])
      ..where(db.claims.deletedAt.isNull() &
          db.documents.deletedAt.isNull() &
          db.claims.status
              .isIn([ClaimStatus.toSubmit, ClaimStatus.submitted]))
      ..orderBy([
        OrderingTerm.asc(db.claims.status),
        OrderingTerm.asc(db.documents.docNumber),
      ]);
    return query.watch().map((rows) => [
          for (final row in rows)
            OpenClaim(row.readTable(db.claims), row.readTable(db.documents)),
        ]);
  }

  /// Anzahl offener Posten (für das Abzeichen auf der Startseite).
  Stream<int> watchOpenFinanceCount() {
    return db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM documents WHERE deleted_at IS NULL '
          '  AND payment_status = ?) + '
          '(SELECT COUNT(*) FROM claims c JOIN documents d ON d.id = c.document_id '
          '  WHERE c.deleted_at IS NULL AND d.deleted_at IS NULL '
          '  AND c.status = ?) AS n',
          variables: [
            Variable.withString(PaymentStatus.open),
            Variable.withString(ClaimStatus.toSubmit),
          ],
          readsFrom: {db.documents, db.claims},
        )
        .watchSingle()
        .map((row) => row.read<int>('n'));
  }

  Future<List<Claim>> claimsForDocument(String documentId,
      {bool includeDeleted = false}) {
    final query = db.select(db.claims)
      ..where((c) => c.documentId.equals(documentId))
      ..orderBy([(c) => OrderingTerm.asc(c.target)]);
    if (!includeDeleted) query.where((c) => c.deletedAt.isNull());
    return query.get();
  }

  /// Anstehende Nachfass-Erinnerungen eingereichter Erstattungen.
  Future<List<Claim>> upcomingClaimFollowUps() {
    return (db.select(db.claims)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.status.equals(ClaimStatus.submitted) &
              c.followUpAt.isNotNull() &
              c.followUpAt.isBiggerThanValue(DateTime.now())))
        .get();
  }

  /// Rechnung als bezahlt markieren; die Zahlungserinnerung entfällt.
  Future<void> markPaid(String documentId, {DateTime? at}) async {
    await (db.update(db.documents)..where((d) => d.id.equals(documentId)))
        .write(DocumentsCompanion(
      paymentStatus: const Value(PaymentStatus.paid),
      paidAt: Value(at ?? DateTime.now()),
      paymentReminderAt: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Status einer Einreichung setzen. Beim Einreichen wird das Datum
  /// gesetzt und (bei [followUpWeeks]) eine Nachfass-Erinnerung geplant;
  /// erledigte Einreichungen verlieren ihre Erinnerung.
  Future<void> setClaimStatus(
    String claimId,
    String status, {
    DateTime? at,
    int? reimbursedCents,
    int? followUpWeeks,
  }) async {
    final when = at ?? DateTime.now();
    final companion = switch (status) {
      ClaimStatus.submitted => ClaimsCompanion(
          submittedAt: Value(when),
          followUpAt: Value(followUpWeeks == null
              ? null
              : claimFollowUpFor(when, followUpWeeks)),
        ),
      ClaimStatus.reimbursed ||
      ClaimStatus.partly ||
      ClaimStatus.rejected =>
        ClaimsCompanion(
          settledAt: Value(when),
          followUpAt: const Value(null),
          reimbursedCents: reimbursedCents == null
              ? const Value.absent()
              : Value(reimbursedCents),
        ),
      _ => const ClaimsCompanion(followUpAt: Value(null)),
    };
    await (db.update(db.claims)..where((c) => c.id.equals(claimId))).write(
      companion.copyWith(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
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

  /// Alle vorhandenen Tag-Namen (für KI-Vorschläge, damit sie bevorzugt
  /// bestehende Tags wiederverwendet statt Dubletten zu erzeugen).
  Future<List<String>> allTagNames() async {
    final tags = await (db.select(db.tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return tags.map((t) => t.name).toList();
  }

  // ----------------------------------------------------------------- intern

  /// Einreichungen speichern: vorhandene aktualisieren, neue anlegen,
  /// entfernte per Soft-Delete ausblenden.
  Future<void> _writeClaims(String documentId, List<ClaimDraft> drafts) async {
    final existing = await claimsForDocument(documentId);
    final keep = drafts.map((c) => c.id).whereType<String>().toSet();
    for (final old in existing) {
      if (!keep.contains(old.id)) {
        await (db.update(db.claims)..where((c) => c.id.equals(old.id))).write(
          ClaimsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
    for (final c in drafts) {
      final companion = ClaimsCompanion(
        documentId: Value(documentId),
        target: Value(c.target),
        status: Value(c.status),
        submittedAt: Value(c.submittedAt),
        reimbursedCents: Value(c.reimbursedCents),
        settledAt: Value(c.settledAt),
        followUpAt: Value(c.followUpAt),
        updatedAt: Value(DateTime.now()),
      );
      if (c.id == null) {
        final row = await db.into(db.claims).insertReturning(companion);
        c.id = row.id;
      } else {
        await (db.update(db.claims)..where((x) => x.id.equals(c.id!)))
            .write(companion);
      }
    }
  }

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
