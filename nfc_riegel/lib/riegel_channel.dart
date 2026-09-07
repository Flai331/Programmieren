import 'package:feedback/feedback.dart';
import 'package:flutter/services.dart';

import 'lock_status.dart';
import 'screen_time.dart';

/// Einzige Stelle, an der Dart mit der nativen Seite spricht.
///
/// Jede aendernde Aktion schreibt eine Zeile ins Protokoll. Genau hier, weil
/// hier alles vorbeikommt — in den einzelnen Schirmen verstreut wuerde die
/// naechste neue Aktion es wieder vergessen.
///
/// **Was nie ins Protokoll darf:** Chip-Kennungen, der Notfall-Code, Termin-
/// titel und Nutzungszeiten. Ein Fehlerbericht landet in einer Notion-Datenbank;
/// eine Chip-Kennung darin waere ein Zweitschluessel zum Schloss.
class RiegelChannel {
  const RiegelChannel([this.channel = const MethodChannel(_name)]);

  static const _name = 'com.klaas.nfc_riegel/riegel';

  final MethodChannel channel;

  Future<LockStatus> getState() async {
    final map = await channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    return LockStatus.fromMap(map ?? const {});
  }

  Future<String> addProfile(String name) async {
    FeedbackService.log('Profil angelegt: $name');
    return await channel.invokeMethod<String>('addProfile', {'name': name}) ??
        '';
  }

  /// Startet eine Zeitsperre ohne Chip. Liefert den nativen Ausgang als Text,
  /// z.B. `STARTED`, `EXTENDED`, `ALREADY_RUNNING`, `UNTIL_IN_PAST`.
  Future<String> startLock(String profileId) async {
    final outcome =
        await channel.invokeMethod<String>('startLock', {
          'profileId': profileId,
        }) ??
        'NO_PROFILE';
    FeedbackService.log('Sperre ohne Chip gestartet: $outcome');
    return outcome;
  }

  Future<bool> updateProfile(ProfileInfo profile) async {
    // Rufnummern gehoeren nicht ins Protokoll — es landet in einer
    // Notion-Datenbank. Die Anzahl beantwortet dieselbe Frage.
    FeedbackService.log(
      'Profil gespeichert: ${profile.name}, '
      '${profile.blockedPackages.length} Apps, '
      'Modus ${modeToNative(profile.mode)}, '
      'Atempause ${profile.pauseEnabled ? "an" : "aus"}, '
      'Freigabe ${profile.timedRelease ? "an" : "aus"}, '
      'Ruhe ${profile.quietEnabled ? "an" : "aus"} '
      '(${profile.quietNumbers.length} Nummern, '
      '${profile.quietSchedules.length} Zeitfenster)',
    );
    return await channel.invokeMethod<bool>('updateProfile', {
          'id': profile.id,
          'name': profile.name,
          'blockedPackages': profile.blockedPackages,
          'defaultMode': modeToNative(profile.mode),
          'durationMinutes': profile.durationMinutes,
          'untilAt': profile.untilAt?.millisecondsSinceEpoch,
          'pinCalendarEnd': profile.pinCalendarEnd,
          'timedRelease': profile.timedRelease,
          'pauseEnabled': profile.pauseEnabled,
          'pauseStepMinutes': profile.pauseStepMinutes,
          'pauseBaseSeconds': profile.pauseBaseSeconds,
          'pauseResetMinutes': profile.pauseResetMinutes,
          'quietEnabled': profile.quietEnabled,
          'quietScope': scopeToNative(profile.quietScope),
          'quietNumbers': profile.quietNumbers,
          'quietAfterEventMinutes': profile.quietAfterEventMinutes,
          'quietWhileLocked': profile.quietWhileLocked,
          'quietSchedules': profile.quietSchedules
              .map((plan) => plan.toMap())
              .toList(),
        }) ??
        false;
  }

  Future<bool> deleteProfile(String id) async {
    FeedbackService.log('Profil gelöscht');
    return await channel.invokeMethod<bool>('deleteProfile', {'id': id}) ??
        false;
  }

  /// Die Kennung des Chips bleibt draußen — sie ist der Schlüssel selbst.
  Future<bool> deleteTag(String uid) async {
    FeedbackService.log('Chip gelöscht');
    return await channel.invokeMethod<bool>('deleteTag', {'uid': uid}) ?? false;
  }

