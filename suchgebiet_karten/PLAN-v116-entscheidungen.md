# Plan v116: Entscheidungen vom 31.10. (Sicherheit, Fund live, Exporte, Mein Gebiet)

## Grundlage

Klaas hat am 31.10. um 7 Uhr entschieden (Memo „Prüfbericht 31.10.2026“, Abschnitt „Offene Entscheidungen“). Umzusetzen sind
nur die Punkte unten. **Nicht** Teil dieser Version sind:

- Rückkanal EL → HF (kommt in v117)
- SOS-Knopf, Begleiter-Rolle, „EL einfach“, Assistent umsortieren, allowBackup (abgelehnt)

## 1. Notion-Token raus aus dem APK, Fehlerberichte über den Status-Server

Heute liest `ErrorReports.kt` den Token aus `BuildConfig.NOTION_TOKEN` (`android/app/build.gradle.kts` Z. 17–19, Workflow
`.github/workflows/suchgebiet-karten-apk.yml` Z. 69). Dadurch steckt er im öffentlichen APK.

- **Apps Script (`apps-script/Code.gs`):**
  - `doPost` erkennt einen Fehlerbericht am Feld `rep` (JSON-Body `{ rep: { … } }`) und ruft `bericht_(rep)` auf. Normale
    Meldungen (`r`, `id`, `d`) bleiben unverändert.
  - `bericht_` baut die Notion-Seite (gleiche Felder wie heute `ErrorReports.body()`, Datenbank-ID `5574dcecd7e84a0aa79446bab3915a47`,
    Plattform aus `rep.platform`, sonst „Android“) und sendet sie mit `UrlFetchApp.fetch` an `https://api.notion.com/v1/pages`
    (`muteHttpExceptions: true`).
  - Den Token liest `bericht_` aus `PropertiesService.getScriptProperties().getProperty('NOTION_TOKEN')`. Fehlt er, antwortet es
    `{ ok: false, fehler: 'kein Token' }`.
  - Schutz gegen Missbrauch:
    - Jedes Textfeld wird auf 2000 Zeichen gekürzt.
    - Höchstens 30 Berichte pro Stunde (`CacheService`-Zähler). Darüber antwortet es `{ ok: false, fehler: 'zu viele' }`.
  - Antwort: `{ ok: true }` bei Notion-Status 2xx. Bei 4xx außer 429 lautet sie `{ ok: true, verworfen: true }`, damit das Gerät
    den Bericht nicht endlos wiederholt. Sonst `{ ok: false }`.
- **ANLEITUNG.md:** Abschnitt „Fehlerberichte (Notion)“ beschreibt:
  - Projekteinstellungen → Skripteigenschaften → `NOTION_TOKEN` setzen.
  - Den alten Token in Notion widerrufen und neu erzeugen.
  - Den Notion-Code danach erneut als neue Version bereitstellen.

  Klaas setzt den Token selbst. Ein Token gehört nie in Code oder Chat.
- **Android:**
  - `ErrorReports.post` sendet den Bericht als `{ rep: { …Bericht…, device, os, platform: 'Android' } }` per POST an die
    Status-Server-URL. Die URL kommt aus der Web-App: Das Bericht-JSON trägt ein Feld `url`, gefüllt mit `STATUS_URL` bzw. der
    eingestellten URL, und nur URLs mit `https://script.google.com/` werden angenommen.
  - Apps Script antwortet mit einer 302-Umleitung; die muss bei POST mitgegangen werden. Zuerst prüfen, wie status.js das im Web
    löst.
  - `hasToken` entfällt. Stattdessen gilt: Berichte sind möglich, wenn eine gültige URL im Bericht steckt.
  - Die Warteschlange bleibt. Für Abstürze ohne Web-App gilt: die zuletzt benutzte URL in SharedPreferences merken.
- **build.gradle.kts und Workflow:** `NOTION_TOKEN` entfernen (buildConfigField und env). `MainActivity.kt` Z. 374 anpassen.
- **Web:** `canReport` bleibt Android-only. `buildReport` bzw. `sendReport` setzen `url`.
- **Unit-Test:** reine Hilfsfunktion in `report.js`, z. B. `reportPayload(r, url)`, falls sinnvoll.

