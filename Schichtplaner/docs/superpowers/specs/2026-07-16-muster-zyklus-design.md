# Design: Muster-Reiter (Zykluserkennung, ICS-Export, Dienstgruppen)

Datum: 2026-07-16
Status: vom Nutzer freigegeben (Reiter separat, eigenständig, eigener ICS-Export)

## Ziel

Die Funktionen des Web-Programms `SCHICHTPLANER.html` in die Flutter-App
übernehmen — als **eigener Reiter „Muster"**, komplett eigenständig:

1. **Dienstplan als Muster eintragen**: ab einem Startdatum Tag für Tag die
   Schicht antippen (bestehende Vorlagen + fester „Frei"-Eintrag).
2. **Automatische Zykluserkennung**: kleinste Periode p, sodass
   `entries[i] == entries[i % p]`; „erkannt" erst ab zwei vollen
   Durchläufen. Bei Teil-Wiederholung kann der Nutzer stattdessen die ganze
   Eingabe als Zyklus erzwingen (`fullCycle`).
3. **ICS-Export**: Zeitraum wählen, Vorschau ansehen, ICS-Datei speichern.
   Das Muster wird dazu in die Zukunft fortgeschrieben.
4. **Dienstgruppen**: mehrere Gruppen fahren denselben Zyklus zeitversetzt.
   Versatz pro Gruppe wählbar, automatisch verteilbar (Abstand + Richtung)
   oder per „aus bekannten Schichten ermitteln" (Probe) bestimmbar.
   Sammel-Export: Ordner wählen, eine ICS-Datei pro Gruppe.

**Kein Planer-Eingriff**: Der Muster-Reiter legt keine Schichten im Planer
an. Export erzeugt nur ICS-Dateien (Entscheidung Nutzer: „eigenen ics").

Bewusste Abweichungen zum Web-Programm:

- Keine eigenen Schichtarten — die bestehenden Schichtvorlagen der App sind
  die Eingabe-Buttons (Farbe/Kürzel/Zeiten kommen von dort). Fester
  „Frei"-Button zusätzlich.
- Kein eigenes Muster-Datei-Backup — das Muster steckt im normalen
  App-Backup (eine Datendatei).
- Browser-Downloads → Datei-Dialog (Einzel-Export) bzw. Ordner-Auswahl
  (Gruppen-Export), wie beim bestehenden Planer-ICS-Export.

## 1. Datenmodell

Neu `lib/models/shift_pattern.dart`:

```dart
/// Fester Platzhalter für "Frei" in [ShiftPattern.entries].
const String freiEntryId = 'frei';

/// Dienstgruppe: fährt denselben Zyklus um [offset] Tage versetzt.
class PatternGroup {
  String name;
  int offset; // Zyklus-Tage, 0 = wie die Eingabe

  // toJson/fromJson mit Defaults (name '', offset 0)
}

/// Eingetragenes Dienstplan-Muster.
class ShiftPattern {
  String startDate;      // 'yyyy-MM-dd' des ersten Eintrags, '' = leer
  List<String> entries;  // je Tag: Vorlagen-Id oder [freiEntryId]
  bool fullCycle;        // ganze Eingabe als Zyklus erzwingen
  List<PatternGroup> groups;

  bool get isEmpty => entries.isEmpty;

  // toJson/fromJson mit Defaults ('' / [] / false / [])
}
```

## 2. Logik (`lib/services/pattern_service.dart`)

Pure statische Methoden, unit-testbar:

```dart
/// Ergebnis der Zyklusbestimmung.
class CycleInfo {
  final List<String> cycle; // verwendeter Zyklus (Eintrags-Ids)
  final bool detected;      // >= 2 volle Durchläufe
  final bool partial;       // Teil-Wiederholung erkannt, nicht bestätigt
  final bool forced;        // Nutzer hat ganze Eingabe erzwungen
  final int autoPeriod;     // automatisch erkannte Periode
  final int totalEntries;   // Länge der Eingabe
}
```

- `detectCycle(List<String> entries) → (int period, bool detected)` —
  kleinste Periode; `detected` nur wenn `entries.length >= 2 * period`.
- `cycleOf(ShiftPattern) → CycleInfo?` — null bei leerem Muster; wertet
  `fullCycle` aus (erzwungen nur relevant wenn `period < n` und nicht
  detected, wie Web-App).
- `shiftsForRange(ShiftPattern, CycleInfo, DateTime from, DateTime to,
  {int offset = 0}) → List<Shift>` — transiente `Shift`-Objekte für alle
  Nicht-Frei-Tage im Zeitraum. Index-Formel wie Web-App:
  `idx = ((daysBetween(startDate, tag) + offset) % p + p) % p`.
  Deterministische Ids `muster-<yyyy-MM-dd>-<templateId>` (bzw. mit
  `-dg<N>`-Suffix beim Gruppen-Export), damit ICS-UIDs stabil sind.
  Vorlagen-Ids, zu denen keine Vorlage mehr existiert, werden übersprungen.
- `probeMatches(List<String> cycle, String patternStart, String probeStart,
  List<String> probeSeq) → List<int>` — alle Versätze o (0..p-1), bei denen
  die Probe-Eingabe zum Zyklus passt.
- `distributeOffsets(List<PatternGroup> groups, int period, int spacing,
  bool later)` — Gruppe i bekommt Versatz `(i*spacing) % p`, bei
  `later` gespiegelt (`(p - shift) % p`), wie Web-App.

ICS-Erzeugung: bestehendes `IcsService.buildIcs(shifts, templatesById,
from, to)` unverändert — die transienten Shifts werden direkt übergeben.
Nachtschicht-/Ganztags-Logik kommt automatisch von Vorlage + Shift.

## 3. Storage + State

- `AppData.pattern` (`ShiftPattern`), JSON-Key `pattern`; fehlt der Key →
  leeres Muster (keine Migration nötig).
- `AppState`:
  - `ShiftPattern get pattern`,
  - `patternAddEntry(String id)` (setzt beim ersten Eintrag `startDate`,
    Parameter Startdatum kommt vom Screen), `patternRemoveLast()`,
    `patternClear()` (löscht auch `fullCycle`), `patternSetStart(String)`,
    `patternSetFullCycle(bool)`, `patternSetGroups(...)` bzw. generisches
    `updatePattern()` nach Mutation — alle mit `_changed()`.
  - `deleteTemplate`: steckt die Vorlage im Muster → komplettes Muster
    zurücksetzen (entries, startDate, fullCycle; Gruppen bleiben).
    Der Lösch-Dialog im Vorlagen-Screen warnt dann zusätzlich.

## 4. UI — neuer Reiter „Muster"

`home_shell.dart`: 6. Destination `(icon: Icons.repeat, label: 'Muster')`
zwischen „Abos" und „Statistik" → `PatternScreen`
(`lib/screens/pattern_screen.dart`).

Aufbau als scrollbare Karten (analog Web-Schritte):

1. **Eintragen**: Datumsfeld „Erster Tag" (gesperrt sobald Einträge
   existieren), Buttons je Vorlage (Farbe + Kürzel) + „Frei",
   „↩ Letzten Tag löschen", „Alles zurücksetzen" (mit Bestätigung),
   Liste der eingetragenen Tage (Datum, Wochentag, Schicht-Chip),
   automatisch ans Ende gescrollt.
2. **Erkennung** (Status-Box):
   - erkannt: „✅ Muster erkannt: N-Tage-Zyklus" + Zyklus-Chips;
   - Teil-Wiederholung: „🔎 Vermutet: N-Tage-Zyklus …" + Button „ganze
     Eingabe (M Tage) als Zyklus verwenden"; erzwungen: Hinweis + Button
     zurück zur Automatik;
   - sonst: „ℹ️ Noch keine Wiederholung erkennbar — ganze Eingabe gilt als
     ein Zyklus".
3. **ICS-Export**: Von/Bis (`showDateRangePicker`, Default morgen bis +92
   Tage), „Vorschau" (Tabelle Datum/Schicht/Zeit, Anzahl-Badge),
   „ICS speichern" über `file_selector` (`getSaveLocation`), wie der
   bestehende Planer-Export.
4. **Dienstgruppen**: Anzahl (0–26), Abstand (Tage) + Richtung
   (später/früher) + „automatisch verteilen"; pro Gruppe: Name (Textfeld),
   Dropdown „war am <Startdatum> bei: Zyklus-Tag k (+ Schichtname)",
   5-Tage-Vorschau ab heute + nächster Zyklus-Beginn, Button „🔍 aus
   bekannten Schichten ermitteln" → Inline-Panel (Datum, Vorlagen-Buttons
   inkl. Frei, Chips der Eingabe, Status: eindeutig → Versatz übernommen /
   x mögliche Positionen / passt nirgends, ↩ und Abbrechen).
   „ICS für alle Gruppen": Ordner wählen (`getDirectoryPath`), pro Gruppe
   `schichten_<Gruppenname>_<von>_<bis>.ics` schreiben; Gruppen ohne
   Dienste im Zeitraum überspringen und melden.

