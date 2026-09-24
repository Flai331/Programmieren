import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../model/genre.dart';

part 'db.g.dart';

enum BookStatus {
  wunsch('Wunschliste'),
  lesend('Am Lesen'),
  beendet('Beendet');

  const BookStatus(this.label);
  final String label;
}

class GenreListConverter extends TypeConverter<List<Genre>, String> {
  const GenreListConverter();

  @override
  List<Genre> fromSql(String fromDb) => genresFromText(fromDb);

  @override
  String toSql(List<Genre> value) => genresToText(value);
}

@DataClassName('Book')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get isbn => text().nullable()();
  TextColumn get titel => text()();
  TextColumn get autor => text().withDefault(const Constant(''))();
  IntColumn get seitenGesamt => integer()();
  TextColumn get genres =>
      text().map(const GenreListConverter()).withDefault(const Constant(''))();
  TextColumn get status => textEnum<BookStatus>()();
  IntColumn get seriesId => integer().nullable().references(SeriesTable, #id)();
  IntColumn get seriesIndex => integer().nullable()();
  TextColumn get notiz => text().nullable()();
  DateTimeColumn get hinzugefuegtAm => dateTime()();
  DateTimeColumn get beendetAm => dateTime().nullable()();
}

@DataClassName('Series')
class SeriesTable extends Table {
  @override
  String get tableName => 'series';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get baendeGesamt => integer().nullable()();

  /// Alle Bände sind erschienen (die Reihe läuft nicht mehr).
  BoolColumn get abgeschlossen =>
      boolean().withDefault(const Constant(false))();

  /// Reihenfolge der Viertel am Stadtrand.
  IntColumn get viertelPosition => integer()();
}

@DataClassName('ReadingEntry')
class ReadingEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get datum => dateTime()();
  IntColumn get vonSeite => integer()();
  IntColumn get bisSeite => integer()();
}

@DataClassName('Building')
class Buildings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get typeId => text()();
  IntColumn get x => integer()();
  IntColumn get y => integer()();
  IntColumn get bookId => integer().nullable().references(
    Books,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get seriesId => integer().nullable()();

  /// Jahr eines Jahresbauwerks.
  IntColumn get jahr => integer().nullable()();
  DateTimeColumn get gebautAm => dateTime()();
}

@DataClassName('YearGoal')
class YearGoals extends Table {
  IntColumn get jahr => integer()();
  IntColumn get zielBuecher => integer()();

  @override
  Set<Column> get primaryKey => {jahr};
}

@DataClassName('CitySnapshot')
class CitySnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get datum => dateTime()();
  TextColumn get gebaeudeJson => text()();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Books,
    SeriesTable,
    ReadingEntries,
    Buildings,
    YearGoals,
    CitySnapshots,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lese_stadt'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
