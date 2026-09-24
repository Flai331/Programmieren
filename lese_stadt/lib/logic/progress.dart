import 'dart:math';

import '../data/db.dart';
import '../model/catalog.dart';
import '../model/genre.dart';
import 'economy.dart';

// ---------------------------------------------------------------- Aktivität

enum Belebung {
  still('Ruhig'),
  wenige('Ein paar Leute unterwegs'),
  licht('Licht in den Fenstern'),
  fest('Markt und Festbeleuchtung');

  const Belebung(this.label);
  final String label;
}

/// Aktivitätswert: gelesene Seiten der letzten 7 Tage.
int activityValue(Iterable<ReadingEntry> entries, DateTime now) {
  final since = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  return entries
      .where((e) => !e.datum.isBefore(since))
      .fold(0, (sum, e) => sum + pagesOf(e));
}

Belebung belebungFuer(int aktivitaet) {
  if (aktivitaet >= 250) return Belebung.fest;
  if (aktivitaet >= 80) return Belebung.licht;
  if (aktivitaet > 0) return Belebung.wenige;
  return Belebung.still;
}

bool istNacht(DateTime t) => t.hour < 7 || t.hour >= 20;

// ------------------------------------------------------------------ Nahziel

class Nahziel {
  Nahziel(this.typ, this.seiten, {this.fehlt = const {}, this.gepinnt = false});
  final BuildingType typ;

  /// Noch zu lesende Seiten, 0 = sofort baubar, null = mit dem aktuellen Buch
  /// nicht erreichbar.
  final int? seiten;

  /// Fehlendes Material, das das aktuelle Buch nicht liefert.
  final Materials fehlt;
  final bool gepinnt;

  String get text {
    if (seiten == 0) return '${typ.name} kann jetzt gebaut werden!';
    if (seiten != null) return 'Noch $seiten Seiten bis zum ${typ.name}';
    final teile = fehlt.entries.map((e) => '${e.value} ${e.key.label}');
    return '${typ.name}: es fehlen noch ${teile.join(', ')}';
  }
}

/// Seiten, die mit einem Buch der Genres [genres] noch fehlen, bis [typ]
/// bezahlbar ist.
Nahziel pagesUntil(
  BuildingType typ,
  Materials inv,
  List<Genre> genres, {
  bool gepinnt = false,
}) {
  var pages = 0;
  final fehlt = <Mat, int>{};
  typ.kosten.forEach((m, kosten) {
    final missing = max(0, kosten - (inv[m] ?? 0));
    if (missing == 0) return;
    if (m == Mat.holz) {
      pages = max(pages, missing);
      return;
    }
    final anteil = genres.where((g) => g.material == m).length;
    if (anteil == 0) {
      fehlt[m] = missing;
    } else {
      // Pro Seite gibt es anteil/genres.length Einheiten dieses Materials.
      pages = max(pages, (missing * genres.length / anteil).ceil());
    }
  });
  return Nahziel(
    typ,
    fehlt.isEmpty ? pages : null,
    fehlt: fehlt,
    gepinnt: gepinnt,
  );
}

/// Das aktuelle Buch: das Buch "Am Lesen" mit dem jüngsten Eintrag.
Book? currentBook(List<Book> books, List<ReadingEntry> entries) {
  final lesend = books.where((b) => b.status == BookStatus.lesend).toList();
  if (lesend.isEmpty) return null;
  DateTime last(Book b) => entries
      .where((e) => e.bookId == b.id)
      .fold(b.hinzugefuegtAm, (d, e) => e.datum.isAfter(d) ? e.datum : d);
  lesend.sort((a, b) => last(b).compareTo(last(a)));
  return lesend.first;
}

/// Nächstes sichtbares Ziel: ein gepinntes Gebäude oder automatisch das
/// nächste erreichbare Genre-Gebäude passend zum aktuellen Buch. Gebäude, die
/// es in der Stadt noch nicht gibt, werden bevorzugt.
Nahziel? nextGoal({
  required Materials inv,
  required Stufe stufe,
  required Book? aktuellesBuch,
  required List<Building> buildings,
  String? gepinntId,
}) {
  final genres = aktuellesBuch?.genres ?? const <Genre>[];
  if (gepinntId != null) {
    final typ = typeById(gepinntId);
    if (typ != null) return pagesUntil(typ, inv, genres, gepinnt: true);
  }
  if (aktuellesBuch == null) return null;

  final gebaut = buildings.map((b) => b.typeId).toSet();
  final kandidaten = catalog
      .where(
        (t) =>
            t.kategorie == Kategorie.genre &&
            t.abStufe.index <= stufe.index &&
            (genres.isEmpty || genres.contains(t.genre)),
      )
      .map((t) => pagesUntil(t, inv, genres))
      .where((z) => z.seiten != null)
      .toList();
  if (kandidaten.isEmpty) {
    return pagesUntil(typeById('haus')!, inv, genres);
  }
  kandidaten.sort((a, b) {
    final neuA = gebaut.contains(a.typ.id) ? 1 : 0;
    final neuB = gebaut.contains(b.typ.id) ? 1 : 0;
    if (neuA != neuB) return neuA - neuB;
    return a.seiten!.compareTo(b.seiten!);
  });
  return kandidaten.first;
}

// ------------------------------------------------------------ Jahresprojekt

enum Extra {
  fahnen('Fahnen'),
  glocken('Glocken'),
  beleuchtung('Beleuchtung');

  const Extra(this.label);
  final String label;
}

class YearProgress {
  YearProgress(this.jahr, this.ziel, this.beendet);
  final int jahr;
  final int ziel;

  /// Im Jahr beendete Bücher, ältestes zuerst.
  final List<Book> beendet;

  int get abschnitte => min(beendet.length, ziel);
  bool get fertig => ziel > 0 && beendet.length >= ziel;
  int get uebererfuellt => max(0, beendet.length - ziel);
  List<Extra> get extras =>
      Extra.values.take(min(uebererfuellt, Extra.values.length)).toList();
}

YearProgress yearProgress(int jahr, int ziel, List<Book> books) {
  final beendet =
      books
          .where(
            (b) => b.status == BookStatus.beendet && b.beendetAm?.year == jahr,
          )
          .toList()
        ..sort((a, b) => a.beendetAm!.compareTo(b.beendetAm!));
  return YearProgress(jahr, ziel, beendet);
}

// ---------------------------------------------------------------- Bauplätze

/// Freie Felder der Hauptstadt, von der Mitte spiralförmig nach außen.
List<(int, int)> freeTiles(int size, Iterable<Building> buildings) {
  final belegt = {for (final b in buildings) (b.x, b.y)};
  final c = (size - 1) / 2;
  final tiles = [
    for (var x = 0; x < size; x++)
      for (var y = 0; y < size; y++)
        if (!belegt.contains((x, y))) (x, y),
  ];
  double dist((int, int) t) {
    final dx = t.$1 - c, dy = t.$2 - c;
    return max(dx.abs(), dy.abs()) + atan2(dy, dx) / (2 * pi * 10);
  }

  tiles.sort((a, b) => dist(a).compareTo(dist(b)));
  return tiles;
}
