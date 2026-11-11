import 'package:drift/drift.dart';

import 'database.dart';
import 'batch_numbering.dart';
import 'finance.dart';
import 'tasks.dart';

/// Filter für die Dokumentenliste/-suche.
class DocumentFilter {
  final String query;
  final String? docType;
  final int? year;
  final String? tagId;
  final String? correspondentId;

  /// Kategorie der Firma (Absender) des Dokuments.
  final String? categoryId;
  final String? storageLocation;

  /// Ein `PaymentStatus` oder ein `ClaimStatus` (offene Einreichungen).
  final String? financeStatus;

  const DocumentFilter({
    this.query = '',
    this.docType,
    this.year,
    this.tagId,
    this.correspondentId,
    this.categoryId,
    this.storageLocation,
    this.financeStatus,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      docType == null &&
      year == null &&
      tagId == null &&
      correspondentId == null &&
      categoryId == null &&
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

  /// Kategorie, die der Firma beim Speichern zugeordnet wird. `null` = die
  /// Kategorie der Firma bleibt, wie sie ist.
  String? categoryId;
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
    this.categoryId,
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

/// Ergebnis von [DocumentRepository.assignFinalNumbers].
class FinalNumbering {
  final Document doc;
  final String oldNumber;
  final String sender;

  /// Alte → neue relative Dateipfade (umbenennen!).
  final Map<String, String> renames;
  const FinalNumbering(
      {required this.doc,
      required this.oldNumber,
      required this.sender,
      required this.renames});
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

  // ------------------------------------------------- Ersterfassung

  /// Vorläufige Nummern (V-0001 …) während der Ersterfassung; Zähler unter
  /// Jahr 0.
  static const provisionalPrefix = 'V-';
  static bool isProvisional(String docNumber) =>
      docNumber.startsWith(provisionalPrefix);

  Future<String> nextProvisionalNumber() => db.transaction(() async {
        final row = await (db.select(db.counters)
              ..where((c) => c.year.equals(0)))
            .getSingleOrNull();
        final next = (row?.lastNumber ?? 0) + 1;
        await db.into(db.counters).insertOnConflictUpdate(
              CountersCompanion(year: const Value(0), lastNumber: Value(next)),
            );
        return '$provisionalPrefix${next.toString().padLeft(4, '0')}';
      });

  Stream<int> watchProvisionalCount() => (db.select(db.documents)
        ..where((d) =>
            d.deletedAt.isNull() & d.docNumber.like('$provisionalPrefix%')))
      .watch()
      .map((rows) => rows.length);

  /// Vergibt allen vorläufig nummerierten Dokumenten endgültige Nummern
  /// nach Dokumentdatum (ältestes zuerst, ohne Datum ans Ende, sonst in
  /// Scan-Reihenfolge). Passt PDF-Pfade und Suchindex an; die Dateien
  /// benennt der Aufrufer um (siehe Rückgabe).
  Future<List<FinalNumbering>> assignFinalNumbers({DateTime? now}) =>
      db.transaction(() async {
        final docs = await (db.select(db.documents)
              ..where((d) =>
                  d.deletedAt.isNull() &
                  d.docNumber.like('$provisionalPrefix%'))
              ..orderBy([(d) => OrderingTerm.asc(d.scannedAt)]))
            .get();
        final result = <FinalNumbering>[];
        for (final doc in sortForNumbering(docs, (d) => d.docDate)) {
          final number = await nextDocNumber(now: now);
          String? swap(String? path) =>
              path?.replaceAll(doc.docNumber, number);
          await (db.update(db.documents)..where((d) => d.id.equals(doc.id)))
              .write(DocumentsCompanion(
            docNumber: Value(number),
            pdfPath: Value(swap(doc.pdfPath)!),
            filledPdfPath: Value(swap(doc.filledPdfPath)),
            updatedAt: Value(DateTime.now()),
          ));
          await db.customStatement(
            'UPDATE document_fts SET content = replace(content, ?, ?) '
            'WHERE document_id = ?',
            [doc.docNumber, number, doc.id],
          );
          final sender = doc.correspondentId == null
              ? ''
              : (await getCorrespondent(doc.correspondentId!))?.name ?? '';
          result.add(FinalNumbering(
            doc: (await getDocument(doc.id))!,
            oldNumber: doc.docNumber,
            sender: sender,
            renames: {
              doc.pdfPath: swap(doc.pdfPath)!,
              if (doc.filledPdfPath != null)
                doc.filledPdfPath!: swap(doc.filledPdfPath)!,
            },
          ));
        }
        // Vorläufiger Zähler startet bei der nächsten Ersterfassung neu.
        await (db.delete(db.counters)..where((c) => c.year.equals(0))).go();
        return result;
      });

  /// Rollback für einen verworfenen Scan: War [docNumber] die zuletzt
  /// vergebene Nummer und wurde kein Dokument damit angelegt, wird der
  /// Zähler zurückgedreht, damit keine Lücke in der Box entsteht.
  Future<void> releaseDocNumberIfUnused(String docNumber) async {
    final parts = docNumber.split('-');
    if (parts.length != 2) return;
    final year = isProvisional(docNumber) ? 0 : int.tryParse(parts[0]);
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
          : (await _ensureCorrespondent(draft.correspondentName!.trim(),
                  categoryId: draft.categoryId))
              .id;
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
          : (await _ensureCorrespondent(draft.correspondentName!.trim(),
                  categoryId: draft.categoryId))
              .id;
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
    if (filter.categoryId != null) {
      where.write(' AND d.correspondent_id IN (SELECT c.id FROM correspondents c '
          'WHERE c.category_id = ? AND c.deleted_at IS NULL)');
      args.add(Variable.withString(filter.categoryId!));
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
          readsFrom: {
            db.documents,
            db.documentTags,
            db.claims,
            db.correspondents,
          },
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

  Future<Correspondent> _ensureCorrespondent(String name,
      {String? categoryId}) async {
    final existing = await (db.select(db.correspondents)
          ..where((c) => c.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) {
      // Gelöschte Firma taucht wieder auf → wiederbeleben.
      final revive = existing.deletedAt != null;
      final recategorize =
          categoryId != null && categoryId != existing.categoryId;
      if (revive || recategorize) {
        await (db.update(db.correspondents)
              ..where((c) => c.id.equals(existing.id)))
            .write(CorrespondentsCompanion(
          deletedAt: revive ? const Value(null) : const Value.absent(),
          categoryId:
              recategorize ? Value(categoryId) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ));
      }
      return existing;
    }
    return db.into(db.correspondents).insertReturning(
          CorrespondentsCompanion.insert(
            name: name,
            aliases: Value(name),
            categoryId: Value(categoryId),
          ),
        );
  }

  // ------------------------------------------------------------ Ausfüllen

  /// Speichert die ausgefüllte Kopie und die Eintragungen (JSON) eines
  /// Dokuments. Das Original bleibt unverändert.
  Future<void> saveFill(String documentId,
          {required String fillData, required String filledPdfPath}) =>
      (db.update(db.documents)..where((d) => d.id.equals(documentId))).write(
        DocumentsCompanion(
          fillData: Value(fillData),
          filledPdfPath: Value(filledPdfPath),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Entfernt die ausgefüllte Kopie (die Datei löscht der Aufrufer).
  Future<void> clearFill(String documentId) =>
      (db.update(db.documents)..where((d) => d.id.equals(documentId))).write(
        DocumentsCompanion(
          fillData: const Value(null),
          filledPdfPath: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Stream<Document?> watchDocument(String id) =>
      (db.select(db.documents)..where((d) => d.id.equals(id)))
          .watchSingleOrNull();

  // ------------------------------------------------- Aufgaben/Erinnerungen

  Future<DocTask> createTask({
    required String documentId,
    required String action,
    String note = '',
    required DateTime dueAt,
    String repeat = '',
  }) =>
      db.into(db.docTasks).insertReturning(DocTasksCompanion.insert(
            documentId: documentId,
            action: action,
            note: Value(note.trim()),
            dueAt: dueAt,
            repeat: Value(repeat),
          ));

  Future<void> updateTask(String id,
          {String? action, String? note, DateTime? dueAt, String? repeat}) =>
      (db.update(db.docTasks)..where((t) => t.id.equals(id))).write(
        DocTasksCompanion(
          action: action == null ? const Value.absent() : Value(action),
          note: note == null ? const Value.absent() : Value(note.trim()),
          dueAt: dueAt == null ? const Value.absent() : Value(dueAt),
          repeat: repeat == null ? const Value.absent() : Value(repeat),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<DocTask?> getTask(String id) =>
      (db.select(db.docTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Abhaken. Bei Wiederholung wird die nächste Aufgabe angelegt und
  /// zurückgegeben.
  Future<DocTask?> completeTask(String id, {DateTime? now}) =>
      db.transaction(() async {
        final task = await getTask(id);
        if (task == null || task.doneAt != null) return null;
        now ??= DateTime.now();
        await (db.update(db.docTasks)..where((t) => t.id.equals(id))).write(
          DocTasksCompanion(doneAt: Value(now), updatedAt: Value(now!)),
        );
        final next = nextDue(task.dueAt, task.repeat, now: now);
        if (next == null) return null;
        return createTask(
          documentId: task.documentId,
          action: task.action,
          note: task.note,
          dueAt: next,
          repeat: task.repeat,
        );
      });

  /// Wieder öffnen (versehentlich abgehakt).
  Future<void> reopenTask(String id) =>
      (db.update(db.docTasks)..where((t) => t.id.equals(id))).write(
        DocTasksCompanion(
          doneAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Verschieben um [by] (ab jetzt, wenn schon überfällig).
  Future<DateTime> snoozeTask(String id, Duration by, {DateTime? now}) async {
    final task = await getTask(id);
    now ??= DateTime.now();
    final base = task == null || task.dueAt.isBefore(now) ? now : task.dueAt;
    var next = base.add(by);
    // Überfälliges auf morgen 9 Uhr statt mitten in die Nacht.
    if (by.inDays >= 1 && (task == null || task.dueAt.isBefore(now))) {
      next = DateTime(next.year, next.month, next.day, 9);
    }
    await updateTask(id, dueAt: next);
    return next;
  }

  Future<void> deleteTask(String id) =>
      (db.update(db.docTasks)..where((t) => t.id.equals(id))).write(
        DocTasksCompanion(deletedAt: Value(DateTime.now())),
      );

  Stream<List<DocTask>> watchTasksForDocument(String documentId) =>
      (db.select(db.docTasks)
            ..where((t) => t.documentId.equals(documentId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.doneAt.isNotNull()),
              (t) => OrderingTerm.asc(t.dueAt),
            ]))
          .watch();

  /// Alle (auch erledigte/gelöschte) Aufgaben eines Dokuments – zum
  /// Planen/Löschen von Benachrichtigungen.
  Future<List<DocTask>> allTasksForDocument(String documentId) =>
      (db.select(db.docTasks)..where((t) => t.documentId.equals(documentId)))
          .get();

  /// Offene Aufgaben einer Aktion für ein Dokument (z. B. nach dem
  /// Ausfüllen: „Aufgabe Ausfüllen erledigt?“).
  Future<List<DocTask>> openTasksFor(String documentId, Set<String> actions) =>
      (db.select(db.docTasks)
            ..where((t) =>
                t.documentId.equals(documentId) &
                t.deletedAt.isNull() &
                t.doneAt.isNull() &
                t.action.isIn(actions))
            ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
          .get();

  /// Alle offenen Aufgaben + in den letzten [doneDays] Tagen erledigte, mit
  /// Dokument (gelöschte Dokumente fallen raus).
  Stream<List<({DocTask task, Document doc})>> watchAllTasks(
      {int doneDays = 30}) {
    final since = DateTime.now().subtract(Duration(days: doneDays));
    final query = db.select(db.docTasks).join([
      innerJoin(db.documents, db.documents.id.equalsExp(db.docTasks.documentId)),
    ])
      ..where(db.docTasks.deletedAt.isNull() &
          db.documents.deletedAt.isNull() &
          (db.docTasks.doneAt.isNull() |
              db.docTasks.doneAt.isBiggerOrEqualValue(since)))
      ..orderBy([OrderingTerm.asc(db.docTasks.dueAt)]);
    return query.watch().map((rows) => [
          for (final r in rows)
            (task: r.readTable(db.docTasks), doc: r.readTable(db.documents)),
        ]);
  }

  /// Anzahl offener Aufgaben, die heute oder früher fällig sind (für das
  /// Symbol auf dem Startbildschirm).
  Stream<int> watchDueTaskCount() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final query = db.select(db.docTasks).join([
      innerJoin(db.documents, db.documents.id.equalsExp(db.docTasks.documentId)),
    ])
      ..where(db.docTasks.deletedAt.isNull() &
          db.docTasks.doneAt.isNull() &
          db.documents.deletedAt.isNull() &
          db.docTasks.dueAt.isSmallerThanValue(endOfDay));
    return query.watch().map((rows) => rows.length);
  }

  /// Offene Aufgaben mit Termin in der Zukunft (für Benachrichtigungen).
  Future<List<DocTask>> upcomingTasks({DateTime? now}) {
    now ??= DateTime.now();
    return (db.select(db.docTasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.doneAt.isNull() &
              t.dueAt.isBiggerThanValue(now!)))
        .get();
  }

  // ------------------------------------------------ Unterschriften/Vorlagen

  Stream<List<SignatureTemplate>> watchTemplates() =>
      (db.select(db.signatureTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<SignatureTemplate>> allTemplates() =>
      (db.select(db.signatureTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<SignatureTemplate> addTemplate(
          {required String name,
          required String imagePath,
          required double aspect}) =>
      db.into(db.signatureTemplates).insertReturning(
            SignatureTemplatesCompanion.insert(
              name: name.trim().isEmpty ? 'Vorlage' : name.trim(),
              imagePath: imagePath,
              aspect: Value(aspect),
            ),
          );

  Future<void> renameTemplate(String id, String name) =>
      (db.update(db.signatureTemplates)..where((t) => t.id.equals(id))).write(
        SignatureTemplatesCompanion(
          name: Value(name.trim()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Soft-Delete: bereits ausgefüllte PDFs behalten die Unterschrift, nur
  /// zum Einfügen steht die Vorlage nicht mehr zur Wahl.
  Future<void> deleteTemplate(String id) =>
      (db.update(db.signatureTemplates)..where((t) => t.id.equals(id))).write(
        SignatureTemplatesCompanion(deletedAt: Value(DateTime.now())),
      );

  Future<SignatureTemplate?> getTemplate(String id) =>
      (db.select(db.signatureTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  // ------------------------------------------------- Kategorien & Firmen

  Stream<List<Category>> watchCategories() => (db.select(db.categories)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<List<Category>> allCategories() => (db.select(db.categories)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .get();

  /// Legt eine Kategorie an (oder belebt eine gelöschte gleichen Namens).
  Future<Category> createCategory(String name) async {
    final trimmed = name.trim();
    final existing = await (db.select(db.categories)
          ..where((c) => c.name.lower().equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) {
      if (existing.deletedAt != null) {
        await (db.update(db.categories)..where((c) => c.id.equals(existing.id)))
            .write(CategoriesCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ));
      }
      return existing;
    }
    return db
        .into(db.categories)
        .insertReturning(CategoriesCompanion.insert(name: trimmed));
  }

  Future<void> renameCategory(String id, String name) =>
      (db.update(db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name.trim()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Löscht eine Kategorie; ihre Firmen werden „ohne Kategorie“.
  Future<void> deleteCategory(String id) => db.transaction(() async {
        await (db.update(db.correspondents)
              ..where((c) => c.categoryId.equals(id)))
            .write(CorrespondentsCompanion(
          categoryId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ));
        await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(deletedAt: Value(DateTime.now())),
        );
      });

  /// Kategorie der Firma mit diesem Namen (falls bekannt und zugeordnet).
  Future<String?> categoryIdForCorrespondentName(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    final c = await (db.select(db.correspondents)
          ..where((c) =>
              c.name.lower().equals(name.trim().toLowerCase()) &
              c.deletedAt.isNull()))
        .getSingleOrNull();
    return c?.categoryId;
  }

  /// Anzahl der (nicht gelöschten) Dokumente je Firma.
  Stream<Map<String, int>> watchDocumentCountsByCorrespondent() => db
      .customSelect(
        'SELECT correspondent_id, COUNT(*) AS n FROM documents '
        'WHERE deleted_at IS NULL AND correspondent_id IS NOT NULL '
        'GROUP BY correspondent_id',
        readsFrom: {db.documents},
      )
      .watch()
      .map((rows) => {
            for (final r in rows)
              r.read<String>('correspondent_id'): r.read<int>('n'),
          });

  /// Legt eine Firma an oder ändert sie. [aliases] sind Erkennungs-
  /// Stichwörter (eins pro Zeile); der Name selbst zählt immer mit.
  Future<void> saveCorrespondent({
    String? id,
    required String name,
    String aliases = '',
    String? categoryId,
  }) async {
    final trimmed = name.trim();
    final aliasList = [
      trimmed,
      for (final a in aliases.split('\n'))
        if (a.trim().isNotEmpty && a.trim().toLowerCase() != trimmed.toLowerCase())
          a.trim(),
    ].join('\n');
    if (id == null) {
      final existing = await _ensureCorrespondent(trimmed);
      id = existing.id;
    }
    await (db.update(db.correspondents)..where((c) => c.id.equals(id!))).write(
      CorrespondentsCompanion(
        name: Value(trimmed),
        aliases: Value(aliasList),
        categoryId: Value(categoryId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Entfernt eine Firma aus der Liste. Dokumente behalten ihren Absender-
  /// Eintrag; wird die Firma wieder erkannt, lebt sie wieder auf.
  Future<void> deleteCorrespondent(String id) =>
      (db.update(db.correspondents)..where((c) => c.id.equals(id))).write(
        CorrespondentsCompanion(deletedAt: Value(DateTime.now())),
      );

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