Leere Vorlagenliste: Hinweis „Erst Schichtvorlagen anlegen" statt Buttons.

## 5. Fehlerfälle / Randfälle

- Muster leer → Erkennung/Export/Gruppen zeigen Hinweis, Buttons inaktiv.
- Startdatum fehlt → Eintragen-Buttons fordern erst Datumswahl.
- Vorlage gelöscht, die im Muster vorkommt → Muster-Reset (mit Warnung im
  Lösch-Dialog); `shiftsForRange` überspringt zusätzlich defensiv
  unbekannte Ids.
- Offsets werden überall modulo Zykluslänge gerechnet (auch negativ sicher).
- Exportzeitraum ohne Dienste (nur Frei) → Meldung, keine Datei.

## 6. Tests

`test/pattern_service_test.dart`:

- `detectCycle`: exakte Wiederholung (erkannt), Teil-Wiederholung
  (period < n, nicht erkannt), keine Wiederholung (period == n).
- `cycleOf`: fullCycle erzwingt ganze Eingabe nur bei Teil-Wiederholung.
- `shiftsForRange`: richtige Zuordnung über Zyklusgrenzen, Frei
  übersprungen, Offset verschiebt korrekt (auch modulo), unbekannte
  Vorlagen-Id übersprungen, deterministische Ids.
- `probeMatches`: eindeutig, mehrdeutig, keine Übereinstimmung.
- `distributeOffsets`: später/früher, Abstand > Zykluslänge (modulo).

Model-Roundtrip-Test für `ShiftPattern`/`PatternGroup`; Storage-Test:
fehlender `pattern`-Key → leeres Muster, Roundtrip erhält Muster.
