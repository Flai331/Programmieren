// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $SeriesTableTable extends SeriesTable
    with TableInfo<$SeriesTableTable, Series> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _baendeGesamtMeta = const VerificationMeta(
    'baendeGesamt',
  );
  @override
  late final GeneratedColumn<int> baendeGesamt = GeneratedColumn<int>(
    'baende_gesamt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abgeschlossenMeta = const VerificationMeta(
    'abgeschlossen',
  );
  @override
  late final GeneratedColumn<bool> abgeschlossen = GeneratedColumn<bool>(
    'abgeschlossen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("abgeschlossen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _viertelPositionMeta = const VerificationMeta(
    'viertelPosition',
  );
  @override
  late final GeneratedColumn<int> viertelPosition = GeneratedColumn<int>(
    'viertel_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baendeGesamt,
    abgeschlossen,
    viertelPosition,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<Series> instance, {
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
    if (data.containsKey('baende_gesamt')) {
      context.handle(
        _baendeGesamtMeta,
        baendeGesamt.isAcceptableOrUnknown(
          data['baende_gesamt']!,
          _baendeGesamtMeta,
        ),
      );
    }
    if (data.containsKey('abgeschlossen')) {
      context.handle(
        _abgeschlossenMeta,
        abgeschlossen.isAcceptableOrUnknown(
          data['abgeschlossen']!,
          _abgeschlossenMeta,
        ),
      );
    }
    if (data.containsKey('viertel_position')) {
      context.handle(
        _viertelPositionMeta,
        viertelPosition.isAcceptableOrUnknown(
          data['viertel_position']!,
          _viertelPositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_viertelPositionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Series map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Series(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baendeGesamt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baende_gesamt'],
      ),
      abgeschlossen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}abgeschlossen'],
      )!,
      viertelPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}viertel_position'],
      )!,
    );
  }

  @override
  $SeriesTableTable createAlias(String alias) {
    return $SeriesTableTable(attachedDatabase, alias);
  }
}

class Series extends DataClass implements Insertable<Series> {
  final int id;
  final String name;
  final int? baendeGesamt;

  /// Alle Bände sind erschienen (die Reihe läuft nicht mehr).
  final bool abgeschlossen;

  /// Reihenfolge der Viertel am Stadtrand.
  final int viertelPosition;
  const Series({
    required this.id,
    required this.name,
    this.baendeGesamt,
    required this.abgeschlossen,
    required this.viertelPosition,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || baendeGesamt != null) {
      map['baende_gesamt'] = Variable<int>(baendeGesamt);
    }
    map['abgeschlossen'] = Variable<bool>(abgeschlossen);
    map['viertel_position'] = Variable<int>(viertelPosition);
    return map;
  }

  SeriesTableCompanion toCompanion(bool nullToAbsent) {
    return SeriesTableCompanion(
      id: Value(id),
      name: Value(name),
      baendeGesamt: baendeGesamt == null && nullToAbsent
          ? const Value.absent()
          : Value(baendeGesamt),
      abgeschlossen: Value(abgeschlossen),
      viertelPosition: Value(viertelPosition),
    );
  }

  factory Series.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Series(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baendeGesamt: serializer.fromJson<int?>(json['baendeGesamt']),
      abgeschlossen: serializer.fromJson<bool>(json['abgeschlossen']),
      viertelPosition: serializer.fromJson<int>(json['viertelPosition']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'baendeGesamt': serializer.toJson<int?>(baendeGesamt),
      'abgeschlossen': serializer.toJson<bool>(abgeschlossen),
      'viertelPosition': serializer.toJson<int>(viertelPosition),
    };
  }

  Series copyWith({
    int? id,
    String? name,
    Value<int?> baendeGesamt = const Value.absent(),
    bool? abgeschlossen,
    int? viertelPosition,
  }) => Series(
    id: id ?? this.id,
    name: name ?? this.name,
    baendeGesamt: baendeGesamt.present ? baendeGesamt.value : this.baendeGesamt,
    abgeschlossen: abgeschlossen ?? this.abgeschlossen,
    viertelPosition: viertelPosition ?? this.viertelPosition,
  );
  Series copyWithCompanion(SeriesTableCompanion data) {
    return Series(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baendeGesamt: data.baendeGesamt.present
          ? data.baendeGesamt.value
          : this.baendeGesamt,
      abgeschlossen: data.abgeschlossen.present
          ? data.abgeschlossen.value
          : this.abgeschlossen,
      viertelPosition: data.viertelPosition.present
          ? data.viertelPosition.value
          : this.viertelPosition,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Series(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baendeGesamt: $baendeGesamt, ')
          ..write('abgeschlossen: $abgeschlossen, ')
          ..write('viertelPosition: $viertelPosition')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, baendeGesamt, abgeschlossen, viertelPosition);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Series &&
          other.id == this.id &&
          other.name == this.name &&
          other.baendeGesamt == this.baendeGesamt &&
          other.abgeschlossen == this.abgeschlossen &&
          other.viertelPosition == this.viertelPosition);
}

class SeriesTableCompanion extends UpdateCompanion<Series> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> baendeGesamt;
  final Value<bool> abgeschlossen;
  final Value<int> viertelPosition;
  const SeriesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baendeGesamt = const Value.absent(),
    this.abgeschlossen = const Value.absent(),
    this.viertelPosition = const Value.absent(),
  });
  SeriesTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.baendeGesamt = const Value.absent(),
    this.abgeschlossen = const Value.absent(),
    required int viertelPosition,
  }) : name = Value(name),
       viertelPosition = Value(viertelPosition);
  static Insertable<Series> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? baendeGesamt,
    Expression<bool>? abgeschlossen,
    Expression<int>? viertelPosition,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baendeGesamt != null) 'baende_gesamt': baendeGesamt,
      if (abgeschlossen != null) 'abgeschlossen': abgeschlossen,
      if (viertelPosition != null) 'viertel_position': viertelPosition,
    });
  }

  SeriesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? baendeGesamt,
    Value<bool>? abgeschlossen,
    Value<int>? viertelPosition,
  }) {
    return SeriesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baendeGesamt: baendeGesamt ?? this.baendeGesamt,
      abgeschlossen: abgeschlossen ?? this.abgeschlossen,
      viertelPosition: viertelPosition ?? this.viertelPosition,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baendeGesamt.present) {
      map['baende_gesamt'] = Variable<int>(baendeGesamt.value);
    }
    if (abgeschlossen.present) {
      map['abgeschlossen'] = Variable<bool>(abgeschlossen.value);
    }
    if (viertelPosition.present) {
      map['viertel_position'] = Variable<int>(viertelPosition.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baendeGesamt: $baendeGesamt, ')
          ..write('abgeschlossen: $abgeschlossen, ')
          ..write('viertelPosition: $viertelPosition')
          ..write(')'))
        .toString();
  }
}

