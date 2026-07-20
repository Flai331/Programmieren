# Schichtplaner

Flutter-App (Windows + Android): Schichten planen, Stundenbilanz/Monatsziel,
Kalender-Abos (ICS-Import), Monats-Solls, Muster-Reiter (Zykluserkennung +
ICS-Export). Ersetzt/erweitert das alte Web-Tool `SCHICHTPLANER.html`.

## Repo-Layout (wichtig!)

- **`app\` ist ein EIGENES Git-Repo** (eigenes `.git`), getrennt vom
  äußeren `Programmieren`-Repo. Code committen → in `app\` committen
  (`cd app`), Pfade relativ zu `app`. Specs/Pläne unter
  `docs\superpowers\` gehören zum äußeren Repo.
- Aktueller Feature-Branch in `app\`: `feature/monats-solls`
  (Monats-Solls + Muster-Reiter, noch nicht in `main` gemerged).

## Build + Deploy

Immer aus `app\` heraus:

- **Windows:** `flutter build windows --release`
  → Output `app\build\windows\x64\runner\Release\`
  → kompletten Ordnerinhalt nach
  `C:\Users\klaas\Desktop\Programmieren\APKs\Windows\Schichtplaner`
  kopieren (`robocopy <src> <dst> /E`). Läuft die App, vorher
  `Stop-Process -Name schichtplaner -Force`; danach über
  `explorer.exe <exe-pfad>` neu starten (AppData-Virtualisierung — nicht
  direkt starten). Die `.exe` behält ihr altes Datum, der App-Code steckt
  in `data\app.so` — DAS Datum prüfen, nicht das der exe. Verknüpfung
  `APKs\Windows\Schichtplaner.lnk` zeigt auf `Schichtplaner\schichtplaner.exe`.
- **Android:** apk nach
  `C:\Users\klaas\Desktop\Programmieren\APKs\Android` kopieren
  (siehe globale Regel in `..\CLAUDE.md`).

## Tests

`cd app; flutter test` (reine Unit-Tests, keine Widget-Tests) und
`flutter analyze` müssen vor jedem Commit sauber sein.

## Architektur

- **Storage:** eine JSON-Datei (`schichtplaner_data.json`) im
  App-Support-Verzeichnis; `AppData` = alles-in-einem
  (`storage_service.dart`). Neue persistierte Felder brauchen
  Feld + Konstruktor-Param + `toJson` + `fromJson` (mit Default für
  fehlenden Key = abwärtskompatibel).
- **State:** `AppState extends ChangeNotifier` (Provider). Jede Mutation
  ruft `_changed()` (debounced Auto-Save + `notifyListeners`).
- **Services** (statische, unit-getestete Logik): `hours_service`
  (Stunden/Ziel/Übertrag/Solls), `pattern_service` (Zyklus/Export),
  `ics_service` (ICS lesen/schreiben), `holiday_service`.
- **Models** sind schlichte Klassen mit `toJson`/`fromJson`-Factory,
  mutable Felder außer `id`.
- **Screens:** `home_shell` = Navigation (Rail breit / BottomBar schmal)
  über Reiter Planer · Vorlagen · Abos · Muster · Statistik ·
  Einstellungen.

## Konzepte

- **Monats-Soll (`ShiftQuota`):** „mind. N Schichten/Monat aus einer
  Gruppe von Vorlagen" (beliebige Mischung). Verwaltung im Vorlagen-Reiter.
- **Muster (`ShiftPattern`):** Dienstplan Tag für Tag (Vorlagen + „Frei"),
  App erkennt kleinsten Zyklus, schreibt ihn fort → ICS-Export (einzeln
  oder pro Dienstgruppe mit Versatz). Legt KEINE Planer-Schichten an.
