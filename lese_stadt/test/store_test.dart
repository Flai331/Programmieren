import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lese_stadt/data/db.dart';
import 'package:lese_stadt/model/catalog.dart';
import 'package:lese_stadt/model/genre.dart';
import 'package:lese_stadt/state/city_store.dart';

void main() {
  late AppDatabase db;
  late CityStore store;
  var now = DateTime(2026, 9, 24, 12);

  setUp(() async {
    now = DateTime(2026, 9, 24, 12);
    db = AppDatabase(NativeDatabase.memory());
    store = CityStore(db, clock: () => now);
    await store.load();
  });

  tearDown(() => db.close());

  test('neues Buch bekommt ein Denkmal als Bauplan', () async {
    await store.addBook(
      titel: 'Dune',
      seitenGesamt: 600,
      genres: [Genre.scifi],
      status: BookStatus.wunsch,
    );
    expect(store.buildings.single.typeId, typBuchDenkmal);
    expect(store.buildings.single.bookId, store.books.single.id);
  });

  test('Eintragen bringt Material, beendet und startet Bücher', () async {
    final id = await store.addBook(
      titel: 'Dune',
      seitenGesamt: 100,
      genres: [Genre.scifi],
      status: BookStatus.wunsch,
    );
    var book = store.booksById[id]!;
    final g1 = await store.addEntry(book, 40);
    expect(g1, {Mat.holz: 40, Mat.metall: 40});
    book = store.booksById[id]!;
    expect(book.status, BookStatus.lesend);
    expect(() => store.addEntry(book, 40), throwsArgumentError);
    await store.addEntry(book, 100, beenden: true);
    book = store.booksById[id]!;
    expect(book.status, BookStatus.beendet);
    expect(book.beendetAm, now);
    expect(store.inventar[Mat.metall], 100);
    expect(store.aktivitaet, 100);
  });

  test('Bauen kostet Material, Abreißen gibt es zurück', () async {
    await store.addBook(
      titel: 'Krimi',
      seitenGesamt: 100,
      genres: [Genre.krimi],
      status: BookStatus.beendet,
      gelesenBis: 100,
    );
    final wache = typeById('polizeiwache')!;
    expect(await store.build(wache, 0, 0), isTrue);
    expect(store.inventar[Mat.stein], 40);
    expect(store.inventar[Mat.holz], 60);
    expect(await store.build(wache, 0, 0), isFalse, reason: 'Feld belegt');
    expect(await store.build(wache, 1, 0), isFalse, reason: 'zu wenig Stein');
    expect(
      await store.build(typeById('burg')!, 2, 0),
      isFalse,
      reason: 'Stufe',
    );
    await store.demolish(store.buildingAt(0, 0)!);
    expect(store.inventar[Mat.stein], 100);
  });

  test('Reihenbände wohnen im Viertel, nicht in der Hauptstadt', () async {
    final id = await store.addBook(
      titel: 'HP 1',
      seitenGesamt: 300,
      genres: [Genre.fantasy],
      status: BookStatus.lesend,
      reihe: 'Harry Potter',
      band: 1,
    );
    expect(store.series.single.name, 'Harry Potter');
    expect(store.buildings, isEmpty);
    expect(store.districts.single.plots.length, 2); // Band 1 + Gerüst

    await store.addBook(
      titel: 'HP 2',
      seitenGesamt: 300,
      status: BookStatus.wunsch,
      reihe: 'harry potter',
      band: 2,
    );
    expect(store.series.length, 1);

    // Aus der Reihe genommen: jetzt ein Denkmal in der Stadt.
    await store.updateBook(store.booksById[id]!, reihe: '');
    expect(store.buildings.where((b) => b.bookId == id), hasLength(1));
  });

  test('komplette Reihe bringt Bonus', () async {
    await store.addBook(
      titel: 'Band 1',
      seitenGesamt: 10,
      genres: [Genre.horror],
      status: BookStatus.beendet,
      reihe: 'Kurz',
      band: 1,
      gelesenBis: 10,
    );
    final s = store.series.single;
    await store.updateSeries(
      s.copyWith(abgeschlossen: true, baendeGesamt: const Value(1)),
    );
    expect(store.districts.single.komplett, isTrue);
    expect(store.inventar[Mat.schattenholz], 10 + 50);
  });

  test('Buch löschen räumt Einträge, Denkmal und leere Reihe weg', () async {
    final id = await store.addBook(
      titel: 'Weg',
      seitenGesamt: 10,
      status: BookStatus.lesend,
      gelesenBis: 5,
    );
    await store.deleteBook(store.booksById[id]!);
    expect(store.books, isEmpty);
    expect(store.entries, isEmpty);
    expect(store.buildings, isEmpty);

    final id2 = await store.addBook(
      titel: 'R',
      seitenGesamt: 10,
      status: BookStatus.lesend,
      reihe: 'X',
    );
    await store.deleteBook(store.booksById[id2]!);
    expect(store.series, isEmpty);
  });

  test('Jahresziel stellt ein Jahresbauwerk auf', () async {
    await store.setYearGoal(2026, 12);
    expect(store.buildings.single.typeId, typJahresprojekt);
    expect(store.buildings.single.jahr, 2026);
    await store.setYearGoal(2026, 20);
    expect(store.buildings, hasLength(1));
    expect(store.goalFor(2026)!.zielBuecher, 20);
  });

  test('ein Schnappschuss pro Monat', () async {
    await store.addBook(
      titel: 'A',
      seitenGesamt: 10,
      status: BookStatus.wunsch,
    );
    await store.load();
    expect(store.snapshots, hasLength(1));
    await store.load();
    expect(store.snapshots, hasLength(1));
    now = DateTime(2026, 10, 1, 8);
    await store.load();
    expect(store.snapshots, hasLength(2));
  });

  test('Nahziel lässt sich anheften und wird nach dem Bau gelöst', () async {
    await store.addBook(
      titel: 'Holz',
      seitenGesamt: 50,
      status: BookStatus.beendet,
      gelesenBis: 50,
    );
    await store.pin('haus');
    expect(store.nahziel!.gepinnt, isTrue);
    expect(store.nahziel!.seiten, 0);
    await store.build(typeById('haus')!, 0, 0);
    expect(store.gepinnt, isNull);
  });
}
