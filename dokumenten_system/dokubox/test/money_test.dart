import 'package:dokubox/data/contracts.dart';
import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:dokubox/finance/girocode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GiroCode', () {
    test('Format nach EPC069-12', () {
      final code = buildGiroCode(
        name: 'enviaM Mitteldeutsche Energie AG',
        iban: 'DE02 1203 0000 0000 2020 51',
        amountCents: 12350,
        reference: 'RG 2026-77 Kd 4711',
      );
      expect(code.split('\n'), [
        'BCD', '002', '1', 'SCT', '',
        'enviaM Mitteldeutsche Energie AG',
        'DE02120300000000202051',
        'EUR123.50', '', '',
        'RG 2026-77 Kd 4711',
      ]);
    });
    test('Fehler und Längen', () {
      expect(() => buildGiroCode(name: 'X', iban: 'DE00123'),
          throwsFormatException);
      expect(
          () => buildGiroCode(
              name: '', iban: 'DE02120300000000202051'),
          throwsFormatException);
      final long = buildGiroCode(
          name: 'Ä' * 90, iban: 'DE02120300000000202051', reference: 'x' * 200);
      expect(long.split('\n')[5].length, 70);
      expect(long.split('\n')[10].length, 140);
      expect(
          buildGiroCode(name: 'A', iban: 'DE02120300000000202051', amountCents: 5)
              .split('\n')[7],
          'EUR0.05');
    });
  });

  group('Verträge', () {
    test('Kosten', () {
      expect(monthlyCents(12000, 'jaehrlich'), 1000);
      expect(yearlyCents(2999, 'monatlich'), 35988);
      expect(monthlyCents(5000, 'einmalig'), 0);
    });

    test('Laufzeit mit Verlängerung und Kündigungsfrist', () {
      final now = DateTime(2026, 11, 11);
      // 2 Jahre ab 01.01.2025, Verlängerung 12 Monate → Ende 01.01.2027
      final end = nextTermEnd(
          minTermUntil: DateTime(2026, 12, 31), renewMonths: 12, now: now);
      expect(end, DateTime(2026, 12, 31));
      expect(
          lastCancelDay(
              termEnd: end, noticeValue: 3, noticeUnit: 'monate', now: now),
          DateTime(2026, 9, 30)); // schon vorbei → Nutzer sieht „verpasst“
      final next = nextTermEnd(
          minTermUntil: DateTime(2025, 12, 31), renewMonths: 12, now: now);
      expect(next, DateTime(2026, 12, 31));
      expect(
          lastCancelDay(
              termEnd: DateTime(2027, 12, 31),
              noticeValue: 1,
              noticeUnit: 'monate',
              now: now),
          DateTime(2027, 11, 30));
    });

    test('Kündigung zum Monatsende mit 1 Monat Frist', () {
      expect(
          lastCancelDay(
              termEnd: null,
              noticeValue: 1,
              noticeUnit: 'monate',
              noticeToEndOf: 'monatsende',
              now: DateTime(2026, 11, 11)),
          DateTime(2026, 11, 30)); // Ende Dezember − 1 Monat
    });
  });

  test('Vertrag speichern plant Kündigungs-Erinnerung; Statistik', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    final doc = await repo.createDocument(
      docNumber: '2026-0001',
      draft: DocumentDraft(
          title: 'Kfz-Versicherung', storageLocation: 'Box', amountCents: 10000,
          claims: [ClaimDraft(target: 'Beihilfe')]),
      pdfPath: 'p.pdf',
      pageCount: 1,
      ocrText: '',
    );
    final now = DateTime(2026, 11, 11);
    final c = await repo.saveContract(
      ContractsCompanion.insert(
        title: 'Kfz',
        documentId: Value(doc.id),
        amountCents: const Value(36000),
        interval: const Value('jaehrlich'),
        minTermUntil: Value(DateTime(2026, 12, 31)),
        autoRenewMonths: const Value(12),
        noticeValue: const Value(1),
        noticeUnit: const Value('monate'),
      ),
      now: now,
    );
    var tasks = await repo.watchTasksForDocument(doc.id).first;
    // Kündigung bis 30.11.2026, Erinnerung 14 Tage vorher.
    expect(tasks.single.origin, 'kuendigung:${c.id}');
    expect(tasks.single.dueAt, DateTime(2026, 11, 16, 9));
    expect(tasks.single.note, contains('30.11.2026'));

    await repo.saveContract(
        ContractsCompanion(cancelledAt: Value(now)), id: c.id, now: now);
    tasks = await repo.watchTasksForDocument(doc.id).first;
    expect(tasks, isEmpty);
    expect((await repo.watchContracts().first).single.c.cancelledAt, now);

    final stats = await repo.claimStats(DateTime.now().year);
    expect(stats.single.target, 'Beihilfe');
    expect(stats.single.open, 1);
    expect(stats.single.amountCents, 10000);
    await db.close();
  });
}
