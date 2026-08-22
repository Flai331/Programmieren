import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';
import 'package:beebrain/utils/app_utils.dart';

HiveActionModel _a({
  String type = HiveActionTypes.inspection,
  String? note,
  int? broodFrames,
  int? beeFrames,
  int? temper,
  bool? queenSeen,
  bool? swarmCells,
  double? amount,
  String? unit,
  String? treatment,
}) =>
    HiveActionModel(
      id: 'a1',
      hiveId: 'h1',
      date: DateTime(2026, 5, 12),
      type: type,
      note: note,
      broodFrames: broodFrames,
      beeFrames: beeFrames,
      temper: temper,
      queenSeen: queenSeen,
      swarmCells: swarmCells,
      amount: amount,
      unit: unit,
      treatment: treatment,
      createdAt: DateTime(2026, 5, 12),
    );

void main() {
  group('HiveActionTypes', () {
    test('jeder Typ hat eine Beschriftung', () {
      for (final t in HiveActionTypes.all) {
        expect(HiveActionTypes.labelOf(t), isNotEmpty);
        expect(HiveActionTypes.labelOf(t), isNot(t));
      }
    });

    test('unbekannter Typ liefert den Rohwert statt zu scheitern', () {
      expect(HiveActionTypes.labelOf('gibtsnicht'), 'gibtsnicht');
    });

    test('Eingabefelder passen zum Typ', () {
      expect(HiveActionTypes.hasColonyMetrics(HiveActionTypes.inspection),
          isTrue);
      expect(HiveActionTypes.hasColonyMetrics(HiveActionTypes.swarm), isTrue);
      expect(HiveActionTypes.hasColonyMetrics(HiveActionTypes.feeding),
          isFalse);

      expect(HiveActionTypes.hasAmount(HiveActionTypes.harvest), isTrue);
      expect(HiveActionTypes.hasAmount(HiveActionTypes.feeding), isTrue);
      expect(HiveActionTypes.hasAmount(HiveActionTypes.varroa), isTrue);
      expect(HiveActionTypes.hasAmount(HiveActionTypes.inspection), isFalse);

      expect(HiveActionTypes.hasTreatment(HiveActionTypes.varroa), isTrue);
      expect(HiveActionTypes.hasTreatment(HiveActionTypes.harvest), isFalse);
    });

    test('Standard-Einheiten', () {
      expect(HiveActionTypes.defaultUnitOf(HiveActionTypes.harvest), 'kg');
      expect(HiveActionTypes.defaultUnitOf(HiveActionTypes.feeding), 'kg');
      expect(HiveActionTypes.defaultUnitOf(HiveActionTypes.varroa), 'ml');
      expect(HiveActionTypes.defaultUnitOf(HiveActionTypes.inspection), '');
    });
  });

  group('HiveActionModel.summary', () {
    test('Durchsicht fasst die Kennzahlen zusammen', () {
      final s = _a(broodFrames: 6, beeFrames: 10, queenSeen: true).summary;
      expect(s, '6 Brutwaben · 10 Waben besetzt · Königin gesehen');
    });

    test('ganze Menge ohne Nachkommastelle', () {
      expect(
        _a(type: HiveActionTypes.feeding, amount: 5, unit: 'kg').summary,
        '5 kg',
      );
    });

    test('gebrochene Menge mit Komma', () {
      expect(
        _a(type: HiveActionTypes.harvest, amount: 12.5, unit: 'kg').summary,
        '12,5 kg',
      );
    });

    test('ohne Kennzahlen wird die Notiz zur Zusammenfassung', () {
      expect(_a(type: HiveActionTypes.other, note: 'Deckel getauscht').summary,
          'Deckel getauscht');
    });

    test('ganz ohne Angaben bleibt die Zusammenfassung leer', () {
      expect(_a(type: HiveActionTypes.other).summary, '');
    });

    test('Schwarmzellen werden nur bei Fund genannt', () {
      expect(_a(swarmCells: true).summary, contains('Schwarmzellen'));
      expect(_a(swarmCells: false).summary, isNot(contains('Schwarmzellen')));
    });
  });

  group('AppUtils.parseNumber', () {
    test('deutsche Schreibweise', () {
      expect(AppUtils.parseNumber('12,5'), 12.5);
      expect(AppUtils.parseNumber('1.234,5'), 1234.5);
    });

    test('englische Schreibweise', () {
      expect(AppUtils.parseNumber('12.5'), 12.5);
      expect(AppUtils.parseNumber('1,234.5'), 1234.5);
    });

    test('ganze Zahlen und Leerzeichen', () {
      expect(AppUtils.parseNumber('7'), 7);
      expect(AppUtils.parseNumber(' 7 '), 7);
    });

    test('leere und ungültige Eingabe liefert null', () {
      expect(AppUtils.parseNumber(''), isNull);
      expect(AppUtils.parseNumber('   '), isNull);
      expect(AppUtils.parseNumber('abc'), isNull);
    });

    test('formatNumber und parseNumber sind gegenläufig', () {
      for (final wert in [0.5, 5.0, 12.5, 1234.5]) {
        expect(AppUtils.parseNumber(AppUtils.formatNumber(wert)), wert);
      }
    });

    test('formatNumber beachtet die Nachkommastellen', () {
      expect(AppUtils.formatNumber(5, decimalDigits: 2), '5,00');
      expect(AppUtils.formatNumber(12.5, decimalDigits: 0), '13');
    });
  });
}
