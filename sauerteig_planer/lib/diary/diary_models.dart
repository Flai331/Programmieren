import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY MODELS
// ═══════════════════════════════════════════════════════════════

enum DiaryEntryType { feeding, baking, observation, note }

const kEntryTypeEmoji = {
  DiaryEntryType.feeding: '🫙',
  DiaryEntryType.baking: '🍞',
  DiaryEntryType.observation: '🔍',
  DiaryEntryType.note: '📝',
};

const kEntryTypeLabel = {
  DiaryEntryType.feeding: 'Fütterung',
  DiaryEntryType.baking: 'Backen',
  DiaryEntryType.observation: 'Beobachtung',
  DiaryEntryType.note: 'Notiz',
};

const kEntryTypeColor = {
  DiaryEntryType.feeding: AppColors.green,
  DiaryEntryType.baking: AppColors.gold,
  DiaryEntryType.observation: AppColors.blue,
  DiaryEntryType.note: AppColors.orange,
};

const kQuickEntries = {
  DiaryEntryType.observation: [
    'Bläschen sichtbar',
    'Geruch säuerlich',
    'Volumen verdoppelt',
    'Oberfläche gewölbt',
    'Graue Flüssigkeit oben drauf (Hunger)',
    'Starter sehr aktiv',
    'Wenig Aktivität',
  ],
  DiaryEntryType.feeding: [
    '1:1:1 Verhältnis',
    '1:2:2 Verhältnis',
    'Hälfte verworfen',
    'Vollkornmehl',
    'Roggenmehl',
    'Weizenmehl 550',
  ],
  DiaryEntryType.baking: [
    'Float-Test bestanden',
    'Brot gut aufgegangen',
    'Kruste super knusprig',
    'Krume schön offen',
    'Ausbund gut geöffnet',
    'Nächstes Mal länger backen',
  ],
  DiaryEntryType.note: [
    'Starter riecht gut',
    'Zimmertemperatur hoch',
    'Neues Mehl ausprobiert',
    'Gärkörbe eingemehlt',
  ],
};

class DiaryEntry {
  final String id;
  final DateTime timestamp;
  final DiaryEntryType type;
  final String text;
  final double? temperature;
  final int? activityRating; // 1–5
  final String? photoPath;
  final String? starterName;
  final String? flourType; // Mehlsorte bei Fütterung

  DiaryEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.text,
    this.temperature,
    this.activityRating,
    this.photoPath,
    this.starterName,
    this.flourType,
  });

  DiaryEntry copyWith({
    DateTime? timestamp,
    DiaryEntryType? type,
    String? text,
    double? temperature,
    int? activityRating,
    String? photoPath,
    String? starterName,
    String? flourType,
    bool clearPhoto = false,
    bool clearTemp = false,
    bool clearRating = false,
    bool clearStarterName = false,
    bool clearFlourType = false,
  }) {
    return DiaryEntry(
      id: id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      text: text ?? this.text,
      temperature: clearTemp ? null : (temperature ?? this.temperature),
      activityRating:
          clearRating ? null : (activityRating ?? this.activityRating),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      starterName:
          clearStarterName ? null : (starterName ?? this.starterName),
      flourType: clearFlourType ? null : (flourType ?? this.flourType),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'text': text,
        'temperature': temperature,
        'activityRating': activityRating,
        'photoPath': photoPath,
        if (starterName != null) 'starterName': starterName,
        if (flourType != null) 'flourType': flourType,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) {
    return DiaryEntry(
      id: j['id'] as String,
      timestamp: DateTime.parse(j['timestamp'] as String),
      type: DiaryEntryType.values.firstWhere(
        (t) => t.name == j['type'],
        orElse: () => DiaryEntryType.note,
      ),
      text: j['text'] as String? ?? '',
      temperature: (j['temperature'] as num?)?.toDouble(),
      activityRating: j['activityRating'] as int?,
      photoPath: j['photoPath'] as String?,
      starterName: j['starterName'] as String?,
      flourType: j['flourType'] as String?,
    );
  }

  factory DiaryEntry.create(DiaryEntryType type) {
    return DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      text: '',
    );
  }
}
