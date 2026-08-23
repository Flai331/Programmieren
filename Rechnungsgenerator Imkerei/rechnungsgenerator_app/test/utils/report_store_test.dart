import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/utils/feedback_report.dart';
import 'package:beebrain/utils/report_store.dart';

FeedbackReport _report({
  required String id,
  DateTime? createdAt,
  String? note,
  List<String> photoNames = const [],
  bool isAutoError = false,
  bool exported = false,
}) =>
    FeedbackReport(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 8, 23, 10, 30),
      title: 'Fehlerbericht $id',
      note: note,
      log: '[10:29:28] SQLite bereit\n[10:29:38] SCREEN: Völker',
      appVersion: '3',
      os: 'android 13',
      screen: 'Völker',
      photoNames: photoNames,
      isAutoError: isAutoError,
      exported: exported,
    );

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('beebrain_reports_');
    ReportStore.overrideDirectoryForTest(temp);
  });

  tearDown(() async {
    ReportStore.overrideDirectoryForTest(null);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('FeedbackReport', () {
    test('Umlauf über JSON erhält alle Felder', () {
      final original = _report(
        id: 'r1',
        note: 'Volkname soll sich anpassen',
        photoNames: const ['r1-0.png'],
        exported: true,
      );
      final gelesen = FeedbackReport.fromJsonString(original.toJsonString());

      expect(gelesen.id, 'r1');
      expect(gelesen.note, 'Volkname soll sich anpassen');
      expect(gelesen.log, original.log);
      expect(gelesen.appVersion, '3');
      expect(gelesen.os, 'android 13');
      expect(gelesen.screen, 'Völker');
      expect(gelesen.photoNames, ['r1-0.png']);
      expect(gelesen.exported, isTrue);
      expect(gelesen.createdAt, original.createdAt);
    });

    test('fehlende Felder bekommen tragfähige Vorgaben', () {
      final gelesen = FeedbackReport.fromJsonString(
          '{"id":"x","created_at":"2026-08-23T10:00:00.000"}');
      expect(gelesen.id, 'x');
      expect(gelesen.title, 'Fehlerbericht');
      expect(gelesen.log, '');
      expect(gelesen.photoNames, isEmpty);
      expect(gelesen.exported, isFalse);
    });

    test('Berichtstext enthält Beschreibung, Protokoll und System', () {
      final text = _report(id: 'r1', note: 'geht nicht').asPlainText();
      expect(text, contains('🐛 FEHLERBESCHREIBUNG'));
      expect(text, contains('geht nicht'));
      expect(text, contains('📱 AKTUELLE SEITE'));
      expect(text, contains('Seite: Völker'));
      expect(text, contains('📋 PROTOKOLL'));
      expect(text, contains('SQLite bereit'));
      expect(text, contains('📱 SYSTEM'));
      expect(text, contains('Build: #3'));
      expect(text, contains('OS: android 13'));
    });

    test('ohne Beschreibung fehlt der Abschnitt', () {
      final text = _report(id: 'r1').asPlainText();
      expect(text, isNot(contains('🐛 FEHLERBESCHREIBUNG')));
      expect(text, contains('📋 PROTOKOLL'));
    });

    test('leeres Protokoll wird kenntlich gemacht', () {
      final text = FeedbackReport(
        id: 'r',
        createdAt: DateTime(2026, 8, 23),
        title: 't',
        log: '',
        appVersion: '3',
        os: '',
      ).asPlainText();
      expect(text, contains('(keine Einträge)'));
    });
  });

  group('ReportStore', () {
    test('gespeicherter Bericht ist wieder lesbar', () async {
      await ReportStore.save(_report(id: 'r1', note: 'Notiz'));
      final gelesen = await ReportStore.byId('r1');
      expect(gelesen, isNotNull);
      expect(gelesen!.note, 'Notiz');
    });

    test('Liste kommt neueste zuerst', () async {
      await ReportStore.save(
          _report(id: 'alt', createdAt: DateTime(2026, 8, 1)));
      await ReportStore.save(
          _report(id: 'neu', createdAt: DateTime(2026, 8, 20)));
      await ReportStore.save(
          _report(id: 'mitte', createdAt: DateTime(2026, 8, 10)));

      final alle = await ReportStore.list();
      expect(alle.map((r) => r.id), ['neu', 'mitte', 'alt']);
    });

    test('erneutes Speichern ersetzt den Bericht', () async {
      await ReportStore.save(_report(id: 'r1'));
      await ReportStore.save(_report(id: 'r1', exported: true));

      final alle = await ReportStore.list();
      expect(alle, hasLength(1));
      expect(alle.single.exported, isTrue);
    });

    test('beschädigte Datei macht die Liste nicht unbrauchbar', () async {
      await ReportStore.save(_report(id: 'gut'));
      await File('${temp.path}/kaputt.json').writeAsString('kein json');

      final alle = await ReportStore.list();
      expect(alle, hasLength(1));
      expect(alle.single.id, 'gut');
    });

    test('Löschen entfernt Bericht und Bilder', () async {
      await File('${temp.path}/r1-0.png').writeAsBytes([1, 2, 3]);
      await ReportStore.save(
          _report(id: 'r1', photoNames: const ['r1-0.png']));

      await ReportStore.delete('r1');

      expect(await ReportStore.byId('r1'), isNull);
      expect(await File('${temp.path}/r1-0.png').exists(), isFalse);
    });

    test('Löschen eines unbekannten Berichts wirft nicht', () async {
      await ReportStore.delete('gibtsnicht');
      expect(await ReportStore.list(), isEmpty);
    });

    test('alle löschen leert die Ablage', () async {
      for (final id in ['a', 'b', 'c']) {
        await ReportStore.save(_report(id: id));
      }
      await ReportStore.deleteAll();
      expect(await ReportStore.list(), isEmpty);
    });

    test('Bild übernehmen kopiert in die Ablage', () async {
      final quelle = File('${temp.path}/quelle.png');
      await quelle.writeAsBytes([9, 9, 9]);

      final name = await ReportStore.adoptPhoto(quelle.path, 'r1', 0);

      expect(name, 'r1-0.png');
      expect(await File('${temp.path}/$name').exists(), isTrue);
    });

    test('fehlende Quelldatei liefert null statt zu werfen', () async {
      final name =
          await ReportStore.adoptPhoto('${temp.path}/gibtsnicht.png', 'r', 0);
      expect(name, isNull);
    });

    test('photoPaths liefert nur vorhandene Bilder', () async {
      await File('${temp.path}/da.png').writeAsBytes([1]);
      final r = _report(id: 'r1', photoNames: const ['da.png', 'weg.png']);

      final pfade = await ReportStore.photoPaths(r);
      expect(pfade, hasLength(1));
      expect(pfade.single, endsWith('da.png'));
    });

    test('pruneTo behält die neuesten Berichte', () async {
      for (var i = 0; i < 5; i++) {
        await ReportStore.save(
            _report(id: 'r$i', createdAt: DateTime(2026, 8, 1 + i)));
      }
      await ReportStore.pruneTo(3);

      final alle = await ReportStore.list();
      expect(alle, hasLength(3));
      expect(alle.map((r) => r.id), ['r4', 'r3', 'r2']);
    });

    test('pruneTo unter der Grenze ändert nichts', () async {
      await ReportStore.save(_report(id: 'r1'));
      await ReportStore.pruneTo(10);
      expect(await ReportStore.list(), hasLength(1));
    });
  });
}
