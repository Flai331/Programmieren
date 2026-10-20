# Laufplan – Flutter Android App

## Was die App ist
Persönlicher 4-Wochen-Trainingsplan (Laufen + Gym), Start Do 01.10.2026.
- Startseite: heutige Einheit, alle 28 Tage mit Datum, geschätzter Dauer, Erledigt-Haken
- Plan verschiebt sich: nicht erledigte Trainingseinheit rückt auf heute, alle folgenden Tage wandern mit (`computeSchedule`); Erledigt-Datum wird gespeichert (`doneOn_<tag>`), Nachtragen (`pickDoneDate`): beim Abhaken einer nachgerückten Einheit und über „Nachträglich abhaken“ auf der Heute-Karte Auswahl der letzten 7 Tage mit Wochentag (Heute, Gestern, Freitag …, geplanter Tag markiert) , Datum als Freitext (`parseUserDate`, `DateTextField`) oder anderes Datum; Erledigt-Datum in der Einheit änderbar – der Plan rückt entsprechend wieder vor
- Einheit: Stoppuhr gegen geschätzte Zeit, Übungen abhaken, Hinweise
- Timer pro Übung: Intervalle, Halten (Arbeit/Pause automatisch), manuelle Sätze mit Pausen-Countdown
- Oberkörper: Dips und Klimmzüge gewichtet (je 4 Sätze mit Zusatzgewicht, Pause 2:00 / 2:30) statt EMOM – auf Wunsch des Nutzers geändert
- Wechselpausen zwischen den Kraftübungen (geschätzt, `Exercise.restAfter`): Pausen-Timer mit Vorschau der nächsten Übung, danach direkt deren Timer
- Strichfiguren-Animationen für alle Gym-Übungen (CustomPainter, Start-/Endpose interpoliert)
- Erklärvideo-Knopf nur für die Bein-Übungen (öffnet YouTube-Suche), im Übungsfenster und im Timer
- Kalender: einzelne Einheit mit frei wählbarem Datum/Uhrzeit (`ExportChoice.date`, nur für den Termin, Plan bleibt); „In den Kalender“ – einzelne Einheit/freie Einheit öffnet die Kalender-App mit vorausgefülltem Termin (Intent, ohne Berechtigung); alle offenen Einheiten werden direkt in einen gewählten Kalender geschrieben (READ/WRITE_CALENDAR, Termin-IDs in `cal_event_<kalender>_plan_<tag>`, erneutes Eintragen aktualisiert). Alternativ „Als Datei teilen“ (.ics; Google-Kalender-App öffnet .ics nicht)
- Freie Einheiten (z. B. Dehnen): Knopf „Freie Einheit“ unten rechts auf der Startseite; Datum/Uhrzeit/Dauer (Zeitansatz)/Notizen, Timer, „Zusätzlich“ oder „Statt Plan-Einheit“ (dann rückt die Plan-Einheit einen Tag nach, `blockedDates`); stehen im Plan beim jeweiligen Tag, einzeln als .ics exportierbar
- Plan bearbeiten (`lib/plan_edit.dart`): Plan = Bausteine (`templateKeyFor`: legA, upper, legB, quality0-3, long0-3, rest); Änderungen je Baustein als JSON in `tpl_<key>`, geladen in `planOverrides` (Store-Konstruktor), gelten für alle Tage des Bausteins; Übungen hinzufügen/bearbeiten/löschen/sortieren, Timer-Art, Sätze, Pausen, Wechselpause, Strichfigur (`Exercise.anim`) und Video (`Exercise.video`) wählbar; „Auf Original zurücksetzen“. Einstieg: Stift-Symbol auf der Startseite und in jeder Einheit. Nächste Stufe geplant: KI-Suche für neue Übungen (braucht Server + API-Schlüssel)
- Gewichte (`lib/weights.dart`): bei Kraft-Bausteinen (legA, legB, upper, außer Aufwärmen) pro Übung Gewicht + Notiz je Plan-Tag eintragen (JSON `weight_log`, Schlüssel = Übungsname); „Letztes Mal“ steht unter der Übung und im Timer, Eingabe vorbelegt, nach dem Übungs-Timer automatische Abfrage, Verlauf im Eingabefenster
- UI-Sprache: Deutsch (auch Datums-/Uhrzeitauswahl via `flutter_localizations`)

## Struktur
- `lib/main.dart` – Plan-Daten, Screens (Home, Session, Timer), Speicherung (shared_preferences)
- `lib/animations.dart` – Posen und Painter; Zuordnung über den Übungsnamen (`exerciseAnims`)
- `lib/device_calendar.dart` – Kanal `lauf_plan/calendar` zu `android/app/src/main/kotlin/de/klaas/lauf_plan/MainActivity.kt` (eingecheckt; Workflow ergänzt die Kalender-Berechtigungen im Manifest)
- `lib/calendar.dart` – .ics erzeugen (RFC 5545, Ortszeit ohne Zeitzone) und über `share_plus` teilen
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
