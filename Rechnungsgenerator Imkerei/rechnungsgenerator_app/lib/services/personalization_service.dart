import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/feedback_service.dart';
import 'database_service.dart';

/// Die anpassbaren Verzeichnisse und einstellbaren Zahlen.
///
/// Lädt **einmal beim Start** und antwortet danach synchron. Das ist die
/// entscheidende Eigenschaft: `HoneyStates.labelOf` und ihresgleichen werden
/// aus `build()`-Methoden gerufen, die nicht warten können. Geladen wird
/// deshalb in [load], und von dort aus in die Modellklassen geschoben.
///
/// Die Werkseinstellung bleibt im Code ([CatalogDefaults]). Sie wird bei jedem
/// Start nachgesät – mit `INSERT OR IGNORE`, also ohne deine Änderungen
/// anzutasten. Das hat zwei angenehme Folgen: „Zurücksetzen" kostet nichts,
/// und ein Verzeichnis, das eine neue Fassung der App dazubekommt, erscheint
/// von selbst.
class PersonalizationService {
  static final PersonalizationService _instance =
      PersonalizationService._internal();
  PersonalizationService._internal();
  factory PersonalizationService() => _instance;

  final DatabaseService _db = DatabaseService();

  /// Nur für Tests: eine Datenbank vorgeben, statt die der App zu öffnen.
  @visibleForTesting
  Database? databaseOverride;

  Future<Database> get _datenbank async =>
      databaseOverride ?? await _db.database;

  /// Alle Einträge je Verzeichnis, einschließlich der ausgeblendeten.
  final Map<String, List<CatalogEntry>> _verzeichnisse = {};

  /// Die einstellbaren Zahlen, nach Namen.
  final Map<String, double> _zahlen = {};

  bool _geladen = false;
  bool get isLoaded => _geladen;

  // ── Laden ───────────────────────────────────────────────────────

  /// Säen, lesen, in die Modelle schieben. Beim Start aufzurufen.
  ///
  /// Scheitert das – eine Datenbank, die es noch nicht gibt, ein Schema, das
  /// nicht passt –, läuft die App mit der Werkseinstellung weiter. Ein
  /// unlesbares Verzeichnis darf den Start nicht verhindern.
  Future<void> load() async {
    try {
      final db = await _datenbank;
      await _seed(db);
      await _read(db);
      _apply();
      _geladen = true;
      FeedbackService.log('⚙️ Verzeichnisse geladen '
          '(${_verzeichnisse.values.fold<int>(0, (s, l) => s + l.length)} '
          'Einträge)');
    } catch (e) {
      _useDefaults();
      FeedbackService.log('⚠️ Verzeichnisse nicht lesbar, '
          'Werkseinstellung gilt: $e');
    }
  }

