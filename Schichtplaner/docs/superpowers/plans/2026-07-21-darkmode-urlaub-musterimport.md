# Dark Mode + Urlaubsrechner + Web-Muster-Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei Features für die Schichtplaner-Flutter-App: (1) Dark-Mode-Umschalter, (2) Urlaubsrechner mit Urlaubstagen als Kalender-Eintrag und Urlaubskonto in Tagen+Stunden, (3) Import von Web-Tool-Muster-Dateien in den Muster-Reiter.

**Architecture:** Neue Felder mit Defaults in `AppSettings` und `Shift` (abwärtskompatibel). Urlaub = `Shift` mit `kind:'vacation'`, zählt fixe Stunden über `HoursService`. Reine, unit-getestete Services (`VacationService`, `PatternImportService`). Theme reaktiv über Provider in `main.dart`. UI-Erweiterungen in Planer, Statistik, Einstellungen, Muster-Reiter.

**Tech Stack:** Flutter/Dart, Provider, fl_chart, file_selector, flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-21-darkmode-urlaub-musterimport-design.md`

**Repo:** `C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app` ist ein EIGENES Git-Repo, Branch `feature/monats-solls`. Alle `flutter`/`git`-Kommandos dort. Jeder Commit staged nur die genannten Dateien.

**Farbkonstante Urlaub:** `0xFFFFB300` (Amber), als `Shift.vacationColorValue` definiert (Task 3).

---

### Task 1: AppSettings — themeMode + Urlaubs-Felder

**Files:**
- Modify: `lib/models/app_settings.dart`
- Test: `test/app_settings_test.dart` (neu)

- [ ] **Step 1: Failing Test**

`test/app_settings_test.dart` (neu):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/app_settings.dart';

void main() {
  group('AppSettings neue Felder', () {
    test('Defaults', () {
      final s = AppSettings();
      expect(s.themeMode, 'system');
      expect(s.annualVacationDays, 30);
      expect(s.hoursPerVacationDay, 8);
      expect(s.vacationStartCarry, 0);
    });

    test('JSON-Roundtrip erhält neue Felder', () {
      final s = AppSettings(
        themeMode: 'dark',
        annualVacationDays: 28,
        hoursPerVacationDay: 7.7,
        vacationStartCarry: 5,
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.themeMode, 'dark');
      expect(r.annualVacationDays, 28);
      expect(r.hoursPerVacationDay, 7.7);
      expect(r.vacationStartCarry, 5);
    });

    test('Alte JSON ohne neue Keys → Defaults', () {
      final r = AppSettings.fromJson({'targetMode': 'fixed'});
      expect(r.themeMode, 'system');
      expect(r.annualVacationDays, 30);
      expect(r.hoursPerVacationDay, 8);
      expect(r.vacationStartCarry, 0);
    });
  });
}
```

- [ ] **Step 2: rot** — `cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app; flutter test test/app_settings_test.dart` → FAIL (Felder fehlen)

- [ ] **Step 3: Felder ergänzen**

In `lib/models/app_settings.dart`:

Neue Felder deklarieren (nach `String lastView;`):

```dart

  /// Theme: 'system' | 'light' | 'dark'.
  String themeMode;

  /// Jahres-Urlaubsanspruch in Tagen.
  double annualVacationDays;

  /// Stunden, die ein Urlaubstag zählt (ins Monatsziel).
  double hoursPerVacationDay;

  /// Resturlaub (Tage), der ins erste Jahr mit Urlaubsdaten übertragen wird.
  double vacationStartCarry;
```

Konstruktor-Parameter ergänzen (im benannten Konstruktor, nach `this.lastView = 'month',`):

```dart
    this.themeMode = 'system',
    this.annualVacationDays = 30,
    this.hoursPerVacationDay = 8,
    this.vacationStartCarry = 0,
```

In `toJson()` nach `'lastView': lastView,` ergänzen:

```dart
        'themeMode': themeMode,
        'annualVacationDays': annualVacationDays,
        'hoursPerVacationDay': hoursPerVacationDay,
        'vacationStartCarry': vacationStartCarry,
```

In `fromJson` nach `lastView: json['lastView'] as String? ?? 'month',` ergänzen:

```dart
        themeMode: json['themeMode'] as String? ?? 'system',
        annualVacationDays:
            (json['annualVacationDays'] as num?)?.toDouble() ?? 30,
        hoursPerVacationDay:
            (json['hoursPerVacationDay'] as num?)?.toDouble() ?? 8,
        vacationStartCarry:
            (json['vacationStartCarry'] as num?)?.toDouble() ?? 0,
```

- [ ] **Step 4: grün** — `flutter test test/app_settings_test.dart` → PASS (3)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/models/app_settings.dart test/app_settings_test.dart
git commit -m "feat: AppSettings um themeMode und Urlaubs-Felder erweitert"
```

---

### Task 2: Dark Mode — Theme-Verdrahtung + Umschalter

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/settings_screen.dart`

Kein Unit-Test (Theme-Verdrahtung); Absicherung `flutter analyze` + volle Suite.

- [ ] **Step 1: main.dart reaktiv machen**

In `lib/main.dart` den `build` von `SchichtplanerApp` ersetzen. Neue Fassung der Klasse:

