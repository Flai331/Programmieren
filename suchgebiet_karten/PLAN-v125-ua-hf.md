# PLAN v125 – Unterabschnitt vollständig, Aufträge-QR jederzeit, HF antwortet, Scanner

Wünsche von Klaas (02.–05.11.), Reihenfolge = Priorität:

## 1. Fehler: UA → EL, neu angelegtes Gebiet kam beim EL nicht an
Klaas: „Ich habe Daten an den EL gesendet und der hat das Gebiet, was angelegt wurde, nicht erhalten (UA an EL).“
- Zuerst **nachstellen** mit Unit-Tests (Vorbild `test/progress.test.mjs`, `makeUA`, `edit`, `wire`):
  neuer Umriss im UA, neues Raster im UA (ohne Felder), Raster-Fläche geändert, per 🌲 Wald geteilte
  Umrisse, Umriss an ein **im UA neu angelegtes Team** zugeteilt, Felder dieses Teams.
- Verdacht A: `buildProgress` filtert `notTo(x)` = `x.by !== to` über **Gerätenamen**. Hat das UA-Gerät
  denselben Namen wie der Empfänger (z. B. beide „EL“, oder `devBy()` liefert 'EL', weil das Handy früher
  EL war), wird alles Neue weggelassen. → Herkunft mit **eindeutiger Geräte-ID** (es gibt eine
  Geräte-ID für die Freigabe, licence.js) statt Name vergleichen; Name nur Anzeige. Altdaten mit `by`-Namen
  weiter verstehen.
- Verdacht B: Felder/Zuteilungen mit Team-IDs, die beim EL (noch) nicht in `p.marks` sind, werden in
  `mergeProgress` verworfen (`!p.marks.some(m => m.id === id)` → continue). `mk` wird mitgeschickt –
  prüfen, ob Teams **vor** den Feldern übernommen werden; sonst Reihenfolge korrigieren.
- Verdacht C: neues Raster ohne Felder wird nur gesendet, wenn `gridT` gestempelt ist – prüfen.
- Fix + Tests, die vorher rot und danach grün sind.

## 2. UAL kann im UA alles, was den UA betrifft; alles geht an den EL zurück
- Alle `isUA(P)`-Einschränkungen in app.js auflisten (grep `isUA`, `parentEid`, `lockOf`, `canEdit`).
  Erlaubt sein soll im UA alles, außer Elemente des Grund-Einsatzes (lock 'base') zu löschen/ändern:
  Teams anlegen/umbenennen/sortieren, Raster und Umrisse anlegen/teilen, Aufträge (QR) an HF, Rückmeldungen
  scannen, Live-Status/Nachrichten, Lage-Orte, Kontakte, Protokoll/Einsatzdaten des UA, PDF, GPX.
- „Fortschritt senden“ vom UA an den EL nimmt **alles** mit: Teams (mk), Umrisse, Raster, Felder,
  Aufträge (`se`), Rückmeldungen/Wege, Meldungen, Lage-Orte, Kontakte (falls bisher nicht), Protokoll-Einträge.
  Was davon bisher fehlt, ergänzen (mit Unit-Test je Art).

## 3. Eigene Team-Namen im UA (keine Überschneidung)
- Neue Teams im UA heißen standardmäßig mit UA-Kürzel, z. B. „N-Team 1“ (Kürzel = erste Buchstaben des
  UA-Namens, editierbar in den UA-Einstellungen) – IDs sind ohnehin eindeutig (prüfen!).
- Beim EL: kommt ein Team, dessen Name schon von einem **anderen** Team benutzt wird, bekommt es den
  Zusatz „ (UA Nord)“. Unit-Test.

