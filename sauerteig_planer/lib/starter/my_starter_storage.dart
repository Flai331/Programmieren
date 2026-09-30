// ═══════════════════════════════════════════════════════════════
//  MEINE STARTER — Storage
//  lib/starter/my_starter_storage.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_starter_models.dart';

class MyStarterStorage {
  static const _key = 'my_starters';

  static Future<List<MyStarter>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MyStarter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<MyStarter> starters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(starters.map((s) => s.toJson()).toList()));
  }

  static Future<void> save(MyStarter starter) async {
    final all = await loadAll();
    final idx = all.indexWhere((s) => s.id == starter.id);
    if (idx >= 0) {
      all[idx] = starter;
    } else {
      all.add(starter);
    }
    await _saveAll(all);
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((s) => s.id == id);
    await _saveAll(all);
  }
}
