# Plan v114: Robustheit (Befunde der Code-Prüfung vom 31.10.2026)

Grundlage: `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/audit/code.md`. Die Nummern beziehen sich
auf diesen Bericht, dort stehen auch Zeilen und Auslöser. Klaas hat vorab entschieden: Eindeutige Fehler werden sofort behoben.
Nur das unten Genannte umsetzen. H1 (Notion-Token) und N7 (Lizenz) **nicht** anfassen, darüber entscheidet Klaas.

## Fehler beheben
1. **H2 Speicher voll:**
   - `saveNow()` gibt `true` bzw. `false` zurück.
   - `addPhoto` und die übrigen Stellen, die „gespeichert“ melden (grep nach `toast(` in der Nähe von `saveNow`), melden bei `false`
     keinen Erfolg.
   - Bei einem Speicherfehler erscheint eine dauerhafte rote Leiste (nicht als Toast):
     „⚠️ Speicher voll – Einsatz jetzt exportieren (Mehr → Einsatz speichern) und alte Einsätze/Fotos löschen“.
     Sie verschwindet beim nächsten erfolgreichen Speichern.
   - IndexedDB-Umbau ist nicht Teil dieser Version.
2. **M1 Startkette:**
   - `chooseModeIfNeeded().then(handleHash)…` so umbauen, dass `startStatus()` und der Rest auch nach einem Fehler laufen
     (`.catch(e => toast('Link/Code konnte nicht gelesen werden'))` vor dem letzten `.then`, oder `finally`).
   - `handleShared` bzw. der `hashchange`-Handler fangen Fehler ab und zeigen dieselbe Meldung.
   - In `applyResult` die Einträge vor jeder Änderung prüfen, damit nicht nur ein Teil übernommen wird. Das geht z. B. so: erst alle
     dekodieren (try), dann anwenden.
3. **M2 innerHTML:**
   - `dlgButton` und `wizBtn` erhalten Text und Untertitel getrennt bzw. maskieren Fremdtext.
   - An allen Aufrufern mit Fremddaten (5261 Gerätename, 4058 Meldungstext, 6100 EL-Name) wird `esc()` verwendet. Gibt es kein
     `esc()`, eins anlegen.
   - Zusätzlich die Namen in `normalizeProject` (`peers[].name`, `from`) auf 60 Zeichen kürzen.
4. **M3 Wetter-Schleife:** Den Zeitpunkt des letzten Fehlschlags merken. Das automatische Nachladen aus `renderWx` startet frühestens
   60 s danach.
5. **M4 Timeouts:**
   - Hilfsfunktion `fetchT(url, opts, ms = 15000)` mit `AbortController`.
   - Verwenden in status.js (Senden und Abholen), weather.js und search.js (Nominatim/Overpass/Photon, soweit dort noch kein Signal
     verwendet wird).
   - `liveBusy` und `flushBusy` werden immer im `finally` zurückgesetzt (prüfen).
6. **M6 simplify:** Bei einem geschlossenen Ring (der erste Punkt ist gleich dem letzten) den Ring am weitesten entfernten Punkt teilen
   oder den doppelten Schlusspunkt vorher entfernen und danach wieder anhängen. Unit-Test: Quadrat mit Schlusspunkt bleibt 5 Punkte
   bzw. ein Viereck.
7. **M7 loadScript:** Pro `src` ein Promise cachen. Bei `onerror` das Element entfernen und den Cache leeren.
8. **M8 Status-Server-Host:**
   - In `normalizeProject` (store.js) `live.url` und `hf.ls[0]` nur übernehmen, wenn sie mit `https://script.google.com/` beginnen;
     es ist dieselbe Prüfung wie in share.js, also eine gemeinsame Hilfsfunktion verwenden.
   - Nicht passende Werte werden verworfen.
   - Unit-Test dazu.
9. **N4 Offline-Kacheln:** Bei HTTP 4xx nicht erneut versuchen. Das gilt für offline.js und android TileDownloadService.kt.
10. **N3:** Bei `QuotaExceededError` in offline.js anhalten und „Speicher voll“ melden.
11. **N5:** `switchProject` beendet eine laufende Aufzeichnung (`stopRec`), bevor es `P` wechselt.
12. **N9:**
    - sw.js und OfflineTiles.kt: Die Host-Prüfung lautet `host === h || host.endsWith('.' + h)`.
    - MainActivity.kt `receiveFile`: das Schema `file` nicht mehr annehmen. Vorher prüfen, ob „Öffnen mit“ aus Dateimanagern
      `content:` liefert; tut es das nicht, die Stelle unverändert lassen und das im Bericht vermerken.
13. **Fehlermeldung GPS:** Die Meldung „Standort nicht verfügbar: “ bzw. „GPS: “ mit leerem `error.message` bekommt einen Standardtext
    („kein GPS-Empfang“).

## Unnützer Code entfernen
- `progressTotal` (progress.js).
- Der Import von `teamMsgs` in app.js. Die Funktion samt Test bleibt.
- CSS `.fchips`, `.fchip-wrap` und `#dlg-box .fchip*` (style.css ~637–643).
- Die überflüssigen ID-Attribute `vtx-info`, `apk-link`, `send-fields-label` und `send-fields-box`. Vorher mit grep prüfen, auch in den
  Tests und in /tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/*.mjs.
- Die losen Screenshots in der Projektwurzel (`labels-*.png`, `orders-*.png`, `park-*.png`) mit `rm` löschen; git erledige ich.

## Tests
- `node --test test/*.mjs` grün, mit neuen Unit-Tests für M6, M8 und `fetchT`, sofern rein testbar.
- Playwright im Scratchpad `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/robust-e2e.mjs`
  (Vorlage `areas-e2e.mjs`):
  1. Start mit kaputtem Hash `#a=xyz`: Meldung erscheint, `startStatus` lief (z. B. `window.__app` prüfen oder ein Fetch auf
     `/macros/` wird ausgelöst).
  2. `localStorage.setItem` per `page.addInitScript` mit einem Quota-Fehler ab dem 2. Aufruf: Die rote Leiste erscheint, kein
     „Foto gespeichert“.
  3. Gerätename `<img src=x onerror=window.__xss=1>` über einen Fortschritts- bzw. Übergabe-Link: Es wird kein Skript ausgeführt,
     der Name erscheint als Text.
- Bestehende e2e-Skripte müssen grün bleiben, Ausgabe „ALLES OK“ bzw. alle OK: areas, progress, tapclose, accept, close, status,
  park, longpress, hidden, licence, vertex, gridfit, noteam, reorder.
- Server: `cd web && (nohup python3 -m http.server 8765 >/dev/null 2>&1 &)`, falls curl nicht 200 liefert. Niemals `pkill -f`.
  Skripte mit `NODE_PATH=$(npm root -g) node …` starten.
- **Nicht** committen, deployen oder die Version ändern; kein git checkout, stash oder reset.