  /// Protokolliert wird, **dass** ein Code erzeugt wurde — nie welcher.
  Future<String?> generateCode() async {
    FeedbackService.log('Notfall-Code erzeugt');
    return channel.invokeMethod<String>('generateCode');
  }

  Future<void> startTagEnrollment({
    required String label,
    required String profileId,
  }) {
    FeedbackService.log('Chip anlernen gestartet: $label');
    return channel.invokeMethod<void>('startTagEnrollment', {
      'label': label,
      'profileId': profileId,
    });
  }

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() {
    FeedbackService.log('Bedienungshilfe-Einstellungen geöffnet');
    return channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() {
    FeedbackService.log('Geräteadministrator angefragt');
    return channel.invokeMethod<void>('requestAdmin');
  }

  /// Gibt das Administratorrecht zurueck, damit sich die App deinstallieren
  /// laesst. Liefert false, wenn gerade etwas sperrt.
  Future<bool> releaseAdmin() async {
    final ok = await channel.invokeMethod<bool>('releaseAdmin') ?? false;
    FeedbackService.log('Adminrecht abgegeben: ${ok ? "ja" : "abgelehnt"}');
    return ok;
  }

  Future<bool> usageAccessGranted() async =>
      await channel.invokeMethod<bool>('usageAccessGranted') ?? false;

  Future<void> openUsageAccessSettings() {
    FeedbackService.log('Nutzungsdaten-Einstellungen geöffnet');
    return channel.invokeMethod<void>('openUsageAccessSettings');
  }

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

  Future<bool> requestCalendarPermission() async {
    final ok =
        await channel.invokeMethod<bool>('requestCalendarPermission') ?? false;
    FeedbackService.log(
      'Kalenderfreigabe angefragt: ${ok ? "erteilt" : "offen"}',
    );
    return ok;
  }

  Future<void> setCalendarSettings({
    required bool enabled,
    required Map<String, CalendarRuleInfo> calendarRules,
    required String keywordMarker,
    String? keywordProfileId,
    Set<String> keywordCalendarIds = const {},
  }) async {
    // Zahlen statt Namen: Termintitel und Kalendernamen gehen niemanden etwas
    // an, die Anzahl der Regeln beantwortet die Frage genauso.
    FeedbackService.log(
      'Kalender gespeichert: ${enabled ? "an" : "aus"}, '
      '${calendarRules.length} Regeln, '
      'Stichwortregel ${keywordProfileId == null ? "aus" : "an"}',
    );
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

  /// Kontakte für die Auswahl. Ohne Berechtigung kommt eine leere Liste.
  Future<List<ContactInfo>> contacts() async {
    final raw = await channel.invokeMethod<List<dynamic>>('contacts');
    return (raw ?? [])
        .map((e) => ContactInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<bool> contactsGranted() async =>
      await channel.invokeMethod<bool>('contactsGranted') ?? false;

  Future<bool> requestContacts() async =>
      await channel.invokeMethod<bool>('requestContacts') ?? false;

  /// Ob das System die Anruffilter-Rolle überhaupt vergibt — erst ab Android 10.
  Future<bool> callScreeningAvailable() async =>
      await channel.invokeMethod<bool>('callScreeningAvailable') ?? false;

  Future<bool> callScreeningHeld() async =>
      await channel.invokeMethod<bool>('callScreeningHeld') ?? false;

  /// Öffnet den Systemdialog für die Anruffilter-Rolle.
  Future<bool> requestCallScreening() async {
    FeedbackService.log('Anruffilter angefragt');
    return await channel.invokeMethod<bool>('requestCallScreening') ?? false;
  }

  Future<bool> dndGranted() async =>
      await channel.invokeMethod<bool>('dndGranted') ?? false;

  Future<void> openDndSettings() {
    FeedbackService.log('Bitte-nicht-stören-Einstellungen geöffnet');
    return channel.invokeMethod<void>('openDndSettings');
  }

  /// Zustand für Fehlerberichte. Enthält keine Tag-UIDs und keinen Code-Hash.
  Future<Map<String, String>> getDiagnostics() async {
    final map = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getDiagnostics',
    );
    return (map ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
