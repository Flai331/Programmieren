/// Imkerei: Volk (Hive) – ersetzt Papier-Stockkarten.
class HiveModel {
  final String id;
  final int? number;
  final String? name;
  final String qrId;
  final int? queenYear;
  final String? queenOrigin;
  final String? location;
  final String status; // 'aktiv' | 'abgegeben' | 'eingegangen'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const HiveModel({
    required this.id,
    this.number,
    this.name,
    required this.qrId,
    this.queenYear,
    this.queenOrigin,
    this.location,
    this.status = 'aktiv',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Anzeige-Bezeichnung: „#5 · Standort A" oder Name fallback
  String get displayLabel {
    final parts = <String>[];
    if (number != null) parts.add('#$number');
    if ((name ?? '').isNotEmpty) parts.add(name!);
    if (parts.isEmpty) parts.add('Volk');
    return parts.join(' · ');
  }

  bool get isActive => status == 'aktiv';

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'name': name,
        'qr_id': qrId,
        'queen_year': queenYear,
        'queen_origin': queenOrigin,
        'location': location,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory HiveModel.fromMap(Map<String, dynamic> m) => HiveModel(
        id: m['id'] as String,
        number: m['number'] as int?,
        name: m['name'] as String?,
        qrId: m['qr_id'] as String,
        queenYear: m['queen_year'] as int?,
        queenOrigin: m['queen_origin'] as String?,
        location: m['location'] as String?,
        status: (m['status'] as String?) ?? 'aktiv',
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  HiveModel copyWith({
    String? id,
    int? number,
    String? name,
    String? qrId,
    int? queenYear,
    String? queenOrigin,
    String? location,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HiveModel(
        id: id ?? this.id,
        number: number ?? this.number,
        name: name ?? this.name,
        qrId: qrId ?? this.qrId,
        queenYear: queenYear ?? this.queenYear,
        queenOrigin: queenOrigin ?? this.queenOrigin,
        location: location ?? this.location,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
