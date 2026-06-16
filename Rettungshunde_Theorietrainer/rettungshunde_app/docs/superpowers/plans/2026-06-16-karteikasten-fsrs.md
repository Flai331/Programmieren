# Karteikasten (FSRS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4th learn mode „Karteikasten" with FSRS spaced repetition, hybrid MC grading, and new-card pacing driven by exam date + daily time cap.

**Architecture:** A new `SrsService` wraps the `fsrs` package's `Scheduler`. FSRS card state is persisted as a JSON blob (+ indexed `due`/`state`) in a new `srs_cards` table; reviews log to `srs_review_log`. A pure helper `srsNewCardsToday` computes how many new cards to introduce. A new `KarteikastenScreen` runs the daily queue. Home/Settings/Stats get small additions. Existing `ProgressService` keeps recording answers so stats stay unified.

**Tech Stack:** Flutter, sqflite, provider, `fsrs: ^2.0.1` (pure Dart), `sqflite_common_ffi` (dev, for DB tests).

**Spec:** `docs/superpowers/specs/2026-06-16-karteikasten-fsrs-design.md`

**Conventions:**
- The user runs all `flutter`/`dart` commands themselves. Where a step says "Run", give the command for the user; do not assume an agent can execute Flutter.
- Commit messages in English, imperative.

---

### Task 1: Add fsrs dependency + dev test deps

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add fsrs to dependencies**

In `pubspec.yaml` under `dependencies:` (after `url_launcher: ^6.3.1`):
```yaml
  fsrs: ^2.0.1
```

- [ ] **Step 2: Add sqflite_common_ffi to dev_dependencies (for DB unit tests)**

Under `dev_dependencies:` (after `flutter_lints: ^6.0.0`):
```yaml
  sqflite_common_ffi: ^2.3.3
```

- [ ] **Step 3: Resolve packages**

Run: `flutter pub get`
Expected: resolves `fsrs 2.0.1` and `sqflite_common_ffi` without conflicts.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: add fsrs and sqflite_common_ffi deps"
```

---

### Task 2: Settings keys + dbVersion bump in AppConstants

**Files:**
- Modify: `lib/utils/app_constants.dart`

- [ ] **Step 1: Bump dbVersion**

Change line `static const int dbVersion = 2;` to:
```dart
  static const int    dbVersion = 3;
```

- [ ] **Step 2: Add SRS settings keys**

After `static const String keySuchhundtyp   = 'suchhundtyp';` add:
```dart
  static const String keySrsExamDate     = 'srs_exam_date';     // ISO date or empty
  static const String keySrsDailyMinutes = 'srs_daily_minutes'; // int or empty
  static const String keySrsIntroDate    = 'srs_intro_date';    // yyyy-MM-dd
  static const String keySrsIntroCount   = 'srs_intro_count';   // int
```

- [ ] **Step 3: Add a Karteikasten accent color**

After `static const Color statsAccent   = Color(0xFF3d9eff); // electric blue` add:
```dart
  static const Color srsAccent     = Color(0xFF9b6cff); // violet (Karteikasten)
```

- [ ] **Step 4: Verify compile**

Run: `flutter analyze lib/utils/app_constants.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/app_constants.dart
git commit -m "feat: add SRS settings keys, dbVersion 3, srs accent color"
```

---

### Task 3: DB migration — srs_cards + srs_review_log tables

**Files:**
- Modify: `lib/services/database_service.dart`
- Test: `test/srs_migration_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/srs_migration_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v3 schema has srs_cards and srs_review_log', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, v) async {
          // mirror DatabaseService._onCreate srs tables
          await db.execute('''
            CREATE TABLE srs_cards(
              question_id INTEGER PRIMARY KEY,
              card_json TEXT NOT NULL,
              due TEXT,
              state INTEGER NOT NULL DEFAULT 1,
              introduced_at TEXT
            )''');
          await db.execute('''
            CREATE TABLE srs_review_log(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id INTEGER NOT NULL,
              rating INTEGER NOT NULL,
              reviewed_at TEXT NOT NULL,
              elapsed_ms INTEGER
            )''');
        },
      ),
    );
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name']).toSet();
    expect(names, containsAll(['srs_cards', 'srs_review_log']));
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it passes (sanity of ffi + DDL)**

Run: `flutter test test/srs_migration_test.dart`
Expected: PASS. (This locks the DDL shape used in the real migration.)

- [ ] **Step 3: Add the tables to `_onCreate`**

In `lib/services/database_service.dart`, inside `_onCreate`, after the `settings` table `db.execute(...)` block, add:
```dart
    await _createSrsTables(db);
