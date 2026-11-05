# PLAN v124 – 📤 Zeichnung mit Auftrag an den ELW · 🗺️ In BaseCamp öffnen

## Ziel (Entscheidungen von Klaas)
Ein EL-Gerät vor Ort (z. B. „Handy EL“) zeichnet mit Stift/Umriss und schickt die Zeichnung
mit einem **Auftragstext** an ein anderes EL-Gerät (z. B. „ELW“-PC mit der Web-App):
„In 2 Gebiete aufteilen“, „2× DRK, 1× JUH“, „Aufzeichnen und drucken“, Freitext.
- Übergabe: **über den Live-Raum (Status-Server / Google Sheets), Ende-zu-Ende verschlüsselt**
  wie die Statusmeldungen (encryptMsg, gleicher Raum `P.live`). In der Tabelle ist nichts lesbar.
- Der ELW **zeigt nur an** (Mensch entscheidet, nichts wird automatisch geteilt/zugewiesen).
- Beim ELW per Knopfdruck: **„➕ In laufenden Einsatz einfügen“** (Gebiete/Striche landen im
  offenen Einsatz der Web-App) und **„🗺️ In BaseCamp öffnen“** (ein Klick, GPX direkt).
- Zusätzlich allgemein: **„🗺️ In BaseCamp öffnen“** im GPX-Export (ohne Teilen-Menü/Dateidialog).

## Bestand (im Code nachlesen)
- `status.js`: `encryptMsg/decryptMsg`, `roomOf`, `flushOutbox`, `pollMessages`, `okMsg`,
  `EL_KINDS = ['q','el','qel']`, `buildElMsg`, `forHf` (HF sehen nur `q`/`el` an sie).
- `app.js`: `elSend(m)` (Outbox, `flushStatus`), Abholen in der Status-Schleife (~5477
  `pollMessages(l)`), `ackSeen`, `needsAck` (EL-Arten werden nicht quittiert),
  `db.deviceName` / `askDeviceName`, `devBy()`; „Fortschritt senden“ (~6069) und
  `progress.js` (`buildProgress`/Übernehmen „nur ergänzen“) als Vorbild für Einfügen ohne Löschen.
- Server `apps-script/Code.gs`: `MAX_DATEN = 20000` Zeichen je Zeile (verschlüsselt, base64).
  **Server nicht ändern** (Klaas müsste neu bereitstellen) → große Zeichnungen in Teile splitten.
- GPX: `buildGpx`/`selectionGpx` in gpx.js; Export-Dialog ~8009–8070 (`saveFiles`, `download`).
- Ein ELW-Gerät hat den Einsatz per Übergabe (QR) – prüfen, ob `P.live` (url+key) dabei mitkommt.
  Nur wenn beide Geräte denselben Live-Raum haben, geht der Weg; sonst klarer Hinweis
  („Live-Kanal fehlt – Einsatz erst per QR übergeben bzw. Status-Server einrichten“).

## Umsetzung

### 1. Reine Logik (neu `web/elw.js`, Unit-Tests `test/elw124.test.mjs`)
- `buildElwOrder({ from, to, txt, items, t, id })` → Nachricht `{ s:'elw', a:'EL', id, t, from, to, txt, items }`.
  `items`: Kopien der gewählten Zeichnungen (`kind` 'track'/'line'/Stift-Striche – die im Projekt
  vorhandenen Formen verwenden), Koordinaten auf 6 Nachkommastellen gerundet, ohne interne Felder
  die beim Empfänger stören (Team-Zuordnung `to` nur als Name `toName` mitgeben, nicht als ID).
- `splitElwOrder(msg, maxChars)` → Liste von Teilen `{ s:'elwp', a:'EL', id, t, oid, n, of, part }`,
  wenn die JSON-Länge zu groß ist (Grenze so wählen, dass verschlüsselt < 20000 bleibt, z. B. 9000 Zeichen Klartext).
  `joinElwParts(msgs)` → vollständige Aufträge (nur wenn alle Teile da sind).
- `elwInbox(msgs, myName)` → empfangene Aufträge: nur `s:'elw'`, nicht vom eigenen Gerät
  (`from !== myName`), `to` leer/„alle“ oder = myName; neueste zuerst; doppelte IDs weg.
- `mergeElwItems(p, items, oid)` → fügt Items mit neuen IDs ein, **nur ergänzen**; mehrfaches
  Einfügen desselben Auftrags erzeugt keine Duplikate (Herkunft `elw: oid` an den Items merken).
- `elwTemplates` = ['In 2 Gebiete aufteilen', 'In 3 Gebiete aufteilen', '2× DRK, 1× JUH',
  'Aufzeichnen und drucken', 'Als Suchgebiet übernehmen'] (Schnellwahl, Text bleibt editierbar).
- `EL_KINDS` um `'elw','elwp'` erweitern (damit HF sie nie sehen und nichts quittiert wird) –
  bestehende Tests müssen grün bleiben.

