enum LockMode { open, timer }

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.locked,
    required this.mode,
    required this.endsAt,
    required this.durationMinutes,
    required this.blockedPackages,
    required this.hasTag,
    required this.hasCode,
  });

  final bool locked;
  final LockMode mode;
  final DateTime? endsAt;
  final int durationMinutes;
  final List<String> blockedPackages;
  final bool hasTag;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final endsAtMillis = map['endsAt'] as int?;
    return LockStatus(
      locked: map['locked'] as bool? ?? false,
      mode: map['mode'] == 'OPEN' ? LockMode.open : LockMode.timer,
      endsAt: endsAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAtMillis),
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      blockedPackages:
          (map['blockedPackages'] as List<dynamic>? ?? []).cast<String>(),
      hasTag: map['hasTag'] as bool? ?? false,
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete => hasTag && hasCode && blockedPackages.isNotEmpty;
}