```dart
class SchichtplanerApp extends StatelessWidget {
  final AppState state;
  const SchichtplanerApp({super.key, required this.state});

  static const _seed = Color(0xFF00696D);

  ThemeMode _themeMode(String mode) => switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'Schichtplaner',
          debugShowCheckedModeBanner: false,
          locale: const Locale('de', 'DE'),
          supportedLocales: const [Locale('de', 'DE')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: _seed),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: _seed, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: _themeMode(state.settings.themeMode),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Umschalter in Einstellungen**

In `lib/screens/settings_screen.dart` im `ListView` direkt nach dem öffnenden `children: [` (also vor `_section(context, 'Stundenziel'),`) einfügen:

```dart
        _section(context, 'Darstellung'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('System')),
              ButtonSegment(value: 'light', label: Text('Hell')),
              ButtonSegment(value: 'dark', label: Text('Dunkel')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) {
              settings.themeMode = s.first;
              state.updateSettings();
            },
          ),
        ),
        const Divider(),
```

- [ ] **Step 3: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 4: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/main.dart lib/screens/settings_screen.dart
git commit -m "feat: Dark Mode – System/Hell/Dunkel umschaltbar"
```

---

### Task 3: Shift — kind (Urlaub) + Präsentations-Helfer

**Files:**
- Modify: `lib/models/shift.dart`
- Test: `test/shift_kind_test.dart` (neu)
- Test: `test/ics_service_test.dart` (ein Test ergänzen)

- [ ] **Step 1: Failing Tests**

`test/shift_kind_test.dart` (neu):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/shift.dart';

void main() {
  group('Shift kind (Urlaub)', () {
    test('Default kind=work, isVacation=false', () {
      final s = Shift(id: '1', date: '2026-07-01');
      expect(s.kind, 'work');
      expect(s.isVacation, isFalse);
    });

    test('Urlaubs-Shift: isVacation, displayName, isAllDay', () {
      final s = Shift(id: '2', date: '2026-07-02', kind: 'vacation');
      expect(s.isVacation, isTrue);
      expect(s.displayName(null), 'Urlaub');
      expect(s.isAllDay(null), isTrue);
    });

    test('JSON-Roundtrip erhält kind, alte JSON = work', () {
      final s = Shift(id: '3', date: '2026-07-03', kind: 'vacation');
      expect(Shift.fromJson(s.toJson()).kind, 'vacation');
      final old = Shift.fromJson({'id': '4', 'date': '2026-07-04'});
      expect(old.kind, 'work');
    });
  });
}
```

In `test/ics_service_test.dart` innerhalb der `group('ICS-Export', ...)` einen Test ergänzen (Import oben `import 'package:schichtplaner/models/shift.dart';` ist dort bereits vorhanden):

```dart
    test('Urlaubstag wird als Ganztags-Termin „Urlaub" exportiert', () {
      final ics = IcsService.buildIcs(
        shifts: [Shift(id: 'u', date: '2026-07-10', kind: 'vacation')],
        templatesById: {},
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 31),
      );
      expect(ics, contains('DTSTART;VALUE=DATE:20260710'));
      expect(ics, contains('SUMMARY:Urlaub'));
    });
```

- [ ] **Step 2: rot** — `flutter test test/shift_kind_test.dart` → FAIL (kein `kind`)

- [ ] **Step 3: Shift erweitern**

In `lib/models/shift.dart`:

Statische Farbkonstante + Feld ergänzen. Im Klassenkopf nach `bool importedAllDay;` einfügen:

```dart

  /// 'work' (Standard) | 'vacation' (Urlaubstag).
  String kind;

  /// Feste Farbe für Urlaubstage (Amber).
  static const int vacationColorValue = 0xFFFFB300;
```

Konstruktor-Parameter ergänzen (nach `this.importedAllDay = false,`):

```dart
    this.kind = 'work',
```

Getter nach `bool get isImported => source == 'imported';` ergänzen:

```dart
  bool get isVacation => kind == 'vacation';
```

`displayName` ersetzen durch:

```dart
  /// Anzeigename (Urlaub, Vorlagenname oder Termin-Titel).
  String displayName(ShiftTemplate? template) {
    if (isVacation) return 'Urlaub';
    return template?.name ?? title ?? 'Schicht';
  }
```

`isAllDay` ersetzen durch:

```dart
  bool isAllDay(ShiftTemplate? template) =>
      isVacation || (template?.isAllDay ?? importedAllDay);
```

In `toJson()` nach `'importedAllDay': importedAllDay,` ergänzen:

```dart
        'kind': kind,
```

In `fromJson` nach `importedAllDay: json['importedAllDay'] as bool? ?? false,` ergänzen:

```dart
        kind: json['kind'] as String? ?? 'work',