  /// Fehlende Werkseinträge ergänzen, Bestehendes unberührt lassen.
  Future<void> _seed(Database db) async {
    final batch = db.batch();
    for (final eintrag in CatalogDefaults.all()) {
      batch.insert('catalog_entries', eintrag.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _read(Database db) async {
    _verzeichnisse.clear();
    final reihen = await db.query('catalog_entries', orderBy: 'sort_order');
    for (final reihe in reihen) {
      final eintrag = CatalogEntry.fromMap(reihe);
      _verzeichnisse.putIfAbsent(eintrag.catalog, () => []).add(eintrag);
    }

    _zahlen.clear();
    final werte = await db.query('app_settings');
    for (final reihe in werte) {
      final zahl = double.tryParse((reihe['value'] as String?) ?? '');
      if (zahl != null) _zahlen[reihe['name'] as String] = zahl;
    }
  }

  /// Das Geladene in die Modellklassen schieben.
  void _apply() {
    HoneyStates.apply(entries(Catalogs.honeyState));
    HoneyCrystallization.catalog
        .apply(entries(Catalogs.honeyCrystallization));
    HoneyVarieties.catalog.apply(entries(Catalogs.honeyVariety));
    StockCategories.catalog.apply(entries(Catalogs.stockCategory));
    StockReasons.catalog.apply(entries(Catalogs.stockReason));
    HiveActionTypes.catalog.apply(entries(Catalogs.hiveActionType));
  }

  void _useDefaults() {
    HoneyStates.useDefaults();
    HoneyCrystallization.catalog.useDefaults();
    HoneyVarieties.catalog.useDefaults();
    StockCategories.catalog.useDefaults();
    StockReasons.catalog.useDefaults();
    HiveActionTypes.catalog.useDefaults();
  }

  /// Nur für Tests: den Dienst in den Zustand „nie geladen" bringen.
  ///
  /// Statische Verzeichnisse sind über Tests hinweg dieselben; ohne das
  /// trüge ein Test die Einstellungen des vorigen mit sich.
  void resetForTests() {
    _verzeichnisse.clear();
    _zahlen.clear();
    _geladen = false;
    _useDefaults();
  }

  // ── Lesen ───────────────────────────────────────────────────────

  /// Die Einträge eines Verzeichnisses, nach Reihenfolge sortiert.
  ///
  /// Ohne geladene Daten die Werkseinstellung – damit der Bildschirm
  /// „Verzeichnisse" auch dann etwas zeigt.
  List<CatalogEntry> entries(String catalog, {bool withArchived = true}) {
    final geladen = _verzeichnisse[catalog];
    final liste = (geladen == null || geladen.isEmpty)
        ? CatalogDefaults.of(catalog)
        : geladen;
    final sortiert = [...liste]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return withArchived
        ? sortiert
        : sortiert.where((e) => !e.archived).toList();
  }

  CatalogEntry? entry(String catalog, String key) {
    for (final e in entries(catalog)) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// Eine einstellbare Zahl, mit Vorgabe.
  double number(String name, double fallback) => _zahlen[name] ?? fallback;

  // ── Schreiben ───────────────────────────────────────────────────

  /// Einen Eintrag anlegen oder ändern. Der Schlüssel bleibt, wie er ist.
  Future<void> save(CatalogEntry eintrag) async {
    final db = await _datenbank;
    await db.insert('catalog_entries', eintrag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _reload();
  }

  /// Die Reihenfolge eines Verzeichnisses neu setzen.
  ///
  /// Bei den Honig-Zuständen ist das die Kette – deshalb zählt hier wirklich
  /// die Reihenfolge und nicht bloß die Ansicht.
  Future<void> reorder(String catalog, List<String> keysInOrder) async {
    final db = await _datenbank;
    final batch = db.batch();
    for (var i = 0; i < keysInOrder.length; i++) {
      batch.update('catalog_entries', {'sort_order': i},
          where: 'catalog = ? AND entry_key = ?',
          whereArgs: [catalog, keysInOrder[i]]);
    }
    await batch.commit(noResult: true);
    await _reload();
  }

  /// Einen selbst angelegten Eintrag löschen.
  ///
  /// Werkseinträge bleiben: der Code verweist auf ihre Schlüssel. Wer sie
  /// nicht mehr sehen will, blendet sie aus.
  Future<bool> remove(String catalog, String key) async {
    final vorhanden = entry(catalog, key);
    if (vorhanden == null || vorhanden.builtIn) return false;
    final db = await _datenbank;
    await db.delete('catalog_entries',
        where: 'catalog = ? AND entry_key = ?', whereArgs: [catalog, key]);
    await _reload();
    return true;
  }

  /// Ein Verzeichnis auf die Werkseinstellung zurücksetzen.
  ///
  /// Selbst angelegte Einträge verschwinden dabei. Was alte Daten davon
  /// benutzen, zeigt danach den nackten Schlüssel – deshalb fragt die
  /// Oberfläche vorher nach.
  Future<void> resetToDefaults(String catalog) async {
    final db = await _datenbank;
    await db
        .delete('catalog_entries', where: 'catalog = ?', whereArgs: [catalog]);
    final batch = db.batch();
    for (final eintrag in CatalogDefaults.of(catalog)) {
      batch.insert('catalog_entries', eintrag.toMap());
    }
    await batch.commit(noResult: true);
    await _reload();
  }

  Future<void> setNumber(String name, double value) async {
    final db = await _datenbank;
    await db.insert('app_settings', {'name': name, 'value': '$value'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _zahlen[name] = value;
  }

  Future<void> _reload() async {
    final db = await _datenbank;
    await _read(db);
    _apply();
  }
}

/// Die Namen der einstellbaren Zahlen.
///
/// Als Konstanten, weil sie in der Datenbank stehen: ein Tippfehler im Namen
/// wäre eine stille Rückkehr zur Vorgabe.
class AppNumbers {
  /// Stunden im Wärmeschrank beim ersten Mal.
  static const String warmerFirstHours = 'waermeschrank_erst_h';

  /// Stunden, wenn der Eimer schon einmal drin war.
  static const String warmerRepeatHours = 'waermeschrank_wieder_h';
}
