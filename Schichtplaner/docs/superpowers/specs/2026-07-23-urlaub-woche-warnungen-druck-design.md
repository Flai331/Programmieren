# Design: Urlaubs-Arbeitstage, Wochenansicht-Warnungen, Ruhezeit, Druckansicht

Datum: 2026-07-23
Status: vom Nutzer freigegeben

Fünf Erweiterungen der Schichtplaner-App:

1. **Urlaub nur an Arbeitstagen** — einstellbar, ob Urlaub am Wochenende/Feiertag Stunden bringt.
2. **Schicht-Notizen in der Wochenansicht** sichtbar.
3. **Terminkollisionen** im Tages-Kopf der Wochenansicht.
4. **Ruhezeit-Unterschreitung** (Standard 11 h) erkennen und warnen.
5. **Druckansicht** als HTML für einen Monat (Wünsche, Schichten, Urlaub, Notizen).

---

## 1. Urlaub nur an Arbeitstagen

### Modell
`AppSettings.vacationOnWorkdaysOnly` (bool, Default **false** = bisheriges
Verhalten, jeder Urlaubstag zählt). toJson/fromJson mit Default.

### Logik
`HoursService.actualHours`: bei `shift.isVacation` zählt der Tag nur dann
`hoursPerVacationDay`, wenn `!settings.vacationOnWorkdaysOnly` ODER der Tag
ein Arbeitstag ist. Arbeitstag = Wochentag in `settings.workdayWeekdays`
und (wenn `settings.subtractHolidays`) kein Feiertag laut
`HolidayService.holidayOn(day, settings.stateCode)`. Sonst 0 Stunden.

Gleiche Regel als wiederverwendbarer Helfer
`HoursService.isWorkday(AppSettings, DateTime)`, den auch
`workdaysInMonth` nutzt (dort bisher inline) — eine Definition, ein Ort.

Das Urlaubs**konto** (`VacationService.takenDays`) bleibt unberührt: ein
Urlaubstag verbraucht immer einen Tag, unabhängig von den Stunden.

### UI
Einstellungen → Abschnitt „Urlaub": `SwitchListTile` „Nur an Arbeitstagen
anrechnen" mit Erläuterung „Urlaub an Wochenenden/Feiertagen bringt dann
keine Stunden".

---

## 2. Schicht-Notizen in der Wochenansicht

`lib/widgets/week_view.dart`:
- Zeitgebundener Schicht-Block: unter dem Titel die Notiz in kleiner
  Schrift (`fontSize: 9`, max. 2 Zeilen, `TextOverflow.ellipsis`), wenn
  `shift.note` nicht leer. Der ganze Block bekommt ein `Tooltip` mit
  „<Schichtname> — <Notiz>", damit auch abgeschnittener Text lesbar ist.
- Ganztags-Chip im Tages-Kopf: Notiz-Icon (`Icons.notes`, size 9) hinter
  dem Text, Tooltip mit der Notiz.

Kein Datenmodell-Eingriff; `Shift.note` existiert.

---

## 3. Terminkollisionen im Tages-Kopf (Wochenansicht)

`_DayHeader` in `week_view.dart` berechnet für die Schichten des Tages
(`state.visibleShiftsOn(day)`) die Konflikte über das vorhandene
`AppState.conflictsFor(shift)`. Bei mindestens einem Konflikt erscheint
neben dem Datum ein `Icons.warning_amber_rounded` (orange, size 14) mit
`Tooltip`: „Überschneidung: <Schichtname> ↔ <Termintitel>" (mehrere
Konflikte durch `\n` getrennt).

---

## 4. Ruhezeit-Unterschreitung

### Modell
`AppSettings.minRestHours` (double, Default 11; **0 = Prüfung aus**).

### Logik — neuer `lib/services/rest_period_service.dart`
```dart
/// Eine zu kurze Ruhezeit zwischen zwei Schichten.
class RestViolation {
  final Shift previous;   // Schicht davor
  final Shift next;       // Schicht danach
  final double restHours; // tatsächliche Ruhezeit
}

class RestPeriodService {
  /// Alle Unterschreitungen im Zeitraum; [minRestHours] <= 0 → leer.
  static List<RestViolation> violations(
    List<Shift> shifts,
    Map<String, ShiftTemplate> templatesById,
    double minRestHours,
  );

  /// Unterschreitungen, die einen bestimmten Tag betreffen
  /// (Schicht davor ODER danach beginnt an diesem Tag).
  static List<RestViolation> violationsOn(
    List<Shift> shifts,
    Map<String, ShiftTemplate> templatesById,
    double minRestHours,
    DateTime day,
  );
}
```
Regeln:
- Berücksichtigt nur zeitgebundene Schichten: `isAllDay(template) == false`
  (Urlaub und Ganztags-/Bereitschaftsdienste werden übersprungen, sonst
  entstünde eine Dauerwarnung).
