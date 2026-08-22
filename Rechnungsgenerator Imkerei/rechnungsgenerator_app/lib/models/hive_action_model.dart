import 'dart:convert';

/// Imkerei: Maßnahme an einem Volk – der Verlauf einer Stockkarte.
///
/// Deckt die in der Projektplanung genannten Arbeiten ab: Durchsicht,
/// Fütterung, Varroabehandlung, Honigernte, Schwarmkontrolle,
/// Königinnenzucht und Wabenerneuerung.
class HiveActionModel {
  final String id;
  final String hiveId;
  final DateTime date;

  /// Siehe [HiveActionTypes].
  final String type;

  final String? note;

  // ── Durchsicht / Schwarmkontrolle ───────────────────────────
  /// Anzahl Brutwaben
  final int? broodFrames;

  /// Anzahl besetzter Waben
  final int? beeFrames;

  /// Sanftmut 1 (stechlustig) – 5 (sehr sanft)
  final int? temper;

  final bool? queenSeen;
  final bool? swarmCells;

  // ── Fütterung / Ernte / Behandlung ──────────────────────────
  /// Menge, z.B. 5 (kg Futter) oder 12.5 (kg Honig)
  final double? amount;

  /// Einheit zur [amount], z.B. 'kg', 'l', 'ml'
  final String? unit;

  /// Eingesetztes Mittel, z.B. 'Ameisensäure 60%'
  final String? treatment;

  /// Lokale Dateipfade der angehängten Fotos
  final List<String> photoPaths;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const HiveActionModel({
    required this.id,
    required this.hiveId,
    required this.date,
    required this.type,
    this.note,
    this.broodFrames,
    this.beeFrames,
    this.temper,
    this.queenSeen,
    this.swarmCells,
    this.amount,
    this.unit,
    this.treatment,
    this.photoPaths = const [],
    required this.createdAt,
    this.updatedAt,
  });

  String get typeLabel => HiveActionTypes.labelOf(type);

  bool get hasPhotos => photoPaths.isNotEmpty;

  /// Einzeilige Zusammenfassung für Timeline und Stockkarte.
  ///
  /// Beispiele: „12,5 kg", „Ameisensäure 60% · 200 ml",
  /// „6 Brutwaben · 10 Waben besetzt · Königin gesehen".
  String get summary {
    final parts = <String>[];

    if ((treatment ?? '').isNotEmpty) parts.add(treatment!);
    if (amount != null) parts.add(_formatAmount(amount!, unit));
    if (broodFrames != null) parts.add('$broodFrames Brutwaben');
    if (beeFrames != null) parts.add('$beeFrames Waben besetzt');
    if (queenSeen == true) parts.add('Königin gesehen');
    if (swarmCells == true) parts.add('Schwarmzellen');
    if (temper != null) parts.add('Sanftmut $temper/5');

    if (parts.isEmpty) return (note ?? '').trim();
    return parts.join(' · ');
  }

  static String _formatAmount(double value, String? unit) {
    final rounded = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return unit == null || unit.isEmpty ? rounded : '$rounded $unit';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'hive_id': hiveId,
        'date': date.toIso8601String(),
        'type': type,
        'note': note,
        'brood_frames': broodFrames,
        'bee_frames': beeFrames,
        'temper': temper,
        'queen_seen': _boolToDb(queenSeen),
        'swarm_cells': _boolToDb(swarmCells),
        'amount': amount,
        'unit': unit,
        'treatment': treatment,
        'photo_paths': photoPaths.isEmpty ? null : jsonEncode(photoPaths),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory HiveActionModel.fromMap(Map<String, dynamic> m) => HiveActionModel(
        id: m['id'] as String,
        hiveId: m['hive_id'] as String,
        date: DateTime.parse(m['date'] as String),
        type: (m['type'] as String?) ?? HiveActionTypes.other,
        note: m['note'] as String?,
        broodFrames: m['brood_frames'] as int?,
        beeFrames: m['bee_frames'] as int?,
        temper: m['temper'] as int?,
        queenSeen: _boolFromDb(m['queen_seen']),
        swarmCells: _boolFromDb(m['swarm_cells']),
        amount: (m['amount'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
        treatment: m['treatment'] as String?,
        photoPaths: _photosFromDb(m['photo_paths']),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  static int? _boolToDb(bool? v) => v == null ? null : (v ? 1 : 0);

  static bool? _boolFromDb(Object? v) => v == null ? null : (v as int) == 1;

  static List<String> _photosFromDb(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // Beschädigter Eintrag darf die Maßnahme nicht unlesbar machen.
    }
    return const [];
  }

  HiveActionModel copyWith({
    String? id,
    String? hiveId,
    DateTime? date,
    String? type,
    String? note,
    int? broodFrames,
    int? beeFrames,
    int? temper,
    bool? queenSeen,
    bool? swarmCells,
    double? amount,
    String? unit,
    String? treatment,
    List<String>? photoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HiveActionModel(
        id: id ?? this.id,
        hiveId: hiveId ?? this.hiveId,
        date: date ?? this.date,
        type: type ?? this.type,
        note: note ?? this.note,
        broodFrames: broodFrames ?? this.broodFrames,
        beeFrames: beeFrames ?? this.beeFrames,
        temper: temper ?? this.temper,
        queenSeen: queenSeen ?? this.queenSeen,
        swarmCells: swarmCells ?? this.swarmCells,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        treatment: treatment ?? this.treatment,
        photoPaths: photoPaths ?? this.photoPaths,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Maßnahmen-Typen samt Beschriftung und passenden Eingabefeldern.
class HiveActionTypes {
  static const String inspection = 'durchsicht';
  static const String feeding = 'fuetterung';
  static const String varroa = 'varroa';
  static const String harvest = 'honigernte';
  static const String swarm = 'schwarmkontrolle';
  static const String queen = 'koenigin';
  static const String combs = 'wabenerneuerung';
  static const String other = 'sonstiges';

  /// Reihenfolge der Auswahl in der App.
  static const List<String> all = [
    inspection,
    feeding,
    varroa,
    harvest,
    swarm,
    queen,
    combs,
    other,
  ];

  static const Map<String, String> _labels = {
    inspection: 'Durchsicht',
    feeding: 'Fütterung',
    varroa: 'Varroabehandlung',
    harvest: 'Honigernte',
    swarm: 'Schwarmkontrolle',
    queen: 'Königin',
    combs: 'Wabenerneuerung',
    other: 'Sonstiges',
  };

  static String labelOf(String type) => _labels[type] ?? type;

  /// Vorbelegte Einheit für die Mengenangabe.
  static String defaultUnitOf(String type) => switch (type) {
        feeding => 'kg',
        harvest => 'kg',
        varroa => 'ml',
        _ => '',
      };

  /// Typen mit Waben-/Brutzählung und Sanftmut.
  static bool hasColonyMetrics(String type) =>
      type == inspection || type == swarm;

  /// Typen mit Mengenangabe.
  static bool hasAmount(String type) =>
      type == feeding || type == harvest || type == varroa;

  /// Typen mit Angabe des eingesetzten Mittels.
  static bool hasTreatment(String type) => type == varroa;
}
