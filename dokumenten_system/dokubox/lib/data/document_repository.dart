import 'package:drift/drift.dart';

import 'database.dart';
import '../extract/ref_matching.dart';
import '../extract/duplicates.dart';
import 'batch_numbering.dart';
import 'cases.dart';
import 'contracts.dart';
import 'personal.dart';
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

  // Schema v6
  DateTime? objectionDeadline;
  DateTime? warrantyUntil;
  String? warrantyKind;

  /// SHA-256 der PDF (nur beim Anlegen).
  String? contentHash;

  /// Tage vor der Widerspruchsfrist erinnern (aus den Einstellungen).
  int objectionLeadDays;

  /// Beim Anlegen mit diesen Dokumenten zu einem Vorgang verknüpfen.
  List<String> linkDocumentIds;

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
    this.objectionDeadline,
    this.warrantyUntil,
    this.warrantyKind,
    this.contentHash,
    this.objectionLeadDays = 7,
    List<String>? linkDocumentIds,
  })  : linkDocumentIds = linkDocumentIds ?? [],
        tagNames = tagNames ?? [],
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

class ClaimStats {
  final String target;
  int count = 0, rejected = 0, open = 0;
  int amountCents = 0, reimbursedCents = 0, openCents = 0;
  ClaimStats(this.target);

  /// Erstattungsquote der abgeschlossenen Einreichungen (0…1).
  double get quota =>
      amountCents - openCents <= 0 ? 0 : reimbursedCents / (amountCents - openCents);
}

