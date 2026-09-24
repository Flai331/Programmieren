import '../data/db.dart';
import '../model/catalog.dart';
import '../model/genre.dart';

typedef Materials = Map<Mat, int>;

void addInto(Materials target, Materials add, [int factor = 1]) {
  add.forEach((m, n) => target[m] = (target[m] ?? 0) + n * factor);
}

int pagesOf(ReadingEntry e) => e.bisSeite - e.vonSeite;

/// Gelesene Seiten pro Buch.
Map<int, int> pagesPerBook(Iterable<ReadingEntry> entries) {
  final result = <int, int>{};
  for (final e in entries) {
    result[e.bookId] = (result[e.bookId] ?? 0) + pagesOf(e);
  }
  return result;
}

int totalPages(Iterable<ReadingEntry> entries) =>
    entries.fold(0, (sum, e) => sum + pagesOf(e));

/// Material für [pages] Seiten eines Buchs: je Seite 1× Holz plus 1× Genre-
/// Material. Bei mehreren Genres wird das Genre-Material aufgeteilt, der Rest
/// geht an die zuerst genannten Genres.
Materials materialsForPages(int pages, List<Genre> genres) {
  final result = <Mat, int>{};
  if (pages <= 0) return result;
  result[Mat.holz] = pages;
  if (genres.isEmpty) return result;
  final share = pages ~/ genres.length;
  final rest = pages % genres.length;
  for (var i = 0; i < genres.length; i++) {
    final n = share + (i < rest ? 1 : 0);
    if (n > 0) {
      final m = genres[i].material;
      result[m] = (result[m] ?? 0) + n;
    }
  }
  return result;
}

/// Material, das ein neuer Eintrag von [pagesBefore] auf [pagesBefore]+[added]
/// Seiten eines Buchs bringt.
Materials materialsGained(int pagesBefore, int added, List<Genre> genres) {
  final result = materialsForPages(pagesBefore + added, genres);
  addInto(result, materialsForPages(pagesBefore, genres), -1);
  result.removeWhere((_, n) => n == 0);
  return result;
}

/// Bonus für eine abgeschlossene Reihe: 50 Holz und 50 Genre-Material je Band.
Materials seriesBonus(int baende, Genre? genre) {
  final result = <Mat, int>{Mat.holz: 50 * baende};
  if (genre != null) result[genre.material] = 50 * baende;
  return result;
}

/// Materialbestand: verdient durch Lesen und Reihen-Boni, abzüglich der Kosten
/// aller gebauten Gebäude. Wird berechnet statt gespeichert, damit geänderte
/// Einträge oder Genres automatisch stimmen.
Materials inventory({
  required List<Book> books,
  required List<ReadingEntry> entries,
  required List<Building> buildings,
  List<Materials> boni = const [],
}) {
  final result = <Mat, int>{for (final m in Mat.values) m: 0};
  final perBook = pagesPerBook(entries);
  for (final b in books) {
    addInto(result, materialsForPages(perBook[b.id] ?? 0, b.genres));
  }
  for (final bonus in boni) {
    addInto(result, bonus);
  }
  for (final b in buildings) {
    final type = typeById(b.typeId);
    if (type != null) addInto(result, type.kosten, -1);
  }
  return result;
}

bool canAfford(Materials inv, BuildingType type) =>
    type.kosten.entries.every((e) => (inv[e.key] ?? 0) >= e.value);