## 2. Lizenzsperre nie im laufenden Einsatz, plus Notfallcode

`licence.js` (`licenceState`) und der Lizenzblock in `app.js` (`licShow`, `licCheck`).

- **Nie im Einsatz:** Läuft ein Einsatz, erscheint die Sperre nicht, sondern ein dezenter Hinweis: „Diese Installation ist
  gesperrt – nach Einsatzende nicht mehr nutzbar“. Das gilt für `blocked` und `expired`.
  - „Läuft ein Einsatz“ bestimmt `einsatzOffen()` aus `update.js` (EL: offener, nicht abgeschlossener Einsatz; HF: Auftrag
    vorhanden).
  - Die Sperre greift beim nächsten Start bzw. bei der nächsten Prüfung, wenn kein Einsatz mehr offen ist.
  - Umsetzung: `licenceState` bekommt `busy` (bool). Bei `busy` und eigentlich `blocked`/`expired` gibt es `'deferred'` zurück.
- **Notfallcode:**
  - Im Blatt „Einstellungen“ steht in Zeile 3 „Notfallcode“ in A3, der Wert in B3; `setup()` legt die Zeile an, leer.
  - Der Server schickt bei jeder Prüfung `notfall: <SHA-256 hex des Codes>` mit, bei leerem Code nichts. Die App speichert den Hash
    im Lizenz-Zustand.
  - Auf dem Sperrbildschirm gibt es den Knopf „Notfallcode eingeben“. Ein richtiger Code (Hash-Vergleich, wie `pinHash`) entsperrt
    für 24 h (`until`), auch offline. Ein falscher Code meldet „Falscher Code“.
  - Ist kein Hash bekannt, steht dort „Kein Notfallcode hinterlegt – Kontakt: …“.
- **Unit-Tests:** `licenceState` mit `busy` und `until`; `applyLicenceReply` übernimmt `notfall`; Ablauf nach 24 h.
- **ANLEITUNG.md:** Notfallcode erklären.
- **licence-e2e:** um „gesperrt, aber Einsatz offen → kein Sperrbildschirm“ und „Notfallcode entsperrt“ ergänzen.

## 3. „Markieren → Fund“ geht sofort live an die EL

`HF_MARKS` (`app.js` ~3013).

- Setzt der HF eine Markierung „✅ Fund“, wird zusätzlich dieselbe Meldung wie „📍 Standort melden → 🟢 Person gefunden“ an dieser
  Stelle erzeugt und gesendet: Warteschlange, dringend, mit Text der Markierung. Dafür vorhandene Funktion nutzen (spotDialog-Pfad).
- Hinweis-Toast: „✅ Fund markiert und an die Einsatzleitung gemeldet“, bzw. „… wartet auf Netz“, wenn es in der Warteschlange
  liegt.
- Wird die Markierung gelöscht, bleibt die Meldung bestehen. Zurückziehen geht wie bisher über die Meldung selbst.
- **Unit-Test** bzw. e2e: HF markiert Fund → Outbox enthält eine dringende Meldung mit Position.

## 4. Funde in GPX, PDF und Abschlussbericht

Meldungen mit Ort (Fund/Person gefunden, Hund zeigt an, Hilfe, Hinweis, Gefahr, Parkplatz …) aus `allMsgs()` bzw. `P.hf.log`
(HF-Gerät):

- **GPX** (`buildGpx` bzw. „Alles für BaseCamp“/Mail-Export): Jede Meldung mit Ort wird ein `<wpt>`.
  - Name z. B. „Fund Bravo 00:21“, Zeit `<time>`, `<desc>` mit dem Text.
  - `<sym>` als Garmin-Symbol: Fund „Flag, Red“, Anzeige „Flag, Blue“, Hilfe „Medical Facility“, sonst „Flag, Green“.
- **PDF:** Meldungen mit Ort erscheinen als Symbol mit kurzer Beschriftung auf der Karte (wie die Live-Karte, nur dringende
  hervorgehoben), dazu als Liste „Meldungen“ in der Legende bzw. auf der Rückseite, sofern es die bestehende Struktur einfach
  hergibt.
