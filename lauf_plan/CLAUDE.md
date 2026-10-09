# Laufplan – Flutter Android App

## Was die App ist
Persönlicher 4-Wochen-Trainingsplan (Laufen + Gym), Start Do 01.10.2026.
- Startseite: heutige Einheit, alle 28 Tage mit Datum, geschätzter Dauer, Erledigt-Haken
- Plan verschiebt sich: nicht erledigte Trainingseinheit rückt auf heute, alle folgenden Tage wandern mit (`computeSchedule`); Erledigt-Datum wird gespeichert (`doneOn_<tag>`), Nachtragen (`pickDoneDate`): beim Abhaken einer nachgerückten Einheit und über „Nachträglich abhaken“ auf der Heute-Karte Auswahl Heute/Gestern/wie geplant/anderes Datum; Erledigt-Datum in der Einheit änderbar – der Plan rückt entsprechend wieder vor
- Einheit: Stoppuhr gegen geschätzte Zeit, Übungen abhaken, Hinweise
- Timer pro Übung: EMOM, Halten (Arbeit/Pause automatisch), manuelle Sätze mit Pausen-Countdown
- Wechselpausen zwischen den Kraftübungen (geschätzt, `Exercise.restAfter`): Pausen-Timer mit Vorschau der nächsten Übung, danach direkt deren Timer
- Strichfiguren-Animationen für alle Gym-Übungen (CustomPainter, Start-/Endpose interpoliert)
- Erklärvideo-Knopf nur für die Bein-Übungen (öffnet YouTube-Suche), im Übungsfenster und im Timer
- Kalender-Export (.ics): alle offenen Einheiten ab heute (Startseite) oder einzeln (Einheit), Uhrzeit oder ganztägig wählbar; feste UID je Plan-Tag, erneuter Export aktualisiert Termine
- Freie Einheiten (z. B. Dehnen): Knopf „Freie Einheit“ unten rechts auf der Startseite; Datum/Uhrzeit/Dauer (Zeitansatz)/Notizen, Timer, „Zusätzlich“ oder „Statt Plan-Einheit“ (dann rückt die Plan-Einheit einen Tag nach, `blockedDates`); stehen im Plan beim jeweiligen Tag, einzeln als .ics exportierbar
- UI-Sprache: Deutsch (auch Datums-/Uhrzeitauswahl via `flutter_localizations`)

## Struktur
- `lib/main.dart` – Plan-Daten, Screens (Home, Session, Timer), Speicherung (shared_preferences)
- `lib/animations.dart` – Posen und Painter; Zuordnung über den Übungsnamen (`exerciseAnims`)
- `lib/calendar.dart` – .ics erzeugen (RFC 5545, Ortszeit ohne Zeitzone) und über `share_plus` teilen
- `lib/free_sessions.dart` – freie Einheiten: Modell, Speicher (JSON in `free_sessions`), Bearbeiten-Seite
- `lib/videos.dart` – Erklärvideos als YouTube-Suche, nur Bein-Übungen (`exerciseVideos`, öffnet per `url_launcher`)
- Liegt als Ordner `lauf_plan/` im Repo `Flai331/Programmieren` (wie der Parkplatz-Merker).
- `../.github/workflows/lauf-plan-apk.yml` – baut bei Push (main, `claude/lauf-plan-**`) eine Release-APK und aktualisiert das GitHub Release `lauf-plan` (`Laufplan.apk`)
- Der `android/`-Ordner wird im Workflow per `flutter create` erzeugt, falls er fehlt. Eingecheckt ist nur `android/app/build.gradle.kts`: feste Signatur mit `spotify_merker_android/android/app/merker-release.p12` (wie Parkplatz-Merker), Passwort aus dem Secret `MERKER_KEYSTORE_PASSWORD`. So lassen sich neue APKs als Update installieren.

## Aufgabe
1. Projekt lokal prüfen: `flutter pub get`, `flutter analyze` – Fehler beheben (Warnungen wie `withOpacity` deprecated sind egal).
2. Optional lokal testen: `flutter create --platforms=android --project-name lauf_plan --org de.klaas .` und `flutter build apk --release`.
3. GitHub-Repository `lauf_plan` anlegen (falls nicht vorhanden), alles auf `main` pushen.
4. Workflow-Lauf mit `gh run watch` beobachten. Bei Fehler: Log mit `gh run view --log-failed` lesen, fixen, erneut pushen, bis der Build grün ist.
5. Am Ende den Link zum Release mit der `app-release.apk` ausgeben.

## Regeln
- Plan-Inhalte (Übungen, Sätze, Zeiten) nicht ändern, nur Build-/Code-Fehler beheben.
- Keine neuen Abhängigkeiten ohne Grund.
