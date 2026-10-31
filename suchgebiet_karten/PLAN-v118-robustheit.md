# Plan v118: Robustheit (Fehler aus der Prüfung vom 31.10.)

## Grundlage

Klaas hat am 31.10. diese Fehler aus dem Code-Audit zur Behebung gewählt (`scratchpad/audit/code.md` N1, N2, M9, M5, N6):

1. Ein abgelehnter Eintrag blockiert die Warteschlange.
2. Startabsturz bei einem defekten Projekt.
3. Live-Schlüssel steckt im PDF bzw. in der Einsatzdatei.
4. Ein zweiter Tab bzw. ein zweites Fenster überschreibt den Stand.
5. GPS-Track: getrennt und gebündelt speichern.

**Nicht** Teil dieser Version: „Hilfe sofort speichern“ und neue Funktionen.

## 1. Warteschlange: abgelehnte Einträge blockieren nicht mehr (status.js)

- **Heute:**
  - `flushOutbox` bricht beim ersten Fehler ab.
  - `postMsg` wirft auch bei `{ ok: false }`.
  - Eine dauerhaft abgelehnte Meldung (Server-Antwort `ok:false`, z. B. Daten zu groß bzw. „Raum“ oder ID ungültig) wird endlos wiederholt. Alles dahinter hängt.
- **Neu:**
  - `postMsg` unterscheidet zwei Fälle:
    - **Netz- bzw. HTTP-Fehler** (fetch wirft, Status ≠ 2xx, kein JSON) → wirft `Error('netz')`. Abbrechen und später erneut versuchen, wie heute.
    - **Server antwortet `ok:false`** → wirft einen Fehler mit `rejected = true` und `reason = j.fehler`.
  - `flushOutbox` nimmt eine abgelehnte Meldung aus der Warteschlange und macht weiter.
  - Rückgabe: `{ sent, left, rejected: [{ id, reason }] }`.
  - Vorher in `apps-script/Code.gs` nachsehen, welche `fehler`-Antworten es bei doPost gibt. Ist eine davon vorübergehend (z. B. Lock-Timeout), gilt sie als Netzfehler. Wenn nötig, eine Liste `TEMP_REJECT` anlegen.
- **app.js:**
  - Alle Aufrufer von `flushOutbox` übernehmen `rejected`: HF-Outbox in `flushStatus` und EL-Outbox aus v117.
  - Abgelehnte Meldungen im HF-Protokoll markieren (`m.rej = reason`), dazu der Toast „⚠️ Meldung vom Server abgelehnt: …“.
  - Im Meldungsprotokoll steht bei einer abgelehnten Meldung „⚠️ nicht zugestellt“.
- **Unit-Tests:**
  - Die zweite von drei Meldungen wird abgelehnt: 1 und 3 sind gesendet, 2 steht in `rejected`.
  - Ein Netzfehler bei 2 bricht ab: 2 und 3 bleiben in `left`.

## 2. Start übersteht ein defektes Projekt (app.js `load()` ~113, store.js)

- `normalizeProject` läuft pro Projekt in einem try/catch.
  - Wirft es, kommt das Rohprojekt unter `localStorage['sgk-quarantaene-<id>']` (JSON, höchstens 3 Einträge; älteste löschen, Fehler beim Schreiben ignorieren) und wird aus `db.projects` entfernt.
  - Toast nach dem Start: „⚠️ Ein Einsatz war beschädigt und wurde beiseitegelegt (Mehr → Fehlerbericht senden)“.
  - Ist `currentId` betroffen, wird ein anderer Einsatz gewählt bzw. ein neuer angelegt.
- **Kaputtes JSON im Speicher:** Vor dem Neustart den Rohstring unter `sgk-defekt-<Zeit>` sichern (nur einer, älteren überschreiben). Sonst überschreibt der erste `save()` die Daten unwiederbringlich.
- `normalizeProject` selbst robuster machen, wo es billig ist: `marks`/`items`/`grids` mit `null`-Einträgen filtern, bevor auf `.kind` usw. zugegriffen wird.
- **Unit-Tests:** `normalizeProject` mit `marks: [null, …]` wirft nicht. Für die Quarantäne gibt es eine reine Hilfsfunktion (z. B. `loadProjects(raw) → { projects, broken }` in store.js) mit Test.

## 3. Kein Live-Schlüssel im PDF bzw. in der weitergegebenen Einsatzdatei (store.js `exportProject`/`embedMarker`, pdf.js)

- **Im PDF eingebetteter Block:** Diese Felder fallen weg:
  - `live` (Schlüssel, Meldungen)
  - `hf.ls`, `hf.outbox`, `hf.inbox`
  - `sent[].live` bzw. andere Stellen, an denen `ls` oder `key` steckt (alles nach `key` und `ls` durchsuchen)
  - Fotos, falls einfach
- Das PDF bleibt als Karte importierbar: Raster, Umrisse, Teams, Felder, Markierungen.
- **„Einsatz exportieren“ als Datei** (Übergabe an eine andere EL) behält alles. Das ist gewollt, denn die Übergabe braucht den Schlüssel. Nur das PDF wird bereinigt. Prüfen, welche Funktion welchen Weg nimmt, und es im Bericht nennen.
- Reine Funktion `stripSecrets(project)` in store.js, mit Unit-Test: keine Zeichenkette „key“ bzw. kein `ls` im Ergebnis, Raster bleibt erhalten.

