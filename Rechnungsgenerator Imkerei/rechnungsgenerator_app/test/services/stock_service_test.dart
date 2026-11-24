import 'package:flutter_test/flutter_test.dart';

import 'package:beebrain/models/models.dart';
import 'package:beebrain/services/season_service.dart';
import 'package:beebrain/services/stock_service.dart';

StockItemModel _item({
  required String id,
  required String name,
  String category = StockCategories.other,
  String unit = 'Stk',
  double? minQuantity,
  double? pricePerUnit,
  String? variety,
  int? jarSizeG,
}) =>
    StockItemModel(
      id: id,
      name: name,
      category: category,
      unit: unit,
      minQuantity: minQuantity,
      pricePerUnit: pricePerUnit,
      variety: variety,
      jarSizeG: jarSizeG,
      createdAt: DateTime(2026, 3, 1),
    );

StockMovementModel _movement({
  String id = 'm1',
  required String itemId,
  required double quantity,
  String reason = StockReasons.purchase,
}) =>
    StockMovementModel(
      id: id,
      itemId: itemId,
      date: DateTime(2026, 4, 1),
      quantity: quantity,
      reason: reason,
      createdAt: DateTime(2026, 4, 1),
    );

void main() {
  group('Bestand ist die Summe der Bewegungen', () {
    test('ordnet jedem Posten seinen Bestand zu', () {
      final bestand = StockService.buildBalances(
        items: [
          _item(id: 'glas', name: '500-g-Gläser'),
          _item(id: 'futter', name: 'Zuckerwasser', unit: 'kg'),
        ],
        balances: {'glas': 120, 'futter': 42.5},
      );

      expect(bestand, hasLength(2));
      expect(bestand.first.quantity, 120);
      expect(bestand.last.quantity, 42.5);
    });

    test('ein Posten ohne Bewegung steht auf 0', () {
      // Die Datenbank liefert nur Posten mit Bewegungen zurück; alles
      // andere muss der Dienst als 0 auffassen statt zu fehlen.
      final bestand = StockService.buildBalances(
        items: [_item(id: 'neu', name: 'Frisch angelegt')],
        balances: const {},
      );

      expect(bestand.single.quantity, 0);
      expect(bestand.single.isEmpty, isTrue);
    });

    test('ein negativer Bestand bleibt sichtbar', () {
      // Mehr gebucht als vorhanden war: Das soll auffallen und nicht
      // stillschweigend auf 0 gekappt werden.
      final bestand = StockService.buildBalances(
        items: [_item(id: 'x', name: 'Verbucht')],
        balances: {'x': -3},
      );

      expect(bestand.single.quantity, -3);
    });

    test('vorzeichenbehaftete Bewegungen ergeben in Summe den Bestand', () {
      final bewegungen = [
        _movement(id: 'm1', itemId: 'glas', quantity: 200),
        _movement(
            id: 'm2',
            itemId: 'glas',
            quantity: -80,
            reason: StockReasons.sale),
        _movement(
            id: 'm3',
            itemId: 'glas',
            quantity: -5,
            reason: StockReasons.ownUse),
      ];

      final summe =
          bewegungen.fold<double>(0, (s, b) => s + b.quantity);
      expect(summe, 115);
      expect(bewegungen.first.isInbound, isTrue);
      expect(bewegungen[1].isInbound, isFalse);
    });
  });

  group('Mindestbestand und Fehlmenge', () {
    test('warnt unter dem Mindestbestand', () {
      final knapp = StockBalance(
        item: _item(id: 'g', name: 'Gläser', minQuantity: 50),
        quantity: 12,
      );
      expect(knapp.isBelowMinimum, isTrue);
      expect(knapp.shortfall, 38);
    });

    test('warnt nicht, wenn der Mindestbestand erreicht ist', () {
      final genug = StockBalance(
        item: _item(id: 'g', name: 'Gläser', minQuantity: 50),
        quantity: 50,
      );
      expect(genug.isBelowMinimum, isFalse);
      expect(genug.shortfall, 0);
    });

    test('ohne gesetzten Mindestbestand gibt es keine Warnung', () {
      final ohne = StockBalance(
        item: _item(id: 'g', name: 'Gläser'),
        quantity: 0,
      );
      expect(ohne.isBelowMinimum, isFalse);
      expect(ohne.shortfall, 0);
    });

    test('die größte Fehlmenge steht oben', () {
      final alle = [
        StockBalance(
            item: _item(id: 'a', name: 'A', minQuantity: 10), quantity: 8),
        StockBalance(
            item: _item(id: 'b', name: 'B', minQuantity: 100), quantity: 10),
        StockBalance(
            item: _item(id: 'c', name: 'C', minQuantity: 5), quantity: 20),
      ];

      final knapp = StockService.belowMinimum(alle);
      expect(knapp.map((b) => b.item.id), ['b', 'a']);
      expect(knapp.first.shortfall, 90);
    });

    test('rechnet den Lagerwert nur aus Posten mit Preis', () {
      final alle = [
        StockBalance(
            item: _item(id: 'a', name: 'A', pricePerUnit: 2.5), quantity: 10),
        // Ohne Preis – darf den Wert nicht verfälschen.
        StockBalance(item: _item(id: 'b', name: 'B'), quantity: 100),
        StockBalance(
            item: _item(id: 'c', name: 'C', pricePerUnit: 0.4), quantity: 50),
      ];

      expect(StockService.totalValue(alle), closeTo(45.0, 0.0001));
    });
  });

  group('Packliste gegen das Lager', () {
    StockBalance bestand(String name, double menge,
            {String unit = 'Stk', String id = 'i'}) =>
        StockBalance(
            item: _item(id: id, name: name, unit: unit), quantity: menge);

    test('nennt die Fehlmenge', () {
      final abgleich = StockService.coverage(
        [
          PackListEntry(
              item: const PackItem('Mittelwände', perHive: 6, unit: 'Stk'),
              quantity: 48),
        ],
        [bestand('Mittelwände', 20)],
      );

      final m = abgleich.single;
      expect(m.isShort, isTrue);
      expect(m.missing, 28);
      expect(m.isUnknown, isFalse);
      expect(m.stockLabel, contains('20'));
    });

    test('meldet nichts, wenn genug da ist', () {
      final abgleich = StockService.coverage(
        [
          PackListEntry(
              item: const PackItem('Mittelwände', perHive: 6, unit: 'Stk'),
              quantity: 48),
        ],
        [bestand('Mittelwände', 60)],
      );

      expect(abgleich.single.isShort, isFalse);
      expect(abgleich.single.missing, 0);
    });

    test('findet den Posten über Umlaute und Groß-/Kleinschreibung', () {
      final abgleich = StockService.coverage(
        [
          PackListEntry(
              item: const PackItem('Mittelwände', perHive: 6, unit: 'Stk'),
              quantity: 12),
        ],
        [bestand('mittelwaende', 5)],
      );

      expect(abgleich.single.isUnknown, isFalse);
      expect(abgleich.single.missing, 7);
    });

    test('„Ameisensäure 60%" trifft den Posten „Ameisensäure"', () {
      // Der Teiltreffer, auf den es praktisch ankommt: Die Packliste nennt
      // das Mittel genauer als das Lager es führt.
      final abgleich = StockService.coverage(
        [
          PackListEntry(
              item: const PackItem('Ameisensäure 60%', perHive: 30, unit: 'ml'),
              quantity: 300),
        ],
        [bestand('Ameisensäure', 100, unit: 'ml')],
      );

      expect(abgleich.single.isUnknown, isFalse);
      expect(abgleich.single.isShort, isTrue);
      expect(abgleich.single.missing, 200);
    });

    test('ein unbekannter Posten gilt nicht als Fehlmenge', () {
      // Die App weiß über ihn einfach nichts – das ist etwas anderes als
      // „fehlt".
      final abgleich = StockService.coverage(
        [
          PackListEntry(
              item: const PackItem('Räucherstoff'), quantity: null),
        ],
        [bestand('Mittelwände', 20)],
      );

      final m = abgleich.single;
      expect(m.isUnknown, isTrue);
      expect(m.isShort, isFalse);
      expect(m.missing, 0);
      expect(m.stockLabel, 'nicht im Lager geführt');
    });

    test('Werkzeug ohne Menge ist nie eine Fehlmenge', () {
      final abgleich = StockService.coverage(
        [
          PackListEntry(item: const PackItem('Stockmeißel'), quantity: null),
        ],
        [bestand('Stockmeißel', 0)],
      );

      expect(abgleich.single.isShort, isFalse);
    });
  });

  group('Warengruppe und Buchungsgrund aus der Maßnahme', () {
    test('ordnet die Maßnahmearten ihren Warengruppen zu', () {
      expect(StockCategories.forActionType(HiveActionTypes.harvest),
          StockCategories.honey);
      expect(StockCategories.forActionType(HiveActionTypes.feeding),
          StockCategories.feed);
      expect(StockCategories.forActionType(HiveActionTypes.varroa),
          StockCategories.treatment);
      expect(StockCategories.forActionType(HiveActionTypes.combs),
          StockCategories.combs);
      // Eine Durchsicht verbraucht nichts.
      expect(StockCategories.forActionType(HiveActionTypes.inspection),
          isNull);
    });

    test('Ernte ist ein Zugang, Fütterung ein Verbrauch', () {
      expect(StockReasons.forActionType(HiveActionTypes.harvest),
          StockReasons.harvest);
      expect(StockReasons.forActionType(HiveActionTypes.feeding),
          StockReasons.consumption);
      expect(StockReasons.forActionType(HiveActionTypes.varroa),
          StockReasons.consumption);
    });
  });

  group('Namen vergleichbar machen', () {
    test('faltet Umlaute, Schreibweise und Leerraum', () {
      expect(StockItemModel.normalizeName('Mittelwände'), 'mittelwaende');
      expect(StockItemModel.normalizeName('MITTELWÄNDE'), 'mittelwaende');
      expect(StockItemModel.normalizeName('  Mittel   wände  '),
          'mittel waende');
      expect(StockItemModel.normalizeName('Straßenhonig'), 'strassenhonig');
    });
  });
}