```

- [ ] **Step 4: grün** — `flutter test test/shift_kind_test.dart test/ics_service_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/models/shift.dart test/shift_kind_test.dart test/ics_service_test.dart
git commit -m "feat: Shift.kind für Urlaubstage (all-day, ICS-Export)"
```

---

### Task 4: HoursService — Urlaubsstunden ins Monatsziel

**Files:**
- Modify: `lib/services/hours_service.dart`
- Modify: `lib/screens/statistics_screen.dart` (Aufruf-Anpassung)
- Test: `test/hours_service_test.dart`

`actualHours` bekommt `AppSettings settings` und zählt Urlaubstage mit `hoursPerVacationDay`.

- [ ] **Step 1: Failing Test**

In `test/hours_service_test.dart` in der `group('HoursService', ...)` neuen Test ergänzen (Import `app_settings.dart` und `shift.dart` sind vorhanden):

```dart
    test('Urlaubstag zählt hoursPerVacationDay ins Monatsziel', () {
      final settings = AppSettings(hoursPerVacationDay: 8);
      final shifts = [
        Shift(id: 'f', date: '2026-07-01', templateId: 'f'), // 7,5 h
        Shift(id: 'u', date: '2026-07-02', kind: 'vacation'), // 8 h
      ];
      final h = HoursService.actualHours(shifts, templates, settings, '2026-07');
      expect(h, closeTo(7.5 + 8, 0.001));
    });
```

Außerdem: alle bestehenden `HoursService.actualHours(...)`-Aufrufe im Test um das `settings`-Argument erweitern. Betroffen sind die Aufrufe in den Tests „Monatsstunden: Schicht zählt zum Monat des Beginns" (zwei Aufrufe). Neue Form:
`HoursService.actualHours(shifts, templates, AppSettings(), '2026-07')` bzw. `... '2026-08')`.

- [ ] **Step 2: rot** — `flutter test test/hours_service_test.dart` → FAIL (Signatur / fehlendes Argument)

- [ ] **Step 3: actualHours anpassen**

In `lib/services/hours_service.dart` die Methode `actualHours` ersetzen durch:

```dart
  /// Netto-Stunden aller Schichten eines Monats.
  /// Eine Schicht zählt komplett zum Monat ihres Beginn-Tags.
  /// Urlaubstage zählen [AppSettings.hoursPerVacationDay] Stunden.
  static double actualHours(
    List<Shift> shifts,
    Map<String, ShiftTemplate> templatesById,
    AppSettings settings,
    String yearMonth,
  ) {
    var minutes = 0;
    for (final s in shifts) {
      if (!s.date.startsWith(yearMonth)) continue;
      if (s.isVacation) {
        minutes += (settings.hoursPerVacationDay * 60).round();
        continue;
      }
      minutes += s.netMinutes(
          s.templateId != null ? templatesById[s.templateId] : null);
    }
    return minutes / 60.0;
  }
```

In derselben Datei die zwei internen Aufrufer anpassen:
- In `carryInto`: `actualHours(shifts, templatesById, m)` → `actualHours(shifts, templatesById, settings, m)` (die Methode `carryInto` hat `settings` bereits als Parameter).
- In `balanceFor`: `actualHours(shifts, templatesById, yearMonth)` → `actualHours(shifts, templatesById, settings, yearMonth)`.

- [ ] **Step 4: statistics_screen-Aufruf anpassen**

In `lib/screens/statistics_screen.dart` den Aufruf
`HoursService.actualHours(state.shifts, templatesById, ym)` ersetzen durch
`HoursService.actualHours(state.shifts, templatesById, state.settings, ym)`.

- [ ] **Step 5: grün** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/hours_service.dart lib/screens/statistics_screen.dart test/hours_service_test.dart
git commit -m "feat: Urlaubstage zählen ins Monats-Stundenziel"
```

---

### Task 5: VacationService — Urlaubskonto

**Files:**
- Create: `lib/services/vacation_service.dart`
- Test: `test/vacation_service_test.dart` (neu)

- [ ] **Step 1: Failing Tests**

`test/vacation_service_test.dart` (neu):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/app_settings.dart';
import 'package:schichtplaner/models/shift.dart';
import 'package:schichtplaner/services/vacation_service.dart';

void main() {
  Shift vac(String date) => Shift(id: date, date: date, kind: 'vacation');
  Shift work(String date) =>
      Shift(id: 'w$date', date: date, templateId: 't');

  group('VacationService', () {
    test('takenDays zählt nur Urlaubstage des Jahres', () {
      final shifts = [
        vac('2026-07-01'),
        vac('2026-07-02'),
        work('2026-07-03'),
        vac('2025-12-30'),
      ];
      expect(VacationService.takenDays(shifts, 2026), 2);
      expect(VacationService.takenDays(shifts, 2025), 1);
    });

    test('Rest = Anspruch + Übertrag − genommen, Kette rollt', () {
      final settings = AppSettings(
          annualVacationDays: 30, hoursPerVacationDay: 8, vacationStartCarry: 5);
      final shifts = [
        for (var i = 1; i <= 10; i++)
          vac('2026-07-${i.toString().padLeft(2, '0')}'), // 10 Tage 2026
        for (var i = 1; i <= 20; i++)
          vac('2027-03-${i.toString().padLeft(2, '0')}'), // 20 Tage 2027
      ];
      // 2026: 30 + 5 − 10 = 25
      final b26 = VacationService.balanceFor(shifts, settings, 2026);
      expect(b26.carryIn, 5);
      expect(b26.taken, 10);
      expect(b26.remainingDays, 25);
      // 2027: Übertrag 25, 30 + 25 − 20 = 35
      final b27 = VacationService.balanceFor(shifts, settings, 2027);
      expect(b27.carryIn, 25);
      expect(b27.remainingDays, 35);
    });

    test('Ohne Urlaubsdaten: Rest = Anspruch + Startwert', () {
      final settings =
          AppSettings(annualVacationDays: 30, vacationStartCarry: 0);
      final b = VacationService.balanceFor([], settings, 2026);
      expect(b.carryIn, 0);
      expect(b.taken, 0);
      expect(b.remainingDays, 30);
    });
  });
}
```

- [ ] **Step 2: rot** — `flutter test test/vacation_service_test.dart` → FAIL (Service fehlt)

- [ ] **Step 3: Service implementieren**

`lib/services/vacation_service.dart` (neu):

```dart
import '../models/app_settings.dart';
import '../models/shift.dart';

