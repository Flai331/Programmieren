
// ═══════════════════════════════════════════════════════════════
//  BAKING MODELS
// ═══════════════════════════════════════════════════════════════

enum StepStatus { pending, active, completed, skipped }

class BakingStep {
  String id;
  String emoji;
  String name;
  String description;
  Duration duration;
  bool useNativeTimer;
  int repeatCount;
  Duration repeatInterval;

  // Laufzeit-State (wird nicht gespeichert)
  StepStatus status;
  Duration remaining;
  DateTime? startedAt;

  BakingStep({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.duration,
    this.useNativeTimer = false,
    this.repeatCount = 1,
    this.repeatInterval = Duration.zero,
    this.status = StepStatus.pending,
  }) : remaining = duration;

  BakingStep copyWith({
    String? id,
    String? emoji,
    String? name,
    String? description,
    Duration? duration,
    bool? useNativeTimer,
    int? repeatCount,
    Duration? repeatInterval,
  }) {
    return BakingStep(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      useNativeTimer: useNativeTimer ?? this.useNativeTimer,
      repeatCount: repeatCount ?? this.repeatCount,
      repeatInterval: repeatInterval ?? this.repeatInterval,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'name': name,
        'description': description,
        'durationSeconds': duration.inSeconds,
        'useNativeTimer': useNativeTimer,
        'repeatCount': repeatCount,
        'repeatIntervalSeconds': repeatInterval.inSeconds,
      };

  factory BakingStep.fromJson(Map<String, dynamic> json) => BakingStep(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        emoji: json['emoji'] as String? ?? '⏱️',
        name: json['name'] as String? ?? 'Unbekannter Schritt',
        description: json['description'] as String? ?? '',
        duration: Duration(seconds: (json['durationSeconds'] as int?) ?? 300),
        useNativeTimer: json['useNativeTimer'] as bool? ?? false,
        repeatCount: (json['repeatCount'] as int?) ?? 1,
        repeatInterval: Duration(seconds: (json['repeatIntervalSeconds'] as int?) ?? 0),
      );
}

// ── Beispiel-Vorlagen ────────────────────────────────────────────
class StepTemplate {
  final String emoji;
  final String name;
  final String description;
  final Duration duration;
  final int repeatCount;
  final Duration repeatInterval;

  const StepTemplate({
    required this.emoji,
    required this.name,
    required this.description,
    required this.duration,
    this.repeatCount = 1,
    this.repeatInterval = Duration.zero,
  });
}

const kStepTemplates = <StepTemplate>[
  StepTemplate(
    emoji: '💧',
    name: 'Autolyse',
    description: 'Mehl und Wasser mischen, quellen lassen.',
    duration: Duration(minutes: 30),
  ),
  StepTemplate(
    emoji: '🧑‍🍳',
    name: 'Teig kneten',
    description: 'Alle Zutaten vermengen und zu einem glatten Teig kneten.',
    duration: Duration(minutes: 10),
  ),
  StepTemplate(
    emoji: '🤲',
    name: 'Dehnen & Falten',
    description: 'Teig von allen vier Seiten dehnen und zur Mitte falten.',
    duration: Duration(minutes: 5),
    repeatCount: 4,
    repeatInterval: Duration(minutes: 30),
  ),
  StepTemplate(
    emoji: '🌀',
    name: 'Coil Fold',
    description: 'Teig aufheben, unter sich falten und im Kreis drehen.',
    duration: Duration(minutes: 5),
    repeatCount: 3,
    repeatInterval: Duration(minutes: 45),
  ),
  StepTemplate(
    emoji: '🌡️',
    name: 'Stockgare',
    description: 'Teig bei Raumtemperatur reifen lassen.',
    duration: Duration(hours: 4),
  ),
  StepTemplate(
    emoji: '🔪',
    name: 'Vorformen',
    description: 'Teig portionieren und grob rund formen.',
    duration: Duration(minutes: 10),
  ),
  StepTemplate(
    emoji: '🫓',
    name: 'Endformen',
    description: 'Teig final formen und in den Gärkorb legen.',
    duration: Duration(minutes: 10),
  ),
  StepTemplate(
    emoji: '❄️',
    name: 'Stückgare (Kühlschrank)',
    description: 'Geformten Teigling über Nacht im Kühlschrank reifen lassen.',
    duration: Duration(hours: 12),
  ),
  StepTemplate(
    emoji: '🔥',
    name: 'Ofen vorheizen',
    description: 'Ofen mit Backstein/Dutch Oven auf 250 °C vorheizen.',
    duration: Duration(minutes: 45),
  ),
  StepTemplate(
    emoji: '🍞',
    name: 'Backen',
    description: 'Brot einschießen, bedampfen und fertig backen.',
    duration: Duration(minutes: 45),
  ),
  StepTemplate(
    emoji: '🧂',
    name: 'Salz einarbeiten',
    description: 'Salz zum Teig geben und einarbeiten.',
    duration: Duration(minutes: 5),
  ),
  StepTemplate(
    emoji: '🧊',
    name: 'Abkühlen',
    description: 'Brot auf einem Gitter vollständig auskühlen lassen.',
    duration: Duration(hours: 2),
  ),
];

class BakingRecipe {
  String id;
  String name;
  List<BakingStep> steps;
  DateTime lastUsed;

  BakingRecipe({
    required this.id,
    required this.name,
    required this.steps,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory BakingRecipe.fromJson(Map<String, dynamic> json) => BakingRecipe(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Unbekanntes Rezept',
        steps: ((json['steps'] as List?) ?? [])
            .map((s) => BakingStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        lastUsed: json['lastUsed'] != null
            ? DateTime.tryParse(json['lastUsed'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  /// Erstellt eine Kopie mit frischen Status-Werten (für aktiven Backmodus).
  /// Schritte mit repeatCount > 1 werden zu einzelnen Runden expandiert,
  /// mit Pause-Schritten dazwischen (wenn repeatInterval > 0).
  List<BakingStep> freshSteps() {
    final result = <BakingStep>[];
    for (final s in steps) {
      if (s.repeatCount <= 1) {
        result.add(BakingStep(
          id: s.id,
          emoji: s.emoji,
          name: s.name,
          description: s.description,
          duration: s.duration,
          useNativeTimer: s.useNativeTimer,
        ));
      } else {
        for (int i = 0; i < s.repeatCount; i++) {
          result.add(BakingStep(
            id: '${s.id}_r$i',
            emoji: s.emoji,
            name: '${s.name} (${i + 1}/${s.repeatCount})',
            description: s.description,
            duration: s.duration,
            useNativeTimer: s.useNativeTimer,
          ));
          if (i < s.repeatCount - 1 && s.repeatInterval > Duration.zero) {
            result.add(BakingStep(
              id: '${s.id}_pause$i',
              emoji: '⏳',
              name: 'Pause',
              description: 'Warte vor Runde ${i + 2}/${s.repeatCount}',
              duration: s.repeatInterval,
              useNativeTimer: s.useNativeTimer,
            ));
          }
        }
      }
    }
    return result;
  }
}

/// Formatiert Duration als "1 h 30 min" oder "45 min"
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  if (m == 0) return '${h}h';
  return '${h}h ${m}min';
}

/// Formatiert Duration als "MM:SS" für den Countdown
String formatCountdown(Duration d) {
  final total = d.inSeconds.clamp(0, double.maxFinite.toInt());
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
