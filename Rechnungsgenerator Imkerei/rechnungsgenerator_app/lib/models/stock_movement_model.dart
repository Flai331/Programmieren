import 'hive_action_model.dart';

/// Imkerei: Eine Lagerbewegung – Zugang, Abgang oder Korrektur.
///
/// [quantity] ist vorzeichenbehaftet: positiv bei Zugang, negativ bei Abgang.
/// Der Bestand eines Postens ist damit schlicht die Summe seiner Bewegungen,
/// ohne Fallunterscheidung in der Abfrage.
class StockMovementModel {
  final String id;
  final String itemId;
  final DateTime date;

  /// Vorzeichenbehaftete Menge in der Einheit des Postens.
  final double quantity;

  /// Siehe [StockReasons].
  final String reason;

  final String? note;

  /// Maßnahme, aus der die Bewegung entstanden ist (Ernte, Fütterung,
  /// Behandlung). Null bei von Hand erfassten Bewegungen.
  final String? hiveActionId;

  /// Rechnung, über die der Abgang verkauft wurde.
  final String? invoiceId;

  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.itemId,
    required this.date,
    required this.quantity,
    required this.reason,
    this.note,
    this.hiveActionId,
    this.invoiceId,
    required this.createdAt,
  });

  bool get isInbound => quantity > 0;

  String get reasonLabel => StockReasons.labelOf(reason);

  /// Stammt die Bewegung aus einer Maßnahme oder Rechnung? Solche Buchungen
  /// gehören zu ihrem Ursprung und werden dort geändert, nicht im Lager.
  bool get isLinked => hiveActionId != null || invoiceId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'date': date.toIso8601String(),
        'quantity': quantity,
        'reason': reason,
        'note': note,
        'hive_action_id': hiveActionId,
        'invoice_id': invoiceId,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovementModel.fromMap(Map<String, dynamic> m) =>
      StockMovementModel(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        date: DateTime.parse(m['date'] as String),
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        reason: (m['reason'] as String?) ?? StockReasons.correction,
        note: m['note'] as String?,
        hiveActionId: m['hive_action_id'] as String?,
        invoiceId: m['invoice_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  StockMovementModel copyWith({
    String? id,
    String? itemId,
    DateTime? date,
    double? quantity,
    String? reason,
    String? note,
    String? hiveActionId,
    String? invoiceId,
    DateTime? createdAt,
  }) =>
      StockMovementModel(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        date: date ?? this.date,
        quantity: quantity ?? this.quantity,
        reason: reason ?? this.reason,
        note: note ?? this.note,
        hiveActionId: hiveActionId ?? this.hiveActionId,
        invoiceId: invoiceId ?? this.invoiceId,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Buchungsgründe. Sie tragen die Bedeutung einer Bewegung – das Vorzeichen
/// der Menge allein sagt nur, in welche Richtung es ging.
class StockReasons {
  /// Einkauf oder Herstellung.
  static const String purchase = 'zugang';

  /// Honigernte aus einem Volk.
  static const String harvest = 'ernte';

  /// Verkauf, in der Regel über eine Rechnung.
  static const String sale = 'verkauf';

  /// Verbrauch am Volk: Futter, Behandlungsmittel, Material.
  static const String consumption = 'verbrauch';

  /// Eigenbedarf, Geschenke, Verkostung.
  static const String ownUse = 'eigenbedarf';

  /// Bruch, Verderb, Verlust.
  static const String loss = 'schwund';

  /// Inventur: der gezählte Bestand weicht ab.
  static const String correction = 'korrektur';

  /// Abfüllung: Honig aus dem Eimer wird zu Gläsern. Erzeugt einen Zugang
  /// beim Glas-Posten und, falls geführt, einen Abgang bei den leeren
  /// Gläsern.
  static const String bottling = 'abfuellung';

  static const Map<String, String> _labels = {
    purchase: 'Zugang',
    harvest: 'Ernte',
    sale: 'Verkauf',
    consumption: 'Verbrauch',
    ownUse: 'Eigenbedarf',
    loss: 'Schwund',
    correction: 'Korrektur',
    bottling: 'Abfüllung',
  };

  static String labelOf(String reason) => _labels[reason] ?? reason;

  /// Gründe für einen Zugang, in der Reihenfolge der Auswahl.
  static const List<String> inbound = [purchase, harvest, bottling, correction];

  /// Gründe für einen Abgang.
  static const List<String> outbound = [
    sale,
    consumption,
    ownUse,
    loss,
    bottling,
    correction,
  ];

  /// Grund, mit dem eine Maßnahme ins Lager gebucht wird.
  static String forActionType(String actionType) =>
      actionType == HiveActionTypes.harvest ? harvest : consumption;
}
