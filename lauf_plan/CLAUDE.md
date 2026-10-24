# Laufplan – Flutter Android App

## Was die App ist
Persönlicher 8-Wochen-Trainingsplan (2 Blöcke à 4 Wochen, Laufen + Gym), Start jeweils ab dem letzten Neustart (`planDays` = 56; Block 2 ab Woche 5: Umfang steigern, Bergsprints 5×, Intervalle 5×400 m, Woche 8 Entlastung). Schwerpunkt: Grundlagenausdauer + Beine; Intervalle/Bergsprints nur 1× pro Woche und kurz; Oberkörper nur Erhalt, 1× pro Woche.
- Wochenaufbau (Reihenfolge, `templateKeyFor`): 1 Grundlagenlauf (`base0-7`, nie unter 8 km: 8/8/9/9, 9/10/10/8), 2 kurze Qualität (`quality0-7`: Steigerungen / Bergsprints / Steigerungen / Intervalle …), 3 Beine A, 4 Ruhetag (optional), 5 Beine B, 6 Oberkörper (Erhalt, 3 Sätze), 7 Langer Lauf (9→12 km, Entlastungswoche 10 km). Bergsprints/Intervalle liegen so immer ≥ 4 Einheiten nach Beine B (auch ohne Ruhetag) – nie 1–3 Tage nach Beintraining (Test sichert das ab). Der Plan beginnt mit Grundlagenausdauer. Ändert sich die Reihenfolge, erhöht man `Store.planLayout`: beim nächsten Start läuft einmalig `restartPlan` (Verlauf bleibt als früherer Durchgang)
- Startseite: „Nächste Einheit“ (erste offene Trainingseinheit, `_TodayCard`) und alle Einheiten der Reihe nach ohne Termine (erledigte mit Erledigt-Datum), Erledigt-Haken. Der Plan läuft der Reihe nach, verpasste Einheiten werden nicht nachgeholt oder gestapelt; Ruhetage sind optional. „Plan ab heute neu starten“ (`Store.restartPlan`, Symbol oben): setzt `plan_start` (= `planStart`, Tag 1) auf heute, löscht Erledigt-/Übungs-Haken; Gewichte/Läufe/Protokoll bleiben als früherer Durchgang (Plan-Tag − 1000 je Neustart, `plan_gen`). Datums-Mechanik (`computeSchedule`, `doneOn_<tag>`, `pickDoneDate`, `DateTextField`, `parseUserDate`) bleibt für Kalender-Export, freie Einheiten und „Datum ändern“ in der Einheit
- Einheit: Stoppuhr gegen geschätzte Zeit, Übungen abhaken, Hinweise
- Timer pro Übung: Intervalle, Halten (Arbeit/Pause automatisch), manuelle Sätze mit Pausen-Countdown
- Oberkörper (Erhalt): Dips und Klimmzüge gewichtet (je 3 Sätze mit Zusatzgewicht, Pause 2:00 / 2:30) statt EMOM; Gewicht halten, nicht steigern
- Wechselpausen zwischen den Kraftübungen (geschätzt, `Exercise.restAfter`): Pausen-Timer mit Vorschau der nächsten Übung, danach direkt deren Timer
- Strichfiguren-Animationen für alle Gym-Übungen (CustomPainter, Start-/Endpose interpoliert)
- Erklärvideo-Knopf nur für die Bein-Übungen (öffnet YouTube-Suche), im Übungsfenster und im Timer
- Kalender: einzelne Einheit mit frei wählbarem Datum/Uhrzeit (`ExportChoice.date`, nur für den Termin, Plan bleibt); „In den Kalender“ – einzelne Einheit/freie Einheit öffnet die Kalender-App mit vorausgefülltem Termin (Intent, ohne Berechtigung); alle offenen Einheiten werden direkt in einen gewählten Kalender geschrieben (READ/WRITE_CALENDAR, Termin-IDs in `cal_event_<kalender>_plan_<tag>`, erneutes Eintragen aktualisiert). Alternativ „Als Datei teilen“ (.ics; Google-Kalender-App öffnet .ics nicht)
- Freie Einheiten (z. B. Dehnen): Knopf „Freie Einheit“ unten rechts auf der Startseite; Datum/Uhrzeit/Dauer (Zeitansatz)/Notizen, Timer, „Zusätzlich“ oder „Statt Plan-Einheit“ (dann rückt die Plan-Einheit einen Tag nach, `blockedDates`); stehen im Plan beim jeweiligen Tag, einzeln als .ics exportierbar
- Plan bearbeiten (`lib/plan_edit.dart`): Plan = Bausteine (`templateKeyFor`: legA, upper, legB, base0-7, quality0-7, long0-7, rest); Änderungen je Baustein als JSON in `tpl_<key>`, geladen in `planOverrides` (Store-Konstruktor), gelten für alle Tage des Bausteins; Übungen hinzufügen/bearbeiten/löschen/sortieren, Timer-Art, Sätze, Pausen, Wechselpause, Strichfigur (`Exercise.anim`) und Video (`Exercise.video`) wählbar; „Auf Original zurücksetzen“. Einstieg: Stift-Symbol auf der Startseite und in jeder Einheit. Nächste Stufe geplant: KI-Suche für neue Übungen (braucht Server + API-Schlüssel)
- Gewichte (`lib/weights.dart`): bei Kraft-Bausteinen (legA, legB, upper, außer Aufwärmen) pro Übung Gewicht + Notiz je Plan-Tag eintragen (JSON `weight_log`, Schlüssel = Übungsname); „Letztes Mal“ steht unter der Übung und im Timer, Eingabe vorbelegt, nach dem Übungs-Timer automatische Abfrage, Verlauf im Eingabefenster
- Läufe (`lib/run_log.dart`): bei Lauf-Bausteinen (base*, quality*, long*) pro Abschnitt Strecke (km), Zeit, Zeiten pro Wiederholung (bei manuellen Runden: Intervalle, Tempo-km) und Notiz je Plan-Tag (JSON `run_log`); Tempo /km und Ø je Wiederholung berechnet; „Letztes Mal“ unter dem Abschnitt und im Timer, nach Intervall-/Tempo-Timer automatische Abfrage
- Protokoll (`lib/diary.dart`): pro Einheit Befinden (1–5), Ø/Max-Puls, Beschwerden Achillessehne/Knie (0–10) und Notiz (JSON `diary`, Schlüssel = Plan-Tag); Abfrage direkt nach „Einheit abschließen“ (überspringbar) und als Karte in der Einheit. Körperwerte (`Vitals`, JSON `vitals`): Ruhepuls und Körpergewicht pro Datum, Eingabe über das Protokoll. Startseite → Herz-Symbol: Bericht (`buildReport`: Überblick, Einheiten, Gewichte/Zusatzgewicht, Läufe, freie Einheiten) zum Kopieren oder Teilen als .txt – der Nutzer gibt ihn Claude, um den Plan anzupassen
- UI-Sprache: Deutsch (auch Datums-/Uhrzeitauswahl via `flutter_localizations`)

