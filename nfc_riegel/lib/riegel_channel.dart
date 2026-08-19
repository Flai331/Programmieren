import 'package:flutter/services.dart';

import 'lock_status.dart';
import 'screen_time.dart';

/// Einzige Stelle, an der Dart mit der nativen Seite spricht.
class RiegelChannel {
  const RiegelChannel([this.channel = const MethodChannel(_name)]);

  static const _name = 'com.klaas.nfc_riegel/riegel';

  final MethodChannel channel;

  Future<LockStatus> getState() async {
    final map = await channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    return LockStatus.fromMap(map ?? const {});
  }

  Future<String> addProfile(String name) async =>
      await channel.invokeMethod<String>('addProfile', {'name': name}) ?? '';

  /// Startet eine Zeitsperre ohne Chip. Liefert den nativen Ausgang als Text,
  /// z.B. `STARTED`, `EXTENDED`, `ALREADY_RUNNING`, `UNTIL_IN_PAST`.
  Future<String> startLock(String profileId) async =>
      await channel.invokeMethod<String>('startLock', {
        'profileId': profileId,
      }) ??
      'NO_PROFILE';

  Future<bool> updateProfile(ProfileInfo profile) async =>
      await channel.invokeMethod<bool>('updateProfile', {
        'id': profile.id,
        'name': profile.name,
        'blockedPackages': profile.blockedPackages,
        'defaultMode': modeToNative(profile.mode),
        'durationMinutes': profile.durationMinutes,
        'untilAt': profile.untilAt?.millisecondsSinceEpoch,
        'pinCalendarEnd': profile.pinCalendarEnd,
        'pauseEnabled': profile.pauseEnabled,
        'pauseStepMinutes': profile.pauseStepMinutes,
        'pauseBaseSeconds': profile.pauseBaseSeconds,
      }) ??
      false;

  Future<bool> deleteProfile(String id) async =>
      await channel.invokeMethod<bool>('deleteProfile', {'id': id}) ?? false;

  Future<bool> deleteTag(String uid) async =>
      await channel.invokeMethod<bool>('deleteTag', {'uid': uid}) ?? false;

  Future<String?> generateCode() async =>
      channel.invokeMethod<String>('generateCode');

  Future<void> startTagEnrollment({
    required String label,
    required String profileId,
    required bool isMaster,
  }) => channel.invokeMethod<void>('startTagEnrollment', {
    'label': label,
    'profileId': profileId,
    'isMaster': isMaster,
  });

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() => channel.invokeMethod<void>('requestAdmin');

  /// Gibt das Administratorrecht zurueck, damit sich die App deinstallieren
  /// laesst. Liefert false, wenn gerade etwas sperrt.
  Future<bool> releaseAdmin() async =>
      await channel.invokeMethod<bool>('releaseAdmin') ?? false;

  Future<bool> usageAccessGranted() async =>
      await channel.invokeMethod<bool>('usageAccessGranted') ?? false;

  Future<void> openUsageAccessSettings() =>
      channel.invokeMethod<void>('openUsageAccessSettings');

  /// Tagesnutzung ab Mitternacht, absteigend sortiert.
  Future<List<AppUsage>> screenTimeToday() async {
    final raw = await channel.invokeMethod<List<dynamic>>('screenTimeToday');
    return (raw ?? [])
        .map((e) => AppUsage.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Sperrbare Apps: alles mit Startsymbol, ohne Riegel selbst.
  Future<List<InstalledAppInfo>> launchableApps() async {
    final raw = await channel.invokeMethod<List<dynamic>>('launchableApps');
    return (raw ?? [])
        .map((e) => InstalledAppInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<List<DeviceCalendarInfo>> deviceCalendars() async {
    final raw = await channel.invokeMethod<List<dynamic>>('deviceCalendars');
    return (raw ?? [])
        .map((e) => DeviceCalendarInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<bool> requestCalendarPermission() async =>
      await channel.invokeMethod<bool>('requestCalendarPermission') ?? false;

  Future<void> setCalendarSettings({
    required bool enabled,
    required Map<String, CalendarRuleInfo> calendarRules,
    required String keywordMarker,
    String? keywordProfileId,
    Set<String> keywordCalendarIds = const {},
  }) async {
    await channel.invokeMethod<bool>('setCalendarSettings', {
      'enabled': enabled,
      'calendarRules': calendarRules.map((k, v) => MapEntry(k, v.toMap())),
      'keywordMarker': keywordMarker,
      'keywordProfileId': keywordProfileId,
      'keywordCalendarIds': keywordCalendarIds.toList(),
    });
  }

  Future<void> refreshCalendar() async {
    await channel.invokeMethod<bool>('refreshCalendar');
  }

  /// Zustand für Fehlerberichte. Enthält keine Tag-UIDs und keinen Code-Hash.
  Future<Map<String, String>> getDiagnostics() async {
    final map =
        await channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
    return (map ?? const {})
        .map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}
