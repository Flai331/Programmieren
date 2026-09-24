import 'dart:convert';

import '../data/db.dart';
import '../model/catalog.dart';
import '../model/genre.dart';
import 'economy.dart';
import 'series.dart';

// ------------------------------------------------------------ Schnappschuss

/// Gebäudeliste als JSON (kein Bild, spart Platz).
String snapshotJson(List<Building> buildings, Map<int, Book> booksById) =>
    jsonEncode([
      for (final b in buildings)
        {
          'typ': b.typeId,
          'name': b.bookId != null
              ? booksById[b.bookId]?.titel ?? '?'
              : b.jahr != null
              ? 'Jahresbauwerk ${b.jahr}'
              : typeById(b.typeId)?.name ?? b.typeId,
          'x': b.x,
          'y': b.y,
        },
    ]);

class SnapshotSummary {
  SnapshotSummary(this.datum, this.gesamt, this.proName);
  final DateTime datum;
  final int gesamt;

  /// Anzahl je Gebäudename, Buch-Denkmäler zusammengefasst.
  final Map<String, int> proName;
}

SnapshotSummary summarizeSnapshot(CitySnapshot s) {
  final list = (jsonDecode(s.gebaeudeJson) as List).cast<Map>();
  final proName = <String, int>{};
  for (final g in list) {
    final name = g['typ'] == typBuchDenkmal
        ? 'Buch-Denkmäler'
        : g['name'] as String;
    proName[name] = (proName[name] ?? 0) + 1;
  }
  return SnapshotSummary(s.datum, list.length, proName);
}

/// Ob für den Monat von [now] schon ein Schnappschuss existiert.
bool hasSnapshotFor(List<CitySnapshot> snapshots, DateTime now) => snapshots
    .any((s) => s.datum.year == now.year && s.datum.month == now.month);

// ------------------------------------------------------------ Jahresrückblick

class YearReview {
  YearReview({
    required this.jahr,
    required this.buecher,
    required this.seiten,
    required this.topGenre,
    required this.laengstesBuch,
    required this.reihen,
  });

  final int jahr;
  final List<Book> buecher;
  final int seiten;
  final Genre? topGenre;
  final Book? laengstesBuch;
  final List<Series> reihen;
}

YearReview yearReview({
  required int jahr,
  required List<Book> books,
  required List<ReadingEntry> entries,
  required List<Series> series,
}) {
  final beendet =
      books
          .where(
            (b) => b.status == BookStatus.beendet && b.beendetAm?.year == jahr,
          )
          .toList()
        ..sort((a, b) => a.beendetAm!.compareTo(b.beendetAm!));
  final imJahr = entries.where((e) => e.datum.year == jahr);
  final seiten = totalPages(imJahr);

  final perGenre = <Genre, int>{};
  final perBook = pagesPerBook(imJahr);
  for (final b in books) {
    final p = perBook[b.id] ?? 0;
    if (p == 0 || b.genres.isEmpty) continue;
    for (final g in b.genres) {
      perGenre[g] = (perGenre[g] ?? 0) + p ~/ b.genres.length;
    }
  }
  final topGenre = perGenre.isEmpty
      ? null
      : perGenre.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  final laengstes = beendet.isEmpty
      ? null
      : beendet.reduce((a, b) => b.seitenGesamt > a.seitenGesamt ? b : a);

  // Eine Reihe zählt im Jahr, in dem ihr letzter Band beendet wurde.
  final reihen = series.where((s) {
    final baende = books.where((b) => b.seriesId == s.id).toList();
    if (!isSeriesComplete(s, baende)) return false;
    final letzter = baende
        .map((b) => b.beendetAm)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return letzter?.year == jahr;
  }).toList();

  return YearReview(
    jahr: jahr,
    buecher: beendet,
    seiten: seiten,
    topGenre: topGenre,
    laengstesBuch: laengstes,
    reihen: reihen,
  );
}

// ---------------------------------------------------------------- Zeitraffer

/// Bücher so, wie sie am Tag [t] standen: noch nicht hinzugefügte fehlen,
/// der Status richtet sich nach Einträgen und Enddatum.
List<Book> booksAt(List<Book> books, List<ReadingEntry> entries, DateTime t) {
  final result = <Book>[];
  for (final b in books) {
    if (b.hinzugefuegtAm.isAfter(t)) continue;
    final BookStatus status;
    if (b.beendetAm != null && !b.beendetAm!.isAfter(t)) {
      status = BookStatus.beendet;
    } else if (entries.any((e) => e.bookId == b.id && !e.datum.isAfter(t))) {
      status = BookStatus.lesend;
    } else {
      // Buch war da, aber noch ohne Eintrag: als Bauplan zeigen.
      status = BookStatus.wunsch;
    }
    result.add(b.copyWith(status: status));
  }
  return result;
}

List<Building> buildingsAt(List<Building> buildings, DateTime t) =>
    buildings.where((b) => !b.gebautAm.isAfter(t)).toList();

List<ReadingEntry> entriesAt(List<ReadingEntry> entries, DateTime t) =>
    entries.where((e) => !e.datum.isAfter(t)).toList();
