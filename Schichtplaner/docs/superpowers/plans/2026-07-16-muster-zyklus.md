# Muster-Reiter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eigener Reiter „Muster": Dienstplan-Muster eintragen, Zyklus automatisch erkennen, ICS exportieren (einzeln + pro Dienstgruppe). Eigenständig, kein Planer-Eingriff.

**Architecture:** Neues Model `ShiftPattern` (+`PatternGroup`) in der bestehenden Single-JSON-Storage; reine Logik in `PatternService` (Statics, unit-getestet); ICS über vorhandenes `IcsService.buildIcs` mit transienten `Shift`-Objekten; UI als neuer `PatternScreen` mit 4 Karten; 6. Navigation-Destination in `home_shell`.

**Tech Stack:** Flutter/Dart, Provider, file_selector/share_plus (über bestehendes `FileIo`), flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-16-muster-zyklus-design.md`

**Repo:** `C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app` ist ein EIGENES Git-Repo, Branch `feature/monats-solls` (weiterverwenden). Alle `flutter`-/`git`-Kommandos dort ausführen. Achtung: Working Tree enthält evtl. eine uncommittete Änderung an `lib/services/storage_service.dart` (Task F) — nicht anfassen, nur die eigenen Dateien stagen.

---

### Task A: ShiftPattern-Model

**Files:**
- Create: `lib/models/shift_pattern.dart`
- Test: `test/shift_pattern_test.dart`

- [ ] **Step 1: Failing Test**

`test/shift_pattern_test.dart` (neu):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/shift_pattern.dart';

void main() {
  group('ShiftPattern', () {
    test('JSON-Roundtrip', () {
      final p = ShiftPattern(
        startDate: '2026-07-01',
        entries: ['a', 'frei', 'b'],
        fullCycle: true,
        groups: [PatternGroup(name: 'DG1', offset: 0), PatternGroup(name: 'B', offset: 3)],
      );
      final r = ShiftPattern.fromJson(p.toJson());
      expect(r.startDate, '2026-07-01');
      expect(r.entries, ['a', 'frei', 'b']);
      expect(r.fullCycle, isTrue);
      expect(r.groups, hasLength(2));
      expect(r.groups[1].name, 'B');
      expect(r.groups[1].offset, 3);
      expect(r.isEmpty, isFalse);
    });

    test('Defaults bei fehlenden Feldern', () {
      final p = ShiftPattern.fromJson({});
      expect(p.startDate, '');
      expect(p.entries, isEmpty);
      expect(p.fullCycle, isFalse);
      expect(p.groups, isEmpty);
      expect(p.isEmpty, isTrue);
    });
  });
}
```

- [ ] **Step 2: Test läuft rot**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/shift_pattern_test.dart` → FAIL (Datei fehlt)

- [ ] **Step 3: Model implementieren**

`lib/models/shift_pattern.dart` (neu):

```dart
/// Fester Platzhalter für "Frei" in [ShiftPattern.entries].
const String freiEntryId = 'frei';

/// Dienstgruppe: fährt denselben Zyklus um [offset] Zyklus-Tage versetzt.
class PatternGroup {
  String name;
  int offset; // 0 = wie die eingetragene Eingabe

  PatternGroup({required this.name, this.offset = 0});

  Map<String, dynamic> toJson() => {'name': name, 'offset': offset};

  factory PatternGroup.fromJson(Map<String, dynamic> json) => PatternGroup(
        name: json['name'] as String? ?? '',
        offset: json['offset'] as int? ?? 0,
      );
}

/// Eingetragenes Dienstplan-Muster (Tag 0 = [startDate]).
class ShiftPattern {
  String startDate; // 'yyyy-MM-dd', '' = noch nichts eingetragen
  List<String> entries; // je Tag: Vorlagen-Id oder [freiEntryId]
  bool fullCycle; // ganze Eingabe als Zyklus erzwingen
  List<PatternGroup> groups;

  ShiftPattern({
    this.startDate = '',
    List<String>? entries,
    this.fullCycle = false,
    List<PatternGroup>? groups,
  })  : entries = entries ?? [],
        groups = groups ?? [];

