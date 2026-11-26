/// Anpassbare Verzeichnisse: ein Eintrag und die Namen der Verzeichnisse.
///
/// Die App wird mit Werkseinstellungen ausgeliefert, die als `static const` in
/// den Modellen stehen – [HoneyStates], [HoneyVarieties] und die anderen. Beim
/// Start sät der PersonalizationService sie in die Tabelle `catalog_entries`;
/// ab dann gilt, was dort steht. Fehlt die Tabelle oder ist sie leer, läuft die
/// App mit den Werkseinstellungen weiter.
library;

/// Ein Eintrag in einem anpassbaren Verzeichnis.
///
/// [key] ist unveränderlich. Er steht in den gespeicherten Daten – und bei den
/// Honigsorten mit Permanentmarker auf den Eimern im Keller. Änderbar sind
/// [label], [sortOrder], [color] und, wo sie etwas bedeuten, [marks],
/// [needsAttention] und [direction]: typabhängig leere Felder, wie beim
/// Eimer-Verlauf.
class CatalogEntry {
  /// Welches Verzeichnis, siehe [Catalogs].
  final String catalog;

  /// Der unveränderliche Schlüssel, z.B. 'geimpft' oder 'SO'.
  final String key;

  /// Was in der App zu lesen ist.
  final String label;

  /// Reihenfolge in der Auswahl; bei den Honig-Zuständen ist das die Kette.
  final int sortOrder;

  /// Farbe zur Anzeige als ARGB-Zahl; null heißt: die Vorgabe nehmen.
  final int? color;

  /// Striche für das handgemalte Kästchen – nur bei Honig-Zuständen.
  /// Null heißt: so viele Striche, wie der Schritt Haken hat, minus einen.
  final String? marks;

  /// „Wartet auf eine Arbeit von mir" – nur bei Honig-Zuständen.
  final bool? needsAttention;

  /// Zugang, Abgang oder beides – nur bei Buchungsgründen, siehe
  /// [CatalogDirections]. Ohne das kann das Lager eine Buchung nicht
  /// einordnen.
  final String? direction;

  /// Ausgeblendet: verschwindet aus der Auswahl, bleibt an alten Daten
  /// lesbar. Der Weg für Einträge, die niemand mehr braucht, aber die in
  /// bestehenden Eimern stehen.
  final bool archived;

  /// Kam aus der Werkseinstellung. Umbenennen, umfärben, umsortieren und
  /// ausblenden ja – löschen nein: der Code verweist auf diese Schlüssel.
  final bool builtIn;

  const CatalogEntry({
    required this.catalog,
    required this.key,
    required this.label,
    required this.sortOrder,
    this.color,
    this.marks,
    this.needsAttention,
    this.direction,
    this.archived = false,
    this.builtIn = false,
  });

  Map<String, dynamic> toMap() => {
        'catalog': catalog,
        'entry_key': key,
        'label': label,
        'sort_order': sortOrder,
        'color': color,
        'marks': marks,
        'needs_attention': needsAttention == null
            ? null
            : (needsAttention! ? 1 : 0),
        'direction': direction,
        'archived': archived ? 1 : 0,
        'built_in': builtIn ? 1 : 0,
      };