class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _isbnMeta = const VerificationMeta('isbn');
  @override
  late final GeneratedColumn<String> isbn = GeneratedColumn<String>(
    'isbn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titelMeta = const VerificationMeta('titel');
  @override
  late final GeneratedColumn<String> titel = GeneratedColumn<String>(
    'titel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autorMeta = const VerificationMeta('autor');
  @override
  late final GeneratedColumn<String> autor = GeneratedColumn<String>(
    'autor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _seitenGesamtMeta = const VerificationMeta(
    'seitenGesamt',
  );
  @override
  late final GeneratedColumn<int> seitenGesamt = GeneratedColumn<int>(
    'seiten_gesamt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Genre>, String> genres =
      GeneratedColumn<String>(
        'genres',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      ).withConverter<List<Genre>>($BooksTable.$convertergenres);
  @override
  late final GeneratedColumnWithTypeConverter<BookStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BookStatus>($BooksTable.$converterstatus);
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id)',
    ),
  );
  static const VerificationMeta _seriesIndexMeta = const VerificationMeta(
    'seriesIndex',
  );
  @override
  late final GeneratedColumn<int> seriesIndex = GeneratedColumn<int>(
    'series_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hinzugefuegtAmMeta = const VerificationMeta(
    'hinzugefuegtAm',
  );
  @override
  late final GeneratedColumn<DateTime> hinzugefuegtAm =
      GeneratedColumn<DateTime>(
        'hinzugefuegt_am',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _beendetAmMeta = const VerificationMeta(
    'beendetAm',
  );
  @override
  late final GeneratedColumn<DateTime> beendetAm = GeneratedColumn<DateTime>(
    'beendet_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isbn,
    titel,
    autor,
    seitenGesamt,
    genres,
    status,
    seriesId,
    seriesIndex,
    notiz,
    hinzugefuegtAm,
    beendetAm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('isbn')) {
      context.handle(
        _isbnMeta,
        isbn.isAcceptableOrUnknown(data['isbn']!, _isbnMeta),
      );
    }
    if (data.containsKey('titel')) {
      context.handle(
        _titelMeta,
        titel.isAcceptableOrUnknown(data['titel']!, _titelMeta),
      );
    } else if (isInserting) {
      context.missing(_titelMeta);
    }
    if (data.containsKey('autor')) {
      context.handle(
        _autorMeta,
        autor.isAcceptableOrUnknown(data['autor']!, _autorMeta),
      );
    }
    if (data.containsKey('seiten_gesamt')) {
      context.handle(
        _seitenGesamtMeta,
        seitenGesamt.isAcceptableOrUnknown(
          data['seiten_gesamt']!,
          _seitenGesamtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seitenGesamtMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('series_index')) {
      context.handle(
        _seriesIndexMeta,
        seriesIndex.isAcceptableOrUnknown(
          data['series_index']!,
          _seriesIndexMeta,
        ),
      );
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    if (data.containsKey('hinzugefuegt_am')) {
      context.handle(
        _hinzugefuegtAmMeta,
        hinzugefuegtAm.isAcceptableOrUnknown(
          data['hinzugefuegt_am']!,
          _hinzugefuegtAmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hinzugefuegtAmMeta);
    }
    if (data.containsKey('beendet_am')) {
      context.handle(
        _beendetAmMeta,
        beendetAm.isAcceptableOrUnknown(data['beendet_am']!, _beendetAmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      isbn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isbn'],
      ),
      titel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titel'],
      )!,
      autor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}autor'],
      )!,
      seitenGesamt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seiten_gesamt'],
      )!,
      genres: $BooksTable.$convertergenres.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}genres'],
        )!,
      ),
      status: $BooksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
      seriesIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_index'],
      ),
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
      hinzugefuegtAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}hinzugefuegt_am'],
      )!,
      beendetAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}beendet_am'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Genre>, String> $convertergenres =
      const GenreListConverter();
  static JsonTypeConverter2<BookStatus, String, String> $converterstatus =
      const EnumNameConverter<BookStatus>(BookStatus.values);
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String? isbn;
  final String titel;
  final String autor;
  final int seitenGesamt;
  final List<Genre> genres;
  final BookStatus status;
  final int? seriesId;
  final int? seriesIndex;
  final String? notiz;
  final DateTime hinzugefuegtAm;
  final DateTime? beendetAm;
  const Book({
    required this.id,
    this.isbn,
    required this.titel,
    required this.autor,
    required this.seitenGesamt,
    required this.genres,
    required this.status,
    this.seriesId,
    this.seriesIndex,
    this.notiz,
    required this.hinzugefuegtAm,
    this.beendetAm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || isbn != null) {
      map['isbn'] = Variable<String>(isbn);
    }
    map['titel'] = Variable<String>(titel);
    map['autor'] = Variable<String>(autor);
    map['seiten_gesamt'] = Variable<int>(seitenGesamt);
    {
      map['genres'] = Variable<String>(
        $BooksTable.$convertergenres.toSql(genres),
      );
    }
    {
      map['status'] = Variable<String>(
        $BooksTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    if (!nullToAbsent || seriesIndex != null) {
      map['series_index'] = Variable<int>(seriesIndex);
    }
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    map['hinzugefuegt_am'] = Variable<DateTime>(hinzugefuegtAm);
    if (!nullToAbsent || beendetAm != null) {
      map['beendet_am'] = Variable<DateTime>(beendetAm);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      isbn: isbn == null && nullToAbsent ? const Value.absent() : Value(isbn),
      titel: Value(titel),
      autor: Value(autor),
      seitenGesamt: Value(seitenGesamt),
      genres: Value(genres),
      status: Value(status),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      seriesIndex: seriesIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesIndex),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
      hinzugefuegtAm: Value(hinzugefuegtAm),
      beendetAm: beendetAm == null && nullToAbsent
          ? const Value.absent()
          : Value(beendetAm),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      isbn: serializer.fromJson<String?>(json['isbn']),
      titel: serializer.fromJson<String>(json['titel']),
      autor: serializer.fromJson<String>(json['autor']),
      seitenGesamt: serializer.fromJson<int>(json['seitenGesamt']),
      genres: serializer.fromJson<List<Genre>>(json['genres']),
      status: $BooksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
      seriesIndex: serializer.fromJson<int?>(json['seriesIndex']),
      notiz: serializer.fromJson<String?>(json['notiz']),
      hinzugefuegtAm: serializer.fromJson<DateTime>(json['hinzugefuegtAm']),
      beendetAm: serializer.fromJson<DateTime?>(json['beendetAm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isbn': serializer.toJson<String?>(isbn),
      'titel': serializer.toJson<String>(titel),
      'autor': serializer.toJson<String>(autor),
      'seitenGesamt': serializer.toJson<int>(seitenGesamt),
      'genres': serializer.toJson<List<Genre>>(genres),
      'status': serializer.toJson<String>(
        $BooksTable.$converterstatus.toJson(status),
      ),
      'seriesId': serializer.toJson<int?>(seriesId),
      'seriesIndex': serializer.toJson<int?>(seriesIndex),
      'notiz': serializer.toJson<String?>(notiz),
      'hinzugefuegtAm': serializer.toJson<DateTime>(hinzugefuegtAm),
      'beendetAm': serializer.toJson<DateTime?>(beendetAm),
    };
  }

  Book copyWith({
    int? id,
    Value<String?> isbn = const Value.absent(),
    String? titel,
    String? autor,
    int? seitenGesamt,
    List<Genre>? genres,
    BookStatus? status,
    Value<int?> seriesId = const Value.absent(),
    Value<int?> seriesIndex = const Value.absent(),
    Value<String?> notiz = const Value.absent(),
    DateTime? hinzugefuegtAm,
    Value<DateTime?> beendetAm = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    isbn: isbn.present ? isbn.value : this.isbn,
    titel: titel ?? this.titel,
    autor: autor ?? this.autor,
    seitenGesamt: seitenGesamt ?? this.seitenGesamt,
    genres: genres ?? this.genres,
    status: status ?? this.status,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    seriesIndex: seriesIndex.present ? seriesIndex.value : this.seriesIndex,
    notiz: notiz.present ? notiz.value : this.notiz,
    hinzugefuegtAm: hinzugefuegtAm ?? this.hinzugefuegtAm,
    beendetAm: beendetAm.present ? beendetAm.value : this.beendetAm,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      isbn: data.isbn.present ? data.isbn.value : this.isbn,
      titel: data.titel.present ? data.titel.value : this.titel,
      autor: data.autor.present ? data.autor.value : this.autor,
      seitenGesamt: data.seitenGesamt.present
          ? data.seitenGesamt.value
          : this.seitenGesamt,
      genres: data.genres.present ? data.genres.value : this.genres,
      status: data.status.present ? data.status.value : this.status,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seriesIndex: data.seriesIndex.present
          ? data.seriesIndex.value
          : this.seriesIndex,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
      hinzugefuegtAm: data.hinzugefuegtAm.present
          ? data.hinzugefuegtAm.value
          : this.hinzugefuegtAm,
      beendetAm: data.beendetAm.present ? data.beendetAm.value : this.beendetAm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('isbn: $isbn, ')
          ..write('titel: $titel, ')
          ..write('autor: $autor, ')
          ..write('seitenGesamt: $seitenGesamt, ')
          ..write('genres: $genres, ')
          ..write('status: $status, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesIndex: $seriesIndex, ')
          ..write('notiz: $notiz, ')
          ..write('hinzugefuegtAm: $hinzugefuegtAm, ')
          ..write('beendetAm: $beendetAm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    isbn,
    titel,
    autor,
    seitenGesamt,
    genres,
    status,
    seriesId,
    seriesIndex,
    notiz,
    hinzugefuegtAm,
    beendetAm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.isbn == this.isbn &&
          other.titel == this.titel &&
          other.autor == this.autor &&
          other.seitenGesamt == this.seitenGesamt &&
          other.genres == this.genres &&
          other.status == this.status &&
          other.seriesId == this.seriesId &&
          other.seriesIndex == this.seriesIndex &&
          other.notiz == this.notiz &&
          other.hinzugefuegtAm == this.hinzugefuegtAm &&
          other.beendetAm == this.beendetAm);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String?> isbn;
  final Value<String> titel;
  final Value<String> autor;
  final Value<int> seitenGesamt;
  final Value<List<Genre>> genres;
  final Value<BookStatus> status;
  final Value<int?> seriesId;
  final Value<int?> seriesIndex;
  final Value<String?> notiz;
  final Value<DateTime> hinzugefuegtAm;
  final Value<DateTime?> beendetAm;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.isbn = const Value.absent(),
    this.titel = const Value.absent(),
    this.autor = const Value.absent(),
    this.seitenGesamt = const Value.absent(),
    this.genres = const Value.absent(),
    this.status = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesIndex = const Value.absent(),
    this.notiz = const Value.absent(),
    this.hinzugefuegtAm = const Value.absent(),
    this.beendetAm = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    this.isbn = const Value.absent(),
    required String titel,
    this.autor = const Value.absent(),
    required int seitenGesamt,
    this.genres = const Value.absent(),
    required BookStatus status,
    this.seriesId = const Value.absent(),
    this.seriesIndex = const Value.absent(),
    this.notiz = const Value.absent(),
    required DateTime hinzugefuegtAm,
    this.beendetAm = const Value.absent(),
  }) : titel = Value(titel),
       seitenGesamt = Value(seitenGesamt),
       status = Value(status),
       hinzugefuegtAm = Value(hinzugefuegtAm);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? isbn,
    Expression<String>? titel,
    Expression<String>? autor,
    Expression<int>? seitenGesamt,
    Expression<String>? genres,
    Expression<String>? status,
    Expression<int>? seriesId,
    Expression<int>? seriesIndex,
    Expression<String>? notiz,
    Expression<DateTime>? hinzugefuegtAm,
    Expression<DateTime>? beendetAm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isbn != null) 'isbn': isbn,
      if (titel != null) 'titel': titel,
      if (autor != null) 'autor': autor,
      if (seitenGesamt != null) 'seiten_gesamt': seitenGesamt,
      if (genres != null) 'genres': genres,
      if (status != null) 'status': status,
      if (seriesId != null) 'series_id': seriesId,
      if (seriesIndex != null) 'series_index': seriesIndex,
      if (notiz != null) 'notiz': notiz,
      if (hinzugefuegtAm != null) 'hinzugefuegt_am': hinzugefuegtAm,
      if (beendetAm != null) 'beendet_am': beendetAm,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String?>? isbn,
    Value<String>? titel,
    Value<String>? autor,
    Value<int>? seitenGesamt,
    Value<List<Genre>>? genres,
    Value<BookStatus>? status,
    Value<int?>? seriesId,
    Value<int?>? seriesIndex,
    Value<String?>? notiz,
    Value<DateTime>? hinzugefuegtAm,
    Value<DateTime?>? beendetAm,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      titel: titel ?? this.titel,
      autor: autor ?? this.autor,
      seitenGesamt: seitenGesamt ?? this.seitenGesamt,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      seriesId: seriesId ?? this.seriesId,
      seriesIndex: seriesIndex ?? this.seriesIndex,
      notiz: notiz ?? this.notiz,
      hinzugefuegtAm: hinzugefuegtAm ?? this.hinzugefuegtAm,
      beendetAm: beendetAm ?? this.beendetAm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isbn.present) {
      map['isbn'] = Variable<String>(isbn.value);
    }
    if (titel.present) {
      map['titel'] = Variable<String>(titel.value);
    }
    if (autor.present) {
      map['autor'] = Variable<String>(autor.value);
    }
    if (seitenGesamt.present) {
      map['seiten_gesamt'] = Variable<int>(seitenGesamt.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(
        $BooksTable.$convertergenres.toSql(genres.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $BooksTable.$converterstatus.toSql(status.value),
      );
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (seriesIndex.present) {
      map['series_index'] = Variable<int>(seriesIndex.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (hinzugefuegtAm.present) {
      map['hinzugefuegt_am'] = Variable<DateTime>(hinzugefuegtAm.value);
    }
    if (beendetAm.present) {
      map['beendet_am'] = Variable<DateTime>(beendetAm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('isbn: $isbn, ')
          ..write('titel: $titel, ')
          ..write('autor: $autor, ')
          ..write('seitenGesamt: $seitenGesamt, ')
          ..write('genres: $genres, ')
          ..write('status: $status, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesIndex: $seriesIndex, ')
          ..write('notiz: $notiz, ')
          ..write('hinzugefuegtAm: $hinzugefuegtAm, ')
          ..write('beendetAm: $beendetAm')
          ..write(')'))
        .toString();
  }
}

class $ReadingEntriesTable extends ReadingEntries
    with TableInfo<$ReadingEntriesTable, ReadingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _datumMeta = const VerificationMeta('datum');
  @override
  late final GeneratedColumn<DateTime> datum = GeneratedColumn<DateTime>(
    'datum',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vonSeiteMeta = const VerificationMeta(
    'vonSeite',
  );
  @override
  late final GeneratedColumn<int> vonSeite = GeneratedColumn<int>(
    'von_seite',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bisSeiteMeta = const VerificationMeta(
    'bisSeite',
  );
  @override
  late final GeneratedColumn<int> bisSeite = GeneratedColumn<int>(
    'bis_seite',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bookId, datum, vonSeite, bisSeite];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('datum')) {
      context.handle(
        _datumMeta,
        datum.isAcceptableOrUnknown(data['datum']!, _datumMeta),
      );
    } else if (isInserting) {
      context.missing(_datumMeta);
    }
    if (data.containsKey('von_seite')) {
      context.handle(
        _vonSeiteMeta,
        vonSeite.isAcceptableOrUnknown(data['von_seite']!, _vonSeiteMeta),
      );
    } else if (isInserting) {
      context.missing(_vonSeiteMeta);
    }
    if (data.containsKey('bis_seite')) {
      context.handle(
        _bisSeiteMeta,
        bisSeite.isAcceptableOrUnknown(data['bis_seite']!, _bisSeiteMeta),
      );
    } else if (isInserting) {
      context.missing(_bisSeiteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      datum: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}datum'],
      )!,
      vonSeite: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}von_seite'],
      )!,
      bisSeite: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bis_seite'],
      )!,
    );
  }

  @override
  $ReadingEntriesTable createAlias(String alias) {
    return $ReadingEntriesTable(attachedDatabase, alias);
  }
}

