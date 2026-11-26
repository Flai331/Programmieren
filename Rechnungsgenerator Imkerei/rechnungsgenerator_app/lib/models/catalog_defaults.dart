import 'catalog_entry_model.dart';
import 'hive_action_model.dart';
import 'honey_bucket_model.dart';
import 'stock_item_model.dart';
import 'stock_movement_model.dart';

/// Die Werkseinstellung jedes anpassbaren Verzeichnisses.
///
/// Eine Übersetzung der `static const`-Vorgaben aus den Modellen in
/// [CatalogEntry]-Zeilen: das, womit die App ausgeliefert wird, womit der
/// PersonalizationService die Tabelle sät, und worauf „Zurücksetzen"
/// zurückgeht.
///
/// Hier steht keine zweite Wahrheit, nur eine andere Form derselben – die
/// Werte kommen aus den Modellklassen, nicht noch einmal von Hand.
class CatalogDefaults {
  /// Die Werkseinträge eines Verzeichnisses, in ihrer Reihenfolge.
  static List<CatalogEntry> of(String catalog) => switch (catalog) {
        Catalogs.honeyState => _honigZustaende(),
        Catalogs.honeyCrystallization => _einfach(
            catalog,
            HoneyCrystallization.catalog,
            farbe: HoneyCrystallization.defaultColor,
          ),
        Catalogs.honeyVariety => _einfach(catalog, HoneyVarieties.catalog),
        Catalogs.stockCategory => _einfach(catalog, StockCategories.catalog),
        Catalogs.stockReason => _buchungsgruende(),
        Catalogs.hiveActionType => _einfach(catalog, HiveActionTypes.catalog),
        _ => const [],
      };

  /// Alle Werkseinträge aller Verzeichnisse – für die Aussaat.
  static List<CatalogEntry> all() =>
      [for (final verzeichnis in Catalogs.all) ...of(verzeichnis)];

  static List<CatalogEntry> _einfach(
    String name,
    SimpleCatalog quelle, {
    int? farbe,
  }) =>
      [
        for (var i = 0; i < quelle.defaultKeys.length; i++)
          CatalogEntry(
            catalog: name,
            key: quelle.defaultKeys[i],
            label: quelle.defaultLabels[quelle.defaultKeys[i]] ??
                quelle.defaultKeys[i],
            sortOrder: i,
            color: farbe,
            builtIn: true,
          ),
      ];

  static List<CatalogEntry> _honigZustaende() {
    final schritte = HoneyStates.defaultSteps;
    return [
      for (var i = 0; i < schritte.length; i++)
        CatalogEntry(
          catalog: Catalogs.honeyState,
          key: schritte[i],
          label: HoneyStates.defaultLabels[schritte[i]] ?? schritte[i],
          sortOrder: i,
          color: HoneyStates.defaultColors[schritte[i]],
          needsAttention:
              HoneyStates.defaultNeedsAttention.contains(schritte[i]),
          builtIn: true,
        ),
      // Außerhalb der Kette: „leer" setzt der Dienst selbst, sobald der Eimer
      // leergeräumt ist. Es steht hier, damit es sich umbenennen lässt, und
      // ganz hinten, damit kein Ziehen in der Liste es in die Kette schiebt.
      // Die Striche stehen ausdrücklich dabei – anders als bei den Schritten,
      // wo sie aus der Hakenzahl folgen.
      CatalogEntry(
        catalog: Catalogs.honeyState,
        key: HoneyStates.empty,
        label: HoneyStates.defaultLabels[HoneyStates.empty] ??
            HoneyStates.empty,
        sortOrder: schritte.length,
        color: HoneyStates.defaultColors[HoneyStates.empty],
        marks: '✕',
        needsAttention: false,
        builtIn: true,
      ),
    ];
  }

  static List<CatalogEntry> _buchungsgruende() => [
        for (var i = 0; i < StockReasons.defaultAll.length; i++)
          CatalogEntry(
            catalog: Catalogs.stockReason,
            key: StockReasons.defaultAll[i],
            label: StockReasons.defaultLabels[StockReasons.defaultAll[i]] ??
                StockReasons.defaultAll[i],
            sortOrder: i,
            direction:
                StockReasons.defaultDirections[StockReasons.defaultAll[i]],
            builtIn: true,
          ),
      ];
}
