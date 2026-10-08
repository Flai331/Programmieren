import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  test('Wechselpausen: in Kraft-Einheiten zwischen allen Übungen, nie nach der letzten', () {
    for (final session in [upperBody, legA, legB]) {
      final ex = session.exercises;
      for (var i = 0; i < ex.length - 1; i++) {
        expect(ex[i].restAfter, inInclusiveRange(30, 300), reason: ex[i].name);
      }
      expect(ex.last.restAfter, 0, reason: ex.last.name);
    }
    for (final run in [...qualityRuns, ...longRuns, restDay]) {
      for (final e in run.exercises) {
        expect(e.restAfter, 0);
      }
    }
  });

  testWidgets('Pausen-Timer zählt runter und zeigt die nächste Übung', (tester) async {
    // Systemtöne/Vibration gibt es im Test nicht.
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await tester.pumpWidget(MaterialApp(
        home: RestScreen(seconds: 5, next: legA.exercises[1])));
    expect(find.text('Kniebeuge (Langhantel)'), findsOneWidget);
    expect(find.text('0:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:03'), findsOneWidget);
    await tester.tap(find.text('+30 Sek.'));
    await tester.pump();
    expect(find.text('0:33'), findsOneWidget);
    await tester.pump(const Duration(seconds: 33));
    expect(find.text('Los'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('Plan verschiebt sich', () {
    DateTime day(int n) => dateOf(n);
    List<PlanDay> plan(DateTime today, Map<int, DateTime?> done) =>
        computeSchedule(today, done.containsKey, (d) => done[d]);

    test('alles im Plan: Datum wie ursprünglich', () {
      final p = plan(day(0), {});
      for (var d = 0; d < planDays; d++) {
        expect(p[d].date, dateOf(d));
        expect(p[d].shiftDays, 0);
      }
    });

    test('verpasste Einheit rückt auf heute, alles danach wandert mit', () {
      // Do erledigt, Fr verpasst, heute ist Sa.
      final p = plan(day(2), {0: day(0)});
      expect(p[0].date, day(0));
      expect(p[1].date, day(2));
      expect(p[1].due, day(1));
      for (var d = 1; d < planDays; d++) {
        expect(p[d].shiftDays, 1, reason: 'Tag $d');
      }
    });

    test('mehrere Tage nichts gemacht: Verschiebung wächst', () {
      final p = plan(day(3), {});
      expect(p[0].date, day(3));
      expect(p.last.date, day(planDays - 1 + 3));
    });

    test('nachträglich am geplanten Tag abgehakt: keine Verschiebung', () {
      final p = plan(day(2), {0: day(0), 1: day(1)});
      for (var d = 0; d < planDays; d++) {
        expect(p[d].date, dateOf(d));
      }
    });

    test('nicht abgehakter Ruhetag verschiebt nichts', () {
      // Do–Di (Tag 0–5) erledigt, Mi = Ruhetag, heute ist Do (Tag 7).
      final p = plan(day(7), {for (var d = 0; d < 6; d++) d: day(d)});
      expect(p[6].date, day(6));
      expect(p[7].date, day(7));
      expect(p[7].shiftDays, 0);
    });

    test('alte Haken ohne Datum zählen am ursprünglichen Tag', () {
      final p = plan(day(1), {0: null});
      expect(p[0].date, day(0));
      expect(p[1].date, day(1));
    });
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
