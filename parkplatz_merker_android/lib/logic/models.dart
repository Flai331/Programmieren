import 'dart:convert';

class RawEvent {
  final String type;
  final int t;
  final Map<String, dynamic> data;

  RawEvent({
    required this.type,
    required this.t,
    required this.data,
  });

  /// Versucht, eine JSON-Zeile zu parsen. Gibt null zurück, wenn ungültig.
  static RawEvent? tryParse(String line) {
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      return RawEvent.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  /// Erstellt eine RawEvent aus einer JSON-Map. Fehlendes 't' wird zu 0.
  factory RawEvent.fromJson(Map<String, dynamic> m) {
    final type = m['type'] as String? ?? 'unknown';
    final t = (m['t'] as num?)?.toInt() ?? 0;
    return RawEvent(type: type, t: t, data: Map.from(m));
  }

  /// Gibt die komplette JSON-Map zurück (= data).
  Map<String, dynamic> toJson() => data;

  String? str(String k) => data[k] as String?;
  double? dbl(String k) {
    final v = data[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? integer(String k) {
    final v = data[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool? boolean(String k) => data[k] as bool?;
}

class LocSample {
  final int t;
  final double lat;
  final double lng;
  final double acc;

  LocSample({
    required this.t,
    required this.lat,
    required this.lng,
    required this.acc,
  });
}

class ParkingSpot {
  final String id;
  final int time;
  final double lat;
  final double lng;
  final double acc;
  final List<String> sources;
  final bool manual;
  final String? note;
  final String? photoPath;
  final String? address;
  final int? reminderAt;

  ParkingSpot({
    required this.id,
    required this.time,
    required this.lat,
    required this.lng,
    required this.acc,
    required this.sources,
    required this.manual,
    this.note,
    this.photoPath,
    this.address,
    this.reminderAt,
  });

  String get sourceLabel => sources.join(' + ');

  ParkingSpot copyWith({
    String? id,
    int? time,
    double? lat,
    double? lng,
    double? acc,
    List<String>? sources,
    bool? manual,
    String? note,
    bool clearNote = false,
    String? photoPath,
    bool clearPhoto = false,
    String? address,
    bool clearAddress = false,
    int? reminderAt,
    bool clearReminder = false,
  }) {
    return ParkingSpot(
      id: id ?? this.id,
      time: time ?? this.time,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      acc: acc ?? this.acc,
      sources: sources ?? this.sources,
      manual: manual ?? this.manual,
      note: clearNote ? null : (note ?? this.note),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      address: clearAddress ? null : (address ?? this.address),
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'lat': lat,
        'lng': lng,
        'acc': acc,
        'sources': sources,
        'manual': manual,
        if (note != null) 'note': note,
        if (photoPath != null) 'photoPath': photoPath,
        if (address != null) 'address': address,
        if (reminderAt != null) 'reminderAt': reminderAt,
      };

  factory ParkingSpot.fromJson(Map<String, dynamic> m) {
    return ParkingSpot(
      id: m['id'] as String,
      time: m['time'] as int,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      acc: (m['acc'] as num).toDouble(),
      sources: List<String>.from(m['sources'] as List),
      manual: m['manual'] as bool,
      note: m['note'] as String?,
      photoPath: m['photoPath'] as String?,
      address: m['address'] as String?,
      reminderAt: m['reminderAt'] as int?,
    );
  }
}
