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

/// Ein Termin, der sperrt oder sperren wird.
class CalendarWindowInfo {
  const CalendarWindowInfo({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.profileId,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String profileId;

  factory CalendarWindowInfo.fromMap(Map<dynamic, dynamic> map) =>
      CalendarWindowInfo(
        eventId: map['eventId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        startsAt: DateTime.fromMillisecondsSinceEpoch(map['startsAt'] as int? ?? 0),
        endsAt: DateTime.fromMillisecondsSinceEpoch(map['endsAt'] as int? ?? 0),
        profileId: map['profileId'] as String? ?? '',
      );
}

/// Ein Kalender des Geräts, für die Auswahlliste.
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.account,
  });

  final String id;
  final String name;
  final String account;

  factory DeviceCalendarInfo.fromMap(Map<dynamic, dynamic> map) =>
      DeviceCalendarInfo(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        account: map['account'] as String? ?? '',
      );
}

/// Welche Termine eines Kalenders sperren.
enum CalendarMatch { all, keyword }

CalendarMatch _matchFrom(String? raw) =>
    raw == 'KEYWORD' ? CalendarMatch.keyword : CalendarMatch.all;

String matchToNative(CalendarMatch m) =>
    m == CalendarMatch.keyword ? 'KEYWORD' : 'ALL';

/// Regel für einen Kalender des Geräts.
class CalendarRuleInfo {
  const CalendarRuleInfo({required this.profileId, required this.match});

  final String profileId;
  final CalendarMatch match;

  factory CalendarRuleInfo.fromMap(Map<dynamic, dynamic> map) => CalendarRuleInfo(
    profileId: map['profileId'] as String? ?? '',
    match: _matchFrom(map['match'] as String?),
  );

  Map<String, String> toMap() => {
    'profileId': profileId,
    'match': matchToNative(match),
  };
}

/// Kalenderteil des Zustands.
class CalendarInfo {
  const CalendarInfo({
    required this.enabled,
    required this.calendarRules,
    required this.keywordMarker,
    required this.keywordProfileId,
    required this.keywordCalendarIds,
    required this.permissionGranted,
    required this.windows,
    required this.activeWindows,
  });

  final bool enabled;

  /// Kalender-ID → Regel. Nicht enthaltene Kalender sperren nicht.
  final Map<String, CalendarRuleInfo> calendarRules;
  final String keywordMarker;
  final String? keywordProfileId;

  /// In welchen Kalendern die eigenständige Stichwortregel sucht. Leer = alle.
  final Set<String> keywordCalendarIds;
  final bool permissionGranted;

  /// Die nächsten drei Termine, für die Vorschau.
  final List<CalendarWindowInfo> windows;

  /// Termine, die gerade sperren.
  final List<CalendarWindowInfo> activeWindows;

  static const empty = CalendarInfo(
    enabled: false,
    calendarRules: {},
    keywordMarker: '[Riegel]',
    keywordProfileId: null,
    keywordCalendarIds: {},
    permissionGranted: false,
    windows: [],
    activeWindows: [],
  );

  factory CalendarInfo.fromMap(Map<dynamic, dynamic> map) => CalendarInfo(
    enabled: map['enabled'] as bool? ?? false,
    calendarRules: (map['calendarRules'] as Map<dynamic, dynamic>? ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        CalendarRuleInfo.fromMap(v as Map<dynamic, dynamic>),
      ),
    ),
    keywordMarker: map['keywordMarker'] as String? ?? '[Riegel]',
    keywordProfileId: map['keywordProfileId'] as String?,
    keywordCalendarIds:
        (map['keywordCalendarIds'] as List<dynamic>? ?? []).cast<String>().toSet(),
    permissionGranted: map['permissionGranted'] as bool? ?? false,
    windows: (map['windows'] as List<dynamic>? ?? [])
        .map((e) => CalendarWindowInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList(),
    activeWindows: (map['activeWindows'] as List<dynamic>? ?? [])
        .map((e) => CalendarWindowInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList(),
  );
}

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.profiles,
    required this.tags,
    required this.chipLockProfileId,
    required this.timeLocks,
    required this.calendar,
    required this.hasMasterTag,
    required this.hasCode,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;

  /// Profil der Chipsperre, oder null. Sie hat kein Ende.
  final String? chipLockProfileId;

  /// Laufende Zeitsperren. Die native Seite filtert abgelaufene bereits heraus.
  final List<TimeLockInfo> timeLocks;

  /// Kalendereinstellungen samt laufender Terminfenster.
  final CalendarInfo calendar;

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
      calendar: map['calendar'] == null
          ? CalendarInfo.empty
          : CalendarInfo.fromMap(map['calendar'] as Map<dynamic, dynamic>),
      hasMasterTag: map['hasMasterTag'] as bool? ?? false,
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  bool get locked =>
      chipLockProfileId != null ||
      timeLocks.isNotEmpty ||
      calendar.activeWindows.isNotEmpty;

  /// Alle Profile, die gerade sperren — über alle drei Quellen.
  Set<String> get lockedProfileIds => {
    ?chipLockProfileId,
    ...timeLocks.map((l) => l.profileId),
    ...calendar.activeWindows.map((w) => w.profileId),
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