class ReadingEntry extends DataClass implements Insertable<ReadingEntry> {
  final int id;
  final int bookId;
  final DateTime datum;
  final int vonSeite;
  final int bisSeite;
  const ReadingEntry({
    required this.id,
    required this.bookId,
    required this.datum,
    required this.vonSeite,
    required this.bisSeite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['datum'] = Variable<DateTime>(datum);
    map['von_seite'] = Variable<int>(vonSeite);
    map['bis_seite'] = Variable<int>(bisSeite);
    return map;
  }

  ReadingEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReadingEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      datum: Value(datum),
      vonSeite: Value(vonSeite),
      bisSeite: Value(bisSeite),
    );
  }

  factory ReadingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingEntry(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      datum: serializer.fromJson<DateTime>(json['datum']),
      vonSeite: serializer.fromJson<int>(json['vonSeite']),
      bisSeite: serializer.fromJson<int>(json['bisSeite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'datum': serializer.toJson<DateTime>(datum),
      'vonSeite': serializer.toJson<int>(vonSeite),
      'bisSeite': serializer.toJson<int>(bisSeite),
    };
  }

  ReadingEntry copyWith({
    int? id,
    int? bookId,
    DateTime? datum,
    int? vonSeite,
    int? bisSeite,
  }) => ReadingEntry(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    datum: datum ?? this.datum,
    vonSeite: vonSeite ?? this.vonSeite,
    bisSeite: bisSeite ?? this.bisSeite,
  );
  ReadingEntry copyWithCompanion(ReadingEntriesCompanion data) {
    return ReadingEntry(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      datum: data.datum.present ? data.datum.value : this.datum,
      vonSeite: data.vonSeite.present ? data.vonSeite.value : this.vonSeite,
      bisSeite: data.bisSeite.present ? data.bisSeite.value : this.bisSeite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingEntry(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('datum: $datum, ')
          ..write('vonSeite: $vonSeite, ')
          ..write('bisSeite: $bisSeite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, datum, vonSeite, bisSeite);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingEntry &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.datum == this.datum &&
          other.vonSeite == this.vonSeite &&
          other.bisSeite == this.bisSeite);
}

class ReadingEntriesCompanion extends UpdateCompanion<ReadingEntry> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<DateTime> datum;
  final Value<int> vonSeite;
  final Value<int> bisSeite;
  const ReadingEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.datum = const Value.absent(),
    this.vonSeite = const Value.absent(),
    this.bisSeite = const Value.absent(),
  });
  ReadingEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required DateTime datum,
    required int vonSeite,
    required int bisSeite,
  }) : bookId = Value(bookId),
       datum = Value(datum),
       vonSeite = Value(vonSeite),
       bisSeite = Value(bisSeite);
  static Insertable<ReadingEntry> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<DateTime>? datum,
    Expression<int>? vonSeite,
    Expression<int>? bisSeite,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (datum != null) 'datum': datum,
      if (vonSeite != null) 'von_seite': vonSeite,
      if (bisSeite != null) 'bis_seite': bisSeite,
    });
  }

  ReadingEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<DateTime>? datum,
    Value<int>? vonSeite,
    Value<int>? bisSeite,
  }) {
    return ReadingEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      datum: datum ?? this.datum,
      vonSeite: vonSeite ?? this.vonSeite,
      bisSeite: bisSeite ?? this.bisSeite,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (datum.present) {
      map['datum'] = Variable<DateTime>(datum.value);
    }
    if (vonSeite.present) {
      map['von_seite'] = Variable<int>(vonSeite.value);
    }
    if (bisSeite.present) {
      map['bis_seite'] = Variable<int>(bisSeite.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('datum: $datum, ')
          ..write('vonSeite: $vonSeite, ')
          ..write('bisSeite: $bisSeite')
          ..write(')'))
        .toString();
  }
}