### 2. Senden (EL)
- Panel „Mehr“ (EL): Abschnitt „📤 An ELW senden“ mit Knopf; zusätzlich in der Stift-/Umriss-Leiste
  oder im Langdruck-Menü eines Umrisses nicht nötig – Mehr reicht (plus ggf. Statuspanel).
- Fenster: Liste der Zeichnungen (Umrisse + Stift-Striche) mit Häkchen; vorausgewählt = alles,
  was seit dem letzten ELW-Senden neu/geändert ist (Zeitstempel im Projekt merken), sonst alles.
  Empfänger: Auswahl aus bekannten Gerätenamen (`proj.peers` o. ä.) oder „alle EL-Geräte“, Freitext.
  Auftrag: Schnellwahl-Knöpfe + Textfeld. Knopf „📤 Senden“.
- Senden über `elSend` (Outbox – ohne Netz wartet es und geht später raus, Toast wie bei Nachrichten).
- Ohne `P.live`: Hinweis wie oben, nichts senden.

### 3. Empfangen (ELW)
- In der bestehenden Abhol-Schleife: `elw`/`elwp` erkennen, Teile zusammensetzen, in
  `P.elwIn` (Liste, max. 50) speichern; neuer Auftrag → kurzer Ton (`beepShort`) und Toast
  „📥 Auftrag von Handy EL: In 2 Gebiete aufteilen“ mit Tipp zum Öffnen.
- Anzeige: Knopf/Plakette „📥 Aufträge (n)“ (nur EL, nur wenn welche da sind – z. B. im Statuspanel
  oder oben neben der Einsatz-Plakette; die vorhandenen Stellen wählen, Platz auf dem Handy prüfen).
- Auftrags-Fenster: Absender, Uhrzeit, Auftragstext groß, Anzahl Zeichnungen; Vorschau auf der
  Karte (gestrichelt, eigene Farbe, solange das Fenster offen ist / „👁 Zeigen“ zoomt hin).
  Knöpfe: **„➕ In laufenden Einsatz einfügen“** (mergeElwItems, ein Rückgängig-Schritt, Toast),
  **„🗺️ In BaseCamp öffnen“** (GPX nur dieser Zeichnungen, siehe 4),
  **„✓ Erledigt“** (abhaken, bleibt grau in der Liste), „Schließen“.
- Drucken: nach „Einfügen“ normal über die vorhandene PDF-Funktion; im Fenster Hinweis/Knopf
  „🖨️ Karten-PDF“ der den vorhandenen PDF-Dialog öffnet (nicht neu bauen).

### 4. „🗺️ In BaseCamp öffnen“
- Lädt die GPX **direkt herunter** (`download(blob, name)`, kein Teilen-Menü, kein Dateidialog);
  Toast: „GPX geladen – unten im Browser anklicken, öffnet BaseCamp (wenn .gpx mit BaseCamp verknüpft ist)“.
- Im vorhandenen GPX-/BaseCamp-Exportdialog als zusätzlicher Knopf (Desktop/Web; in der APK
  weglassen oder dort auf den bestehenden Weg leiten).

## Tests
- Unit `test/elw124.test.mjs`: build/split/join (inkl. fehlender Teil → nichts), elwInbox
  (eigene ausgeblendet, an anderes Gerät adressierte ausgeblendet, „alle“ sichtbar), mergeElwItems
  (zweimal einfügen = keine Duplikate, nichts gelöscht), Rundung, HF-Filter `forHf` ignoriert `elw`.
  Alle bisherigen 350 Tests grün.
- e2e im Scratchpad `elw-e2e.mjs`: zwei Browser-Kontexte (Handy EL + ELW-PC 1280×800) mit demselben
  Einsatz und Live-Raum; Status-Server per `page.route` simulieren (POST speichert Zeilen, GET liefert
  sie zurück – siehe vorhandene e2e mit Live-Server, z. B. status-e2e.mjs / v117-e2e.mjs als Vorbild).
  Handy zeichnet 2 Umrisse + 1 Strich, Auftrag „2× DRK, 1× JUH“, sendet → ELW bekommt Toast,
  öffnet Auftrag, „Einfügen“ (Items da), nochmal „Einfügen“ (keine Duplikate), „In BaseCamp öffnen“
  (Download-Event mit .gpx, Inhalt enthält die Umrisse). Große Zeichnung (viele Punkte) → Teile.
  HF-Gerät im selben Raum zeigt nichts davon. Screenshots Telefon + Tablet ansehen, keine JS-Fehler.
  BKG-Kacheln per Route mit PNG beantworten (wie fallback-e2e.mjs).
- Zusätzlich grün: status-e2e.mjs, v117-e2e.mjs, v116-e2e.mjs, progress-e2e.mjs, bedienung-e2e.mjs, nav-e2e.mjs.

## Nicht tun (Agent)
Kein Commit, kein Push, kein `deploy.sh`, keine Versionsnummern (`APP_VERSION`, `sw.js` `VERSION`,
`ROADMAP.md`), kein `pkill -f`, `apps-script/Code.gs` nicht ändern.