/// Urlaubskonto eines Jahres (in Tagen; Stunden = Tage × Std/Urlaubstag).
class VacationBalance {
  final int year;
  final double entitlement; // Jahresanspruch
  final double carryIn;     // Übertrag Vorjahr
  final double taken;       // genommene Tage im Jahr

  const VacationBalance({
    required this.year,
    required this.entitlement,
    required this.carryIn,
    required this.taken,
  });

  double get remainingDays => entitlement + carryIn - taken;
}

/// Rechnet Urlaubsanspruch, Übertrag und Rest aus den Urlaubstagen
/// (Schichten mit kind=='vacation'). Übertrag-Kette startet beim ersten
/// Jahr mit Urlaubsdaten (Seed: [AppSettings.vacationStartCarry]), damit
/// Jahre ohne Daten keinen künstlichen Übertrag erzeugen.
class VacationService {
  static double takenDays(List<Shift> shifts, int year) {
    var n = 0;
    for (final s in shifts) {
      if (s.isVacation && s.day.year == year) n++;
    }
    return n.toDouble();
  }

  static int? _firstYear(List<Shift> shifts) {
    int? first;
    for (final s in shifts) {
      if (!s.isVacation) continue;
      final y = s.day.year;
      if (first == null || y < first) first = y;
    }
    return first;
  }

  /// Übertrag INS Jahr [year].
  static double _carryInto(
      List<Shift> shifts, AppSettings settings, int year, int firstYear) {
    if (year <= firstYear) return year == firstYear ? settings.vacationStartCarry : 0;
    var balance = settings.vacationStartCarry; // = Übertrag in firstYear
    for (var y = firstYear; y < year; y++) {
      balance = settings.annualVacationDays + balance - takenDays(shifts, y);
    }
    return balance;
  }

  static VacationBalance balanceFor(
      List<Shift> shifts, AppSettings settings, int year) {
    final first = _firstYear(shifts) ?? year;
    return VacationBalance(
      year: year,
      entitlement: settings.annualVacationDays,
      carryIn: _carryInto(shifts, settings, year, first),
      taken: takenDays(shifts, year),
    );
  }
}
```

- [ ] **Step 4: grün** — `flutter test test/vacation_service_test.dart` → PASS (3)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/vacation_service.dart test/vacation_service_test.dart
git commit -m "feat: VacationService – Urlaubskonto mit Übertrag-Kette"
```

---

### Task 6: AppState — addVacation

**Files:**
- Modify: `lib/state/app_state.dart`

Kein eigener Test (State/Timer-Kopplung); Absicherung `flutter analyze` + Suite.

- [ ] **Step 1: Methode ergänzen**

In `lib/state/app_state.dart` im Schichten-Abschnitt nach `Shift addShift(...)` (endet mit `return shift;` `}`) einfügen:

```dart

  /// Urlaubstag für [day] anlegen (max. einer pro Tag). Zählt
  /// hoursPerVacationDay ins Monatsziel und 1 Tag vom Urlaubskonto.
  Shift? addVacation(DateTime day) {
    final key = dateKey(day);
    if (_data.shifts.any((s) => s.date == key && s.isVacation)) return null;
    final shift = Shift(id: _uuid.v4(), date: key, kind: 'vacation');
    _data.shifts.add(shift);
    _changed();
    return shift;
  }
```

(`dateKey` und `_uuid` existieren bereits in AppState.)

- [ ] **Step 2: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 3: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/state/app_state.dart
git commit -m "feat: AppState.addVacation legt Urlaubstag an"
```

---

### Task 7: Planer — Urlaub eintragen + Urlaub im Kalender anzeigen

**Files:**
- Modify: `lib/screens/planner_screen.dart` (Urlaubs-Chip in Sidebar + Bottom-Bar)
- Modify: `lib/widgets/month_grid.dart` (Urlaub-Chip färben/beschriften)
- Modify: `lib/widgets/week_view.dart` (Urlaub-Ganztages-Chip färben)

- [ ] **Step 1: month_grid – Urlaub im Tages-Chip**

In `lib/widgets/month_grid.dart` in der Methode `_chip` die drei `final`-Zeilen für `color`/`textColor`/`label` ersetzen. Vorher:

```dart
    final template =
        shift.templateId != null ? state.templatesById[shift.templateId] : null;
    final color = template?.color ?? Colors.blueGrey;
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final label = template != null
        ? (template.abbreviation.isNotEmpty
            ? template.abbreviation
            : template.name)
        : (shift.title ?? 'Import');
