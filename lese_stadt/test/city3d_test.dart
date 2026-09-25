import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lese_stadt/data/db.dart';
import 'package:lese_stadt/model/catalog.dart';
import 'package:lese_stadt/model/genre.dart';
import 'package:lese_stadt/state/city_store.dart';
import 'package:lese_stadt/ui/city3d.dart';
import 'package:lese_stadt/ui/city_painter.dart';

void main() {
  test('Stadtzustand für die 3D-Szene', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 9, 24, 14, 30);
    final store = CityStore(db, clock: () => now);
    await store.load();
    await store.addBook(
      titel: 'Lesend',
      seitenGesamt: 300,
      genres: [Genre.krimi],
      status: BookStatus.lesend,
      gelesenBis: 250,
    );
    await store.addBook(
      titel: 'Fertig',
      seitenGesamt: 100,
      genres: [Genre.fantasy],
      status: BookStatus.beendet,
      gelesenBis: 100,
    );
    await store.addBook(
      titel: 'Wunsch',
      seitenGesamt: 100,
      status: BookStatus.wunsch,
    );
    await store.build(typeById('baeckerei')!, 0, 0);
    await store.build(typeById('strasse')!, 1, 0);

    final scene = buildScene(
      books: store.books,
      entries: store.entries,
      buildings: store.buildings,
      series: store.series,
      yearGoals: store.yearGoals,
      now: now,
    );
    final j = city3dJson(scene, now: now, placing: true, highlight: (1, 0));
    final gebaeude = (j['gebaeude'] as List).cast<Map>();
    final modelle = gebaeude.map((g) => g['modell']).toList();

    expect(j['stunde'], 14.5);
    expect(
      modelle,
      containsAll(['baustelle3', 'buch_fantasy', 'haus', 'baeckerei3d']),
    );
    expect(gebaeude.firstWhere((g) => g['modell'] == 'haus')['geist'], isTrue);
    expect(modelle, isNot(contains('strasse')));
    expect(j['strassen'], [
      [1, 0],
    ]);
    expect(j['arbeitsplaetze'], [
      [0, 0],
    ]);
    expect((j['baustellen'] as List).length, 1);
    expect(j['highlight'], [1, 0]);
    await db.close();
  });
}
