import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/extract/ref_matching.dart';
import 'package:dokubox/reports/report_pdf.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchRefs', () {
    test('gleiches Aktenzeichen trotz Schreibweise → Treffer', () {
      final m = matchRefs({
        'AZ': {'12/345-67'}
      }, 'fa', [
        const RefCandidate('alt', 'anderer', {
          'AZ': {'12 345 67'}
        }),
      ]);
      expect(m.single.documentId, 'alt');
      expect(m.single.reasons, ['AZ 12/345-67']);
    });

    test('nur gleiche IBAN → kein Treffer', () {
      expect(
          matchRefs({
            'IBAN': {'DE02120300000000202051'}
          }, 'x', [
            const RefCandidate('alt', 'x', {
              'IBAN': {'DE02120300000000202051'}
            }),
          ]),
          isEmpty);
    });

    test('Kundennummer zählt nur bei gleicher Firma, mit Bonus', () {
      const refs = {
        'KDNR': {'4711-0815'},
        'VSNR': {'AB123456'},
      };
      expect(
          matchRefs(refs, 'allianz', [
            const RefCandidate('fremd', 'huk', {
              'KDNR': {'47110815'}
            }),
          ]),
          isEmpty);
      final m = matchRefs(refs, 'allianz', [
        const RefCandidate('eigen', 'allianz', {
          'KDNR': {'47110815'},
          'VSNR': {'AB 123 456'},
        }),
        const RefCandidate('schwach', 'allianz', {
          'KDNR': {'47110815'},
        }),
      ]);
      expect(m.map((e) => e.documentId), ['eigen']);
      expect(m.single.score, 9);
    });
  });

  group('Repository', () {
    late AppDatabase db;
    late DocumentRepository repo;
    setUp(() {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      repo = DocumentRepository(db);
    });
    tearDown(() => db.close());

    test('Kandidaten über normalisierte Referenzen', () async {
      final antrag = await repo.createDocument(
        docNumber: '2026-0001',
        draft: DocumentDraft(
            title: 'Antrag', correspondentName: 'Finanzamt',
            storageLocation: 'Box'),
        pdfPath: 'a.pdf',
        pageCount: 1,
        ocrText: '',
        refs: {
          'AZ': {'12/345/67'}
        },
      );
      final c = await repo.refCandidates({
        'AZ': {'12 345 67'}
      });
      expect(c.single.documentId, antrag.id);
      expect(await repo.refCandidates({'AZ': {'99'}}), isEmpty);
    });

    test('ensureAutoTask: anlegen, verschieben, nicht doppelt, löschen',
        () async {
      final doc = await repo.createDocument(
          docNumber: '2026-0001',
          draft: DocumentDraft(title: 'Bescheid', storageLocation: 'Box'),
          pdfPath: 'b.pdf',
          pageCount: 1,
          ocrText: '');
      final t1 = await repo.ensureAutoTask(
          documentId: doc.id,
          origin: 'widerspruch',
          action: 'pruefen',
          dueAt: DateTime(2026, 12, 1));
      final t2 = await repo.ensureAutoTask(
          documentId: doc.id,
          origin: 'widerspruch',
          action: 'pruefen',
          dueAt: DateTime(2026, 12, 5));
      expect(t2!.id, t1!.id);
      expect(t2.dueAt, DateTime(2026, 12, 5));
      expect(t2.origin, 'widerspruch');
      expect((await repo.watchTasksForDocument(doc.id).first).length, 1);
      await repo.ensureAutoTask(
          documentId: doc.id,
          origin: 'widerspruch',
          action: 'pruefen',
          dueAt: null);
      expect(await repo.watchTasksForDocument(doc.id).first, isEmpty);
    });
  });

  test('Bericht-Baustein erzeugt PDF mit Tabelle und Umlauten', () async {
    final bytes = await buildReport(
      title: 'Box 2026 – Inhalt',
      subtitle: '3 Dokumente',
      font: ByteData.sublistView(
          File('assets/fonts/DejaVuSans.ttf').readAsBytesSync()),
      content: () => [
        reportTable(['Nr.', 'Titel'], [
          ['2026-0001', 'Größe 12,50 €'],
          ['2026-0002', 'Müller'],
        ]),
      ],
    );
    expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF'), isTrue);
  });
}
