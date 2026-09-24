import 'dart:math';

import '../data/db.dart';
import '../model/genre.dart';

enum PlotState {
  /// Band noch nicht gelesen (Wunschliste oder gar nicht im Regal).
  geist,

  /// Band wird gerade gelesen.
  baustelle,

  /// Band beendet: Gebäude mit Titel.
  fertig,

  /// Platzhalter mit Gerüst für künftige Bände einer laufenden Reihe.
  geruest,

  /// Wahrzeichen einer kompletten Reihe.
  wahrzeichen,
}

class SeriesPlot {
  SeriesPlot(this.state, this.x, this.y, {this.band, this.book});
  final PlotState state;
  final int? band;
  final Book? book;

  /// Weltkoordinaten (gleiches Raster wie die Hauptstadt).
  final int x;
  final int y;
}

class District {
  District({
    required this.series,
    required this.genre,
    required this.plots,
    required this.baende,
    required this.komplett,
    required this.x0,
    required this.y0,
    required this.breite,
    required this.hoehe,
  });

  final Series series;
  final Genre? genre;
  final List<SeriesPlot> plots;
  final int baende;
  final bool komplett;
  final int x0, y0, breite, hoehe;

  String get stilName => genre?.viertelStil ?? 'Viertel';
  int get fertigeBaende =>
      plots.where((p) => p.state == PlotState.fertig).length;
}

/// Häufigstes Hauptgenre der Bände einer Reihe.
Genre? seriesGenre(List<Book> baende) {
  final counts = <Genre, int>{};
  for (final b in baende) {
    if (b.genres.isNotEmpty) {
      counts[b.genres.first] = (counts[b.genres.first] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

int _rank(BookStatus s) => switch (s) {
  BookStatus.beendet => 2,
  BookStatus.lesend => 1,
  BookStatus.wunsch => 0,
};

/// Ordnet jedem Band (1…n) das Buch mit dem weitesten Status zu. Bücher ohne
/// Bandnummer füllen die ersten freien Plätze.
Map<int, Book> assignVolumes(List<Book> baende, int? baendeGesamt) {
  final result = <int, Book>{};
  final ohneNummer = <Book>[];
  for (final b in baende) {
    final i = b.seriesIndex;
    if (i == null || i < 1) {
      ohneNummer.add(b);
    } else if (result[i] == null ||
        _rank(b.status) > _rank(result[i]!.status)) {
      result[i] = b;
    }
  }
  var next = 1;
  for (final b in ohneNummer) {
    while (result.containsKey(next)) {
      next++;
    }
    result[next] = b;
  }
  return result;
}

int volumeCount(Series s, Map<int, Book> volumes) {
  final maxIndex = volumes.keys.fold(0, max);
  return max(s.baendeGesamt ?? 0, maxIndex);
}

bool isSeriesComplete(Series s, List<Book> baende) {
  if (!s.abgeschlossen) return false;
  final volumes = assignVolumes(baende, s.baendeGesamt);
  final n = volumeCount(s, volumes);
  if (n == 0) return false;
  for (var i = 1; i <= n; i++) {
    if (volumes[i]?.status != BookStatus.beendet) return false;
  }
  return true;
}

/// Legt die Reihen-Viertel östlich der Hauptstadt (Kantenlänge [citySize])
/// untereinander an. Kurze Reihen sind eine Gasse mit zwei Häuserreihen,
/// lange Reihen (10+ Bände) wachsen zu einer kleinen quadratischen Stadt.
List<District> layoutDistricts({
  required List<Series> series,
  required List<Book> books,
  required int citySize,
}) {
  final sorted = [...series]
    ..sort((a, b) => a.viertelPosition.compareTo(b.viertelPosition));
  final result = <District>[];
  var y0 = 0;
  final x0 = citySize + 2;
  for (final s in sorted) {
    final baende = books.where((b) => b.seriesId == s.id).toList();
    final volumes = assignVolumes(baende, s.baendeGesamt);
    final n = volumeCount(s, volumes);
    final komplett = isSeriesComplete(s, baende);

    final states = <(PlotState, int?, Book?)>[];
    for (var i = 1; i <= n; i++) {
      final b = volumes[i];
      final state = switch (b?.status) {
        BookStatus.beendet => PlotState.fertig,
        BookStatus.lesend => PlotState.baustelle,
        _ => PlotState.geist,
      };
      states.add((state, i, b));
    }
    if (!s.abgeschlossen) states.add((PlotState.geruest, null, null));
    if (komplett) states.add((PlotState.wahrzeichen, null, null));

    final count = max(1, states.length);
    final breite = n >= 10 ? sqrt(count).ceil() : max(1, (count / 2).ceil());
    final hoehe = (count / breite).ceil();
    final plots = [
      for (var i = 0; i < states.length; i++)
        SeriesPlot(
          states[i].$1,
          x0 + i % breite,
          y0 + i ~/ breite,
          band: states[i].$2,
          book: states[i].$3,
        ),
    ];
    result.add(
      District(
        series: s,
        genre: seriesGenre(baende),
        plots: plots,
        baende: n,
        komplett: komplett,
        x0: x0,
        y0: y0,
        breite: breite,
        hoehe: hoehe,
      ),
    );
    y0 += hoehe + 1;
  }
  return result;
}

/// Straßenfelder von der Hauptstadt zu den Vierteln: eine Straße entlang der
/// Ostkante und je ein Abzweig zu jedem Viertel.
List<(int, int)> districtRoads(List<District> districts, int citySize) {
  if (districts.isEmpty) return const [];
  final last = districts.last.y0;
  return [
    for (var y = 0; y <= last; y++) (citySize, y),
    for (final d in districts) (citySize + 1, d.y0),
  ];
}