String? _nn(String s) => s.trim().isEmpty ? null : s.trim();

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
        objectionDeadline: Value(draft.objectionDeadline),
        warrantyUntil: Value(draft.warrantyUntil),
        warrantyKind: Value(draft.warrantyKind),
        contentHash: Value(draft.contentHash),
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
      await _syncAutoTasks(doc.id, draft);
      for (final other in draft.linkDocumentIds) {
        await linkDocuments(doc.id, other, role: guessCaseRole(draft.docType));
      }
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
          objectionDeadline: Value(draft.objectionDeadline),
          warrantyUntil: Value(draft.warrantyUntil),
          warrantyKind: Value(draft.warrantyKind),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _writeClaims(id, draft.claims);
      await _syncAutoTasks(id, draft);
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
  Future<void> markDestroyed(String id, {DateTime? at}) async {
    final doc = await getDocument(id);
    if (doc == null || doc.storageLocation == 'vernichtet') return;
    await (db.update(db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        storageLocation: const Value('vernichtet'),
        destroyedAt: Value(at ?? DateTime.now()),
        destroyedFrom: Value(doc.storageLocation),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Map<String, Set<String>>> refsForDocument(String documentId) async {
    final rows = await (db.select(db.extractedRefs)
          ..where((r) => r.documentId.equals(documentId)))
        .get();
    final refs = <String, Set<String>>{};
    for (final r in rows) {
      refs.putIfAbsent(r.kind, () => {}).add(r.value);
    }
    return refs;
  }

  Future<void> setCorrespondentBank(String id, {String? iban, String? bic}) =>
      (db.update(db.correspondents)..where((c) => c.id.equals(id))).write(
        CorrespondentsCompanion(
          iban: iban == null ? const Value.absent() : Value(iban),
          bic: bic == null ? const Value.absent() : Value(bic),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ------------------------------------------------- Anhänge

  Future<Attachment> addAttachment({
    required String documentId,
    required String kind,
    required String relPath,
    String mime = '',
    String caption = '',
    int sizeBytes = 0,
    String? sha256,
  }) =>
      db.into(db.attachments).insertReturning(AttachmentsCompanion.insert(
            documentId: documentId,
            kind: kind,
            relPath: relPath,
            mime: Value(mime),
            caption: Value(caption),
            sizeBytes: Value(sizeBytes),
            sha256: Value(sha256),
          ));

  Stream<List<Attachment>> watchAttachments(String documentId) =>
      (db.select(db.attachments)
            ..where((a) => a.documentId.equals(documentId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<void> deleteAttachment(String id) =>
      (db.update(db.attachments)..where((a) => a.id.equals(id)))
          .write(AttachmentsCompanion(deletedAt: Value(DateTime.now())));

  // ------------------------------------------------- Meine Daten

  Stream<List<String>> watchPersons() => (db.select(db.personalData)
        ..where((p) => p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
      .watch()
      .map((rows) => {for (final r in rows) r.person}.toList());

  /// Werte einer Person (Schlüssel → Wert).
  Future<Map<String, String>> personalValues(String person) async {
    final rows = await (db.select(db.personalData)
          ..where((p) => p.person.equals(person) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> setPersonalValue(String person, String key, String value) async {
    final existing = await (db.select(db.personalData)
          ..where((p) =>
              p.person.equals(person) & p.key.equals(key) & p.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.personalData)..where((p) => p.id.equals(existing.id)))
          .write(PersonalDataCompanion(
              value: Value(value.trim()), updatedAt: Value(DateTime.now())));
      return;
    }
    final order = kPersonalFields.keys.toList().indexOf(key);
    await db.into(db.personalData).insert(PersonalDataCompanion.insert(
          person: person,
          key: key,
          label: kPersonalFields[key] ?? key,
          value: Value(value.trim()),
          sortOrder: Value(order < 0 ? 999 : order),
        ));
  }

  Future<void> addPerson(String person) =>
      setPersonalValue(person, 'vorname', '');

  Future<void> renamePerson(String from, String to) =>
      (db.update(db.personalData)..where((p) => p.person.equals(from))).write(
          PersonalDataCompanion(
              person: Value(to.trim()), updatedAt: Value(DateTime.now())));

  Future<void> deletePerson(String person) =>
      (db.update(db.personalData)..where((p) => p.person.equals(person)))
          .write(PersonalDataCompanion(deletedAt: Value(DateTime.now())));

  /// Eigene IBANs (aus Meine Daten) – nicht als Empfänger-IBAN vorschlagen.
  Future<Set<String>> ownIbans() async {
    final rows = await (db.select(db.personalData)
          ..where((p) => p.key.equals('iban') & p.deletedAt.isNull()))
        .get();
    return {for (final r in rows) r.value.replaceAll(' ', '').toUpperCase()};
  }

  // ------------------------------------------------- Verträge

  Stream<List<({Contract c, String firm, String? categoryId})>>
      watchContracts() {
    final q = db.select(db.contracts).join([
      leftOuterJoin(db.correspondents,
          db.correspondents.id.equalsExp(db.contracts.correspondentId)),
    ])
      ..where(db.contracts.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.contracts.title)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            (
              c: r.readTable(db.contracts),
              firm: r.readTableOrNull(db.correspondents)?.name ?? '',
              categoryId: r.readTableOrNull(db.correspondents)?.categoryId,
            ),
        ]);
  }

  Future<Contract?> contractForDocument(String documentId) =>
      (db.select(db.contracts)
            ..where((c) => c.documentId.equals(documentId) & c.deletedAt.isNull()))
          .getSingleOrNull();

  /// Vertrag speichern; plant die Kündigungs-Erinnerung [leadDays] vor dem
  /// letzten Kündigungstag.
  Future<Contract> saveContract(ContractsCompanion data,
      {String? id, int leadDays = 14, DateTime? now}) async {
    now ??= DateTime.now();
    late Contract c;
    if (id == null) {
      c = await db.into(db.contracts).insertReturning(data);
    } else {
      await (db.update(db.contracts)..where((x) => x.id.equals(id)))
          .write(data.copyWith(updatedAt: Value(now)));
      c = (await (db.select(db.contracts)..where((x) => x.id.equals(id)))
          .getSingle());
    }
    final docId = c.documentId;
    if (docId != null) {
      final end = nextTermEnd(
          minTermUntil: c.minTermUntil, renewMonths: c.autoRenewMonths, now: now);
      final last = c.cancelledAt != null
          ? null
          : lastCancelDay(
              termEnd: end,
              noticeValue: c.noticeValue,
              noticeUnit: c.noticeUnit,
              noticeToEndOf: c.noticeToEndOf,
              now: now);
      // Erinnerung [leadDays] vorher; ist das schon vorbei, aber die Frist
      // noch nicht, gleich erinnern. Frist verpasst → keine Erinnerung.
      DateTime? due;
      if (last != null && !last.isBefore(DateTime(now.year, now.month, now.day))) {
        due = DateTime(last.year, last.month, last.day - leadDays, 9);
        if (due.isBefore(now)) due = now.add(const Duration(hours: 1));
      }
      String date(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      await ensureAutoTask(
        documentId: docId,
        origin: 'kuendigung:${c.id}',
        action: 'kuendigen',
        dueAt: due,
        note: last == null
            ? ''
            : 'Kündigung muss bis ${date(last)} eingehen – Tarif prüfen?',
      );
    }
    return c;
  }

  Future<void> deleteContract(String id) =>
      (db.update(db.contracts)..where((c) => c.id.equals(id)))
          .write(ContractsCompanion(deletedAt: Value(DateTime.now())));

  // ------------------------------------------------- Erstattungs-Statistik

  /// Pro Stelle und Jahr (Einreichdatum, sonst Dokumentdatum): Anzahl,
  /// eingereichte Summe, erstattet, abgelehnt, offen.
  Future<List<ClaimStats>> claimStats(int year) async {
    final q = db.select(db.claims).join([
      innerJoin(db.documents, db.documents.id.equalsExp(db.claims.documentId)),
    ])
      ..where(db.claims.deletedAt.isNull() & db.documents.deletedAt.isNull());
    final stats = <String, ClaimStats>{};
    for (final r in await q.get()) {
      final c = r.readTable(db.claims);
      final d = r.readTable(db.documents);
      final when = c.submittedAt ?? d.docDate ?? d.scannedAt;
      if (when.year != year) continue;
      final s = stats.putIfAbsent(c.target, () => ClaimStats(c.target));
      s.count++;
      s.amountCents += d.amountCents ?? 0;
      if (c.status == ClaimStatus.reimbursed || c.status == ClaimStatus.partly) {
        s.reimbursedCents += c.reimbursedCents ?? d.amountCents ?? 0;
      } else if (c.status == ClaimStatus.rejected) {
        s.rejected++;
      } else {
        s.open++;
        s.openCents += d.amountCents ?? 0;
      }
    }
    final list = stats.values.toList()
      ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return list;
  }

  // ------------------------------------------------- Ausdrucke

  /// Lagerorte mit Originalen (ohne „vernichtet“), z. B. „Box 2026“.
  Future<List<String>> storageLocations() async {
    final rows = await db.customSelect(
      "SELECT DISTINCT storage_location AS l FROM documents "
      "WHERE deleted_at IS NULL AND storage_location != 'vernichtet' "
      'ORDER BY storage_location',
      readsFrom: {db.documents},
    ).get();
    return [for (final r in rows) r.read<String>('l')];
  }

  Future<String> _senderOf(Document d) async => d.correspondentId == null
      ? ''
      : (await getCorrespondent(d.correspondentId!))?.name ?? '';

  /// Dokumente eines Lagerorts nach Nummer (für die Box-Inhaltsliste).
  Future<List<({Document doc, String sender})>> documentsAt(
      String location) async {
    final docs = await (db.select(db.documents)
          ..where((d) => d.deletedAt.isNull() & d.storageLocation.equals(location))
          ..orderBy([(d) => OrderingTerm.asc(d.docNumber)]))
        .get();
    return [for (final d in docs) (doc: d, sender: await _senderOf(d))];
  }

  /// Vernichtete Originale in einem Zeitraum (Vernichtungs-Protokoll).
  /// Alte Einträge ohne Datum kommen mit, wenn [includeUndated].
  Future<List<({Document doc, String sender})>> destroyedBetween(
      DateTime from, DateTime to,
      {bool includeUndated = false}) async {
    final docs = await (db.select(db.documents)
          ..where((d) =>
              d.deletedAt.isNull() &
              d.storageLocation.equals('vernichtet') &
              (d.destroyedAt.isBetweenValues(from, to) |
                  (includeUndated
                      ? d.destroyedAt.isNull()
                      : const Constant(false))))
          ..orderBy([(d) => OrderingTerm.asc(d.docNumber)]))
        .get();
    return [for (final d in docs) (doc: d, sender: await _senderOf(d))];
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
              d.storageLocation.equals('vernichtet').not() &
              // Solange Garantie läuft, nicht ausmisten.
              (d.warrantyUntil.isNull() | d.warrantyUntil.isSmallerOrEqualValue(now)))
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

  // ------------------------------------------------- Dubletten

  /// Mögliche Dubletten eines neuen Dokuments: gleiche Datei (Hash), gleiche
  /// Rechnungsnummer bei gleicher Firma, oder fast gleicher Text bei gleicher
  /// Firma ±60 Tage.
  Future<List<({Document doc, String reason})>> findDuplicates({
    String? contentHash,
    Map<String, Set<String>> refs = const {},
    String? correspondentName,
    String ocrText = '',
    DateTime? docDate,
  }) async {
    final found = <String, ({Document doc, String reason})>{};
    final alive = db.documents.deletedAt.isNull();
    if (contentHash != null) {
      for (final d in await (db.select(db.documents)
            ..where((d) => alive & d.contentHash.equals(contentHash)))
          .get()) {
        found[d.id] = (doc: d, reason: 'gleiche Datei');
      }
    }
    final firm = correspondentName == null || correspondentName.trim().isEmpty
        ? null
        : await (db.select(db.correspondents)
              ..where((c) =>
                  c.name.lower().equals(correspondentName.trim().toLowerCase())))
            .getSingleOrNull();
    if (firm != null) {
      final rgnr = refs['RGNR'] ?? const {};
      if (rgnr.isNotEmpty) {
        for (final c in await refCandidates({'RGNR': rgnr})) {
          if (c.correspondentId != firm.id || found.containsKey(c.documentId)) {
            continue;
          }
          final d = await getDocument(c.documentId);
          if (d != null && d.docType != 'Mahnung') {
            found[d.id] = (doc: d, reason: 'gleiche Rechnungsnummer');
          }
        }
      }
      if (ocrText.trim().isNotEmpty) {
        final from = docDate?.subtract(const Duration(days: 60));
        final to = docDate?.add(const Duration(days: 60));
        final sameFirm = await (db.select(db.documents)
              ..where((d) {
                var w = alive & d.correspondentId.equals(firm.id);
                if (from != null && to != null) {
                  w = w &
                      (d.docDate.isNull() | d.docDate.isBetweenValues(from, to));
                }
                return w;
              })
              ..limit(200))
            .get();
        for (final d in sameFirm) {
          if (found.containsKey(d.id)) continue;
          if (textSimilarity(ocrText, d.ocrText) >= kDuplicateSimilarity) {
            found[d.id] = (doc: d, reason: 'fast gleicher Text');
          }
        }
      }
    }
    return found.values.toList();
  }

  // ------------------------------------------------- Vorgänge

  Future<Case> createCase(String title,
          {String? correspondentId, String note = ''}) =>
      db.into(db.cases).insertReturning(CasesCompanion.insert(
            title: title.trim().isEmpty ? 'Vorgang' : title.trim(),
            correspondentId: Value(correspondentId),
            note: Value(note),
          ));

  Future<void> addToCase(String caseId, String documentId,
      {String role = 'sonstiges'}) async {
    final existing = await (db.select(db.caseDocuments)
          ..where((c) =>
              c.caseId.equals(caseId) &
              c.documentId.equals(documentId) &
              c.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) return;
    await db.into(db.caseDocuments).insert(CaseDocumentsCompanion.insert(
        caseId: caseId, documentId: documentId, role: Value(role)));
    await _touchCase(caseId);
  }

  Future<void> removeFromCase(String caseId, String documentId) async {
    await (db.update(db.caseDocuments)
          ..where((c) =>
              c.caseId.equals(caseId) & c.documentId.equals(documentId)))
        .write(CaseDocumentsCompanion(deletedAt: Value(DateTime.now())));
    await _touchCase(caseId);
  }

  Future<void> _touchCase(String caseId) =>
      (db.update(db.cases)..where((c) => c.id.equals(caseId)))
          .write(CasesCompanion(updatedAt: Value(DateTime.now())));

  Future<void> setCaseStatus(String caseId, String status) =>
      (db.update(db.cases)..where((c) => c.id.equals(caseId))).write(
        CasesCompanion(
          status: Value(status),
          closedAt: Value(status == 'erledigt' ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> renameCase(String caseId, String title) =>
      (db.update(db.cases)..where((c) => c.id.equals(caseId))).write(
          CasesCompanion(
              title: Value(title.trim()), updatedAt: Value(DateTime.now())));

  Future<void> deleteCase(String caseId) =>
      (db.update(db.cases)..where((c) => c.id.equals(caseId)))
          .write(CasesCompanion(deletedAt: Value(DateTime.now())));

  /// Neues Dokument mit einem vorhandenen verknüpfen: in dessen Vorgang
  /// aufnehmen, oder einen neuen Vorgang für beide anlegen.
  Future<Case> linkDocuments(String newId, String otherId,
      {String role = 'sonstiges'}) async {
    final existing = await casesForDocument(otherId);
    Case target;
    if (existing.isNotEmpty) {
      target = existing.first;
    } else {
      final other = await getDocument(otherId);
      final firm = other?.correspondentId == null
          ? null
          : await getCorrespondent(other!.correspondentId!);
      target = await createCase(
        [firm?.name, other?.title]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' – '),
        correspondentId: other?.correspondentId,
      );
      await addToCase(target.id, otherId);
    }
    await addToCase(target.id, newId, role: role);
    if (target.status == 'wartet') await setCaseStatus(target.id, 'offen');
    return target;
  }

  Future<List<Case>> casesForDocument(String documentId) async {
    final q = db.select(db.cases).join([
      innerJoin(db.caseDocuments,
          db.caseDocuments.caseId.equalsExp(db.cases.id)),
    ])
      ..where(db.caseDocuments.documentId.equals(documentId) &
          db.caseDocuments.deletedAt.isNull() &
          db.cases.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.cases.updatedAt)]);
    return [for (final r in await q.get()) r.readTable(db.cases)];
  }

  Stream<List<Case>> watchCasesForDocument(String documentId) {
    final q = db.select(db.cases).join([
      innerJoin(db.caseDocuments,
          db.caseDocuments.caseId.equalsExp(db.cases.id)),
    ])
      ..where(db.caseDocuments.documentId.equals(documentId) &
          db.caseDocuments.deletedAt.isNull() &
          db.cases.deletedAt.isNull());
    return q.watch().map((rows) => [for (final r in rows) r.readTable(db.cases)]);
  }

  /// Alle Vorgänge mit Anzahl Dokumente; offene zuerst.
  Stream<List<({Case c, int docs})>> watchCases() => db
      .customSelect(
        'SELECT c.id, COUNT(cd.id) AS n FROM cases c '
        'LEFT JOIN case_documents cd ON cd.case_id = c.id AND cd.deleted_at IS NULL '
        'LEFT JOIN documents d ON d.id = cd.document_id AND d.deleted_at IS NULL '
        'WHERE c.deleted_at IS NULL GROUP BY c.id',
        readsFrom: {db.cases, db.caseDocuments, db.documents},
      )
      .watch()
      .asyncMap((rows) async {
        final counts = {for (final r in rows) r.read<String>('id'): r.read<int>('n')};
        final cases = await (db.select(db.cases)
              ..where((c) => c.id.isIn(counts.keys)))
            .get();
        int rank(String s) => s == 'erledigt' ? 2 : (s == 'wartet' ? 1 : 0);
        cases.sort((a, b) {
          final r = rank(a.status).compareTo(rank(b.status));
          return r != 0 ? r : b.updatedAt.compareTo(a.updatedAt);
        });
        return [for (final c in cases) (c: c, docs: counts[c.id] ?? 0)];
      });

  Stream<int> watchOpenCaseCount() => (db.select(db.cases)
        ..where((c) => c.deletedAt.isNull() & c.status.equals('erledigt').not()))
      .watch()
      .map((r) => r.length);

  Stream<Case?> watchCase(String id) =>
      (db.select(db.cases)..where((c) => c.id.equals(id))).watchSingleOrNull();

  /// Dokumente eines Vorgangs, zeitlich (Dokumentdatum, sonst Scan).
  Stream<List<({Document doc, String role})>> watchCaseDocuments(
      String caseId) {
    final q = db.select(db.caseDocuments).join([
      innerJoin(db.documents,
          db.documents.id.equalsExp(db.caseDocuments.documentId)),
    ])
      ..where(db.caseDocuments.caseId.equals(caseId) &
          db.caseDocuments.deletedAt.isNull() &
          db.documents.deletedAt.isNull());
    return q.watch().map((rows) {
      final list = [
        for (final r in rows)
          (doc: r.readTable(db.documents), role: r.readTable(db.caseDocuments).role),
      ];
      list.sort((a, b) => (a.doc.docDate ?? a.doc.scannedAt)
          .compareTo(b.doc.docDate ?? b.doc.scannedAt));
      return list;
    });
  }

  // ------------------------------------------------- Verknüpfen

  /// Dokumente mit mindestens einer gleichen Referenz (normalisiert), als
  /// Kandidaten für [matchRefs]. [excludeId]: das Dokument selbst.
  Future<List<RefCandidate>> refCandidates(Map<String, Set<String>> refs,
      {String? excludeId}) async {
    final values = {
      for (final v in refs.values.expand((v) => v)) normalizeRef(v),
    }.where((v) => v.length >= 4).toList();
    if (values.isEmpty) return const [];
    final placeholders = List.filled(values.length, '?').join(',');
    final rows = await db.customSelect(
      'SELECT r.document_id, r.kind, r.value, d.correspondent_id '
      'FROM extracted_refs r JOIN documents d ON d.id = r.document_id '
      'WHERE d.deleted_at IS NULL '
      "AND upper(replace(replace(replace(replace(r.value, ' ', ''), '-', ''), '/', ''), '.', '')) "
      'IN ($placeholders)',
      variables: [for (final v in values) Variable.withString(v)],
      readsFrom: {db.extractedRefs, db.documents},
    ).get();
    final byDoc = <String, RefCandidate>{};
    for (final r in rows) {
      final id = r.read<String>('document_id');
      if (id == excludeId) continue;
      final c = byDoc.putIfAbsent(
          id,
          () => RefCandidate(
              id, r.readNullable<String>('correspondent_id'), {}));
      c.refs.putIfAbsent(r.read<String>('kind'), () => {})
          .add(r.read<String>('value'));
    }
    return byDoc.values.toList();
  }

  /// Erinnerungen an Widerspruchsfrist und Garantieende passend zum
  /// Dokument anlegen/verschieben/entfernen.
  Future<void> _syncAutoTasks(String documentId, DocumentDraft draft) async {
    String date(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final o = draft.objectionDeadline;
    await ensureAutoTask(
      documentId: documentId,
      origin: 'widerspruch',
      action: 'pruefen',
      dueAt: o == null
          ? null
          : DateTime(o.year, o.month, o.day - draft.objectionLeadDays, 9),
      note: o == null
          ? ''
          : 'Widerspruchsfrist endet am ${date(o)} – Widerspruch nötig?',
    );
    final w = draft.warrantyUntil;
    await ensureAutoTask(
      documentId: documentId,
      origin: 'garantie',
      action: 'pruefen',
      dueAt: w == null ? null : DateTime(w.year, w.month, w.day - 28, 9),
      note: w == null
          ? ''
          : '${draft.warrantyKind == 'garantie' ? 'Garantie' : 'Gewährleistung'} '
              'endet am ${date(w)} – Mängel jetzt melden',
    );
  }

  /// Automatisch erzeugte Aufgabe (Widerspruchsfrist, Garantie,
  /// Kündigung …) anlegen, verschieben oder – bei [dueAt] == null – löschen.
  /// Zugeordnet über [origin], damit nichts doppelt entsteht.
  Future<DocTask?> ensureAutoTask({
    required String documentId,
    required String origin,
    required String action,
    required DateTime? dueAt,
    String note = '',
  }) async {
    final existing = await (db.select(db.docTasks)
          ..where((t) =>
              t.documentId.equals(documentId) &
              t.origin.equals(origin) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
    if (dueAt == null) {
      if (existing != null) await deleteTask(existing.id);
      return null;
    }
    if (existing != null) {
      if (existing.doneAt == null) {
        await updateTask(existing.id, dueAt: dueAt, note: note);
      }
      return getTask(existing.id);
    }
    final task = await createTask(
        documentId: documentId, action: action, note: note, dueAt: dueAt);
    await (db.update(db.docTasks)..where((t) => t.id.equals(task.id)))
        .write(DocTasksCompanion(origin: Value(origin)));
    return getTask(task.id);
  }

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
    ({String email, String fax, String postalAddress, String subject, String body})?
        contact,
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
        email: contact == null ? const Value.absent() : Value(_nn(contact.email)),
        fax: contact == null ? const Value.absent() : Value(_nn(contact.fax)),
        postalAddress: contact == null
            ? const Value.absent()
            : Value(_nn(contact.postalAddress)),
        mailSubjectTemplate:
            contact == null ? const Value.absent() : Value(_nn(contact.subject)),
        mailBodyTemplate:
            contact == null ? const Value.absent() : Value(_nn(contact.body)),
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

  /// Suchindex eines Dokuments neu aufbauen (z. B. nach dem Abgleich).
  Future<void> rebuildFts(String documentId) async {
    final doc = await getDocument(documentId);
    await db.customStatement(
        'DELETE FROM document_fts WHERE document_id = ?', [documentId]);
    if (doc == null || doc.deletedAt != null) return;
    final firm = doc.correspondentId == null
        ? null
        : await getCorrespondent(doc.correspondentId!);
    await _writeFtsEntry(
      documentId,
      doc.docNumber,
      DocumentDraft(
        title: doc.title,
        correspondentName: firm?.name,
        docType: doc.docType,
        tagNames: await tagNamesForDocument(documentId),
        storageLocation: doc.storageLocation,
      ),
      doc.ocrText,
      await refsForDocument(documentId),
    );
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