class $BuildingsTable extends Buildings
    with TableInfo<$BuildingsTable, Building> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuildingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<int> x = GeneratedColumn<int>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<int> y = GeneratedColumn<int>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jahrMeta = const VerificationMeta('jahr');
  @override
  late final GeneratedColumn<int> jahr = GeneratedColumn<int>(
    'jahr',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gebautAmMeta = const VerificationMeta(
    'gebautAm',
  );
  @override
  late final GeneratedColumn<DateTime> gebautAm = GeneratedColumn<DateTime>(
    'gebaut_am',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    typeId,
    x,
    y,
    bookId,
    seriesId,
    jahr,
    gebautAm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buildings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Building> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('jahr')) {
      context.handle(
        _jahrMeta,
        jahr.isAcceptableOrUnknown(data['jahr']!, _jahrMeta),
      );
    }
    if (data.containsKey('gebaut_am')) {
      context.handle(
        _gebautAmMeta,
        gebautAm.isAcceptableOrUnknown(data['gebaut_am']!, _gebautAmMeta),
      );
    } else if (isInserting) {
      context.missing(_gebautAmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Building map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Building(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}y'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
      jahr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jahr'],
      ),
      gebautAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gebaut_am'],
      )!,
    );
  }

  @override
  $BuildingsTable createAlias(String alias) {
    return $BuildingsTable(attachedDatabase, alias);
  }
}

class Building extends DataClass implements Insertable<Building> {
  final int id;
  final String typeId;
  final int x;
  final int y;
  final int? bookId;
  final int? seriesId;

