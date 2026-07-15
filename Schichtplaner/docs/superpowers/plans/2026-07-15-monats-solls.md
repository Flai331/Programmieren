# Monats-Solls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Frei einstellbare Monats-Solls: „mindestens N Schichten pro Monat aus einer Gruppe von Schichtvorlagen" (z. B. 10 Spätschichten aus 3 Vorlagen, beliebige Mischung). Ersetzt das bisherige `minPerMonth` pro Einzelvorlage inkl. automatischer Migration.

**Architecture:** Neues Model `ShiftQuota` (Name, Mindestanzahl, Vorlagen-IDs), gespeichert als `quotas`-Liste in der bestehenden JSON-Datendatei (`AppData`). `HoursService.missingQuotas` zählt Monats-Schichten gruppenübergreifend. UI: neuer Abschnitt „Monats-Solls" im Vorlagen-Screen mit Editor-Dialog (Vorlagen als FilterChips). Migration in `AppData.fromJson`, wenn der `quotas`-Key fehlt.

**Tech Stack:** Flutter/Dart, Provider (`AppState extends ChangeNotifier`), JSON-Datei-Storage (`StorageService`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-14-schicht-solls-design.md`

**Arbeitsverzeichnis:** `C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app` (alle `flutter`-Kommandos dort ausführen). Git-Repo-Root liegt höher; `git add` mit Pfaden relativ zu `Schichtplaner/` funktioniert aus `Schichtplaner\` heraus.

---

### Task 1: ShiftQuota-Model

**Files:**
- Create: `app/lib/models/shift_quota.dart`
- Test: `app/test/shift_quota_test.dart`

- [ ] **Step 1: Failing Test schreiben**

`app/test/shift_quota_test.dart` (neue Datei):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/shift_quota.dart';

void main() {
  group('ShiftQuota', () {
    test('JSON-Roundtrip', () {
      final q = ShiftQuota(
        id: 'q1',
        name: 'Spätschichten',
        minPerMonth: 10,
        templateIds: ['a', 'b'],
      );
      final restored = ShiftQuota.fromJson(q.toJson());
      expect(restored.id, 'q1');
      expect(restored.name, 'Spätschichten');
      expect(restored.minPerMonth, 10);
      expect(restored.templateIds, ['a', 'b']);
    });

    test('Defaults bei fehlenden Feldern', () {
      final q = ShiftQuota.fromJson({'id': 'x'});
      expect(q.name, '');
      expect(q.minPerMonth, 0);
      expect(q.templateIds, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/shift_quota_test.dart`
Expected: FAIL (Compile-Fehler: `shift_quota.dart` existiert nicht)

- [ ] **Step 3: Model implementieren**

`app/lib/models/shift_quota.dart` (neue Datei):

```dart
/// Frei einstellbares Monats-Soll: mindestens [minPerMonth] Schichten aus
/// den zugeordneten Vorlagen pro Monat (z. B. "Spätschichten": min. 10,
/// beliebige Mischung der zugeordneten Vorlagen).
class ShiftQuota {
  final String id;
  String name;
  int minPerMonth; // 0 = inaktiv
  List<String> templateIds; // zugeordnete Schichtvorlagen

  ShiftQuota({
    required this.id,
    required this.name,
    this.minPerMonth = 0,
    List<String>? templateIds,
  }) : templateIds = templateIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'minPerMonth': minPerMonth,
        'templateIds': templateIds,
      };

  factory ShiftQuota.fromJson(Map<String, dynamic> json) => ShiftQuota(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        minPerMonth: json['minPerMonth'] as int? ?? 0,
        templateIds:
            (json['templateIds'] as List?)?.map((e) => e as String).toList(),
      );
}
```

- [ ] **Step 4: Test laufen lassen — muss bestehen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/shift_quota_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/models/shift_quota.dart app/test/shift_quota_test.dart
git commit -m "feat: ShiftQuota-Model für Monats-Solls"
```

---

### Task 2: HoursService.missingQuotas

**Files:**
- Modify: `app/lib/services/hours_service.dart` (Import ergänzen, neue Methode; `missingMinimums` bleibt vorerst — wird in Task 5 entfernt)
- Test: `app/test/hours_service_test.dart`

- [ ] **Step 1: Failing Tests schreiben**

In `app/test/hours_service_test.dart` oben Import ergänzen:

```dart
import 'package:schichtplaner/models/shift_quota.dart';
```

Am Ende der `group('HoursService', ...)` (nach dem Test `'Ampel: grün, gelb, rot in beide Richtungen'`) neue Tests einfügen:

```dart
    test('Monats-Soll: Schichten aller zugeordneten Vorlagen zählen zusammen',
        () {
      final quota = ShiftQuota(
        id: 'q1',
        name: 'Spätschichten',
        minPerMonth: 3,
        templateIds: ['s1', 's2'],
      );
      final shifts = [
        Shift(id: '1', date: '2026-07-01', templateId: 's1'),
        Shift(id: '2', date: '2026-07-02', templateId: 's2'),
        Shift(id: '3', date: '2026-07-03', templateId: 'x'), // zählt nicht
        Shift(id: '4', date: '2026-08-01', templateId: 's1'), // anderer Monat
      ];
      final missing = HoursService.missingQuotas(shifts, [quota], '2026-07');
      expect(missing, hasLength(1));
      expect(missing.first.$1.id, 'q1');
      expect(missing.first.$2, 1); // 2 von 3 geplant

      // Dritte Gruppen-Schicht (egal welche Vorlage) → erfüllt
      shifts.add(Shift(id: '5', date: '2026-07-10', templateId: 's2'));
      expect(HoursService.missingQuotas(shifts, [quota], '2026-07'), isEmpty);
    });

    test('Monats-Soll: Vorlage in zwei Solls zählt in beiden', () {
      final a = ShiftQuota(
          id: 'a', name: 'A', minPerMonth: 1, templateIds: ['t']);
      final b = ShiftQuota(
          id: 'b', name: 'B', minPerMonth: 2, templateIds: ['t']);
      final shifts = [Shift(id: '1', date: '2026-07-01', templateId: 't')];
      final missing = HoursService.missingQuotas(shifts, [a, b], '2026-07');
      expect(missing, hasLength(1)); // a erfüllt (1 von 1)
      expect(missing.first.$1.id, 'b');
      expect(missing.first.$2, 1);
    });

    test('Monats-Soll: min 0 ist inaktiv, Soll ohne Vorlagen bleibt offen',
        () {
      final inactive = ShiftQuota(
          id: 'i', name: 'I', minPerMonth: 0, templateIds: ['t']);
      final empty = ShiftQuota(id: 'e', name: 'E', minPerMonth: 2);
      final shifts = [Shift(id: '1', date: '2026-07-01', templateId: 't')];
      final missing =
          HoursService.missingQuotas(shifts, [inactive, empty], '2026-07');
      expect(missing, hasLength(1));
      expect(missing.first.$1.id, 'e');
      expect(missing.first.$2, 2);
    });
```

- [ ] **Step 2: Tests laufen lassen — müssen fehlschlagen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/hours_service_test.dart`
Expected: FAIL (Compile-Fehler: `missingQuotas` existiert nicht)

- [ ] **Step 3: Methode implementieren**

In `app/lib/services/hours_service.dart` oben Import ergänzen:

```dart
import '../models/shift_quota.dart';
```

Direkt **nach** der Methode `missingMinimums` (Zeile ~135) einfügen:

```dart
  /// Monats-Solls: wie viele Schichten aus den zugeordneten Vorlagen
  /// fehlen noch? Liefert nur Solls, deren Vorgabe nicht erfüllt ist.
  /// Eine Vorlage kann in mehreren Solls stecken und zählt dann in jedem.
  static List<(ShiftQuota, int)> missingQuotas(
    List<Shift> shifts,
    List<ShiftQuota> quotas,
    String yearMonth,
  ) {
    final counts = <String, int>{}; // Vorlagen-Id → Anzahl im Monat
    for (final s in shifts) {
      if (!s.date.startsWith(yearMonth) || s.templateId == null) continue;
      counts[s.templateId!] = (counts[s.templateId!] ?? 0) + 1;
    }
    final result = <(ShiftQuota, int)>[];
    for (final q in quotas) {
      if (q.minPerMonth <= 0) continue;
      var count = 0;
      for (final id in q.templateIds) {
        count += counts[id] ?? 0;
      }
      if (count < q.minPerMonth) result.add((q, q.minPerMonth - count));
    }
    return result;
  }
```

- [ ] **Step 4: Tests laufen lassen — müssen bestehen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/hours_service_test.dart`
Expected: PASS (alle Tests, inkl. der 3 neuen)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/services/hours_service.dart app/test/hours_service_test.dart
git commit -m "feat: missingQuotas zählt Monats-Solls gruppenübergreifend"
```

---

### Task 3: Storage — quotas-Liste + Migration

**Files:**
- Modify: `app/lib/services/storage_service.dart` (`AppData`)
- Test: `app/test/storage_service_test.dart` (neue Datei; testet nur `AppData`, kein Datei-IO)

- [ ] **Step 1: Failing Tests schreiben**

`app/test/storage_service_test.dart` (neue Datei):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/services/storage_service.dart';

void main() {
  group('AppData quotas', () {
    // Roh-JSON wie ein alter Datenstand (vor Einführung der Solls):
    // Vorlage t1 hatte minPerMonth 3, t2 keine Vorgabe.
    final oldJson = {
      'templates': [
        {
          'id': 't1',
          'name': 'Nacht',
          'abbreviation': 'N',
          'colorValue': 0,
          'minPerMonth': 3,
        },
        {
          'id': 't2',
          'name': 'Früh',
          'abbreviation': 'F',
          'colorValue': 0,
        },
      ],
    };

    test('Migration: minPerMonth > 0 wird zu Soll mit einer Vorlage', () {
      final data = AppData.fromJson(oldJson);
      expect(data.quotas, hasLength(1));
      final q = data.quotas.first;
      expect(q.name, 'Nacht');
      expect(q.minPerMonth, 3);
      expect(q.templateIds, ['t1']);
    });

    test('Vorhandener quotas-Key (auch leer) → keine Re-Migration', () {
      final data = AppData.fromJson({...oldJson, 'quotas': []});
      expect(data.quotas, isEmpty);
    });

    test('JSON-Roundtrip enthält quotas', () {
      final data = AppData.fromJson(oldJson);
      final restored = AppData.fromJson(data.toJson());
      expect(restored.quotas, hasLength(1));
      expect(restored.quotas.first.templateIds, ['t1']);
    });
  });
}
```

- [ ] **Step 2: Tests laufen lassen — müssen fehlschlagen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/storage_service_test.dart`
Expected: FAIL (Compile-Fehler: `AppData` hat kein `quotas`)

- [ ] **Step 3: AppData erweitern**

In `app/lib/services/storage_service.dart`:

Import ergänzen (bei den anderen Model-Imports):

```dart
import '../models/shift_quota.dart';
```

`AppData` um das Feld erweitern — Klassenkopf ändern zu:

```dart
/// Alles was gespeichert wird, als ein Objekt.
class AppData {
  List<ShiftTemplate> templates;
  List<Shift> shifts;
  List<CalendarSubscription> subscriptions;
  List<DayNote> dayNotes;
  List<ShiftQuota> quotas;
  AppSettings settings;

  AppData({
    List<ShiftTemplate>? templates,
    List<Shift>? shifts,
    List<CalendarSubscription>? subscriptions,
    List<DayNote>? dayNotes,
    List<ShiftQuota>? quotas,
    AppSettings? settings,
  })  : templates = templates ?? [],
        shifts = shifts ?? [],
        subscriptions = subscriptions ?? [],
        dayNotes = dayNotes ?? [],
        quotas = quotas ?? [],
        settings = settings ?? AppSettings();
```

In `toJson()` nach der `dayNotes`-Zeile ergänzen:

```dart
        'quotas': quotas.map((q) => q.toJson()).toList(),
```

`fromJson` von Arrow-Factory auf Block-Factory umbauen (Migration braucht Zwischenschritte) — komplette neue Fassung:

```dart
  factory AppData.fromJson(Map<String, dynamic> json) {
    final templates = (json['templates'] as List? ?? [])
        .map((e) => ShiftTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    List<ShiftQuota> quotas;
    if (json.containsKey('quotas')) {
      quotas = (json['quotas'] as List? ?? [])
          .map((e) => ShiftQuota.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // Migration alter Datenstände: minPerMonth pro Vorlage → eigenes
      // Soll mit genau dieser Vorlage. Deterministische Id, damit eine
      // wiederholte Migration (Datei noch ohne quotas-Key) idempotent ist.
      quotas = [
        for (final t in templates)
          if (t.minPerMonth > 0)
            ShiftQuota(
              id: 'quota-${t.id}',
              name: t.name,
              minPerMonth: t.minPerMonth,
              templateIds: [t.id],
            ),
      ];
    }
    return AppData(
      templates: templates,
      shifts: (json['shifts'] as List? ?? [])
          .map((e) => Shift.fromJson(e as Map<String, dynamic>))
          .toList(),
      subscriptions: (json['subscriptions'] as List? ?? [])
          .map((e) => CalendarSubscription.fromJson(e as Map<String, dynamic>))
          .toList(),
      dayNotes: (json['dayNotes'] as List? ?? [])
          .map((e) => DayNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      quotas: quotas,
      settings: json['settings'] != null
          ? AppSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : AppSettings(),
    );
  }
```

- [ ] **Step 4: Tests laufen lassen — müssen bestehen**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test`
Expected: PASS (komplette Suite — auch bestehende Tests dürfen nicht brechen)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/services/storage_service.dart app/test/storage_service_test.dart
git commit -m "feat: quotas in AppData speichern, minPerMonth migrieren"
```

---

### Task 4: AppState — Solls verwalten

**Files:**
- Modify: `app/lib/state/app_state.dart`

Kein eigener Unit-Test (AppState hängt an Datei-Storage und Timer); Absicherung über `flutter analyze` + bestehende Suite. Logik ist trivial (Liste + `_changed()`).

- [ ] **Step 1: Getter und CRUD ergänzen**

In `app/lib/state/app_state.dart`:

Import ergänzen (bei den Model-Imports):

```dart
import '../models/shift_quota.dart';
```

Nach dem Getter `AppSettings get settings => _data.settings;` ergänzen:

```dart
  List<ShiftQuota> get quotas => _data.quotas;
```

Neuen Abschnitt nach dem Vorlagen-Block (nach `manualShiftCount`, vor `// Schichten`) einfügen:

```dart
  // ---------------------------------------------------------------- Solls

  void addQuota(ShiftQuota quota) {
    _data.quotas.add(quota);
    _changed();
  }

  void updateQuota() => _changed();

  void removeQuota(ShiftQuota quota) {
    _data.quotas.remove(quota);
    _changed();
  }
```

- [ ] **Step 2: deleteTemplate räumt Soll-Zuordnungen auf**

In `deleteTemplate` (app_state.dart:89) vor `_changed();` ergänzen:

```dart
    for (final q in _data.quotas) {
      q.templateIds.remove(template.id);
    }
```

- [ ] **Step 3: Analyze + Tests**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter analyze; flutter test`
Expected: analyze ohne Fehler, alle Tests PASS

- [ ] **Step 4: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/state/app_state.dart
git commit -m "feat: AppState verwaltet Monats-Solls"
```

---

### Task 5: BalanceCard auf missingQuotas umstellen, missingMinimums entfernen

**Files:**
- Modify: `app/lib/widgets/balance_card.dart:102-105`
- Modify: `app/lib/services/hours_service.dart` (`missingMinimums` löschen)
- Modify: `app/test/hours_service_test.dart` (alten Test löschen)

- [ ] **Step 1: BalanceCard umstellen**

In `app/lib/widgets/balance_card.dart` den Builder-Block (Zeile ~102) ändern von:

```dart
            // Nicht erfüllte Mindestanzahlen pro Vorlage
            Builder(builder: (context) {
              final missing = HoursService.missingMinimums(
                  state.shifts, state.templates, yearMonth);
```

zu:

```dart
            // Nicht erfüllte Monats-Solls
            Builder(builder: (context) {
              final missing = HoursService.missingQuotas(
                  state.shifts, state.quotas, yearMonth);
```

Der Rest des Blocks (Anzeige `'Fehlt noch: ${missing.map((m) => '${m.$2}× ${m.$1.name}').join(', ')}'`) bleibt unverändert — `ShiftQuota` hat ebenfalls `.name`.

- [ ] **Step 2: missingMinimums löschen**

In `app/lib/services/hours_service.dart` die komplette Methode `missingMinimums` (Zeilen ~118–135, inkl. Doku-Kommentar) entfernen.

- [ ] **Step 3: Alten Test löschen**

In `app/test/hours_service_test.dart` den Test `'Mindestanzahl pro Monat: fehlende Schichten'` (kompletter `test(...)`-Block, Zeilen ~241–267) entfernen.

- [ ] **Step 4: Analyze + Tests**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter analyze; flutter test`
Expected: analyze ohne Fehler (kein Verweis auf `missingMinimums` mehr), alle Tests PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/widgets/balance_card.dart app/lib/services/hours_service.dart app/test/hours_service_test.dart
git commit -m "feat: Bilanz-Karte warnt über Monats-Solls statt Einzelvorlagen"
```

---

### Task 6: Vorlagen-Screen — Soll-Verwaltung, altes Feld raus

**Files:**
- Modify: `app/lib/screens/templates_screen.dart`
- Modify: `app/lib/models/shift_template.dart` (`toJson` schreibt `minPerMonth` nicht mehr)

- [ ] **Step 1: Soll-Abschnitt in die Liste einbauen**

In `app/lib/screens/templates_screen.dart`:

Import ergänzen:

```dart
import '../models/shift_quota.dart';
```

Im `ListView` (Zeile ~36) zwischen der Vorlagen-Schleife und `const SizedBox(height: 80),` einfügen:

```dart
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: Text('Monats-Solls',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Neues Soll',
                    icon: const Icon(Icons.add),
                    onPressed: () => _editQuota(context, null),
                  ),
                ]),
              ),
              if (state.quotas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Kein Soll definiert. Ein Soll fordert eine Mindestanzahl '
                    'Schichten pro Monat aus einer Gruppe von Vorlagen — '
                    'z.B. „Spätschichten: min. 10ד mit allen Spät-Varianten.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              for (final q in state.quotas)
                ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: Text(q.name),
                  subtitle: Text('min. ${q.minPerMonth}×/Monat · '
                      '${q.templateIds.isEmpty ? 'keine Vorlagen zugeordnet' : q.templateIds.map((id) => state.templatesById[id]?.abbreviation ?? '?').join(', ')}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editQuota(context, q)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteQuota(context, q)),
                  ]),
                  onTap: () => _editQuota(context, q),
                ),
```

Hinweis: Bei leerer Vorlagenliste zeigt der Screen weiterhin nur den Empty-State — ohne Vorlagen sind Solls sinnlos, kein Sonderfall nötig.

- [ ] **Step 2: Edit-/Delete-Handler für Solls ergänzen**

In der Klasse `TemplatesScreen` nach `_edit` (Zeile ~122) einfügen:

```dart
  Future<void> _editQuota(BuildContext context, ShiftQuota? quota) async {
    await showDialog(
      context: context,
      builder: (context) => _QuotaDialog(quota: quota),
    );
  }

  Future<void> _deleteQuota(BuildContext context, ShiftQuota quota) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${quota.name}" löschen?'),
        content:
            const Text('Nur das Soll wird gelöscht, Schichten und Vorlagen '
                'bleiben erhalten.'),
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
    if (ok == true) state.removeQuota(quota);
  }
```

- [ ] **Step 3: Soll-Editor-Dialog anlegen**

Ans Dateiende von `templates_screen.dart` anhängen:

```dart
class _QuotaDialog extends StatefulWidget {
  final ShiftQuota? quota;
  const _QuotaDialog({this.quota});

  @override
  State<_QuotaDialog> createState() => _QuotaDialogState();
}

class _QuotaDialogState extends State<_QuotaDialog> {
  late final TextEditingController _name;
  late final TextEditingController _min;
  late Set<String> _templateIds;

  @override
  void initState() {
    super.initState();
    final q = widget.quota;
    _name = TextEditingController(text: q?.name ?? '');
    _min = TextEditingController(
        text: (q?.minPerMonth ?? 0) == 0 ? '' : q!.minPerMonth.toString());
    _templateIds = {...q?.templateIds ?? []};
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AlertDialog(
      title: Text(
          widget.quota == null ? 'Neues Monats-Soll' : 'Soll bearbeiten'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectAllTextField(
              controller: _name,
              autofocus: widget.quota == null,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'z.B. Spätschichten'),
            ),
            const SizedBox(height: 8),
            SelectAllTextField(
              controller: _min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mindestens pro Monat',
                suffixText: '×',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Zählende Vorlagen (beliebige Mischung erfüllt das Soll)',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final t in state.templates)
                FilterChip(
                  label: Text(
                      t.abbreviation.isEmpty ? t.name : t.abbreviation),
                  visualDensity: VisualDensity.compact,
                  // Haken-Platz immer reservieren, damit der Chip beim
                  // An-/Abwählen nicht breiter/schmaler wird.
                  showCheckmark: false,
                  avatar: Icon(
                      _templateIds.contains(t.id) ? Icons.check : null,
                      size: 16),
                  selected: _templateIds.contains(t.id),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _templateIds.add(t.id);
                    } else {
                      _templateIds.remove(t.id);
                    }
                  }),
                ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final min = int.tryParse(_min.text.trim()) ?? 0;
    final state = context.read<AppState>();
    // Reihenfolge wie in der Vorlagenliste, nicht Klick-Reihenfolge.
    final ids = [
      for (final t in state.templates)
        if (_templateIds.contains(t.id)) t.id,
    ];
    final existing = widget.quota;
    if (existing == null) {
      state.addQuota(ShiftQuota(
        id: const Uuid().v4(),
        name: name,
        minPerMonth: min,
        templateIds: ids,
      ));
    } else {
      existing
        ..name = name
        ..minPerMonth = min
        ..templateIds = ids;
      state.updateQuota();
    }
    Navigator.pop(context);
  }
}
```

- [ ] **Step 4: minPerMonth-Feld aus dem Vorlagen-Editor entfernen**

In `templates_screen.dart` alle `minPerMonth`-Reste entfernen:

1. Subtitle der Vorlagen-Liste (Zeile ~79): den Teil
   ```dart
                      (t.minPerMonth > 0
                          ? ' · min. ${t.minPerMonth}×/Monat'
                          : '')
   ```
   samt vorangehendem `+` löschen.
2. Controller-Deklaration `late final TextEditingController _minPerMonth;` (Zeile ~150) löschen.
3. Initialisierung in `initState` (Zeilen ~177–178) löschen.
4. Das `FocusTraversalOrder`-Widget mit dem Feld „Mindestens pro Monat" (Zeilen ~352–363) löschen.
5. In `_save`: Zeile `final minPerMonth = int.tryParse(_minPerMonth.text.trim()) ?? 0;` (Zeile ~421), Konstruktor-Argument `minPerMonth: minPerMonth,` (Zeile ~438) und Cascade `..minPerMonth = minPerMonth;` (Zeile ~451) löschen — beim Cascade davor `..allowedWeekdays = weekdays` wieder mit `;` abschließen.

- [ ] **Step 5: ShiftTemplate.toJson schreibt minPerMonth nicht mehr**

In `app/lib/models/shift_template.dart` in `toJson()` die Zeile

```dart
        'minPerMonth': minPerMonth,
```

löschen. `fromJson` liest das Feld weiterhin (nötig für die Migration in Task 3), Feld und Konstruktor-Parameter bleiben.

- [ ] **Step 6: Analyze + Tests**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter analyze; flutter test`
Expected: analyze ohne Fehler, alle Tests PASS

- [ ] **Step 7: Manuell verifizieren (App starten)**

Run: `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter run -d windows`

Checkliste:
1. Vorlagen-Screen → Abschnitt „Monats-Solls" sichtbar, Plus öffnet Dialog.
2. Soll „Spätschichten", min 3, zwei Vorlagen anhaken → speichern → erscheint in Liste mit Kürzeln.
3. Planer: 2 Schichten der Gruppe planen → Bilanz-Karte zeigt „Fehlt noch: 1× Spätschichten"; dritte planen → Hinweis weg.
4. Vorlagen-Editor: kein Feld „Mindestens pro Monat" mehr.
5. Falls Alt-Daten mit minPerMonth vorhanden: Soll wurde automatisch angelegt.

- [ ] **Step 8: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner
git add app/lib/screens/templates_screen.dart app/lib/models/shift_template.dart
git commit -m "feat: Monats-Solls im Vorlagen-Screen verwalten, minPerMonth-Feld entfernt"
```
