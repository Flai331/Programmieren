import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'starter_models.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER STORAGE
// ═══════════════════════════════════════════════════════════════

class StarterStorage {
  static const _journeyKey = 'starter_journey';
  static const _notifKey = 'starter_notif_enabled';
  static const _notifHourKey = 'starter_notif_hour';
  static const _notifMinuteKey = 'starter_notif_minute';

  static Future<StarterJourney?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_journeyKey);
      if (raw == null) return null;
      return StarterJourney.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(StarterJourney journey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_journeyKey, jsonEncode(journey.toJson()));
  }

  static Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_journeyKey);
  }

  static Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifKey) ?? false;
  }

  static Future<void> setNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, value);
  }

  /// Liefert die gespeicherte Benachrichtigungszeit. Standard: 8:00 Uhr.
  static Future<({int hour, int minute})> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_notifHourKey) ?? 8,
      minute: prefs.getInt(_notifMinuteKey) ?? 0,
    );
  }

  static Future<void> setNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifHourKey, hour);
    await prefs.setInt(_notifMinuteKey, minute);
  }
}