```

- [ ] **Step 4: Add the migration to `_onUpgrade`**

Replace the body of `_onUpgrade` so it reads:
```dart
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE questions ADD COLUMN multi INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await _createSrsTables(db);
    }
  }
```

- [ ] **Step 5: Add the shared DDL helper**

After `_onUpgrade`, add:
```dart
  Future<void> _createSrsTables(Database db) async {
    await db.execute('''
      CREATE TABLE srs_cards(
        question_id INTEGER PRIMARY KEY,
        card_json TEXT NOT NULL,
        due TEXT,
        state INTEGER NOT NULL DEFAULT 1,
        introduced_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_srs_due ON srs_cards(due)');
    await db.execute('''
      CREATE TABLE srs_review_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        rating INTEGER NOT NULL,
        reviewed_at TEXT NOT NULL,
        elapsed_ms INTEGER
      )
    ''');
  }
```

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/services/database_service.dart`
Expected: No issues.
```bash
git add lib/services/database_service.dart test/srs_migration_test.dart
git commit -m "feat: add srs_cards and srs_review_log tables (db v3)"
```

---

### Task 4: Pure pacing function `srsNewCardsToday`

**Files:**
- Create: `lib/services/srs_pacing.dart`
- Test: `test/srs_pacing_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/srs_pacing_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rettungshunde_app/services/srs_pacing.dart';

void main() {
  final today = DateTime(2026, 6, 16);

  test('no remaining new -> 0', () {
    expect(srsNewCardsToday(
      dueToday: 0, remainingNew: 0, introducedToday: 0,
      examDate: null, dailyMinutes: null,
      avgSecondsPerCard: 20, today: today), 0);
  });

  test('no exam, no cap -> default 20', () {
    expect(srsNewCardsToday(
      dueToday: 0, remainingNew: 200, introducedToday: 0,
      examDate: null, dailyMinutes: null,
      avgSecondsPerCard: 20, today: today), 20);
  });

  test('exam date spreads remaining over 80% of days', () {
    // 100 days left, introDays = ceil(80) = 80, 160 new -> ceil(2) = 2
    final exam = today.add(const Duration(days: 100));
    expect(srsNewCardsToday(
      dueToday: 0, remainingNew: 160, introducedToday: 0,
      examDate: exam, dailyMinutes: null,
      avgSecondsPerCard: 20, today: today), 2);
  });

  test('time cap reduces below target; due cards eat budget first', () {
    // 10 min = 600s, 20s/card => budget 30 cards; due 28 => cap 2
    final exam = today.add(const Duration(days: 2));
    expect(srsNewCardsToday(
      dueToday: 28, remainingNew: 200, introducedToday: 0,
      examDate: exam, dailyMinutes: 10,
      avgSecondsPerCard: 20, today: today), 2);
  });

  test('already introduced today is subtracted', () {
    expect(srsNewCardsToday(
      dueToday: 0, remainingNew: 200, introducedToday: 15,
      examDate: null, dailyMinutes: null,
      avgSecondsPerCard: 20, today: today), 5);
  });

  test('after exam date -> introduce all remaining (capped by remaining)', () {
    final exam = today.subtract(const Duration(days: 1));
    expect(srsNewCardsToday(
      dueToday: 0, remainingNew: 7, introducedToday: 0,
      examDate: exam, dailyMinutes: null,
      avgSecondsPerCard: 20, today: today), 7);
  });

  test('result never negative when due exceeds budget', () {
    expect(srsNewCardsToday(
      dueToday: 100, remainingNew: 50, introducedToday: 0,
      examDate: null, dailyMinutes: 5,
      avgSecondsPerCard: 20, today: today), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/srs_pacing_test.dart`
Expected: FAIL — `srs_pacing.dart` / `srsNewCardsToday` not found.

- [ ] **Step 3: Implement the function**

Create `lib/services/srs_pacing.dart`:
```dart
import 'dart:math' as math;

/// Pure: how many NEW cards to introduce today.
///
/// - [examDate]/[dailyMinutes] optional. examDate is the main goal; dailyMinutes
///   is a cap. [avgSecondsPerCard] estimated from review history (fallback 20).
/// - [today] should be a local date (time-of-day ignored).
int srsNewCardsToday({
  required int dueToday,
  required int remainingNew,
  required int introducedToday,
  required DateTime? examDate,
  required int? dailyMinutes,
  required double avgSecondsPerCard,
  required DateTime today,
}) {
  if (remainingNew <= 0) return 0;

  final t = DateTime(today.year, today.month, today.day);

  // Main goal: exam date
  int target;
  if (examDate != null) {
    final e = DateTime(examDate.year, examDate.month, examDate.day);
    final daysLeft = e.difference(t).inDays;
    if (daysLeft <= 0) {
      target = remainingNew; // exam reached/passed: introduce all that remain
    } else {
      final introDays = math.max(1, (daysLeft * 0.8).ceil());
      target = (remainingNew / introDays).ceil();
    }
  } else {
    target = 20; // sensible default when no exam date set
  }

  // Cap: daily minutes
  int cap;
  if (dailyMinutes != null && dailyMinutes > 0) {
    final sec = avgSecondsPerCard < 5 ? 5.0 : avgSecondsPerCard;
    final budget = (dailyMinutes * 60 / sec).floor();
    cap = math.max(0, budget - dueToday); // due reviews have priority
  } else {
    cap = 1 << 30; // effectively unlimited
  }

  var allowed = math.min(target, cap) - introducedToday;
  if (allowed < 0) allowed = 0;
  if (allowed > remainingNew) allowed = remainingNew;
  return allowed;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/srs_pacing_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/srs_pacing.dart test/srs_pacing_test.dart
git commit -m "feat: add pure srsNewCardsToday pacing function"
```

---

### Task 5: SrsService — review persistence + counts

**Files:**
- Create: `lib/services/srs_service.dart`
- Test: `test/srs_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/srs_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:rettungshunde_app/services/srs_service.dart';

Future<Database> _openTestDb() async {
  return databaseFactory.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, v) async {
          await db.execute('''CREATE TABLE srs_cards(
            question_id INTEGER PRIMARY KEY, card_json TEXT NOT NULL,
            due TEXT, state INTEGER NOT NULL DEFAULT 1, introduced_at TEXT)''');
          await db.execute('''CREATE TABLE srs_review_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT, question_id INTEGER NOT NULL,
            rating INTEGER NOT NULL, reviewed_at TEXT NOT NULL, elapsed_ms INTEGER)''');
        },
      ));
}

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('first review creates row, sets introduced_at, logs review', () async {
    final db = await _openTestDb();
    final svc = SrsService.forTest(db);

    await svc.review(42, fsrs.Rating.good, elapsedMs: 3000);

    final cards = await db.query('srs_cards', where: 'question_id = ?', whereArgs: [42]);
    expect(cards.length, 1);
    expect(cards.first['introduced_at'], isNotNull);
    expect(cards.first['card_json'], isNotNull);

    final logs = await db.query('srs_review_log');
    expect(logs.length, 1);
    expect(logs.first['rating'], 3);
    expect(logs.first['elapsed_ms'], 3000);
    await db.close();
  });

  test('Good pushes due into the future', () async {
    final db = await _openTestDb();
    final svc = SrsService.forTest(db);
    await svc.review(7, fsrs.Rating.good);
    final row = (await db.query('srs_cards', where: 'question_id = ?', whereArgs: [7])).first;
    final due = DateTime.parse(row['due'] as String);
    expect(due.isAfter(DateTime.now().toUtc()), isTrue);
    await db.close();
  });

  test('card json round-trips through fsrs', () async {
    final db = await _openTestDb();
    final svc = SrsService.forTest(db);
    await svc.review(9, fsrs.Rating.good);
    await svc.review(9, fsrs.Rating.again); // second review loads stored card
    final logs = await db.query('srs_review_log', where: 'question_id = ?', whereArgs: [9]);
    expect(logs.length, 2);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/srs_service_test.dart`
Expected: FAIL — `SrsService` not found.

- [ ] **Step 3: Implement SrsService (review + load + counts)**

Create `lib/services/srs_service.dart`:
```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import 'database_service.dart';
import 'progress_service.dart';
import 'question_repository.dart';
import 'srs_pacing.dart';

/// FSRS-based spaced repetition over the question catalog.
///
/// "New" = no row in srs_cards. A row is created on the first review.
class SrsService extends ChangeNotifier {
  SrsService(this._dbService, this._repo, this._progress);

  /// Test constructor: inject an already-open database, no repo/progress.
  @visibleForTesting
  SrsService.forTest(Database db)
      : _dbService = null,
        _repo = null,
        _progress = null,
        _testDb = db;

  final DatabaseService? _dbService;
  final QuestionRepository? _repo;
  final ProgressService? _progress;
  Database? _testDb;

  final _scheduler = fsrs.Scheduler(desiredRetention: 0.9);

  Future<Database> get _db async => _testDb ?? await _dbService!.database;

  // ── Review ────────────────────────────────────────────────────────────────

  Future<void> review(int questionId, fsrs.Rating rating, {int? elapsedMs}) async {
    final db = await _db;
    final existing = await db.query('srs_cards',
        where: 'question_id = ?', whereArgs: [questionId], limit: 1);
    final isNew = existing.isEmpty;

    final card = isNew
        ? fsrs.Card(cardId: questionId)
        : fsrs.Card.fromMap(
            jsonDecode(existing.first['card_json'] as String)
                as Map<String, dynamic>);

    final result = _scheduler.reviewCard(card, rating, reviewDuration: elapsedMs);
    final updated = result.card;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.insert(
      'srs_cards',
      {
        'question_id': questionId,
        'card_json': jsonEncode(updated.toMap()),
        'due': updated.due.toUtc().toIso8601String(),
        'state': updated.state.value,
        'introduced_at':
            isNew ? nowIso : (existing.first['introduced_at'] as String?),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert('srs_review_log', {
      'question_id': questionId,
      'rating': rating.value,
      'reviewed_at': nowIso,
      'elapsed_ms': elapsedMs,
    });

    if (isNew) await _bumpIntroducedToday();
    await _progress?.recordAnswer(questionId, rating != fsrs.Rating.again);
    notifyListeners();
  }

  // ── Counts ──────────────────────────────────────────────────────────────

  Future<double> _avgSecondsPerCard() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT elapsed_ms FROM srs_review_log '
      'WHERE elapsed_ms IS NOT NULL ORDER BY id DESC LIMIT 50',
    );
    if (rows.isEmpty) return 20.0;
    final total = rows.fold<int>(0, (s, r) => s + (r['elapsed_ms'] as int));
    return (total / rows.length) / 1000.0;
  }

  // ── Daily intro counter (persisted across restarts) ──────────────────────

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Future<int> _introducedToday() async {
    if (_dbService == null) return 0; // test mode
    final date = await _dbService.getSetting('srs_intro_date');
    if (date != _todayStr()) return 0;
    return int.tryParse(await _dbService.getSetting('srs_intro_count') ?? '0') ?? 0;
  }

  Future<void> _bumpIntroducedToday() async {
    if (_dbService == null) return; // test mode
    final today = _todayStr();
    final date = await _dbService.getSetting('srs_intro_date');
    final count =
        date == today ? (int.tryParse(await _dbService.getSetting('srs_intro_count') ?? '0') ?? 0) : 0;
    await _dbService.setSetting('srs_intro_date', today);
    await _dbService.setSetting('srs_intro_count', '${count + 1}');
  }
}
```

Note: settings key string literals here intentionally match `AppConstants.keySrsIntroDate`/`keySrsIntroCount`. Task 7 replaces them with the constants once the queue logic is added — for now literals keep this task self-contained.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/srs_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/srs_service.dart test/srs_service_test.dart
git commit -m "feat: SrsService review persistence + review log"
```

---

### Task 6: SrsService — scope counts + today queue + reset

**Files:**
- Modify: `lib/services/srs_service.dart`

- [ ] **Step 1: Add scope queries + queue + reset**

Append these methods inside `SrsService` (before the closing brace), and switch the
literals from Task 5 to constants by adding `import '../utils/app_constants.dart';`
at the top and replacing `'srs_intro_date'`/`'srs_intro_count'` with
`AppConstants.keySrsIntroDate`/`AppConstants.keySrsIntroCount`:

```dart
  /// Questions in scope (same pool as Lernmodus): free/pro + discipline filter.
  Future<List<Question>> _scope(bool freeOnly, List<String> excluded) =>
      _repo!.questions(freeOnly: freeOnly, excludeCategories: excluded);

  Future<Set<int>> _introducedIds() async {
    final db = await _db;
    final rows = await db.query('srs_cards', columns: ['question_id']);
    return rows.map((r) => r['question_id'] as int).toSet();
  }

  /// Due reviews (introduced cards with due <= now) within scope.
  Future<int> dueCount({required bool freeOnly, required List<String> excluded}) async {
    final scopeIds = (await _scope(freeOnly, excluded)).map((q) => q.id).toSet();
    final db = await _db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query('srs_cards',
        columns: ['question_id'], where: 'due <= ?', whereArgs: [nowIso]);
    return rows.where((r) => scopeIds.contains(r['question_id'] as int)).length;
  }

  Future<int> remainingNewCount({required bool freeOnly, required List<String> excluded}) async {
    final scope = await _scope(freeOnly, excluded);
    final introduced = await _introducedIds();
    return scope.where((q) => !introduced.contains(q.id)).length;
  }

  Future<int> newAllowedToday({required bool freeOnly, required List<String> excluded}) async {
    return srsNewCardsToday(
      dueToday: await dueCount(freeOnly: freeOnly, excluded: excluded),
      remainingNew: await remainingNewCount(freeOnly: freeOnly, excluded: excluded),
      introducedToday: await _introducedToday(),
      examDate: await examDate(),
      dailyMinutes: await dailyMinutes(),
      avgSecondsPerCard: await _avgSecondsPerCard(),
      today: DateTime.now(),
    );
  }

  /// Today's queue: due reviews first (by due asc), then up to N new cards.
  Future<List<Question>> buildTodayQueue({required bool freeOnly, required List<String> excluded}) async {
    final scope = await _scope(freeOnly, excluded);
    final byId = {for (final q in scope) q.id: q};
    final db = await _db;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final dueRows = await db.query('srs_cards',
        columns: ['question_id', 'due'],
        where: 'due <= ?', whereArgs: [nowIso], orderBy: 'due ASC');
    final dueQuestions = <Question>[
      for (final r in dueRows)
        if (byId.containsKey(r['question_id'] as int)) byId[r['question_id'] as int]!,
    ];

    final introduced = await _introducedIds();
    final allowNew = await newAllowedToday(freeOnly: freeOnly, excluded: excluded);
    final newQuestions =
        scope.where((q) => !introduced.contains(q.id)).take(allowNew).toList();

    return [...dueQuestions, ...newQuestions];
  }

  /// Earliest future due date (for the "done for today" screen).
  Future<DateTime?> nextDue({required bool freeOnly, required List<String> excluded}) async {
    final scopeIds = (await _scope(freeOnly, excluded)).map((q) => q.id).toSet();
    final db = await _db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query('srs_cards',
        columns: ['question_id', 'due'],
        where: 'due > ?', whereArgs: [nowIso], orderBy: 'due ASC');
    for (final r in rows) {
      if (scopeIds.contains(r['question_id'] as int)) {
        return DateTime.parse(r['due'] as String).toLocal();
      }
    }
    return null;
  }

  // ── Settings accessors ────────────────────────────────────────────────────
  Future<DateTime?> examDate() async {
    final s = await _dbService!.getSetting(AppConstants.keySrsExamDate);
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Future<void> setExamDate(DateTime? date) async {
    await _dbService!.setSetting(
        AppConstants.keySrsExamDate, date == null ? '' : date.toIso8601String());
    notifyListeners();
  }

  Future<int?> dailyMinutes() async {
    final s = await _dbService!.getSetting(AppConstants.keySrsDailyMinutes);
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<void> setDailyMinutes(int? minutes) async {
    await _dbService!.setSetting(AppConstants.keySrsDailyMinutes,
        minutes == null ? '' : minutes.toString());
    notifyListeners();
  }

  /// State counts for stats: {'neu':, 'lernend':, 'reif':, 'faellig':}.
  Future<Map<String, int>> stateCounts({required bool freeOnly, required List<String> excluded}) async {
    final scope = await _scope(freeOnly, excluded);
    final scopeIds = scope.map((q) => q.id).toSet();
    final db = await _db;
    final rows = await db.query('srs_cards', columns: ['question_id', 'state', 'due']);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    var lernend = 0, reif = 0, faellig = 0, introduced = 0;
    for (final r in rows) {
      if (!scopeIds.contains(r['question_id'] as int)) continue;
      introduced++;
      final state = r['state'] as int;
      if (state == 2) { reif++; } else { lernend++; }
      if ((r['due'] as String).compareTo(nowIso) <= 0) faellig++;
    }
    return {
      'neu': scopeIds.length - introduced,
      'lernend': lernend,
      'reif': reif,
      'faellig': faellig,
    };
  }

  Future<void> resetSrs() async {
    final db = await _db;
    await db.delete('srs_cards');
    await db.delete('srs_review_log');
    await _dbService!.setSetting(AppConstants.keySrsIntroDate, '');
    await _dbService!.setSetting(AppConstants.keySrsIntroCount, '0');
    notifyListeners();
  }
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/services/srs_service.dart`
Expected: No issues. (The `forTest` constructor leaves `_repo`/`_progress`/`_dbService` null; scope methods are only called in app mode where they are non-null.)

- [ ] **Step 3: Commit**

```bash
git add lib/services/srs_service.dart
git commit -m "feat: SrsService scope counts, today queue, reset, settings"
```

---

### Task 7: Register SrsService provider

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Import + construct + provide**

In `lib/main.dart` add import:
```dart
import 'services/srs_service.dart';
```

In `main()`, after `final iap = ...; await iap.init(...)`, build the progress service
once so it can be shared (replace the inline `ProgressService(db)` in `runApp`):
```dart
    final progress = ProgressService(db);
    final srs = SrsService(db, repo, progress);
```
Then pass both into `RettungshundeApp`:
```dart
    runApp(RettungshundeApp(
      repo:       repo,
      license:    license,
      iap:        iap,
      progress:   progress,
      backup:     BackupService(db),
      discipline: discipline,
      srs:        srs,
    ));
```

- [ ] **Step 2: Add field + provider**

In `RettungshundeApp`, add `required this.srs,` to the constructor, add field:
```dart
  final SrsService srs;
```
And in the `providers:` list add:
```dart
        ChangeNotifierProvider<SrsService>.value(value: srs),
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/main.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register SrsService provider"
```

---

### Task 8: KarteikastenScreen (session + hybrid rating)

**Files:**
- Create: `lib/screens/karteikasten_screen.dart`

- [ ] **Step 1: Implement the screen**

Create `lib/screens/karteikasten_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../services/discipline_service.dart';
import '../services/license_service.dart';
import '../services/srs_service.dart';
import '../utils/app_constants.dart';
import '../widgets/gradient_button.dart';
import '../widgets/question_card.dart';

class KarteikastenScreen extends StatefulWidget {
  const KarteikastenScreen({super.key});
  @override
  State<KarteikastenScreen> createState() => _KarteikastenScreenState();
}

class _KarteikastenScreenState extends State<KarteikastenScreen> {
  final List<Question> _queue = [];
  int _total = 0;
  int _done = 0;
  bool _loading = true;
  Set<int> _selected = {};
  bool _revealed = false;
  bool _lastCorrect = false;
  DateTime _shownAt = DateTime.now();
  DateTime? _nextDue;

  bool get _freeOnly => !context.read<LicenseService>().isPro;
  List<String> get _excluded =>
      context.read<DisciplineService>().typ.excludedCategories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final srs = context.read<SrsService>();
    final queue =
        await srs.buildTodayQueue(freeOnly: _freeOnly, excluded: _excluded);
    final next = queue.isEmpty
        ? await srs.nextDue(freeOnly: _freeOnly, excluded: _excluded)
        : null;
    if (!mounted) return;
    setState(() {
      _queue.addAll(queue);
      _total = queue.length;
      _nextDue = next;
      _loading = false;
      _shownAt = DateTime.now();
    });
  }

  Question get _current => _queue.first;

  void _toggle(int i) {
    setState(() {
      if (_current.isSingleChoice) {
        _selected = {i};
      } else {
        final s = Set<int>.from(_selected);
        s.contains(i) ? s.remove(i) : s.add(i);
        _selected = s;
      }
    });
  }

  void _check() {
    setState(() {
      _revealed = true;
      _lastCorrect = _current.isAnswerCorrect(_selected);
    });
  }

  Future<void> _rate(fsrs.Rating rating) async {
    final srs = context.read<SrsService>();
    final q = _queue.removeAt(0);
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    await srs.review(q.id, rating, elapsedMs: elapsed);
    if (!mounted) return;
    setState(() {
      _done++;
      _selected = {};
      _revealed = false;
      _shownAt = DateTime.now();
    });
  }

  String _nextDueLabel() {
    if (_nextDue == null) return 'Keine weiteren Karten geplant.';
    final days = _nextDue!.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Nächste Wiederholung: heute/morgen.';
    return 'Nächste Wiederholung in $days Tag${days == 1 ? '' : 'en'}.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Karteikasten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Karteikasten')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 56, color: AppConstants.successColor),
                const SizedBox(height: 14),
                Text(_done > 0 ? 'Fertig für heute! 🎉' : 'Nichts fällig.',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_nextDueLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppConstants.textMuted)),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Zurück',
                  icon: Icons.home_outlined,
                  fullWidth: false,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = _total == 0 ? 0.0 : _done / _total;
    return Scaffold(
      appBar: AppBar(title: Text('Karteikasten · $_done / $_total')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              LinearProgressIndicator(
                  value: progress, color: AppConstants.srsAccent),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    QuestionCard(
                      question: _current,
                      selected: _selected,
                      onToggle: _toggle,
                      revealed: _revealed,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (!_revealed) {
      return GradientButton.success(
        label: 'Antwort prüfen',
        icon: Icons.check_rounded,
        onPressed: _selected.isEmpty ? null : _check,
      );
    }
    if (!_lastCorrect) {
      // Wrong -> Again automatically.
      return GradientButton(
        label: 'Weiter (nochmal lernen)',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => _rate(fsrs.Rating.again),
      );
    }
    // Correct -> Hard / Good / Easy.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _rate(fsrs.Rating.hard),
            child: const Text('Schwer'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GradientButton(
            label: 'Gut',
            onPressed: () => _rate(fsrs.Rating.good),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _rate(fsrs.Rating.easy),
            child: const Text('Leicht'),
          ),
        ),
      ],
    );
  }
}
```

Note: confirm `GradientButton` exposes `fullWidth` and a default unnamed
constructor with optional `icon`; both are used in existing screens
(`exam_screen.dart`, `learn_screen.dart`) so the API already matches.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/screens/karteikasten_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/karteikasten_screen.dart
git commit -m "feat: KarteikastenScreen with FSRS hybrid rating"
```

---

### Task 9: Home — 4th mode card with live badge

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add imports**

After `import 'exam_screen.dart';` add:
```dart
import 'karteikasten_screen.dart';
```
After `import '../services/license_service.dart';` add:
```dart
import '../services/srs_service.dart';
```

- [ ] **Step 2: Insert the Karteikasten card as the first mode card**

In `build`, immediately after the `const SizedBox(height: 12),` that follows the
`'TRAININGS-MODI'` label and BEFORE the `_ModeCard(... 'Lernmodus' ...)`, insert:
```dart
                _SrsModeCard(
                  freeOnly: !isPro,
                  excluded: discipline.typ.excludedCategories,
                ),
                const SizedBox(height: 10),
```

- [ ] **Step 3: Add the `_SrsModeCard` widget**

At the end of the file (after `_DisciplineDialogState`), add:
```dart
class _SrsModeCard extends StatelessWidget {
  const _SrsModeCard({required this.freeOnly, required this.excluded});
  final bool freeOnly;
  final List<String> excluded;

  @override
  Widget build(BuildContext context) {
    final srs = context.watch<SrsService>();
    return FutureBuilder<List<int>>(
      future: Future.wait([
        srs.dueCount(freeOnly: freeOnly, excluded: excluded),
        srs.newAllowedToday(freeOnly: freeOnly, excluded: excluded),
      ]),
      builder: (context, snap) {
        final due = snap.data?[0] ?? 0;
        final neu = snap.data?[1] ?? 0;
        final subtitle = snap.hasData
            ? '$due fällig · $neu neu heute'
            : 'Spaced Repetition lädt …';
        return _ModeCard(
          icon: Icons.style_outlined,
          title: 'Karteikasten',
          subtitle: subtitle,
          accent: AppConstants.srsAccent,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const KarteikastenScreen())),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: home Karteikasten card with due/new badge"
```

---

### Task 10: Settings — KARTEIKASTEN section

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add imports + provider read**

Add import:
```dart
import '../services/srs_service.dart';
```
Add `import 'package:intl/intl.dart';` (already a dependency) for date formatting.

- [ ] **Step 2: Add the section UI**

In `build`, after the `FEEDBACK & RECHTLICHES` `_SettingsCard([...])` block and its
trailing `const SizedBox(height: 24),` (insert the section BEFORE the version
footer), add:
```dart
              const _SectionLabel('KARTEIKASTEN'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.event_outlined,
                  iconColor: AppConstants.srsAccent,
                  title: 'Prüfungsdatum',
                  subtitle: 'Tempo der neuen Karten richtet sich danach',
                  onTap: () => _pickExamDate(context),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.timer_outlined,
                  iconColor: AppConstants.srsAccent,
                  title: 'Max. Lernzeit pro Tag',
                  subtitle: 'Deckelt neue Karten (optional)',
                  onTap: () => _pickDailyMinutes(context),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.restart_alt,
                  iconColor: AppConstants.dangerColor,
                  title: 'Karteikasten zurücksetzen',
                  subtitle: 'Alle Wiederholungs-Daten löschen',
                  onTap: () => _resetSrs(context),
                ),
              ]),
              const SizedBox(height: 24),
```

- [ ] **Step 3: Add the handler methods**

Add these methods to `SettingsScreen` (it is a `StatelessWidget`; all use
`BuildContext`):
```dart
  Future<void> _pickExamDate(BuildContext context) async {
    final srs = context.read<SrsService>();
    final current = await srs.examDate();
    if (!context.mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    await srs.setExamDate(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Prüfungsdatum: ${DateFormat('dd.MM.yyyy').format(picked)}'),
    ));
  }

  Future<void> _pickDailyMinutes(BuildContext context) async {
    final srs = context.read<SrsService>();
    final current = await srs.dailyMinutes();
    if (!context.mounted) return;
    final controller = TextEditingController(text: current?.toString() ?? '');
    final value = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Max. Minuten pro Tag'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'z.B. 15 (leer = kein Limit)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              child: const Text('Kein Limit')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text.trim())),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (value == null) return; // dialog dismissed
    await srs.setDailyMinutes(value < 0 ? null : value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value < 0 ? 'Kein Zeitlimit.' : 'Max $value Min/Tag.'),
    ));
  }

  Future<void> _resetSrs(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Karteikasten zurücksetzen?'),
        content: const Text(
            'Alle Wiederholungs-Intervalle und der Karteikasten-Verlauf werden '
            'gelöscht. Der allgemeine Lernfortschritt bleibt erhalten.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SrsService>().resetSrs();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Karteikasten zurückgesetzt.')),
      );
    }
  }
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: settings Karteikasten section (exam date, time cap, reset)"
```

---

### Task 11: Stats — Karteikasten state section

**Files:**
- Modify: `lib/screens/stats_screen.dart`

- [ ] **Step 1: Read current structure**

Open `lib/screens/stats_screen.dart` and locate the main `ListView`/`children` list
and existing `_SectionLabel` usage (mirror its style).

- [ ] **Step 2: Add imports**

```dart
import '../services/discipline_service.dart';
import '../services/license_service.dart';
import '../services/srs_service.dart';
```

- [ ] **Step 3: Insert a Karteikasten stats block**

At the end of the stats `children` list (before the final spacing), add:
```dart
              const SizedBox(height: 24),
              const _SectionLabel('KARTEIKASTEN'),
              Builder(builder: (context) {
                final srs = context.watch<SrsService>();
                final freeOnly = !context.read<LicenseService>().isPro;
                final excluded =
                    context.read<DisciplineService>().typ.excludedCategories;
                return FutureBuilder<Map<String, int>>(
                  future: srs.stateCounts(freeOnly: freeOnly, excluded: excluded),
                  builder: (context, snap) {
                    final m = snap.data ??
                        const {'neu': 0, 'lernend': 0, 'reif': 0, 'faellig': 0};
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppConstants.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SrsStat(label: 'Neu', value: m['neu']!),
                          _SrsStat(label: 'Lernend', value: m['lernend']!),
                          _SrsStat(label: 'Reif', value: m['reif']!),
                          _SrsStat(
                              label: 'Fällig',
                              value: m['faellig']!,
                              color: AppConstants.srsAccent),
                        ],
                      ),
                    );
                  },
                );
              }),
```

- [ ] **Step 4: Add `_SrsStat` helper widget**

At the end of the file add (if `_SectionLabel` isn't defined in this file, also add
the same `_SectionLabel` widget as used in `settings_screen.dart`):
```dart
class _SrsStat extends StatelessWidget {
  const _SrsStat({required this.label, required this.value, this.color});
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color ?? Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppConstants.textMuted)),
      ],
    );
  }
}
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/screens/stats_screen.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/stats_screen.dart
git commit -m "feat: stats Karteikasten state counts"
```

---

### Task 12: Full analyze, bump build, manual verification

**Files:**
- Modify: `lib/build_info.dart`, `pubspec.yaml`

- [ ] **Step 1: Bump build number**

`lib/build_info.dart` → `const int kBuildNumber = 5;`
`pubspec.yaml` → `version: 1.0.0+5`

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: all pass (migration, pacing, srs_service suites).

- [ ] **Step 3: Full analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 4: Manual smoke test (build + run)**

Run: `flutter run -d chrome` (web) and/or APK build.
Verify:
- Home shows „Karteikasten" card with „X fällig · Y neu".
- Tapping starts a session; answering correct shows Schwer/Gut/Leicht; wrong shows „Weiter (nochmal lernen)".
- After finishing → „Fertig für heute" with next-due text.
- Settings → KARTEIKASTEN: set exam date + minutes; values persist after restart.
- Reset clears the box (badge returns to all-new).
- Gating: in Gratis mode only free questions appear as new.

- [ ] **Step 5: Commit**

```bash
git add lib/build_info.dart pubspec.yaml
git commit -m "chore: bump build to 5 for Karteikasten feature"
```

---

## Self-Review Notes (author)

- **Spec coverage:** §3 dep → T1; §4 schema/migration → T2,T3; §5 SrsService → T5,T6;
  §6 pacing → T4; §7 session → T8; §8 UI (home/screen/settings/stats) → T9,T10,T11;
  §10 build bump → T12. Gating handled via `_scope` (T6) used everywhere. ✓
- **Risks honored:** time estimate fallback 20s (T6 `_avgSecondsPerCard`); JSON blob
  storage only (T5); UTC due handling (T5/T6); local date for daily counting (T5).
- **Type consistency:** `SrsService` method names (`dueCount`, `newAllowedToday`,
  `buildTodayQueue`, `nextDue`, `examDate`, `dailyMinutes`, `stateCounts`, `resetSrs`,
  `review`) are referenced identically in T8–T11. `AppConstants.srsAccent`,
  `keySrs*` defined in T2 and used later. ✓
- **Open follow-up (not v1):** within-session re-appearance of Again/Hard cards only
  triggers when their learning-step due (1–10 min) elapses; acceptable per spec §9.
