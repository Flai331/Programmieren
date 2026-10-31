# Plan v117: Rückkanal Einsatzleitung → Hundeführer (Lesebestätigung + Nachrichten)

## Grundlage

Entscheidung vom 31.10. (Memo „Prüfbericht 31.10.2026“): „Lesebestätigung + Nachrichten (Empf.)“.
Heute fließen Meldungen nur HF → EL. Die EL holt sie mit `pollLive()` (app.js ~4825) per `pollMessages()` ab.
Der HF sendet über `sendStatus`/`flushStatus` (app.js ~4161/4194), `P.hf.ls = [Adresse, Schlüssel]` und
`P.hf.outbox`.

Einsatzleitung und alle HF eines Einsatzes benutzen **denselben Raum**: `roomOf(key)` mit dem Schlüssel aus `P.live`,
der mit dem Auftrag als `ls` mitgeht. Zuerst nachprüfen, dass `P.hf.ls[1] === P.live.key` der EL ist (buildAssignment).

Der Status-Server (`apps-script/Code.gs`) speichert pro Raum beliebige verschlüsselte Zeilen. Daraus folgt:

- Der Server braucht **keine Änderung**.
- Die EL kann mit `postMsg` selbst in den Raum schreiben.
- Der HF kann mit `pollMessages` mitlesen.

## 1. Neue Meldungsarten (status.js, reine Logik + Unit-Tests)

Alle Meldungen laufen über das bestehende Format (`buildMsg` mit `v`, `id`, `a`, `t`, `s`), verschlüsselt wie bisher.
Absender EL: `a: 'EL'` (fester Wert, kein Auftrag), `tm: 'Einsatzleitung'`.

- **Quittung `s: 'q'`:** `ref` ist die ID der HF-Meldung, `to` der Auftrag (`m.a` der quittierten Meldung).
  - Die EL sendet sie automatisch, wenn sie eine dringende Meldung mit „✓ Gesehen“ bestätigt (`showUrgent`).
  - Die EL sendet sie auch, wenn sie eine Meldung in der Statusliste bzw. im Meldungsdialog liest. Dafür einen
    vorhandenen Lese-/Gelesen-Pfad nutzen (`msgRecv`/ungelesen). Nur einmal pro Meldung senden: gemerkt in
    `P.live.qSent = { id: 1 }`.
- **Nachricht `s: 'el'`:**
  - `to` ist eine Auftrags-ID oder `'*'` (alle), `txt` höchstens 300 Zeichen.
  - Optional `prio: 1` für „wichtig“: Ton und Fenster beim HF, bis „Verstanden“.
- **Antwort HF `s: 'qel'`:** `ref` ist die ID der EL-Nachricht, damit die EL „gelesen“ sieht. Der HF sendet sie
  automatisch, wenn er die Nachricht angezeigt bekommt bzw. „Verstanden“ tippt.

Neue Funktionen in status.js, alle mit Tests in `test/status.test.mjs` bzw. neuer `test/rueck.test.mjs`:

- `buildAck({ ref, to, t, id })`, `buildElMsg({ to, txt, prio, t, id })` und `buildReadAck({ a, tm, ref })`.
- `forHf(msgs, a)`: Meldungen, die ein HF mit Auftrag `a` sehen soll. Das sind `s === 'q'` mit `to === a` und
  `s === 'el'` mit `to === a || to === '*'`. Dazu kommen nur Meldungen mit `a === 'EL'`. Andere HF-Meldungen im Raum
  ignoriert der HF.
- `ackedIds(msgs)`: Set der quittierten Meldungs-IDs, für den HF.
- `readBy(msgs, elId)`: Aufträge, die eine EL-Nachricht gelesen haben (`qel`), für die EL.
- `msgLabel`/`statusLabel`/`msgIcon` sollen q/el/qel sinnvoll benennen: „✓ Gesehen“, „✉️ Nachricht der Einsatzleitung“,
  „👁 gelesen“.
