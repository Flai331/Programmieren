# Plan v113: Freigabe – Installationen abschalten (Hauptschalter + einzelne Geräte)

Mit Klaas am 30.10.2026 abgestimmt:
- Er will beides: einen Hauptschalter und das Sperren einzelner Geräte.
- Ohne Internet läuft die App 14 Tage weiter. Danach, und ebenso bei einer Sperre, erscheint der Sperrbildschirm mit
  „Bitte beim Administrator melden: error.404.found@outlook.de“.
- Eine Sperre wirkt **erst beim nächsten Start**. Eine laufende Sitzung läuft zu Ende.

Die Verwaltung läuft über die vorhandene Google-Tabelle mit dem Status-Server (`apps-script/Code.gs`, URL
`STATUS_URL` in app.js:68). Klaas stellt den neuen Code selbst bereit. Es gibt keine eigene Admin-Oberfläche: Er pflegt
alles direkt in der Tabelle.

## 1. Server (apps-script/Code.gs)
- **`doGet` mit `?lic=<Geräte-ID>`** – ID nach dem Muster `^[A-Za-z0-9_-]{8,40}$`.
  - Weitere Parameter, jeweils auf 60 Zeichen gekürzt: `m` (Modus el/hf), `v` (App-Version), `p` (Plattform `apk`|`web`),
    `n` (Gerätename, optional), `ua` (Gerätemodell aus dem User-Agent, gekürzt).
- **Blatt „Geräte“** (wird angelegt, falls es fehlt). Spalten: `Geräte-ID | Name | Modus | Plattform | Version |
  Modell | zuerst gesehen | zuletzt gesehen | Gesperrt`.
  - Neue ID → neue Zeile anlegen.
  - Bekannte ID → Modus, Plattform, Version, Modell und „zuletzt gesehen“ aktualisieren. Name nur überschreiben, wenn
    `n` nicht leer ist.
  - Gesperrt ist die Zeile, wenn in „Gesperrt“ irgendein nicht leerer Wert steht (x, ja, 1 …), außer „nein“ bzw. „0“.
- **Blatt „Einstellungen“** (wird angelegt): A1 „App aktiv“, B1 „JA“.
  - Aktiv ist die App, solange B1 nicht „NEIN“, „nein“, `FALSE` oder „0“ enthält.
  - A2 „Kontakt“, B2 „error.404.found@outlook.de“.
- **Antwort:** `{ ok: true, lic: true, aktiv: bool, gesperrt: bool, kontakt: '…', now }`.
- **Sperren:** `LockService` wie in `doPost` verwenden. Zeiten als ms-Zahl wie im Blatt „Meldungen“, zusätzlich eine
  lesbare Datumsspalte ist nicht nötig. Wenn möglich `setNumberFormat` mit Datum/Uhrzeit für die beiden Zeitspalten,
  damit Klaas lesbare Zeiten sieht; sonst ISO-Text.
- **`setup()`** legt die beiden neuen Blätter mit an.
- **ANLEITUNG.md** bekommt einen Abschnitt „Geräte freigeben und sperren“:
  - neuen Code einfügen, „Bereitstellungen verwalten → Stift → Neue Version → Bereitstellen“ (die URL bleibt gleich);
  - Blatt „Geräte“: x in „Gesperrt“;
  - Blatt „Einstellungen“: B1 NEIN schaltet alle ab;
  - Wirkung beim nächsten Start; 14 Tage ohne Internet;
  - Grenzen: Kopien des Codes, Daten bleiben auf dem Gerät.
- Der bisherige Meldungsbetrieb (`r`/`since`, `doPost`) bleibt unverändert.

## 2. App (neues Modul web/licence.js, rein und testbar, plus Einbindung in app.js)
- **`licenceState({ now, lastOk, firstStart, blocked, inactive })`** liefert `'ok' | 'blocked' | 'expired'`.
  - `blocked` oder `inactive` → `'blocked'`.
  - Sonst `'expired'`, wenn `now - (lastOk || firstStart) > 14 Tage`.
  - Sonst `'ok'`.
- **Gespeichert** wird in localStorage unter einem eigenen Schlüssel, z. B. `sgk-licence`:
  `{ id, firstStart, lastOk, blocked, inactive, kontakt }`.
  - `id` beim ersten Start mit `uid()` erzeugen, mindestens 12 Zeichen, nur `[A-Za-z0-9_-]`.
  - Die Android-App nutzt denselben WebView-Speicher.