  bool get isEmpty => entries.isEmpty;

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'entries': entries,
        'fullCycle': fullCycle,
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  factory ShiftPattern.fromJson(Map<String, dynamic> json) => ShiftPattern(
        startDate: json['startDate'] as String? ?? '',
        entries: (json['entries'] as List?)?.map((e) => e as String).toList(),
        fullCycle: json['fullCycle'] as bool? ?? false,
        groups: (json['groups'] as List?)
            ?.map((e) => PatternGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 4: Test grün** — `flutter test test/shift_pattern_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/models/shift_pattern.dart test/shift_pattern_test.dart
git commit -m "feat: ShiftPattern-Model für Muster-Reiter"
```

---

### Task B: PatternService

**Files:**
- Create: `lib/services/pattern_service.dart`
- Test: `test/pattern_service_test.dart`

- [ ] **Step 1: Failing Tests**

`test/pattern_service_test.dart` (neu):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/shift_pattern.dart';
import 'package:schichtplaner/models/shift_template.dart';
import 'package:schichtplaner/services/pattern_service.dart';

void main() {
  ShiftTemplate tpl(String id) => ShiftTemplate(
      id: id, name: id.toUpperCase(), abbreviation: id, colorValue: 0);

  group('detectCycle', () {
    test('volle Wiederholung wird erkannt', () {
      final (p, detected) =
          PatternService.detectCycle(['f', 'n', 'frei', 'f', 'n', 'frei']);
      expect(p, 3);
      expect(detected, isTrue);
    });

    test('Teil-Wiederholung: Periode gefunden, aber nicht bestätigt', () {
      final (p, detected) =
          PatternService.detectCycle(['f', 'n', 'frei', 'f', 'n']);
      expect(p, 3);
      expect(detected, isFalse);
    });

    test('keine Wiederholung: Periode = Länge', () {
      final (p, detected) = PatternService.detectCycle(['f', 'n', 's']);
      expect(p, 3);
      expect(detected, isFalse);
    });
  });

  group('cycleOf', () {
    test('fullCycle erzwingt ganze Eingabe nur bei Teil-Wiederholung', () {
      final partial = ShiftPattern(
          startDate: '2026-07-01',
          entries: ['f', 'n', 'frei', 'f', 'n'],
          fullCycle: true);
      final c1 = PatternService.cycleOf(partial)!;
      expect(c1.forced, isTrue);
      expect(c1.cycle, hasLength(5));
      expect(c1.autoPeriod, 3);

      // voll erkannt -> fullCycle wird ignoriert
      final full = ShiftPattern(
          startDate: '2026-07-01',
          entries: ['f', 'n', 'f', 'n'],
          fullCycle: true);
      final c2 = PatternService.cycleOf(full)!;
      expect(c2.detected, isTrue);
      expect(c2.cycle, ['f', 'n']);

      expect(PatternService.cycleOf(ShiftPattern()), isNull);
    });
  });

  group('shiftsForRange', () {
    final pattern = ShiftPattern(
        startDate: '2026-07-01', entries: ['f', 'frei', 'f', 'frei']);
    final templates = {'f': tpl('f')};

    test('Frei übersprungen, Zyklus läuft über Grenzen, Ids deterministisch',
        () {
      final cycle = PatternService.cycleOf(pattern)!;
      expect(cycle.cycle, ['f', 'frei']);
      final shifts = PatternService.shiftsForRange(pattern, cycle, templates,
          DateTime(2026, 7, 5), DateTime(2026, 7, 8));
      // 5.7. = Tag 4 -> idx 0 (f), 6.7. frei, 7.7. f, 8.7. frei
      expect(shifts.map((s) => s.date), ['2026-07-05', '2026-07-07']);
      expect(shifts.first.id, 'muster-2026-07-05-f');
      expect(shifts.first.templateId, 'f');
    });

    test('Offset verschiebt, unbekannte Vorlagen-Id übersprungen', () {
      final cycle = PatternService.cycleOf(pattern)!;
      final shifted = PatternService.shiftsForRange(pattern, cycle, templates,
          DateTime(2026, 7, 5), DateTime(2026, 7, 8),
          offset: 1, uidSuffix: '-dg2');
      expect(shifted.map((s) => s.date), ['2026-07-06', '2026-07-08']);
      expect(shifted.first.id, 'muster-2026-07-06-f-dg2');

      final unknown = ShiftPattern(startDate: '2026-07-01', entries: ['x']);
      final cu = PatternService.cycleOf(unknown)!;
      expect(
          PatternService.shiftsForRange(unknown, cu, templates,
              DateTime(2026, 7, 1), DateTime(2026, 7, 3)),
          isEmpty);
    });
  });

  group('probeMatches', () {
    // Zyklus: f n s frei (p=4), Muster-Start 1.7.
    const cycle = ['f', 'n', 's', 'frei'];

    test('eindeutig, mehrdeutig, keine Übereinstimmung', () {
      // Probe ab 3.7. (= Zyklus-Index 2 ohne Versatz)
      expect(
          PatternService.probeMatches(cycle, '2026-07-01', '2026-07-03',
              ['s', 'frei', 'f']),
          [0]);
      // nur 'f': passt bei Versätzen, die Index auf 0 schieben
      expect(
          PatternService.probeMatches(cycle, '2026-07-01', '2026-07-03', ['f']),
          [2]);
      // Sequenz, die nirgends vorkommt
      expect(
          PatternService.probeMatches(cycle, '2026-07-01', '2026-07-03',
              ['f', 'f']),
          isEmpty);
      // mehrdeutig: Zyklus f f n n, Probe 'f' ab Muster-Start
      expect(
          PatternService.probeMatches(
              ['f', 'f', 'n', 'n'], '2026-07-01', '2026-07-01', ['f']),
          [0, 1]);
    });
  });

  group('distributeOffsets', () {
    test('später/früher, modulo Zykluslänge', () {
      final groups = [
        PatternGroup(name: 'A'),
        PatternGroup(name: 'B'),
        PatternGroup(name: 'C'),
      ];
      PatternService.distributeOffsets(groups, 6, 2, false); // früher
      expect(groups.map((g) => g.offset), [0, 2, 4]);
      PatternService.distributeOffsets(groups, 6, 2, true); // später
      expect(groups.map((g) => g.offset), [0, 4, 2]);
      PatternService.distributeOffsets(groups, 3, 4, false); // Abstand > p
      expect(groups.map((g) => g.offset), [0, 1, 2]);
    });
  });

  group('Datums-Helfer', () {
    test('daysBetween/addDays sind DST-sicher', () {
      // Über die Sommerzeit-Umstellung (29.3.2026) hinweg
      expect(PatternService.daysBetween('2026-03-28', '2026-03-30'), 2);
      expect(PatternService.addDays('2026-03-28', 2), '2026-03-30');
      expect(PatternService.addDays('2026-07-31', 1), '2026-08-01');
    });
  });
}
```

- [ ] **Step 2: rot** — `flutter test test/pattern_service_test.dart` → FAIL (Service fehlt)

- [ ] **Step 3: Service implementieren**

`lib/services/pattern_service.dart` (neu):

```dart
import '../models/shift.dart';
import '../models/shift_pattern.dart';
import '../models/shift_template.dart';

/// Ergebnis der Zyklusbestimmung eines Musters.
class CycleInfo {
  final List<String> cycle; // verwendeter Zyklus (Eintrags-Ids)
  final bool detected; // mindestens 2 volle Durchläufe eingegeben
  final bool partial; // Teil-Wiederholung erkannt, aber nicht bestätigt
  final bool forced; // Nutzer hat ganze Eingabe als Zyklus erzwungen
  final int autoPeriod; // automatisch erkannte Periode
  final int totalEntries; // Länge der gesamten Eingabe

  const CycleInfo({
    required this.cycle,
    required this.detected,
    required this.partial,
    required this.forced,
    required this.autoPeriod,
    required this.totalEntries,
  });
}

/// Reine Muster-Logik: Zykluserkennung, Fortschreibung, Dienstgruppen.
/// Datumsrechnung über UTC, damit die Sommerzeit keine Tage verschiebt.
class PatternService {
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime parseDay(String s) {
    final p = s.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static int daysBetween(String a, String b) =>
      parseDay(b).difference(parseDay(a)).inDays;

  static String addDays(String day, int n) =>
      dateKey(parseDay(day).add(Duration(days: n)));

  /// Kleinste Periode p mit entries[i] == entries[i % p].
  /// detected erst, wenn die Eingabe mindestens 2 volle Durchläufe enthält.
  static (int, bool) detectCycle(List<String> entries) {
    final n = entries.length;
    for (var p = 1; p < n; p++) {
      var ok = true;
      for (var i = p; i < n; i++) {
        if (entries[i] != entries[i % p]) {
          ok = false;
          break;
        }
      }
      if (ok) return (p, n >= 2 * p);
    }
    return (n, false);
  }

  /// Zyklus des Musters; null bei leerer Eingabe. [ShiftPattern.fullCycle]
  /// greift nur bei unbestätigter Teil-Wiederholung (wie im Web-Programm).
  static CycleInfo? cycleOf(ShiftPattern pattern) {
    final n = pattern.entries.length;
    if (n == 0) return null;
    final (period, detected) = detectCycle(pattern.entries);
    if (!detected && period < n && pattern.fullCycle) {
      return CycleInfo(
        cycle: List.of(pattern.entries),
        detected: false,
        partial: false,
        forced: true,
        autoPeriod: period,
        totalEntries: n,
      );
    }
    return CycleInfo(
      cycle: pattern.entries.sublist(0, period),
      detected: detected,
      partial: !detected && period < n,
      forced: false,
      autoPeriod: period,
      totalEntries: n,
    );
  }

  /// Schreibt den Zyklus in den Zeitraum [from, to] fort und liefert
  /// transiente Shifts (nur für ICS-Export, werden nicht gespeichert).
  /// Frei-Tage und Ids ohne existierende Vorlage werden übersprungen.
  static List<Shift> shiftsForRange(
    ShiftPattern pattern,
    CycleInfo cycle,
    Map<String, ShiftTemplate> templatesById,
    DateTime from,
    DateTime to, {
    int offset = 0,
    String uidSuffix = '',
  }) {
    final p = cycle.cycle.length;
    final result = <Shift>[];
    final fromKey = dateKey(from);
    final total = daysBetween(fromKey, dateKey(to));
    for (var i = 0; i <= total; i++) {
      final day = addDays(fromKey, i);
      final diff = daysBetween(pattern.startDate, day) + offset;
      final idx = ((diff % p) + p) % p;
      final id = cycle.cycle[idx];
      if (id == freiEntryId || !templatesById.containsKey(id)) continue;
      result.add(Shift(id: 'muster-$day-$id$uidSuffix', date: day, templateId: id));
    }
    return result;
  }

  /// Alle Versätze (0..p-1), bei denen die Probe-Eingabe zum Zyklus passt.
  static List<int> probeMatches(
    List<String> cycle,
    String patternStart,
    String probeStart,
    List<String> probeSeq,
  ) {
    final p = cycle.length;
    if (p == 0 || probeSeq.isEmpty) return [];
    final base = daysBetween(patternStart, probeStart);
    final res = <int>[];
    for (var o = 0; o < p; o++) {
      var ok = true;
      for (var j = 0; j < probeSeq.length; j++) {
        final idx = (((base + j + o) % p) + p) % p;
        if (cycle[idx] != probeSeq[j]) {
          ok = false;
          break;
        }
      }
      if (ok) res.add(o);
    }
    return res;
  }

  /// Versätze automatisch verteilen: Gruppe i um i*spacing Tage,
  /// bei [later] startet jede weitere Gruppe später (wie Web-Programm).
  static void distributeOffsets(
      List<PatternGroup> groups, int period, int spacing, bool later) {
    for (var i = 0; i < groups.length; i++) {
      final shift = (i * spacing) % period;
      groups[i].offset = later ? (period - shift) % period : shift;
    }
  }
}
```

- [ ] **Step 4: grün** — `flutter test test/pattern_service_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/pattern_service.dart test/pattern_service_test.dart
git commit -m "feat: PatternService – Zykluserkennung und Fortschreibung"
```

---

### Task C: Storage + AppState

**Files:**
- Modify: `lib/services/storage_service.dart` (`AppData`)
- Modify: `lib/state/app_state.dart`
- Test: `test/storage_service_test.dart` (erweitern)

- [ ] **Step 1: Failing Test**

In `test/storage_service_test.dart` neue Gruppe ans Datei-Ende (vor dem
schließenden `}` von `main`) und Import oben ergänzen:

```dart
import 'package:schichtplaner/models/shift_pattern.dart';
```

```dart
  group('AppData pattern', () {
    test('fehlender Key → leeres Muster, Roundtrip erhält Muster', () {
      final empty = AppData.fromJson({});
      expect(empty.pattern.isEmpty, isTrue);

      final data = AppData.fromJson({});
      data.pattern
        ..startDate = '2026-07-01'
        ..entries.addAll(['a', 'frei'])
        ..fullCycle = true
        ..groups.add(PatternGroup(name: 'DG1', offset: 2));
      final restored = AppData.fromJson(data.toJson());
      expect(restored.pattern.startDate, '2026-07-01');
      expect(restored.pattern.entries, ['a', 'frei']);
      expect(restored.pattern.fullCycle, isTrue);
      expect(restored.pattern.groups.single.offset, 2);
    });
  });
```

- [ ] **Step 2: rot** — `flutter test test/storage_service_test.dart` → FAIL (kein `pattern`)

- [ ] **Step 3: AppData erweitern**

In `lib/services/storage_service.dart`:

- Import ergänzen: `import '../models/shift_pattern.dart';`
- Feld + Konstruktor-Param (analog `quotas`):
  - Feld: `ShiftPattern pattern;` (nach `quotas`)
  - Konstruktor-Param `ShiftPattern? pattern,` + Initialisierung `pattern = pattern ?? ShiftPattern(),`
- `toJson()`: nach der `'quotas'`-Zeile: `'pattern': pattern.toJson(),`
- `fromJson`: im `return AppData(...)` nach `quotas: quotas,` ergänzen:

```dart
      pattern: json['pattern'] != null
          ? ShiftPattern.fromJson(json['pattern'] as Map<String, dynamic>)
          : ShiftPattern(),
```

- [ ] **Step 4: AppState erweitern**

In `lib/state/app_state.dart`:

- Import: `import '../models/shift_pattern.dart';` (alphabetisch zu den Model-Imports)
- Getter nach `List<ShiftQuota> get quotas ...`:

```dart
  ShiftPattern get pattern => _data.pattern;
```

- Neuen Abschnitt nach dem Solls-Block (vor `// Schichten`):

```dart
  // --------------------------------------------------------------- Muster

  void patternSetStart(String date) {
    _data.pattern.startDate = date;
    _changed();
  }

  void patternAddEntry(String entryId) {
    _data.pattern.entries.add(entryId);
    _data.pattern.fullCycle = false; // Eingabe geändert -> Wahl zurücksetzen
    _changed();
  }

  void patternRemoveLast() {
    if (_data.pattern.entries.isEmpty) return;
    _data.pattern.entries.removeLast();
    _data.pattern.fullCycle = false;
    _changed();
  }

  void patternClear() {
    _data.pattern
      ..entries.clear()
      ..startDate = ''
      ..fullCycle = false;
    _changed();
  }

  void patternSetFullCycle(bool on) {
    _data.pattern.fullCycle = on;
    _changed();
  }

  /// Nach direkter Mutation von [pattern] (z.B. Gruppen) speichern.
  void updatePattern() => _changed();
```

- In `deleteTemplate` vor dem `_changed();` (nach der Quota-Bereinigung):

```dart
    if (_data.pattern.entries.contains(template.id)) {
      // Muster würde zerreißen -> komplett zurücksetzen (Gruppen bleiben).
      _data.pattern
        ..entries.clear()
        ..startDate = ''
        ..fullCycle = false;
    }
```

- [ ] **Step 5: grün** — `flutter analyze; flutter test` → analyze sauber, alle Tests PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/storage_service.dart lib/state/app_state.dart test/storage_service_test.dart
git commit -m "feat: Muster in AppData/AppState verwalten"
```

---

### Task D: FileIo.saveTextFiles (Mehrfach-Export)

**Files:**
- Modify: `lib/services/file_io.dart`

Kein Unit-Test (Plattform-Dialoge); Absicherung über analyze + manuelle Prüfung in Task E.

- [ ] **Step 1: Methode ergänzen**

In `lib/services/file_io.dart`, nach `saveTextFile`:

```dart
  /// Mehrere Dateien auf einmal: Desktop → Ordner wählen und alle dort
  /// ablegen, Android/iOS → ein Teilen-Dialog mit allen Dateien.
  /// Liefert die Anzahl gespeicherter Dateien (0 = abgebrochen).
  static Future<int> saveTextFiles({
    required List<(String, String)> files, // (Dateiname, Inhalt)
    String mimeType = 'text/plain',
  }) async {
    if (files.isEmpty) return 0;
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await SharePlus.instance.share(ShareParams(
        files: [
          for (final (name, content) in files)
            XFile.fromData(utf8.encode(content),
                name: name, mimeType: mimeType),
        ],
        fileNameOverrides: [for (final (name, _) in files) name],
      ));
      return result.status == ShareResultStatus.success ? files.length : 0;
    }
    final dir = await getDirectoryPath();
    if (dir == null) return 0;
    for (final (name, content) in files) {
      await File('$dir${Platform.pathSeparator}$name').writeAsString(content);
    }
    return files.length;
  }
```

- [ ] **Step 2: analyze** — `flutter analyze` → sauber

- [ ] **Step 3: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/file_io.dart
git commit -m "feat: FileIo.saveTextFiles für Mehrfach-Export"
```

---

### Task E: PatternScreen + Navigation + Lösch-Warnung

**Files:**
- Create: `lib/screens/pattern_screen.dart`
- Modify: `lib/screens/home_shell.dart`
- Modify: `lib/screens/templates_screen.dart` (nur `_delete`-Dialog)

- [ ] **Step 1: Navigation erweitern**

`lib/screens/home_shell.dart`:

- Import: `import 'pattern_screen.dart';`
- In `_destinations` zwischen „Abos" und „Statistik":

```dart
    (icon: Icons.repeat, label: 'Muster'),
```

- `_screen` anpassen:

```dart
  Widget _screen(int index) => switch (index) {
        0 => const PlannerScreen(),
        1 => const TemplatesScreen(),
        2 => const SubscriptionsScreen(),
        3 => const PatternScreen(),
        4 => const StatisticsScreen(),
        _ => const SettingsScreen(),
      };
```

- [ ] **Step 2: PatternScreen anlegen**

`lib/screens/pattern_screen.dart` (neu, kompletter Inhalt):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shift.dart';
import '../models/shift_pattern.dart';
import '../services/file_io.dart';
import '../services/ics_service.dart';
import '../services/pattern_service.dart';
import '../state/app_state.dart';
import '../widgets/select_all_text_field.dart';

/// Muster-Reiter: Dienstplan-Zyklus eintragen, erkennen und als ICS
/// exportieren (einzeln oder pro Dienstgruppe). Eigenständig — legt keine
/// Schichten im Planer an.
class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key});

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  static const _freiColor = Color(0xFF94A3B8);
  static const _wd = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  DateTimeRange? _exportRange;
  List<Shift>? _preview;

  // Dienstgruppen-Einstellungen (nicht persistiert, wie im Web-Programm)
  final _spacing = TextEditingController(text: '1');
  bool _spacingLater = true;

  // "Aus bekannten Schichten ermitteln" (Probe) für eine Gruppe
  int? _probeGroup;
  String _probeStart = '';
  final List<String> _probeSeq = [];
  String? _probeDoneMsg; // Erfolgsmeldung nach eindeutiger Zuordnung

  static String _fmtGerman(String day) {
    final p = day.split('-');
    return '${p[2]}.${p[1]}.${p[0]}';
  }

  static String _weekday(String day) =>
      _wd[PatternService.parseDay(day).weekday - 1];

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Color _entryColor(AppState state, String id) => id == freiEntryId
      ? _freiColor
      : (state.templatesById[id]?.color ?? Colors.grey);

  String _entryAbbr(AppState state, String id) => id == freiEntryId
      ? 'Frei'
      : (state.templatesById[id]?.abbreviation ?? '?');

  String _entryName(AppState state, String id) =>
      id == freiEntryId ? 'Frei' : (state.templatesById[id]?.name ?? '?');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pattern = state.pattern;
    final cycle = PatternService.cycleOf(pattern);
    return Scaffold(
      appBar: AppBar(title: const Text('Muster & Zyklus')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        _entryCard(state, pattern),
        _cycleCard(state, pattern, cycle),
        _exportCard(state, pattern, cycle),
        _groupsCard(state, pattern, cycle),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ------------------------------------------------------------ Eintragen

  Widget _entryCard(AppState state, ShiftPattern pattern) {
    final locked = pattern.entries.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1. Dienstplan eintragen',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(pattern.startDate.isEmpty
                  ? 'Erster Tag: noch nicht gewählt'
                  : 'Erster Tag: ${_weekday(pattern.startDate)}, ${_fmtGerman(pattern.startDate)}'),
            ),
            TextButton.icon(
              onPressed: locked ? null : () => _pickStart(state),
              icon: const Icon(Icons.event, size: 18),
              label: const Text('Datum wählen'),
            ),
          ]),
          Text(
              'Der Reihe nach für jeden Tag die Schicht antippen – auch freie Tage!',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (state.templates.isEmpty)
            const Text('Erst im Reiter „Vorlagen" Schichtvorlagen anlegen.')
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in state.templates)
                _entryButton(state, pattern, t.id),
              _entryButton(state, pattern, freiEntryId),
            ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: pattern.entries.isEmpty
                  ? null
                  : () {
                      state.patternRemoveLast();
                      setState(() => _preview = null);
                    },
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Letzten Tag löschen'),
            ),
            OutlinedButton.icon(
              onPressed:
                  pattern.entries.isEmpty ? null : () => _confirmClear(state),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Alles zurücksetzen'),
            ),
          ]),
          if (pattern.entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            _entryList(state, pattern),
          ],
        ]),
      ),
    );
  }

  Widget _entryButton(AppState state, ShiftPattern pattern, String id) {
    final color = _entryColor(state, id);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black87,
        minimumSize: const Size(64, 48),
      ),
      onPressed: () {
        if (pattern.startDate.isEmpty) {
          _snack('Bitte zuerst den ersten Tag wählen');
          return;
        }
        state.patternAddEntry(id);
        setState(() => _preview = null);
      },
      child: Text(_entryAbbr(state, id)),
    );
  }

  Future<void> _pickStart(AppState state) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: pattern0(state) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: 'Erster Tag der Eingabe',
    );
    if (picked != null) state.patternSetStart(PatternService.dateKey(picked));
  }

  DateTime? pattern0(AppState state) => state.pattern.startDate.isEmpty
      ? null
      : PatternService.parseDay(state.pattern.startDate).toLocal();

  Future<void> _confirmClear(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle eingetragenen Tage löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.patternClear();
      setState(() => _preview = null);
    }
  }

  Widget _entryList(AppState state, ShiftPattern pattern) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      // reverse + gespiegelter Index: neueste Einträge unten, direkt sichtbar
      child: ListView.builder(
        reverse: true,
        itemCount: pattern.entries.length,
        itemBuilder: (context, i) {
          final index = pattern.entries.length - 1 - i;
          final date = PatternService.addDays(pattern.startDate, index);
          final id = pattern.entries[index];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: SizedBox(
                width: 30,
                child: Text(_weekday(date),
                    style: Theme.of(context).textTheme.bodySmall)),
            title: Text(_fmtGerman(date)),
            trailing: _chip(state, id),
          );
        },
      ),
    );
  }

  Widget _chip(AppState state, String id) {
    final color = _entryColor(state, id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        _entryAbbr(state, id),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color:
              ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Erkennung

  Widget _cycleCard(AppState state, ShiftPattern pattern, CycleInfo? cycle) {
    Widget content;
    if (cycle == null) {
      content = const Text('Noch nichts eingetragen.');
    } else {
      final chips = Wrap(spacing: 4, runSpacing: 4, children: [
        for (final id in cycle.cycle) _chip(state, id),
      ]);
      if (cycle.detected) {
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✅ Muster erkannt: ${cycle.cycle.length}-Tage-Zyklus',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Text('Wiederholt sich beim Export automatisch weiter.'),
          const SizedBox(height: 6),
          chips,
        ]);
      } else if (cycle.forced) {
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '📌 Ganze Eingabe (${cycle.cycle.length} Tage) wird als Zyklus verwendet (deine Wahl).',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          chips,
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: () => state.patternSetFullCycle(false),
            child: Text(
                'Zurück zur automatischen Erkennung (${cycle.autoPeriod} Tage)'),
          ),
        ]);
      } else if (cycle.partial) {
        final rest = cycle.totalEntries - cycle.cycle.length;
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔎 Vermutet: ${cycle.cycle.length}-Tage-Zyklus',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
              'Von ${cycle.totalEntries} eingetragenen Tagen passen die letzten $rest auf den Anfang der Wiederholung. Für sichere Erkennung das Muster mindestens 2× komplett durchgeben.'),
          const SizedBox(height: 6),
          chips,
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: () => state.patternSetFullCycle(true),
            child: Text(
                'Stimmt nicht – ganze Eingabe (${cycle.totalEntries} Tage) als Zyklus verwenden'),
          ),
        ]);
      } else {
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'ℹ️ Noch keine Wiederholung erkennbar – die gesamte Eingabe (${cycle.cycle.length} Tage) gilt als ein Zyklus.'),
          const Text(
              'Für sichere Erkennung das Muster mindestens 2× durchgeben.'),
          const SizedBox(height: 6),
          chips,
        ]);
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('2. Erkanntes Muster',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          content,
        ]),
      ),
    );
  }

  // -------------------------------------------------------------- Export

  Widget _exportCard(
      AppState state, ShiftPattern pattern, CycleInfo? cycle) {
    final enabled = cycle != null;
    final rangeText = _exportRange == null
        ? 'Kein Zeitraum gewählt'
        : 'Zeitraum: ${_fmtGerman(PatternService.dateKey(_exportRange!.start))} – ${_fmtGerman(PatternService.dateKey(_exportRange!.end))}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('3. ICS-Kalender exportieren',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(rangeText)),
            TextButton.icon(
              onPressed: enabled ? _pickRange : null,
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Zeitraum wählen'),
            ),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed:
                  enabled ? () => _showPreview(state, pattern, cycle) : null,
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Vorschau'),
            ),
            FilledButton.icon(
              onPressed:
                  enabled ? () => _saveIcs(state, pattern, cycle) : null,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('ICS speichern'),
            ),
          ]),
          if (_preview != null) ...[
            const SizedBox(height: 8),
            Text('${_preview!.length} Dienste im Zeitraum',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _preview!.length,
                itemBuilder: (context, i) {
                  final s = _preview![i];
                  final t = state.templatesById[s.templateId];
                  final time = t == null
                      ? ''
                      : t.isAllDay
                          ? 'Ganztägig'
                          : '${t.start}–${t.end}${t.isNightShift ? ' (Folgetag)' : ''}';
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: SizedBox(
                        width: 30,
                        child: Text(_weekday(s.date),
                            style: Theme.of(context).textTheme.bodySmall)),
                    title: Text('${_fmtGerman(s.date)}  ·  $time'),
                    trailing: _chip(state, s.templateId!),
                  );
                },
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _exportRange ??
          DateTimeRange(
              start: now.add(const Duration(days: 1)),
              end: now.add(const Duration(days: 92))),
      helpText: 'Zeitraum für den ICS-Export',
    );
    if (range != null) {
      setState(() {
        _exportRange = range;
        _preview = null;
      });
    }
  }

  Future<bool> _ensureRange() async {
    if (_exportRange != null) return true;
    await _pickRange();
    return _exportRange != null;
  }

  List<Shift> _generate(
          AppState state, ShiftPattern pattern, CycleInfo cycle,
          {int offset = 0, String uidSuffix = ''}) =>
      PatternService.shiftsForRange(pattern, cycle, state.templatesById,
          _exportRange!.start, _exportRange!.end,
          offset: offset, uidSuffix: uidSuffix);

  Future<void> _showPreview(
      AppState state, ShiftPattern pattern, CycleInfo cycle) async {
    if (!await _ensureRange()) return;
    setState(() => _preview = _generate(state, pattern, cycle));
  }

  Future<void> _saveIcs(
      AppState state, ShiftPattern pattern, CycleInfo cycle) async {
    if (!await _ensureRange()) return;
    final shifts = _generate(state, pattern, cycle);
    if (shifts.isEmpty) {
      _snack('Keine Dienste im gewählten Zeitraum (nur freie Tage)');
      return;
    }
    final ics = IcsService.buildIcs(
      shifts: shifts,
      templatesById: state.templatesById,
      from: _exportRange!.start,
      to: _exportRange!.end,
    );
    final name =
        'schichten_${PatternService.dateKey(_exportRange!.start)}_${PatternService.dateKey(_exportRange!.end)}.ics';
    final ok = await FileIo.saveTextFile(
        suggestedName: name, content: ics, mimeType: 'text/calendar');
    if (!mounted) return;
    if (ok) _snack('${shifts.length} Dienste exportiert ($name)');
  }

  // -------------------------------------------------------- Dienstgruppen

  Widget _groupsCard(
      AppState state, ShiftPattern pattern, CycleInfo? cycle) {
    final groups = pattern.groups;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('4. Dienstgruppen (optional)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'Alle Gruppen fahren denselben Zyklus, nur zeitversetzt. Export: eine ICS-Datei pro Gruppe (Zeitraum aus Schritt 3).',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Anzahl Gruppen:'),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: groups.isEmpty
                  ? null
                  : () => _setGroupCount(state, pattern, groups.length - 1),
            ),
            Text('${groups.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: groups.length >= 26 || cycle == null
                  ? null
                  : () => _setGroupCount(state, pattern, groups.length + 1),
            ),
          ]),
          if (cycle == null)
            const Text('Erst in Schritt 1 das Muster eintragen.')
          else if (groups.isNotEmpty) ...[
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    child: SelectAllTextField(
                      controller: _spacing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Abstand', suffixText: 'Tage'),
                    ),
                  ),
                  DropdownButton<bool>(
                    value: _spacingLater,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('später')),
                      DropdownMenuItem(value: false, child: Text('früher')),
                    ],
                    onChanged: (v) =>
                        setState(() => _spacingLater = v ?? true),
                  ),
                  OutlinedButton(
                    onPressed: () => _distribute(state, pattern, cycle),
                    child: const Text('↔ Versatz automatisch verteilen'),
                  ),
                ]),
            const SizedBox(height: 8),
            for (var i = 0; i < groups.length; i++)
              _groupTile(state, pattern, cycle, i),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _exportGroups(state, pattern, cycle),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('ICS für alle Dienstgruppen speichern'),
            ),
          ],
        ]),
      ),
    );
  }

  void _setGroupCount(AppState state, ShiftPattern pattern, int n) {
    n = n.clamp(0, 26);
    while (pattern.groups.length < n) {
      pattern.groups
          .add(PatternGroup(name: 'DG${pattern.groups.length + 1}'));
    }
    if (pattern.groups.length > n) {
      pattern.groups.removeRange(n, pattern.groups.length);
    }
    if (_probeGroup != null && _probeGroup! >= n) _cancelProbe();
    state.updatePattern();
  }

  void _distribute(AppState state, ShiftPattern pattern, CycleInfo cycle) {
    var spacing = int.tryParse(_spacing.text.trim()) ?? 1;
    if (spacing < 1) spacing = 1;
    PatternService.distributeOffsets(
        pattern.groups, cycle.cycle.length, spacing, _spacingLater);
    state.updatePattern();
  }

  Widget _groupTile(
      AppState state, ShiftPattern pattern, CycleInfo cycle, int i) {
    final g = pattern.groups[i];
    final p = cycle.cycle.length;
    final off = ((g.offset % p) + p) % p;
    final today = PatternService.dateKey(DateTime.now());

    // Kontrolle: die nächsten 5 Tage dieser Gruppe + nächster Zyklusstart
    final parts = <String>[];
    for (var d = 0; d < 5; d++) {
      final day = PatternService.addDays(today, d);
      final diff = PatternService.daysBetween(pattern.startDate, day) + off;
      final id = cycle.cycle[((diff % p) + p) % p];
      parts.add('${_weekday(day)}: ${_entryAbbr(state, id)}');
    }
    final diffToday =
        PatternService.daysBetween(pattern.startDate, today) + off;
    final idxToday = ((diffToday % p) + p) % p;
    final nextStart = PatternService.addDays(today, (p - idxToday) % p);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 160,
                child: TextFormField(
                  initialValue: g.name,
                  decoration:
                      InputDecoration(labelText: 'Name der Gruppe ${i + 1}'),
                  onChanged: (v) {
                    g.name = v.trim().isEmpty ? 'DG${i + 1}' : v.trim();
                    state.updatePattern();
                  },
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    'War am ${_fmtGerman(pattern.startDate)} bei:',
                    style: Theme.of(context).textTheme.bodySmall),
                DropdownButton<int>(
                  value: off,
                  items: [
                    for (var k = 0; k < p; k++)
                      DropdownMenuItem(
                        value: k,
                        child: Text(
                            'Zyklus-Tag ${k + 1}: ${_entryName(state, cycle.cycle[k])}${k == 0 ? ' – wie deine Eingabe' : ''}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    g.offset = v;
                    state.updatePattern();
                  },
                ),
              ]),
              OutlinedButton.icon(
                onPressed: () => _startProbe(i),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Aus bekannten Schichten ermitteln'),
              ),
            ]),
        const SizedBox(height: 4),
        Text(
            'Zyklus startet (Tag 1) am ${_weekday(nextStart)}, ${_fmtGerman(nextStart)}  –  ab heute: ${parts.join('  ·  ')}',
            style: Theme.of(context).textTheme.bodySmall),
        if (_probeDoneMsg != null && _probeGroup == null && i == _probeDoneFor)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_probeDoneMsg!,
                style: TextStyle(color: Colors.green.shade800)),
          ),
        if (_probeGroup == i) _probePanel(state, pattern, cycle),
      ]),
    );
  }

  // ---------------------------------------------------------------- Probe

  int? _probeDoneFor;

  void _startProbe(int i) {
    setState(() {
      _probeGroup = i;
      _probeStart = PatternService.dateKey(DateTime.now());
      _probeSeq.clear();
      _probeDoneMsg = null;
      _probeDoneFor = null;
    });
  }

  void _cancelProbe() {
    setState(() {
      _probeGroup = null;
      _probeSeq.clear();
    });
  }

  void _probeAdd(
      AppState state, ShiftPattern pattern, CycleInfo cycle, String id) {
    setState(() {
      _probeSeq.add(id);
      final m = PatternService.probeMatches(
          cycle.cycle, pattern.startDate, _probeStart, _probeSeq);
      if (m.length == 1) {
        pattern.groups[_probeGroup!].offset = m.first;
        state.updatePattern();
        _probeDoneMsg =
            '✅ Eindeutig zugeordnet: Zyklus-Tag ${m.first + 1} übernommen.';
        _probeDoneFor = _probeGroup;
        _probeGroup = null;
        _probeSeq.clear();
      }
    });
  }

  Widget _probePanel(AppState state, ShiftPattern pattern, CycleInfo cycle) {
    final m = PatternService.probeMatches(
        cycle.cycle, pattern.startDate, _probeStart, _probeSeq);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(
                  'Erster Tag der bekannten Schichten: ${_fmtGerman(_probeStart)}')),
          TextButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: PatternService.parseDay(_probeStart).toLocal(),
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setState(() => _probeStart = PatternService.dateKey(picked));
              }
            },
            icon: const Icon(Icons.event, size: 18),
            label: const Text('Datum'),
          ),
        ]),
        Text(
            'Dann der Reihe nach die Schichten dieser Gruppe drücken (auch Frei):',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in state.templates)
            _probeButton(state, pattern, cycle, t.id),
          _probeButton(state, pattern, cycle, freiEntryId),
        ]),
        if (_probeSeq.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (var j = 0; j < _probeSeq.length; j++) _chip(state, _probeSeq[j]),
          ]),
        ],
        const SizedBox(height: 6),
        Text(
          _probeSeq.isEmpty
              ? 'Noch keine Schicht eingetragen.'
              : m.isEmpty
                  ? '❌ Passt an keiner Stelle zum Zyklus – Datum und Eingabe prüfen.'
                  : 'Noch ${m.length} mögliche Positionen (Zyklus-Tage ${m.take(8).map((o) => o + 1).join(', ')}${m.length > 8 ? ', …' : ''}) – weitere Tage eintragen.',
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          OutlinedButton(
            onPressed: _probeSeq.isEmpty
                ? null
                : () => setState(() => _probeSeq.removeLast()),
            child: const Text('↩ Letzten Tag löschen'),
          ),
          OutlinedButton(
            onPressed: _cancelProbe,
            child: const Text('Abbrechen'),
          ),
        ]),
      ]),
    );
  }

  Widget _probeButton(
      AppState state, ShiftPattern pattern, CycleInfo cycle, String id) {
    final color = _entryColor(state, id);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black87,
        minimumSize: const Size(56, 40),
      ),
      onPressed: () => _probeAdd(state, pattern, cycle, id),
      child: Text(_entryAbbr(state, id)),
    );
  }

  Future<void> _exportGroups(
      AppState state, ShiftPattern pattern, CycleInfo cycle) async {
    if (!await _ensureRange()) return;
    final files = <(String, String)>[];
    var skipped = 0;
    for (var i = 0; i < pattern.groups.length; i++) {
      final g = pattern.groups[i];
      final shifts = _generate(state, pattern, cycle,
          offset: g.offset, uidSuffix: '-dg${i + 1}');
      if (shifts.isEmpty) {
        skipped++;
        continue;
      }
      final ics = IcsService.buildIcs(
        shifts: shifts,
        templatesById: state.templatesById,
        from: _exportRange!.start,
        to: _exportRange!.end,
      );
      final safe = g.name.replaceAll(RegExp(r'[^\wäöüÄÖÜß-]+'), '_');
      files.add((
        'schichten_${safe}_${PatternService.dateKey(_exportRange!.start)}_${PatternService.dateKey(_exportRange!.end)}.ics',
        ics
      ));
    }
    if (files.isEmpty) {
      _snack('Keine Dienste in den Gruppen im gewählten Zeitraum');
      return;
    }
    final saved =
        await FileIo.saveTextFiles(files: files, mimeType: 'text/calendar');
    if (!mounted) return;
    if (saved > 0) {
      _snack(
          '$saved ICS-Datei(en) gespeichert${skipped > 0 ? ', $skipped Gruppe(n) ohne Dienste übersprungen' : ''}');
    }
  }

  @override
  void dispose() {
    _spacing.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Lösch-Warnung im Vorlagen-Screen**

In `lib/screens/templates_screen.dart`, Methode `_delete`: den
`content: Text(...)`-Ausdruck ersetzen durch:

```dart
        content: Text([
          count > 0
              ? 'Achtung: $count eingeplante Schichten mit dieser Vorlage werden mitgelöscht.'
              : 'Die Vorlage wird gelöscht.',
          if (state.pattern.entries.contains(template.id))
            'Das eingetragene Muster im Reiter „Muster" wird dabei zurückgesetzt.',
        ].join('\n\n')),
```

- [ ] **Step 4: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 5: Manuell verifizieren** (Controller macht das, nicht der Subagent)

- [ ] **Step 6: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/screens/pattern_screen.dart lib/screens/home_shell.dart lib/screens/templates_screen.dart
git commit -m "feat: Muster-Reiter mit Zykluserkennung, ICS-Export und Dienstgruppen"
```

---

### Task F: Offene Review-Fixes Monats-Solls

Aus dem Abschluss-Review des Monats-Solls-Features (zwei „Important"-Punkte).
`lib/services/storage_service.dart` enthält dafür bereits eine uncommittete
Änderung (Feld `quotasMigrated` + `migrated`-Logik in `fromJson`) — prüfen und
weiterverwenden.

**Files:**
- Modify: `lib/services/storage_service.dart` (liegt evtl. schon im Working Tree)
- Modify: `lib/state/app_state.dart`
- Modify: `lib/screens/templates_screen.dart` (Body-Umbau)
- Test: `test/storage_service_test.dart`

- [ ] **Step 1: Failing Test**

In `test/storage_service_test.dart`, Gruppe `AppData quotas`, neuer Test:

```dart
    test('Migration setzt quotasMigrated, vorhandener Key nicht', () {
      expect(AppData.fromJson(oldJson).quotasMigrated, isTrue);
      expect(AppData.fromJson({...oldJson, 'quotas': []}).quotasMigrated,
          isFalse);
    });
```

- [ ] **Step 2: Storage-Flag sicherstellen**

In `lib/services/storage_service.dart` muss vorhanden sein (evtl. schon da):

- Feld in `AppData`:

```dart
  /// true, wenn [fromJson] einen alten Datenstand (ohne quotas-Key)
  /// migriert hat — dann direkt speichern, damit der neue Stand persistiert.
  bool quotasMigrated = false;
```

- In `fromJson`: `var migrated = false;` vor dem `if (json.containsKey('quotas'))`,
  `migrated = true;` als erste Zeile des `else`-Zweigs, und das
  `return AppData(...)` endet mit `)..quotasMigrated = migrated;`.

- [ ] **Step 3: Sofort-Speichern nach Migration**

In `lib/state/app_state.dart`, Methode `load()`:

```dart
  Future<void> load() async {
    _data = await _storage.load();
    loaded = true;
    // Migrierte Solls sofort persistieren, nicht erst bei nächster Änderung.
    if (_data.quotasMigrated) _scheduleSave();
    notifyListeners();
    // Abos im Hintergrund aktualisieren, UI nicht blockieren.
    unawaited(syncAllSubscriptions());
  }
```

- [ ] **Step 4: Soll-Abschnitt auch ohne Vorlagen anzeigen**

In `lib/screens/templates_screen.dart`: den `body:`-Ausdruck so umbauen, dass
die ListView IMMER gerendert wird. Der bisherige Empty-State-Text wird erstes
ListView-Kind statt eigener Center-Zweig:

```dart
      body: ListView(children: [
        if (state.templates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Noch keine Schichtvorlagen.\n\n'
              'Lege z.B. „Frühschicht F 06:00–14:00" an – '
              'die Vorlagen ziehst du dann im Planer per Drag&Drop auf die Tage.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final t in state.templates)
          ListTile(
          ... (bestehender Inhalt unverändert)
```

Das `state.templates.isEmpty ? Center(...) :`-Konstrukt entfällt; alles ab
`const Divider(height: 32),` bis `const SizedBox(height: 80),` bleibt wie es
ist (nur eine Einrückungsebene weniger).

- [ ] **Step 5: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/storage_service.dart lib/state/app_state.dart lib/screens/templates_screen.dart test/storage_service_test.dart
git commit -m "fix: Soll-Migration sofort speichern, Solls ohne Vorlagen erreichbar"
```