- **Wichtig:** Überall, wo die EL ihre Liste auswertet, müssen `q`, `el` und `qel` herausgefiltert bzw. gesondert
  behandelt werden. Sonst zählen sie als Teammeldung, z. B. in `markAccepted`, `headMsg`, `latestFor`, Chips, ungelesen,
  `noteReceived`, Abschluss-Prüfung (`openPoints`), GPX/PDF/Bericht (`msgWaypoints`/`msgRows`) und `checkCloseAsk`.
  - Am saubersten: In `pollLive` die eigenen bzw. EL-Arten (`a === 'EL'`) in `P.live.out` ablegen, nicht in `l.msgs`.
  - `qel` von HF geht in `P.live.reads` (`{ elMsgId: { auftragId: t } }`).
  - `l.msgs` bleibt so frei von den neuen Arten.
  - Diese Aufteilung als reine Funktion `splitIncoming(fresh)` → `{ team, el, reads }` mit Test.

## 2. Einsatzleitung (app.js)

- **Senden:** gemeinsamer Helfer `elSend(m)`. Er verschlüsselt mit `P.live.key`, schickt per `postMsg` an `P.live.url`
  und legt bei Fehler in `P.live.outbox` ab. Bei `online`, `visibilitychange` und alle 60 s wird mit `flushOutbox`
  nachgesendet. Die gesendeten EL-Nachrichten stehen in `P.live.out` (für Anzeige und Lesestatus).
- **Quittung:**
  - `showUrgent`: nach „✓ Gesehen“ für jede bestätigte Meldung `buildAck` senden.
  - Normale Meldungen: beim Öffnen des Statuspanels bzw. wenn eine Meldung als gelesen gilt. Das Gelesen-Signal aus
    `checkUnread`/`msgRecv` nutzen; quittiert wird automatisch, ohne neuen Knopf.
- **Nachricht schreiben:**
  - Im Statuspanel (`#panel-status`) oben „✉️ Nachricht an …“: Auswahl „Alle Teams“ oder ein Team (nur Aufträge mit
    `live`), Textfeld, Häkchen „Wichtig (Ton beim HF)“, Senden.
  - Zusätzlich im Team-Chip bzw. Auftragsdialog ein Knopf „✉️ Nachricht“ mit vorgewähltem Team, wenn es einfach geht.
- **Anzeige:**
  - Im Statuspanel erscheinen die EL-Nachrichten in der Zeitleiste, rechtsbündig bzw. anders hinterlegt (Klasse
    `st-el`), mit „👁 gelesen: Alpha, Bravo“ bzw. „noch ungelesen“. Liegt die Nachricht noch in der Outbox, steht dort
    „⏳ wartet auf Netz“.
  - Quittierte HF-Meldungen bekommen in der EL-Liste kein Extra.
- Kein Senden, wenn das Projekt `closed` ist oder kein Auftrag mit `live` existiert. Dann ist der Knopf ausgeblendet.

## 3. Hundeführer (app.js)

- **Abholen:** neue Funktion `pollHf()`, alle 20 s und bei `online`/`visibilitychange`, nur wenn `db.mode === 'hf'`,
  `P.hf.ls` gesetzt, Fenster sichtbar und online.
  - Sie benutzt `pollMessages({ url, key, since: P.hf.since })` und filtert mit `forHf(msgs, P.hf.a)`. Die passende
    Auftrags-ID aus `P.hf` nehmen und nachsehen, wie sie heißt.
  - Ergebnis: `P.hf.inbox` (Liste, ohne Doppelte, höchstens 200), `P.hf.since` merken.
  - Den ersten Abruf mit `since` = Zeit der Auftragsübernahme minus 10 min machen, damit nicht der ganze Raum (7 Tage)
    kommt.
- **Lesebestätigung sichtbar:**
  - Im HF-Meldungsprotokoll („Meine Meldungen“ / `P.hf.log`-Liste) steht hinter jeder quittierten Meldung „✓ gesehen“.
  - Nach dem Senden eines Fundes oder Hilfe-Rufs wechselt der Toast bzw. die Statuszeile von „gesendet“ zu „✓ von der
    Einsatzleitung gesehen“, sobald die Quittung da ist (einmaliger Toast).
