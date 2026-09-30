import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
//  PLANER STORAGE — gespeicherte Berechnungen
// ═══════════════════════════════════════════════════════════════

class SavedPlan {
  final String id;
  final DateTime savedAt;

  // Eingaben
  final double temp;
  final DateTime bakingTime;

  // Ergebnis
  final String ratio;
  final int anstellgut;
  final int wasser;
  final int mehl;
  final int gesamt;
  final int forRecipe;
  final int leftover;
  final int unusedStarter;
  final double estTime;
  final int wasserTempC;

  // Termine
  final DateTime dFeed;
  final DateTime dHalf;
  final DateTime dPeak;

  // Optional
  final String? note;

  SavedPlan({
    required this.id,
    required this.savedAt,
    required this.temp,
    required this.bakingTime,
    required this.ratio,
    required this.anstellgut,
    required this.wasser,
    required this.mehl,
    required this.gesamt,
    required this.forRecipe,
    required this.leftover,
    required this.unusedStarter,
    required this.estTime,
    this.wasserTempC = 0,
    required this.dFeed,
    required this.dHalf,
    required this.dPeak,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'temp': temp,
        'bakingTime': bakingTime.toIso8601String(),
        'ratio': ratio,
        'anstellgut': anstellgut,
        'wasser': wasser,
        'mehl': mehl,
        'gesamt': gesamt,
        'forRecipe': forRecipe,
        'leftover': leftover,
        'unusedStarter': unusedStarter,
        'estTime': estTime,
        'wasserTempC': wasserTempC,
        'dFeed': dFeed.toIso8601String(),
        'dHalf': dHalf.toIso8601String(),
        'dPeak': dPeak.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory SavedPlan.fromJson(Map<String, dynamic> j) => SavedPlan(
        id: j['id'] as String,
        savedAt: DateTime.parse(j['savedAt'] as String),
        temp: (j['temp'] as num).toDouble(),
        bakingTime: DateTime.parse(j['bakingTime'] as String),
        ratio: j['ratio'] as String,
        anstellgut: j['anstellgut'] as int,
        wasser: j['wasser'] as int,
        mehl: j['mehl'] as int,
        gesamt: j['gesamt'] as int,
        forRecipe: j['forRecipe'] as int,
        leftover: j['leftover'] as int,
        unusedStarter: (j['unusedStarter'] as num? ?? 0).toInt(),
        estTime: (j['estTime'] as num).toDouble(),
        wasserTempC: (j['wasserTempC'] as num? ?? 0).toInt(),
        dFeed: DateTime.parse(j['dFeed'] as String),
        dHalf: DateTime.parse(j['dHalf'] as String),
        dPeak: DateTime.parse(j['dPeak'] as String),
        note: j['note'] as String?,
      );
}

class PlanerStorage {
  static const _key = 'saved_plans';

  static Future<List<SavedPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) {
          try {
            return SavedPlan.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedPlan>()
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  static Future<void> save(SavedPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await loadAll();
    plans.removeWhere((p) => p.id == plan.id);
    plans.insert(0, plan);
    // Maximal 50 gespeicherte Pläne
    final trimmed = plans.take(50).toList();
    await prefs.setStringList(
        _key, trimmed.map((p) => jsonEncode(p.toJson())).toList());
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await loadAll();
    plans.removeWhere((p) => p.id == id);
    await prefs.setStringList(
        _key, plans.map((p) => jsonEncode(p.toJson())).toList());
  }
}