  /// Jahr eines Jahresbauwerks.
  final int? jahr;
  final DateTime gebautAm;
  const Building({
    required this.id,
    required this.typeId,
    required this.x,
    required this.y,
    this.bookId,
    this.seriesId,
    this.jahr,
    required this.gebautAm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type_id'] = Variable<String>(typeId);
    map['x'] = Variable<int>(x);
    map['y'] = Variable<int>(y);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<int>(bookId);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    if (!nullToAbsent || jahr != null) {
      map['jahr'] = Variable<int>(jahr);
    }
    map['gebaut_am'] = Variable<DateTime>(gebautAm);
    return map;
  }

  BuildingsCompanion toCompanion(bool nullToAbsent) {
    return BuildingsCompanion(
      id: Value(id),
      typeId: Value(typeId),
      x: Value(x),
      y: Value(y),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      jahr: jahr == null && nullToAbsent ? const Value.absent() : Value(jahr),
      gebautAm: Value(gebautAm),
    );
  }

  factory Building.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Building(
      id: serializer.fromJson<int>(json['id']),
      typeId: serializer.fromJson<String>(json['typeId']),
      x: serializer.fromJson<int>(json['x']),
      y: serializer.fromJson<int>(json['y']),
      bookId: serializer.fromJson<int?>(json['bookId']),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
      jahr: serializer.fromJson<int?>(json['jahr']),
      gebautAm: serializer.fromJson<DateTime>(json['gebautAm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'typeId': serializer.toJson<String>(typeId),
      'x': serializer.toJson<int>(x),
      'y': serializer.toJson<int>(y),
      'bookId': serializer.toJson<int?>(bookId),
      'seriesId': serializer.toJson<int?>(seriesId),
      'jahr': serializer.toJson<int?>(jahr),
      'gebautAm': serializer.toJson<DateTime>(gebautAm),
    };
  }

  Building copyWith({
    int? id,
    String? typeId,
    int? x,
    int? y,
    Value<int?> bookId = const Value.absent(),
    Value<int?> seriesId = const Value.absent(),
    Value<int?> jahr = const Value.absent(),
    DateTime? gebautAm,
  }) => Building(
    id: id ?? this.id,
    typeId: typeId ?? this.typeId,
    x: x ?? this.x,
    y: y ?? this.y,
    bookId: bookId.present ? bookId.value : this.bookId,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    jahr: jahr.present ? jahr.value : this.jahr,
    gebautAm: gebautAm ?? this.gebautAm,
  );
  Building copyWithCompanion(BuildingsCompanion data) {
    return Building(
      id: data.id.present ? data.id.value : this.id,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      jahr: data.jahr.present ? data.jahr.value : this.jahr,
      gebautAm: data.gebautAm.present ? data.gebautAm.value : this.gebautAm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Building(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('bookId: $bookId, ')
          ..write('seriesId: $seriesId, ')
          ..write('jahr: $jahr, ')
          ..write('gebautAm: $gebautAm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, typeId, x, y, bookId, seriesId, jahr, gebautAm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Building &&
          other.id == this.id &&
          other.typeId == this.typeId &&
          other.x == this.x &&
          other.y == this.y &&
          other.bookId == this.bookId &&
          other.seriesId == this.seriesId &&
          other.jahr == this.jahr &&
          other.gebautAm == this.gebautAm);
}

class BuildingsCompanion extends UpdateCompanion<Building> {
  final Value<int> id;
  final Value<String> typeId;
  final Value<int> x;
  final Value<int> y;
  final Value<int?> bookId;
  final Value<int?> seriesId;
  final Value<int?> jahr;
  final Value<DateTime> gebautAm;
  const BuildingsCompanion({
    this.id = const Value.absent(),
    this.typeId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.bookId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.jahr = const Value.absent(),
    this.gebautAm = const Value.absent(),
  });
  BuildingsCompanion.insert({
    this.id = const Value.absent(),
    required String typeId,
    required int x,
    required int y,
    this.bookId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.jahr = const Value.absent(),
    required DateTime gebautAm,
  }) : typeId = Value(typeId),
       x = Value(x),
       y = Value(y),
       gebautAm = Value(gebautAm);
  static Insertable<Building> custom({
    Expression<int>? id,
    Expression<String>? typeId,
    Expression<int>? x,
    Expression<int>? y,
    Expression<int>? bookId,
    Expression<int>? seriesId,
    Expression<int>? jahr,
    Expression<DateTime>? gebautAm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (typeId != null) 'type_id': typeId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (bookId != null) 'book_id': bookId,
      if (seriesId != null) 'series_id': seriesId,
      if (jahr != null) 'jahr': jahr,
      if (gebautAm != null) 'gebaut_am': gebautAm,
    });
  }

  BuildingsCompanion copyWith({
    Value<int>? id,
    Value<String>? typeId,
    Value<int>? x,
    Value<int>? y,
    Value<int?>? bookId,
    Value<int?>? seriesId,
    Value<int?>? jahr,
    Value<DateTime>? gebautAm,
  }) {
    return BuildingsCompanion(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      x: x ?? this.x,
      y: y ?? this.y,
      bookId: bookId ?? this.bookId,
      seriesId: seriesId ?? this.seriesId,
      jahr: jahr ?? this.jahr,
      gebautAm: gebautAm ?? this.gebautAm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (x.present) {
      map['x'] = Variable<int>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<int>(y.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (jahr.present) {
      map['jahr'] = Variable<int>(jahr.value);
    }
    if (gebautAm.present) {
      map['gebaut_am'] = Variable<DateTime>(gebautAm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuildingsCompanion(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('bookId: $bookId, ')
          ..write('seriesId: $seriesId, ')
          ..write('jahr: $jahr, ')
          ..write('gebautAm: $gebautAm')
          ..write(')'))
        .toString();
  }
}

class $YearGoalsTable extends YearGoals
    with TableInfo<$YearGoalsTable, YearGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $YearGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jahrMeta = const VerificationMeta('jahr');
  @override
  late final GeneratedColumn<int> jahr = GeneratedColumn<int>(
    'jahr',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zielBuecherMeta = const VerificationMeta(
    'zielBuecher',
  );
  @override
  late final GeneratedColumn<int> zielBuecher = GeneratedColumn<int>(
    'ziel_buecher',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [jahr, zielBuecher];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'year_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<YearGoal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jahr')) {
      context.handle(
        _jahrMeta,
        jahr.isAcceptableOrUnknown(data['jahr']!, _jahrMeta),
      );
    }
    if (data.containsKey('ziel_buecher')) {
      context.handle(
        _zielBuecherMeta,
        zielBuecher.isAcceptableOrUnknown(
          data['ziel_buecher']!,
          _zielBuecherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_zielBuecherMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jahr};
  @override
  YearGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return YearGoal(
      jahr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jahr'],
      )!,
      zielBuecher: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ziel_buecher'],
      )!,
    );
  }

  @override
  $YearGoalsTable createAlias(String alias) {
    return $YearGoalsTable(attachedDatabase, alias);
  }
}

class YearGoal extends DataClass implements Insertable<YearGoal> {
  final int jahr;
  final int zielBuecher;
  const YearGoal({required this.jahr, required this.zielBuecher});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['jahr'] = Variable<int>(jahr);
    map['ziel_buecher'] = Variable<int>(zielBuecher);
    return map;
  }

  YearGoalsCompanion toCompanion(bool nullToAbsent) {
    return YearGoalsCompanion(
      jahr: Value(jahr),
      zielBuecher: Value(zielBuecher),
    );
  }

  factory YearGoal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return YearGoal(
      jahr: serializer.fromJson<int>(json['jahr']),
      zielBuecher: serializer.fromJson<int>(json['zielBuecher']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jahr': serializer.toJson<int>(jahr),
      'zielBuecher': serializer.toJson<int>(zielBuecher),
    };
  }

  YearGoal copyWith({int? jahr, int? zielBuecher}) => YearGoal(
    jahr: jahr ?? this.jahr,
    zielBuecher: zielBuecher ?? this.zielBuecher,
  );
  YearGoal copyWithCompanion(YearGoalsCompanion data) {
    return YearGoal(
      jahr: data.jahr.present ? data.jahr.value : this.jahr,
      zielBuecher: data.zielBuecher.present
          ? data.zielBuecher.value
          : this.zielBuecher,
    );
  }

  @override
  String toString() {
    return (StringBuffer('YearGoal(')
          ..write('jahr: $jahr, ')
          ..write('zielBuecher: $zielBuecher')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(jahr, zielBuecher);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YearGoal &&
          other.jahr == this.jahr &&
          other.zielBuecher == this.zielBuecher);
}

class YearGoalsCompanion extends UpdateCompanion<YearGoal> {
  final Value<int> jahr;
  final Value<int> zielBuecher;
  const YearGoalsCompanion({
    this.jahr = const Value.absent(),
    this.zielBuecher = const Value.absent(),
  });
  YearGoalsCompanion.insert({
    this.jahr = const Value.absent(),
    required int zielBuecher,
  }) : zielBuecher = Value(zielBuecher);
  static Insertable<YearGoal> custom({
    Expression<int>? jahr,
    Expression<int>? zielBuecher,
  }) {
    return RawValuesInsertable({
      if (jahr != null) 'jahr': jahr,
      if (zielBuecher != null) 'ziel_buecher': zielBuecher,
    });
  }

  YearGoalsCompanion copyWith({Value<int>? jahr, Value<int>? zielBuecher}) {
    return YearGoalsCompanion(
      jahr: jahr ?? this.jahr,
      zielBuecher: zielBuecher ?? this.zielBuecher,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jahr.present) {
      map['jahr'] = Variable<int>(jahr.value);
    }
    if (zielBuecher.present) {
      map['ziel_buecher'] = Variable<int>(zielBuecher.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('YearGoalsCompanion(')
          ..write('jahr: $jahr, ')
          ..write('zielBuecher: $zielBuecher')
          ..write(')'))
        .toString();
  }
}

class $CitySnapshotsTable extends CitySnapshots
    with TableInfo<$CitySnapshotsTable, CitySnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CitySnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _datumMeta = const VerificationMeta('datum');
  @override
  late final GeneratedColumn<DateTime> datum = GeneratedColumn<DateTime>(
    'datum',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gebaeudeJsonMeta = const VerificationMeta(
    'gebaeudeJson',
  );
  @override
  late final GeneratedColumn<String> gebaeudeJson = GeneratedColumn<String>(
    'gebaeude_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, datum, gebaeudeJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'city_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<CitySnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('datum')) {
      context.handle(
        _datumMeta,
        datum.isAcceptableOrUnknown(data['datum']!, _datumMeta),
      );
    } else if (isInserting) {
      context.missing(_datumMeta);
    }
    if (data.containsKey('gebaeude_json')) {
      context.handle(
        _gebaeudeJsonMeta,
        gebaeudeJson.isAcceptableOrUnknown(
          data['gebaeude_json']!,
          _gebaeudeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gebaeudeJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CitySnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CitySnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      datum: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}datum'],
      )!,
      gebaeudeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gebaeude_json'],
      )!,
    );
  }

  @override
  $CitySnapshotsTable createAlias(String alias) {
    return $CitySnapshotsTable(attachedDatabase, alias);
  }
}

class CitySnapshot extends DataClass implements Insertable<CitySnapshot> {
  final int id;
  final DateTime datum;
  final String gebaeudeJson;
  const CitySnapshot({
    required this.id,
    required this.datum,
    required this.gebaeudeJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['datum'] = Variable<DateTime>(datum);
    map['gebaeude_json'] = Variable<String>(gebaeudeJson);
    return map;
  }

  CitySnapshotsCompanion toCompanion(bool nullToAbsent) {
    return CitySnapshotsCompanion(
      id: Value(id),
      datum: Value(datum),
      gebaeudeJson: Value(gebaeudeJson),
    );
  }

  factory CitySnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CitySnapshot(
      id: serializer.fromJson<int>(json['id']),
      datum: serializer.fromJson<DateTime>(json['datum']),
      gebaeudeJson: serializer.fromJson<String>(json['gebaeudeJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datum': serializer.toJson<DateTime>(datum),
      'gebaeudeJson': serializer.toJson<String>(gebaeudeJson),
    };
  }

  CitySnapshot copyWith({int? id, DateTime? datum, String? gebaeudeJson}) =>
      CitySnapshot(
        id: id ?? this.id,
        datum: datum ?? this.datum,
        gebaeudeJson: gebaeudeJson ?? this.gebaeudeJson,
      );
  CitySnapshot copyWithCompanion(CitySnapshotsCompanion data) {
    return CitySnapshot(
      id: data.id.present ? data.id.value : this.id,
      datum: data.datum.present ? data.datum.value : this.datum,
      gebaeudeJson: data.gebaeudeJson.present
          ? data.gebaeudeJson.value
          : this.gebaeudeJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CitySnapshot(')
          ..write('id: $id, ')
          ..write('datum: $datum, ')
          ..write('gebaeudeJson: $gebaeudeJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, datum, gebaeudeJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CitySnapshot &&
          other.id == this.id &&
          other.datum == this.datum &&
          other.gebaeudeJson == this.gebaeudeJson);
}

class CitySnapshotsCompanion extends UpdateCompanion<CitySnapshot> {
  final Value<int> id;
  final Value<DateTime> datum;
  final Value<String> gebaeudeJson;
  const CitySnapshotsCompanion({
    this.id = const Value.absent(),
    this.datum = const Value.absent(),
    this.gebaeudeJson = const Value.absent(),
  });
  CitySnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime datum,
    required String gebaeudeJson,
  }) : datum = Value(datum),
       gebaeudeJson = Value(gebaeudeJson);
  static Insertable<CitySnapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? datum,
    Expression<String>? gebaeudeJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datum != null) 'datum': datum,
      if (gebaeudeJson != null) 'gebaeude_json': gebaeudeJson,
    });
  }

  CitySnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? datum,
    Value<String>? gebaeudeJson,
  }) {
    return CitySnapshotsCompanion(
      id: id ?? this.id,
      datum: datum ?? this.datum,
      gebaeudeJson: gebaeudeJson ?? this.gebaeudeJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datum.present) {
      map['datum'] = Variable<DateTime>(datum.value);
    }
    if (gebaeudeJson.present) {
      map['gebaeude_json'] = Variable<String>(gebaeudeJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CitySnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('datum: $datum, ')
          ..write('gebaeudeJson: $gebaeudeJson')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SeriesTableTable seriesTable = $SeriesTableTable(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ReadingEntriesTable readingEntries = $ReadingEntriesTable(this);
  late final $BuildingsTable buildings = $BuildingsTable(this);
  late final $YearGoalsTable yearGoals = $YearGoalsTable(this);
  late final $CitySnapshotsTable citySnapshots = $CitySnapshotsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    seriesTable,
    books,
    readingEntries,
    buildings,
    yearGoals,
    citySnapshots,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('buildings', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SeriesTableTableCreateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> baendeGesamt,
      Value<bool> abgeschlossen,
      required int viertelPosition,
    });
typedef $$SeriesTableTableUpdateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> baendeGesamt,
      Value<bool> abgeschlossen,
      Value<int> viertelPosition,
    });

final class $$SeriesTableTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTableTable, Series> {
  $$SeriesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BooksTable, List<Book>> _booksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.books,
    aliasName: 'series__id__books__series_id',
  );

  $$BooksTableProcessedTableManager get booksRefs {
    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_booksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baendeGesamt => $composableBuilder(
    column: $table.baendeGesamt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get abgeschlossen => $composableBuilder(
    column: $table.abgeschlossen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get viertelPosition => $composableBuilder(
    column: $table.viertelPosition,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> booksRefs(
    Expression<bool> Function($$BooksTableFilterComposer f) f,
  ) {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baendeGesamt => $composableBuilder(
    column: $table.baendeGesamt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get abgeschlossen => $composableBuilder(
    column: $table.abgeschlossen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get viertelPosition => $composableBuilder(
    column: $table.viertelPosition,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get baendeGesamt => $composableBuilder(
    column: $table.baendeGesamt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get abgeschlossen => $composableBuilder(
    column: $table.abgeschlossen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get viertelPosition => $composableBuilder(
    column: $table.viertelPosition,
    builder: (column) => column,
  );

  Expression<T> booksRefs<T extends Object>(
    Expression<T> Function($$BooksTableAnnotationComposer a) f,
  ) {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTableTable,
          Series,
          $$SeriesTableTableFilterComposer,
          $$SeriesTableTableOrderingComposer,
          $$SeriesTableTableAnnotationComposer,
          $$SeriesTableTableCreateCompanionBuilder,
          $$SeriesTableTableUpdateCompanionBuilder,
          (Series, $$SeriesTableTableReferences),
          Series,
          PrefetchHooks Function({bool booksRefs})
        > {
  $$SeriesTableTableTableManager(_$AppDatabase db, $SeriesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> baendeGesamt = const Value.absent(),
                Value<bool> abgeschlossen = const Value.absent(),
                Value<int> viertelPosition = const Value.absent(),
              }) => SeriesTableCompanion(
                id: id,
                name: name,
                baendeGesamt: baendeGesamt,
                abgeschlossen: abgeschlossen,
                viertelPosition: viertelPosition,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> baendeGesamt = const Value.absent(),
                Value<bool> abgeschlossen = const Value.absent(),
                required int viertelPosition,
              }) => SeriesTableCompanion.insert(
                id: id,
                name: name,
                baendeGesamt: baendeGesamt,
                abgeschlossen: abgeschlossen,
                viertelPosition: viertelPosition,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesTableTable, Series>(table),
                  $$SeriesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({booksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (booksRefs) db.books],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (booksRefs)
                    await $_getPrefetchedData<Series, $SeriesTableTable, Book>(
                      currentTable: table,
                      referencedTable: $$SeriesTableTableReferences
                          ._booksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SeriesTableTableReferences(db, table, p0).booksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.seriesId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SeriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTableTable,
      Series,
      $$SeriesTableTableFilterComposer,
      $$SeriesTableTableOrderingComposer,
      $$SeriesTableTableAnnotationComposer,
      $$SeriesTableTableCreateCompanionBuilder,
      $$SeriesTableTableUpdateCompanionBuilder,
      (Series, $$SeriesTableTableReferences),
      Series,
      PrefetchHooks Function({bool booksRefs})
    >;
typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String?> isbn,
  required String titel,
  Value<String> autor,
  required int seitenGesamt,
  Value<List<Genre>> genres,
  required BookStatus status,
  Value<int?> seriesId,
  Value<int?> seriesIndex,
  Value<String?> notiz,
  required DateTime hinzugefuegtAm,
  Value<DateTime?> beendetAm,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String?> isbn,
  Value<String> titel,
  Value<String> autor,
  Value<int> seitenGesamt,
  Value<List<Genre>> genres,
  Value<BookStatus> status,
  Value<int?> seriesId,
  Value<int?> seriesIndex,
  Value<String?> notiz,
  Value<DateTime> hinzugefuegtAm,
  Value<DateTime?> beendetAm,
});

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTableTable _seriesIdTable(_$AppDatabase db) =>
      db.seriesTable.createAlias('books__series_id__series__id');

  $$SeriesTableTableProcessedTableManager? get seriesId {
    final $_column = $_itemColumn<int>('series_id');
    if ($_column == null) return null;
    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReadingEntriesTable, List<ReadingEntry>>
  _readingEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingEntries,
    aliasName: 'books__id__reading_entries__book_id',
  );

  $$ReadingEntriesTableProcessedTableManager get readingEntriesRefs {
    final manager = $$ReadingEntriesTableTableManager(
      $_db,
      $_db.readingEntries,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_readingEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BuildingsTable, List<Building>>
  _buildingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.buildings,
    aliasName: 'books__id__buildings__book_id',
  );

  $$BuildingsTableProcessedTableManager get buildingsRefs {
    final manager = $$BuildingsTableTableManager(
      $_db,
      $_db.buildings,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_buildingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isbn => $composableBuilder(
    column: $table.isbn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titel => $composableBuilder(
    column: $table.titel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seitenGesamt => $composableBuilder(
    column: $table.seitenGesamt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Genre>, List<Genre>, String> get genres =>
      $composableBuilder(
        column: $table.genres,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<BookStatus, BookStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get seriesIndex => $composableBuilder(
    column: $table.seriesIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get hinzugefuegtAm => $composableBuilder(
    column: $table.hinzugefuegtAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get beendetAm => $composableBuilder(
    column: $table.beendetAm,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableTableFilterComposer get seriesId {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> readingEntriesRefs(
    Expression<bool> Function($$ReadingEntriesTableFilterComposer f) f,
  ) {
    final $$ReadingEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingEntries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingEntriesTableFilterComposer(
            $db: $db,
            $table: $db.readingEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> buildingsRefs(
    Expression<bool> Function($$BuildingsTableFilterComposer f) f,
  ) {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.buildings,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuildingsTableFilterComposer(
            $db: $db,
            $table: $db.buildings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isbn => $composableBuilder(
    column: $table.isbn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titel => $composableBuilder(
    column: $table.titel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seitenGesamt => $composableBuilder(
    column: $table.seitenGesamt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesIndex => $composableBuilder(
    column: $table.seriesIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get hinzugefuegtAm => $composableBuilder(
    column: $table.hinzugefuegtAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get beendetAm => $composableBuilder(
    column: $table.beendetAm,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableTableOrderingComposer get seriesId {
    final $$SeriesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableOrderingComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get isbn =>
      $composableBuilder(column: $table.isbn, builder: (column) => column);

  GeneratedColumn<String> get titel =>
      $composableBuilder(column: $table.titel, builder: (column) => column);

  GeneratedColumn<String> get autor =>
      $composableBuilder(column: $table.autor, builder: (column) => column);

  GeneratedColumn<int> get seitenGesamt => $composableBuilder(
    column: $table.seitenGesamt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<Genre>, String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BookStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get seriesIndex => $composableBuilder(
    column: $table.seriesIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);

  GeneratedColumn<DateTime> get hinzugefuegtAm => $composableBuilder(
    column: $table.hinzugefuegtAm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get beendetAm =>
      $composableBuilder(column: $table.beendetAm, builder: (column) => column);

  $$SeriesTableTableAnnotationComposer get seriesId {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> readingEntriesRefs<T extends Object>(
    Expression<T> Function($$ReadingEntriesTableAnnotationComposer a) f,
  ) {
    final $$ReadingEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingEntries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.readingEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> buildingsRefs<T extends Object>(
    Expression<T> Function($$BuildingsTableAnnotationComposer a) f,
  ) {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.buildings,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuildingsTableAnnotationComposer(
            $db: $db,
            $table: $db.buildings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, $$BooksTableReferences),
          Book,
          PrefetchHooks Function({
            bool seriesId,
            bool readingEntriesRefs,
            bool buildingsRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> isbn = const Value.absent(),
                Value<String> titel = const Value.absent(),
                Value<String> autor = const Value.absent(),
                Value<int> seitenGesamt = const Value.absent(),
                Value<List<Genre>> genres = const Value.absent(),
                Value<BookStatus> status = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> seriesIndex = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<DateTime> hinzugefuegtAm = const Value.absent(),
                Value<DateTime?> beendetAm = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                isbn: isbn,
                titel: titel,
                autor: autor,
                seitenGesamt: seitenGesamt,
                genres: genres,
                status: status,
                seriesId: seriesId,
                seriesIndex: seriesIndex,
                notiz: notiz,
                hinzugefuegtAm: hinzugefuegtAm,
                beendetAm: beendetAm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> isbn = const Value.absent(),
                required String titel,
                Value<String> autor = const Value.absent(),
                required int seitenGesamt,
                Value<List<Genre>> genres = const Value.absent(),
                required BookStatus status,
                Value<int?> seriesId = const Value.absent(),
                Value<int?> seriesIndex = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                required DateTime hinzugefuegtAm,
                Value<DateTime?> beendetAm = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                isbn: isbn,
                titel: titel,
                autor: autor,
                seitenGesamt: seitenGesamt,
                genres: genres,
                status: status,
                seriesId: seriesId,
                seriesIndex: seriesIndex,
                notiz: notiz,
                hinzugefuegtAm: hinzugefuegtAm,
                beendetAm: beendetAm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, Book>(table),
                  $$BooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                seriesId = false,
                readingEntriesRefs = false,
                buildingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (readingEntriesRefs) db.readingEntries,
                    if (buildingsRefs) db.buildings,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (seriesId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.seriesId,
                            referencedTable: $$BooksTableReferences
                                ._seriesIdTable(db),
                            referencedColumn: $$BooksTableReferences
                                ._seriesIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (readingEntriesRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          ReadingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (buildingsRefs)
                        await $_getPrefetchedData<Book, $BooksTable, Building>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._buildingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).buildingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, $$BooksTableReferences),
      Book,
      PrefetchHooks Function({
        bool seriesId,
        bool readingEntriesRefs,
        bool buildingsRefs,
      })
    >;
typedef $$ReadingEntriesTableCreateCompanionBuilder =
    ReadingEntriesCompanion Function({
      Value<int> id,
      required int bookId,
      required DateTime datum,
      required int vonSeite,
      required int bisSeite,
    });
typedef $$ReadingEntriesTableUpdateCompanionBuilder =
    ReadingEntriesCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<DateTime> datum,
      Value<int> vonSeite,
      Value<int> bisSeite,
    });

final class $$ReadingEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $ReadingEntriesTable, ReadingEntry> {
  $$ReadingEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('reading_entries__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingEntriesTable> {
  $$ReadingEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get datum => $composableBuilder(
    column: $table.datum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vonSeite => $composableBuilder(
    column: $table.vonSeite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bisSeite => $composableBuilder(
    column: $table.bisSeite,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingEntriesTable> {
  $$ReadingEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get datum => $composableBuilder(
    column: $table.datum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vonSeite => $composableBuilder(
    column: $table.vonSeite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bisSeite => $composableBuilder(
    column: $table.bisSeite,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingEntriesTable> {
  $$ReadingEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get datum =>
      $composableBuilder(column: $table.datum, builder: (column) => column);

  GeneratedColumn<int> get vonSeite =>
      $composableBuilder(column: $table.vonSeite, builder: (column) => column);

  GeneratedColumn<int> get bisSeite =>
      $composableBuilder(column: $table.bisSeite, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingEntriesTable,
          ReadingEntry,
          $$ReadingEntriesTableFilterComposer,
          $$ReadingEntriesTableOrderingComposer,
          $$ReadingEntriesTableAnnotationComposer,
          $$ReadingEntriesTableCreateCompanionBuilder,
          $$ReadingEntriesTableUpdateCompanionBuilder,
          (ReadingEntry, $$ReadingEntriesTableReferences),
          ReadingEntry,
          PrefetchHooks Function({bool bookId})
        > {
  $$ReadingEntriesTableTableManager(
    _$AppDatabase db,
    $ReadingEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<DateTime> datum = const Value.absent(),
                Value<int> vonSeite = const Value.absent(),
                Value<int> bisSeite = const Value.absent(),
              }) => ReadingEntriesCompanion(
                id: id,
                bookId: bookId,
                datum: datum,
                vonSeite: vonSeite,
                bisSeite: bisSeite,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                required DateTime datum,
                required int vonSeite,
                required int bisSeite,
              }) => ReadingEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                datum: datum,
                vonSeite: vonSeite,
                bisSeite: bisSeite,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingEntriesTable, ReadingEntry>(table),
                  $$ReadingEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$ReadingEntriesTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$ReadingEntriesTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingEntriesTable,
      ReadingEntry,
      $$ReadingEntriesTableFilterComposer,
      $$ReadingEntriesTableOrderingComposer,
      $$ReadingEntriesTableAnnotationComposer,
      $$ReadingEntriesTableCreateCompanionBuilder,
      $$ReadingEntriesTableUpdateCompanionBuilder,
      (ReadingEntry, $$ReadingEntriesTableReferences),
      ReadingEntry,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$BuildingsTableCreateCompanionBuilder = BuildingsCompanion Function({
  Value<int> id,
  required String typeId,
  required int x,
  required int y,
  Value<int?> bookId,
  Value<int?> seriesId,
  Value<int?> jahr,
  required DateTime gebautAm,
});
typedef $$BuildingsTableUpdateCompanionBuilder = BuildingsCompanion Function({
  Value<int> id,
  Value<String> typeId,
  Value<int> x,
  Value<int> y,
  Value<int?> bookId,
  Value<int?> seriesId,
  Value<int?> jahr,
  Value<DateTime> gebautAm,
});

final class $$BuildingsTableReferences
    extends BaseReferences<_$AppDatabase, $BuildingsTable, Building> {
  $$BuildingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('buildings__book_id__books__id');

  $$BooksTableProcessedTableManager? get bookId {
    final $_column = $_itemColumn<int>('book_id');
    if ($_column == null) return null;
    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BuildingsTableFilterComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jahr => $composableBuilder(
    column: $table.jahr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gebautAm => $composableBuilder(
    column: $table.gebautAm,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BuildingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jahr => $composableBuilder(
    column: $table.jahr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gebautAm => $composableBuilder(
    column: $table.gebautAm,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BuildingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<int> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<int> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get jahr =>
      $composableBuilder(column: $table.jahr, builder: (column) => column);

  GeneratedColumn<DateTime> get gebautAm =>
      $composableBuilder(column: $table.gebautAm, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BuildingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BuildingsTable,
          Building,
          $$BuildingsTableFilterComposer,
          $$BuildingsTableOrderingComposer,
          $$BuildingsTableAnnotationComposer,
          $$BuildingsTableCreateCompanionBuilder,
          $$BuildingsTableUpdateCompanionBuilder,
          (Building, $$BuildingsTableReferences),
          Building,
          PrefetchHooks Function({bool bookId})
        > {
  $$BuildingsTableTableManager(_$AppDatabase db, $BuildingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuildingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuildingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuildingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> typeId = const Value.absent(),
                Value<int> x = const Value.absent(),
                Value<int> y = const Value.absent(),
                Value<int?> bookId = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> jahr = const Value.absent(),
                Value<DateTime> gebautAm = const Value.absent(),
              }) => BuildingsCompanion(
                id: id,
                typeId: typeId,
                x: x,
                y: y,
                bookId: bookId,
                seriesId: seriesId,
                jahr: jahr,
                gebautAm: gebautAm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String typeId,
                required int x,
                required int y,
                Value<int?> bookId = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> jahr = const Value.absent(),
                required DateTime gebautAm,
              }) => BuildingsCompanion.insert(
                id: id,
                typeId: typeId,
                x: x,
                y: y,
                bookId: bookId,
                seriesId: seriesId,
                jahr: jahr,
                gebautAm: gebautAm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BuildingsTable, Building>(table),
                  $$BuildingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$BuildingsTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$BuildingsTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BuildingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BuildingsTable,
      Building,
      $$BuildingsTableFilterComposer,
      $$BuildingsTableOrderingComposer,
      $$BuildingsTableAnnotationComposer,
      $$BuildingsTableCreateCompanionBuilder,
      $$BuildingsTableUpdateCompanionBuilder,
      (Building, $$BuildingsTableReferences),
      Building,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$YearGoalsTableCreateCompanionBuilder = YearGoalsCompanion Function({
  Value<int> jahr,
  required int zielBuecher,
});
typedef $$YearGoalsTableUpdateCompanionBuilder = YearGoalsCompanion Function({
  Value<int> jahr,
  Value<int> zielBuecher,
});

class $$YearGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $YearGoalsTable> {
  $$YearGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get jahr => $composableBuilder(
    column: $table.jahr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get zielBuecher => $composableBuilder(
    column: $table.zielBuecher,
    builder: (column) => ColumnFilters(column),
  );
}

class $$YearGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $YearGoalsTable> {
  $$YearGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get jahr => $composableBuilder(
    column: $table.jahr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get zielBuecher => $composableBuilder(
    column: $table.zielBuecher,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$YearGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $YearGoalsTable> {
  $$YearGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get jahr =>
      $composableBuilder(column: $table.jahr, builder: (column) => column);

  GeneratedColumn<int> get zielBuecher => $composableBuilder(
    column: $table.zielBuecher,
    builder: (column) => column,
  );
}

class $$YearGoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $YearGoalsTable,
          YearGoal,
          $$YearGoalsTableFilterComposer,
          $$YearGoalsTableOrderingComposer,
          $$YearGoalsTableAnnotationComposer,
          $$YearGoalsTableCreateCompanionBuilder,
          $$YearGoalsTableUpdateCompanionBuilder,
          (YearGoal, BaseReferences<_$AppDatabase, $YearGoalsTable, YearGoal>),
          YearGoal,
          PrefetchHooks Function()
        > {
  $$YearGoalsTableTableManager(_$AppDatabase db, $YearGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$YearGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$YearGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$YearGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> jahr = const Value.absent(),
            Value<int> zielBuecher = const Value.absent(),
          }) => YearGoalsCompanion(jahr: jahr, zielBuecher: zielBuecher),
          createCompanionCallback: ({
            Value<int> jahr = const Value.absent(),
            required int zielBuecher,
          }) => YearGoalsCompanion.insert(jahr: jahr, zielBuecher: zielBuecher),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$YearGoalsTable, YearGoal>(table),
                  BaseReferences<_$AppDatabase, $YearGoalsTable, YearGoal>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$YearGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $YearGoalsTable,
      YearGoal,
      $$YearGoalsTableFilterComposer,
      $$YearGoalsTableOrderingComposer,
      $$YearGoalsTableAnnotationComposer,
      $$YearGoalsTableCreateCompanionBuilder,
      $$YearGoalsTableUpdateCompanionBuilder,
      (YearGoal, BaseReferences<_$AppDatabase, $YearGoalsTable, YearGoal>),
      YearGoal,
      PrefetchHooks Function()
    >;
typedef $$CitySnapshotsTableCreateCompanionBuilder =
    CitySnapshotsCompanion Function({
      Value<int> id,
      required DateTime datum,
      required String gebaeudeJson,
    });
typedef $$CitySnapshotsTableUpdateCompanionBuilder =
    CitySnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> datum,
      Value<String> gebaeudeJson,
    });

class $$CitySnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $CitySnapshotsTable> {
  $$CitySnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get datum => $composableBuilder(
    column: $table.datum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gebaeudeJson => $composableBuilder(
    column: $table.gebaeudeJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CitySnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $CitySnapshotsTable> {
  $$CitySnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get datum => $composableBuilder(
    column: $table.datum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gebaeudeJson => $composableBuilder(
    column: $table.gebaeudeJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CitySnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CitySnapshotsTable> {
  $$CitySnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get datum =>
      $composableBuilder(column: $table.datum, builder: (column) => column);

  GeneratedColumn<String> get gebaeudeJson => $composableBuilder(
    column: $table.gebaeudeJson,
    builder: (column) => column,
  );
}

class $$CitySnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CitySnapshotsTable,
          CitySnapshot,
          $$CitySnapshotsTableFilterComposer,
          $$CitySnapshotsTableOrderingComposer,
          $$CitySnapshotsTableAnnotationComposer,
          $$CitySnapshotsTableCreateCompanionBuilder,
          $$CitySnapshotsTableUpdateCompanionBuilder,
          (
            CitySnapshot,
            BaseReferences<_$AppDatabase, $CitySnapshotsTable, CitySnapshot>,
          ),
          CitySnapshot,
          PrefetchHooks Function()
        > {
  $$CitySnapshotsTableTableManager(_$AppDatabase db, $CitySnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CitySnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CitySnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CitySnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> datum = const Value.absent(),
                Value<String> gebaeudeJson = const Value.absent(),
              }) => CitySnapshotsCompanion(
                id: id,
                datum: datum,
                gebaeudeJson: gebaeudeJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime datum,
                required String gebaeudeJson,
              }) => CitySnapshotsCompanion.insert(
                id: id,
                datum: datum,
                gebaeudeJson: gebaeudeJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CitySnapshotsTable, CitySnapshot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CitySnapshotsTable,
                    CitySnapshot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CitySnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CitySnapshotsTable,
      CitySnapshot,
      $$CitySnapshotsTableFilterComposer,
      $$CitySnapshotsTableOrderingComposer,
      $$CitySnapshotsTableAnnotationComposer,
      $$CitySnapshotsTableCreateCompanionBuilder,
      $$CitySnapshotsTableUpdateCompanionBuilder,
      (
        CitySnapshot,
        BaseReferences<_$AppDatabase, $CitySnapshotsTable, CitySnapshot>,
      ),
      CitySnapshot,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db, _db.seriesTable);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ReadingEntriesTableTableManager get readingEntries =>
      $$ReadingEntriesTableTableManager(_db, _db.readingEntries);
  $$BuildingsTableTableManager get buildings =>
      $$BuildingsTableTableManager(_db, _db.buildings);
  $$YearGoalsTableTableManager get yearGoals =>
      $$YearGoalsTableTableManager(_db, _db.yearGoals);
  $$CitySnapshotsTableTableManager get citySnapshots =>
      $$CitySnapshotsTableTableManager(_db, _db.citySnapshots);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
