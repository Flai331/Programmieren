import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/extract/deadlines.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ostern und Feiertage', () {
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    final ni = holidays(2026, state: 'NI');
    expect(ni, contains(DateTime(2026, 10, 31))); // Reformationstag
    expect(ni, isNot(contains(DateTime(2026, 11, 1))));
    expect(holidays(2026, state: 'SN'), contains(DateTime(2026, 11, 18)));
    expect(holidays(2026, state: 'NW'), contains(DateTime(2026, 6, 4)));
  });

  test('Fristende am Wochenende/Feiertag → nächster Werktag', () {
    expect(nextWorkday(DateTime(2026, 11, 14)), DateTime(2026, 11, 16)); // Sa
    expect(nextWorkday(DateTime(2026, 10, 31), state: 'NI'),
        DateTime(2026, 11, 2)); // Sa + Reformationstag
    expect(nextWorkday(DateTime(2026, 11, 18), state: 'SN'),
        DateTime(2026, 11, 19)); // Buß- und Bettag
    expect(nextWorkday(DateTime(2026, 11, 18), state: 'NI'),
        DateTime(2026, 11, 18));
  });

  group('Widerspruchsfrist', () {
    const bescheid = 'Rechtsbehelfsbelehrung: Gegen diesen Bescheid kann '
        'innerhalb eines Monats nach Bekanntgabe Widerspruch erhoben werden.';

    test('ein Monat ab Bekanntgabe (Briefdatum + 4 Tage)', () {
      // 06.11.2026 + 4 = 10.11. → 10.12.2026 (Do)
      expect(extractObjectionDeadline(bescheid, DateTime(2026, 11, 6)),
          DateTime(2026, 12, 10));
    });

    test('Monatsende und Wochenende', () {
      // 27.01.2026 + 4 = 31.01. → 28.02.2026 (Sa) → Mo 02.03.
      expect(extractObjectionDeadline(bescheid, DateTime(2026, 1, 27)),
          DateTime(2026, 3, 2));
    });

    test('Wochen und ausdrückliches Datum', () {
      expect(
          extractObjectionDeadline(
              'Einspruch ist binnen zwei Wochen nach Bekanntgabe möglich.',
              DateTime(2026, 11, 2)),
          DateTime(2026, 11, 20));
      expect(
          extractObjectionDeadline(
              'Widerspruch können Sie bis zum 15.12.2026 einlegen.', null),
          DateTime(2026, 12, 15));
    });

    test('kein Bescheid → nichts', () {
      expect(
          extractObjectionDeadline(
              'Zahlbar innerhalb eines Monats.', DateTime(2026, 1, 1)),
          isNull);
    });
  });

  test('Garantie erkennen', () {
    final w = extractWarranty(
        'Fernseher XY, 3 Jahre Herstellergarantie', DateTime(2026, 2, 28))!;
    expect(w.until, DateTime(2029, 2, 28));
    expect(extractWarranty('Garantie: 24 Monate', DateTime(2026, 1, 31))!.until,
        DateTime(2028, 1, 31));
    expect(extractWarranty('Rechnung Handwerker', DateTime(2026, 1, 1)), isNull);
  });

  test('Speichern legt Erinnerungen an, Garantie schützt vor Ausmisten',
      () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    final draft = DocumentDraft(
      title: 'Bescheid',
      storageLocation: 'Box',
      objectionDeadline: DateTime(2026, 12, 10),
      warrantyUntil: DateTime(2030, 1, 31),
      warrantyKind: 'garantie',
      retentionUntil: DateTime(2020, 1, 1), // längst abgelaufen
    );
    final doc = await repo.createDocument(
        docNumber: '2026-0001',
        draft: draft,
        pdfPath: 'p.pdf',
        pageCount: 1,
        ocrText: '');
    final tasks = await repo.watchTasksForDocument(doc.id).first;
    expect({for (final t in tasks) t.origin: t.dueAt}, {
      'widerspruch': DateTime(2026, 12, 3, 9),
      'garantie': DateTime(2030, 1, 3, 9),
    });
    expect(tasks.firstWhere((t) => t.origin == 'widerspruch').note,
        contains('10.12.2026'));
    // Garantie läuft noch → nicht in der Ausmistliste.
    expect(await repo.watchCleanupCandidates().first, isEmpty);

    // Frist entfernt → Erinnerung weg, keine Dubletten.
    draft.objectionDeadline = null;
    await repo.updateDocument(doc.id, draft);
    await repo.updateDocument(doc.id, draft);
    final after = await repo.watchTasksForDocument(doc.id).first;
    expect(after.map((t) => t.origin), ['garantie']);
    await db.close();
  });
}
