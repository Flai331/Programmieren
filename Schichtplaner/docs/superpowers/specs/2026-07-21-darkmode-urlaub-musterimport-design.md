# Design: Dark Mode + Urlaubsrechner + Web-Muster-Import

Datum: 2026-07-21
Status: vom Nutzer freigegeben

Drei unabhängige Features für die Schichtplaner-App, zusammen umgesetzt:

1. **Dark Mode** — Theme-Umschalter System/Hell/Dunkel.
2. **Urlaubsrechner** — Urlaub als Kalender-Eintrag, Urlaubskonto in Tagen + Stunden.
3. **Web-Muster-Import** — `schichtplaner_muster.json` aus dem alten Web-Tool
   in den Muster-Reiter laden (Vorlagen-Mapping, Rückgängig).

---

## Feature 1: Dark Mode

### Modell
- `AppSettings.themeMode`: `'system'` | `'light'` | `'dark'` (Default `'system'`).
  toJson/fromJson mit Default.

### App-Theme
- `main.dart`: `MaterialApp` in ein Widget auslagern, das
  `context.watch<AppState>()` liest, damit Umschalten sofort neu baut.
  - `theme`: bestehendes Light-Theme (`ColorScheme.fromSeed(seedColor:
    0xFF00696D)`, M3).
  - `darkTheme`: `ColorScheme.fromSeed(seedColor: 0xFF00696D,
    brightness: Brightness.dark)`, M3.
  - `themeMode`: aus Settings gemappt
    (`system`→`ThemeMode.system`, usw.).

### UI
- **Einstellungen**: neuer Abschnitt „Darstellung" mit SegmentedButton
  System / Hell / Dunkel.

### Randfälle
- Fest kodierte Farben (Vorlagen-Farben, Ampel grün/orange/rot,
  Urlaubs-Farbe) bleiben — sie funktionieren in beiden Modi. Text auf
  farbigen Badges nutzt schon `ThemeData.estimateBrightnessForColor`
  (schwarz/weiß automatisch), bleibt also lesbar. Cards, Scaffold,
  Navigation, Dialoge kommen aus `Theme` und passen sich automatisch an.

---

## Feature 2: Urlaubsrechner

### Konzept
Ein Urlaubstag ist ein Tages-Eintrag im Kalender (technisch eine Schicht
mit `kind: 'vacation'`). Er zählt einen festen Stundenwert
(`hoursPerVacationDay`, Default 8) ins Monats-Stundenziel (wie bezahlte
Arbeit → Monatssaldo bleibt ausgeglichen) und verbraucht 1 Tag vom
Urlaubskonto. Urlaubskonto pro Jahr: Anspruch + Übertrag − genommen,
angezeigt in Tagen UND Stunden.

### Modell
- `Shift.kind`: `'work'` (Default) | `'vacation'`. toJson/fromJson mit
  Default `'work'` (alte Daten = alles Arbeit, kein Bruch). Urlaubs-Shift
  hat `templateId == null`.
  - `displayName(template)`: bei `kind=='vacation'` → `'Urlaub'`.
  - `isVacation` getter für Lesbarkeit.
- `AppSettings`:
  - `annualVacationDays` (double, Default 30) — Jahresanspruch.
  - `hoursPerVacationDay` (double, Default 8).
  - `vacationStartCarry` (double, Default 0) — Resturlaub, der ins erste
    Jahr mit Urlaubsdaten übertragen wird (Seed für die Übertrag-Kette).

### Stunden-Integration (`HoursService`)
- `actualHours` bekommt zusätzlich `AppSettings settings`. Pro Schicht:
  `kind=='vacation'` → `+ hoursPerVacationDay*60` Minuten, sonst wie bisher
  `netMinutes(template)`. Damit fließen Urlaubsstunden automatisch in
  Monatssaldo, Übertrag und Statistik. Aufrufer (`balanceFor`, `carryInto`,
  `statistics_screen`, Tests) reichen `settings` durch.

### Urlaubskonto (`VacationService`, pure Statics)
```dart
class VacationBalance {
  final int year;
  final double entitlement; // Jahresanspruch
  final double carryIn;     // Übertrag Vorjahr
  final double taken;       // genommene Tage im Jahr
  double get remainingDays => entitlement + carryIn - taken;
}
```
- `takenDays(shifts, year)` = Anzahl `kind=='vacation'`-Schichten mit
  `day.year == year`.
- Übertrag-Kette (analog Stunden-Übertrag: nur Jahre mit Daten):
  - `firstYear` = kleinstes Jahr unter den Urlaubs-Schichten (keine → year).
  - `carryIn(firstYear) = vacationStartCarry`; für Jahre davor 0.
  - `carryIn(Y) = remainingDays(Y-1)` für `Y > firstYear` (rekursiv ab
    firstYear).
- `balanceFor(shifts, settings, year) → VacationBalance`.
- Stunden = Tage × `hoursPerVacationDay` (im UI berechnet).

### Erfassung im Planer
- In der Vorlagen-/Aktionsleiste ein **„Urlaub"-Eintrag** (fester Chip
  „U", eigene Farbe, z.B. Amber) neben den Vorlagen. Auf einen gewählten
  Tag angewandt → legt Urlaubs-Shift an (`AppState.addVacation(day)`).
  Löschen wie andere Schichten im Tages-Detail.
