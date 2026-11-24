import 'hive_action_model.dart';

/// Imkerei: Ein Posten im Lager – Honig, Gläser, Futter, Material.
///
/// Der Bestand steht bewusst NICHT in diesem Modell: Er ergibt sich aus der
/// Summe aller Bewegungen (siehe StockMovementModel und StockService). So kann
/// kein zweiter Wahrheitsstand entstehen, und zu jedem Bestand gibt es eine
/// Begründung in der Historie.
class StockItemModel {
  final String id;
  final String name;

  /// Siehe [StockCategories].
  final String category;

  /// Einheit des Bestands, z.B. 'kg', 'Stk', 'l', 'ml'.
  final String unit;

  /// Mindestbestand. Wird er unterschritten, warnt die App.
  /// Null bedeutet: keine Warnung für diesen Posten.
  final double? minQuantity;

  /// Einkaufs- bzw. Herstellungspreis je Einheit – Grundlage des Lagerwerts.
  final double? pricePerUnit;

  /// Honigsorte, nur bei abgefüllten Gläsern gesetzt (siehe HoneyVarieties).
  /// Material-Posten lassen das Feld leer.
  final String? variety;

  /// Füllgewicht eines Glases in Gramm, z.B. 500. Nur bei Glas-Posten.
  /// Macht aus kg im Eimer eine Gläserzahl beim Abfüllen.
  final int? jarSizeG;

  final String? note;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const StockItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.minQuantity,
    this.pricePerUnit,
    this.variety,
    this.jarSizeG,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  String get categoryLabel => StockCategories.labelOf(category);

  bool get hasMinimum => minQuantity != null && minQuantity! > 0;

  /// Hat der Posten ein Füllgewicht? Gilt für gefüllte wie für leere
  /// Gläser – das Füllgewicht allein sagt noch nicht, ob Honig drin ist.
  bool get hasJarSize => jarSizeG != null && jarSizeG! > 0;

  /// Abgefüllter Honig: ein Glas einer Sorte in einer Größe. Steht in der
  /// Warengruppe Honig, weil es Ware ist und keine Verpackung.
  bool get isFilledJar => category == StockCategories.honey && hasJarSize;

  /// Leergut: Gläser einer Größe, noch ohne Inhalt. Beim Abfüllen gehen sie
  /// ab, während die gefüllten zugehen – aber nur, wenn sie geführt werden.
  bool get isEmptyJar => category == StockCategories.jars && hasJarSize;

  /// Füllgewicht in kg, z.B. 0,5 bei einem 500-g-Glas.
  double? get jarSizeKg => jarSizeG == null ? null : jarSizeG! / 1000;

  /// Vergleichsname für den Abgleich mit Packlisten und Rechnungsposten.
  String get matchKey => normalizeName(name);

  /// Namen vergleichbar machen: Groß-/Kleinschreibung, Umlaute und
  /// Mehrfach-Leerzeichen sollen keinen Unterschied machen. „Mittelwände"
  /// und „mittelwaende" sind derselbe Posten.
  static String normalizeName(String raw) {
    final lower = raw.trim().toLowerCase();
    final ohneUmlaute = lower
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    return ohneUmlaute.replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'min_quantity': minQuantity,
        'price_per_unit': pricePerUnit,
        'variety': variety,
        'jar_size_g': jarSizeG,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory StockItemModel.fromMap(Map<String, dynamic> m) => StockItemModel(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        category: (m['category'] as String?) ?? StockCategories.other,
        unit: (m['unit'] as String?) ?? 'Stk',
        minQuantity: (m['min_quantity'] as num?)?.toDouble(),
        pricePerUnit: (m['price_per_unit'] as num?)?.toDouble(),
        variety: m['variety'] as String?,
        jarSizeG: (m['jar_size_g'] as num?)?.toInt(),
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  StockItemModel copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? minQuantity,
    double? pricePerUnit,
    String? variety,
    int? jarSizeG,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StockItemModel(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        minQuantity: minQuantity ?? this.minQuantity,
        pricePerUnit: pricePerUnit ?? this.pricePerUnit,
        variety: variety ?? this.variety,
        jarSizeG: jarSizeG ?? this.jarSizeG,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Warengruppen des Lagers.
class StockCategories {
  static const String honey = 'honig';
  static const String jars = 'glaeser';
  static const String feed = 'futter';
  static const String treatment = 'behandlung';
  static const String combs = 'waben';
  static const String hiveParts = 'beuten';
  static const String tools = 'werkzeug';
  static const String other = 'sonstiges';

  /// Reihenfolge der Auswahl in der App.
  static const List<String> all = [
    honey,
    jars,
    feed,
    treatment,
    combs,
    hiveParts,
    tools,
    other,
  ];

  static const Map<String, String> _labels = {
    honey: 'Honig',
    jars: 'Gläser & Etiketten',
    feed: 'Futter',
    treatment: 'Behandlungsmittel',
    combs: 'Waben & Rähmchen',
    hiveParts: 'Beuten & Zubehör',
    tools: 'Werkzeug',
    other: 'Sonstiges',
  };

  static String labelOf(String category) => _labels[category] ?? category;

  /// Vorbelegte Einheit einer Warengruppe.
  static String defaultUnitOf(String category) => switch (category) {
        honey => 'kg',
        feed => 'kg',
        treatment => 'ml',
        _ => 'Stk',
      };

  /// Warengruppe, aus der eine Maßnahme ihr Material nimmt.
  ///
  /// Grundlage für den Buchungsvorschlag nach dem Speichern einer Maßnahme:
  /// Eine Fütterung zehrt am Futter, eine Varroabehandlung am
  /// Behandlungsmittel, eine Honigernte füllt den Honigbestand auf.
  static String? forActionType(String actionType) => switch (actionType) {
        HiveActionTypes.harvest => honey,
        HiveActionTypes.feeding => feed,
        HiveActionTypes.varroa => treatment,
        HiveActionTypes.combs => combs,
        _ => null,
      };
}
