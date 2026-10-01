import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lauf_plan/animations.dart';
import 'package:lauf_plan/main.dart';
import 'package:lauf_plan/videos.dart';

void main() {
  test('Plan startet am Donnerstag, 1.10.2026', () {
    expect(planStart.weekday, DateTime.thursday);
    expect(dateLabel(dateOf(0)), 'Do, 1.10.');
    expect(dateLabel(dateOf(planDays - 1)), 'Mi, 28.10.');
  });

  test('Jeder der 28 Tage hat eine Einheit, Mittwoch ist Ruhetag', () {
    for (var d = 0; d < planDays; d++) {
      final s = sessionFor(d);
      expect(s.exercises, isNotEmpty);
      expect(s.isRest, dateOf(d).weekday == DateTime.wednesday);
    }
  });

  test('Jede Animation gehört zu einer Übung im Plan', () {
    final names = {
      for (var d = 0; d < planDays; d++)
        for (final e in sessionFor(d).exercises) e.name
    };
    for (final name in exerciseAnims.keys) {
      expect(names, contains(name));
    }
  });

  test('Erklärvideos gibt es genau für die Bein-Übungen', () {
    final legNames = {
      for (final e in [...legA.exercises, ...legB.exercises]) e.name
    };
    for (final name in exerciseVideos.keys) {
      expect(legNames, contains(name));
    }
    for (final e in [...legA.exercises, ...legB.exercises]) {
      if (e.name == 'Aufwärmen') continue;
      expect(exerciseVideos, contains(e.name));
    }
    expect(videoUri('Hip Thrust').toString(),
        'https://www.youtube.com/results?search_query=Hip+Thrust');
  });

  test('fmt formatiert Minuten und Sekunden', () {
    expect(fmt(0), '0:00');
    expect(fmt(65), '1:05');
    expect(fmt(480), '8:00');
  });

  testWidgets('Startseite zeigt den Plan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(TrainingApp(store: Store(prefs)));
    await tester.pumpAndSettle();
    expect(find.text('Laufplan'), findsOneWidget);
    expect(find.textContaining('Woche 1'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Animation lässt sich zeichnen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          for (final a in exerciseAnims.values) ExerciseAnimation(anim: a, size: 40),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(ExerciseAnimation), findsNWidgets(exerciseAnims.length));
  });
}