- **Abschlussbericht** (`report.js` bzw. `buildReport`/Einsatzbericht, nicht der Fehlerbericht): Abschnitt „Meldungen mit Ort“
  mit Zeit, Team, Art, Text und Koordinate (UTMREF).
- Zurückgezogene oder gelöschte Meldungen (`gone`, `withoutDeleted`) erscheinen nicht.
- Reine Funktion z. B. `msgWaypoints(msgs, teamsById)` in gpx.js mit Unit-Test.

## 5. Einsatz abschließen prüft offene Punkte

`app.js` ~7831 (`ms-close`):

- Vor dem Abschließen listet der Dialog auf:
  - offene Aufträge (nicht `isDone`), mit Team
  - unquittierte Funde und Hilfe-Meldungen (`P.live.ack`)
  - Teams ohne Rückgabe (`isReturned` false)
- Gibt es etwas davon, stehen die Liste und „Trotzdem abschließen“ (rot) bzw. „Zurück“ da. Ist alles erledigt, bleibt der Dialog wie
  heute.
- Die Logik steht rein, z. B. in `closeout.js` als `openPoints(P, msgs)`, mit Unit-Test.

## 6. „Mein Gebiet“ und Navigation beim HF

- **„🎯 Mein Gebiet“** im HF-Menü und als kleiner Knopf auf der Auftragskarte (`#hfinfo`): zoomt auf alle Gebiete des Auftrags
  (`hfAreas` bzw. Umrisse und Felder des Teams).
- **„🧭 Navigation“** im HF-Menü mit den Zielen Parkplatz, B-Ort bzw. Treffpunkt und Gebiet (Mittelpunkt).
  - Es werden nur die Ziele gezeigt, die es im Auftrag gibt.
  - Ein Ziel öffnet `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lon>`; in der APK geht das über einen Intent bzw.
    den bestehenden Link-Weg, also prüfen, wie externe Links heute geöffnet werden.
- **GPS beim Auftrag an:** Übernimmt der HF einen Auftrag, startet die Standortanzeige automatisch (wie der GPS-Knopf), falls sie aus
  ist. Eine Ablehnung der Berechtigung bleibt ohne weitere Nachfrage.

## 7. PIN-Text

- An den Stellen mit der EL-PIN (`askPin`-Dialog, Moduswahl-Text `index.html` Z. 348, Mehr) steht klar: „Die PIN schützt vor
  versehentlichem Wechsel, nicht die Daten.“
- Kurz halten: ein Satz im PIN-Dialog, keine neuen Dialoge.

## Tests

- **Unit-Tests:** `node --test test/*.mjs` grün, mit neuen Tests zu 1 (falls rein), 2, 4 und 5.
- **e2e:** Neues Skript `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/v116-e2e.mjs`, je Punkt eine
  Prüfung mit Screenshots (Tablet 1280×800, Handy 412×860):
  - Lizenz: deferred, Notfallcode
  - Fund live (Outbox bzw. Status-Server-Mock)
  - GPX enthält `<wpt>` „Fund …“
  - Abschluss-Dialog listet offene Punkte
  - „Mein Gebiet“ zoomt
  - Navigation-Link stimmt
- **Bestehende e2e-Skripte** bleiben grün: areas, progress, tapclose, accept, close, status, park, longpress, hidden, licence, vertex,
  gridfit, noteam, reorder, robust, bedienung, edit. Gewollte Verhaltensänderungen im Skript anpassen und im Bericht nennen.
- **Android:** Kotlin kann hier nicht gebaut werden. Den Code sorgfältig gegen bestehende Muster schreiben (Imports, Threads), die
  CI baut.
- **Testserver:** Liefert curl nicht 200, starten mit `cd web && (nohup python3 -m http.server 8765 >/dev/null 2>&1 &)`. Niemals
  `pkill -f`. Skripte laufen mit `NODE_PATH=$(npm root -g) node …`.
- **Nicht** committen, deployen oder die Version ändern; kein git checkout, stash oder reset.
