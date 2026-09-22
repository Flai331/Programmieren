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

/// Wen die Ruhe stumm schaltet. Spiegelt `QuietScope` der nativen Seite.
enum QuietScope { alle, ausgewaehlte, alleAusser }

QuietScope _scopeFrom(String? raw) => switch (raw) {
  'AUSGEWAEHLTE' => QuietScope.ausgewaehlte,
  'ALLE_AUSSER' => QuietScope.alleAusser,
  _ => QuietScope.alle,
};

String scopeToNative(QuietScope scope) => switch (scope) {
  QuietScope.alle => 'ALLE',
  QuietScope.ausgewaehlte => 'AUSGEWAEHLTE',
  QuietScope.alleAusser => 'ALLE_AUSSER',
};

/// Klingelmodus, den die Ruhe setzt. Reihenfolge wie im Kotlin-Enum.
enum RingerMode { unveraendert, laut, vibrieren, lautlos }

RingerMode _ringerFrom(String? raw) => switch (raw) {
  'LAUT' => RingerMode.laut,
  'VIBRIEREN' => RingerMode.vibrieren,
  'LAUTLOS' => RingerMode.lautlos,
  _ => RingerMode.unveraendert,
};

String ringerToNative(RingerMode mode) => switch (mode) {
  RingerMode.unveraendert => 'UNVERAENDERT',
  RingerMode.laut => 'LAUT',
  RingerMode.vibrieren => 'VIBRIEREN',
  RingerMode.lautlos => 'LAUTLOS',
};

/// Beschriftung für die Auswahl im Profilschirm.
String ringerLabel(RingerMode mode) => switch (mode) {
  RingerMode.unveraendert => 'Unverändert',
  RingerMode.laut => 'Laut',
  RingerMode.vibrieren => 'Vibrieren',
  RingerMode.lautlos => 'Lautlos',
};

/// Kürzel der Wochentage nach `Calendar.DAY_OF_WEEK`: Sonntag ist die 1.
const Map<int, String> kTagKuerzel = {
  2: 'Mo',
  3: 'Di',
  4: 'Mi',
  5: 'Do',
  6: 'Fr',
  7: 'Sa',
  1: 'So',
};

