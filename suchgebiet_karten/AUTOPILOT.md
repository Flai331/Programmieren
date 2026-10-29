# Autopilot Suchgebiet-Karten – Ablauf für die stündlichen Läufe

Diese Datei steuert die geplante Aufgabe, die stündlich eine neue Claude-Sitzung startet.
Klaas (klaasotte99@gmail.com, GitHub `Flai331`) hat das ausdrücklich so gewollt: Fehler
selbstständig beheben und live stellen, neue Funktionen fertig bauen und zum Testen
bereitstellen, ohne dass er dabei sein muss. Alle Texte an Klaas auf Deutsch, kurz, ohne
Fachjargon.

## Eckdaten

| Was | Wo |
|---|---|
| Repo | `flai331/programmieren`, App in `suchgebiet_karten/` (Web in `web/`, Android-Hülle in `android/`) |
| Live | Zweig `main` → GitHub Pages https://flai331.github.io/Programmieren/suchgebiet-karten/ und Release `suchgebiet-karten` (APK) |
| Testversion | Zweig `claude/suchgebiet-beta` → Release `suchgebiet-karten-beta` (nur APK): https://github.com/Flai331/Programmieren/releases/download/suchgebiet-karten-beta/Suchgebiet-Karten.apk |
| Fehlerbehebungen | Zweige `claude/suchgebiet-fix-<kurzname>` → PR nach `main` |
| CI | `.github/workflows/suchgebiet-karten-apk.yml` (Unit-Tests, APK-Build, Emulator-Starttest) |
| Fahrplan | `suchgebiet_karten/ROADMAP.md` |
| Fehlermeldungen | Notion 🐞 Fehlerzentrale → 🐛 Suchgebiet-Karten, Data Source `collection://6e714284-f99a-477c-8e5d-7b2848e1c4b5` |
| Ideen | Notion 💡 Ideen & Features, Data Source `collection://c2ab9d89-75fe-484d-8170-6a4f8f7200f9`, Filter App = „RHS Einsatz App“ |

Klaas erlaubt ausdrücklich, auf `claude/suchgebiet-beta` und `claude/suchgebiet-fix-*` zu
pushen, PRs zu öffnen und nach grünem CI zusammenzuführen (Regeln unten). Nie auf `main`
direkt pushen, nie Force-Push auf `claude/suchgebiet-beta`.

## Ablauf eines Laufs

0. **Nicht doppelt laufen.** Sitzungstitel auf „Autopilot Suchgebiet <Datum Uhrzeit>“ setzen.
   Mit `list_sessions` (mine) prüfen, ob eine andere Sitzung „Autopilot Suchgebiet …“ gerade
   arbeitet (nicht idle/abgeschlossen, jünger als 3 h) → dann sofort beenden, ohne etwas zu tun.
1. **Stand holen.** `git fetch origin main claude/suchgebiet-beta`; offene PRs und laufende
   CI-Runs ansehen. Ein abgebrochener Vorlauf (z. B. Nutzungsgrenze) hinterlässt Zweige/PRs:
   dort weitermachen statt neu anfangen.
2. **Fehlermeldungen (Vorrang).** In der Fehler-Datenbank alle Einträge mit Status „Offen“.
   - Gleicher Fingerprint wie ein schon behobener/bearbeiteter Eintrag → Status wie dort,
     Kommentar „Doppelt zu …“.
   - Sonst Status „In Bearbeitung“, Ursache im Code suchen, möglichst mit Unit-Test oder
     Playwright reproduzieren, beheben.
   - Nicht nachvollziehbar oder nur mit Klaas' Hilfe lösbar → Status „Rückfrage“, Frage als
     Kommentar am Eintrag, Zeile unter „Rückfragen“ in `ROADMAP.md`.
   - Fix auf `claude/suchgebiet-fix-<kurzname>` von `origin/main`; Version auf der live
     Nummer hochzählen mit Unterversion (v74 → v74.1 → v74.2 …; `APP_VERSION` in `web/app.js`
     und `VERSION` in `web/sw.js` gleich), `./deploy.sh`, Zeile unter „Fehlerbehebungen“ in
     `ROADMAP.md`. PR nach `main`, nach grünem CI zusammenführen (`expectedHeadSha` = voller
     Head-SHA). Danach Eintrag „Behoben“, „Behoben in“ = Version, kurzer Kommentar, was es war.
   - Danach `main` in `claude/suchgebiet-beta` mergen (Merge-Commit, kein Rebase); bei
     Konflikten in der Versionsnummer gewinnt die höhere Beta-Version; `./deploy.sh` erneut.
