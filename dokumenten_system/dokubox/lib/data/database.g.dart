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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    updatedAt,
    deletedAt,
  );
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

  /// Zuletzt bestätigte Werte — Grundlage der „lernenden Zuordnungen".
  final String? defaultDocType;
  final String defaultTagIds;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Correspondent({
    required this.id,
    required this.name,
    required this.aliases,
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
    Value<String?> defaultDocType = const Value.absent(),
    String? defaultTagIds,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Correspondent(
    id: id ?? this.id,
    name: name ?? this.name,
    aliases: aliases ?? this.aliases,
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
          other.defaultDocType == this.defaultDocType &&
          other.defaultTagIds == this.defaultTagIds &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CorrespondentsCompanion extends UpdateCompanion<Correspondent> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> aliases;
  final Value<String?> defaultDocType;
  final Value<String> defaultTagIds;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CorrespondentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.aliases = const Value.absent(),
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $CorrespondentsTable correspondents = $CorrespondentsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $DocumentTagsTable documentTags = $DocumentTagsTable(this);
  late final $ExtractedRefsTable extractedRefs = $ExtractedRefsTable(this);
  late final $CountersTable counters = $CountersTable(this);
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
                Value<String?> defaultDocType = const Value.absent(),
                Value<String> defaultTagIds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrespondentsCompanion(
                id: id,
                name: name,
                aliases: aliases,
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
                Value<String?> defaultDocType = const Value.absent(),
                Value<String> defaultTagIds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrespondentsCompanion.insert(
                id: id,
                name: name,
                aliases: aliases,
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
}
