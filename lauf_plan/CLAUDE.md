# Laufplan – Flutter Android App

## Was die App ist
Persönlicher 4-Wochen-Trainingsplan (Laufen + Gym), Start Do 01.10.2026.
- Startseite: heutige Einheit, alle 28 Tage mit Datum, geschätzter Dauer, Erledigt-Haken
- Einheit: Stoppuhr gegen geschätzte Zeit, Übungen abhaken, Hinweise
- Timer pro Übung: EMOM, Halten (Arbeit/Pause automatisch), manuelle Sätze mit Pausen-Countdown
- Strichfiguren-Animationen für alle Gym-Übungen (CustomPainter, Start-/Endpose interpoliert)
- UI-Sprache: Deutsch

## Struktur
- `lib/main.dart` – Plan-Daten, Screens (Home, Session, Timer), Speicherung (shared_preferences)
- `lib/animations.dart` – Posen und Painter; Zuordnung über den Übungsnamen (`exerciseAnims`)
- Liegt als Ordner `lauf_plan/` im Repo `Flai331/Programmieren` (wie der Parkplatz-Merker).
- `../.github/workflows/lauf-plan-apk.yml` – baut bei Push (main, `claude/lauf-plan-**`) eine Release-APK und aktualisiert das GitHub Release `lauf-plan` (`Laufplan.apk`)
- Der `android/`-Ordner wird im Workflow per `flutter create` erzeugt, falls er fehlt. Er darf aber auch lokal erzeugt und eingecheckt werden.

## Aufgabe
1. Projekt lokal prüfen: `flutter pub get`, `flutter analyze` – Fehler beheben (Warnungen wie `withOpacity` deprecated sind egal).
2. Optional lokal testen: `flutter create --platforms=android --project-name lauf_plan --org de.klaas .` und `flutter build apk --release`.
3. GitHub-Repository `lauf_plan` anlegen (falls nicht vorhanden), alles auf `main` pushen.
4. Workflow-Lauf mit `gh run watch` beobachten. Bei Fehler: Log mit `gh run view --log-failed` lesen, fixen, erneut pushen, bis der Build grün ist.
5. Am Ende den Link zum Release mit der `app-release.apk` ausgeben.

## Regeln
- Plan-Inhalte (Übungen, Sätze, Zeiten) nicht ändern, nur Build-/Code-Fehler beheben.
- Keine neuen Abhängigkeiten ohne Grund.