## Struktur
- `lib/main.dart` – Plan-Daten, Screens (Home, Session, Timer), Speicherung (shared_preferences)
- `lib/animations.dart` – Posen und Painter; Zuordnung über den Übungsnamen (`exerciseAnims`)
- `lib/device_calendar.dart` – Kanal `lauf_plan/calendar` zu `android/app/src/main/kotlin/de/klaas/lauf_plan/MainActivity.kt` (eingecheckt; Workflow ergänzt die Kalender-Berechtigungen im Manifest)
- `lib/calendar.dart` – .ics erzeugen (RFC 5545, Ortszeit ohne Zeitzone) und über `share_plus` teilen
- `lib/diary.dart` – Protokoll (Befinden, Puls, Beschwerden) und Bericht/Export
- `lib/free_sessions.dart` – freie Einheiten: Modell, Speicher (JSON in `free_sessions`), Bearbeiten-Seite
- `lib/videos.dart` – Erklärvideos als YouTube-Suche oder fester Link (Tibialis Raises: vom Nutzer gewähltes Short), nur Bein-Übungen (`exerciseVideos`, öffnet per `url_launcher`)
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
- Plan-Inhalte (Übungen, Sätze, Zeiten) nur auf ausdrücklichen Wunsch des Nutzers ändern; der Nutzer kann sie inzwischen selbst im Plan-Editor anpassen.
- Keine neuen Abhängigkeiten ohne Grund.