- Rendering in Monats-/Wochenansicht: Urlaubs-Shift wie eine Schicht, aber
  fixe Urlaubs-Farbe + Kürzel „U"/Label „Urlaub" (Sonderfall in den
  Badge-/Chip-Widgets).

### UI Urlaubskonto
- **Statistik-Screen** (schon nach Jahr): neue Karte „Urlaub":
  Anspruch · Übertrag Vorjahr · genommen · **Rest: X Tage (Y h)**.
- **Einstellungen**: neuer Abschnitt „Urlaub" — Jahresanspruch (Tage),
  Stunden pro Urlaubstag, Resturlaub-Startwert (Tage).

### ICS-Export
- Urlaubs-Shift wird als Ganztags-Termin „Urlaub" exportiert
  (`IcsService`: bei `kind=='vacation'` DATE-Wert + SUMMARY „Urlaub").

### Bewusst weggelassen (YAGNI)
Halbtags-Urlaub, Krank-Kategorie, per-Jahr-Anspruch-Overrides. `kind` ist
erweiterbar.

---

## Feature 3: Web-Muster-Import (Muster-Reiter)

### Format (aus `SCHICHTPLANER.html`, `savePatternFile`)
```json
{ "app":"schichtplaner", "version":1,
  "shifts":[{"id","name","code","start","end","color","allDay"}],
  "patternStart":"YYYY-MM-DD",
  "entries":["<shiftId>"|"frei", ...],
  "fullCycle":bool,
  "groups":[{"name","offset"}] }
```

### Parsing (`PatternImportService.parseWebPattern`, pure + testbar)
```dart
class WebPatternResult {
  final String? error;                 // null = ok
  final ShiftPattern? pattern;         // fertig gemapptes Muster
  final List<ShiftTemplate> newTemplates; // neu anzulegen
  final int matchedCount;              // wiederverwendete Vorlagen
}

static WebPatternResult parseWebPattern(
  String jsonText,
  List<ShiftTemplate> existing,
  String Function() newId, // Id-Generator injizierbar (Test)
);
```
Ablauf:
1. JSON parsen; Fehler / `app != 'schichtplaner'` / `shifts` fehlt /
   `entries` fehlt → `error`.
2. Je Web-Schicht → App-Vorlage:
   - Match in `existing`: erst `abbreviation == code`, sonst `name == name`
     (beide getrimmt, case-insensitive). Treffer → dessen Id
     (`matchedCount++`).
   - Kein Treffer → neue `ShiftTemplate` (id via `newId()`):
     `name`, `abbreviation=code`, `colorValue` aus `#rrggbb`
     (→ `0xFF000000 | hex`), `start`/`end`, `isAllDay=allDay`. Landet in
     `newTemplates`.
   - `idMap[webId] = templateId`; `idMap['frei'] = freiEntryId`.
3. `entries` per `idMap` umschreiben; unbekannte Id → `error`.
4. `pattern` = `ShiftPattern(startDate: patternStart, entries: remapped,
   fullCycle, groups: [PatternGroup(name, offset)…])`.

### Anwenden + Rückgängig (`AppState`)
- `applyWebPattern(String jsonText) → WebPatternResult`:
  parse; bei `error` nichts ändern und zurückgeben. Sonst Snapshot
  `(List.of(_data.templates), _data.pattern)` merken, `newTemplates` adden,
  `_data.pattern` ersetzen, `_changed()`.
- `undoWebPatternImport()`: Snapshot zurückspielen (Vorlagen-Liste
  ersetzen — entfernt die neu angelegten — und Muster zurücksetzen),
  `_changed()`. Snapshot danach verwerfen.

### UI
- Muster-Reiter: neue Karte „Muster-Datei laden" mit Button →
  `FileIo.openTextFile(extensions:['json'])`. Ergebnis-Snackbar:
  „Muster geladen: X Vorlagen neu, Y erkannt" mit **Rückgängig**-Aktion.
  Fehler → Fehler-Snackbar.

### Tests (`pattern_import_service_test`)
- Match per Kürzel; Match per Name; neue Vorlage bei keinem Treffer;
  `frei`-Mapping; unbekannte Entry-Id → Fehler; kaputtes JSON → Fehler;
  falsche `app` → Fehler; Gruppen + `fullCycle` übernommen;
  Farb-Parsing `#rrggbb`.

---

## Storage / Kompatibilität (alle Features)
Neue Felder in `AppSettings` (themeMode, annualVacationDays,
hoursPerVacationDay, vacationStartCarry) und `Shift` (kind) haben Defaults
in `fromJson` → alte Datendateien/Backups laden unverändert. Kein
Migrations-Schritt nötig.

## Test-Übersicht
- `AppSettings`/`Shift` Roundtrip mit neuen Feldern.
- `HoursService`: Urlaubstag zählt `hoursPerVacationDay` ins Monatsziel.
- `VacationService`: Übertrag-Kette, genommen zählen, Rest Tage+Stunden.
- `PatternImportService`: siehe Feature 3.
- Dark Mode: kein Unit-Test (Theme-Verdrahtung) — `flutter analyze` +
  manuelle Sicht.