3. **Freigaben und Rückmeldungen der Testversion.** Offener PR `claude/suchgebiet-beta` → `main`:
   - Kommentar von Klaas wie „passt“, „freigabe“, „ok“, „live“ (nach dem letzten Push) →
     PR zusammenführen (nach grünem CI), alle enthaltenen Fahrplan-Punkte auf `[x]`, zugehörige
     Ideen in Notion auf „Umgesetzt“. Danach `claude/suchgebiet-beta` auf `origin/main`
     zurücksetzen (nur jetzt, wo alles gemergt ist).
   - Kommentar mit Fehlern/Änderungswünschen → wie eine Fehlermeldung in der Beta beheben,
     kurz antworten, was geändert wurde.
   - Kommentare in Notion zu Rückfragen lesen; beantwortete Fragen weiterbearbeiten.
4. **Neue Ideen.** In „💡 Ideen & Features“ Einträge mit App = „RHS Einsatz App“ und Status
   „Offen“ (Priorität „Erstmal nicht umsetzen“ überspringen; „Direkt“ vor „Optional“):
   - Eindeutig → als neuer Punkt unter „Aus Ideen übernommen“ in `ROADMAP.md` (mit Notion-Link),
     Status „In Bearbeitung“.
   - Unklar oder im Widerspruch zu Bestehendem → Frage als Notion-Kommentar, Zeile unter
     „Rückfragen“; nicht raten. Gleiche Frage nicht erneut stellen.
5. **Nächste Funktion bauen** (nur wenn Schritte 2–3 nichts Unerledigtes hinterlassen und noch
   Volumen da ist): den obersten offenen Punkt `[ ]` aus `ROADMAP.md` (Ideen mit Priorität
   „Direkt“ dürfen vor die geplanten Versionen) auf `claude/suchgebiet-beta` bauen:
   - Version = nächste ganze Nummer nach der höchsten bisher vergebenen (Beta oder live).
   - Neue Logik in eigene, testbare Dateien; neue JS-Dateien in `APP_FILES` von `web/sw.js`.
   - Prüfen wie unten, `./deploy.sh`, Punkt auf `[~]`, committen, pushen.
   - PR `claude/suchgebiet-beta` → `main` anlegen bzw. Titel/Beschreibung aktualisieren:
     Titel „Testversion: v75–v77 …“, Beschreibung mit allen enthaltenen Punkten, Link zur
     Beta-APK und der Bitte: „Zum Freigeben hier ‚passt‘ kommentieren.“ **Nicht zusammenführen.**
   - Pro Lauf höchstens eine Funktion. Mehrere Funktionen dürfen sich auf dem Beta-Zweig stapeln.
6. **Ende.** Nur wenn etwas passiert ist, eine kurze Zusammenfassung als letzte Nachricht
   (wird als Push-Benachrichtigung verschickt): was live ging, was zum Testen bereitliegt,
   welche Rückfragen offen sind. Ohne Arbeit: keine Nachricht, sofort beenden.

## Prüfen vor jedem Push

- `cd suchgebiet_karten && node --test test/*.mjs` – alles grün.
- Für sichtbare Änderungen ein Playwright-Skript im Scratchpad: Chromium ist vorinstalliert
  (`require('playwright')` mit `NODE_PATH=$(npm root -g)`), Web-App mit
  `python3 -m http.server 8765` aus `web/` ausliefern, externe Anfragen mit `page.route` auf 404.
  Start: Knopf „Einsatzleitung“, auf einem frischen Gerät dann `#wz-exit` (Assistent schließen).
  `window.__app` gibt Zugriff auf `P`, `db`, `map`, `setArea`, `saveNow`. Screenshots ansehen.
- Eigene Änderung kritisch lesen (Fehlerfälle, HF- und EL-Modus, offline, alte Links/Daten).
- Nach dem Push auf grünes CI warten (GitHub API, Workflow `suchgebiet-karten-apk.yml`,
  Zweig filtern). Rot → Ursache beheben, nie Tests abschalten.

## Regeln der App (nicht brechen)

- Feste EL-PIN 110112, keine weiteren PINs. Alte Links (`#a=`, `#r=`, `#e=`, `#m=`) bleiben gültig.
- Keine Einsatzdaten in Fehlermeldungen. Keine Tokens/Secrets in `web/` (öffentlich).
- Commit-Nachrichten auf Deutsch, Ende mit den Attribution-Zeilen aus dem System-Hinweis der Sitzung.
- In Notion „Umgesetzt“ erst nach Klaas' Freigabe; Fehlermeldungen „Behoben“ sofort nach Live-Gang.
