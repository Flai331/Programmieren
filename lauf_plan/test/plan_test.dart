import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lauf_plan/animations.dart';
import 'package:lauf_plan/calendar.dart';
import 'package:lauf_plan/free_sessions.dart';
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

  group('Kalender-Export (.ics)', () {
    final now = DateTime.utc(2026, 10, 8, 9, 30);

    test('Termin mit Uhrzeit', () {
      final ics = buildIcs([
        CalEvent(
            uid: 'a@x', title: 'Beine A – Kraft', day: DateTime.utc(2026, 10, 9),
            startMinutes: 18 * 60 + 30, minutes: 60, description: 'Zeile 1\nZeile 2; mit, Zeichen'),
      ], now: now);
      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(ics, contains('DTSTART:20261009T183000\r\n'));
      expect(ics, contains('DTEND:20261009T193000\r\n'));
      expect(ics, contains('DTSTAMP:20261008T093000Z'));
      expect(ics, contains('SUMMARY:Beine A – Kraft'));
      expect(ics, contains('DESCRIPTION:Zeile 1\\nZeile 2\\; mit\\, Zeichen'));
      expect(ics, contains('TRIGGER:-PT30M'));
    });

    test('ganztägig und über Mitternacht', () {
      final ics = buildIcs([
        CalEvent(uid: 'b@x', title: 'Lauf', day: DateTime.utc(2026, 10, 31), allDay: true),
        CalEvent(
            uid: 'c@x', title: 'Spät', day: DateTime.utc(2026, 10, 31),
            startMinutes: 23 * 60 + 30, minutes: 60),
      ], now: now);
      expect(ics, contains('DTSTART;VALUE=DATE:20261031\r\nDTEND;VALUE=DATE:20261101'));
      expect(ics, contains('DTEND:20261101T003000'));
      expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
    });

    test('lange Zeilen werden auf 75 Bytes umbrochen', () {
      final ics = buildIcs([
        CalEvent(uid: 'd@x', title: 'Ü' * 100, day: DateTime.utc(2026, 10, 9)),
      ], now: now);
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      final unfolded = ics.replaceAll('\r\n ', '');
      expect(unfolded, contains('SUMMARY:${'Ü' * 100}'));
    });

    test('Plan-Einheit als Termin', () {
      final d = PlanDay(0, dateOf(0), dateOf(0));
      final e = planEvent(d, const ExportChoice(7 * 60, false));
      expect(e.title, legA.title);
      expect(e.minutes, legA.minutes);
      expect(e.uid, 'laufplan-tag-0@klaas.de');
      expect(e.description, contains('Kniebeuge (Langhantel): 4 × 5'));
    });

    test('Dateiname', () {
      expect(icsFileName('Beine A – Kraft', DateTime.utc(2026, 10, 9)),
          'beine-a-kraft-2026-10-09.ics');
      expect(icsFileName('Dehnen & Rücken', DateTime.utc(2026, 1, 2)),
          'dehnen-ruecken-2026-01-02.ics');
    });
  });

  test('Freie Einheiten speichern, ändern, löschen', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FreeStore(await SharedPreferences.getInstance());
    expect(store.all(), isEmpty);
    final a = FreeSession(id: '1', title: 'Dehnen', date: DateTime.utc(2026, 10, 10),
        startMinutes: 7 * 60, minutes: 15, notes: 'Hüfte');
    final b = FreeSession(id: '2', title: 'Yoga', date: DateTime.utc(2026, 10, 9));
    await store.upsert(a);
    await store.upsert(b);
    expect(store.all().map((s) => s.id), ['2', '1']);
    await store.upsert(a.copyWith(title: 'Dehnen lang', minutes: 30));
    final saved = store.all().last;
    expect(saved.title, 'Dehnen lang');
    expect(saved.minutes, 30);
    expect(saved.notes, 'Hüfte');
    expect(saved.toEvent().uid, 'laufplan-frei-1@klaas.de');
    await store.remove('2');
    expect(store.all().map((s) => s.id), ['1']);
  });

  testWidgets('Freie Einheit anlegen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(TrainingApp(store: Store(prefs)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Neu'), 200);
    await tester.tap(find.text('Neu'));
    await tester.pumpAndSettle();
    expect(find.text('Freie Einheit'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final saved = FreeStore(prefs).all().single;
    expect(saved.title, 'Dehnen');
    expect(saved.replacesPlan, isFalse);
  });

  testWidgets('Knopf „Freie Einheit“ auf der Startseite', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(TrainingApp(store: Store(prefs)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Freie Einheit'));
    await tester.pumpAndSettle();
    expect(find.text('Statt Plan-Einheit'), findsOneWidget);
    expect(find.text('Zusätzlich'), findsOneWidget);
    expect(find.text('Dauer (Zeitansatz)'), findsOneWidget);
  });

  group('Freie Einheit statt Plan-Einheit', () {
    test('Plan-Einheit an dem Tag rückt einen Tag nach hinten', () {
      final p = computeSchedule(dateOf(0), (_) => false, (_) => null,
          blocked: {dateOf(1)});
      expect(p[0].date, dateOf(0));
      expect(p[1].date, dateOf(2));
      expect(p[1].shiftDays, 1);
      expect(p[2].date, dateOf(3));
    });

    test('zusätzlich verschiebt nichts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.free.upsert(FreeSession(id: 'z', title: 'Dehnen', date: dateOf(1)));
      expect(store.free.blockedDates(), isEmpty);
      await store.free.upsert(
          FreeSession(id: 'z', title: 'Dehnen', date: dateOf(1), replacesPlan: true));
      expect(store.free.blockedDates(), {dateOf(1)});
      expect(store.free.blockedDates(exceptId: 'z'), isEmpty);
      expect(store.free.all().single.replacesPlan, isTrue);
      // Ohne die eigene Sperre liegt dort die Plan-Einheit.
      final day1 = store.schedule(dateOf(0), 'z')[1];
      expect(day1.date, dateOf(1));
      expect(store.schedule(dateOf(0))[1].date, dateOf(2));
    });
  });

  testWidgets('Nachträglich abhaken: Gestern wählbar, Plan passt sich an', (tester) async {
    final today = todayDate();
    final yesterday = today.subtract(const Duration(days: 1));
    if (yesterday.isBefore(planStart)) return; // nur sinnvoll ab Tag 2 des Plans
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await pickDoneDate(context, due: today.subtract(const Duration(days: 3))),
          child: const Text('los'),
        ),
      ),
    ));
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Heute ('), findsOneWidget);
    expect(find.textContaining('Anderes Datum'), findsOneWidget);
    await tester.tap(find.textContaining('Gestern ('));
    await tester.pumpAndSettle();
    expect(picked, yesterday);
  });

  test('Für gestern abgehakt: Folgetage rücken wieder vor', () {
    // Tag 0 erledigt, Tag 1 gestern gemacht aber erst heute (Tag 2) abgehakt.
    final before = computeSchedule(dateOf(2), {0}.contains, (_) => dateOf(0));
    expect(before[2].shiftDays, 1);
    final after = computeSchedule(
        dateOf(2), {0, 1}.contains, (d) => d == 0 ? dateOf(0) : dateOf(1));
    expect(after[1].date, dateOf(1));
    expect(after[2].date, dateOf(2));
    expect(after[2].shiftDays, 0);
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
