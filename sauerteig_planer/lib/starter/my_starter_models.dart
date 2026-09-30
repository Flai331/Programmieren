// ═══════════════════════════════════════════════════════════════
//  MEINE STARTER — Datenmodelle
//  lib/starter/my_starter_models.dart
// ═══════════════════════════════════════════════════════════════

class StarterFeedingLog {
  final DateTime date;
  final int kept;       // g behalten vor dem Füttern
  final int flour;      // g Mehl zugegeben
  final int water;      // g Wasser zugegeben
  final int totalAfter; // = kept + flour + water
  final String notes;

  const StarterFeedingLog({
    required this.date,
    required this.kept,
    required this.flour,
    required this.water,
    required this.totalAfter,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'kept': kept,
        'flour': flour,
        'water': water,
        'totalAfter': totalAfter,
        'notes': notes,
      };

  factory StarterFeedingLog.fromJson(Map<String, dynamic> j) =>
      StarterFeedingLog(
        date: DateTime.parse(j['date'] as String),
        kept: j['kept'] as int,
        flour: j['flour'] as int,
        water: j['water'] as int,
        totalAfter: j['totalAfter'] as int,
        notes: j['notes'] as String? ?? '',
      );
}

class MyStarter {
  final String id;
  final String name;
  final String? flourType;
  final String? origin;
  final int gramAmount; // aktuelle Menge im Kühlschrank
  final List<StarterFeedingLog> feedings;
  final DateTime createdAt;

  const MyStarter({
    required this.id,
    required this.name,
    this.flourType,
    this.origin,
    required this.gramAmount,
    required this.feedings,
    required this.createdAt,
  });

  DateTime? get lastFed =>
      feedings.isEmpty ? null : feedings.last.date;

  int get daysSinceLastFed {
    final l = lastFed;
    if (l == null) return -1;
    return DateTime.now().difference(l).inDays;
  }

  bool get needsFeeding => daysSinceLastFed >= 7 || daysSinceLastFed == -1;

  MyStarter copyWith({
    String? name,
    String? flourType,
    String? origin,
    int? gramAmount,
    List<StarterFeedingLog>? feedings,
  }) =>
      MyStarter(
        id: id,
        name: name ?? this.name,
        flourType: flourType ?? this.flourType,
        origin: origin ?? this.origin,
        gramAmount: gramAmount ?? this.gramAmount,
        feedings: feedings ?? this.feedings,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (flourType != null) 'flourType': flourType,
        if (origin != null) 'origin': origin,
        'gramAmount': gramAmount,
        'feedings': feedings.map((f) => f.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory MyStarter.fromJson(Map<String, dynamic> j) => MyStarter(
        id: j['id'] as String,
        name: j['name'] as String,
        flourType: j['flourType'] as String?,
        origin: j['origin'] as String?,
        gramAmount: j['gramAmount'] as int,
        feedings: (j['feedings'] as List<dynamic>? ?? [])
            .map((f) => StarterFeedingLog.fromJson(f as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  factory MyStarter.create({
    required String name,
    String? flourType,
    String? origin,
    required int gramAmount,
  }) =>
      MyStarter(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        flourType: flourType,
        origin: origin,
        gramAmount: gramAmount,
        feedings: [],
        createdAt: DateTime.now(),
      );
}
