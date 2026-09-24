import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lese_stadt/data/db.dart';
import 'package:lese_stadt/logic/chronicle.dart';
import 'package:lese_stadt/logic/economy.dart';
import 'package:lese_stadt/logic/progress.dart';
import 'package:lese_stadt/logic/series.dart';
import 'package:lese_stadt/model/catalog.dart';
import 'package:lese_stadt/model/genre.dart';

final _t0 = DateTime(2026, 1, 1);

Book book(
  int id, {
  List<Genre> genres = const [],
  BookStatus status = BookStatus.lesend,
  int seiten = 300,
  int? seriesId,
  int? band,
  DateTime? beendetAm,
  DateTime? hinzugefuegtAm,
}) => Book(
  id: id,
  titel: 'Buch $id',
  autor: '',
  seitenGesamt: seiten,
  genres: genres,
  status: status,
  seriesId: seriesId,
  seriesIndex: band,
  hinzugefuegtAm: hinzugefuegtAm ?? _t0,
  beendetAm: beendetAm,
);

ReadingEntry entry(int id, int bookId, int von, int bis, [DateTime? datum]) =>
    ReadingEntry(
      id: id,
      bookId: bookId,
      datum: datum ?? _t0,
      vonSeite: von,
      bisSeite: bis,
    );

Building building(int id, String typ, int x, int y, [DateTime? am]) =>
    Building(id: id, typeId: typ, x: x, y: y, gebautAm: am ?? _t0);

Series series(int id, {int? baende, bool fertig = false, int pos = 0}) =>
    Series(
      id: id,
      name: 'Reihe $id',
      baendeGesamt: baende,
      abgeschlossen: fertig,
      viertelPosition: pos,
    );