## 4. EL ruft jeden Auftrags-QR erneut auf
- In der Auftragsliste (`P.sent`, Statuspanel/„Aufträge“) bei **jedem** Auftrag – laufend, abgeschlossen –
  Knopf „📲 QR-Code erneut zeigen“ (gleicher Inhalt/gleicher Live-Kanal wie beim ersten Mal, nichts Neues
  anlegen). Für Teams mit Gebieten, aber **noch ohne Auftrag**: „📲 Auftrag erstellen“ führt direkt zum
  vorhandenen Auftrags-Ablauf. Gilt auch im UA.

## 5. Gebiete, die per Auftrags-QR übergeben werden, dem Team zuordnen
- Wählt der EL/UAL beim Auftrag für Team X Umrisse/Rasterfelder aus, die noch **keinem** Team zugeordnet
  sind, werden sie beim Erstellen des Auftrags Team X zugeordnet (`it.to = X`, Felder `fills = X`).
  Bereits einem anderen Team zugeordnete bleiben unverändert (Hinweis im Dialog). Ein Rückgängig-Schritt.
  Gilt auch im UA. Unit-Test der reinen Logik.

## 6. HF kann zurückschreiben
- Beim HF: in einer EL-Nachricht (v117) Knopf „✍️ Antworten“ und im ☰-Menü „✍️ Nachricht an EL“:
  Freitext (+ Schnellwahl „Verstanden“, „Brauche Rückruf“, „Bin am B-Ort“) → als Statusmeldung mit Text
  (vorhandenes `buildMsg` mit `txt`, ggf. `ref` auf die EL-Nachricht) über den Live-Kanal; ohne Netz
  Warteschlange wie die anderen Meldungen. EL sieht sie in der Liste/Plakette wie andere Meldungen
  (mit „↩︎ Antwort auf: …“). Unit-Test für Aufbau/Filter.

## 7. HF-Ansicht: Scannen
- Klaas findet in der HF-Ansicht keine Scan-Möglichkeit. `#hfm-scan` existiert im ☰-Menü – prüfen, wann es
  sichtbar ist; einen gut sichtbaren Knopf „📷 Scannen“ in der HF-Hauptansicht ergänzen (neuer Auftrag,
  Einsatz-Übergabe).

## 8. Scanner nimmt die Weitwinkel-Kamera
- `getUserMedia({ video: { facingMode: 'environment' } })` (app.js ~5779) landet auf Android oft bei der
  Ultraweitwinkel-Kamera (unscharf im Nahbereich). Neu: nach erster Freigabe `enumerateDevices()`, Rückkameras
  nach Label bewerten (bevorzugt „camera2 0“/„camera 0“/„back“ ohne „wide“, „ultra“, „0.5“, „tele“,
  „depth“), mit `deviceId: { exact }` öffnen, `width/height ideal 1920×1080`, `focusMode: 'continuous'`
  wenn unterstützt. Im Scanfenster Knopf „🔄 Kamera wechseln“ (reihum), Wahl in localStorage merken (try/catch).
  Reine Bewertungsfunktion mit Unit-Test.

## Tests
- Unit: neue Tests je Punkt; alle bisherigen grün.
- e2e (Scratchpad): `ua125-e2e.mjs` (UA anlegen, neues Gebiet + Team, Fortschritt zum EL → kommt an,
  Team-Name mit Kürzel, QR erneut zeigen, Zuordnung beim Auftrag), `hfreply-e2e.mjs` (HF antwortet, EL sieht es;
  Status-Server per route simuliert wie v117-e2e.mjs), Scanner: getUserMedia/enumerateDevices im Browser
  mocken und prüfen, dass die Hauptkamera gewählt wird. BKG-Kacheln per PNG-Route.
- Zusätzlich grün: progress-e2e, multi-e2e, status-e2e, v116/v117/v118-e2e, bedienung-e2e, nav-e2e, elw-e2e.

## Nicht tun (Agent)
Kein Commit, kein Push, kein `deploy.sh`, keine Versionsnummern, kein `ROADMAP.md`, kein `pkill -f`,
`apps-script/Code.gs` nicht ändern.
