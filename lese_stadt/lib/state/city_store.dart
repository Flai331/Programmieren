import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../logic/chronicle.dart';
import '../logic/economy.dart';
import '../logic/progress.dart';
import '../logic/series.dart';
import '../model/catalog.dart';
import '../model/genre.dart';

const _pinKey = 'nahziel';

/// Hält alle Daten im Speicher und berechnet daraus Stadt, Inventar und
/// Ziele. Jede Änderung schreibt in die Datenbank und lädt neu.
class CityStore extends ChangeNotifier {
  CityStore(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;
  DateTime get now => _clock();

  bool loaded = false;
  List<Book> books = [];
  List<Series> series = [];
  List<ReadingEntry> entries = [];
  List<Building> buildings = [];
  List<YearGoal> yearGoals = [];
  List<CitySnapshot> snapshots = [];
  String? gepinnt;

  /// Bücher, deren Denkmal keinen freien Platz mehr gefunden hat.
  int ohnePlatz = 0;

  // ------------------------------------------------------------ Abgeleitet

  Map<int, Book> get booksById => {for (final b in books) b.id: b};
  Map<int, Series> get seriesById => {for (final s in series) s.id: s};

  int get seitenGesamt => totalPages(entries);
  Stufe get stufe => Stufe.fuerSeiten(seitenGesamt);
  int get citySize => stufe.groesse;

  List<District> get districts =>
      layoutDistricts(series: series, books: books, citySize: citySize);

  Materials get inventar => inventory(
    books: books,
    entries: entries,
    buildings: buildings,
    boni: [
      for (final d in districts)
        if (d.komplett) seriesBonus(d.baende, d.genre),
    ],
  );

  int get aktivitaet => activityValue(entries, now);
  Belebung get belebung => belebungFuer(aktivitaet);

  Book? get aktuellesBuch => currentBook(books, entries);

  Nahziel? get nahziel => nextGoal(
    inv: inventar,
    stufe: stufe,
    aktuellesBuch: aktuellesBuch,
    buildings: buildings,
    gepinntId: gepinnt,
  );

  int pagesRead(Book b) => entries
      .where((e) => e.bookId == b.id)
      .fold(0, (sum, e) => sum + pagesOf(e));

  /// Aktuelle Seite = höchste eingetragene Seite.
  int currentPage(Book b) => entries
      .where((e) => e.bookId == b.id)
      .fold(0, (p, e) => e.bisSeite > p ? e.bisSeite : p);

  List<ReadingEntry> entriesOf(Book b) =>
      entries.where((e) => e.bookId == b.id).toList()
        ..sort((a, b) => b.datum.compareTo(a.datum));

  YearGoal? goalFor(int jahr) =>
      yearGoals.where((g) => g.jahr == jahr).firstOrNull;

  Building? buildingAt(int x, int y) =>
      buildings.where((b) => b.x == x && b.y == y).firstOrNull;

  // ------------------------------------------------------------ Laden

  Future<void> load() async {
    await _reload();
    await _reconcile();
    await _takeSnapshotIfDue();
    loaded = true;
    notifyListeners();
  }

  Future<void> _reload() async {
    books = await db.select(db.books).get();
    series = await db.select(db.seriesTable).get();
    entries = await db.select(db.readingEntries).get();
    buildings = await db.select(db.buildings).get();
    yearGoals = await db.select(db.yearGoals).get();
    snapshots = await (db.select(
      db.citySnapshots,
    )..orderBy([(s) => OrderingTerm.desc(s.datum)])).get();
    final pin = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(_pinKey))).getSingleOrNull();
    gepinnt = pin?.value;
  }

  Future<void> _changed() async {
    await _reload();
    await _reconcile();
    notifyListeners();
  }

  /// Sorgt dafür, dass jedes Buch außerhalb einer Reihe genau ein Denkmal in
  /// der Stadt hat und jedes Jahresziel sein Bauwerk.
  Future<void> _reconcile() async {
    var changed = false;
    final bookIds = {for (final b in books) b.id};
    final ohneReihe = {
      for (final b in books)
        if (b.seriesId == null) b.id,
    };

    for (final b in buildings.where((b) => b.typeId == typBuchDenkmal)) {
      if (!ohneReihe.contains(b.bookId) || !bookIds.contains(b.bookId)) {
        await (db.delete(db.buildings)..where((t) => t.id.equals(b.id))).go();
        changed = true;
      }
    }
    if (changed) buildings = await db.select(db.buildings).get();

    final mitDenkmal = {
      for (final b in buildings)
        if (b.typeId == typBuchDenkmal) b.bookId,
    };
    final mitJahr = {
      for (final b in buildings)
        if (b.typeId == typJahresprojekt) b.jahr,
    };
    final fehlend = [
      for (final g in yearGoals)
        if (!mitJahr.contains(g.jahr)) (typJahresprojekt, null, g.jahr),
      for (final b in books)
        if (b.seriesId == null && !mitDenkmal.contains(b.id))
          (typBuchDenkmal, b, null),
    ];

    var frei = freeTiles(citySize, buildings);
    ohnePlatz = 0;
    for (final (typ, book, jahr) in fehlend) {
      if (frei.isEmpty) {
        if (book != null) ohnePlatz++;
        continue;
      }
      final (x, y) = frei.removeAt(0);
      await db
          .into(db.buildings)
          .insert(
            BuildingsCompanion.insert(
              typeId: typ,
              x: x,
              y: y,
              bookId: Value(book?.id),
              jahr: Value(jahr),
              gebautAm: book?.hinzugefuegtAm ?? now,
            ),
          );
      changed = true;
    }
    if (changed) buildings = await db.select(db.buildings).get();
  }

  Future<void> _takeSnapshotIfDue() async {
    if (buildings.isEmpty || hasSnapshotFor(snapshots, now)) return;
    await db
        .into(db.citySnapshots)
        .insert(
          CitySnapshotsCompanion.insert(
            datum: now,
            gebaeudeJson: snapshotJson(buildings, booksById),
          ),
        );
    snapshots = await (db.select(
      db.citySnapshots,
    )..orderBy([(s) => OrderingTerm.desc(s.datum)])).get();
  }

  // ------------------------------------------------------------ Bücher

  Future<int> _seriesIdFor(String? name) async {
    final n = name!.trim();
    final existing = series
        .where((s) => s.name.toLowerCase() == n.toLowerCase())
        .firstOrNull;
    if (existing != null) return existing.id;
    final pos =
        series.fold(
          -1,
          (p, s) => s.viertelPosition > p ? s.viertelPosition : p,
        ) +
        1;
    final id = await db
        .into(db.seriesTable)
        .insert(SeriesTableCompanion.insert(name: n, viertelPosition: pos));
    series = await db.select(db.seriesTable).get();
    return id;
  }

  /// Legt ein Buch an. [gelesenBis] trägt bereits gelesene Seiten als ersten
  /// Eintrag ein, damit auch das Material dafür kommt.
  Future<int> addBook({
    String? isbn,
    required String titel,
    String autor = '',
    required int seitenGesamt,
    List<Genre> genres = const [],
    required BookStatus status,
    String? reihe,
    int? band,
    String? notiz,
    int gelesenBis = 0,
  }) async {
    final t = now;
    final seriesId = (reihe == null || reihe.trim().isEmpty)
        ? null
        : await _seriesIdFor(reihe);
    final id = await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            isbn: Value(isbn),
            titel: titel.trim(),
            autor: Value(autor.trim()),
            seitenGesamt: seitenGesamt,
            genres: Value(genres),
            status: status,
            seriesId: Value(seriesId),
            seriesIndex: Value(seriesId == null ? null : band),
            notiz: Value(notiz),
            hinzugefuegtAm: t,
            beendetAm: Value(status == BookStatus.beendet ? t : null),
          ),
        );
    if (gelesenBis > 0) {
      await db
          .into(db.readingEntries)
          .insert(
            ReadingEntriesCompanion.insert(
              bookId: id,
              datum: t,
              vonSeite: 0,
              bisSeite: gelesenBis,
            ),
          );
    }
    await _changed();
    return id;
  }

  Future<void> updateBook(Book book, {String? reihe}) async {
    var b = book;
    if (reihe != null) {
      final id = reihe.trim().isEmpty ? null : await _seriesIdFor(reihe);
      b = b.copyWith(
        seriesId: Value(id),
        seriesIndex: Value(id == null ? null : b.seriesIndex),
      );
    }
    if (b.status == BookStatus.beendet && b.beendetAm == null) {
      b = b.copyWith(beendetAm: Value(now));
    } else if (b.status != BookStatus.beendet) {
      b = b.copyWith(beendetAm: const Value(null));
    }
    await db.update(db.books).replace(b);
    await _cleanupSeries();
    await _changed();
  }

  Future<void> setStatus(Book book, BookStatus status) =>
      updateBook(book.copyWith(status: status));

  Future<void> deleteBook(Book book) async {
    await (db.delete(
      db.readingEntries,
    )..where((e) => e.bookId.equals(book.id))).go();
    await (db.delete(
      db.buildings,
    )..where((b) => b.bookId.equals(book.id))).go();
    await (db.delete(db.books)..where((b) => b.id.equals(book.id))).go();
    await _cleanupSeries();
    await _changed();
  }

  /// Reihen ohne Bücher verschwinden wieder.
  Future<void> _cleanupSeries() async {
    final all = await db.select(db.books).get();
    final used = {for (final b in all) b.seriesId};
    for (final s in await db.select(db.seriesTable).get()) {
      if (!used.contains(s.id)) {
        await (db.delete(db.seriesTable)..where((t) => t.id.equals(s.id))).go();
      }
    }
  }

  Future<void> updateSeries(Series s) async {
    await db.update(db.seriesTable).replace(s);
    await _changed();
  }

  // ------------------------------------------------------------ Lesen

  /// Trägt ein, dass [book] bis Seite [bisSeite] gelesen wurde. Gibt das
  /// gewonnene Material zurück.
  Future<Materials> addEntry(
    Book book,
    int bisSeite, {
    DateTime? datum,
    bool beenden = false,
  }) async {
    final von = currentPage(book);
    if (bisSeite <= von) {
      throw ArgumentError('Die neue Seite muss größer als $von sein.');
    }
    final gained = materialsGained(
      pagesRead(book),
      bisSeite - von,
      book.genres,
    );
    final d = datum ?? now;
    await db
        .into(db.readingEntries)
        .insert(
          ReadingEntriesCompanion.insert(
            bookId: book.id,
            datum: d,
            vonSeite: von,
            bisSeite: bisSeite,
          ),
        );
    var status = book.status;
    if (beenden) {
      status = BookStatus.beendet;
    } else if (status == BookStatus.wunsch) {
      status = BookStatus.lesend;
    }
    if (status != book.status) {
      await db
          .update(db.books)
          .replace(
            book.copyWith(
              status: status,
              beendetAm: Value(status == BookStatus.beendet ? d : null),
            ),
          );
    }
    await _changed();
    return gained;
  }

  Future<void> deleteEntry(ReadingEntry e) async {
    await (db.delete(db.readingEntries)..where((t) => t.id.equals(e.id))).go();
    await _changed();
  }

  // ------------------------------------------------------------ Bauen

  bool isFreeTile(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < citySize &&
      y < citySize &&
      buildingAt(x, y) == null;

  Future<bool> build(BuildingType typ, int x, int y) async {
    if (!typ.baubar || !isFreeTile(x, y)) return false;
    if (typ.abStufe.index > stufe.index || !canAfford(inventar, typ)) {
      return false;
    }
    await db
        .into(db.buildings)
        .insert(
          BuildingsCompanion.insert(typeId: typ.id, x: x, y: y, gebautAm: now),
        );
    if (gepinnt == typ.id) await pin(null);
    await _changed();
    return true;
  }

  /// Abreißen gibt das Material zurück (der Bestand wird ja berechnet).
  Future<void> demolish(Building b) async {
    if (!(typeById(b.typeId)?.baubar ?? false)) return;
    await (db.delete(db.buildings)..where((t) => t.id.equals(b.id))).go();
    await _changed();
  }

  /// Verschiebt ein Gebäude auf ein freies Feld.
  Future<bool> move(Building b, int x, int y) async {
    if (!isFreeTile(x, y)) return false;
    await db.update(db.buildings).replace(b.copyWith(x: x, y: y));
    await _changed();
    return true;
  }

  Future<void> pin(String? typeId) async {
    if (typeId == null) {
      await (db.delete(db.settings)..where((s) => s.key.equals(_pinKey))).go();
    } else {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: _pinKey, value: typeId),
          );
    }
    await _changed();
  }

  // ------------------------------------------------------------ Jahresziel

  Future<void> setYearGoal(int jahr, int ziel) async {
    await db
        .into(db.yearGoals)
        .insertOnConflictUpdate(
          YearGoalsCompanion.insert(jahr: Value(jahr), zielBuecher: ziel),
        );
    await _changed();
  }
}