  factory CatalogEntry.fromMap(Map<String, dynamic> m) => CatalogEntry(
        catalog: (m['catalog'] as String?) ?? '',
        key: (m['entry_key'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        color: (m['color'] as num?)?.toInt(),
        marks: m['marks'] as String?,
        needsAttention: m['needs_attention'] == null
            ? null
            : (m['needs_attention'] as num).toInt() != 0,
        direction: m['direction'] as String?,
        archived: ((m['archived'] as num?)?.toInt() ?? 0) != 0,
        builtIn: ((m['built_in'] as num?)?.toInt() ?? 0) != 0,
      );

  CatalogEntry copyWith({
    String? label,
    int? sortOrder,
    int? color,
    bool clearColor = false,
    String? marks,
    bool clearMarks = false,
    bool? needsAttention,
    String? direction,
    bool? archived,
  }) =>
      CatalogEntry(
        catalog: catalog,
        key: key,
        label: label ?? this.label,
        sortOrder: sortOrder ?? this.sortOrder,
        color: clearColor ? null : (color ?? this.color),
        marks: clearMarks ? null : (marks ?? this.marks),
        needsAttention: needsAttention ?? this.needsAttention,
        direction: direction ?? this.direction,
        archived: archived ?? this.archived,
        builtIn: builtIn,
      );

  @override
  String toString() => 'CatalogEntry($catalog/$key, "$label", $sortOrder'
      '${archived ? ', ausgeblendet' : ''})';
}

/// Die Namen der anpassbaren Verzeichnisse.
///
/// Bewusst deutsche Schlüssel, wie bei den übrigen gespeicherten Werten: sie
/// stehen in der Datenbank und werden nie umbenannt.
class Catalogs {
  static const String honeyState = 'honig_zustand';
  static const String honeyCrystallization = 'honig_kristall';
  static const String honeyVariety = 'honig_sorte';
  static const String stockCategory = 'lager_kategorie';
  static const String stockReason = 'lager_grund';
  static const String hiveActionType = 'massnahme_art';

  /// Reihenfolge auf dem Bildschirm „Verzeichnisse".
  static const List<String> all = [
    honeyState,
    honeyCrystallization,
    honeyVariety,
    stockCategory,
    stockReason,
    hiveActionType,
  ];

  static const Map<String, String> _labels = {
    honeyState: 'Zustände am Eimer',
    honeyCrystallization: 'Markierungen am Honig',
    honeyVariety: 'Honigsorten',
    stockCategory: 'Lager-Kategorien',
    stockReason: 'Buchungsgründe',
    hiveActionType: 'Maßnahmen am Volk',
  };

  /// Was dieses Verzeichnis bedeutet – eine Zeile unter dem Namen.
  static const Map<String, String> _hints = {
    honeyState: 'Die Haken, die du am Eimer abhakst. Die Reihenfolge ist die '
        'Kette: wer einen Haken setzt, hat die davor erledigt.',
    honeyCrystallization: 'Steht neben den Haken, nicht darin. Der Weg zurück '
        'ist das Melitherm.',
    honeyVariety: 'Die Kürzel stehen auf den Eimern. Sie lassen sich '
        'umbenennen, aber nicht umschlüsseln.',
    stockCategory: 'Wie die Lagerposten einsortiert werden.',
    stockReason: 'Warum etwas ins Lager kam oder hinausging. Jeder Grund muss '
        'sagen, in welche Richtung er zählt.',
    hiveActionType: 'Die Arten von Einträgen in der Stockkarte.',
  };

  static String labelOf(String catalog) => _labels[catalog] ?? catalog;

  static String hintOf(String catalog) => _hints[catalog] ?? '';
}

/// In welche Richtung ein Buchungsgrund zählt.
///
/// `beides` gibt es, weil Abfüllung und Korrektur heute in beiden Listen
/// stehen: die Abfüllung nimmt Honig aus dem Eimer und legt Gläser ins Regal,
/// und eine Inventur kann in jede Richtung ausgehen.
class CatalogDirections {
  static const String inbound = 'zugang';
  static const String outbound = 'abgang';
  static const String both = 'beides';

  static const List<String> all = [inbound, outbound, both];

  static const Map<String, String> _labels = {
    inbound: 'Zugang',
    outbound: 'Abgang',
    both: 'beide Richtungen',
  };

  static String labelOf(String direction) => _labels[direction] ?? direction;

  static bool countsInbound(String? direction) =>
      direction == inbound || direction == both;

  static bool countsOutbound(String? direction) =>
      direction == outbound || direction == both;
}

/// Ein Verzeichnis, bei dem nur Beschriftung, Reihenfolge, Farbe und
/// Sichtbarkeit anpassbar sind.
///
/// Die schlichten Verzeichnisse – Sorten, Lager-Kategorien, Buchungsgründe,
/// Maßnahmen-Arten, Markierungen – unterscheiden sich allein in ihren
/// Vorgaben. Statt denselben Block fünfmal zu schreiben, hält jede Klasse eine
/// Instanz hiervon und gibt ihre öffentlichen Methoden daran weiter. Die
/// Aufrufstellen in den Bildschirmen bleiben dadurch unverändert.
///
/// Statische Felder mit Zustand sind sonst ein schlechtes Zeichen; hier sind
/// sie es nicht: Die Verzeichnisse werden einmal beim Start geladen und danach
/// aus `build()`-Methoden gelesen, die nicht warten können.
class SimpleCatalog {
  /// Welches Verzeichnis, siehe [Catalogs].
  final String name;

  /// Die Schlüssel der Werkseinstellung, in ihrer Reihenfolge.
  final List<String> defaultKeys;

  /// Die Beschriftungen der Werkseinstellung.
  final Map<String, String> defaultLabels;

  List<String> _keys;
  Map<String, CatalogEntry> _entries = const {};

  SimpleCatalog({
    required this.name,
    required this.defaultKeys,
    required this.defaultLabels,
  }) : _keys = defaultKeys;

  /// Das geladene Verzeichnis übernehmen.
  ///
  /// Ein Verzeichnis ohne jeden sichtbaren Eintrag wäre eine Auswahl ohne
  /// Auswahl, deshalb bleibt dann die Werkseinstellung stehen.
  void apply(List<CatalogEntry> eintraege) {
    final sortiert = [...eintraege]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _entries = {for (final e in sortiert) e.key: e};
    final sichtbar = sortiert
        .where((e) => !e.archived)
        .map((e) => e.key)
        .toList(growable: false);
    _keys = sichtbar.isEmpty ? defaultKeys : sichtbar;
  }

  /// Zurück auf die Werkseinstellung – für „Zurücksetzen" und für Tests.
  void useDefaults() {
    _keys = defaultKeys;
    _entries = const {};
  }

  /// Die sichtbaren Schlüssel in ihrer Reihenfolge.
  List<String> get keys => _keys;

  /// Auch ein ausgeblendeter Eintrag behält seine Beschriftung – sonst stünde
  /// an alten Daten plötzlich ein nackter Schlüssel.
  String labelOf(String key) =>
      _entries[key]?.label ?? defaultLabels[key] ?? key;

  int? colorOf(String key) => _entries[key]?.color;

  String? directionOf(String key) => _entries[key]?.direction;

  bool isKnown(String key) =>
      _entries.containsKey(key) || defaultLabels.containsKey(key);
}
