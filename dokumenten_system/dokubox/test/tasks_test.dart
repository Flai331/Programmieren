import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/tasks.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:dokubox/reminders/notification_service.dart';
import 'package:dokubox/ui/task_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  group('nextDue (Wiederholung)', () {
    final now = DateTime(2026, 11, 10, 12);
    test('einmalig → keine nächste', () {
      expect(nextDue(DateTime(2026, 11, 1), '', now: now), isNull);
    });
    test('monatlich, Monatsende wird begrenzt', () {
      expect(nextDue(DateTime(2027, 1, 31, 9), 'monatlich', now: now),
          DateTime(2027, 2, 28, 9));
    });
    test('vierteljährlich und jährlich', () {
      expect(nextDue(DateTime(2026, 12, 1, 9), 'vierteljaehrlich', now: now),
          DateTime(2027, 3, 1, 9));
      expect(nextDue(DateTime(2026, 12, 1, 9), 'jaehrlich', now: now),
          DateTime(2027, 12, 1, 9));
    });
    test('lange überfällig → nächster Termin in der Zukunft', () {
      expect(nextDue(DateTime(2026, 1, 15, 9), 'monatlich', now: now),
          DateTime(2026, 11, 15, 9));
    });
  });

  test('Gruppen der Übersicht', () {
    final now = DateTime(2026, 11, 10, 12);
    expect(taskGroup(DateTime(2026, 11, 10, 9), null, now: now),
        TaskGroup.overdue);
    expect(taskGroup(DateTime(2026, 11, 10, 18), null, now: now),
        TaskGroup.today);
    expect(taskGroup(DateTime(2026, 11, 13, 9), null, now: now),
        TaskGroup.week);
    expect(taskGroup(DateTime(2026, 12, 1), null, now: now), TaskGroup.later);
    expect(taskGroup(DateTime(2026, 11, 1), now, now: now), TaskGroup.done);
  });

  test('Schnellauswahl liegt immer in der Zukunft', () {
    final late = DateTime(2026, 11, 10, 22);
    for (final c in kDueChoices) {
      expect(c.at(late).isAfter(late), isTrue, reason: c.label);
    }
    expect(kDueChoices[1].at(late), DateTime(2026, 11, 11, 9)); // Morgen 9 Uhr
  });

  group('Repository', () {
    late AppDatabase db;
    late DocumentRepository repo;
    late Document doc;
    setUp(() async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      repo = DocumentRepository(db);
      doc = await repo.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(title: 'Antrag Beihilfe', storageLocation: 'Box'),
        pdfPath: 'pdfs/2026-0001.pdf',
        pageCount: 1,
        ocrText: 'antrag',
      );
    });
    tearDown(() => db.close());

    test('anlegen, ändern, abhaken, wieder öffnen, löschen', () async {
      final now = DateTime.now();
      final t = await repo.createTask(
        documentId: doc.id,
        action: 'versenden',
        note: ' an Beihilfestelle per Mail ',
        dueAt: now.subtract(const Duration(hours: 1)),
      );
      expect(t.note, 'an Beihilfestelle per Mail');
      expect(await repo.watchDueTaskCount().first, 1);

      await repo.updateTask(t.id, note: 'per Post');
      expect((await repo.getTask(t.id))!.note, 'per Post');

      expect(await repo.completeTask(t.id), isNull); // einmalig
      expect((await repo.getTask(t.id))!.doneAt, isNotNull);
      expect(await repo.watchDueTaskCount().first, 0);
      final all = await repo.watchAllTasks().first;
      expect(all.single.doc.docNumber, '2026-0001'); // erledigt, sichtbar

      await repo.reopenTask(t.id);
      expect((await repo.getTask(t.id))!.doneAt, isNull);

      await repo.deleteTask(t.id);
      expect(await repo.watchAllTasks().first, isEmpty);
    });

    test('wiederkehrende Aufgabe legt beim Abhaken die nächste an', () async {
      final t = await repo.createTask(
        documentId: doc.id,
        action: 'pruefen',
        dueAt: DateTime(2026, 11, 1, 9),
        repeat: 'jaehrlich',
      );
      final next =
          await repo.completeTask(t.id, now: DateTime(2026, 11, 2, 10));
      expect(next!.dueAt, DateTime(2027, 11, 1, 9));
      expect(next.action, 'pruefen');
      expect(next.repeat, 'jaehrlich');
      final tasks = await repo.watchTasksForDocument(doc.id).first;
      expect(tasks.first.id, next.id); // offene zuerst
    });

    test('verschieben: überfällig → morgen 9 Uhr', () async {
      final now = DateTime(2026, 11, 10, 15);
      final t = await repo.createTask(
          documentId: doc.id, action: 'anrufen', dueAt: DateTime(2026, 11, 9, 9));
      final next =
          await repo.snoozeTask(t.id, const Duration(days: 1), now: now);
      expect(next, DateTime(2026, 11, 11, 9));
    });

    test('offene Aufgaben einer Aktion finden (Ausfüllen/Versenden)', () async {
      await repo.createTask(
          documentId: doc.id, action: 'ausfuellen', dueAt: DateTime.now());
      await repo.createTask(
          documentId: doc.id, action: 'versenden', dueAt: DateTime.now());
      final open =
          await repo.openTasksFor(doc.id, {'ausfuellen', 'unterschreiben'});
      expect(open.single.action, 'ausfuellen');
    });

    test('Aufgaben gelöschter Dokumente verschwinden aus der Übersicht',
        () async {
      await repo.createTask(
          documentId: doc.id, action: 'bezahlen', dueAt: DateTime.now());
      await repo.softDeleteDocument(doc.id);
      expect(await repo.watchAllTasks().first, isEmpty);
      expect(await repo.watchDueTaskCount().first, 0);
    });
  });

  test('Benachrichtigung: Aktion, Titel, Notiz, Nummer; Tippen → Dokument',
      () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    final doc = await repo.createDocument(
      docNumber: '2026-0042',
      draft: DocumentDraft(title: 'Antrag Beihilfe', storageLocation: 'Box'),
      pdfPath: 'p.pdf',
      pageCount: 1,
      ocrText: '',
    );
    final task = await repo.createTask(
        documentId: doc.id,
        action: 'versenden',
        note: 'an Beihilfestelle per Mail',
        dueAt: DateTime(2026, 11, 20, 9));
    final text = NotificationService.taskText(task, doc);
    expect(text.title, 'Versenden: Antrag Beihilfe');
    expect(text.body, 'an Beihilfestelle per Mail · 2026-0042');
    final payload = NotificationService.payloadFor(doc.id);
    expect(NotificationService.documentIdFromPayload(payload), doc.id);
    expect(NotificationService.documentIdFromPayload('x'), isNull);
    await db.close();
  });

  test('Termin-Anzeige und „Jetzt …“-Knöpfe', () async {
    await initializeDateFormatting('de_DE');
    final now = DateTime(2026, 11, 10, 12);
    expect(taskDueLabel(DateTime(2026, 11, 10, 18), now: now), 'heute 18:00');
    expect(taskDueLabel(DateTime(2026, 11, 11, 9), now: now), 'morgen 09:00');
    expect(taskDueLabel(DateTime(2026, 11, 20, 9), now: now),
        'Fr., 20.11.2026 · 09:00');
    expect(quickActionFor('ausfuellen'), TaskQuickAction.fill);
    expect(quickActionFor('unterschreiben'), TaskQuickAction.fill);
    expect(quickActionFor('versenden'), TaskQuickAction.share);
    expect(quickActionFor('bezahlen'), TaskQuickAction.paid);
    expect(quickActionFor('anrufen'), isNull);
  });
}
