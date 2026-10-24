import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lauf_plan/animations.dart';
import 'package:lauf_plan/calendar.dart';
import 'package:lauf_plan/device_calendar.dart';
import 'package:lauf_plan/diary.dart';
import 'package:lauf_plan/free_sessions.dart';
import 'package:lauf_plan/main.dart';
import 'package:lauf_plan/plan_edit.dart';
import 'package:lauf_plan/videos.dart';
import 'package:lauf_plan/weights.dart';
import 'package:lauf_plan/run_log.dart';

void main() {
  setUp(() {
    planOverrides.clear();
    planStart = defaultPlanStart;
  });

  test('Plan startet am Donnerstag, 1.10.2026', () {
    expect(planStart.weekday, DateTime.thursday);
    expect(dateLabel(dateOf(0)), 'Do, 1.10.');
    expect(dateLabel(dateOf(planDays - 1)), 'Mi, 25.11.');
  });

  test('Jeder der 56 Tage hat eine Einheit, nur Slot 3 jeder Woche ist Ruhetag', () {
    for (var d = 0; d < planDays; d++) {
      final s = sessionFor(d);
      expect(s.exercises, isNotEmpty);
      expect(s.isRest, d % 7 == 3);
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
    expect(videoUri(exerciseVideos['Tibialis Raises']!).toString(),
        'https://youtube.com/shorts/3p30KbEgJbo');
  });

  test('Wechselpausen: in Kraft-Einheiten zwischen allen Übungen, nie nach der letzten', () {
    for (final session in [upperBody, legA, legB]) {
      final ex = session.exercises;
      for (var i = 0; i < ex.length - 1; i++) {
        expect(ex[i].restAfter, inInclusiveRange(30, 300), reason: ex[i].name);
      }
      expect(ex.last.restAfter, 0, reason: ex.last.name);
    }
    for (final run in [...baseRuns, ...qualityRuns, ...longRuns, restDay]) {
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
      // Tag 0–2 erledigt, Tag 3 = Ruhetag, heute ist Tag 4.
      final p = plan(day(4), {for (var d = 0; d < 3; d++) d: day(d)});
      expect(p[3].date, day(3));
      expect(p[4].date, day(4));
      expect(p[4].shiftDays, 0);
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
      final d = PlanDay(2, dateOf(2), dateOf(2));
      final e = planEvent(d, const ExportChoice(7 * 60, false));
      expect(e.title, legA.title);
      expect(e.minutes, legA.minutes);
      expect(e.uid, 'laufplan-tag-2@klaas.de');
      expect(e.description, contains('Kniebeuge (Langhantel): 4 × 5'));
    });

    test('Argumente für den Handykalender', () {
      final e = CalEvent(
          uid: 'x', title: 'Dehnen', day: DateTime.utc(2026, 10, 12),
          startMinutes: 7 * 60 + 15, minutes: 20, description: 'Hüfte');
      expect(calendarArgs(e), {
        'year': 2026, 'month': 10, 'day': 12, 'start': 435, 'minutes': 20,
        'allDay': false, 'title': 'Dehnen', 'description': 'Hüfte', 'alarm': 30,
      });
      expect(calendarArgs(e, id: 42)['id'], 42);
    });

    test('Einzelne Einheit mit frei gewähltem Termin', () {
      final d = PlanDay(1, dateOf(1), dateOf(1));
      final e = planEvent(d, ExportChoice(6 * 60, false, date: DateTime.utc(2026, 10, 20)));
      expect(e.day, DateTime.utc(2026, 10, 20));
      expect(e.startMinutes, 6 * 60);
      expect(e.uid, 'laufplan-tag-1@klaas.de');
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
    expect(find.textContaining('Heute, '), findsOneWidget);
    expect(find.textContaining('Anderes Datum'), findsOneWidget);
    // Tage der letzten Woche stehen mit Wochentag zur Auswahl.
    final threeAgo = today.subtract(const Duration(days: 3));
    if (!threeAgo.isBefore(planStart)) {
      expect(find.text('${weekdaysLong[threeAgo.weekday - 1]}, '
          '${threeAgo.day}.${threeAgo.month}. – wie geplant'), findsOneWidget);
    }
    await tester.tap(find.textContaining('Gestern, '));
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

  test('Datum als Freitext', () {
    final today = DateTime.utc(2026, 10, 9);
    expect(parseUserDate('7.10.', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate(' 07.10.2026 ', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate('7.10.26', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate('7.10', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate('7,10', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate('7/10/2026', today), DateTime.utc(2026, 10, 7));
    expect(parseUserDate('31.2.', today), isNull);
    expect(parseUserDate('Freitag', today), isNull);
    expect(parseUserDate('', today), isNull);
  });

  testWidgets('Datum im Abhaken-Fenster eintippen', (tester) async {
    final today = todayDate();
    if (today.difference(planStart).inDays < 1) return; // erst ab Tag 2 sinnvoll
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await pickDoneDate(context, due: today),
          child: const Text('los'),
        ),
      ),
    ));
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'quatsch');
    await tester.tap(find.byTooltip('Übernehmen'));
    await tester.pump();
    expect(find.textContaining('Bitte so eingeben'), findsOneWidget);
    final start = planStart;
    await tester.enterText(find.byType(TextField), '${start.day}.${start.month}.${start.year}');
    await tester.tap(find.byTooltip('Übernehmen'));
    await tester.pumpAndSettle();
    expect(picked, start);
  });

  test('Plan-Schwerpunkt: Beine + Grundlagenausdauer, Oberkörper nur 1× pro Woche', () {
    for (var w = 0; w < planDays ~/ 7; w++) {
      final keys = [for (var i = 0; i < 7; i++) templateKeyFor(w * 7 + i)];
      expect(keys.where((k) => k == 'upper').length, 1);
      expect(keys.where((k) => k == 'legA' || k == 'legB').length, 2);
      expect(keys.where((k) => k.startsWith('base') || k.startsWith('long')).length, 2);
      expect(keys.where((k) => k.startsWith('quality')).length, 1); // Intervalle/Berg nur 1×
    }
    // Bergsprints/Intervalle liegen nie 1–3 Einheiten nach Beine A/B (Ruhetag zählt nicht).
    for (var d = 0; d < planDays; d++) {
      final q = sessionFor(d).title;
      if (q != 'Lauf: Bergsprints' && q != 'Lauf: Intervalle') continue;
      final training = [
        for (var x = d - 1; x > d - 7 && x >= 0; x--)
          if (!sessionFor(x).isRest) templateKeyFor(x)
      ];
      for (var i = 0; i < 3 && i < training.length; i++) {
        expect(training[i], isNot(anyOf('legA', 'legB')), reason: 'Tag $d, $i Einheiten davor');
      }
    }
    final bergsprints = qualityRuns[1].exercises.firstWhere((e) => e.name == 'Bergsprints');
    expect(bergsprints.timer!.rounds, 4);
  });

  test('Oberkörper: gewichtete Dips und Klimmzüge statt EMOM', () {
    final names = upperBody.exercises.map((e) => e.name).toList();
    expect(names, containsAll(['Dips (gewichtet)', 'Klimmzüge (gewichtet)']));
    expect(names.where((n) => n.contains('EMOM')), isEmpty);
    for (final n in ['Dips (gewichtet)', 'Klimmzüge (gewichtet)']) {
      final e = upperBody.exercises.firstWhere((x) => x.name == n);
      expect(e.timer!.rounds, 3);
      expect(e.timer!.work, 0); // manuelle Sätze mit Pausen-Countdown
      expect(exerciseAnims, contains(n));
    }
  });

  group('Plan bearbeiten', () {
    test('Bausteine passen zur bisherigen Reihenfolge', () {
      expect(templateKeyFor(0), 'base0');
      expect(templateKeyFor(1), 'quality0');
      expect(templateKeyFor(2), 'legA');
      expect(templateKeyFor(3), 'rest');
      expect(templateKeyFor(4), 'legB');
      expect(templateKeyFor(5), 'upper');
      expect(templateKeyFor(13), 'long1');
      expect(templateKeyFor(8), 'quality1');
      expect(sessionFor(8).title, 'Lauf: Bergsprints');
    });

    test('JSON hin und zurück', () {
      final j = jsonDecode(jsonEncode(sessionToJson(legA)));
      final back = sessionFromJson(j, legA)!;
      expect(back.title, legA.title);
      expect(back.minutes, legA.minutes);
      expect(back.exercises.length, legA.exercises.length);
      for (var i = 0; i < legA.exercises.length; i++) {
        final a = legA.exercises[i], b = back.exercises[i];
        expect(b.name, a.name);
        expect(b.detail, a.detail);
        expect(b.restAfter, a.restAfter);
        expect(b.timer?.work, a.timer?.work);
        expect(b.timer?.rest, a.timer?.rest);
        expect(b.timer?.rounds, a.timer?.rounds);
        expect(b.timer?.workLabel, a.timer?.workLabel);
      }
    });

    test('Speichern gilt für alle Tage des Bausteins, Zurücksetzen stellt her', () async {
      SharedPreferences.setMockInitialValues({'ex_5_0': true, 'ex_12_2': true, 'done_19': true, 'ex_19_0': true});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      final changed = Session('Oberkörper neu', upperBody.icon, 50, [
        const Exercise('Bankdrücken', '4 × 6', TimerConfig(rest: 150, rounds: 4), 120),
        ...upperBody.exercises,
      ]);
      await saveTemplate(store, 'upper', changed);
      for (final d in [5, 12, 19, 26, 33, 40, 47, 54]) {
        expect(sessionFor(d).title, 'Oberkörper neu', reason: 'Tag $d');
        expect(sessionFor(d).exercises.first.name, 'Bankdrücken');
      }
      expect(sessionFor(2).title, legA.title);
      // Übungs-Haken offener Tage zurückgesetzt, erledigte bleiben.
      expect(store.exDone(5, 0), isFalse);
      expect(store.exDone(12, 2), isFalse);
      expect(store.exDone(19, 0), isTrue);
      // Nach Neustart (neuer Store) weiterhin geändert.
      planOverrides.clear();
      Store(prefs);
      expect(sessionFor(5).exercises.first.name, 'Bankdrücken');
      expect(sessionFor(5).exercises.first.timer!.rounds, 4);
      await saveTemplate(store, 'upper', null);
      expect(sessionFor(5).title, upperBody.title);
      expect(prefs.getString('tpl_upper'), isNull);
    });

    test('Eigene Strichfigur und eigenes Video', () {
      const e = Exercise('Goblet Squat', '3 × 10', null, 0, 'Kniebeuge (Langhantel)', 'https://youtu.be/x');
      expect(animFor(e), same(exerciseAnims['Kniebeuge (Langhantel)']));
      expect(videoFor(e), 'https://youtu.be/x');
      const none = Exercise('Hip Thrust', '', null, 0, '', '');
      expect(animFor(none), isNull);
      expect(videoFor(none), isNull);
      const auto = Exercise('Hip Thrust', '');
      expect(animFor(auto), isNotNull);
      expect(videoFor(auto), isNotNull);
      final back = exerciseFromJson(jsonDecode(jsonEncode(exerciseToJson(e))))!;
      expect(back.anim, 'Kniebeuge (Langhantel)');
      expect(back.video, 'https://youtu.be/x');
    });

    testWidgets('Editor: Baustein öffnen, Übung anlegen, speichern', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SessionEditorScreen(store: store, templateKey: 'legB'))),
            child: const Text('öffnen'),
          ),
        ),
      ));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Hip Thrust'), findsOneWidget);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Übung'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Nordic Curl');
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(sessionFor(4).exercises.last.name, 'Nordic Curl');
      expect(sessionFor(4).exercises.last.timer!.rounds, 3);
      expect(prefs.getString('tpl_legB'), contains('Nordic Curl'));
    });
  });

  group('Gewichte', () {
    test('Anzeige und Eingabe', () {
      expect(kgLabel(60), '60 kg');
      expect(kgLabel(62.5), '62,5 kg');
      expect(kgLabel(61.25), '61,25 kg');
      expect(kgLabel(100), '100 kg');
      expect(kgLabel(0), '0 kg');
      expect(parseKg('62,5'), 62.5);
      expect(parseKg('62.5 kg'), 62.5);
      expect(parseKg(' 70 '), 70);
      expect(parseKg('abc'), isNull);
      expect(parseKg(''), isNull);
    });

    test('Letztes Mal wird bei der nächsten Einheit angezeigt', () async {
      SharedPreferences.setMockInitialValues({});
      final log = WeightLog(await SharedPreferences.getInstance());
      const squat = 'Kniebeuge (Langhantel)';
      expect(log.lastBefore(squat, 7), isNull);
      await log.set(squat, WeightEntry(0, dateOf(0), 60, '4×5'));
      // Woche 2, Beine A (Tag 7): zeigt Woche 1.
      expect(log.lastBefore(squat, 7)!.kg, 60);
      expect(log.lastBefore(squat, 7)!.note, '4×5');
      expect(log.forDay(squat, 7), isNull);
      await log.set(squat, WeightEntry(7, dateOf(7), 62.5));
      expect(log.forDay(squat, 7)!.kg, 62.5);
      expect(log.lastBefore(squat, 14)!.kg, 62.5);
      // Am selben Tag erneut eintragen ersetzt.
      await log.set(squat, WeightEntry(7, dateOf(7), 65));
      expect(log.history(squat).map((w) => w.kg), [65, 60]);
      await log.remove(squat, 7);
      expect(log.history(squat).map((w) => w.kg), [60]);
    });

    test('Nur bei Kraft-Einheiten, nicht beim Aufwärmen', () {
      expect(tracksWeight(2, legA.exercises[1]), isTrue);
      expect(tracksWeight(2, legA.exercises[0]), isFalse); // Aufwärmen
      expect(tracksWeight(1, qualityRuns[0].exercises[0]), isFalse);
      expect(tracksWeight(0, baseRuns[0].exercises[0]), isFalse);
      expect(tracksWeight(5, upperBody.exercises[1]), isTrue);
    });

    testWidgets('Einheit zeigt „Letztes Mal“ und Eingabe', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.weights.set('Kniebeuge (Langhantel)', WeightEntry(0, dateOf(0), 60, '4×5'));
      await tester.pumpWidget(MaterialApp(home: SessionScreen(day: 9, store: store)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Letztes Mal: 60 kg · 4×5'), findsOneWidget);
      await tester.tap(find.text('Gewicht eintragen').first);
      await tester.pumpAndSettle();
      // Vorbelegt mit dem letzten Gewicht, +2,5 kg.
      await tester.tap(find.byTooltip('2,5 kg mehr'));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(store.weights.forDay('Kniebeuge (Langhantel)', 9)!.kg, 62.5);
      expect(find.textContaining('Heute: 62,5 kg'), findsOneWidget);
    });
  });

  group('Läufe', () {
    test('Zeiten, Strecke, Tempo', () {
      expect(parseDuration('34:10'), 34 * 60 + 10);
      expect(parseDuration('1:05:30'), 3600 + 5 * 60 + 30);
      expect(parseDuration('45'), 45 * 60);
      expect(parseDuration('34:75'), isNull);
      expect(parseDuration('abc'), isNull);
      expect(fmtDuration(2050), '34:10');
      expect(fmtDuration(3930), '1:05:30');
      expect(kmLabel(6.2), '6,2 km');
      expect(kmLabel(10), '10 km');
      expect(paceLabel(6.2, 34 * 60 + 10), '5:31 /km');
      expect(paceLabel(null, 100), isNull);
      expect(parseSplits('1:32 1:30, 1:31'), [92, 90, 91]);
      expect(parseSplits('92 90'), [92, 90]);
      expect(parseSplits('1:32 x'), isNull);
    });

    test('Letztes Mal beim nächsten Lauf', () async {
      SharedPreferences.setMockInitialValues({});
      final log = RunLog(await SharedPreferences.getInstance());
      await log.set('Intervalle',
          RunEntry(16, dateOf(16), km: 5.4, secs: 1800, splits: [92, 90, 91, 93, 92, 90]));
      final last = log.lastBefore('Intervalle', 23)!;
      expect(runSummary(last, withDate: false), contains('5,4 km in 30:00'));
      expect(runSummary(last, withDate: false), contains('6× Ø 1:31'));
      expect(log.forDay('Intervalle', 16)!.splits.length, 6);
      await log.remove('Intervalle', 16);
      expect(log.history('Intervalle'), isEmpty);
    });

    test('Nur bei Lauf-Einheiten, Wiederholungszeiten bei Intervallen/Tempo', () {
      expect(tracksRun(0, baseRuns[0].exercises[0]), isTrue);
      expect(tracksRun(1, qualityRuns[0].exercises[0]), isTrue);
      expect(tracksRun(6, longRuns[0].exercises[0]), isTrue);
      expect(tracksRun(2, legA.exercises[1]), isFalse);
      final intervals = qualityRuns[3].exercises.firstWhere((e) => e.name == 'Intervalle');
      expect(hasSplits(intervals), isTrue);
      expect(hasSplits(qualityRuns[0].exercises[0]), isFalse); // Locker laufen
    });

    testWidgets('Lauf-Einheit: eintragen und Tempo sehen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.runs.set('Locker laufen', RunEntry(5, dateOf(5), km: 8, secs: 48 * 60));
      await tester.pumpWidget(MaterialApp(home: SessionScreen(day: 13, store: store)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Letztes Mal: 8 km in 48:00 · 6:00 /km'), findsOneWidget);
      await tester.tap(find.text('Strecke / Zeit eintragen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Strecke'), '9');
      await tester.enterText(find.widgetWithText(TextField, 'Zeit'), '51:45');
      await tester.pump();
      expect(find.text('Tempo: 5:45 /km'), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(store.runs.forDay('Locker laufen', 13)!.secs, 51 * 60 + 45);
      expect(find.textContaining('Heute: 9 km in 51:45'), findsOneWidget);
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
    expect(find.text('Woche 1: Grundlagen aufbauen'), findsOneWidget);
    expect(find.text('Nächste Einheit · 1 von 48'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  group('Der Reihe nach', () {
    testWidgets('Startseite zeigt die erste offene Einheit ohne Datum', (tester) async {
      SharedPreferences.setMockInitialValues({'done_0': true, 'doneOn_0': '2026-10-01'});
      final store = Store(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
      await tester.pumpAndSettle();
      // Tag 0 erledigt, auch wenn Wochen vergangen sind: Tag 1 ist die nächste.
      expect(find.text('Nächste Einheit · 2 von 48'), findsOneWidget);
      expect(find.textContaining('Verschoben'), findsNothing);
    });

    test('Reihenfolge ändert sich: einmal automatisch ab heute neu, Verlauf bleibt', () async {
      SharedPreferences.setMockInitialValues({'done_0': true, 'plan_start': '2026-10-01'});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.weights.set('Kniebeuge (Langhantel)', WeightEntry(2, dateOf(2), 60));
      await store.migrateLayout();
      expect(store.done(0), isFalse);
      expect(planStart, todayDate());
      expect(store.weights.forDay('Kniebeuge (Langhantel)', 2), isNull);
      expect(store.weights.history('Kniebeuge (Langhantel)').single.kg, 60);
      // Nur einmal.
      await store.setDone(0, true);
      await store.migrateLayout();
      expect(store.done(0), isTrue);
    });

    test('Neustart ab heute: Fortschritt zurück, Verlauf bleibt als früherer Durchgang', () async {
      SharedPreferences.setMockInitialValues(
          {'done_0': true, 'doneOn_0': '2026-10-01', 'ex_0_1': true});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.weights.set('Kniebeuge (Langhantel)', WeightEntry(7, dateOf(7), 60));
      await store.runs.set('Locker laufen', RunEntry(5, dateOf(5), km: 8, secs: 2880));
      await store.diary.set(DayEntry(0, dateOf(0), feeling: 4));
      final from = DateTime.utc(2026, 11, 2);
      await store.restartPlan(from);
      expect(planStart, from);
      expect(Store(prefs).done(0), isFalse);
      expect(store.exDone(0, 1), isFalse);
      // Neuer Durchgang beginnt leer, der alte bleibt sichtbar (Letztes Mal).
      expect(store.weights.forDay('Kniebeuge (Langhantel)', 7), isNull);
      expect(store.weights.lastBefore('Kniebeuge (Langhantel)', 7)!.kg, 60);
      expect(store.runs.forDay('Locker laufen', 5), isNull);
      expect(store.runs.history('Locker laufen').single.km, 8);
      expect(store.diary.forDay(0), isNull);
      expect(buildReport(store, today: from), contains('Früherer Durchgang'));
      // Zweiter Neustart kollidiert nicht mit dem ersten.
      await store.weights.set('Kniebeuge (Langhantel)', WeightEntry(7, dateOf(7), 65));
      await store.restartPlan(from);
      expect(store.weights.history('Kniebeuge (Langhantel)').map((w) => w.kg), [65, 60]);
    });
  });

  group('Protokoll', () {
    test('Eintrag speichern, lesen, löschen', () async {
      SharedPreferences.setMockInitialValues({});
      final diary = Diary(await SharedPreferences.getInstance());
      expect(diary.forDay(7), isNull);
      await diary.set(DayEntry(7, dateOf(7),
          feeling: 4, pulseAvg: 142, pulseMax: 171, pain: 2, note: 'schwere Beine'));
      final e = Diary(diary.p).forDay(7)!;
      expect(e.feeling, 4);
      expect(e.pulseMax, 171);
      expect(diarySummary(e),
          'Befinden 4/5 (gut) · Puls Ø 142 / max 171 · Beschwerden 2/10 · „schwere Beine“');
      await diary.remove(7);
      expect(diary.all(), isEmpty);
    });

    test('Bericht enthält Befinden, Puls, Gewichte und Läufe', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = Store(prefs);
      await store.setDone(0, true, on: dateOf(0));
      await store.diary.set(DayEntry(0, dateOf(0), feeling: 3, pulseAvg: 130, pain: 1));
      await store.weights.set('Dips (gewichtet)', WeightEntry(2, dateOf(2), 10, '3×8'));
      await store.weights.set('Dips (gewichtet)', WeightEntry(9, dateOf(9), 12.5));
      await store.runs.set('Locker laufen', RunEntry(5, dateOf(5), km: 8, secs: 48 * 60));
      final report = buildReport(store, today: dateOf(10));
      expect(report, contains('Erledigt: 1 von 48'));
      expect(report, contains('Grundlagenlauf'));
      expect(report, contains('Befinden 3/5 (okay)'));
      expect(report, contains('Puls Ø 130'));
      expect(report, contains('Dips (gewichtet): '));
      expect(report, contains('10 kg (3×8) → '));
      expect(report, contains('12,5 kg'));
      expect(report, contains('8 km in 48:00'));
    });

    test('Körperwerte im Bericht', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final v = Vitals(prefs);
      await v.set(VitalEntry(dateOf(2), restingPulse: 52, bodyKg: 78.5));
      await v.set(VitalEntry(dateOf(9), bodyKg: 78));
      expect(v.forDate(dateOf(2))!.restingPulse, 52);
      final report = buildReport(Store(prefs), today: dateOf(10));
      expect(report, contains('Ruhepuls 52 · 78,5 kg'));
      expect(report, contains('78 kg'));
      await v.remove(dateOf(2));
      expect(v.all().length, 1);
    });

    testWidgets('Einheit: Befinden und Puls eintragen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: SessionScreen(day: 0, store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Befinden & Puls eintragen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 · gut'));
      await tester.enterText(find.widgetWithText(TextField, 'Ø Puls'), '140');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final e = store.diary.forDay(0)!;
      expect(e.feeling, 4);
      expect(e.pulseAvg, 140);
      expect(find.textContaining('Puls Ø 140'), findsOneWidget);
    });
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
