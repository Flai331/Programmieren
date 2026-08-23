import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';

/// Wunsch aus dem Fehlerbericht vom 23.08.2026:
/// „der Volkname soll sich aus dem Standort und dem Aufstellungsort
/// zusammensetzen und wenn sich der Ort ändert soll sich auch der Name
/// dementsprechend anpassen."
HiveModel _hive({
  int? number = 1,
  String? name,
  String? location,
  String? position,
}) =>
    HiveModel(
      id: 'h1',
      number: number,
      name: name,
      qrId: 'qr-h1',
      location: location,
      position: position,
      createdAt: DateTime(2026, 8, 23),
    );

void main() {
  group('Name aus Standort und Aufstellungsort', () {
    test('setzt sich aus beiden Teilen zusammen', () {
      final h = _hive(location: 'Hausstand', position: 'Reihe 2');
      expect(h.derivedName, 'Hausstand · Reihe 2');
      expect(h.effectiveName, 'Hausstand · Reihe 2');
      expect(h.usesDerivedName, isTrue);
    });

    test('nur Standort reicht aus', () {
      final h = _hive(location: 'Wiese am Bach');
      expect(h.derivedName, 'Wiese am Bach');
      expect(h.effectiveName, 'Wiese am Bach');
    });

    test('nur Aufstellungsort reicht aus', () {
      final h = _hive(position: 'Platz 3');
      expect(h.derivedName, 'Platz 3');
      expect(h.effectiveName, 'Platz 3');
    });

    test('Leerzeichen zählen nicht als Angabe', () {
      final h = _hive(location: '   ', position: '  ');
      expect(h.derivedName, '');
      expect(h.usesDerivedName, isFalse);
      expect(h.effectiveName, 'Volk #1');
    });

    test('ohne Ortsangaben bleibt die Nummer', () {
      expect(_hive().effectiveName, 'Volk #1');
      expect(_hive(number: null).effectiveName, 'Volk');
    });
  });

  group('Name zieht bei einem Ortswechsel mit', () {
    test('neuer Standort ändert den Namen', () {
      final vorher = _hive(location: 'Hausstand', position: 'Reihe 2');
      final nachher = vorher.copyWith(location: 'Rapsfeld');

      expect(vorher.effectiveName, 'Hausstand · Reihe 2');
      expect(nachher.effectiveName, 'Rapsfeld · Reihe 2');
    });

    test('neuer Aufstellungsort ändert den Namen', () {
      final nachher = _hive(location: 'Hausstand', position: 'Reihe 2')
          .copyWith(position: 'Reihe 5');
      expect(nachher.effectiveName, 'Hausstand · Reihe 5');
    });

    test('der Name wird nicht gespeichert, sondern gebildet', () {
      // Sonst bliebe im Datensatz ein veralteter Name stehen.
      final h = _hive(location: 'Hausstand', position: 'Reihe 2');
      expect(h.toMap()['name'], isNull);
      expect(h.toMap()['location'], 'Hausstand');
      expect(h.toMap()['position'], 'Reihe 2');
    });
  });

  group('Eigener Name hat Vorrang', () {
    test('übersteuert den gebildeten Namen', () {
      final h = _hive(
          name: 'Zuchtvolk Anna', location: 'Hausstand', position: 'Reihe 2');
      expect(h.effectiveName, 'Zuchtvolk Anna');
      expect(h.usesDerivedName, isFalse);
    });

    test('bleibt bei einem Ortswechsel stehen', () {
      final nachher = _hive(
        name: 'Zuchtvolk Anna',
        location: 'Hausstand',
        position: 'Reihe 2',
      ).copyWith(location: 'Rapsfeld');
      expect(nachher.effectiveName, 'Zuchtvolk Anna');
    });

    test('leerer Name fällt auf den gebildeten zurück', () {
      final h = _hive(name: '  ', location: 'Hausstand');
      expect(h.effectiveName, 'Hausstand');
      expect(h.usesDerivedName, isTrue);
    });
  });

  group('displayLabel', () {
    test('Nummer und Name', () {
      final h = _hive(number: 5, location: 'Hausstand', position: 'Reihe 2');
      expect(h.displayLabel, '#5 · Hausstand · Reihe 2');
    });

    test('ohne Ortsangabe nur die Nummer', () {
      expect(_hive(number: 5).displayLabel, '#5');
    });

    test('ganz ohne Angaben', () {
      expect(_hive(number: null).displayLabel, 'Volk');
    });
  });

  group('Datenbank-Umlauf', () {
    test('Aufstellungsort übersteht toMap/fromMap', () {
      final h = _hive(location: 'Hausstand', position: 'Reihe 2');
      final gelesen = HiveModel.fromMap(h.toMap());
      expect(gelesen.location, 'Hausstand');
      expect(gelesen.position, 'Reihe 2');
      expect(gelesen.effectiveName, 'Hausstand · Reihe 2');
    });

    test('Datensatz ohne Aufstellungsort bleibt lesbar', () {
      // So sehen Völker aus, die vor der Migration angelegt wurden.
      final map = _hive(location: 'Hausstand').toMap()..remove('position');
      final gelesen = HiveModel.fromMap(map);
      expect(gelesen.position, isNull);
      expect(gelesen.effectiveName, 'Hausstand');
    });
  });
}