- **Nachricht empfangen:**
  - Neue `el`-Nachricht → Toast „✉️ Einsatzleitung: …“ (8 s) und ein roter Punkt an einem neuen Knopf „✉️“ im
    HF-Menü bzw. in der Auftragskarte `#hfinfo`.
  - Antippen öffnet die Liste der EL-Nachrichten (neueste oben) und sendet für ungelesene `buildReadAck`.
  - `prio: 1`: zusätzlich `beep()`, Vibration und ein Fenster mit dem Text und „Verstanden“. Erst danach geht `qel` raus.
  - Nachrichten an „Alle“ und an das eigene Team werden gleich dargestellt; „an alle“ steht klein dabei.
- `qel` geht über die normale HF-Outbox (`sendStatus`-Pfad ohne Position, `NO_POS` ergänzen).
  - Es darf beim HF **nicht** im eigenen Protokoll bzw. QR-Rückmeldung als Meldung erscheinen und nicht `markAccepted`
    auslösen.
  - Es darf bei Abschluss bzw. GPX nicht mitzählen.

## 4. Robustheit und Grenzen

- **Ohne Status-Server** (`ls` leer, Rückmeldung nur per QR) gibt es keinen Rückkanal. Die Knöpfe sind ausgeblendet; die EL
  sieht beim Team den Hinweis „kein Live-Kanal“.
- Datenmenge: Der HF bekommt bei jedem Abruf nur Zeilen nach `since`. Fremde HF-Zeilen werden entschlüsselt und verworfen.
  Das ist in Ordnung, weil der Raum klein ist.
- Ältere App-Versionen ignorieren die neuen Arten:
  - Ein alter HF pollt nicht.
  - Eine alte EL sieht `qel` als unbekannte Meldung. Das ist akzeptabel, weil EL und HF normalerweise aktualisiert sind;
    in der Statusliste erscheint dann höchstens der Code.
  - Prüfen, dass `statusLabel` bei unbekanntem Code nicht abstürzt; das tut es heute nicht.
- `P.live.out`/`P.hf.inbox` müssen beim Speichern und Laden (`store.js`/`normalize`) mit Standardwerten versehen
  werden, damit alte Projekte laden.

## Tests

- **Unit:** `node --test test/*.mjs` grün, neu: `rueck.test.mjs`. Inhalt:
  - `buildAck`/`buildElMsg`/`buildReadAck`
  - `forHf`: eigenes Team, alle, fremdes Team und HF-Meldungen werden ignoriert
  - `ackedIds`, `readBy`, `splitIncoming`
  - EL-Arten verändern `headMsg`/`latestFor`/`openPoints`/`msgWaypoints` nicht
- **e2e:** neues Skript `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/v117-e2e.mjs` mit
  Status-Server-Mock. `page.route` auf `https://script.google.com/**` mit einem gemeinsamen In-Memory-Raum für zwei
  Browser-Kontexte (EL und HF); das Muster aus `status-e2e.mjs`/`v116-e2e.mjs` übernehmen. Ablauf:
  1. Die EL erstellt einen Auftrag mit Live, der HF übernimmt ihn.
  2. Der HF meldet „Person gefunden“, die EL bestätigt mit „Gesehen“, der HF zeigt „✓ gesehen“.
  3. Die EL schickt eine Nachricht an alle (wichtig): Toast, Fenster und „Verstanden“ beim HF. Danach zeigt die EL
     „gelesen: Team“.
  4. Die EL schickt eine Nachricht nur an Team B: Der HF von Team A sieht sie nicht (zweiter HF-Kontext, wenn machbar,
     sonst Unit-Test reicht).
  5. Offline senden bei der EL → „wartet auf Netz“ → online → zugestellt.
  - Screenshots Tablet 1280×800 (EL) und Handy 412×860 (HF).
- **Bestehende e2e-Skripte** bleiben grün: areas, progress, tapclose, accept, close, status, park, longpress, hidden,
  licence, vertex, gridfit, noteam, reorder, robust, bedienung, edit, v116. Gewollte Änderungen im Bericht nennen.
- **Testserver:** Liefert curl nicht 200, starten mit `cd web && (nohup python3 -m http.server 8765 >/dev/null 2>&1 &)`.
  Niemals `pkill -f`. Skripte laufen mit `NODE_PATH=$(npm root -g) node …`.
- **Nicht** committen, deployen oder die Version ändern; kein git checkout, stash oder reset. Code.gs nicht ändern.