```

Nachher:

```dart
    final template =
        shift.templateId != null ? state.templatesById[shift.templateId] : null;
    final color = shift.isVacation
        ? const Color(Shift.vacationColorValue)
        : (template?.color ?? Colors.blueGrey);
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final label = shift.isVacation
        ? 'Urlaub'
        : (template != null
            ? (template.abbreviation.isNotEmpty
                ? template.abbreviation
                : template.name)
            : (shift.title ?? 'Import'));
```

(`Shift` ist in month_grid bereits importiert.)

- [ ] **Step 2: week_view – Urlaub-Ganztages-Chip**

In `lib/widgets/week_view.dart` im `_DayHeader.build`, in der `for (final s in allDayItems)`-Schleife das `_allDayChip(...)` so anpassen, dass Urlaub die Urlaubsfarbe bekommt. Vorher:

```dart
          for (final s in allDayItems)
            _allDayChip(
                context,
                s.displayName(s.templateId != null
                    ? state.templatesById[s.templateId]
                    : null),
                (s.templateId != null
                        ? state.templatesById[s.templateId]?.color
                        : null) ??
                    Colors.blueGrey,
                () => onShiftTap(s)),
```

Nachher:

```dart
          for (final s in allDayItems)
            _allDayChip(
                context,
                s.displayName(s.templateId != null
                    ? state.templatesById[s.templateId]
                    : null),
                s.isVacation
                    ? const Color(Shift.vacationColorValue)
                    : ((s.templateId != null
                            ? state.templatesById[s.templateId]?.color
                            : null) ??
                        Colors.blueGrey),
                () => onShiftTap(s)),
```

(`Shift` ist in week_view bereits importiert. Urlaubs-Shifts sind all-day → sie erscheinen automatisch in `allDayItems`.)

- [ ] **Step 3: Planer – Urlaubs-Chip (Sidebar)**

In `lib/screens/planner_screen.dart` in `_templateSidebar`, im Zweig
`if (!showTabs || _sidebarTab == 'templates') ...[ ... ]`, direkt VOR der Zeile
`Expanded(child: _templateList(state)),` einfügen:

```dart
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _vacationChip(state, _selectedDay!),
            ),
```

- [ ] **Step 4: Planer – Urlaubs-Chip (Bottom-Bar) + Helfer**

In `lib/screens/planner_screen.dart` in `_templateBottomBar`, im `Row(children: [ ... ])`, direkt VOR `Expanded(` (dem mit der horizontalen Vorlagen-Liste) einfügen:

```dart
        if (sel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _vacationChip(state, sel),
          ),
```

Und die Helfer-Methode in der `_PlannerScreenState`-Klasse ergänzen (z.B. direkt nach `_trashTarget`):

```dart
  /// Chip „Urlaub" — trägt für den gewählten Tag einen Urlaubstag ein.
  Widget _vacationChip(AppState state, DateTime day) {
    return ActionChip(
      avatar: const Icon(Icons.beach_access, size: 16),
      label: const Text('Urlaub'),
      backgroundColor:
          const Color(Shift.vacationColorValue).withValues(alpha: 0.25),
      onPressed: () {
        if (state.addVacation(day) == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('An diesem Tag ist schon Urlaub eingetragen')));
        }
      },
    );
  }
```

(`Shift` ist in planner_screen bereits importiert.)

- [ ] **Step 5: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/screens/planner_screen.dart lib/widgets/month_grid.dart lib/widgets/week_view.dart
git commit -m "feat: Urlaub im Planer eintragen und im Kalender anzeigen"
```

---

### Task 8: Statistik-Karte + Einstellungen für Urlaub

