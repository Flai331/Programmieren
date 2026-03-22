import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'starter_models.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER STORAGE
// ═══════════════════════════════════════════════════════════════

class StarterStorage {
  static const _journeyKey = 'starter_journey';
  static const _notifKey = 'starter_notif_enabled';

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
}