void main() {
  group('Material', () {
    test('jede Seite bringt Holz und Genre-Material', () {
      expect(materialsForPages(10, [Genre.fantasy]), {
        Mat.holz: 10,
        Mat.kristall: 10,
      });
    });

    test('mehrere Genres teilen das Genre-Material auf', () {
      expect(materialsForPages(11, [Genre.krimi, Genre.horror]), {
        Mat.holz: 11,
        Mat.stein: 6,
        Mat.schattenholz: 5,
      });
    });

    test('ohne Genre gibt es nur Holz', () {
      expect(materialsForPages(7, const []), {Mat.holz: 7});
    });

    test('Zugewinn eines Eintrags summiert sich exakt auf', () {
      final g = [Genre.krimi, Genre.horror];
      final a = materialsGained(0, 5, g);
      final b = materialsGained(5, 6, g);
      final sum = <Mat, int>{};
      addInto(sum, a);
      addInto(sum, b);
      expect(sum, materialsForPages(11, g));
    });

    test('Inventar zieht Baukosten ab und rechnet Boni dazu', () {
      final inv = inventory(
        books: [
          book(1, genres: [Genre.fantasy]),
        ],
        entries: [entry(1, 1, 0, 100)],
        buildings: [
          building(1, 'magierturm', 0, 0),
          building(2, typBuchDenkmal, 1, 1),
        ],
        boni: [
          {Mat.gold: 5},
        ],
      );
      expect(inv[Mat.holz], 60);
      expect(inv[Mat.kristall], 40);
      expect(inv[Mat.gold], 5);
    });
  });

  group('Stufen', () {
    test('Schwellen', () {
      expect(Stufe.fuerSeiten(0), Stufe.dorf);
      expect(Stufe.fuerSeiten(1999), Stufe.dorf);
      expect(Stufe.fuerSeiten(2000), Stufe.kleinstadt);
      expect(Stufe.fuerSeiten(10000), Stufe.stadt);
      expect(Stufe.fuerSeiten(50000), Stufe.metropole);
      expect(Stufe.metropole.naechste, isNull);
    });

    test('Katalog hat eindeutige Ids und Kombi braucht 3+ Materialien', () {
      expect(catalog.map((t) => t.id).toSet().length, catalog.length);
      for (final t in catalog.where((t) => t.kategorie == Kategorie.kombi)) {
        expect(t.kosten.length, greaterThanOrEqualTo(3), reason: t.id);
      }
      for (final t in catalog.where((t) => t.kategorie == Kategorie.grund)) {
        expect(t.kosten.keys, [Mat.holz]);
      }
    });
  });

  group('Nahziel', () {
    test('Seiten bis zum Magierturm', () {
      final typ = typeById('magierturm')!;
      final z = pagesUntil(
        typ,
        {Mat.holz: 30, Mat.kristall: 26},
        [Genre.fantasy],
      );
      expect(z.seiten, 34);
      expect(z.text, 'Noch 34 Seiten bis zum Magierturm');
    });

    test('bei zwei Genres zählt jede Seite halb', () {
      final typ = typeById('magierturm')!;
      final z = pagesUntil(typ, {Mat.holz: 100}, [Genre.fantasy, Genre.krimi]);
      expect(z.seiten, 120);
    });

    test('Material aus anderem Genre ist nicht erreichbar', () {
      final z = pagesUntil(typeById('labor')!, {}, [Genre.fantasy]);
      expect(z.seiten, isNull);
      expect(z.fehlt, {Mat.metall: 250});
    });

    test('automatisch passend zum aktuellen Buch, Ungebautes zuerst', () {
      final b = book(1, genres: [Genre.fantasy]);
      final z = nextGoal(
        inv: {Mat.holz: 500, Mat.kristall: 500},
        stufe: Stufe.kleinstadt,
        aktuellesBuch: b,
        buildings: [building(1, 'magierturm', 0, 0)],
      );
      expect(z!.typ.id, 'burg');
      expect(z.seiten, 0);
    });

    test('gepinntes Ziel hat Vorrang', () {
      final z = nextGoal(
        inv: {},
        stufe: Stufe.dorf,
        aktuellesBuch: null,
        buildings: const [],
        gepinntId: 'haus',
      );
      expect(z!.gepinnt, isTrue);
      expect(z.seiten, 30);
    });

    test('aktuelles Buch ist das mit dem jüngsten Eintrag', () {
      final books = [book(1), book(2), book(3, status: BookStatus.wunsch)];
      final entries = [
        entry(1, 1, 0, 10, DateTime(2026, 3, 1)),
        entry(2, 2, 0, 10, DateTime(2026, 3, 5)),
      ];
      expect(currentBook(books, entries)!.id, 2);
    });
  });

  group('Lebendige Stadt', () {
    test('Aktivität zählt nur die letzten 7 Tage', () {
      final now = DateTime(2026, 5, 10, 18);
      final entries = [
        entry(1, 1, 0, 50, DateTime(2026, 5, 4, 9)),
        entry(2, 1, 50, 80, DateTime(2026, 5, 3, 22)),
      ];
      expect(activityValue(entries, now), 50);
      expect(belebungFuer(0), Belebung.still);
      expect(belebungFuer(50), Belebung.wenige);
      expect(belebungFuer(100), Belebung.licht);
      expect(belebungFuer(300), Belebung.fest);
    });
  });

  group('Reihen', () {
    test(
      'Bände werden nach Nummer zugeordnet, ohne Nummer auf freie Plätze',
      () {
        final v = assignVolumes([
          book(1, seriesId: 1, band: 2),
          book(2, seriesId: 1),
          book(3, seriesId: 1, band: 2, status: BookStatus.beendet),
        ], null);
        expect(v[1]!.id, 2);
        expect(v[2]!.id, 3);
      },
    );

    test('Reihe komplett erst, wenn alle Bände beendet und erschienen', () {
      final s = series(1, baende: 2, fertig: true);
      final b1 = book(1, seriesId: 1, band: 1, status: BookStatus.beendet);
      final b2 = book(2, seriesId: 1, band: 2, status: BookStatus.lesend);
      expect(isSeriesComplete(s, [b1, b2]), isFalse);
      expect(
        isSeriesComplete(s, [b1, b2.copyWith(status: BookStatus.beendet)]),
        isTrue,
      );
      expect(
        isSeriesComplete(series(1, baende: 2), [
          b1,
          b2.copyWith(status: BookStatus.beendet),
        ]),
        isFalse,
      );
    });

    test('Viertel: Bauplätze, Gerüst und Wahrzeichen', () {
      final districts = layoutDistricts(
        series: [
          series(1, baende: 3),
          series(2, baende: 1, fertig: true, pos: 1),
        ],
        books: [
          book(
            1,
            seriesId: 1,
            band: 1,
            status: BookStatus.beendet,
            genres: [Genre.fantasy],
          ),
          book(2, seriesId: 1, band: 2, status: BookStatus.lesend),
          book(3, seriesId: 2, band: 1, status: BookStatus.beendet),
        ],
        citySize: 10,
      );
      final a = districts[0];
      expect(a.plots.map((p) => p.state), [
        PlotState.fertig,
        PlotState.baustelle,
        PlotState.geist,
        PlotState.geruest,
      ]);
      expect(a.stilName, 'Burgdorf');
      expect(a.x0, 12);
      final b = districts[1];
      expect(b.komplett, isTrue);
      expect(b.plots.last.state, PlotState.wahrzeichen);
      expect(b.y0, a.y0 + a.hoehe + 1);
      final roads = districtRoads(districts, 10);
      expect(roads, contains((11, b.y0)));
    });

    test('lange Reihen werden quadratisch', () {
      final d = layoutDistricts(
        series: [series(1, baende: 16, fertig: true)],
        books: const [],
        citySize: 10,
      );
      expect(d.single.breite, 4);
      expect(d.single.hoehe, 4);
    });
  });

  group('Jahresprojekt', () {
    test('Abschnitte und Extras', () {
      final books = [
        for (var i = 1; i <= 5; i++)
          book(i, status: BookStatus.beendet, beendetAm: DateTime(2026, i, 1)),
        book(9, status: BookStatus.beendet, beendetAm: DateTime(2025, 12, 1)),
      ];
      final p = yearProgress(2026, 3, books);
      expect(p.abschnitte, 3);
      expect(p.fertig, isTrue);
      expect(p.extras, [Extra.fahnen, Extra.glocken]);
      expect(yearProgress(2026, 12, books).fertig, isFalse);
    });
  });

  group('Bauplätze', () {
    test('freie Felder beginnen in der Mitte', () {
      final tiles = freeTiles(10, [building(1, 'haus', 4, 4)]);
      expect(tiles.length, 99);
      expect(tiles.first, isNot((4, 4)));
      final (x, y) = tiles.first;
      expect((x - 4.5).abs() <= 1 && (y - 4.5).abs() <= 1, isTrue);
    });
  });

  group('Chronik', () {
    test('Jahresrückblick', () {
      final books = [
        book(
          1,
          genres: [Genre.krimi],
          status: BookStatus.beendet,
          seiten: 500,
          beendetAm: DateTime(2026, 2, 1),
        ),
        book(
          2,
          genres: [Genre.fantasy],
          status: BookStatus.beendet,
          seiten: 200,
          beendetAm: DateTime(2026, 3, 1),
          seriesId: 1,
          band: 1,
        ),
      ];
      final entries = [
        entry(1, 1, 0, 500, DateTime(2026, 1, 20)),
        entry(2, 2, 0, 200, DateTime(2026, 2, 20)),
      ];
      final r = yearReview(
        jahr: 2026,
        books: books,
        entries: entries,
        series: [series(1, baende: 1, fertig: true)],
      );
      expect(r.buecher.length, 2);
      expect(r.seiten, 700);
      expect(r.topGenre, Genre.krimi);
      expect(r.laengstesBuch!.id, 1);
      expect(r.reihen.single.id, 1);
    });

    test('Zeitraffer: Status zum Stichtag', () {
      final b = book(
        1,
        status: BookStatus.beendet,
        hinzugefuegtAm: DateTime(2026, 1, 5),
        beendetAm: DateTime(2026, 3, 1),
      );
      final entries = [entry(1, 1, 0, 10, DateTime(2026, 2, 1))];
      expect(booksAt([b], entries, DateTime(2026, 1, 2)), isEmpty);
      expect(
        booksAt([b], entries, DateTime(2026, 1, 10)).single.status,
        BookStatus.wunsch,
      );
      expect(
        booksAt([b], entries, DateTime(2026, 2, 10)).single.status,
        BookStatus.lesend,
      );
      expect(
        booksAt([b], entries, DateTime(2026, 3, 10)).single.status,
        BookStatus.beendet,
      );
    });

    test('Schnappschuss fasst Buch-Denkmäler zusammen', () {
      final json = snapshotJson(
        [
          building(1, typBuchDenkmal, 0, 0).copyWith(bookId: const Value(1)),
          building(2, typBuchDenkmal, 1, 0).copyWith(bookId: const Value(2)),
          building(3, 'haus', 2, 0),
        ],
        {1: book(1), 2: book(2)},
      );
      final s = summarizeSnapshot(
        CitySnapshot(id: 1, datum: _t0, gebaeudeJson: json),
      );
      expect(s.gesamt, 3);
      expect(s.proName, {'Buch-Denkmäler': 2, 'Haus': 1});
    });
  });
}