**Files:**
- Modify: `lib/screens/statistics_screen.dart` (Urlaub aus Arbeits-Zählern raus + Urlaubs-Karte)
- Modify: `lib/screens/settings_screen.dart` (Abschnitt „Urlaub")

- [ ] **Step 1: Urlaub aus den Arbeits-Zählern nehmen**

In `lib/screens/statistics_screen.dart` in der Schleife `for (final s in state.shifts) { ... }` direkt nach `if (d.year != _year) continue;` einfügen:

```dart
      if (s.isVacation) continue; // Urlaub separat im Urlaubskonto
```

- [ ] **Step 2: Urlaubs-Karte rendern**

In `lib/screens/statistics_screen.dart` oben Import ergänzen:

```dart
import '../services/vacation_service.dart';
```

Im `body`-`ListView`, nach dem `Text('Jahr gesamt: ...')` am Ende (letztes Kind), davor/dahinter eine Urlaubs-Karte einfügen — konkret direkt nach dem `Wrap`-Block der Stat-Cards (nach dessen schließendem `),`) einfügen:

```dart
        const SizedBox(height: 16),
        Builder(builder: (context) {
          final v =
              VacationService.balanceFor(state.shifts, state.settings, _year);
          final hpd = state.settings.hoursPerVacationDay;
          String d(double x) =>
              x.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.beach_access, size: 20),
                      const SizedBox(width: 8),
                      Text('Urlaub $_year',
                          style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    Text('Anspruch: ${d(v.entitlement)} Tage'),
                    Text('Übertrag Vorjahr: ${d(v.carryIn)} Tage'),
                    Text('Genommen: ${d(v.taken)} Tage'),
                    const SizedBox(height: 4),
                    Text(
                      'Rest: ${d(v.remainingDays)} Tage  (${d(v.remainingDays * hpd)} h)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ]),
            ),
          );
        }),
```

- [ ] **Step 3: Einstellungen – Abschnitt „Urlaub"**

In `lib/screens/settings_screen.dart` direkt vor `const Divider(),` `_section(context, 'Feiertage'),` (also am Ende des Ampel/Übertrag-Blocks, vor dem Feiertage-Abschnitt) einfügen:

```dart
        const Divider(),
        _section(context, 'Urlaub'),
        ListTile(
          title: const Text('Jahres-Urlaubsanspruch'),
          trailing: Text('${_fmt(settings.annualVacationDays)} Tage',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: () => _editNumber(
            context,
            title: 'Urlaubsanspruch pro Jahr',
            value: settings.annualVacationDays,
            suffix: 'Tage',
            onSave: (v) {
              settings.annualVacationDays = v;
              state.updateSettings();
            },
          ),
        ),
        ListTile(
          title: const Text('Stunden pro Urlaubstag'),
          subtitle: const Text('So viel zählt ein Urlaubstag ins Monatsziel'),
          trailing: Text('${_fmt(settings.hoursPerVacationDay)} h',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: () => _editNumber(
            context,
            title: 'Stunden pro Urlaubstag',
            value: settings.hoursPerVacationDay,
            suffix: 'h',
            onSave: (v) {
              settings.hoursPerVacationDay = v;
              state.updateSettings();
            },
          ),
        ),
        ListTile(
          title: const Text('Resturlaub-Startwert'),
          subtitle:
              const Text('Übertrag ins erste Jahr mit Urlaubsdaten'),
          trailing: Text('${_fmt(settings.vacationStartCarry)} Tage',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: () => _editNumber(
            context,
            title: 'Resturlaub-Startwert',
            value: settings.vacationStartCarry,
            suffix: 'Tage',
            onSave: (v) {
              settings.vacationStartCarry = v;
              state.updateSettings();
            },
          ),
        ),
```

Hinweis: `_editNumber` erlaubt nur Werte `>= 0` — passt für alle drei.

- [ ] **Step 4: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/screens/statistics_screen.dart lib/screens/settings_screen.dart
git commit -m "feat: Urlaubskonto in Statistik + Urlaubs-Einstellungen"
```

---

### Task 9: PatternImportService — Web-Muster parsen

**Files:**
- Create: `lib/services/pattern_import_service.dart`
- Test: `test/pattern_import_service_test.dart` (neu)

- [ ] **Step 1: Failing Tests**

`test/pattern_import_service_test.dart` (neu):

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplaner/models/shift_pattern.dart';
import 'package:schichtplaner/models/shift_template.dart';
import 'package:schichtplaner/services/pattern_import_service.dart';

void main() {
  ShiftTemplate tpl(String id, String abbr, String name) => ShiftTemplate(
      id: id, name: name, abbreviation: abbr, colorValue: 0);

  String web(Map<String, dynamic> m) => jsonEncode({
        'app': 'schichtplaner',
        'version': 1,
        'shifts': m['shifts'],
        'patternStart': m['patternStart'] ?? '2026-07-01',
        'entries': m['entries'],
        'fullCycle': m['fullCycle'] ?? false,
        'groups': m['groups'] ?? [],
      });

  var counter = 0;
  String newId() => 'new${counter++}';

  setUp(() => counter = 0);

  test('Match per Kürzel, kein neuer Template', () {
    final json = web({
      'shifts': [
        {'id': 'w1', 'name': 'Frühschicht', 'code': 'F',
         'start': '06:00', 'end': '14:00', 'color': '#ff0000', 'allDay': false}
      ],
      'entries': ['w1', 'frei'],
    });
    final r = PatternImportService.parseWebPattern(
        json, [tpl('t1', 'F', 'Irgendwas')], newId);
    expect(r.error, isNull);
    expect(r.newTemplates, isEmpty);
    expect(r.matchedCount, 1);
    expect(r.pattern!.entries, ['t1', 'frei']);
  });

  test('Match per Name wenn Kürzel abweicht', () {
    final json = web({
      'shifts': [
        {'id': 'w1', 'name': 'Nachtschicht', 'code': 'X',
         'start': '21:00', 'end': '06:00', 'color': '#00ff00', 'allDay': false}
      ],
      'entries': ['w1'],
    });
    final r = PatternImportService.parseWebPattern(
        json, [tpl('t9', 'N', 'Nachtschicht')], newId);
    expect(r.error, isNull);
    expect(r.matchedCount, 1);
    expect(r.pattern!.entries, ['t9']);
  });

  test('Kein Treffer → neue Vorlage angelegt, Farbe geparst', () {
    final json = web({
      'shifts': [
        {'id': 'w1', 'name': 'Spät', 'code': 'S',
         'start': '14:00', 'end': '22:00', 'color': '#0000ff', 'allDay': false}
      ],
      'entries': ['w1'],
    });
    final r = PatternImportService.parseWebPattern(json, [], newId);
    expect(r.error, isNull);
    expect(r.newTemplates, hasLength(1));
    expect(r.newTemplates.first.abbreviation, 'S');
    expect(r.newTemplates.first.colorValue, 0xFF0000FF);
    expect(r.pattern!.entries, [r.newTemplates.first.id]);
  });

  test('frei bleibt frei, groups + fullCycle übernommen', () {
    final json = web({
      'shifts': [
        {'id': 'w1', 'name': 'F', 'code': 'F', 'start': '06:00',
         'end': '14:00', 'color': '#ffffff', 'allDay': false}
      ],
      'entries': ['w1', 'frei'],
      'fullCycle': true,
      'groups': [{'name': 'DG2', 'offset': 3}],
    });
    final r = PatternImportService.parseWebPattern(json, [], newId);
    expect(r.pattern!.entries, [r.newTemplates.first.id, 'frei']);
    expect(r.pattern!.fullCycle, isTrue);
    expect(r.pattern!.groups.single.name, 'DG2');
    expect(r.pattern!.groups.single.offset, 3);
  });

  test('Unbekannte Entry-Id → Fehler', () {
    final json = web({
      'shifts': [
        {'id': 'w1', 'name': 'F', 'code': 'F', 'start': '06:00',
         'end': '14:00', 'color': '#ffffff', 'allDay': false}
      ],
      'entries': ['w1', 'w999'],
    });
    final r = PatternImportService.parseWebPattern(json, [], newId);
    expect(r.error, isNotNull);
    expect(r.pattern, isNull);
  });

  test('Kaputtes JSON und falsche app → Fehler', () {
    expect(PatternImportService.parseWebPattern('{kaputt', [], newId).error,
        isNotNull);
    expect(
        PatternImportService.parseWebPattern(
                jsonEncode({'app': 'anders', 'shifts': [], 'entries': []}),
                [],
                newId)
            .error,
        isNotNull);
  });
}
```

- [ ] **Step 2: rot** — `flutter test test/pattern_import_service_test.dart` → FAIL (Service fehlt)

- [ ] **Step 3: Service implementieren**

`lib/services/pattern_import_service.dart` (neu):

```dart
import 'dart:convert';

import '../models/shift_pattern.dart';
import '../models/shift_template.dart';

/// Ergebnis eines Web-Muster-Imports.
class WebPatternResult {
  final String? error; // null = ok
  final ShiftPattern? pattern; // fertig gemapptes Muster
  final List<ShiftTemplate> newTemplates; // neu anzulegende Vorlagen
  final int matchedCount; // wiederverwendete Vorlagen

  const WebPatternResult({
    this.error,
    this.pattern,
    this.newTemplates = const [],
    this.matchedCount = 0,
  });

  factory WebPatternResult.fail(String message) =>
      WebPatternResult(error: message);
}

/// Liest die `schichtplaner_muster.json` des alten Web-Tools und bildet sie
/// auf App-Vorlagen + ein [ShiftPattern] ab. Rein (kein State), testbar.
class PatternImportService {
  /// [newId] erzeugt Ids für neu angelegte Vorlagen (injizierbar für Tests).
  static WebPatternResult parseWebPattern(
    String jsonText,
    List<ShiftTemplate> existing,
    String Function() newId,
  ) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        return WebPatternResult.fail('Datei ist kein gültiges Muster.');
      }
      json = decoded;
    } catch (_) {
      return WebPatternResult.fail('Datei ist kein gültiges JSON.');
    }
    if (json['app'] != 'schichtplaner') {
      return WebPatternResult.fail('Keine Schichtplaner-Muster-Datei.');
    }
    final rawShifts = json['shifts'];
    final rawEntries = json['entries'];
    if (rawShifts is! List || rawEntries is! List) {
      return WebPatternResult.fail('Muster-Datei unvollständig.');
    }

    final newTemplates = <ShiftTemplate>[];
    var matched = 0;
    final idMap = <String, String>{freiEntryId: freiEntryId};

    String norm(String s) => s.trim().toLowerCase();

    for (final raw in rawShifts) {
      if (raw is! Map) continue;
      final webId = raw['id'] as String?;
      if (webId == null) continue;
      final code = (raw['code'] as String? ?? '').trim();
      final name = (raw['name'] as String? ?? '').trim();

      ShiftTemplate? match;
      for (final t in existing) {
        if (code.isNotEmpty && norm(t.abbreviation) == norm(code)) {
          match = t;
          break;
        }
      }
      match ??= () {
        for (final t in existing) {
          if (name.isNotEmpty && norm(t.name) == norm(name)) return t;
        }
        return null;
      }();

      if (match != null) {
        matched++;
        idMap[webId] = match.id;
      } else {
        final t = ShiftTemplate(
          id: newId(),
          name: name.isEmpty ? (code.isEmpty ? 'Schicht' : code) : name,
          abbreviation: code,
          colorValue: _parseColor(raw['color'] as String?),
          start: raw['start'] as String? ?? '08:00',
          end: raw['end'] as String? ?? '16:00',
          isAllDay: raw['allDay'] as bool? ?? false,
        );
        newTemplates.add(t);
        idMap[webId] = t.id;
      }
    }

    final entries = <String>[];
    for (final e in rawEntries) {
      final id = e as String?;
      if (id == null || !idMap.containsKey(id)) {
        return WebPatternResult.fail(
            'Muster verweist auf eine unbekannte Schicht.');
      }
      entries.add(idMap[id]!);
    }

    final groups = <PatternGroup>[];
    final rawGroups = json['groups'];
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is! Map) continue;
        groups.add(PatternGroup(
          name: g['name'] as String? ?? '',
          offset: (g['offset'] as num?)?.toInt() ?? 0,
        ));
      }
    }

    final pattern = ShiftPattern(
      startDate: json['patternStart'] as String? ?? '',
      entries: entries,
      fullCycle: json['fullCycle'] as bool? ?? false,
      groups: groups,
    );

    return WebPatternResult(
      pattern: pattern,
      newTemplates: newTemplates,
      matchedCount: matched,
    );
  }

  /// '#rrggbb' → 0xFFrrggbb; ungültig → Standardblau.
  static int _parseColor(String? hex) {
    if (hex == null) return 0xFF2196F3;
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return 0xFF2196F3;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return 0xFF2196F3;
    return 0xFF000000 | v;
  }
}
```

- [ ] **Step 4: grün** — `flutter test test/pattern_import_service_test.dart` → PASS (6)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/services/pattern_import_service.dart test/pattern_import_service_test.dart
git commit -m "feat: PatternImportService – Web-Muster-Dateien parsen"
```

---

### Task 10: AppState — applyWebPattern + Rückgängig

**Files:**
- Modify: `lib/state/app_state.dart`

Kein eigener Test; `flutter analyze` + Suite. Der pure Parse-Teil ist in Task 9 getestet.

- [ ] **Step 1: Import + Undo-Feld + Methoden**

In `lib/state/app_state.dart`:

Import ergänzen (bei den Service-Imports):

```dart
import '../services/pattern_import_service.dart';
```

Feld für den Undo-Snapshot deklarieren (bei den anderen Feldern, nach `Timer? _saveTimer;`):

```dart
  (List<ShiftTemplate>, ShiftPattern)? _patternImportUndo;
```

Im Muster-Abschnitt (nach `updatePattern()`) einfügen:

```dart

  /// Web-Muster-Datei anwenden: fehlende Vorlagen anlegen, Muster ersetzen.
  /// Vorher wird ein Snapshot für [undoWebPatternImport] gesichert.
  WebPatternResult applyWebPattern(String jsonText) {
    final res = PatternImportService.parseWebPattern(
        jsonText, _data.templates, () => _uuid.v4());
    if (res.error != null) return res;
    _patternImportUndo = (List.of(_data.templates), _data.pattern);
    _data.templates.addAll(res.newTemplates);
    _data.pattern = res.pattern!;
    _changed();
    return res;
  }

  bool get canUndoPatternImport => _patternImportUndo != null;

  /// Letzten Web-Muster-Import rückgängig machen (Vorlagen + Muster zurück).
  void undoWebPatternImport() {
    final snap = _patternImportUndo;
    if (snap == null) return;
    _data.templates
      ..clear()
      ..addAll(snap.$1);
    _data.pattern = snap.$2;
    _patternImportUndo = null;
    _changed();
  }
```

Hinweis: `ShiftTemplate` und `ShiftPattern` sind in app_state.dart bereits importiert (Muster-Task C bzw. Vorlagen).

- [ ] **Step 2: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 3: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/state/app_state.dart
git commit -m "feat: AppState.applyWebPattern mit Rückgängig"
```

---

### Task 11: Muster-Reiter — Datei laden Karte

**Files:**
- Modify: `lib/screens/pattern_screen.dart`

- [ ] **Step 1: Import + Lade-Karte**

In `lib/screens/pattern_screen.dart`:

Import ergänzen (bei den Service-Imports):

```dart
import '../services/file_io.dart';
```

(Falls `file_io.dart` schon importiert ist, diesen Schritt überspringen.)

Im `build`-`ListView` (die Karten-Liste) als erstes Kind — vor `_entryCard(state, pattern)` — einfügen:

```dart
        _importCard(state),
```

Und die Methode in `_PatternScreenState` ergänzen (z.B. nach `build`):

```dart
  Widget _importCard(AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Muster-Datei laden',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'Lädt eine schichtplaner_muster.json aus dem alten Web-Tool. '
              'Fehlende Vorlagen werden angelegt, vorhandene per Kürzel/Name erkannt.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _loadFile(state),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Datei wählen'),
          ),
        ]),
      ),
    );
  }

  Future<void> _loadFile(AppState state) async {
    final content = await FileIo.openTextFile(extensions: ['json']);
    if (content == null || !mounted) return;
    final res = state.applyWebPattern(content);
    if (!mounted) return;
    if (res.error != null) {
      _snack(res.error!);
      return;
    }
    setState(() {
      _exportRange = null;
      _preview = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Muster geladen: ${res.newTemplates.length} Vorlagen neu, ${res.matchedCount} erkannt'),
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () => state.undoWebPatternImport(),
      ),
    ));
  }
```

(`_snack`, `_exportRange`, `_preview`, `AppState` sind in `_PatternScreenState` bereits vorhanden.)

- [ ] **Step 2: Analyze + Tests** — `flutter analyze; flutter test` → sauber, alle PASS

- [ ] **Step 3: Manuell verifizieren** (Controller, nicht Subagent): App starten, Muster-Reiter → „Datei wählen" mit einer alten `schichtplaner_muster.json` → Muster + Vorlagen erscheinen, Rückgängig funktioniert.

- [ ] **Step 4: Commit**

```bash
cd C:\Users\klaas\Desktop\Programmieren\Schichtplaner\app
git add lib/screens/pattern_screen.dart
git commit -m "feat: Web-Muster-Datei im Muster-Reiter laden"
```