- Schichten chronologisch nach `startDateTime` sortieren; jeweils
  aufeinanderfolgende Paare prüfen: `rest = next.start − prev.end` in
  Stunden. `rest < minRestHours` → Verstoß. Negative Werte (echte
  Überlappung) zählen ebenfalls als Verstoß.
- Nachtschichten funktionieren automatisch, weil `endDateTime` bereits in
  den Folgetag läuft.

### UI
- Wochenansicht-Tages-Kopf und Monatsraster-Tageszelle: `Icons.bedtime_off`
  (rot, size 14) mit Tooltip „Nur 9:30 h Ruhezeit vor Spätschicht
  (mind. 11 h)".
- Einstellungen → neuer Abschnitt „Ruhezeit": Zahlenfeld „Mindest-Ruhezeit"
  (Suffix h, Hinweis „0 = keine Prüfung").

---

## 5. Druckansicht (HTML)

### Erzeugung — neuer `lib/services/print_service.dart`
```dart
static String buildMonthHtml({
  required String yearMonth,          // 'yyyy-MM'
  required List<Shift> shifts,
  required Map<String, ShiftTemplate> templatesById,
  required List<DayNote> dayNotes,
  required AppSettings settings,
  required MonthBalance balance,      // aus HoursService
  required VacationBalance vacation,  // aus VacationService
});
```
Reine String-Erzeugung (testbar, kein IO). Inhalt:

1. **Kopf**: „Dienstplan <Monat Jahr>", Erstellungsdatum.
2. **Monatsraster** (HTML-Tabelle, Mo–So): pro Tag Tagesnummer, Feiertagsname,
   geplante Schichten (Kürzel + Zeiten, Urlaub als „Urlaub"), Vormerkungen
   kursiv mit vorangestelltem „?", Tages-Kommentar klein. Wochenenden und
   Feiertage grau hinterlegt; Tage ohne jeden Eintrag bleiben leer
   (= dienstfrei).
3. **Auflistung** (Tabelle): nur Tage mit Inhalt — Datum · Wochentag ·
   Art (Schicht/Wunsch/Urlaub) · Bezeichnung · Zeiten · Notiz
   (Schicht-Notiz und Tages-Kommentar).
4. **Fuß**: geplante Stunden, Monatsziel, Saldo, genommene Urlaubstage und
   Resturlaub.

Styling inline im `<style>`-Block, druckoptimiert
(`@media print`, `@page { size: A4 landscape }` fürs Raster,
keine externen Ressourcen).

### Öffnen — `FileIo.openHtmlInBrowser(String html, String fileName)`
- Desktop: Datei ins temporäre Verzeichnis schreiben
  (`Directory.systemTemp`), dann `Process.run('cmd', ['/c', 'start', '',
  path])` unter Windows. Kein neues Paket nötig (url_launcher ist nur
  transitiv vorhanden und wird bewusst nicht direkt genutzt).
- Android/iOS: über den bestehenden Teilen-Dialog
  (`SharePlus` mit `XFile`, mimeType `text/html`) — der Nutzer wählt den
  Browser.
- Rückgabe `bool` (false = konnte nicht geöffnet werden).

### UI
Planer-Leiste: neues Drucker-Icon (`Icons.print`, Tooltip „Monat drucken")
neben dem ICS-Export. Erzeugt die HTML für den gerade angezeigten Monat
(`_anchor`) und öffnet sie. Fehlerfall → SnackBar.

---

## Datenkompatibilität
Neue Settings-Felder (`vacationOnWorkdaysOnly`, `minRestHours`) haben
Defaults in `fromJson`; alte Datendateien und Backups laden unverändert.
Kein Migrationsschritt.

## Tests
- `HoursService`: Urlaub am Wochenende/Feiertag zählt 0 bei aktivem
  `vacationOnWorkdaysOnly`, sonst volle Stunden; `isWorkday` direkt.
- `RestPeriodService`: Verstoß erkannt (Spät→Früh), kein Verstoß bei
  ausreichender Pause, Nachtschicht über Mitternacht, Ganztags/Urlaub
  übersprungen, `minRestHours == 0` → keine Prüfung, `violationsOn`
  filtert korrekt.
- `PrintService`: HTML enthält geplante Schicht, Vormerkung mit „?",
  Urlaub, Schicht-Notiz, Tages-Kommentar, Feiertagsname, Saldo-Zeile;
  leerer Monat erzeugt trotzdem gültiges HTML.
- Wochenansicht-Anzeige (Notizen, Konflikt-Icon) und Monatszellen-Icon:
  keine Tests (Widget-Ebene, Projekt hat keine Widget-Tests).
