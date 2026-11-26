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

  /// Welche Tabelle und Spalte ein Verzeichnis tatsächlich benutzt.
  ///
  /// Nur was hier steht, kann gezählt werden – und nur was zählbar ist, darf
  /// die Oberfläche zum Löschen anbieten.
  static const Map<String, List<List<String>>> usageSources = {
    Catalogs.honeyState: [
      ['honey_buckets', 'state'],
      // Der Verlauf zählt mit: ein gelöschter Zustand machte alte Zeilen
      // unlesbar.
      ['honey_bucket_events', 'state'],
    ],
    Catalogs.honeyCrystallization: [
      ['honey_buckets', 'crystallization'],
    ],
    Catalogs.honeyVariety: [
      ['honey_buckets', 'variety'],
    ],
    Catalogs.stockCategory: [
      ['stock_items', 'category'],
    ],
    Catalogs.stockReason: [
      ['stock_movements', 'reason'],
    ],
    Catalogs.hiveActionType: [
      ['hive_actions', 'type'],
    ],
  };

  /// Wie oft jeder Eintrag eines Verzeichnisses in den Daten vorkommt.
  ///
  /// Das ist die Antwort auf die Frage „darf das weg?": was niemand benutzt,
  /// kann gelöscht werden; alles andere wird ausgeblendet, damit alte
  /// Datensätze lesbar bleiben. Die Zahl steht in der Oberfläche daneben,
  /// damit sichtbar ist, warum der Mülleimer fehlt.
  ///
  /// Eine Tabelle, die es noch nicht gibt, zählt als „nicht benutzt" – sonst
  /// stünde der Bildschirm auf einer frischen Installation still.
  Future<Map<String, int>> usageCounts(String catalog) async {
    final quellen = usageSources[catalog];
    if (quellen == null) return const {};

    final db = await _datenbank;
    final summe = <String, int>{};
    for (final quelle in quellen) {
      final tabelle = quelle[0];
      final spalte = quelle[1];
      try {
        final zeilen = await db.rawQuery(
          'SELECT $spalte AS k, COUNT(*) AS n FROM $tabelle '
          'WHERE $spalte IS NOT NULL GROUP BY $spalte',
        );
        for (final zeile in zeilen) {
          final k = zeile['k'] as String?;
          if (k == null) continue;
          summe[k] = (summe[k] ?? 0) + ((zeile['n'] as int?) ?? 0);
        }
      } catch (e) {
        FeedbackService.log('⚠️ $tabelle nicht zählbar: $e');
      }
    }
    return summe;
  }

  // ── Schreiben ───────────────────────────────────────────────────

  /// Einen Eintrag anlegen oder ändern. Der Schlüssel bleibt, wie er ist.
  Future<void> save(CatalogEntry eintrag) async {
    final db = await _datenbank;
    await db.insert('catalog_entries', eintrag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _reload();
  }

  /// Einen eigenen Eintrag anlegen.
  ///
  /// Der Schlüssel wird aus der Beschriftung gebildet, wenn keiner mitkommt.
  /// Bei den Honigsorten kommt einer mit: dort ist der Schlüssel das Kürzel,
  /// das auf dem Eimer steht. Einmal angelegt, bleibt er – umbenennen ändert
  /// nur die Beschriftung.
  Future<CatalogEntry> add(
    String catalog, {
    required String label,
    String? key,
    String? direction,
    int? color,
    String? marks,
    bool needsAttention = false,
  }) async {
    final belegt = entries(catalog).map((e) => e.key).toSet();
    final schluessel = freeKey(
      key == null ? keyFromLabel(label) : keyAsGiven(key),
      belegt,
    );
    var hoechste = -1;
    for (final e in entries(catalog)) {
      if (e.sortOrder > hoechste) hoechste = e.sortOrder;
    }

    final eintrag = CatalogEntry(
      catalog: catalog,
      key: schluessel,
      label: label,
      sortOrder: hoechste + 1,
      color: color,
      marks: marks,
      needsAttention: needsAttention,
      direction: direction,
    );
    await save(eintrag);
    return eintrag;
  }

  /// Ein mitgegebener Schlüssel bleibt so geschrieben, wie er kommt.
  ///
  /// Bei den Honigsorten ist er das Kürzel auf dem Eimer, und dort gilt
  /// Großschreibung: aus `LZ` darf nicht `lz` werden, sonst stünde auf dem
  /// nächsten Eimer `lz-001` neben `SO-042`. Entfernt wird nur, was in Daten
  /// und Code störte.
  @visibleForTesting
  static String keyAsGiven(String key) {
    final sauber = key.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    return sauber.isEmpty ? 'eigener' : sauber;
  }

  /// Aus einer Beschriftung einen Schlüssel machen: klein, ohne Umlaute,
  /// ohne Zeichen, die in SQL oder im Code stören.
  @visibleForTesting
  static String keyFromLabel(String label) {
    const ersatz = {
      'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss',
      'Ä': 'ae', 'Ö': 'oe', 'Ü': 'ue',
    };
    var text = label.trim().toLowerCase();
    ersatz.forEach((von, nach) => text = text.replaceAll(von, nach));
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    text = text.replaceAll(RegExp(r'^_+|_+$'), '');
    return text.isEmpty ? 'eigener' : text;
  }

  /// Denselben Schlüssel zweimal darf es nicht geben – also durchzählen.
  @visibleForTesting
  static String freeKey(String basis, Set<String> belegt) {
    if (!belegt.contains(basis)) return basis;
    for (var i = 2; i < 100; i++) {
      if (!belegt.contains('${basis}_$i')) return '${basis}_$i';
    }
    return '${basis}_${DateTime.now().millisecondsSinceEpoch}';
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

  /// Einen selbst angelegten, unbenutzten Eintrag löschen.
  ///
  /// Zwei Dinge bleiben: Werkseinträge, denn der Code verweist auf ihre
  /// Schlüssel, und alles, was in den Daten vorkommt – ein gelöschter Eintrag
  /// hinterließe dort den nackten Schlüssel. Wer so etwas nicht mehr sehen
  /// will, blendet es aus. Diese Regel steht hier und nicht nur in der
  /// Oberfläche, damit sie nicht an einem Knopf hängt.
  Future<bool> remove(String catalog, String key) async {
    final vorhanden = entry(catalog, key);
    if (vorhanden == null || vorhanden.builtIn) return false;
    final benutzt = (await usageCounts(catalog))[key] ?? 0;
    if (benutzt > 0) return false;
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