/// Minuten seit Mitternacht als `22:00`.
String uhrzeitAusMinuten(int minuten) {
  final h = (minuten ~/ 60).toString().padLeft(2, '0');
  final m = (minuten % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Ein wiederkehrendes Ruhefenster, etwa Mo–Fr 22:00–06:00.
class QuietScheduleInfo {
  const QuietScheduleInfo({
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });

  /// Wochentage nach `Calendar.DAY_OF_WEEK` — dieselbe Zählung wie nativ.
  final Set<int> days;
  final int startMinute;
  final int endMinute;

  factory QuietScheduleInfo.fromMap(Map<dynamic, dynamic> map) =>
      QuietScheduleInfo(
        days: (map['days'] as List<dynamic>? ?? []).cast<int>().toSet(),
        startMinute: map['startMinute'] as int? ?? 22 * 60,
        endMinute: map['endMinute'] as int? ?? 6 * 60,
      );

  Map<String, dynamic> toMap() => {
    'days': days.toList(),
    'startMinute': startMinute,
    'endMinute': endMinute,
  };

  QuietScheduleInfo copyWith({
    Set<int>? days,
    int? startMinute,
    int? endMinute,
  }) => QuietScheduleInfo(
    days: days ?? this.days,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
  );

  /// „Mo Di Mi · 22:00–06:00". Ohne Tag heißt: das Fenster greift nie.
  String get label {
    // In Wochenreihenfolge, nicht in der Reihenfolge des Antippens.
    final tage = kTagKuerzel.keys
        .where(days.contains)
        .map((t) => kTagKuerzel[t])
        .join(' ');
    final zeit =
        '${uhrzeitAusMinuten(startMinute)}–${uhrzeitAusMinuten(endMinute)}';
    return tage.isEmpty ? 'kein Tag · $zeit' : '$tage · $zeit';
  }
}

/// Ein Kontakt für die Auswahl. Die Nummer ist bereits auf Ziffern normalisiert.
class ContactInfo {
  const ContactInfo({required this.name, required this.number});

  final String name;
  final String number;

  factory ContactInfo.fromMap(Map<dynamic, dynamic> map) => ContactInfo(
    name: map['name'] as String? ?? '',
    number: map['number'] as String? ?? '',
  );
}

class ProfileInfo {
  const ProfileInfo({
    required this.id,
    required this.name,
    required this.blockedPackages,
    required this.mode,
    required this.durationMinutes,
    required this.untilAt,
    required this.pinCalendarEnd,
    required this.timedRelease,
    required this.pauseEnabled,
    required this.pauseStepMinutes,
    required this.pauseBaseSeconds,
    required this.pauseResetMinutes,
    required this.quietEnabled,
    required this.quietScope,
    required this.quietNumbers,
    required this.quietAfterEventMinutes,
    required this.quietWhileLocked,
    required this.quietSchedules,
    this.quietRinger = RingerMode.unveraendert,
    this.calendars = const {},
    this.keywordEverywhere = false,
  });

  final String id;
  final String name;
  final List<String> blockedPackages;
  final LockMode mode;
  final int durationMinutes;
  final DateTime? untilAt;
  final bool pinCalendarEnd;

  /// Der Chip öffnet dieses Profil nur für eine gewählte Spanne; danach sperrt
  /// es von selbst wieder.
  final bool timedRelease;

  /// Atempause gegen Doomscrolling. Keine Sperre — sie hält kurz auf.
  final bool pauseEnabled;
  final int pauseStepMinutes;
  final int pauseBaseSeconds;

  /// So lange unbenutzt, dann faengt die Staffelung von vorn an.
  final int pauseResetMinutes;

  /// Ruhe: Anrufe stumm schalten, ohne die Apps zu sperren.
  final bool quietEnabled;
  final QuietScope quietScope;

  /// Normalisierte Rufnummern — nur Ziffern, ohne Namen.
  final List<String> quietNumbers;

  /// Nachlauf nach dem Ende eines Termins dieses Profils.
  final int quietAfterEventMinutes;

  /// Ruhe auch, solange eine Sperre dieses Profils laeuft.
  final bool quietWhileLocked;
  final List<QuietScheduleInfo> quietSchedules;

  /// Klingelmodus des Telefons, solange die Ruhe dieses Profils greift.
  final RingerMode quietRinger;

  /// Kalender-ID → welche Termine dieses Profil sperren. Fehlt = aus.
  final Map<String, CalendarMatch> calendars;

  /// Termine mit dem Stichwort sperren dieses Profil, egal in welchem Kalender.
  final bool keywordEverywhere;

  /// Ob überhaupt ein Termin dieses Profil sperren kann.
  bool get usesCalendar => calendars.isNotEmpty || keywordEverywhere;

  factory ProfileInfo.fromMap(Map<dynamic, dynamic> map) {
    final until = map['untilAt'] as int?;
    return ProfileInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      blockedPackages: (map['blockedPackages'] as List<dynamic>? ?? [])
          .cast<String>(),
      mode: _modeFrom(map['defaultMode'] as String?),
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      untilAt: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until),
      pinCalendarEnd: map['pinCalendarEnd'] as bool? ?? false,
      timedRelease: map['timedRelease'] as bool? ?? false,
      pauseEnabled: map['pauseEnabled'] as bool? ?? false,
      pauseStepMinutes: map['pauseStepMinutes'] as int? ?? 15,
      pauseBaseSeconds: map['pauseBaseSeconds'] as int? ?? 5,
      pauseResetMinutes: map['pauseResetMinutes'] as int? ?? 15,
      quietEnabled: map['quietEnabled'] as bool? ?? false,
      quietScope: _scopeFrom(map['quietScope'] as String?),
      quietNumbers: (map['quietNumbers'] as List<dynamic>? ?? []).cast<String>(),
      quietAfterEventMinutes: map['quietAfterEventMinutes'] as int? ?? 0,
      quietWhileLocked: map['quietWhileLocked'] as bool? ?? true,
      quietSchedules: (map['quietSchedules'] as List<dynamic>? ?? [])
          .map((e) => QuietScheduleInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      quietRinger: _ringerFrom(map['quietRinger'] as String?),
      calendars: (map['calendars'] as Map<dynamic, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k as String, _matchFrom(v as String?)),
      ),
      keywordEverywhere: map['keywordEverywhere'] as bool? ?? false,
    );
  }
}

class TagInfo {
  const TagInfo({
    required this.uid,
    required this.label,
    required this.profileId,
  });

  final String uid;
  final String label;
  final String profileId;

