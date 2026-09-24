import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lese_stadt/data/db.dart';
import 'package:lese_stadt/main.dart';
import 'package:lese_stadt/model/genre.dart';
import 'package:lese_stadt/state/city_store.dart';

void main() {
  testWidgets('alle Tabs lassen sich öffnen', (tester) async {
    await initializeDateFormatting('de');
    final db = AppDatabase(NativeDatabase.memory());
    final store = CityStore(db, clock: () => DateTime(2026, 9, 24, 21));
    await tester.runAsync(() async {
      await store.load();
      await store.addBook(
        titel: 'Der Hobbit',
        seitenGesamt: 300,
        genres: [Genre.fantasy],
        status: BookStatus.lesend,
        gelesenBis: 120,
      );
      await store.addBook(
        titel: 'HP 1',
        seitenGesamt: 300,
        genres: [Genre.fantasy],
        status: BookStatus.beendet,
        reihe: 'Harry Potter',
        band: 1,
        gelesenBis: 300,
      );
      await store.setYearGoal(2026, 12);
    });

    await tester.pumpWidget(LeseStadtApp(store: store));
    await tester.pump();
    expect(find.textContaining('Dorf'), findsOneWidget);
    expect(find.textContaining('Magierturm kann jetzt'), findsOneWidget);

    await tester.tap(find.text('Regal'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Der Hobbit'), findsOneWidget);
    await tester.tap(find.text('Reihen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Harry Potter'), findsOneWidget);

    await tester.tap(find.text('Jahr'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Jahresbauwerk 2026'), findsOneWidget);

    await tester.tap(find.text('Chronik'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Jahresrückblick'), findsOneWidget);

    await tester.tap(find.text('Stadt'));
    await tester.pump();
    await tester.tap(find.byTooltip('Baumenü'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Haus'), findsOneWidget);
    expect(find.text('Grundgebäude'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
