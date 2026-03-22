import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'baking_models.dart';

// ═══════════════════════════════════════════════════════════════
//  RECIPE STORAGE — Lokal speichern via shared_preferences
// ═══════════════════════════════════════════════════════════════

class RecipeStorage {
  static const _key = 'baking_recipes';

  static Future<List<BakingRecipe>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BakingRecipe.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    } catch (_) {
      // Korrupte Daten → verwerfen und leere Liste zurückgeben
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> save(BakingRecipe recipe) async {
    final recipes = await loadAll();
    final idx = recipes.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      recipes[idx] = recipe;
    } else {
      recipes.add(recipe);
    }
    await _persist(recipes);
  }

  static Future<void> delete(String id) async {
    final recipes = await loadAll();
    recipes.removeWhere((r) => r.id == id);
    await _persist(recipes);
  }

  static Future<void> _persist(List<BakingRecipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(recipes.map((r) => r.toJson()).toList()));
  }
}