## 4. Zweiter Tab bzw. zweites Fenster erkennen und sperren (app.js)

- **Heute:** `reloadFromStorage` (app.js, `storage`-Ereignis) ersetzt `db`/`P` durch den Stand des anderen Tabs. Laufende Abläufe schreiben dann ins Leere.
- **Neu:**
  - Die Sperre läuft mit `navigator.locks.request('sgk-main', { ifAvailable: true }, …)`, wo vorhanden. Sonst gibt es einen BroadcastChannel-Ping (`sgk-tabs`), der innerhalb von 300 ms eine Antwort erwartet.
  - Bekommt ein Fenster die Sperre nicht, ist es **zweites Fenster**: Vollbild-Hinweis „Die App ist schon in einem anderen Fenster offen. Bitte dort weiterarbeiten.“ mit dem Knopf „Hier weiterarbeiten“.
  - „Hier weiterarbeiten“ schickt per BroadcastChannel `take` an das erste Fenster. Das erste speichert sofort (`saveNow`), zeigt selbst den Hinweis und gibt die Sperre frei. Danach lädt das zweite den Speicher neu und übernimmt die Sperre.
  - Solange ein Fenster gesperrt ist, schreibt es **nie** in den Speicher (`save` bzw. `saveNow` sind no-op) und pollt nicht.
- Das bisherige `reloadFromStorage` bleibt als Rückfall nur, wenn weder Locks noch BroadcastChannel vorhanden sind.
- **APK (WebView):** Es gibt nur ein Fenster. Die Sperre greift sofort; darauf achten, dass nichts hängt, wenn `navigator.locks` fehlt.
- **e2e:** Zwei Seiten im selben Kontext:
  - Die zweite zeigt den Hinweis.
  - Eine Änderung im ersten Fenster bleibt erhalten.
  - „Hier weiterarbeiten“ tauscht die Rollen.

## 5. GPS-Weg getrennt und gebündelt speichern (app.js ~2990 Aufzeichnung)

- **Heute:** Jeder GPS-Punkt ruft `save()` auf. Das löst `saveNow()` mit `JSON.stringify` des gesamten `db` aus (bis zu alle 300 ms) und lässt das Handy ruckeln.
- **Neu:**
  - Neue Punkte der laufenden Aufzeichnung kommen zusätzlich in einen kleinen eigenen Speicher `localStorage['sgk-track-<projektId>']`. Darin steht nur das laufende Segment (`recSeg.pts`), höchstens alle 5 s geschrieben.
  - Der Gesamtspeicher wird während der Aufzeichnung höchstens alle 30 s geschrieben, sowie bei `visibilitychange` (hidden), `pagehide` und beim Stoppen.
  - **Beim Start:** Liegt ein `sgk-track-*` vor, das mehr Punkte hat als das letzte Segment im Projekt, wird es eingearbeitet (Absturz zwischen zwei Gesamtspeicherungen). Danach den Schlüssel löschen.
  - Das gilt nur für die Weg-Aufzeichnung. Alle anderen `save()`-Aufrufe bleiben unverändert.
- Reine Hilfsfunktion `mergeTrackBackup(track, backup)` mit Unit-Test.
- **e2e:** Die Aufzeichnung läuft mit simulierten Positionen. Dann ein harter Reload ohne `pagehide` (z. B. `page.close({ runBeforeUnload: false })` und neue Seite), danach sind die Punkte vorhanden.

## Tests

- **Unit:** `node --test test/*.mjs` grün, neue Tests zu 1, 2, 3 und 5. Am besten in einer neuen `test/robust118.test.mjs` bzw. bei den passenden Dateien.
- **e2e:** Neues Skript `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/v118-e2e.mjs`, je Punkt eine Prüfung mit Screenshots (Tablet 1280×800, Handy 412×860):
  - Warteschlange mit abgelehnter Meldung (Mock antwortet für eine ID `ok:false`)
  - Kaputtes Projekt im localStorage → App startet und zeigt den Hinweis
  - PDF-Export enthält keinen Schlüssel (eingebetteten Block auslesen wie in bestehenden Tests)
  - Zwei Tabs
  - Weg nach hartem Abbruch
- **Bestehende e2e-Skripte** bleiben grün: areas, progress, tapclose, accept, close, status, park, longpress, hidden, licence, vertex, gridfit, noteam, reorder, robust, bedienung, edit, v116, v117.
  - Viele davon öffnen mehrere Seiten im selben Kontext (EL und HF). Prüfen, dass Punkt 4 sie nicht stört. Wenn nötig, getrennte Kontexte nutzen und im Bericht nennen.
- **Testserver:** Liefert curl nicht 200, starten mit `cd web && (nohup python3 -m http.server 8765 >/dev/null 2>&1 &)`. Niemals `pkill -f`. Skripte laufen mit `NODE_PATH=$(npm root -g) node …`.
- **Nicht** committen, deployen oder die Version ändern; kein git checkout, stash oder reset. Code.gs nur lesen.