  factory TagInfo.fromMap(Map<dynamic, dynamic> map) => TagInfo(
    uid: map['uid'] as String? ?? '',
    label: map['label'] as String? ?? '',
    profileId: map['profileId'] as String? ?? '',
  );
}

/// Eine laufende Zeitsperre. Endet vorzeitig nur durch den Notfall-Code.
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

/// Eine App, die im Starter auftaucht und damit sperrbar ist.
class InstalledAppInfo {
  const InstalledAppInfo({required this.name, required this.packageName});

  final String name;
  final String packageName;

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> map) =>
      InstalledAppInfo(
        name: map['name'] as String? ?? '',
        packageName: map['packageName'] as String? ?? '',
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
        startsAt: DateTime.fromMillisecondsSinceEpoch(
          map['startsAt'] as int? ?? 0,
        ),
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

/// Kalenderteil des Zustands.
class CalendarInfo {
  const CalendarInfo({
    required this.enabled,
    required this.keywordMarker,
    required this.permissionGranted,
    required this.windows,
    required this.activeWindows,
  });

  final bool enabled;
  final String keywordMarker;
  final bool permissionGranted;

  /// Die nächsten drei Termine, für die Vorschau.
  final List<CalendarWindowInfo> windows;

  /// Termine, die gerade sperren.
  final List<CalendarWindowInfo> activeWindows;

  static const empty = CalendarInfo(
    enabled: false,
    keywordMarker: '[Riegel]',
    permissionGranted: false,
    windows: [],
    activeWindows: [],
  );

  factory CalendarInfo.fromMap(Map<dynamic, dynamic> map) => CalendarInfo(
    enabled: map['enabled'] as bool? ?? false,
    keywordMarker: map['keywordMarker'] as String? ?? '[Riegel]',
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
    required this.releaseProfileId,
    required this.releaseEndsAt,
    required this.timeLocks,
    required this.calendar,
    required this.hasCode,
    required this.quietNow,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;

  /// Profil der Chipsperre, oder null. Sie hat kein Ende.
  final String? chipLockProfileId;

  /// Profil der laufenden Freigabe, oder null. Abgelaufene schickt die native
  /// Seite gar nicht erst mit.
  final String? releaseProfileId;

  /// Wann die Freigabe endet und das Profil wieder sperrt.
  final DateTime? releaseEndsAt;

  /// Laufende Zeitsperren. Die native Seite filtert abgelaufene bereits heraus.
  final List<TimeLockInfo> timeLocks;

  /// Kalendereinstellungen samt laufender Terminfenster.
  final CalendarInfo calendar;

  final bool hasCode;

  /// Ob gerade Ruhe gilt — nativ gerechnet, damit die Fensterlogik nicht
  /// zweimal existiert.
  final bool quietNow;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final chipLock = map['chipLock'] as Map<dynamic, dynamic>?;
    final release = map['release'] as Map<dynamic, dynamic>?;
    return LockStatus(
      profiles: (map['profiles'] as List<dynamic>? ?? [])
          .map((e) => ProfileInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => TagInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      chipLockProfileId: chipLock?['profileId'] as String?,
      releaseProfileId: release?['profileId'] as String?,
      releaseEndsAt: release?['endsAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(release!['endsAt'] as int),
      timeLocks: (map['timeLocks'] as List<dynamic>? ?? [])
          .map((e) => TimeLockInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      calendar: map['calendar'] == null
          ? CalendarInfo.empty
          : CalendarInfo.fromMap(map['calendar'] as Map<dynamic, dynamic>),
      hasCode: map['hasCode'] as bool? ?? false,
      quietNow: map['quietNow'] as bool? ?? false,
    );
  }

  bool get locked => lockedProfileIds.isNotEmpty;

  /// Alle Profile, die gerade sperren — über alle drei Quellen. Die Chipsperre
  /// zählt nicht, solange ihr Profil freigegeben ist; dieselbe Ausnahme wie in
  /// `LockEngine.lockedProfileIds`.
  Set<String> get lockedProfileIds => {
    if (chipLockProfileId != null && chipLockProfileId != releaseProfileId)
      chipLockProfileId!,
    ...timeLocks.map((l) => l.profileId),
    ...calendar.activeWindows.map((w) => w.profileId),
  };

  bool isProfileLocked(String profileId) =>
      lockedProfileIds.contains(profileId);

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
