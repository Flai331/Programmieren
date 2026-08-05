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

/// Eine laufende Zeitsperre. Endet vorzeitig nur durch Generalschlüssel oder Code.
class TimeLockInfo {
  const TimeLockInfo({
    required this.profileId,
    required this.mode,
    required this.endsAt,
  });

  final String profileId;
  final LockMode mode;
  final DateTime endsAt;

  factory TimeLockInfo.fromMap(Map<dynamic, dynamic> map) => TimeLockInfo(
    profileId: map['profileId'] as String? ?? '',
    mode: _modeFrom(map['mode'] as String?),
    endsAt: DateTime.fromMillisecondsSinceEpoch(map['endsAt'] as int? ?? 0),
  );
}

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.profiles,
    required this.tags,
    required this.chipLockProfileId,
    required this.timeLocks,
    required this.hasMasterTag,
    required this.hasCode,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;

  /// Profil der Chipsperre, oder null. Sie hat kein Ende.
  final String? chipLockProfileId;

  /// Laufende Zeitsperren. Die native Seite filtert abgelaufene bereits heraus.
  final List<TimeLockInfo> timeLocks;

  /// Ob überhaupt ein Generalschlüssel angelernt ist — sonst öffnet nur der Code.
  final bool hasMasterTag;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final chipLock = map['chipLock'] as Map<dynamic, dynamic>?;
    return LockStatus(
      profiles: (map['profiles'] as List<dynamic>? ?? [])
          .map((e) => ProfileInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => TagInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      chipLockProfileId: chipLock?['profileId'] as String?,
      timeLocks: (map['timeLocks'] as List<dynamic>? ?? [])
          .map((e) => TimeLockInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      hasMasterTag: map['hasMasterTag'] as bool? ?? false,
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  bool get locked => chipLockProfileId != null || timeLocks.isNotEmpty;

  /// Alle Profile, die gerade sperren — über beide Spuren.
  Set<String> get lockedProfileIds => {
    ?chipLockProfileId,
    ...timeLocks.map((l) => l.profileId),
  };

  bool isProfileLocked(String profileId) => lockedProfileIds.contains(profileId);

  TimeLockInfo? timeLockFor(String profileId) {
    for (final lock in timeLocks) {
      if (lock.profileId == profileId) return lock;
    }
    return null;
  }

  /// Wann die erste Sperre fällt. Null, wenn nur die Chipsperre läuft.
  DateTime? get earliestEnd {
    if (timeLocks.isEmpty) return null;
    var earliest = timeLocks.first.endsAt;
    for (final lock in timeLocks) {
      if (lock.endsAt.isBefore(earliest)) earliest = lock.endsAt;
    }
    return earliest;
  }

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete =>
      tags.isNotEmpty &&
      hasCode &&
      profiles.any((p) => p.blockedPackages.isNotEmpty);
}
