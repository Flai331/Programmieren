enum LockMode { open, timer, until }

LockMode _modeFrom(String? raw) => switch (raw) {
  'OPEN' => LockMode.open,
  'UNTIL' => LockMode.until,
  _ => LockMode.timer,
};

String modeToNative(LockMode mode) => switch (mode) {
  LockMode.open => 'OPEN',
  LockMode.timer => 'TIMER',
  LockMode.until => 'UNTIL',
};

class ProfileInfo {
  const ProfileInfo({
    required this.id,
    required this.name,
    required this.blockedPackages,
    required this.mode,
    required this.durationMinutes,
    required this.untilAt,
    required this.pinCalendarEnd,
  });

  final String id;
  final String name;
  final List<String> blockedPackages;
  final LockMode mode;
  final int durationMinutes;
  final DateTime? untilAt;
  final bool pinCalendarEnd;

  factory ProfileInfo.fromMap(Map<dynamic, dynamic> map) {
    final until = map['untilAt'] as int?;
    return ProfileInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      blockedPackages:
          (map['blockedPackages'] as List<dynamic>? ?? []).cast<String>(),
      mode: _modeFrom(map['defaultMode'] as String?),
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      untilAt: until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
      pinCalendarEnd: map['pinCalendarEnd'] as bool? ?? false,
    );
  }
}

class TagInfo {
  const TagInfo({
    required this.uid,
    required this.label,
    required this.profileId,
    required this.isMaster,
  });

  final String uid;
  final String label;
  final String profileId;
  final bool isMaster;

  factory TagInfo.fromMap(Map<dynamic, dynamic> map) => TagInfo(
    uid: map['uid'] as String? ?? '',
    label: map['label'] as String? ?? '',
    profileId: map['profileId'] as String? ?? '',
    isMaster: map['isMaster'] as bool? ?? false,
  );
}

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.profiles,
    required this.tags,
    required this.activeProfileId,
    required this.activeMode,
    required this.endsAt,
    required this.hasCode,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;
  final String? activeProfileId;
  final LockMode? activeMode;
  final DateTime? endsAt;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final lock = map['activeLock'] as Map<dynamic, dynamic>?;
    final endsAtMillis = lock?['endsAt'] as int?;
    return LockStatus(
      profiles: (map['profiles'] as List<dynamic>? ?? [])
          .map((e) => ProfileInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => TagInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      activeProfileId: lock?['profileId'] as String?,
      activeMode: lock == null ? null : _modeFrom(lock['mode'] as String?),
      endsAt: endsAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAtMillis),
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  bool get locked => activeProfileId != null;

  ProfileInfo? get activeProfile {
    for (final p in profiles) {
      if (p.id == activeProfileId) return p;
    }
    return null;
  }

  /// Ein Profil ist nur dann gesperrt, wenn genau es gerade sperrt.
  bool isProfileLocked(String profileId) => activeProfileId == profileId;

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete =>
      tags.isNotEmpty &&
      hasCode &&
      profiles.any((p) => p.blockedPackages.isNotEmpty);
}
