// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _docNumberMeta = const VerificationMeta(
    'docNumber',
  );
  @override
  late final GeneratedColumn<String> docNumber = GeneratedColumn<String>(
    'doc_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _docDateMeta = const VerificationMeta(
    'docDate',
  );
  @override
  late final GeneratedColumn<DateTime> docDate = GeneratedColumn<DateTime>(
    'doc_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _correspondentIdMeta = const VerificationMeta(
    'correspondentId',
  );
  @override
  late final GeneratedColumn<String> correspondentId = GeneratedColumn<String>(
    'correspondent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _docTypeMeta = const VerificationMeta(
    'docType',
  );
  @override
  late final GeneratedColumn<String> docType = GeneratedColumn<String>(
    'doc_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storageLocationMeta = const VerificationMeta(
    'storageLocation',
  );
  @override
  late final GeneratedColumn<String> storageLocation = GeneratedColumn<String>(
    'storage_location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pdfPathMeta = const VerificationMeta(
    'pdfPath',
  );
  @override
  late final GeneratedColumn<String> pdfPath = GeneratedColumn<String>(
    'pdf_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _retentionUntilMeta = const VerificationMeta(
    'retentionUntil',
  );
  @override
  late final GeneratedColumn<DateTime> retentionUntil =
      GeneratedColumn<DateTime>(
        'retention_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reminderAtMeta = const VerificationMeta(
    'reminderAt',
  );
  @override
  late final GeneratedColumn<DateTime> reminderAt = GeneratedColumn<DateTime>(
    'reminder_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderNoteMeta = const VerificationMeta(
    'reminderNote',
  );
  @override
  late final GeneratedColumn<String> reminderNote = GeneratedColumn<String>(
    'reminder_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentReminderAtMeta = const VerificationMeta(
    'paymentReminderAt',
  );
  @override
  late final GeneratedColumn<DateTime> paymentReminderAt =
      GeneratedColumn<DateTime>(
        'payment_reminder_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _filledPdfPathMeta = const VerificationMeta(
    'filledPdfPath',
  );
  @override
  late final GeneratedColumn<String> filledPdfPath = GeneratedColumn<String>(
    'filled_pdf_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fillDataMeta = const VerificationMeta(
    'fillData',
  );
  @override
  late final GeneratedColumn<String> fillData = GeneratedColumn<String>(
    'fill_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warrantyUntilMeta = const VerificationMeta(
    'warrantyUntil',
  );
  @override
  late final GeneratedColumn<DateTime> warrantyUntil =
      GeneratedColumn<DateTime>(
        'warranty_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _warrantyKindMeta = const VerificationMeta(
    'warrantyKind',
  );
  @override
  late final GeneratedColumn<String> warrantyKind = GeneratedColumn<String>(
    'warranty_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objectionDeadlineMeta = const VerificationMeta(
    'objectionDeadline',
  );
  @override
  late final GeneratedColumn<DateTime> objectionDeadline =
      GeneratedColumn<DateTime>(
        'objection_deadline',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _taxCategoryMeta = const VerificationMeta(
    'taxCategory',
  );
  @override
  late final GeneratedColumn<String> taxCategory = GeneratedColumn<String>(
    'tax_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxYearMeta = const VerificationMeta(
    'taxYear',
  );
  @override
  late final GeneratedColumn<int> taxYear = GeneratedColumn<int>(
    'tax_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxAmountCentsMeta = const VerificationMeta(
    'taxAmountCents',
  );
  @override
  late final GeneratedColumn<int> taxAmountCents = GeneratedColumn<int>(
    'tax_amount_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destroyedAtMeta = const VerificationMeta(
    'destroyedAt',
  );
  @override
  late final GeneratedColumn<DateTime> destroyedAt = GeneratedColumn<DateTime>(
    'destroyed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destroyedFromMeta = const VerificationMeta(
    'destroyedFrom',
  );
  @override
  late final GeneratedColumn<String> destroyedFrom = GeneratedColumn<String>(
    'destroyed_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentReferenceMeta = const VerificationMeta(
    'paymentReference',
  );
  @override
  late final GeneratedColumn<String> paymentReference = GeneratedColumn<String>(
    'payment_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    docNumber,
    title,
    docDate,
    scannedAt,
    correspondentId,
    docType,
    storageLocation,
    pdfPath,
    pageCount,
    ocrText,
    retentionUntil,
    reminderAt,
    reminderNote,
    amountCents,
    dueDate,
    paymentStatus,
    paidAt,
    paymentReminderAt,
    filledPdfPath,
    fillData,
    contentHash,
    warrantyUntil,
    warrantyKind,
    objectionDeadline,
    taxCategory,
    taxYear,
    taxAmountCents,
    destroyedAt,
    destroyedFrom,
    paymentReference,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('doc_number')) {
      context.handle(
        _docNumberMeta,
        docNumber.isAcceptableOrUnknown(data['doc_number']!, _docNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_docNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('doc_date')) {
      context.handle(
        _docDateMeta,
        docDate.isAcceptableOrUnknown(data['doc_date']!, _docDateMeta),
      );
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    }
    if (data.containsKey('correspondent_id')) {
      context.handle(
        _correspondentIdMeta,
        correspondentId.isAcceptableOrUnknown(
          data['correspondent_id']!,
          _correspondentIdMeta,
        ),
      );
    }
    if (data.containsKey('doc_type')) {
      context.handle(
        _docTypeMeta,
        docType.isAcceptableOrUnknown(data['doc_type']!, _docTypeMeta),
      );
    }
    if (data.containsKey('storage_location')) {
      context.handle(
        _storageLocationMeta,
        storageLocation.isAcceptableOrUnknown(
          data['storage_location']!,
          _storageLocationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageLocationMeta);
    }
    if (data.containsKey('pdf_path')) {
      context.handle(
        _pdfPathMeta,
        pdfPath.isAcceptableOrUnknown(data['pdf_path']!, _pdfPathMeta),
      );
    } else if (isInserting) {
      context.missing(_pdfPathMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    if (data.containsKey('retention_until')) {
      context.handle(
        _retentionUntilMeta,
        retentionUntil.isAcceptableOrUnknown(
          data['retention_until']!,
          _retentionUntilMeta,
        ),
      );
    }
    if (data.containsKey('reminder_at')) {
      context.handle(
        _reminderAtMeta,
        reminderAt.isAcceptableOrUnknown(data['reminder_at']!, _reminderAtMeta),
      );
    }
    if (data.containsKey('reminder_note')) {
      context.handle(
        _reminderNoteMeta,
        reminderNote.isAcceptableOrUnknown(
          data['reminder_note']!,
          _reminderNoteMeta,
        ),
      );
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    if (data.containsKey('payment_reminder_at')) {
      context.handle(
        _paymentReminderAtMeta,
        paymentReminderAt.isAcceptableOrUnknown(
          data['payment_reminder_at']!,
          _paymentReminderAtMeta,
        ),
      );
    }
    if (data.containsKey('filled_pdf_path')) {
      context.handle(
        _filledPdfPathMeta,
        filledPdfPath.isAcceptableOrUnknown(
          data['filled_pdf_path']!,
          _filledPdfPathMeta,
        ),
      );
    }
    if (data.containsKey('fill_data')) {
      context.handle(
        _fillDataMeta,
        fillData.isAcceptableOrUnknown(data['fill_data']!, _fillDataMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('warranty_until')) {
      context.handle(
        _warrantyUntilMeta,
        warrantyUntil.isAcceptableOrUnknown(
          data['warranty_until']!,
          _warrantyUntilMeta,
        ),
      );
    }
    if (data.containsKey('warranty_kind')) {
      context.handle(
        _warrantyKindMeta,
        warrantyKind.isAcceptableOrUnknown(
          data['warranty_kind']!,
          _warrantyKindMeta,
        ),
      );
    }
    if (data.containsKey('objection_deadline')) {
      context.handle(
        _objectionDeadlineMeta,
        objectionDeadline.isAcceptableOrUnknown(
          data['objection_deadline']!,
          _objectionDeadlineMeta,
        ),
      );
    }
    if (data.containsKey('tax_category')) {
      context.handle(
        _taxCategoryMeta,
        taxCategory.isAcceptableOrUnknown(
          data['tax_category']!,
          _taxCategoryMeta,
        ),
      );
    }
    if (data.containsKey('tax_year')) {
      context.handle(
        _taxYearMeta,
        taxYear.isAcceptableOrUnknown(data['tax_year']!, _taxYearMeta),
      );
    }
    if (data.containsKey('tax_amount_cents')) {
      context.handle(
        _taxAmountCentsMeta,
        taxAmountCents.isAcceptableOrUnknown(
          data['tax_amount_cents']!,
          _taxAmountCentsMeta,
        ),
      );
    }
    if (data.containsKey('destroyed_at')) {
      context.handle(
        _destroyedAtMeta,
        destroyedAt.isAcceptableOrUnknown(
          data['destroyed_at']!,
          _destroyedAtMeta,
        ),
      );
    }
    if (data.containsKey('destroyed_from')) {
      context.handle(
        _destroyedFromMeta,
        destroyedFrom.isAcceptableOrUnknown(
          data['destroyed_from']!,
          _destroyedFromMeta,
        ),
      );
    }
    if (data.containsKey('payment_reference')) {
      context.handle(
        _paymentReferenceMeta,
        paymentReference.isAcceptableOrUnknown(
          data['payment_reference']!,
          _paymentReferenceMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      docNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      docDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}doc_date'],
      ),
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      )!,
      correspondentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correspondent_id'],
      ),
      docType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_type'],
      ),
      storageLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_location'],
      )!,
      pdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_path'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      )!,
      retentionUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}retention_until'],
      ),
      reminderAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reminder_at'],
      ),
      reminderNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_note'],
      ),
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      paymentReminderAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}payment_reminder_at'],
      ),
      filledPdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_pdf_path'],
      ),
      fillData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fill_data'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      warrantyUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}warranty_until'],
      ),
      warrantyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warranty_kind'],
      ),
      objectionDeadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}objection_deadline'],
      ),
      taxCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_category'],
      ),
      taxYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_year'],
      ),
      taxAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_amount_cents'],
      ),
      destroyedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}destroyed_at'],
      ),
      destroyedFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destroyed_from'],
      ),
      paymentReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_reference'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final String id;

  /// Fortlaufende Nummer im Schema JJJJ-NNNN, steht auch auf dem Original.
  final String docNumber;
  final String title;

  /// Datum des Dokuments (nicht des Scans).
  final DateTime? docDate;
  final DateTime scannedAt;
  final String? correspondentId;
  final String? docType;

  /// Wo liegt das Original: "Box 2026", Mappe, digital, vernichtet.
  final String storageLocation;

  /// Pfad der PDF relativ zum App-Dokumentenverzeichnis.
  final String pdfPath;
  final int pageCount;
  final String ocrText;

  /// Aufbewahren bis — danach erscheint das Dokument in der Ausmistliste.
  final DateTime? retentionUntil;

  /// Wiedervorlage/Kündigungsfrist mit Benachrichtigung.
  final DateTime? reminderAt;
  final String? reminderNote;

  /// Endbetrag in Cent.
  final int? amountCents;
  final DateTime? dueDate;

  /// Siehe `PaymentStatus`: zu bezahlen, wird abgebucht, bezahlt,
  /// Gutschrift. `null` = keine Zahlung betroffen.
  final String? paymentStatus;
  final DateTime? paidAt;

  /// Zahlungserinnerung (eigene Benachrichtigung, unabhängig von
  /// [reminderAt]).
  final DateTime? paymentReminderAt;

  /// Ausgefüllte Kopie (PDF, relativ zum App-Verzeichnis). Das Original in
  /// [pdfPath] bleibt unverändert.
  final String? filledPdfPath;

  /// Eingetragene Texte/Haken/Unterschriften als JSON (siehe FillDocument),
  /// damit man später weiter ausfüllen kann.
  final String? fillData;

  /// SHA-256 der PDF (Dubletten-Erkennung).
  final String? contentHash;
  final DateTime? warrantyUntil;

  /// `garantie` oder `gewaehrleistung`.
  final String? warrantyKind;
  final DateTime? objectionDeadline;

  /// Steuer-Mappe: Kategorie, Jahr, anrechenbarer Betrag (Cent).
  final String? taxCategory;
  final int? taxYear;
  final int? taxAmountCents;

  /// Vernichtungs-Protokoll.
  final DateTime? destroyedAt;
  final String? destroyedFrom;

  /// Verwendungszweck für Überweisung (GiroCode).
  final String? paymentReference;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Document({
    required this.id,
    required this.docNumber,
    required this.title,
    this.docDate,
    required this.scannedAt,
    this.correspondentId,
    this.docType,
    required this.storageLocation,
    required this.pdfPath,
    required this.pageCount,
    required this.ocrText,
    this.retentionUntil,
    this.reminderAt,
    this.reminderNote,
    this.amountCents,
    this.dueDate,
    this.paymentStatus,
    this.paidAt,
    this.paymentReminderAt,
    this.filledPdfPath,
    this.fillData,
    this.contentHash,
    this.warrantyUntil,
    this.warrantyKind,
    this.objectionDeadline,
    this.taxCategory,
    this.taxYear,
    this.taxAmountCents,
    this.destroyedAt,
    this.destroyedFrom,
    this.paymentReference,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['doc_number'] = Variable<String>(docNumber);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || docDate != null) {
      map['doc_date'] = Variable<DateTime>(docDate);
    }
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    if (!nullToAbsent || correspondentId != null) {
      map['correspondent_id'] = Variable<String>(correspondentId);
    }
    if (!nullToAbsent || docType != null) {
      map['doc_type'] = Variable<String>(docType);
    }
    map['storage_location'] = Variable<String>(storageLocation);
    map['pdf_path'] = Variable<String>(pdfPath);
    map['page_count'] = Variable<int>(pageCount);
    map['ocr_text'] = Variable<String>(ocrText);
    if (!nullToAbsent || retentionUntil != null) {
      map['retention_until'] = Variable<DateTime>(retentionUntil);
    }
    if (!nullToAbsent || reminderAt != null) {
      map['reminder_at'] = Variable<DateTime>(reminderAt);
    }
    if (!nullToAbsent || reminderNote != null) {
      map['reminder_note'] = Variable<String>(reminderNote);
    }
    if (!nullToAbsent || amountCents != null) {
      map['amount_cents'] = Variable<int>(amountCents);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || paymentStatus != null) {
      map['payment_status'] = Variable<String>(paymentStatus);
    }
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    if (!nullToAbsent || paymentReminderAt != null) {
      map['payment_reminder_at'] = Variable<DateTime>(paymentReminderAt);
    }
    if (!nullToAbsent || filledPdfPath != null) {
      map['filled_pdf_path'] = Variable<String>(filledPdfPath);
    }
    if (!nullToAbsent || fillData != null) {
      map['fill_data'] = Variable<String>(fillData);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || warrantyUntil != null) {
      map['warranty_until'] = Variable<DateTime>(warrantyUntil);
    }
    if (!nullToAbsent || warrantyKind != null) {
      map['warranty_kind'] = Variable<String>(warrantyKind);
    }
    if (!nullToAbsent || objectionDeadline != null) {
      map['objection_deadline'] = Variable<DateTime>(objectionDeadline);
    }
    if (!nullToAbsent || taxCategory != null) {
      map['tax_category'] = Variable<String>(taxCategory);
    }
    if (!nullToAbsent || taxYear != null) {
      map['tax_year'] = Variable<int>(taxYear);
    }
    if (!nullToAbsent || taxAmountCents != null) {
      map['tax_amount_cents'] = Variable<int>(taxAmountCents);
    }
    if (!nullToAbsent || destroyedAt != null) {
      map['destroyed_at'] = Variable<DateTime>(destroyedAt);
    }
    if (!nullToAbsent || destroyedFrom != null) {
      map['destroyed_from'] = Variable<String>(destroyedFrom);
    }
    if (!nullToAbsent || paymentReference != null) {
      map['payment_reference'] = Variable<String>(paymentReference);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      docNumber: Value(docNumber),
      title: Value(title),
      docDate: docDate == null && nullToAbsent
          ? const Value.absent()
          : Value(docDate),
      scannedAt: Value(scannedAt),
      correspondentId: correspondentId == null && nullToAbsent
          ? const Value.absent()
          : Value(correspondentId),
      docType: docType == null && nullToAbsent
          ? const Value.absent()
          : Value(docType),
      storageLocation: Value(storageLocation),
      pdfPath: Value(pdfPath),
      pageCount: Value(pageCount),
      ocrText: Value(ocrText),
      retentionUntil: retentionUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(retentionUntil),
      reminderAt: reminderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderAt),
      reminderNote: reminderNote == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderNote),
      amountCents: amountCents == null && nullToAbsent
          ? const Value.absent()
          : Value(amountCents),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      paymentStatus: paymentStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentStatus),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      paymentReminderAt: paymentReminderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentReminderAt),
      filledPdfPath: filledPdfPath == null && nullToAbsent
          ? const Value.absent()
          : Value(filledPdfPath),
      fillData: fillData == null && nullToAbsent
          ? const Value.absent()
          : Value(fillData),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      warrantyUntil: warrantyUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyUntil),
      warrantyKind: warrantyKind == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyKind),
      objectionDeadline: objectionDeadline == null && nullToAbsent
          ? const Value.absent()
          : Value(objectionDeadline),
      taxCategory: taxCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(taxCategory),
      taxYear: taxYear == null && nullToAbsent
          ? const Value.absent()
          : Value(taxYear),
      taxAmountCents: taxAmountCents == null && nullToAbsent
          ? const Value.absent()
          : Value(taxAmountCents),
      destroyedAt: destroyedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(destroyedAt),
      destroyedFrom: destroyedFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(destroyedFrom),
      paymentReference: paymentReference == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentReference),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<String>(json['id']),
      docNumber: serializer.fromJson<String>(json['docNumber']),
      title: serializer.fromJson<String>(json['title']),
      docDate: serializer.fromJson<DateTime?>(json['docDate']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      correspondentId: serializer.fromJson<String?>(json['correspondentId']),
      docType: serializer.fromJson<String?>(json['docType']),
      storageLocation: serializer.fromJson<String>(json['storageLocation']),
      pdfPath: serializer.fromJson<String>(json['pdfPath']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      ocrText: serializer.fromJson<String>(json['ocrText']),
      retentionUntil: serializer.fromJson<DateTime?>(json['retentionUntil']),
      reminderAt: serializer.fromJson<DateTime?>(json['reminderAt']),
      reminderNote: serializer.fromJson<String?>(json['reminderNote']),
      amountCents: serializer.fromJson<int?>(json['amountCents']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      paymentStatus: serializer.fromJson<String?>(json['paymentStatus']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      paymentReminderAt: serializer.fromJson<DateTime?>(
        json['paymentReminderAt'],
      ),
      filledPdfPath: serializer.fromJson<String?>(json['filledPdfPath']),
      fillData: serializer.fromJson<String?>(json['fillData']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      warrantyUntil: serializer.fromJson<DateTime?>(json['warrantyUntil']),
      warrantyKind: serializer.fromJson<String?>(json['warrantyKind']),
      objectionDeadline: serializer.fromJson<DateTime?>(
        json['objectionDeadline'],
      ),
      taxCategory: serializer.fromJson<String?>(json['taxCategory']),
      taxYear: serializer.fromJson<int?>(json['taxYear']),
      taxAmountCents: serializer.fromJson<int?>(json['taxAmountCents']),
      destroyedAt: serializer.fromJson<DateTime?>(json['destroyedAt']),
      destroyedFrom: serializer.fromJson<String?>(json['destroyedFrom']),
      paymentReference: serializer.fromJson<String?>(json['paymentReference']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'docNumber': serializer.toJson<String>(docNumber),
      'title': serializer.toJson<String>(title),
      'docDate': serializer.toJson<DateTime?>(docDate),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'correspondentId': serializer.toJson<String?>(correspondentId),
      'docType': serializer.toJson<String?>(docType),
      'storageLocation': serializer.toJson<String>(storageLocation),
      'pdfPath': serializer.toJson<String>(pdfPath),
      'pageCount': serializer.toJson<int>(pageCount),
      'ocrText': serializer.toJson<String>(ocrText),
      'retentionUntil': serializer.toJson<DateTime?>(retentionUntil),
      'reminderAt': serializer.toJson<DateTime?>(reminderAt),
      'reminderNote': serializer.toJson<String?>(reminderNote),
      'amountCents': serializer.toJson<int?>(amountCents),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'paymentStatus': serializer.toJson<String?>(paymentStatus),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'paymentReminderAt': serializer.toJson<DateTime?>(paymentReminderAt),
      'filledPdfPath': serializer.toJson<String?>(filledPdfPath),
      'fillData': serializer.toJson<String?>(fillData),
      'contentHash': serializer.toJson<String?>(contentHash),
      'warrantyUntil': serializer.toJson<DateTime?>(warrantyUntil),
      'warrantyKind': serializer.toJson<String?>(warrantyKind),
      'objectionDeadline': serializer.toJson<DateTime?>(objectionDeadline),
      'taxCategory': serializer.toJson<String?>(taxCategory),
      'taxYear': serializer.toJson<int?>(taxYear),
      'taxAmountCents': serializer.toJson<int?>(taxAmountCents),
      'destroyedAt': serializer.toJson<DateTime?>(destroyedAt),
      'destroyedFrom': serializer.toJson<String?>(destroyedFrom),
      'paymentReference': serializer.toJson<String?>(paymentReference),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Document copyWith({
    String? id,
    String? docNumber,
    String? title,
    Value<DateTime?> docDate = const Value.absent(),
    DateTime? scannedAt,
    Value<String?> correspondentId = const Value.absent(),
    Value<String?> docType = const Value.absent(),
    String? storageLocation,
    String? pdfPath,
    int? pageCount,
    String? ocrText,
    Value<DateTime?> retentionUntil = const Value.absent(),
    Value<DateTime?> reminderAt = const Value.absent(),
    Value<String?> reminderNote = const Value.absent(),
    Value<int?> amountCents = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String?> paymentStatus = const Value.absent(),
    Value<DateTime?> paidAt = const Value.absent(),
    Value<DateTime?> paymentReminderAt = const Value.absent(),
    Value<String?> filledPdfPath = const Value.absent(),
    Value<String?> fillData = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    Value<DateTime?> warrantyUntil = const Value.absent(),
    Value<String?> warrantyKind = const Value.absent(),
    Value<DateTime?> objectionDeadline = const Value.absent(),
    Value<String?> taxCategory = const Value.absent(),
    Value<int?> taxYear = const Value.absent(),
    Value<int?> taxAmountCents = const Value.absent(),
    Value<DateTime?> destroyedAt = const Value.absent(),
    Value<String?> destroyedFrom = const Value.absent(),
    Value<String?> paymentReference = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Document(
    id: id ?? this.id,
    docNumber: docNumber ?? this.docNumber,
    title: title ?? this.title,
    docDate: docDate.present ? docDate.value : this.docDate,
    scannedAt: scannedAt ?? this.scannedAt,
    correspondentId: correspondentId.present
        ? correspondentId.value
        : this.correspondentId,
    docType: docType.present ? docType.value : this.docType,
    storageLocation: storageLocation ?? this.storageLocation,
    pdfPath: pdfPath ?? this.pdfPath,
    pageCount: pageCount ?? this.pageCount,
    ocrText: ocrText ?? this.ocrText,
    retentionUntil: retentionUntil.present
        ? retentionUntil.value
        : this.retentionUntil,
    reminderAt: reminderAt.present ? reminderAt.value : this.reminderAt,
    reminderNote: reminderNote.present ? reminderNote.value : this.reminderNote,
    amountCents: amountCents.present ? amountCents.value : this.amountCents,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    paymentStatus: paymentStatus.present
        ? paymentStatus.value
        : this.paymentStatus,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    paymentReminderAt: paymentReminderAt.present
        ? paymentReminderAt.value
        : this.paymentReminderAt,
    filledPdfPath: filledPdfPath.present
        ? filledPdfPath.value
        : this.filledPdfPath,
    fillData: fillData.present ? fillData.value : this.fillData,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    warrantyUntil: warrantyUntil.present
        ? warrantyUntil.value
        : this.warrantyUntil,
    warrantyKind: warrantyKind.present ? warrantyKind.value : this.warrantyKind,
    objectionDeadline: objectionDeadline.present
        ? objectionDeadline.value
        : this.objectionDeadline,
    taxCategory: taxCategory.present ? taxCategory.value : this.taxCategory,
    taxYear: taxYear.present ? taxYear.value : this.taxYear,
    taxAmountCents: taxAmountCents.present
        ? taxAmountCents.value
        : this.taxAmountCents,
    destroyedAt: destroyedAt.present ? destroyedAt.value : this.destroyedAt,
    destroyedFrom: destroyedFrom.present
        ? destroyedFrom.value
        : this.destroyedFrom,
    paymentReference: paymentReference.present
        ? paymentReference.value
        : this.paymentReference,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      docNumber: data.docNumber.present ? data.docNumber.value : this.docNumber,
      title: data.title.present ? data.title.value : this.title,
      docDate: data.docDate.present ? data.docDate.value : this.docDate,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      correspondentId: data.correspondentId.present
          ? data.correspondentId.value
          : this.correspondentId,
      docType: data.docType.present ? data.docType.value : this.docType,
      storageLocation: data.storageLocation.present
          ? data.storageLocation.value
          : this.storageLocation,
      pdfPath: data.pdfPath.present ? data.pdfPath.value : this.pdfPath,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      retentionUntil: data.retentionUntil.present
          ? data.retentionUntil.value
          : this.retentionUntil,
      reminderAt: data.reminderAt.present
          ? data.reminderAt.value
          : this.reminderAt,
      reminderNote: data.reminderNote.present
          ? data.reminderNote.value
          : this.reminderNote,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      paymentReminderAt: data.paymentReminderAt.present
          ? data.paymentReminderAt.value
          : this.paymentReminderAt,
      filledPdfPath: data.filledPdfPath.present
          ? data.filledPdfPath.value
          : this.filledPdfPath,
      fillData: data.fillData.present ? data.fillData.value : this.fillData,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      warrantyUntil: data.warrantyUntil.present
          ? data.warrantyUntil.value
          : this.warrantyUntil,
      warrantyKind: data.warrantyKind.present
          ? data.warrantyKind.value
          : this.warrantyKind,
      objectionDeadline: data.objectionDeadline.present
          ? data.objectionDeadline.value
          : this.objectionDeadline,
      taxCategory: data.taxCategory.present
          ? data.taxCategory.value
          : this.taxCategory,
      taxYear: data.taxYear.present ? data.taxYear.value : this.taxYear,
      taxAmountCents: data.taxAmountCents.present
          ? data.taxAmountCents.value
          : this.taxAmountCents,
      destroyedAt: data.destroyedAt.present
          ? data.destroyedAt.value
          : this.destroyedAt,
      destroyedFrom: data.destroyedFrom.present
          ? data.destroyedFrom.value
          : this.destroyedFrom,
      paymentReference: data.paymentReference.present
          ? data.paymentReference.value
          : this.paymentReference,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('docNumber: $docNumber, ')
          ..write('title: $title, ')
          ..write('docDate: $docDate, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('docType: $docType, ')
          ..write('storageLocation: $storageLocation, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('pageCount: $pageCount, ')
          ..write('ocrText: $ocrText, ')
          ..write('retentionUntil: $retentionUntil, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('reminderNote: $reminderNote, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueDate: $dueDate, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('paidAt: $paidAt, ')
          ..write('paymentReminderAt: $paymentReminderAt, ')
          ..write('filledPdfPath: $filledPdfPath, ')
          ..write('fillData: $fillData, ')
          ..write('contentHash: $contentHash, ')
          ..write('warrantyUntil: $warrantyUntil, ')
          ..write('warrantyKind: $warrantyKind, ')
          ..write('objectionDeadline: $objectionDeadline, ')
          ..write('taxCategory: $taxCategory, ')
          ..write('taxYear: $taxYear, ')
          ..write('taxAmountCents: $taxAmountCents, ')
          ..write('destroyedAt: $destroyedAt, ')
          ..write('destroyedFrom: $destroyedFrom, ')
          ..write('paymentReference: $paymentReference, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    docNumber,
    title,
    docDate,
    scannedAt,
    correspondentId,
    docType,
    storageLocation,
    pdfPath,
    pageCount,
    ocrText,
    retentionUntil,
    reminderAt,
    reminderNote,
    amountCents,
    dueDate,
    paymentStatus,
    paidAt,
    paymentReminderAt,
    filledPdfPath,
    fillData,
    contentHash,
    warrantyUntil,
    warrantyKind,
    objectionDeadline,
    taxCategory,
    taxYear,
    taxAmountCents,
    destroyedAt,
    destroyedFrom,
    paymentReference,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.docNumber == this.docNumber &&
          other.title == this.title &&
          other.docDate == this.docDate &&
          other.scannedAt == this.scannedAt &&
          other.correspondentId == this.correspondentId &&
          other.docType == this.docType &&
          other.storageLocation == this.storageLocation &&
          other.pdfPath == this.pdfPath &&
          other.pageCount == this.pageCount &&
          other.ocrText == this.ocrText &&
          other.retentionUntil == this.retentionUntil &&
          other.reminderAt == this.reminderAt &&
          other.reminderNote == this.reminderNote &&
          other.amountCents == this.amountCents &&
          other.dueDate == this.dueDate &&
          other.paymentStatus == this.paymentStatus &&
          other.paidAt == this.paidAt &&
          other.paymentReminderAt == this.paymentReminderAt &&
          other.filledPdfPath == this.filledPdfPath &&
          other.fillData == this.fillData &&
          other.contentHash == this.contentHash &&
          other.warrantyUntil == this.warrantyUntil &&
          other.warrantyKind == this.warrantyKind &&
          other.objectionDeadline == this.objectionDeadline &&
          other.taxCategory == this.taxCategory &&
          other.taxYear == this.taxYear &&
          other.taxAmountCents == this.taxAmountCents &&
          other.destroyedAt == this.destroyedAt &&
          other.destroyedFrom == this.destroyedFrom &&
          other.paymentReference == this.paymentReference &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> id;
  final Value<String> docNumber;
  final Value<String> title;
  final Value<DateTime?> docDate;
  final Value<DateTime> scannedAt;
  final Value<String?> correspondentId;
  final Value<String?> docType;
  final Value<String> storageLocation;
  final Value<String> pdfPath;
  final Value<int> pageCount;
  final Value<String> ocrText;
  final Value<DateTime?> retentionUntil;
  final Value<DateTime?> reminderAt;
  final Value<String?> reminderNote;
  final Value<int?> amountCents;
  final Value<DateTime?> dueDate;
  final Value<String?> paymentStatus;
  final Value<DateTime?> paidAt;
  final Value<DateTime?> paymentReminderAt;
  final Value<String?> filledPdfPath;
  final Value<String?> fillData;
  final Value<String?> contentHash;
  final Value<DateTime?> warrantyUntil;
  final Value<String?> warrantyKind;
  final Value<DateTime?> objectionDeadline;
  final Value<String?> taxCategory;
  final Value<int?> taxYear;
  final Value<int?> taxAmountCents;
  final Value<DateTime?> destroyedAt;
  final Value<String?> destroyedFrom;
  final Value<String?> paymentReference;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.docNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.docDate = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.correspondentId = const Value.absent(),
    this.docType = const Value.absent(),
    this.storageLocation = const Value.absent(),
    this.pdfPath = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.retentionUntil = const Value.absent(),
    this.reminderAt = const Value.absent(),
    this.reminderNote = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.paymentReminderAt = const Value.absent(),
    this.filledPdfPath = const Value.absent(),
    this.fillData = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.warrantyUntil = const Value.absent(),
    this.warrantyKind = const Value.absent(),
    this.objectionDeadline = const Value.absent(),
    this.taxCategory = const Value.absent(),
    this.taxYear = const Value.absent(),
    this.taxAmountCents = const Value.absent(),
    this.destroyedAt = const Value.absent(),
    this.destroyedFrom = const Value.absent(),
    this.paymentReference = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String docNumber,
    this.title = const Value.absent(),
    this.docDate = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.correspondentId = const Value.absent(),
    this.docType = const Value.absent(),
    required String storageLocation,
    required String pdfPath,
    this.pageCount = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.retentionUntil = const Value.absent(),
    this.reminderAt = const Value.absent(),
    this.reminderNote = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.paymentReminderAt = const Value.absent(),
    this.filledPdfPath = const Value.absent(),
    this.fillData = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.warrantyUntil = const Value.absent(),
    this.warrantyKind = const Value.absent(),
    this.objectionDeadline = const Value.absent(),
    this.taxCategory = const Value.absent(),
    this.taxYear = const Value.absent(),
    this.taxAmountCents = const Value.absent(),
    this.destroyedAt = const Value.absent(),
    this.destroyedFrom = const Value.absent(),
    this.paymentReference = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : docNumber = Value(docNumber),
       storageLocation = Value(storageLocation),
       pdfPath = Value(pdfPath);
  static Insertable<Document> custom({
    Expression<String>? id,
    Expression<String>? docNumber,
    Expression<String>? title,
    Expression<DateTime>? docDate,
    Expression<DateTime>? scannedAt,
    Expression<String>? correspondentId,
    Expression<String>? docType,
    Expression<String>? storageLocation,
    Expression<String>? pdfPath,
    Expression<int>? pageCount,
    Expression<String>? ocrText,
    Expression<DateTime>? retentionUntil,
    Expression<DateTime>? reminderAt,
    Expression<String>? reminderNote,
    Expression<int>? amountCents,
    Expression<DateTime>? dueDate,
    Expression<String>? paymentStatus,
    Expression<DateTime>? paidAt,
    Expression<DateTime>? paymentReminderAt,
    Expression<String>? filledPdfPath,
    Expression<String>? fillData,
    Expression<String>? contentHash,
    Expression<DateTime>? warrantyUntil,
    Expression<String>? warrantyKind,
    Expression<DateTime>? objectionDeadline,
    Expression<String>? taxCategory,
    Expression<int>? taxYear,
    Expression<int>? taxAmountCents,
    Expression<DateTime>? destroyedAt,
    Expression<String>? destroyedFrom,
    Expression<String>? paymentReference,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (docNumber != null) 'doc_number': docNumber,
      if (title != null) 'title': title,
      if (docDate != null) 'doc_date': docDate,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (correspondentId != null) 'correspondent_id': correspondentId,
      if (docType != null) 'doc_type': docType,
      if (storageLocation != null) 'storage_location': storageLocation,
      if (pdfPath != null) 'pdf_path': pdfPath,
      if (pageCount != null) 'page_count': pageCount,
      if (ocrText != null) 'ocr_text': ocrText,
      if (retentionUntil != null) 'retention_until': retentionUntil,
      if (reminderAt != null) 'reminder_at': reminderAt,
      if (reminderNote != null) 'reminder_note': reminderNote,
      if (amountCents != null) 'amount_cents': amountCents,
      if (dueDate != null) 'due_date': dueDate,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paidAt != null) 'paid_at': paidAt,
      if (paymentReminderAt != null) 'payment_reminder_at': paymentReminderAt,
      if (filledPdfPath != null) 'filled_pdf_path': filledPdfPath,
      if (fillData != null) 'fill_data': fillData,
      if (contentHash != null) 'content_hash': contentHash,
      if (warrantyUntil != null) 'warranty_until': warrantyUntil,
      if (warrantyKind != null) 'warranty_kind': warrantyKind,
      if (objectionDeadline != null) 'objection_deadline': objectionDeadline,
      if (taxCategory != null) 'tax_category': taxCategory,
      if (taxYear != null) 'tax_year': taxYear,
      if (taxAmountCents != null) 'tax_amount_cents': taxAmountCents,
      if (destroyedAt != null) 'destroyed_at': destroyedAt,
      if (destroyedFrom != null) 'destroyed_from': destroyedFrom,
      if (paymentReference != null) 'payment_reference': paymentReference,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? docNumber,
    Value<String>? title,
    Value<DateTime?>? docDate,
    Value<DateTime>? scannedAt,
    Value<String?>? correspondentId,
    Value<String?>? docType,
    Value<String>? storageLocation,
    Value<String>? pdfPath,
    Value<int>? pageCount,
    Value<String>? ocrText,
    Value<DateTime?>? retentionUntil,
    Value<DateTime?>? reminderAt,
    Value<String?>? reminderNote,
    Value<int?>? amountCents,
    Value<DateTime?>? dueDate,
    Value<String?>? paymentStatus,
    Value<DateTime?>? paidAt,
    Value<DateTime?>? paymentReminderAt,
    Value<String?>? filledPdfPath,
    Value<String?>? fillData,
    Value<String?>? contentHash,
    Value<DateTime?>? warrantyUntil,
    Value<String?>? warrantyKind,
    Value<DateTime?>? objectionDeadline,
    Value<String?>? taxCategory,
    Value<int?>? taxYear,
    Value<int?>? taxAmountCents,
    Value<DateTime?>? destroyedAt,
    Value<String?>? destroyedFrom,
    Value<String?>? paymentReference,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      docNumber: docNumber ?? this.docNumber,
      title: title ?? this.title,
      docDate: docDate ?? this.docDate,
      scannedAt: scannedAt ?? this.scannedAt,
      correspondentId: correspondentId ?? this.correspondentId,
      docType: docType ?? this.docType,
      storageLocation: storageLocation ?? this.storageLocation,
      pdfPath: pdfPath ?? this.pdfPath,
      pageCount: pageCount ?? this.pageCount,
      ocrText: ocrText ?? this.ocrText,
      retentionUntil: retentionUntil ?? this.retentionUntil,
      reminderAt: reminderAt ?? this.reminderAt,
      reminderNote: reminderNote ?? this.reminderNote,
      amountCents: amountCents ?? this.amountCents,
      dueDate: dueDate ?? this.dueDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      paymentReminderAt: paymentReminderAt ?? this.paymentReminderAt,
      filledPdfPath: filledPdfPath ?? this.filledPdfPath,
      fillData: fillData ?? this.fillData,
      contentHash: contentHash ?? this.contentHash,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      warrantyKind: warrantyKind ?? this.warrantyKind,
      objectionDeadline: objectionDeadline ?? this.objectionDeadline,
      taxCategory: taxCategory ?? this.taxCategory,
      taxYear: taxYear ?? this.taxYear,
      taxAmountCents: taxAmountCents ?? this.taxAmountCents,
      destroyedAt: destroyedAt ?? this.destroyedAt,
      destroyedFrom: destroyedFrom ?? this.destroyedFrom,
      paymentReference: paymentReference ?? this.paymentReference,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (docNumber.present) {
      map['doc_number'] = Variable<String>(docNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (docDate.present) {
      map['doc_date'] = Variable<DateTime>(docDate.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (correspondentId.present) {
      map['correspondent_id'] = Variable<String>(correspondentId.value);
    }
    if (docType.present) {
      map['doc_type'] = Variable<String>(docType.value);
    }
    if (storageLocation.present) {
      map['storage_location'] = Variable<String>(storageLocation.value);
    }
    if (pdfPath.present) {
      map['pdf_path'] = Variable<String>(pdfPath.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (retentionUntil.present) {
      map['retention_until'] = Variable<DateTime>(retentionUntil.value);
    }
    if (reminderAt.present) {
      map['reminder_at'] = Variable<DateTime>(reminderAt.value);
    }
    if (reminderNote.present) {
      map['reminder_note'] = Variable<String>(reminderNote.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (paymentReminderAt.present) {
      map['payment_reminder_at'] = Variable<DateTime>(paymentReminderAt.value);
    }
    if (filledPdfPath.present) {
      map['filled_pdf_path'] = Variable<String>(filledPdfPath.value);
    }
    if (fillData.present) {
      map['fill_data'] = Variable<String>(fillData.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (warrantyUntil.present) {
      map['warranty_until'] = Variable<DateTime>(warrantyUntil.value);
    }
    if (warrantyKind.present) {
      map['warranty_kind'] = Variable<String>(warrantyKind.value);
    }
    if (objectionDeadline.present) {
      map['objection_deadline'] = Variable<DateTime>(objectionDeadline.value);
    }
    if (taxCategory.present) {
      map['tax_category'] = Variable<String>(taxCategory.value);
    }
    if (taxYear.present) {
      map['tax_year'] = Variable<int>(taxYear.value);
    }
    if (taxAmountCents.present) {
      map['tax_amount_cents'] = Variable<int>(taxAmountCents.value);
    }
    if (destroyedAt.present) {
      map['destroyed_at'] = Variable<DateTime>(destroyedAt.value);
    }
    if (destroyedFrom.present) {
      map['destroyed_from'] = Variable<String>(destroyedFrom.value);
    }
    if (paymentReference.present) {
      map['payment_reference'] = Variable<String>(paymentReference.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('docNumber: $docNumber, ')
          ..write('title: $title, ')
          ..write('docDate: $docDate, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('docType: $docType, ')
          ..write('storageLocation: $storageLocation, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('pageCount: $pageCount, ')
          ..write('ocrText: $ocrText, ')
          ..write('retentionUntil: $retentionUntil, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('reminderNote: $reminderNote, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueDate: $dueDate, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('paidAt: $paidAt, ')
          ..write('paymentReminderAt: $paymentReminderAt, ')
          ..write('filledPdfPath: $filledPdfPath, ')
          ..write('fillData: $fillData, ')
          ..write('contentHash: $contentHash, ')
          ..write('warrantyUntil: $warrantyUntil, ')
          ..write('warrantyKind: $warrantyKind, ')
          ..write('objectionDeadline: $objectionDeadline, ')
          ..write('taxCategory: $taxCategory, ')
          ..write('taxYear: $taxYear, ')
          ..write('taxAmountCents: $taxAmountCents, ')
          ..write('destroyedAt: $destroyedAt, ')
          ..write('destroyedFrom: $destroyedFrom, ')
          ..write('paymentReference: $paymentReference, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CorrespondentsTable extends Correspondents
    with TableInfo<$CorrespondentsTable, Correspondent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CorrespondentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _faxMeta = const VerificationMeta('fax');
  @override
  late final GeneratedColumn<String> fax = GeneratedColumn<String>(
    'fax',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postalAddressMeta = const VerificationMeta(
    'postalAddress',
  );
  @override
  late final GeneratedColumn<String> postalAddress = GeneratedColumn<String>(
    'postal_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mailSubjectTemplateMeta =
      const VerificationMeta('mailSubjectTemplate');
  @override
  late final GeneratedColumn<String> mailSubjectTemplate =
      GeneratedColumn<String>(
        'mail_subject_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mailBodyTemplateMeta = const VerificationMeta(
    'mailBodyTemplate',
  );
  @override
  late final GeneratedColumn<String> mailBodyTemplate = GeneratedColumn<String>(
    'mail_body_template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ibanMeta = const VerificationMeta('iban');
  @override
  late final GeneratedColumn<String> iban = GeneratedColumn<String>(
    'iban',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bicMeta = const VerificationMeta('bic');
  @override
  late final GeneratedColumn<String> bic = GeneratedColumn<String>(
    'bic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultDocTypeMeta = const VerificationMeta(
    'defaultDocType',
  );
  @override
  late final GeneratedColumn<String> defaultDocType = GeneratedColumn<String>(
    'default_doc_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultTagIdsMeta = const VerificationMeta(
    'defaultTagIds',
  );
  @override
  late final GeneratedColumn<String> defaultTagIds = GeneratedColumn<String>(
    'default_tag_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    aliases,
    categoryId,
    email,
    fax,
    postalAddress,
    mailSubjectTemplate,
    mailBodyTemplate,
    iban,
    bic,
    defaultDocType,
    defaultTagIds,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'correspondents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Correspondent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('fax')) {
      context.handle(
        _faxMeta,
        fax.isAcceptableOrUnknown(data['fax']!, _faxMeta),
      );
    }
    if (data.containsKey('postal_address')) {
      context.handle(
        _postalAddressMeta,
        postalAddress.isAcceptableOrUnknown(
          data['postal_address']!,
          _postalAddressMeta,
        ),
      );
    }
    if (data.containsKey('mail_subject_template')) {
      context.handle(
        _mailSubjectTemplateMeta,
        mailSubjectTemplate.isAcceptableOrUnknown(
          data['mail_subject_template']!,
          _mailSubjectTemplateMeta,
        ),
      );
    }
    if (data.containsKey('mail_body_template')) {
      context.handle(
        _mailBodyTemplateMeta,
        mailBodyTemplate.isAcceptableOrUnknown(
          data['mail_body_template']!,
          _mailBodyTemplateMeta,
        ),
      );
    }
    if (data.containsKey('iban')) {
      context.handle(
        _ibanMeta,
        iban.isAcceptableOrUnknown(data['iban']!, _ibanMeta),
      );
    }
    if (data.containsKey('bic')) {
      context.handle(
        _bicMeta,
        bic.isAcceptableOrUnknown(data['bic']!, _bicMeta),
      );
    }
    if (data.containsKey('default_doc_type')) {
      context.handle(
        _defaultDocTypeMeta,
        defaultDocType.isAcceptableOrUnknown(
          data['default_doc_type']!,
          _defaultDocTypeMeta,
        ),
      );
    }
    if (data.containsKey('default_tag_ids')) {
      context.handle(
        _defaultTagIdsMeta,
        defaultTagIds.isAcceptableOrUnknown(
          data['default_tag_ids']!,
          _defaultTagIdsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Correspondent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Correspondent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      fax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fax'],
      ),
      postalAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postal_address'],
      ),
      mailSubjectTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_subject_template'],
      ),
      mailBodyTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_body_template'],
      ),
      iban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iban'],
      ),
      bic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bic'],
      ),
      defaultDocType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_doc_type'],
      ),
      defaultTagIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_tag_ids'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CorrespondentsTable createAlias(String alias) {
    return $CorrespondentsTable(attachedDatabase, alias);
  }
}

class Correspondent extends DataClass implements Insertable<Correspondent> {
  final String id;
  final String name;

  /// Erkennungs-Keywords, mit Zeilenumbruch getrennt. Wird eines davon im
  /// OCR-Text gefunden, wird dieser Absender vorgeschlagen.
  final String aliases;

  /// Kategorie der Firma (z. B. „Bank & Geldanlage“). Dokumente lassen sich
  /// darüber filtern (Schema v3).
  final String? categoryId;
  final String? email;
  final String? fax;
  final String? postalAddress;
  final String? mailSubjectTemplate;
  final String? mailBodyTemplate;
  final String? iban;
  final String? bic;

  /// Zuletzt bestätigte Werte — Grundlage der „lernenden Zuordnungen".
  final String? defaultDocType;
  final String defaultTagIds;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Correspondent({
    required this.id,
    required this.name,
    required this.aliases,
    this.categoryId,
    this.email,
    this.fax,
    this.postalAddress,
    this.mailSubjectTemplate,
    this.mailBodyTemplate,
    this.iban,
    this.bic,
    this.defaultDocType,
    required this.defaultTagIds,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['aliases'] = Variable<String>(aliases);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || fax != null) {
      map['fax'] = Variable<String>(fax);
    }
    if (!nullToAbsent || postalAddress != null) {
      map['postal_address'] = Variable<String>(postalAddress);
    }
    if (!nullToAbsent || mailSubjectTemplate != null) {
      map['mail_subject_template'] = Variable<String>(mailSubjectTemplate);
    }
    if (!nullToAbsent || mailBodyTemplate != null) {
      map['mail_body_template'] = Variable<String>(mailBodyTemplate);
    }
    if (!nullToAbsent || iban != null) {
      map['iban'] = Variable<String>(iban);
    }
    if (!nullToAbsent || bic != null) {
      map['bic'] = Variable<String>(bic);
    }
    if (!nullToAbsent || defaultDocType != null) {
      map['default_doc_type'] = Variable<String>(defaultDocType);
    }
    map['default_tag_ids'] = Variable<String>(defaultTagIds);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CorrespondentsCompanion toCompanion(bool nullToAbsent) {
    return CorrespondentsCompanion(
      id: Value(id),
      name: Value(name),
      aliases: Value(aliases),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      fax: fax == null && nullToAbsent ? const Value.absent() : Value(fax),
      postalAddress: postalAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(postalAddress),
      mailSubjectTemplate: mailSubjectTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(mailSubjectTemplate),
      mailBodyTemplate: mailBodyTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(mailBodyTemplate),
      iban: iban == null && nullToAbsent ? const Value.absent() : Value(iban),
      bic: bic == null && nullToAbsent ? const Value.absent() : Value(bic),
      defaultDocType: defaultDocType == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultDocType),
      defaultTagIds: Value(defaultTagIds),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Correspondent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Correspondent(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      aliases: serializer.fromJson<String>(json['aliases']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      email: serializer.fromJson<String?>(json['email']),
      fax: serializer.fromJson<String?>(json['fax']),
      postalAddress: serializer.fromJson<String?>(json['postalAddress']),
      mailSubjectTemplate: serializer.fromJson<String?>(
        json['mailSubjectTemplate'],
      ),
      mailBodyTemplate: serializer.fromJson<String?>(json['mailBodyTemplate']),
      iban: serializer.fromJson<String?>(json['iban']),
      bic: serializer.fromJson<String?>(json['bic']),
      defaultDocType: serializer.fromJson<String?>(json['defaultDocType']),
      defaultTagIds: serializer.fromJson<String>(json['defaultTagIds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'aliases': serializer.toJson<String>(aliases),
      'categoryId': serializer.toJson<String?>(categoryId),
      'email': serializer.toJson<String?>(email),
      'fax': serializer.toJson<String?>(fax),
      'postalAddress': serializer.toJson<String?>(postalAddress),
      'mailSubjectTemplate': serializer.toJson<String?>(mailSubjectTemplate),
      'mailBodyTemplate': serializer.toJson<String?>(mailBodyTemplate),
      'iban': serializer.toJson<String?>(iban),
      'bic': serializer.toJson<String?>(bic),
      'defaultDocType': serializer.toJson<String?>(defaultDocType),
      'defaultTagIds': serializer.toJson<String>(defaultTagIds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Correspondent copyWith({
    String? id,
    String? name,
    String? aliases,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> fax = const Value.absent(),
    Value<String?> postalAddress = const Value.absent(),
    Value<String?> mailSubjectTemplate = const Value.absent(),
    Value<String?> mailBodyTemplate = const Value.absent(),
    Value<String?> iban = const Value.absent(),
    Value<String?> bic = const Value.absent(),
    Value<String?> defaultDocType = const Value.absent(),
    String? defaultTagIds,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Correspondent(
    id: id ?? this.id,
    name: name ?? this.name,
    aliases: aliases ?? this.aliases,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    email: email.present ? email.value : this.email,
    fax: fax.present ? fax.value : this.fax,
    postalAddress: postalAddress.present
        ? postalAddress.value
        : this.postalAddress,
    mailSubjectTemplate: mailSubjectTemplate.present
        ? mailSubjectTemplate.value
        : this.mailSubjectTemplate,
    mailBodyTemplate: mailBodyTemplate.present
        ? mailBodyTemplate.value
        : this.mailBodyTemplate,
    iban: iban.present ? iban.value : this.iban,
    bic: bic.present ? bic.value : this.bic,
    defaultDocType: defaultDocType.present
        ? defaultDocType.value
        : this.defaultDocType,
    defaultTagIds: defaultTagIds ?? this.defaultTagIds,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Correspondent copyWithCompanion(CorrespondentsCompanion data) {
    return Correspondent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      email: data.email.present ? data.email.value : this.email,
      fax: data.fax.present ? data.fax.value : this.fax,
      postalAddress: data.postalAddress.present
          ? data.postalAddress.value
          : this.postalAddress,
      mailSubjectTemplate: data.mailSubjectTemplate.present
          ? data.mailSubjectTemplate.value
          : this.mailSubjectTemplate,
      mailBodyTemplate: data.mailBodyTemplate.present
          ? data.mailBodyTemplate.value
          : this.mailBodyTemplate,
      iban: data.iban.present ? data.iban.value : this.iban,
      bic: data.bic.present ? data.bic.value : this.bic,
      defaultDocType: data.defaultDocType.present
          ? data.defaultDocType.value
          : this.defaultDocType,
      defaultTagIds: data.defaultTagIds.present
          ? data.defaultTagIds.value
          : this.defaultTagIds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Correspondent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('categoryId: $categoryId, ')
          ..write('email: $email, ')
          ..write('fax: $fax, ')
          ..write('postalAddress: $postalAddress, ')
          ..write('mailSubjectTemplate: $mailSubjectTemplate, ')
          ..write('mailBodyTemplate: $mailBodyTemplate, ')
          ..write('iban: $iban, ')
          ..write('bic: $bic, ')
          ..write('defaultDocType: $defaultDocType, ')
          ..write('defaultTagIds: $defaultTagIds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    aliases,
    categoryId,
    email,
    fax,
    postalAddress,
    mailSubjectTemplate,
    mailBodyTemplate,
    iban,
    bic,
    defaultDocType,
    defaultTagIds,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Correspondent &&
          other.id == this.id &&
          other.name == this.name &&
          other.aliases == this.aliases &&
          other.categoryId == this.categoryId &&
          other.email == this.email &&
          other.fax == this.fax &&
          other.postalAddress == this.postalAddress &&
          other.mailSubjectTemplate == this.mailSubjectTemplate &&
          other.mailBodyTemplate == this.mailBodyTemplate &&
          other.iban == this.iban &&
          other.bic == this.bic &&
          other.defaultDocType == this.defaultDocType &&
          other.defaultTagIds == this.defaultTagIds &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CorrespondentsCompanion extends UpdateCompanion<Correspondent> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> aliases;
  final Value<String?> categoryId;
  final Value<String?> email;
  final Value<String?> fax;
  final Value<String?> postalAddress;
  final Value<String?> mailSubjectTemplate;
  final Value<String?> mailBodyTemplate;
  final Value<String?> iban;
  final Value<String?> bic;
  final Value<String?> defaultDocType;
  final Value<String> defaultTagIds;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CorrespondentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.aliases = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.email = const Value.absent(),
    this.fax = const Value.absent(),
    this.postalAddress = const Value.absent(),
    this.mailSubjectTemplate = const Value.absent(),
    this.mailBodyTemplate = const Value.absent(),
    this.iban = const Value.absent(),
    this.bic = const Value.absent(),
    this.defaultDocType = const Value.absent(),
    this.defaultTagIds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CorrespondentsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.aliases = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.email = const Value.absent(),
    this.fax = const Value.absent(),
    this.postalAddress = const Value.absent(),
    this.mailSubjectTemplate = const Value.absent(),
    this.mailBodyTemplate = const Value.absent(),
    this.iban = const Value.absent(),
    this.bic = const Value.absent(),
    this.defaultDocType = const Value.absent(),
    this.defaultTagIds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Correspondent> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? aliases,
    Expression<String>? categoryId,
    Expression<String>? email,
    Expression<String>? fax,
    Expression<String>? postalAddress,
    Expression<String>? mailSubjectTemplate,
    Expression<String>? mailBodyTemplate,
    Expression<String>? iban,
    Expression<String>? bic,
    Expression<String>? defaultDocType,
    Expression<String>? defaultTagIds,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (aliases != null) 'aliases': aliases,
      if (categoryId != null) 'category_id': categoryId,
      if (email != null) 'email': email,
      if (fax != null) 'fax': fax,
      if (postalAddress != null) 'postal_address': postalAddress,
      if (mailSubjectTemplate != null)
        'mail_subject_template': mailSubjectTemplate,
      if (mailBodyTemplate != null) 'mail_body_template': mailBodyTemplate,
      if (iban != null) 'iban': iban,
      if (bic != null) 'bic': bic,
      if (defaultDocType != null) 'default_doc_type': defaultDocType,
      if (defaultTagIds != null) 'default_tag_ids': defaultTagIds,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CorrespondentsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? aliases,
    Value<String?>? categoryId,
    Value<String?>? email,
    Value<String?>? fax,
    Value<String?>? postalAddress,
    Value<String?>? mailSubjectTemplate,
    Value<String?>? mailBodyTemplate,
    Value<String?>? iban,
    Value<String?>? bic,
    Value<String?>? defaultDocType,
    Value<String>? defaultTagIds,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CorrespondentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      categoryId: categoryId ?? this.categoryId,
      email: email ?? this.email,
      fax: fax ?? this.fax,
      postalAddress: postalAddress ?? this.postalAddress,
      mailSubjectTemplate: mailSubjectTemplate ?? this.mailSubjectTemplate,
      mailBodyTemplate: mailBodyTemplate ?? this.mailBodyTemplate,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      defaultDocType: defaultDocType ?? this.defaultDocType,
      defaultTagIds: defaultTagIds ?? this.defaultTagIds,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (fax.present) {
      map['fax'] = Variable<String>(fax.value);
    }
    if (postalAddress.present) {
      map['postal_address'] = Variable<String>(postalAddress.value);
    }
    if (mailSubjectTemplate.present) {
      map['mail_subject_template'] = Variable<String>(
        mailSubjectTemplate.value,
      );
    }
    if (mailBodyTemplate.present) {
      map['mail_body_template'] = Variable<String>(mailBodyTemplate.value);
    }
    if (iban.present) {
      map['iban'] = Variable<String>(iban.value);
    }
    if (bic.present) {
      map['bic'] = Variable<String>(bic.value);
    }
    if (defaultDocType.present) {
      map['default_doc_type'] = Variable<String>(defaultDocType.value);
    }
    if (defaultTagIds.present) {
      map['default_tag_ids'] = Variable<String>(defaultTagIds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CorrespondentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('categoryId: $categoryId, ')
          ..write('email: $email, ')
          ..write('fax: $fax, ')
          ..write('postalAddress: $postalAddress, ')
          ..write('mailSubjectTemplate: $mailSubjectTemplate, ')
          ..write('mailBodyTemplate: $mailBodyTemplate, ')
          ..write('iban: $iban, ')
          ..write('bic: $bic, ')
          ..write('defaultDocType: $defaultDocType, ')
          ..write('defaultTagIds: $defaultTagIds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF607D8B),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final int color;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    int? color,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentTagsTable extends DocumentTags
    with TableInfo<$DocumentTagsTable, DocumentTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [documentId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, tagId};
  @override
  DocumentTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentTag(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $DocumentTagsTable createAlias(String alias) {
    return $DocumentTagsTable(attachedDatabase, alias);
  }
}

class DocumentTag extends DataClass implements Insertable<DocumentTag> {
  final String documentId;
  final String tagId;
  const DocumentTag({required this.documentId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  DocumentTagsCompanion toCompanion(bool nullToAbsent) {
    return DocumentTagsCompanion(
      documentId: Value(documentId),
      tagId: Value(tagId),
    );
  }

  factory DocumentTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentTag(
      documentId: serializer.fromJson<String>(json['documentId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  DocumentTag copyWith({String? documentId, String? tagId}) => DocumentTag(
    documentId: documentId ?? this.documentId,
    tagId: tagId ?? this.tagId,
  );
  DocumentTag copyWithCompanion(DocumentTagsCompanion data) {
    return DocumentTag(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentTag(')
          ..write('documentId: $documentId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentTag &&
          other.documentId == this.documentId &&
          other.tagId == this.tagId);
}

class DocumentTagsCompanion extends UpdateCompanion<DocumentTag> {
  final Value<String> documentId;
  final Value<String> tagId;
  final Value<int> rowid;
  const DocumentTagsCompanion({
    this.documentId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentTagsCompanion.insert({
    required String documentId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       tagId = Value(tagId);
  static Insertable<DocumentTag> custom({
    Expression<String>? documentId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentTagsCompanion copyWith({
    Value<String>? documentId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return DocumentTagsCompanion(
      documentId: documentId ?? this.documentId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentTagsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExtractedRefsTable extends ExtractedRefs
    with TableInfo<$ExtractedRefsTable, ExtractedRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractedRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [documentId, kind, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extracted_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractedRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, kind, value};
  @override
  ExtractedRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractedRef(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ExtractedRefsTable createAlias(String alias) {
    return $ExtractedRefsTable(attachedDatabase, alias);
  }
}

class ExtractedRef extends DataClass implements Insertable<ExtractedRef> {
  final String documentId;

  /// Art der Referenz: IBAN, VSNR, KDNR, RGNR, STNR, AZ …
  final String kind;
  final String value;
  const ExtractedRef({
    required this.documentId,
    required this.kind,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['kind'] = Variable<String>(kind);
    map['value'] = Variable<String>(value);
    return map;
  }

  ExtractedRefsCompanion toCompanion(bool nullToAbsent) {
    return ExtractedRefsCompanion(
      documentId: Value(documentId),
      kind: Value(kind),
      value: Value(value),
    );
  }

  factory ExtractedRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractedRef(
      documentId: serializer.fromJson<String>(json['documentId']),
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<String>(value),
    };
  }

  ExtractedRef copyWith({String? documentId, String? kind, String? value}) =>
      ExtractedRef(
        documentId: documentId ?? this.documentId,
        kind: kind ?? this.kind,
        value: value ?? this.value,
      );
  ExtractedRef copyWithCompanion(ExtractedRefsCompanion data) {
    return ExtractedRef(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractedRef(')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, kind, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractedRef &&
          other.documentId == this.documentId &&
          other.kind == this.kind &&
          other.value == this.value);
}

class ExtractedRefsCompanion extends UpdateCompanion<ExtractedRef> {
  final Value<String> documentId;
  final Value<String> kind;
  final Value<String> value;
  final Value<int> rowid;
  const ExtractedRefsCompanion({
    this.documentId = const Value.absent(),
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExtractedRefsCompanion.insert({
    required String documentId,
    required String kind,
    required String value,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       kind = Value(kind),
       value = Value(value);
  static Insertable<ExtractedRef> custom({
    Expression<String>? documentId,
    Expression<String>? kind,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExtractedRefsCompanion copyWith({
    Value<String>? documentId,
    Value<String>? kind,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ExtractedRefsCompanion(
      documentId: documentId ?? this.documentId,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractedRefsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CountersTable extends Counters with TableInfo<$CountersTable, Counter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastNumberMeta = const VerificationMeta(
    'lastNumber',
  );
  @override
  late final GeneratedColumn<int> lastNumber = GeneratedColumn<int>(
    'last_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [year, lastNumber];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Counter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('last_number')) {
      context.handle(
        _lastNumberMeta,
        lastNumber.isAcceptableOrUnknown(data['last_number']!, _lastNumberMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {year};
  @override
  Counter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Counter(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      lastNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_number'],
      )!,
    );
  }

  @override
  $CountersTable createAlias(String alias) {
    return $CountersTable(attachedDatabase, alias);
  }
}

class Counter extends DataClass implements Insertable<Counter> {
  final int year;
  final int lastNumber;
  const Counter({required this.year, required this.lastNumber});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['last_number'] = Variable<int>(lastNumber);
    return map;
  }

  CountersCompanion toCompanion(bool nullToAbsent) {
    return CountersCompanion(year: Value(year), lastNumber: Value(lastNumber));
  }

  factory Counter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Counter(
      year: serializer.fromJson<int>(json['year']),
      lastNumber: serializer.fromJson<int>(json['lastNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'lastNumber': serializer.toJson<int>(lastNumber),
    };
  }

  Counter copyWith({int? year, int? lastNumber}) => Counter(
    year: year ?? this.year,
    lastNumber: lastNumber ?? this.lastNumber,
  );
  Counter copyWithCompanion(CountersCompanion data) {
    return Counter(
      year: data.year.present ? data.year.value : this.year,
      lastNumber: data.lastNumber.present
          ? data.lastNumber.value
          : this.lastNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Counter(')
          ..write('year: $year, ')
          ..write('lastNumber: $lastNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(year, lastNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Counter &&
          other.year == this.year &&
          other.lastNumber == this.lastNumber);
}

class CountersCompanion extends UpdateCompanion<Counter> {
  final Value<int> year;
  final Value<int> lastNumber;
  const CountersCompanion({
    this.year = const Value.absent(),
    this.lastNumber = const Value.absent(),
  });
  CountersCompanion.insert({
    this.year = const Value.absent(),
    this.lastNumber = const Value.absent(),
  });
  static Insertable<Counter> custom({
    Expression<int>? year,
    Expression<int>? lastNumber,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (lastNumber != null) 'last_number': lastNumber,
    });
  }

  CountersCompanion copyWith({Value<int>? year, Value<int>? lastNumber}) {
    return CountersCompanion(
      year: year ?? this.year,
      lastNumber: lastNumber ?? this.lastNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (lastNumber.present) {
      map['last_number'] = Variable<int>(lastNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountersCompanion(')
          ..write('year: $year, ')
          ..write('lastNumber: $lastNumber')
          ..write(')'))
        .toString();
  }
}

class $ClaimsTable extends Claims with TableInfo<$ClaimsTable, Claim> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reimbursedCentsMeta = const VerificationMeta(
    'reimbursedCents',
  );
  @override
  late final GeneratedColumn<int> reimbursedCents = GeneratedColumn<int>(
    'reimbursed_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _settledAtMeta = const VerificationMeta(
    'settledAt',
  );
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
    'settled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpAtMeta = const VerificationMeta(
    'followUpAt',
  );
  @override
  late final GeneratedColumn<DateTime> followUpAt = GeneratedColumn<DateTime>(
    'follow_up_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    target,
    status,
    submittedAt,
    reimbursedCents,
    settledAt,
    followUpAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claims';
  @override
  VerificationContext validateIntegrity(
    Insertable<Claim> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    }
    if (data.containsKey('reimbursed_cents')) {
      context.handle(
        _reimbursedCentsMeta,
        reimbursedCents.isAcceptableOrUnknown(
          data['reimbursed_cents']!,
          _reimbursedCentsMeta,
        ),
      );
    }
    if (data.containsKey('settled_at')) {
      context.handle(
        _settledAtMeta,
        settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta),
      );
    }
    if (data.containsKey('follow_up_at')) {
      context.handle(
        _followUpAtMeta,
        followUpAt.isAcceptableOrUnknown(
          data['follow_up_at']!,
          _followUpAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Claim map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Claim(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}submitted_at'],
      ),
      reimbursedCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reimbursed_cents'],
      ),
      settledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}settled_at'],
      ),
      followUpAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}follow_up_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ClaimsTable createAlias(String alias) {
    return $ClaimsTable(attachedDatabase, alias);
  }
}

class Claim extends DataClass implements Insertable<Claim> {
  final String id;
  final String documentId;
  final String target;

  /// Siehe `ClaimStatus`.
  final String status;
  final DateTime? submittedAt;

  /// Erstatteter Betrag in Cent.
  final int? reimbursedCents;
  final DateTime? settledAt;

  /// Nachfassen, falls die Erstattung ausbleibt.
  final DateTime? followUpAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Claim({
    required this.id,
    required this.documentId,
    required this.target,
    required this.status,
    this.submittedAt,
    this.reimbursedCents,
    this.settledAt,
    this.followUpAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['target'] = Variable<String>(target);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    if (!nullToAbsent || reimbursedCents != null) {
      map['reimbursed_cents'] = Variable<int>(reimbursedCents);
    }
    if (!nullToAbsent || settledAt != null) {
      map['settled_at'] = Variable<DateTime>(settledAt);
    }
    if (!nullToAbsent || followUpAt != null) {
      map['follow_up_at'] = Variable<DateTime>(followUpAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ClaimsCompanion toCompanion(bool nullToAbsent) {
    return ClaimsCompanion(
      id: Value(id),
      documentId: Value(documentId),
      target: Value(target),
      status: Value(status),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      reimbursedCents: reimbursedCents == null && nullToAbsent
          ? const Value.absent()
          : Value(reimbursedCents),
      settledAt: settledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(settledAt),
      followUpAt: followUpAt == null && nullToAbsent
          ? const Value.absent()
          : Value(followUpAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Claim.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Claim(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      target: serializer.fromJson<String>(json['target']),
      status: serializer.fromJson<String>(json['status']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      reimbursedCents: serializer.fromJson<int?>(json['reimbursedCents']),
      settledAt: serializer.fromJson<DateTime?>(json['settledAt']),
      followUpAt: serializer.fromJson<DateTime?>(json['followUpAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'target': serializer.toJson<String>(target),
      'status': serializer.toJson<String>(status),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'reimbursedCents': serializer.toJson<int?>(reimbursedCents),
      'settledAt': serializer.toJson<DateTime?>(settledAt),
      'followUpAt': serializer.toJson<DateTime?>(followUpAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Claim copyWith({
    String? id,
    String? documentId,
    String? target,
    String? status,
    Value<DateTime?> submittedAt = const Value.absent(),
    Value<int?> reimbursedCents = const Value.absent(),
    Value<DateTime?> settledAt = const Value.absent(),
    Value<DateTime?> followUpAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Claim(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    target: target ?? this.target,
    status: status ?? this.status,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    reimbursedCents: reimbursedCents.present
        ? reimbursedCents.value
        : this.reimbursedCents,
    settledAt: settledAt.present ? settledAt.value : this.settledAt,
    followUpAt: followUpAt.present ? followUpAt.value : this.followUpAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Claim copyWithCompanion(ClaimsCompanion data) {
    return Claim(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      target: data.target.present ? data.target.value : this.target,
      status: data.status.present ? data.status.value : this.status,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      reimbursedCents: data.reimbursedCents.present
          ? data.reimbursedCents.value
          : this.reimbursedCents,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
      followUpAt: data.followUpAt.present
          ? data.followUpAt.value
          : this.followUpAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Claim(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('target: $target, ')
          ..write('status: $status, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('reimbursedCents: $reimbursedCents, ')
          ..write('settledAt: $settledAt, ')
          ..write('followUpAt: $followUpAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    target,
    status,
    submittedAt,
    reimbursedCents,
    settledAt,
    followUpAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Claim &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.target == this.target &&
          other.status == this.status &&
          other.submittedAt == this.submittedAt &&
          other.reimbursedCents == this.reimbursedCents &&
          other.settledAt == this.settledAt &&
          other.followUpAt == this.followUpAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ClaimsCompanion extends UpdateCompanion<Claim> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> target;
  final Value<String> status;
  final Value<DateTime?> submittedAt;
  final Value<int?> reimbursedCents;
  final Value<DateTime?> settledAt;
  final Value<DateTime?> followUpAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ClaimsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.target = const Value.absent(),
    this.status = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.reimbursedCents = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.followUpAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimsCompanion.insert({
    this.id = const Value.absent(),
    required String documentId,
    required String target,
    required String status,
    this.submittedAt = const Value.absent(),
    this.reimbursedCents = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.followUpAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       target = Value(target),
       status = Value(status);
  static Insertable<Claim> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? target,
    Expression<String>? status,
    Expression<DateTime>? submittedAt,
    Expression<int>? reimbursedCents,
    Expression<DateTime>? settledAt,
    Expression<DateTime>? followUpAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (target != null) 'target': target,
      if (status != null) 'status': status,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (reimbursedCents != null) 'reimbursed_cents': reimbursedCents,
      if (settledAt != null) 'settled_at': settledAt,
      if (followUpAt != null) 'follow_up_at': followUpAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimsCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? target,
    Value<String>? status,
    Value<DateTime?>? submittedAt,
    Value<int?>? reimbursedCents,
    Value<DateTime?>? settledAt,
    Value<DateTime?>? followUpAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ClaimsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      target: target ?? this.target,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reimbursedCents: reimbursedCents ?? this.reimbursedCents,
      settledAt: settledAt ?? this.settledAt,
      followUpAt: followUpAt ?? this.followUpAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (reimbursedCents.present) {
      map['reimbursed_cents'] = Variable<int>(reimbursedCents.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (followUpAt.present) {
      map['follow_up_at'] = Variable<DateTime>(followUpAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaimsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('target: $target, ')
          ..write('status: $status, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('reimbursedCents: $reimbursedCents, ')
          ..write('settledAt: $settledAt, ')
          ..write('followUpAt: $followUpAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Category({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SignatureTemplatesTable extends SignatureTemplates
    with TableInfo<$SignatureTemplatesTable, SignatureTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignatureTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aspectMeta = const VerificationMeta('aspect');
  @override
  late final GeneratedColumn<double> aspect = GeneratedColumn<double>(
    'aspect',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.35),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    imagePath,
    aspect,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signature_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignatureTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('aspect')) {
      context.handle(
        _aspectMeta,
        aspect.isAcceptableOrUnknown(data['aspect']!, _aspectMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SignatureTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignatureTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      aspect: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aspect'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SignatureTemplatesTable createAlias(String alias) {
    return $SignatureTemplatesTable(attachedDatabase, alias);
  }
}

class SignatureTemplate extends DataClass
    implements Insertable<SignatureTemplate> {
  final String id;
  final String name;

  /// Pfad der PNG relativ zum App-Verzeichnis.
  final String imagePath;

  /// Höhe / Breite des Bildes.
  final double aspect;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SignatureTemplate({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.aspect,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['image_path'] = Variable<String>(imagePath);
    map['aspect'] = Variable<double>(aspect);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SignatureTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SignatureTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      imagePath: Value(imagePath),
      aspect: Value(aspect),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SignatureTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignatureTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      aspect: serializer.fromJson<double>(json['aspect']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'imagePath': serializer.toJson<String>(imagePath),
      'aspect': serializer.toJson<double>(aspect),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SignatureTemplate copyWith({
    String? id,
    String? name,
    String? imagePath,
    double? aspect,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SignatureTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    imagePath: imagePath ?? this.imagePath,
    aspect: aspect ?? this.aspect,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SignatureTemplate copyWithCompanion(SignatureTemplatesCompanion data) {
    return SignatureTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      aspect: data.aspect.present ? data.aspect.value : this.aspect,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignatureTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imagePath: $imagePath, ')
          ..write('aspect: $aspect, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, imagePath, aspect, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignatureTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.imagePath == this.imagePath &&
          other.aspect == this.aspect &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SignatureTemplatesCompanion extends UpdateCompanion<SignatureTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> imagePath;
  final Value<double> aspect;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SignatureTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.aspect = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SignatureTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String imagePath,
    this.aspect = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       imagePath = Value(imagePath);
  static Insertable<SignatureTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? imagePath,
    Expression<double>? aspect,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (imagePath != null) 'image_path': imagePath,
      if (aspect != null) 'aspect': aspect,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SignatureTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? imagePath,
    Value<double>? aspect,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SignatureTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      aspect: aspect ?? this.aspect,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (aspect.present) {
      map['aspect'] = Variable<double>(aspect.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignatureTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imagePath: $imagePath, ')
          ..write('aspect: $aspect, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocTasksTable extends DocTasks with TableInfo<$DocTasksTable, DocTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<DateTime> doneAt = GeneratedColumn<DateTime>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    action,
    note,
    dueAt,
    repeat,
    origin,
    doneAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'doc_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}done_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DocTasksTable createAlias(String alias) {
    return $DocTasksTable(attachedDatabase, alias);
  }
}

class DocTask extends DataClass implements Insertable<DocTask> {
  final String id;
  final String documentId;

  /// Siehe `TaskAction` (lib/data/tasks.dart), z. B. `versenden`.
  final String action;

  /// Was genau zu tun ist, z. B. „an Beihilfestelle per Mail“.
  final String note;
  final DateTime dueAt;

  /// '' (einmalig), `monatlich`, `vierteljaehrlich`, `jaehrlich`.
  final String repeat;

  /// Automatisch erzeugt? z. B. `widerspruch`, `garantie`,
  /// `kuendigung:<contractId>` (Schema v6).
  final String? origin;
  final DateTime? doneAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const DocTask({
    required this.id,
    required this.documentId,
    required this.action,
    required this.note,
    required this.dueAt,
    required this.repeat,
    this.origin,
    this.doneAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['action'] = Variable<String>(action);
    map['note'] = Variable<String>(note);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['repeat'] = Variable<String>(repeat);
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<DateTime>(doneAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DocTasksCompanion toCompanion(bool nullToAbsent) {
    return DocTasksCompanion(
      id: Value(id),
      documentId: Value(documentId),
      action: Value(action),
      note: Value(note),
      dueAt: Value(dueAt),
      repeat: Value(repeat),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DocTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocTask(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      action: serializer.fromJson<String>(json['action']),
      note: serializer.fromJson<String>(json['note']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      repeat: serializer.fromJson<String>(json['repeat']),
      origin: serializer.fromJson<String?>(json['origin']),
      doneAt: serializer.fromJson<DateTime?>(json['doneAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'action': serializer.toJson<String>(action),
      'note': serializer.toJson<String>(note),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'repeat': serializer.toJson<String>(repeat),
      'origin': serializer.toJson<String?>(origin),
      'doneAt': serializer.toJson<DateTime?>(doneAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DocTask copyWith({
    String? id,
    String? documentId,
    String? action,
    String? note,
    DateTime? dueAt,
    String? repeat,
    Value<String?> origin = const Value.absent(),
    Value<DateTime?> doneAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => DocTask(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    action: action ?? this.action,
    note: note ?? this.note,
    dueAt: dueAt ?? this.dueAt,
    repeat: repeat ?? this.repeat,
    origin: origin.present ? origin.value : this.origin,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DocTask copyWithCompanion(DocTasksCompanion data) {
    return DocTask(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      action: data.action.present ? data.action.value : this.action,
      note: data.note.present ? data.note.value : this.note,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      origin: data.origin.present ? data.origin.value : this.origin,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocTask(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('action: $action, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('repeat: $repeat, ')
          ..write('origin: $origin, ')
          ..write('doneAt: $doneAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    action,
    note,
    dueAt,
    repeat,
    origin,
    doneAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocTask &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.action == this.action &&
          other.note == this.note &&
          other.dueAt == this.dueAt &&
          other.repeat == this.repeat &&
          other.origin == this.origin &&
          other.doneAt == this.doneAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DocTasksCompanion extends UpdateCompanion<DocTask> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> action;
  final Value<String> note;
  final Value<DateTime> dueAt;
  final Value<String> repeat;
  final Value<String?> origin;
  final Value<DateTime?> doneAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DocTasksCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.action = const Value.absent(),
    this.note = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.repeat = const Value.absent(),
    this.origin = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocTasksCompanion.insert({
    this.id = const Value.absent(),
    required String documentId,
    required String action,
    this.note = const Value.absent(),
    required DateTime dueAt,
    this.repeat = const Value.absent(),
    this.origin = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       action = Value(action),
       dueAt = Value(dueAt);
  static Insertable<DocTask> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? action,
    Expression<String>? note,
    Expression<DateTime>? dueAt,
    Expression<String>? repeat,
    Expression<String>? origin,
    Expression<DateTime>? doneAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (action != null) 'action': action,
      if (note != null) 'note': note,
      if (dueAt != null) 'due_at': dueAt,
      if (repeat != null) 'repeat': repeat,
      if (origin != null) 'origin': origin,
      if (doneAt != null) 'done_at': doneAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? action,
    Value<String>? note,
    Value<DateTime>? dueAt,
    Value<String>? repeat,
    Value<String?>? origin,
    Value<DateTime?>? doneAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DocTasksCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      action: action ?? this.action,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      repeat: repeat ?? this.repeat,
      origin: origin ?? this.origin,
      doneAt: doneAt ?? this.doneAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<DateTime>(doneAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocTasksCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('action: $action, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('repeat: $repeat, ')
          ..write('origin: $origin, ')
          ..write('doneAt: $doneAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CasesTable extends Cases with TableInfo<$CasesTable, Case> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('offen'),
  );
  static const VerificationMeta _correspondentIdMeta = const VerificationMeta(
    'correspondentId',
  );
  @override
  late final GeneratedColumn<String> correspondentId = GeneratedColumn<String>(
    'correspondent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refKindMeta = const VerificationMeta(
    'refKind',
  );
  @override
  late final GeneratedColumn<String> refKind = GeneratedColumn<String>(
    'ref_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refValueMeta = const VerificationMeta(
    'refValue',
  );
  @override
  late final GeneratedColumn<String> refValue = GeneratedColumn<String>(
    'ref_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    status,
    correspondentId,
    refKind,
    refValue,
    note,
    closedAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Case> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('correspondent_id')) {
      context.handle(
        _correspondentIdMeta,
        correspondentId.isAcceptableOrUnknown(
          data['correspondent_id']!,
          _correspondentIdMeta,
        ),
      );
    }
    if (data.containsKey('ref_kind')) {
      context.handle(
        _refKindMeta,
        refKind.isAcceptableOrUnknown(data['ref_kind']!, _refKindMeta),
      );
    }
    if (data.containsKey('ref_value')) {
      context.handle(
        _refValueMeta,
        refValue.isAcceptableOrUnknown(data['ref_value']!, _refValueMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Case map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Case(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      correspondentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correspondent_id'],
      ),
      refKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_kind'],
      ),
      refValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_value'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CasesTable createAlias(String alias) {
    return $CasesTable(attachedDatabase, alias);
  }
}

class Case extends DataClass implements Insertable<Case> {
  final String id;
  final String title;

  /// `offen`, `wartet`, `erledigt`.
  final String status;
  final String? correspondentId;
  final String? refKind;
  final String? refValue;
  final String note;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Case({
    required this.id,
    required this.title,
    required this.status,
    this.correspondentId,
    this.refKind,
    this.refValue,
    required this.note,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || correspondentId != null) {
      map['correspondent_id'] = Variable<String>(correspondentId);
    }
    if (!nullToAbsent || refKind != null) {
      map['ref_kind'] = Variable<String>(refKind);
    }
    if (!nullToAbsent || refValue != null) {
      map['ref_value'] = Variable<String>(refValue);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CasesCompanion toCompanion(bool nullToAbsent) {
    return CasesCompanion(
      id: Value(id),
      title: Value(title),
      status: Value(status),
      correspondentId: correspondentId == null && nullToAbsent
          ? const Value.absent()
          : Value(correspondentId),
      refKind: refKind == null && nullToAbsent
          ? const Value.absent()
          : Value(refKind),
      refValue: refValue == null && nullToAbsent
          ? const Value.absent()
          : Value(refValue),
      note: Value(note),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Case.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Case(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      correspondentId: serializer.fromJson<String?>(json['correspondentId']),
      refKind: serializer.fromJson<String?>(json['refKind']),
      refValue: serializer.fromJson<String?>(json['refValue']),
      note: serializer.fromJson<String>(json['note']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'correspondentId': serializer.toJson<String?>(correspondentId),
      'refKind': serializer.toJson<String?>(refKind),
      'refValue': serializer.toJson<String?>(refValue),
      'note': serializer.toJson<String>(note),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Case copyWith({
    String? id,
    String? title,
    String? status,
    Value<String?> correspondentId = const Value.absent(),
    Value<String?> refKind = const Value.absent(),
    Value<String?> refValue = const Value.absent(),
    String? note,
    Value<DateTime?> closedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Case(
    id: id ?? this.id,
    title: title ?? this.title,
    status: status ?? this.status,
    correspondentId: correspondentId.present
        ? correspondentId.value
        : this.correspondentId,
    refKind: refKind.present ? refKind.value : this.refKind,
    refValue: refValue.present ? refValue.value : this.refValue,
    note: note ?? this.note,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Case copyWithCompanion(CasesCompanion data) {
    return Case(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      correspondentId: data.correspondentId.present
          ? data.correspondentId.value
          : this.correspondentId,
      refKind: data.refKind.present ? data.refKind.value : this.refKind,
      refValue: data.refValue.present ? data.refValue.value : this.refValue,
      note: data.note.present ? data.note.value : this.note,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Case(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('refKind: $refKind, ')
          ..write('refValue: $refValue, ')
          ..write('note: $note, ')
          ..write('closedAt: $closedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    status,
    correspondentId,
    refKind,
    refValue,
    note,
    closedAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Case &&
          other.id == this.id &&
          other.title == this.title &&
          other.status == this.status &&
          other.correspondentId == this.correspondentId &&
          other.refKind == this.refKind &&
          other.refValue == this.refValue &&
          other.note == this.note &&
          other.closedAt == this.closedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CasesCompanion extends UpdateCompanion<Case> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> status;
  final Value<String?> correspondentId;
  final Value<String?> refKind;
  final Value<String?> refValue;
  final Value<String> note;
  final Value<DateTime?> closedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CasesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.correspondentId = const Value.absent(),
    this.refKind = const Value.absent(),
    this.refValue = const Value.absent(),
    this.note = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CasesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.status = const Value.absent(),
    this.correspondentId = const Value.absent(),
    this.refKind = const Value.absent(),
    this.refValue = const Value.absent(),
    this.note = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Case> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? status,
    Expression<String>? correspondentId,
    Expression<String>? refKind,
    Expression<String>? refValue,
    Expression<String>? note,
    Expression<DateTime>? closedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (correspondentId != null) 'correspondent_id': correspondentId,
      if (refKind != null) 'ref_kind': refKind,
      if (refValue != null) 'ref_value': refValue,
      if (note != null) 'note': note,
      if (closedAt != null) 'closed_at': closedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CasesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? status,
    Value<String?>? correspondentId,
    Value<String?>? refKind,
    Value<String?>? refValue,
    Value<String>? note,
    Value<DateTime?>? closedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CasesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      correspondentId: correspondentId ?? this.correspondentId,
      refKind: refKind ?? this.refKind,
      refValue: refValue ?? this.refValue,
      note: note ?? this.note,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (correspondentId.present) {
      map['correspondent_id'] = Variable<String>(correspondentId.value);
    }
    if (refKind.present) {
      map['ref_kind'] = Variable<String>(refKind.value);
    }
    if (refValue.present) {
      map['ref_value'] = Variable<String>(refValue.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CasesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('refKind: $refKind, ')
          ..write('refValue: $refValue, ')
          ..write('note: $note, ')
          ..write('closedAt: $closedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaseDocumentsTable extends CaseDocuments
    with TableInfo<$CaseDocumentsTable, CaseDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<String> caseId = GeneratedColumn<String>(
    'case_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sonstiges'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    caseId,
    documentId,
    role,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(
        _caseIdMeta,
        caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      caseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CaseDocumentsTable createAlias(String alias) {
    return $CaseDocumentsTable(attachedDatabase, alias);
  }
}

class CaseDocument extends DataClass implements Insertable<CaseDocument> {
  final String id;
  final String caseId;
  final String documentId;

  /// `antrag`, `rueckfrage`, `bescheid`, `widerspruch`, `sonstiges`.
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CaseDocument({
    required this.id,
    required this.caseId,
    required this.documentId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['case_id'] = Variable<String>(caseId);
    map['document_id'] = Variable<String>(documentId);
    map['role'] = Variable<String>(role);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CaseDocumentsCompanion toCompanion(bool nullToAbsent) {
    return CaseDocumentsCompanion(
      id: Value(id),
      caseId: Value(caseId),
      documentId: Value(documentId),
      role: Value(role),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CaseDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseDocument(
      id: serializer.fromJson<String>(json['id']),
      caseId: serializer.fromJson<String>(json['caseId']),
      documentId: serializer.fromJson<String>(json['documentId']),
      role: serializer.fromJson<String>(json['role']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'caseId': serializer.toJson<String>(caseId),
      'documentId': serializer.toJson<String>(documentId),
      'role': serializer.toJson<String>(role),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CaseDocument copyWith({
    String? id,
    String? caseId,
    String? documentId,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CaseDocument(
    id: id ?? this.id,
    caseId: caseId ?? this.caseId,
    documentId: documentId ?? this.documentId,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CaseDocument copyWithCompanion(CaseDocumentsCompanion data) {
    return CaseDocument(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      role: data.role.present ? data.role.value : this.role,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseDocument(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('documentId: $documentId, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    caseId,
    documentId,
    role,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseDocument &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.documentId == this.documentId &&
          other.role == this.role &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CaseDocumentsCompanion extends UpdateCompanion<CaseDocument> {
  final Value<String> id;
  final Value<String> caseId;
  final Value<String> documentId;
  final Value<String> role;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CaseDocumentsCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.role = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseDocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String caseId,
    required String documentId,
    this.role = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : caseId = Value(caseId),
       documentId = Value(documentId);
  static Insertable<CaseDocument> custom({
    Expression<String>? id,
    Expression<String>? caseId,
    Expression<String>? documentId,
    Expression<String>? role,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (documentId != null) 'document_id': documentId,
      if (role != null) 'role': role,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? caseId,
    Value<String>? documentId,
    Value<String>? role,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CaseDocumentsCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      documentId: documentId ?? this.documentId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<String>(caseId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('documentId: $documentId, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContractsTable extends Contracts
    with TableInfo<$ContractsTable, Contract> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContractsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correspondentIdMeta = const VerificationMeta(
    'correspondentId',
  );
  @override
  late final GeneratedColumn<String> correspondentId = GeneratedColumn<String>(
    'correspondent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<String> interval = GeneratedColumn<String>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('monatlich'),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minTermUntilMeta = const VerificationMeta(
    'minTermUntil',
  );
  @override
  late final GeneratedColumn<DateTime> minTermUntil = GeneratedColumn<DateTime>(
    'min_term_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noticeValueMeta = const VerificationMeta(
    'noticeValue',
  );
  @override
  late final GeneratedColumn<int> noticeValue = GeneratedColumn<int>(
    'notice_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noticeUnitMeta = const VerificationMeta(
    'noticeUnit',
  );
  @override
  late final GeneratedColumn<String> noticeUnit = GeneratedColumn<String>(
    'notice_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noticeToEndOfMeta = const VerificationMeta(
    'noticeToEndOf',
  );
  @override
  late final GeneratedColumn<String> noticeToEndOf = GeneratedColumn<String>(
    'notice_to_end_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoRenewMonthsMeta = const VerificationMeta(
    'autoRenewMonths',
  );
  @override
  late final GeneratedColumn<int> autoRenewMonths = GeneratedColumn<int>(
    'auto_renew_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cancelledAtMeta = const VerificationMeta(
    'cancelledAt',
  );
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
    'cancelled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    correspondentId,
    title,
    amountCents,
    interval,
    startDate,
    minTermUntil,
    noticeValue,
    noticeUnit,
    noticeToEndOf,
    autoRenewMonths,
    cancelledAt,
    endsAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contracts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contract> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('correspondent_id')) {
      context.handle(
        _correspondentIdMeta,
        correspondentId.isAcceptableOrUnknown(
          data['correspondent_id']!,
          _correspondentIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('min_term_until')) {
      context.handle(
        _minTermUntilMeta,
        minTermUntil.isAcceptableOrUnknown(
          data['min_term_until']!,
          _minTermUntilMeta,
        ),
      );
    }
    if (data.containsKey('notice_value')) {
      context.handle(
        _noticeValueMeta,
        noticeValue.isAcceptableOrUnknown(
          data['notice_value']!,
          _noticeValueMeta,
        ),
      );
    }
    if (data.containsKey('notice_unit')) {
      context.handle(
        _noticeUnitMeta,
        noticeUnit.isAcceptableOrUnknown(data['notice_unit']!, _noticeUnitMeta),
      );
    }
    if (data.containsKey('notice_to_end_of')) {
      context.handle(
        _noticeToEndOfMeta,
        noticeToEndOf.isAcceptableOrUnknown(
          data['notice_to_end_of']!,
          _noticeToEndOfMeta,
        ),
      );
    }
    if (data.containsKey('auto_renew_months')) {
      context.handle(
        _autoRenewMonthsMeta,
        autoRenewMonths.isAcceptableOrUnknown(
          data['auto_renew_months']!,
          _autoRenewMonthsMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
        _cancelledAtMeta,
        cancelledAt.isAcceptableOrUnknown(
          data['cancelled_at']!,
          _cancelledAtMeta,
        ),
      );
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Contract map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contract(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      correspondentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correspondent_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      ),
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interval'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      minTermUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}min_term_until'],
      ),
      noticeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notice_value'],
      ),
      noticeUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notice_unit'],
      ),
      noticeToEndOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notice_to_end_of'],
      ),
      autoRenewMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_renew_months'],
      ),
      cancelledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cancelled_at'],
      ),
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ContractsTable createAlias(String alias) {
    return $ContractsTable(attachedDatabase, alias);
  }
}

class Contract extends DataClass implements Insertable<Contract> {
  final String id;
  final String? documentId;
  final String? correspondentId;
  final String title;
  final int? amountCents;

  /// `monatlich`, `vierteljaehrlich`, `halbjaehrlich`, `jaehrlich`, `einmalig`.
  final String interval;
  final DateTime? startDate;
  final DateTime? minTermUntil;
  final int? noticeValue;

  /// `tage`, `wochen`, `monate`.
  final String? noticeUnit;

  /// `laufzeitende` oder `monatsende`.
  final String? noticeToEndOf;
  final int? autoRenewMonths;
  final DateTime? cancelledAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Contract({
    required this.id,
    this.documentId,
    this.correspondentId,
    required this.title,
    this.amountCents,
    required this.interval,
    this.startDate,
    this.minTermUntil,
    this.noticeValue,
    this.noticeUnit,
    this.noticeToEndOf,
    this.autoRenewMonths,
    this.cancelledAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    if (!nullToAbsent || correspondentId != null) {
      map['correspondent_id'] = Variable<String>(correspondentId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || amountCents != null) {
      map['amount_cents'] = Variable<int>(amountCents);
    }
    map['interval'] = Variable<String>(interval);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || minTermUntil != null) {
      map['min_term_until'] = Variable<DateTime>(minTermUntil);
    }
    if (!nullToAbsent || noticeValue != null) {
      map['notice_value'] = Variable<int>(noticeValue);
    }
    if (!nullToAbsent || noticeUnit != null) {
      map['notice_unit'] = Variable<String>(noticeUnit);
    }
    if (!nullToAbsent || noticeToEndOf != null) {
      map['notice_to_end_of'] = Variable<String>(noticeToEndOf);
    }
    if (!nullToAbsent || autoRenewMonths != null) {
      map['auto_renew_months'] = Variable<int>(autoRenewMonths);
    }
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ContractsCompanion toCompanion(bool nullToAbsent) {
    return ContractsCompanion(
      id: Value(id),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      correspondentId: correspondentId == null && nullToAbsent
          ? const Value.absent()
          : Value(correspondentId),
      title: Value(title),
      amountCents: amountCents == null && nullToAbsent
          ? const Value.absent()
          : Value(amountCents),
      interval: Value(interval),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      minTermUntil: minTermUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(minTermUntil),
      noticeValue: noticeValue == null && nullToAbsent
          ? const Value.absent()
          : Value(noticeValue),
      noticeUnit: noticeUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(noticeUnit),
      noticeToEndOf: noticeToEndOf == null && nullToAbsent
          ? const Value.absent()
          : Value(noticeToEndOf),
      autoRenewMonths: autoRenewMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(autoRenewMonths),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Contract.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contract(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      correspondentId: serializer.fromJson<String?>(json['correspondentId']),
      title: serializer.fromJson<String>(json['title']),
      amountCents: serializer.fromJson<int?>(json['amountCents']),
      interval: serializer.fromJson<String>(json['interval']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      minTermUntil: serializer.fromJson<DateTime?>(json['minTermUntil']),
      noticeValue: serializer.fromJson<int?>(json['noticeValue']),
      noticeUnit: serializer.fromJson<String?>(json['noticeUnit']),
      noticeToEndOf: serializer.fromJson<String?>(json['noticeToEndOf']),
      autoRenewMonths: serializer.fromJson<int?>(json['autoRenewMonths']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String?>(documentId),
      'correspondentId': serializer.toJson<String?>(correspondentId),
      'title': serializer.toJson<String>(title),
      'amountCents': serializer.toJson<int?>(amountCents),
      'interval': serializer.toJson<String>(interval),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'minTermUntil': serializer.toJson<DateTime?>(minTermUntil),
      'noticeValue': serializer.toJson<int?>(noticeValue),
      'noticeUnit': serializer.toJson<String?>(noticeUnit),
      'noticeToEndOf': serializer.toJson<String?>(noticeToEndOf),
      'autoRenewMonths': serializer.toJson<int?>(autoRenewMonths),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Contract copyWith({
    String? id,
    Value<String?> documentId = const Value.absent(),
    Value<String?> correspondentId = const Value.absent(),
    String? title,
    Value<int?> amountCents = const Value.absent(),
    String? interval,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> minTermUntil = const Value.absent(),
    Value<int?> noticeValue = const Value.absent(),
    Value<String?> noticeUnit = const Value.absent(),
    Value<String?> noticeToEndOf = const Value.absent(),
    Value<int?> autoRenewMonths = const Value.absent(),
    Value<DateTime?> cancelledAt = const Value.absent(),
    Value<DateTime?> endsAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Contract(
    id: id ?? this.id,
    documentId: documentId.present ? documentId.value : this.documentId,
    correspondentId: correspondentId.present
        ? correspondentId.value
        : this.correspondentId,
    title: title ?? this.title,
    amountCents: amountCents.present ? amountCents.value : this.amountCents,
    interval: interval ?? this.interval,
    startDate: startDate.present ? startDate.value : this.startDate,
    minTermUntil: minTermUntil.present ? minTermUntil.value : this.minTermUntil,
    noticeValue: noticeValue.present ? noticeValue.value : this.noticeValue,
    noticeUnit: noticeUnit.present ? noticeUnit.value : this.noticeUnit,
    noticeToEndOf: noticeToEndOf.present
        ? noticeToEndOf.value
        : this.noticeToEndOf,
    autoRenewMonths: autoRenewMonths.present
        ? autoRenewMonths.value
        : this.autoRenewMonths,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Contract copyWithCompanion(ContractsCompanion data) {
    return Contract(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      correspondentId: data.correspondentId.present
          ? data.correspondentId.value
          : this.correspondentId,
      title: data.title.present ? data.title.value : this.title,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      interval: data.interval.present ? data.interval.value : this.interval,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      minTermUntil: data.minTermUntil.present
          ? data.minTermUntil.value
          : this.minTermUntil,
      noticeValue: data.noticeValue.present
          ? data.noticeValue.value
          : this.noticeValue,
      noticeUnit: data.noticeUnit.present
          ? data.noticeUnit.value
          : this.noticeUnit,
      noticeToEndOf: data.noticeToEndOf.present
          ? data.noticeToEndOf.value
          : this.noticeToEndOf,
      autoRenewMonths: data.autoRenewMonths.present
          ? data.autoRenewMonths.value
          : this.autoRenewMonths,
      cancelledAt: data.cancelledAt.present
          ? data.cancelledAt.value
          : this.cancelledAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contract(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('title: $title, ')
          ..write('amountCents: $amountCents, ')
          ..write('interval: $interval, ')
          ..write('startDate: $startDate, ')
          ..write('minTermUntil: $minTermUntil, ')
          ..write('noticeValue: $noticeValue, ')
          ..write('noticeUnit: $noticeUnit, ')
          ..write('noticeToEndOf: $noticeToEndOf, ')
          ..write('autoRenewMonths: $autoRenewMonths, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    correspondentId,
    title,
    amountCents,
    interval,
    startDate,
    minTermUntil,
    noticeValue,
    noticeUnit,
    noticeToEndOf,
    autoRenewMonths,
    cancelledAt,
    endsAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contract &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.correspondentId == this.correspondentId &&
          other.title == this.title &&
          other.amountCents == this.amountCents &&
          other.interval == this.interval &&
          other.startDate == this.startDate &&
          other.minTermUntil == this.minTermUntil &&
          other.noticeValue == this.noticeValue &&
          other.noticeUnit == this.noticeUnit &&
          other.noticeToEndOf == this.noticeToEndOf &&
          other.autoRenewMonths == this.autoRenewMonths &&
          other.cancelledAt == this.cancelledAt &&
          other.endsAt == this.endsAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ContractsCompanion extends UpdateCompanion<Contract> {
  final Value<String> id;
  final Value<String?> documentId;
  final Value<String?> correspondentId;
  final Value<String> title;
  final Value<int?> amountCents;
  final Value<String> interval;
  final Value<DateTime?> startDate;
  final Value<DateTime?> minTermUntil;
  final Value<int?> noticeValue;
  final Value<String?> noticeUnit;
  final Value<String?> noticeToEndOf;
  final Value<int?> autoRenewMonths;
  final Value<DateTime?> cancelledAt;
  final Value<DateTime?> endsAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ContractsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.correspondentId = const Value.absent(),
    this.title = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.interval = const Value.absent(),
    this.startDate = const Value.absent(),
    this.minTermUntil = const Value.absent(),
    this.noticeValue = const Value.absent(),
    this.noticeUnit = const Value.absent(),
    this.noticeToEndOf = const Value.absent(),
    this.autoRenewMonths = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContractsCompanion.insert({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.correspondentId = const Value.absent(),
    required String title,
    this.amountCents = const Value.absent(),
    this.interval = const Value.absent(),
    this.startDate = const Value.absent(),
    this.minTermUntil = const Value.absent(),
    this.noticeValue = const Value.absent(),
    this.noticeUnit = const Value.absent(),
    this.noticeToEndOf = const Value.absent(),
    this.autoRenewMonths = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Contract> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? correspondentId,
    Expression<String>? title,
    Expression<int>? amountCents,
    Expression<String>? interval,
    Expression<DateTime>? startDate,
    Expression<DateTime>? minTermUntil,
    Expression<int>? noticeValue,
    Expression<String>? noticeUnit,
    Expression<String>? noticeToEndOf,
    Expression<int>? autoRenewMonths,
    Expression<DateTime>? cancelledAt,
    Expression<DateTime>? endsAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (correspondentId != null) 'correspondent_id': correspondentId,
      if (title != null) 'title': title,
      if (amountCents != null) 'amount_cents': amountCents,
      if (interval != null) 'interval': interval,
      if (startDate != null) 'start_date': startDate,
      if (minTermUntil != null) 'min_term_until': minTermUntil,
      if (noticeValue != null) 'notice_value': noticeValue,
      if (noticeUnit != null) 'notice_unit': noticeUnit,
      if (noticeToEndOf != null) 'notice_to_end_of': noticeToEndOf,
      if (autoRenewMonths != null) 'auto_renew_months': autoRenewMonths,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContractsCompanion copyWith({
    Value<String>? id,
    Value<String?>? documentId,
    Value<String?>? correspondentId,
    Value<String>? title,
    Value<int?>? amountCents,
    Value<String>? interval,
    Value<DateTime?>? startDate,
    Value<DateTime?>? minTermUntil,
    Value<int?>? noticeValue,
    Value<String?>? noticeUnit,
    Value<String?>? noticeToEndOf,
    Value<int?>? autoRenewMonths,
    Value<DateTime?>? cancelledAt,
    Value<DateTime?>? endsAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ContractsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      correspondentId: correspondentId ?? this.correspondentId,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      minTermUntil: minTermUntil ?? this.minTermUntil,
      noticeValue: noticeValue ?? this.noticeValue,
      noticeUnit: noticeUnit ?? this.noticeUnit,
      noticeToEndOf: noticeToEndOf ?? this.noticeToEndOf,
      autoRenewMonths: autoRenewMonths ?? this.autoRenewMonths,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      endsAt: endsAt ?? this.endsAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (correspondentId.present) {
      map['correspondent_id'] = Variable<String>(correspondentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (interval.present) {
      map['interval'] = Variable<String>(interval.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (minTermUntil.present) {
      map['min_term_until'] = Variable<DateTime>(minTermUntil.value);
    }
    if (noticeValue.present) {
      map['notice_value'] = Variable<int>(noticeValue.value);
    }
    if (noticeUnit.present) {
      map['notice_unit'] = Variable<String>(noticeUnit.value);
    }
    if (noticeToEndOf.present) {
      map['notice_to_end_of'] = Variable<String>(noticeToEndOf.value);
    }
    if (autoRenewMonths.present) {
      map['auto_renew_months'] = Variable<int>(autoRenewMonths.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContractsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('correspondentId: $correspondentId, ')
          ..write('title: $title, ')
          ..write('amountCents: $amountCents, ')
          ..write('interval: $interval, ')
          ..write('startDate: $startDate, ')
          ..write('minTermUntil: $minTermUntil, ')
          ..write('noticeValue: $noticeValue, ')
          ..write('noticeUnit: $noticeUnit, ')
          ..write('noticeToEndOf: $noticeToEndOf, ')
          ..write('autoRenewMonths: $autoRenewMonths, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    kind,
    relPath,
    mime,
    caption,
    sizeBytes,
    sha256,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String documentId;

  /// `foto` oder `datei`.
  final String kind;
  final String relPath;
  final String mime;
  final String caption;
  final int sizeBytes;
  final String? sha256;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Attachment({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.relPath,
    required this.mime,
    required this.caption,
    required this.sizeBytes,
    this.sha256,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['kind'] = Variable<String>(kind);
    map['rel_path'] = Variable<String>(relPath);
    map['mime'] = Variable<String>(mime);
    map['caption'] = Variable<String>(caption);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      documentId: Value(documentId),
      kind: Value(kind),
      relPath: Value(relPath),
      mime: Value(mime),
      caption: Value(caption),
      sizeBytes: Value(sizeBytes),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      kind: serializer.fromJson<String>(json['kind']),
      relPath: serializer.fromJson<String>(json['relPath']),
      mime: serializer.fromJson<String>(json['mime']),
      caption: serializer.fromJson<String>(json['caption']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'kind': serializer.toJson<String>(kind),
      'relPath': serializer.toJson<String>(relPath),
      'mime': serializer.toJson<String>(mime),
      'caption': serializer.toJson<String>(caption),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'sha256': serializer.toJson<String?>(sha256),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Attachment copyWith({
    String? id,
    String? documentId,
    String? kind,
    String? relPath,
    String? mime,
    String? caption,
    int? sizeBytes,
    Value<String?> sha256 = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Attachment(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    kind: kind ?? this.kind,
    relPath: relPath ?? this.relPath,
    mime: mime ?? this.mime,
    caption: caption ?? this.caption,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    sha256: sha256.present ? sha256.value : this.sha256,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      kind: data.kind.present ? data.kind.value : this.kind,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      mime: data.mime.present ? data.mime.value : this.mime,
      caption: data.caption.present ? data.caption.value : this.caption,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('caption: $caption, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    kind,
    relPath,
    mime,
    caption,
    sizeBytes,
    sha256,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.kind == this.kind &&
          other.relPath == this.relPath &&
          other.mime == this.mime &&
          other.caption == this.caption &&
          other.sizeBytes == this.sizeBytes &&
          other.sha256 == this.sha256 &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> kind;
  final Value<String> relPath;
  final Value<String> mime;
  final Value<String> caption;
  final Value<int> sizeBytes;
  final Value<String?> sha256;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.kind = const Value.absent(),
    this.relPath = const Value.absent(),
    this.mime = const Value.absent(),
    this.caption = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required String documentId,
    required String kind,
    required String relPath,
    this.mime = const Value.absent(),
    this.caption = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       kind = Value(kind),
       relPath = Value(relPath);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? kind,
    Expression<String>? relPath,
    Expression<String>? mime,
    Expression<String>? caption,
    Expression<int>? sizeBytes,
    Expression<String>? sha256,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (kind != null) 'kind': kind,
      if (relPath != null) 'rel_path': relPath,
      if (mime != null) 'mime': mime,
      if (caption != null) 'caption': caption,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sha256 != null) 'sha256': sha256,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? kind,
    Value<String>? relPath,
    Value<String>? mime,
    Value<String>? caption,
    Value<int>? sizeBytes,
    Value<String?>? sha256,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      kind: kind ?? this.kind,
      relPath: relPath ?? this.relPath,
      mime: mime ?? this.mime,
      caption: caption ?? this.caption,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('caption: $caption, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalDataTable extends PersonalData
    with TableInfo<$PersonalDataTable, PersonalDataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalDataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: _uuid.v4,
  );
  static const VerificationMeta _personMeta = const VerificationMeta('person');
  @override
  late final GeneratedColumn<String> person = GeneratedColumn<String>(
    'person',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    person,
    key,
    label,
    value,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalDataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person')) {
      context.handle(
        _personMeta,
        person.isAcceptableOrUnknown(data['person']!, _personMeta),
      );
    } else if (isInserting) {
      context.missing(_personMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonalDataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalDataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      person: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PersonalDataTable createAlias(String alias) {
    return $PersonalDataTable(attachedDatabase, alias);
  }
}

class PersonalDataData extends DataClass
    implements Insertable<PersonalDataData> {
  final String id;
  final String person;

  /// Vordefinierter Schlüssel (vorname, iban …) oder `frei`.
  final String key;
  final String label;
  final String value;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const PersonalDataData({
    required this.id,
    required this.person,
    required this.key,
    required this.label,
    required this.value,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person'] = Variable<String>(person);
    map['key'] = Variable<String>(key);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PersonalDataCompanion toCompanion(bool nullToAbsent) {
    return PersonalDataCompanion(
      id: Value(id),
      person: Value(person),
      key: Value(key),
      label: Value(label),
      value: Value(value),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PersonalDataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalDataData(
      id: serializer.fromJson<String>(json['id']),
      person: serializer.fromJson<String>(json['person']),
      key: serializer.fromJson<String>(json['key']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'person': serializer.toJson<String>(person),
      'key': serializer.toJson<String>(key),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PersonalDataData copyWith({
    String? id,
    String? person,
    String? key,
    String? label,
    String? value,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PersonalDataData(
    id: id ?? this.id,
    person: person ?? this.person,
    key: key ?? this.key,
    label: label ?? this.label,
    value: value ?? this.value,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PersonalDataData copyWithCompanion(PersonalDataCompanion data) {
    return PersonalDataData(
      id: data.id.present ? data.id.value : this.id,
      person: data.person.present ? data.person.value : this.person,
      key: data.key.present ? data.key.value : this.key,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalDataData(')
          ..write('id: $id, ')
          ..write('person: $person, ')
          ..write('key: $key, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    person,
    key,
    label,
    value,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalDataData &&
          other.id == this.id &&
          other.person == this.person &&
          other.key == this.key &&
          other.label == this.label &&
          other.value == this.value &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PersonalDataCompanion extends UpdateCompanion<PersonalDataData> {
  final Value<String> id;
  final Value<String> person;
  final Value<String> key;
  final Value<String> label;
  final Value<String> value;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PersonalDataCompanion({
    this.id = const Value.absent(),
    this.person = const Value.absent(),
    this.key = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalDataCompanion.insert({
    this.id = const Value.absent(),
    required String person,
    required String key,
    required String label,
    this.value = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : person = Value(person),
       key = Value(key),
       label = Value(label);
  static Insertable<PersonalDataData> custom({
    Expression<String>? id,
    Expression<String>? person,
    Expression<String>? key,
    Expression<String>? label,
    Expression<String>? value,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (person != null) 'person': person,
      if (key != null) 'key': key,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalDataCompanion copyWith({
    Value<String>? id,
    Value<String>? person,
    Value<String>? key,
    Value<String>? label,
    Value<String>? value,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PersonalDataCompanion(
      id: id ?? this.id,
      person: person ?? this.person,
      key: key ?? this.key,
      label: label ?? this.label,
      value: value ?? this.value,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (person.present) {
      map['person'] = Variable<String>(person.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalDataCompanion(')
          ..write('id: $id, ')
          ..write('person: $person, ')
          ..write('key: $key, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $CorrespondentsTable correspondents = $CorrespondentsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $DocumentTagsTable documentTags = $DocumentTagsTable(this);
  late final $ExtractedRefsTable extractedRefs = $ExtractedRefsTable(this);
  late final $CountersTable counters = $CountersTable(this);
  late final $ClaimsTable claims = $ClaimsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SignatureTemplatesTable signatureTemplates =
      $SignatureTemplatesTable(this);
  late final $DocTasksTable docTasks = $DocTasksTable(this);
  late final $CasesTable cases = $CasesTable(this);
  late final $CaseDocumentsTable caseDocuments = $CaseDocumentsTable(this);
  late final $ContractsTable contracts = $ContractsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $PersonalDataTable personalData = $PersonalDataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documents,
    correspondents,
    tags,
    documentTags,
    extractedRefs,
    counters,
    claims,
    categories,
    signatureTemplates,
    docTasks,
    cases,
    caseDocuments,
    contracts,
    attachments,
    personalData,
  ];
}

typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      required String docNumber,
      Value<String> title,
      Value<DateTime?> docDate,
      Value<DateTime> scannedAt,
      Value<String?> correspondentId,
      Value<String?> docType,
      required String storageLocation,
      required String pdfPath,
      Value<int> pageCount,
      Value<String> ocrText,
      Value<DateTime?> retentionUntil,
      Value<DateTime?> reminderAt,
      Value<String?> reminderNote,
      Value<int?> amountCents,
      Value<DateTime?> dueDate,
      Value<String?> paymentStatus,
      Value<DateTime?> paidAt,
      Value<DateTime?> paymentReminderAt,
      Value<String?> filledPdfPath,
      Value<String?> fillData,
      Value<String?> contentHash,
      Value<DateTime?> warrantyUntil,
      Value<String?> warrantyKind,
      Value<DateTime?> objectionDeadline,
      Value<String?> taxCategory,
      Value<int?> taxYear,
      Value<int?> taxAmountCents,
      Value<DateTime?> destroyedAt,
      Value<String?> destroyedFrom,
      Value<String?> paymentReference,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      Value<String> docNumber,
      Value<String> title,
      Value<DateTime?> docDate,
      Value<DateTime> scannedAt,
      Value<String?> correspondentId,
      Value<String?> docType,
      Value<String> storageLocation,
      Value<String> pdfPath,
      Value<int> pageCount,
      Value<String> ocrText,
      Value<DateTime?> retentionUntil,
      Value<DateTime?> reminderAt,
      Value<String?> reminderNote,
      Value<int?> amountCents,
      Value<DateTime?> dueDate,
      Value<String?> paymentStatus,
      Value<DateTime?> paidAt,
      Value<DateTime?> paymentReminderAt,
      Value<String?> filledPdfPath,
      Value<String?> fillData,
      Value<String?> contentHash,
      Value<DateTime?> warrantyUntil,
      Value<String?> warrantyKind,
      Value<DateTime?> objectionDeadline,
      Value<String?> taxCategory,
      Value<int?> taxYear,
      Value<int?> taxAmountCents,
      Value<DateTime?> destroyedAt,
      Value<String?> destroyedFrom,
      Value<String?> paymentReference,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docNumber => $composableBuilder(
    column: $table.docNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get docDate => $composableBuilder(
    column: $table.docDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageLocation => $composableBuilder(
    column: $table.storageLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get retentionUntil => $composableBuilder(
    column: $table.retentionUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderNote => $composableBuilder(
    column: $table.reminderNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paymentReminderAt => $composableBuilder(
    column: $table.paymentReminderAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledPdfPath => $composableBuilder(
    column: $table.filledPdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fillData => $composableBuilder(
    column: $table.fillData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get warrantyUntil => $composableBuilder(
    column: $table.warrantyUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warrantyKind => $composableBuilder(
    column: $table.warrantyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get objectionDeadline => $composableBuilder(
    column: $table.objectionDeadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxCategory => $composableBuilder(
    column: $table.taxCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxYear => $composableBuilder(
    column: $table.taxYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxAmountCents => $composableBuilder(
    column: $table.taxAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get destroyedAt => $composableBuilder(
    column: $table.destroyedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destroyedFrom => $composableBuilder(
    column: $table.destroyedFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentReference => $composableBuilder(
    column: $table.paymentReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docNumber => $composableBuilder(
    column: $table.docNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get docDate => $composableBuilder(
    column: $table.docDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageLocation => $composableBuilder(
    column: $table.storageLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get retentionUntil => $composableBuilder(
    column: $table.retentionUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderNote => $composableBuilder(
    column: $table.reminderNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paymentReminderAt => $composableBuilder(
    column: $table.paymentReminderAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledPdfPath => $composableBuilder(
    column: $table.filledPdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fillData => $composableBuilder(
    column: $table.fillData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get warrantyUntil => $composableBuilder(
    column: $table.warrantyUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warrantyKind => $composableBuilder(
    column: $table.warrantyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get objectionDeadline => $composableBuilder(
    column: $table.objectionDeadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxCategory => $composableBuilder(
    column: $table.taxCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxYear => $composableBuilder(
    column: $table.taxYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxAmountCents => $composableBuilder(
    column: $table.taxAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get destroyedAt => $composableBuilder(
    column: $table.destroyedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destroyedFrom => $composableBuilder(
    column: $table.destroyedFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentReference => $composableBuilder(
    column: $table.paymentReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get docNumber =>
      $composableBuilder(column: $table.docNumber, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get docDate =>
      $composableBuilder(column: $table.docDate, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get docType =>
      $composableBuilder(column: $table.docType, builder: (column) => column);

  GeneratedColumn<String> get storageLocation => $composableBuilder(
    column: $table.storageLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfPath =>
      $composableBuilder(column: $table.pdfPath, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<DateTime> get retentionUntil => $composableBuilder(
    column: $table.retentionUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderNote => $composableBuilder(
    column: $table.reminderNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<DateTime> get paymentReminderAt => $composableBuilder(
    column: $table.paymentReminderAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filledPdfPath => $composableBuilder(
    column: $table.filledPdfPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fillData =>
      $composableBuilder(column: $table.fillData, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get warrantyUntil => $composableBuilder(
    column: $table.warrantyUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get warrantyKind => $composableBuilder(
    column: $table.warrantyKind,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get objectionDeadline => $composableBuilder(
    column: $table.objectionDeadline,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taxCategory => $composableBuilder(
    column: $table.taxCategory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxYear =>
      $composableBuilder(column: $table.taxYear, builder: (column) => column);

  GeneratedColumn<int> get taxAmountCents => $composableBuilder(
    column: $table.taxAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get destroyedAt => $composableBuilder(
    column: $table.destroyedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destroyedFrom => $composableBuilder(
    column: $table.destroyedFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentReference => $composableBuilder(
    column: $table.paymentReference,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
          Document,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> docNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime?> docDate = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                Value<String?> docType = const Value.absent(),
                Value<String> storageLocation = const Value.absent(),
                Value<String> pdfPath = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
                Value<DateTime?> retentionUntil = const Value.absent(),
                Value<DateTime?> reminderAt = const Value.absent(),
                Value<String?> reminderNote = const Value.absent(),
                Value<int?> amountCents = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> paymentStatus = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<DateTime?> paymentReminderAt = const Value.absent(),
                Value<String?> filledPdfPath = const Value.absent(),
                Value<String?> fillData = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<DateTime?> warrantyUntil = const Value.absent(),
                Value<String?> warrantyKind = const Value.absent(),
                Value<DateTime?> objectionDeadline = const Value.absent(),
                Value<String?> taxCategory = const Value.absent(),
                Value<int?> taxYear = const Value.absent(),
                Value<int?> taxAmountCents = const Value.absent(),
                Value<DateTime?> destroyedAt = const Value.absent(),
                Value<String?> destroyedFrom = const Value.absent(),
                Value<String?> paymentReference = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                docNumber: docNumber,
                title: title,
                docDate: docDate,
                scannedAt: scannedAt,
                correspondentId: correspondentId,
                docType: docType,
                storageLocation: storageLocation,
                pdfPath: pdfPath,
                pageCount: pageCount,
                ocrText: ocrText,
                retentionUntil: retentionUntil,
                reminderAt: reminderAt,
                reminderNote: reminderNote,
                amountCents: amountCents,
                dueDate: dueDate,
                paymentStatus: paymentStatus,
                paidAt: paidAt,
                paymentReminderAt: paymentReminderAt,
                filledPdfPath: filledPdfPath,
                fillData: fillData,
                contentHash: contentHash,
                warrantyUntil: warrantyUntil,
                warrantyKind: warrantyKind,
                objectionDeadline: objectionDeadline,
                taxCategory: taxCategory,
                taxYear: taxYear,
                taxAmountCents: taxAmountCents,
                destroyedAt: destroyedAt,
                destroyedFrom: destroyedFrom,
                paymentReference: paymentReference,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String docNumber,
                Value<String> title = const Value.absent(),
                Value<DateTime?> docDate = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                Value<String?> docType = const Value.absent(),
                required String storageLocation,
                required String pdfPath,
                Value<int> pageCount = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
                Value<DateTime?> retentionUntil = const Value.absent(),
                Value<DateTime?> reminderAt = const Value.absent(),
                Value<String?> reminderNote = const Value.absent(),
                Value<int?> amountCents = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> paymentStatus = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<DateTime?> paymentReminderAt = const Value.absent(),
                Value<String?> filledPdfPath = const Value.absent(),
                Value<String?> fillData = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<DateTime?> warrantyUntil = const Value.absent(),
                Value<String?> warrantyKind = const Value.absent(),
                Value<DateTime?> objectionDeadline = const Value.absent(),
                Value<String?> taxCategory = const Value.absent(),
                Value<int?> taxYear = const Value.absent(),
                Value<int?> taxAmountCents = const Value.absent(),
                Value<DateTime?> destroyedAt = const Value.absent(),
                Value<String?> destroyedFrom = const Value.absent(),
                Value<String?> paymentReference = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                docNumber: docNumber,
                title: title,
                docDate: docDate,
                scannedAt: scannedAt,
                correspondentId: correspondentId,
                docType: docType,
                storageLocation: storageLocation,
                pdfPath: pdfPath,
                pageCount: pageCount,
                ocrText: ocrText,
                retentionUntil: retentionUntil,
                reminderAt: reminderAt,
                reminderNote: reminderNote,
                amountCents: amountCents,
                dueDate: dueDate,
                paymentStatus: paymentStatus,
                paidAt: paidAt,
                paymentReminderAt: paymentReminderAt,
                filledPdfPath: filledPdfPath,
                fillData: fillData,
                contentHash: contentHash,
                warrantyUntil: warrantyUntil,
                warrantyKind: warrantyKind,
                objectionDeadline: objectionDeadline,
                taxCategory: taxCategory,
                taxYear: taxYear,
                taxAmountCents: taxAmountCents,
                destroyedAt: destroyedAt,
                destroyedFrom: destroyedFrom,
                paymentReference: paymentReference,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
      Document,
      PrefetchHooks Function()
    >;
typedef $$CorrespondentsTableCreateCompanionBuilder =
    CorrespondentsCompanion Function({
      Value<String> id,
      required String name,
      Value<String> aliases,
      Value<String?> categoryId,
      Value<String?> email,
      Value<String?> fax,
      Value<String?> postalAddress,
      Value<String?> mailSubjectTemplate,
      Value<String?> mailBodyTemplate,
      Value<String?> iban,
      Value<String?> bic,
      Value<String?> defaultDocType,
      Value<String> defaultTagIds,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CorrespondentsTableUpdateCompanionBuilder =
    CorrespondentsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> aliases,
      Value<String?> categoryId,
      Value<String?> email,
      Value<String?> fax,
      Value<String?> postalAddress,
      Value<String?> mailSubjectTemplate,
      Value<String?> mailBodyTemplate,
      Value<String?> iban,
      Value<String?> bic,
      Value<String?> defaultDocType,
      Value<String> defaultTagIds,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CorrespondentsTableFilterComposer
    extends Composer<_$AppDatabase, $CorrespondentsTable> {
  $$CorrespondentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fax => $composableBuilder(
    column: $table.fax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postalAddress => $composableBuilder(
    column: $table.postalAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mailSubjectTemplate => $composableBuilder(
    column: $table.mailSubjectTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mailBodyTemplate => $composableBuilder(
    column: $table.mailBodyTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bic => $composableBuilder(
    column: $table.bic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultDocType => $composableBuilder(
    column: $table.defaultDocType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultTagIds => $composableBuilder(
    column: $table.defaultTagIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CorrespondentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CorrespondentsTable> {
  $$CorrespondentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fax => $composableBuilder(
    column: $table.fax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postalAddress => $composableBuilder(
    column: $table.postalAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mailSubjectTemplate => $composableBuilder(
    column: $table.mailSubjectTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mailBodyTemplate => $composableBuilder(
    column: $table.mailBodyTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bic => $composableBuilder(
    column: $table.bic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultDocType => $composableBuilder(
    column: $table.defaultDocType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultTagIds => $composableBuilder(
    column: $table.defaultTagIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CorrespondentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CorrespondentsTable> {
  $$CorrespondentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get fax =>
      $composableBuilder(column: $table.fax, builder: (column) => column);

  GeneratedColumn<String> get postalAddress => $composableBuilder(
    column: $table.postalAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mailSubjectTemplate => $composableBuilder(
    column: $table.mailSubjectTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mailBodyTemplate => $composableBuilder(
    column: $table.mailBodyTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iban =>
      $composableBuilder(column: $table.iban, builder: (column) => column);

  GeneratedColumn<String> get bic =>
      $composableBuilder(column: $table.bic, builder: (column) => column);

  GeneratedColumn<String> get defaultDocType => $composableBuilder(
    column: $table.defaultDocType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultTagIds => $composableBuilder(
    column: $table.defaultTagIds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CorrespondentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CorrespondentsTable,
          Correspondent,
          $$CorrespondentsTableFilterComposer,
          $$CorrespondentsTableOrderingComposer,
          $$CorrespondentsTableAnnotationComposer,
          $$CorrespondentsTableCreateCompanionBuilder,
          $$CorrespondentsTableUpdateCompanionBuilder,
          (
            Correspondent,
            BaseReferences<_$AppDatabase, $CorrespondentsTable, Correspondent>,
          ),
          Correspondent,
          PrefetchHooks Function()
        > {
  $$CorrespondentsTableTableManager(
    _$AppDatabase db,
    $CorrespondentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CorrespondentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CorrespondentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CorrespondentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> fax = const Value.absent(),
                Value<String?> postalAddress = const Value.absent(),
                Value<String?> mailSubjectTemplate = const Value.absent(),
                Value<String?> mailBodyTemplate = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<String?> bic = const Value.absent(),
                Value<String?> defaultDocType = const Value.absent(),
                Value<String> defaultTagIds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrespondentsCompanion(
                id: id,
                name: name,
                aliases: aliases,
                categoryId: categoryId,
                email: email,
                fax: fax,
                postalAddress: postalAddress,
                mailSubjectTemplate: mailSubjectTemplate,
                mailBodyTemplate: mailBodyTemplate,
                iban: iban,
                bic: bic,
                defaultDocType: defaultDocType,
                defaultTagIds: defaultTagIds,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<String> aliases = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> fax = const Value.absent(),
                Value<String?> postalAddress = const Value.absent(),
                Value<String?> mailSubjectTemplate = const Value.absent(),
                Value<String?> mailBodyTemplate = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<String?> bic = const Value.absent(),
                Value<String?> defaultDocType = const Value.absent(),
                Value<String> defaultTagIds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrespondentsCompanion.insert(
                id: id,
                name: name,
                aliases: aliases,
                categoryId: categoryId,
                email: email,
                fax: fax,
                postalAddress: postalAddress,
                mailSubjectTemplate: mailSubjectTemplate,
                mailBodyTemplate: mailBodyTemplate,
                iban: iban,
                bic: bic,
                defaultDocType: defaultDocType,
                defaultTagIds: defaultTagIds,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CorrespondentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CorrespondentsTable,
      Correspondent,
      $$CorrespondentsTableFilterComposer,
      $$CorrespondentsTableOrderingComposer,
      $$CorrespondentsTableAnnotationComposer,
      $$CorrespondentsTableCreateCompanionBuilder,
      $$CorrespondentsTableUpdateCompanionBuilder,
      (
        Correspondent,
        BaseReferences<_$AppDatabase, $CorrespondentsTable, Correspondent>,
      ),
      Correspondent,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      required String name,
      Value<int> color,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> color,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<int> color = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$DocumentTagsTableCreateCompanionBuilder =
    DocumentTagsCompanion Function({
      required String documentId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$DocumentTagsTableUpdateCompanionBuilder =
    DocumentTagsCompanion Function({
      Value<String> documentId,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$DocumentTagsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentTagsTable> {
  $$DocumentTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentTagsTable> {
  $$DocumentTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentTagsTable> {
  $$DocumentTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$DocumentTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentTagsTable,
          DocumentTag,
          $$DocumentTagsTableFilterComposer,
          $$DocumentTagsTableOrderingComposer,
          $$DocumentTagsTableAnnotationComposer,
          $$DocumentTagsTableCreateCompanionBuilder,
          $$DocumentTagsTableUpdateCompanionBuilder,
          (
            DocumentTag,
            BaseReferences<_$AppDatabase, $DocumentTagsTable, DocumentTag>,
          ),
          DocumentTag,
          PrefetchHooks Function()
        > {
  $$DocumentTagsTableTableManager(_$AppDatabase db, $DocumentTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentTagsCompanion(
                documentId: documentId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => DocumentTagsCompanion.insert(
                documentId: documentId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentTagsTable,
      DocumentTag,
      $$DocumentTagsTableFilterComposer,
      $$DocumentTagsTableOrderingComposer,
      $$DocumentTagsTableAnnotationComposer,
      $$DocumentTagsTableCreateCompanionBuilder,
      $$DocumentTagsTableUpdateCompanionBuilder,
      (
        DocumentTag,
        BaseReferences<_$AppDatabase, $DocumentTagsTable, DocumentTag>,
      ),
      DocumentTag,
      PrefetchHooks Function()
    >;
typedef $$ExtractedRefsTableCreateCompanionBuilder =
    ExtractedRefsCompanion Function({
      required String documentId,
      required String kind,
      required String value,
      Value<int> rowid,
    });
typedef $$ExtractedRefsTableUpdateCompanionBuilder =
    ExtractedRefsCompanion Function({
      Value<String> documentId,
      Value<String> kind,
      Value<String> value,
      Value<int> rowid,
    });

class $$ExtractedRefsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtractedRefsTable> {
  $$ExtractedRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtractedRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtractedRefsTable> {
  $$ExtractedRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtractedRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtractedRefsTable> {
  $$ExtractedRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ExtractedRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtractedRefsTable,
          ExtractedRef,
          $$ExtractedRefsTableFilterComposer,
          $$ExtractedRefsTableOrderingComposer,
          $$ExtractedRefsTableAnnotationComposer,
          $$ExtractedRefsTableCreateCompanionBuilder,
          $$ExtractedRefsTableUpdateCompanionBuilder,
          (
            ExtractedRef,
            BaseReferences<_$AppDatabase, $ExtractedRefsTable, ExtractedRef>,
          ),
          ExtractedRef,
          PrefetchHooks Function()
        > {
  $$ExtractedRefsTableTableManager(_$AppDatabase db, $ExtractedRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractedRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractedRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractedRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtractedRefsCompanion(
                documentId: documentId,
                kind: kind,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String kind,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ExtractedRefsCompanion.insert(
                documentId: documentId,
                kind: kind,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExtractedRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtractedRefsTable,
      ExtractedRef,
      $$ExtractedRefsTableFilterComposer,
      $$ExtractedRefsTableOrderingComposer,
      $$ExtractedRefsTableAnnotationComposer,
      $$ExtractedRefsTableCreateCompanionBuilder,
      $$ExtractedRefsTableUpdateCompanionBuilder,
      (
        ExtractedRef,
        BaseReferences<_$AppDatabase, $ExtractedRefsTable, ExtractedRef>,
      ),
      ExtractedRef,
      PrefetchHooks Function()
    >;
typedef $$CountersTableCreateCompanionBuilder =
    CountersCompanion Function({Value<int> year, Value<int> lastNumber});
typedef $$CountersTableUpdateCompanionBuilder =
    CountersCompanion Function({Value<int> year, Value<int> lastNumber});

class $$CountersTableFilterComposer
    extends Composer<_$AppDatabase, $CountersTable> {
  $$CountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountersTableOrderingComposer
    extends Composer<_$AppDatabase, $CountersTable> {
  $$CountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountersTable> {
  $$CountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => column,
  );
}

class $$CountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CountersTable,
          Counter,
          $$CountersTableFilterComposer,
          $$CountersTableOrderingComposer,
          $$CountersTableAnnotationComposer,
          $$CountersTableCreateCompanionBuilder,
          $$CountersTableUpdateCompanionBuilder,
          (Counter, BaseReferences<_$AppDatabase, $CountersTable, Counter>),
          Counter,
          PrefetchHooks Function()
        > {
  $$CountersTableTableManager(_$AppDatabase db, $CountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> lastNumber = const Value.absent(),
              }) => CountersCompanion(year: year, lastNumber: lastNumber),
          createCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> lastNumber = const Value.absent(),
              }) =>
                  CountersCompanion.insert(year: year, lastNumber: lastNumber),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CountersTable,
      Counter,
      $$CountersTableFilterComposer,
      $$CountersTableOrderingComposer,
      $$CountersTableAnnotationComposer,
      $$CountersTableCreateCompanionBuilder,
      $$CountersTableUpdateCompanionBuilder,
      (Counter, BaseReferences<_$AppDatabase, $CountersTable, Counter>),
      Counter,
      PrefetchHooks Function()
    >;
typedef $$ClaimsTableCreateCompanionBuilder =
    ClaimsCompanion Function({
      Value<String> id,
      required String documentId,
      required String target,
      required String status,
      Value<DateTime?> submittedAt,
      Value<int?> reimbursedCents,
      Value<DateTime?> settledAt,
      Value<DateTime?> followUpAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ClaimsTableUpdateCompanionBuilder =
    ClaimsCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String> target,
      Value<String> status,
      Value<DateTime?> submittedAt,
      Value<int?> reimbursedCents,
      Value<DateTime?> settledAt,
      Value<DateTime?> followUpAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ClaimsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reimbursedCents => $composableBuilder(
    column: $table.reimbursedCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get followUpAt => $composableBuilder(
    column: $table.followUpAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClaimsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reimbursedCents => $composableBuilder(
    column: $table.reimbursedCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get followUpAt => $composableBuilder(
    column: $table.followUpAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClaimsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reimbursedCents => $composableBuilder(
    column: $table.reimbursedCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);

  GeneratedColumn<DateTime> get followUpAt => $composableBuilder(
    column: $table.followUpAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ClaimsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaimsTable,
          Claim,
          $$ClaimsTableFilterComposer,
          $$ClaimsTableOrderingComposer,
          $$ClaimsTableAnnotationComposer,
          $$ClaimsTableCreateCompanionBuilder,
          $$ClaimsTableUpdateCompanionBuilder,
          (Claim, BaseReferences<_$AppDatabase, $ClaimsTable, Claim>),
          Claim,
          PrefetchHooks Function()
        > {
  $$ClaimsTableTableManager(_$AppDatabase db, $ClaimsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<int?> reimbursedCents = const Value.absent(),
                Value<DateTime?> settledAt = const Value.absent(),
                Value<DateTime?> followUpAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion(
                id: id,
                documentId: documentId,
                target: target,
                status: status,
                submittedAt: submittedAt,
                reimbursedCents: reimbursedCents,
                settledAt: settledAt,
                followUpAt: followUpAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String documentId,
                required String target,
                required String status,
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<int?> reimbursedCents = const Value.absent(),
                Value<DateTime?> settledAt = const Value.absent(),
                Value<DateTime?> followUpAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimsCompanion.insert(
                id: id,
                documentId: documentId,
                target: target,
                status: status,
                submittedAt: submittedAt,
                reimbursedCents: reimbursedCents,
                settledAt: settledAt,
                followUpAt: followUpAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClaimsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaimsTable,
      Claim,
      $$ClaimsTableFilterComposer,
      $$ClaimsTableOrderingComposer,
      $$ClaimsTableAnnotationComposer,
      $$ClaimsTableCreateCompanionBuilder,
      $$ClaimsTableUpdateCompanionBuilder,
      (Claim, BaseReferences<_$AppDatabase, $ClaimsTable, Claim>),
      Claim,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      required String name,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$SignatureTemplatesTableCreateCompanionBuilder =
    SignatureTemplatesCompanion Function({
      Value<String> id,
      required String name,
      required String imagePath,
      Value<double> aspect,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SignatureTemplatesTableUpdateCompanionBuilder =
    SignatureTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> imagePath,
      Value<double> aspect,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SignatureTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $SignatureTemplatesTable> {
  $$SignatureTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignatureTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SignatureTemplatesTable> {
  $$SignatureTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignatureTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignatureTemplatesTable> {
  $$SignatureTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<double> get aspect =>
      $composableBuilder(column: $table.aspect, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SignatureTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignatureTemplatesTable,
          SignatureTemplate,
          $$SignatureTemplatesTableFilterComposer,
          $$SignatureTemplatesTableOrderingComposer,
          $$SignatureTemplatesTableAnnotationComposer,
          $$SignatureTemplatesTableCreateCompanionBuilder,
          $$SignatureTemplatesTableUpdateCompanionBuilder,
          (
            SignatureTemplate,
            BaseReferences<
              _$AppDatabase,
              $SignatureTemplatesTable,
              SignatureTemplate
            >,
          ),
          SignatureTemplate,
          PrefetchHooks Function()
        > {
  $$SignatureTemplatesTableTableManager(
    _$AppDatabase db,
    $SignatureTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignatureTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignatureTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignatureTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<double> aspect = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignatureTemplatesCompanion(
                id: id,
                name: name,
                imagePath: imagePath,
                aspect: aspect,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                required String imagePath,
                Value<double> aspect = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignatureTemplatesCompanion.insert(
                id: id,
                name: name,
                imagePath: imagePath,
                aspect: aspect,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignatureTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignatureTemplatesTable,
      SignatureTemplate,
      $$SignatureTemplatesTableFilterComposer,
      $$SignatureTemplatesTableOrderingComposer,
      $$SignatureTemplatesTableAnnotationComposer,
      $$SignatureTemplatesTableCreateCompanionBuilder,
      $$SignatureTemplatesTableUpdateCompanionBuilder,
      (
        SignatureTemplate,
        BaseReferences<
          _$AppDatabase,
          $SignatureTemplatesTable,
          SignatureTemplate
        >,
      ),
      SignatureTemplate,
      PrefetchHooks Function()
    >;
typedef $$DocTasksTableCreateCompanionBuilder =
    DocTasksCompanion Function({
      Value<String> id,
      required String documentId,
      required String action,
      Value<String> note,
      required DateTime dueAt,
      Value<String> repeat,
      Value<String?> origin,
      Value<DateTime?> doneAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DocTasksTableUpdateCompanionBuilder =
    DocTasksCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String> action,
      Value<String> note,
      Value<DateTime> dueAt,
      Value<String> repeat,
      Value<String?> origin,
      Value<DateTime?> doneAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$DocTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DocTasksTable> {
  $$DocTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DocTasksTable> {
  $$DocTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocTasksTable> {
  $$DocTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DocTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocTasksTable,
          DocTask,
          $$DocTasksTableFilterComposer,
          $$DocTasksTableOrderingComposer,
          $$DocTasksTableAnnotationComposer,
          $$DocTasksTableCreateCompanionBuilder,
          $$DocTasksTableUpdateCompanionBuilder,
          (DocTask, BaseReferences<_$AppDatabase, $DocTasksTable, DocTask>),
          DocTask,
          PrefetchHooks Function()
        > {
  $$DocTasksTableTableManager(_$AppDatabase db, $DocTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<String> repeat = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocTasksCompanion(
                id: id,
                documentId: documentId,
                action: action,
                note: note,
                dueAt: dueAt,
                repeat: repeat,
                origin: origin,
                doneAt: doneAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String documentId,
                required String action,
                Value<String> note = const Value.absent(),
                required DateTime dueAt,
                Value<String> repeat = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocTasksCompanion.insert(
                id: id,
                documentId: documentId,
                action: action,
                note: note,
                dueAt: dueAt,
                repeat: repeat,
                origin: origin,
                doneAt: doneAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocTasksTable,
      DocTask,
      $$DocTasksTableFilterComposer,
      $$DocTasksTableOrderingComposer,
      $$DocTasksTableAnnotationComposer,
      $$DocTasksTableCreateCompanionBuilder,
      $$DocTasksTableUpdateCompanionBuilder,
      (DocTask, BaseReferences<_$AppDatabase, $DocTasksTable, DocTask>),
      DocTask,
      PrefetchHooks Function()
    >;
typedef $$CasesTableCreateCompanionBuilder =
    CasesCompanion Function({
      Value<String> id,
      required String title,
      Value<String> status,
      Value<String?> correspondentId,
      Value<String?> refKind,
      Value<String?> refValue,
      Value<String> note,
      Value<DateTime?> closedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CasesTableUpdateCompanionBuilder =
    CasesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> status,
      Value<String?> correspondentId,
      Value<String?> refKind,
      Value<String?> refValue,
      Value<String> note,
      Value<DateTime?> closedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CasesTableFilterComposer extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refKind => $composableBuilder(
    column: $table.refKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refValue => $composableBuilder(
    column: $table.refValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CasesTableOrderingComposer
    extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refKind => $composableBuilder(
    column: $table.refKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refValue => $composableBuilder(
    column: $table.refValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CasesTable> {
  $$CasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refKind =>
      $composableBuilder(column: $table.refKind, builder: (column) => column);

  GeneratedColumn<String> get refValue =>
      $composableBuilder(column: $table.refValue, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CasesTable,
          Case,
          $$CasesTableFilterComposer,
          $$CasesTableOrderingComposer,
          $$CasesTableAnnotationComposer,
          $$CasesTableCreateCompanionBuilder,
          $$CasesTableUpdateCompanionBuilder,
          (Case, BaseReferences<_$AppDatabase, $CasesTable, Case>),
          Case,
          PrefetchHooks Function()
        > {
  $$CasesTableTableManager(_$AppDatabase db, $CasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                Value<String?> refKind = const Value.absent(),
                Value<String?> refValue = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CasesCompanion(
                id: id,
                title: title,
                status: status,
                correspondentId: correspondentId,
                refKind: refKind,
                refValue: refValue,
                note: note,
                closedAt: closedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String title,
                Value<String> status = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                Value<String?> refKind = const Value.absent(),
                Value<String?> refValue = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CasesCompanion.insert(
                id: id,
                title: title,
                status: status,
                correspondentId: correspondentId,
                refKind: refKind,
                refValue: refValue,
                note: note,
                closedAt: closedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CasesTable,
      Case,
      $$CasesTableFilterComposer,
      $$CasesTableOrderingComposer,
      $$CasesTableAnnotationComposer,
      $$CasesTableCreateCompanionBuilder,
      $$CasesTableUpdateCompanionBuilder,
      (Case, BaseReferences<_$AppDatabase, $CasesTable, Case>),
      Case,
      PrefetchHooks Function()
    >;
typedef $$CaseDocumentsTableCreateCompanionBuilder =
    CaseDocumentsCompanion Function({
      Value<String> id,
      required String caseId,
      required String documentId,
      Value<String> role,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CaseDocumentsTableUpdateCompanionBuilder =
    CaseDocumentsCompanion Function({
      Value<String> id,
      Value<String> caseId,
      Value<String> documentId,
      Value<String> role,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CaseDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $CaseDocumentsTable> {
  $$CaseDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseId => $composableBuilder(
    column: $table.caseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaseDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CaseDocumentsTable> {
  $$CaseDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseId => $composableBuilder(
    column: $table.caseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaseDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaseDocumentsTable> {
  $$CaseDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CaseDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaseDocumentsTable,
          CaseDocument,
          $$CaseDocumentsTableFilterComposer,
          $$CaseDocumentsTableOrderingComposer,
          $$CaseDocumentsTableAnnotationComposer,
          $$CaseDocumentsTableCreateCompanionBuilder,
          $$CaseDocumentsTableUpdateCompanionBuilder,
          (
            CaseDocument,
            BaseReferences<_$AppDatabase, $CaseDocumentsTable, CaseDocument>,
          ),
          CaseDocument,
          PrefetchHooks Function()
        > {
  $$CaseDocumentsTableTableManager(_$AppDatabase db, $CaseDocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> caseId = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseDocumentsCompanion(
                id: id,
                caseId: caseId,
                documentId: documentId,
                role: role,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String caseId,
                required String documentId,
                Value<String> role = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseDocumentsCompanion.insert(
                id: id,
                caseId: caseId,
                documentId: documentId,
                role: role,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaseDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaseDocumentsTable,
      CaseDocument,
      $$CaseDocumentsTableFilterComposer,
      $$CaseDocumentsTableOrderingComposer,
      $$CaseDocumentsTableAnnotationComposer,
      $$CaseDocumentsTableCreateCompanionBuilder,
      $$CaseDocumentsTableUpdateCompanionBuilder,
      (
        CaseDocument,
        BaseReferences<_$AppDatabase, $CaseDocumentsTable, CaseDocument>,
      ),
      CaseDocument,
      PrefetchHooks Function()
    >;
typedef $$ContractsTableCreateCompanionBuilder =
    ContractsCompanion Function({
      Value<String> id,
      Value<String?> documentId,
      Value<String?> correspondentId,
      required String title,
      Value<int?> amountCents,
      Value<String> interval,
      Value<DateTime?> startDate,
      Value<DateTime?> minTermUntil,
      Value<int?> noticeValue,
      Value<String?> noticeUnit,
      Value<String?> noticeToEndOf,
      Value<int?> autoRenewMonths,
      Value<DateTime?> cancelledAt,
      Value<DateTime?> endsAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ContractsTableUpdateCompanionBuilder =
    ContractsCompanion Function({
      Value<String> id,
      Value<String?> documentId,
      Value<String?> correspondentId,
      Value<String> title,
      Value<int?> amountCents,
      Value<String> interval,
      Value<DateTime?> startDate,
      Value<DateTime?> minTermUntil,
      Value<int?> noticeValue,
      Value<String?> noticeUnit,
      Value<String?> noticeToEndOf,
      Value<int?> autoRenewMonths,
      Value<DateTime?> cancelledAt,
      Value<DateTime?> endsAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ContractsTableFilterComposer
    extends Composer<_$AppDatabase, $ContractsTable> {
  $$ContractsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get minTermUntil => $composableBuilder(
    column: $table.minTermUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get noticeValue => $composableBuilder(
    column: $table.noticeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noticeUnit => $composableBuilder(
    column: $table.noticeUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noticeToEndOf => $composableBuilder(
    column: $table.noticeToEndOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoRenewMonths => $composableBuilder(
    column: $table.autoRenewMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContractsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContractsTable> {
  $$ContractsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get minTermUntil => $composableBuilder(
    column: $table.minTermUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get noticeValue => $composableBuilder(
    column: $table.noticeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noticeUnit => $composableBuilder(
    column: $table.noticeUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noticeToEndOf => $composableBuilder(
    column: $table.noticeToEndOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoRenewMonths => $composableBuilder(
    column: $table.autoRenewMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContractsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContractsTable> {
  $$ContractsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get correspondentId => $composableBuilder(
    column: $table.correspondentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get minTermUntil => $composableBuilder(
    column: $table.minTermUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get noticeValue => $composableBuilder(
    column: $table.noticeValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noticeUnit => $composableBuilder(
    column: $table.noticeUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noticeToEndOf => $composableBuilder(
    column: $table.noticeToEndOf,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoRenewMonths => $composableBuilder(
    column: $table.autoRenewMonths,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ContractsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContractsTable,
          Contract,
          $$ContractsTableFilterComposer,
          $$ContractsTableOrderingComposer,
          $$ContractsTableAnnotationComposer,
          $$ContractsTableCreateCompanionBuilder,
          $$ContractsTableUpdateCompanionBuilder,
          (Contract, BaseReferences<_$AppDatabase, $ContractsTable, Contract>),
          Contract,
          PrefetchHooks Function()
        > {
  $$ContractsTableTableManager(_$AppDatabase db, $ContractsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContractsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContractsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContractsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> amountCents = const Value.absent(),
                Value<String> interval = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> minTermUntil = const Value.absent(),
                Value<int?> noticeValue = const Value.absent(),
                Value<String?> noticeUnit = const Value.absent(),
                Value<String?> noticeToEndOf = const Value.absent(),
                Value<int?> autoRenewMonths = const Value.absent(),
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContractsCompanion(
                id: id,
                documentId: documentId,
                correspondentId: correspondentId,
                title: title,
                amountCents: amountCents,
                interval: interval,
                startDate: startDate,
                minTermUntil: minTermUntil,
                noticeValue: noticeValue,
                noticeUnit: noticeUnit,
                noticeToEndOf: noticeToEndOf,
                autoRenewMonths: autoRenewMonths,
                cancelledAt: cancelledAt,
                endsAt: endsAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String?> correspondentId = const Value.absent(),
                required String title,
                Value<int?> amountCents = const Value.absent(),
                Value<String> interval = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> minTermUntil = const Value.absent(),
                Value<int?> noticeValue = const Value.absent(),
                Value<String?> noticeUnit = const Value.absent(),
                Value<String?> noticeToEndOf = const Value.absent(),
                Value<int?> autoRenewMonths = const Value.absent(),
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContractsCompanion.insert(
                id: id,
                documentId: documentId,
                correspondentId: correspondentId,
                title: title,
                amountCents: amountCents,
                interval: interval,
                startDate: startDate,
                minTermUntil: minTermUntil,
                noticeValue: noticeValue,
                noticeUnit: noticeUnit,
                noticeToEndOf: noticeToEndOf,
                autoRenewMonths: autoRenewMonths,
                cancelledAt: cancelledAt,
                endsAt: endsAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContractsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContractsTable,
      Contract,
      $$ContractsTableFilterComposer,
      $$ContractsTableOrderingComposer,
      $$ContractsTableAnnotationComposer,
      $$ContractsTableCreateCompanionBuilder,
      $$ContractsTableUpdateCompanionBuilder,
      (Contract, BaseReferences<_$AppDatabase, $ContractsTable, Contract>),
      Contract,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      required String documentId,
      required String kind,
      required String relPath,
      Value<String> mime,
      Value<String> caption,
      Value<int> sizeBytes,
      Value<String?> sha256,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String> kind,
      Value<String> relPath,
      Value<String> mime,
      Value<String> caption,
      Value<int> sizeBytes,
      Value<String?> sha256,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            Attachment,
            BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
          ),
          Attachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String> caption = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                documentId: documentId,
                kind: kind,
                relPath: relPath,
                mime: mime,
                caption: caption,
                sizeBytes: sizeBytes,
                sha256: sha256,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String documentId,
                required String kind,
                required String relPath,
                Value<String> mime = const Value.absent(),
                Value<String> caption = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                documentId: documentId,
                kind: kind,
                relPath: relPath,
                mime: mime,
                caption: caption,
                sizeBytes: sizeBytes,
                sha256: sha256,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        Attachment,
        BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
      ),
      Attachment,
      PrefetchHooks Function()
    >;
typedef $$PersonalDataTableCreateCompanionBuilder =
    PersonalDataCompanion Function({
      Value<String> id,
      required String person,
      required String key,
      required String label,
      Value<String> value,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$PersonalDataTableUpdateCompanionBuilder =
    PersonalDataCompanion Function({
      Value<String> id,
      Value<String> person,
      Value<String> key,
      Value<String> label,
      Value<String> value,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$PersonalDataTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalDataTable> {
  $$PersonalDataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonalDataTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalDataTable> {
  $$PersonalDataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonalDataTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalDataTable> {
  $$PersonalDataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get person =>
      $composableBuilder(column: $table.person, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PersonalDataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalDataTable,
          PersonalDataData,
          $$PersonalDataTableFilterComposer,
          $$PersonalDataTableOrderingComposer,
          $$PersonalDataTableAnnotationComposer,
          $$PersonalDataTableCreateCompanionBuilder,
          $$PersonalDataTableUpdateCompanionBuilder,
          (
            PersonalDataData,
            BaseReferences<_$AppDatabase, $PersonalDataTable, PersonalDataData>,
          ),
          PersonalDataData,
          PrefetchHooks Function()
        > {
  $$PersonalDataTableTableManager(_$AppDatabase db, $PersonalDataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalDataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalDataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalDataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> person = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalDataCompanion(
                id: id,
                person: person,
                key: key,
                label: label,
                value: value,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String person,
                required String key,
                required String label,
                Value<String> value = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalDataCompanion.insert(
                id: id,
                person: person,
                key: key,
                label: label,
                value: value,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonalDataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalDataTable,
      PersonalDataData,
      $$PersonalDataTableFilterComposer,
      $$PersonalDataTableOrderingComposer,
      $$PersonalDataTableAnnotationComposer,
      $$PersonalDataTableCreateCompanionBuilder,
      $$PersonalDataTableUpdateCompanionBuilder,
      (
        PersonalDataData,
        BaseReferences<_$AppDatabase, $PersonalDataTable, PersonalDataData>,
      ),
      PersonalDataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$CorrespondentsTableTableManager get correspondents =>
      $$CorrespondentsTableTableManager(_db, _db.correspondents);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$DocumentTagsTableTableManager get documentTags =>
      $$DocumentTagsTableTableManager(_db, _db.documentTags);
  $$ExtractedRefsTableTableManager get extractedRefs =>
      $$ExtractedRefsTableTableManager(_db, _db.extractedRefs);
  $$CountersTableTableManager get counters =>
      $$CountersTableTableManager(_db, _db.counters);
  $$ClaimsTableTableManager get claims =>
      $$ClaimsTableTableManager(_db, _db.claims);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SignatureTemplatesTableTableManager get signatureTemplates =>
      $$SignatureTemplatesTableTableManager(_db, _db.signatureTemplates);
  $$DocTasksTableTableManager get docTasks =>
      $$DocTasksTableTableManager(_db, _db.docTasks);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db, _db.cases);
  $$CaseDocumentsTableTableManager get caseDocuments =>
      $$CaseDocumentsTableTableManager(_db, _db.caseDocuments);
  $$ContractsTableTableManager get contracts =>
      $$ContractsTableTableManager(_db, _db.contracts);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$PersonalDataTableTableManager get personalData =>
      $$PersonalDataTableTableManager(_db, _db.personalData);
}
