import 'package:dokubox/ai/ai_extraction_service.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAiJson', () {
    test('parst sauberes JSON', () {
      final result = parseAiJson(
          '{"absender": "HUK-COBURG", "datum": "2026-03-14", '
          '"typ": "Mitteilung", "titel": "Beitragsanpassung"}');
      expect(result, isNotNull);
      expect(result!.absender, 'HUK-COBURG');
      expect(result.datum, DateTime(2026, 3, 14));
      expect(result.typ, 'Mitteilung');
      expect(result.titel, 'Beitragsanpassung');
    });

    test('überlebt Markdown-Zäune, Denk-Blöcke und Geschwätz', () {
      const response = '''
<think>Der Absender steht oben im Briefkopf.</think>
Hier ist das Ergebnis:
```json
{"absender": "Stadtwerke", "datum": "2026-01-05", "typ": "Rechnung", "titel": "Abschlag"}
```''';
      final result = parseAiJson(response);
      expect(result!.absender, 'Stadtwerke');
      expect(result.typ, 'Rechnung');
    });

    test('toleriert deutsches Datumsformat und null-Strings', () {
      final result = parseAiJson(
          '{"absender": "null", "datum": "14.03.2026", "typ": null, "titel": "X y z"}');
      expect(result!.absender, isNull);
      expect(result.datum, DateTime(2026, 3, 14));
      expect(result.typ, isNull);
    });

    test('verwirft unbekannte Typen und unplausible Daten', () {
      final result = parseAiJson(
          '{"absender": null, "datum": "1234-01-01", "typ": "Liebesbrief", "titel": null}');
      expect(result, isNull);
    });

    test('Typ wird case-insensitiv auf bekannte Typen normalisiert', () {
      final result = parseAiJson('{"typ": "mitteilung"}');
      expect(result!.typ, 'Mitteilung');
    });

    test('null bei kaputtem/fehlendem JSON', () {
      expect(parseAiJson('Ich konnte nichts erkennen.'), isNull);
      expect(parseAiJson('{"absender": '), isNull);
      expect(parseAiJson('[1, 2]'), isNull);
    });

    test('parst Tags als Liste', () {
      final result = parseAiJson(
          '{"absender": "Deutsche Rentenversicherung", "typ": "Mitteilung", '
          '"tags": ["Rentenversicherung", "Rente"]}');
      expect(result!.tags, ['Rentenversicherung', 'Rente']);
    });

    test('parst Tags auch als kommagetrennten String und entdoppelt', () {
      final result =
          parseAiJson('{"tags": "Auto, auto ,Versicherung"}');
      expect(result!.tags, ['Auto', 'Versicherung']);
    });

    test('begrenzt auf 4 Tags und verwirft zu lange', () {
      final result = parseAiJson(
          '{"tags": ["a","b","c","d","e","${'x' * 40}"]}');
      expect(result!.tags, ['a', 'b', 'c', 'd']);
    });

    test('tags null/fehlend ergibt leere Liste', () {
      final result = parseAiJson('{"typ": "Mitteilung", "tags": null}');
      expect(result!.tags, isEmpty);
    });
  });

  group('applyAiToDraft', () {
    DocumentDraft draft() => DocumentDraft(
          title: 'Rechnung Stadtwerke',
          docDate: DateTime(2026, 1, 1),
          correspondentName: 'Stadtwerke',
          docType: 'Rechnung',
          storageLocation: 'Box 2026',
          retentionUntil: DateTime(2028, 12, 31),
        );

    test('KI gewinnt bei Titel, Datum, Typ; Frist wird neu berechnet', () {
      final d = draft();
      applyAiToDraft(
        d,
        AiDocumentData(
          titel: 'Jahresabrechnung 2025',
          datum: DateTime(2026, 2, 2),
          typ: 'Mitteilung',
        ),
      );
      expect(d.title, 'Jahresabrechnung 2025');
      expect(d.docDate, DateTime(2026, 2, 2));
      expect(d.docType, 'Mitteilung');
      // Mitteilung: 3 Jahre ab Dokumentdatum, zum Jahresende.
      expect(d.retentionUntil, DateTime(2029, 12, 31));
    });

    test('bekannter Korrespondent wird nicht überschrieben', () {
      final d = draft();
      applyAiToDraft(
        d,
        const AiDocumentData(absender: 'Stadtwerke Musterstadt GmbH & Co.'),
        preserveCorrespondent: true,
      );
      expect(d.correspondentName, 'Stadtwerke');
    });

    test('unbekannter Absender wird von der KI gesetzt', () {
      final d = draft()..correspondentName = null;
      applyAiToDraft(d, const AiDocumentData(absender: 'Finanzamt Köln'));
      expect(d.correspondentName, 'Finanzamt Köln');
    });

    test('null-Felder der KI lassen Regel-Werte stehen', () {
      final d = draft();
      applyAiToDraft(d, const AiDocumentData(titel: 'Neuer Titel'));
      expect(d.docDate, DateTime(2026, 1, 1));
      expect(d.docType, 'Rechnung');
      expect(d.retentionUntil, DateTime(2028, 12, 31));
    });

    test('KI-Tags werden ergänzt, gelernte Tags bleiben, keine Dubletten', () {
      final d = draft()..tagNames = ['Auto'];
      applyAiToDraft(
        d,
        const AiDocumentData(tags: ['auto', 'Rentenversicherung']),
      );
      // 'auto' ist Dublette zu 'Auto' → nicht doppelt; neuer Tag ergänzt.
      expect(d.tagNames, ['Auto', 'Rentenversicherung']);
    });

    test('KI setzt Tags für neue Mitteilung (Beispiel Rentenversicherung)', () {
      final d = draft()
        ..tagNames = []
        ..docType = 'Mitteilung';
      applyAiToDraft(d, const AiDocumentData(tags: ['Rentenversicherung']));
      expect(d.tagNames, ['Rentenversicherung']);
    });
  });

  group('buildPrompt', () {
    test('kürzt langen OCR-Text und enthält die Typenliste', () {
      final prompt = AiExtractionService.buildPrompt('x' * 5000);
      expect(prompt.length, lessThan(4000));
      expect(prompt, contains('Mitteilung'));
      expect(prompt, contains('JJJJ-MM-TT'));
      expect(prompt, contains('tags'));
    });

    test('bietet vorhandene Tags zur Wiederverwendung an', () {
      final prompt = AiExtractionService.buildPrompt('kurz',
          knownTags: ['Rentenversicherung', 'Auto']);
      expect(prompt, contains('Rentenversicherung'));
      expect(prompt, contains('vorhandene Tags'));
    });
  });
}