- **Ablauf beim Start** (früh in app.js, vor dem Modus-Dialog bzw. Assistenten):
  1. Zuerst den gespeicherten Zustand auswerten. Ist er nicht `'ok'`, sofort den Sperrbildschirm zeigen (Overlay über
     allem, z-index ganz oben, keine Bedienung dahinter).
  2. Dann **im Hintergrund** prüfen: `fetch(STATUS_URL + '?lic=…&m=…&v=APP_VERSION&p=…&ua=…')` mit Timeout von ca. 8 s.
     - Plattform: `apk`, wenn `window.AndroidBridge` vorhanden ist, sonst `web`.
     - Erfolg (`ok: true`): `lastOk = now`.
     - Enthält die Antwort `lic: true`, `blocked`, `inactive` und `kontakt` übernehmen und speichern.
     - Eine alte Server-Version ohne `lic` (Antwort `{ ok: true, info }`) gilt als erfolgreich und nicht gesperrt.
     - Netzfehler: nichts ändern.
     - **Wirkung:** Wird das Gerät dabei neu gesperrt, wird nur gespeichert, ohne Sperrbildschirm, denn es soll erst
       beim nächsten Start greifen. Wird es dagegen entsperrt bzw. ist es wieder in der Frist, während der
       Sperrbildschirm offen ist, schließt dieser sofort und die App startet normal (Knopf „Erneut prüfen“ macht
       dasselbe).
  3. Zusätzlich alle 6 Stunden erneut prüfen, solange die App offen und online ist. Nur speichern, keine sofortige
     Sperre.
- **Sperrbildschirm** (`#lic-lock` in index.html, Stil passend zur App):
  - Titel „🔒 Suchgebiet-Karten ist gesperrt“ bzw. bei `expired` „🔒 Freigabe abgelaufen“.
  - Text:
    - gesperrt: „Diese Installation wurde vom Administrator deaktiviert.“
    - abgelaufen: „Seit über 14 Tagen konnte die Freigabe nicht geprüft werden. Bitte mit dem Internet verbinden und
      erneut prüfen.“
    - beide: „Wenn Sie die App weiter nutzen wollen, melden Sie sich beim Administrator: **error.404.found@outlook.de**“
      als `mailto:`-Link, mit Betreff „Suchgebiet-Karten Freigabe“ und der Geräte-ID im Text. Die Kontaktadresse aus
      der Server-Antwort gewinnt, Standard ist die genannte.
  - Darunter die Geräte-ID gut lesbar und kopierbar, plus der Knopf **„Erneut prüfen“**.
  - Gesperrt heißt: Karte, Leisten, Dialoge sind nicht bedienbar. Service Worker und Update-Prüfung dürfen weiterlaufen,
    damit eine neue Version ankommen kann.
- **„Mehr“-Menü bzw. Info:** eine Zeile „Geräte-ID: …“ und optional ein Feld „Gerätename“. Der Name wird beim nächsten
  Check als `n` mitgesendet, damit Klaas in der Tabelle sieht, welches Handy welches ist. Prüfen, wo es Info oder
  Einstellungen gibt (`grep -n "APP_VERSION" app.js`), und es dort einfügen.
- **Tests/e2e/localhost:** Die Prüfung schlägt im Test ohne Netz fehl, dann gilt `firstStart` als Frist, also `'ok'`.
  Bestehende e2e-Skripte dürfen davon nicht betroffen sein. Damit kein Test hängt, darf die Prüfung den Start nicht
  blockieren.

## Tests
- **Unit-Tests** (`test/licence.test.mjs`): `licenceState` deckt alle Fälle ab.
  - Frist ab `firstStart` bzw. `lastOk`, genau 14 Tage.
  - `blocked` bzw. `inactive` hat Vorrang.
  - Antwort-Auswertung als reine Funktion `applyLicenceReply(state, reply, now)`: alte Server-Antwort,
    `lic`-Antwort gesperrt bzw. aktiv, Fehler.
- **Playwright** `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/licence-e2e.mjs`
  (Vorlage `areas-e2e.mjs`). Server `python3 -m http.server 8765` in `web/` (prüfen per curl, ggf. starten; nie
  `pkill -f`). STATUS_URL per `page.route('**/macros/**', …)` mocken. Jeweils Tablet und Handy:
  1. Normaler Start, Mock antwortet aktiv: keine Sperre, `lastOk` gesetzt, ID vorhanden.
  2. Mock antwortet gesperrt: weiter bedienbar (erst beim nächsten Start). Reload zeigt den Sperrbildschirm mit
     E-Mail und ID.
  3. Mock antwortet wieder aktiv, „Erneut prüfen“: der Sperrbildschirm verschwindet.
  4. Hauptschalter (`aktiv: false`) und Reload: gesperrt.
  5. Kein Netz (Route abbrechen) und `lastOk` vor 15 Tagen (localStorage vorher setzen): „Freigabe abgelaufen“.
  6. Kein Netz und `lastOk` vor 13 Tagen: normal.
  7. Alte Server-Antwort `{ ok: true, info }`: gilt als ok.
  8. Screenshots machen.
- Bestehende Tests bleiben grün: `node --test test/*.mjs` und die e2e-Skripte areas, progress, tapclose, accept,
  close, status, park, longpress und hidden (Ausgabe ALLES OK bzw. alle OK). Ausführen mit
  `NODE_PATH=$(npm root -g) node …`; Chromium ist vorinstalliert und darf nicht neu installiert werden.
- Den Code von apps-script/Code.gs lokal mit `node --check` prüfen (nur die Syntax; Apps Script ist ES5-kompatibel,
  also `var` und `function` verwenden).
- **Nicht** committen, pushen oder deployen, keine Versionsnummern ändern, kein git checkout/stash/reset.
