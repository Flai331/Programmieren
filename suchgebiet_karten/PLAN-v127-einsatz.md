# PLAN v127 – Fehler aus dem Einsatz-Durchlauf beheben

Grundlage: Audit-Bericht `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/EINSATZ-DURCHLAUF.md`
(Abschnitt 2 „Gefundene Fehler“ – dort Reproduktion, Ursache, Vorschlag je Fehler; bitte zuerst lesen).
Test-Skripte/Fixtures dort: `mission-e2e.mjs`, `mission-lib.mjs`, `mission-fixtures.mjs`.

## Entscheidungen von Klaas (05.11.)
- **UA-Meldungen:** Ein Unterabschnitt (isUA) sieht im Status-Fenster/Plakette/Chips nur Meldungen
  seiner eigenen Teams (Teams in seinem `P.marks`). **Fund und Hilfe aller Teams** weiterhin überall
  (inkl. Dringend-Fenster). Der Grund-Einsatz (EL/ELW) sieht alles.
- **Team-Namen:** Haupt-Teams bleiben „Team 1“ (kein Kürzel). UA-Kürzel wie bisher.
- **ELW „Einfügen“:** schon vorhandene Gebiete erkennen und überspringen; Toast „n neu, m schon vorhanden“.
- **Live-Kanal:** entsteht beim Anlegen des Einsatzes (auch Assistent/leerer Einsatz) und geht mit jeder
  Übergabe (QR/Link) mit. Bestehende Einsätze ohne `P.live`: beim nächsten Öffnen/Übergeben anlegen.
  „Live-Kanal fehlt“ → stattdessen „Live-Kanal jetzt anlegen“ anbieten. Kein Dummy-Auftrag mehr nötig.

## Fehler (je mit Unit-Test, der vorher rot ist)
1. **F2 Relay-Verlust UA → ELW → EL** (progress.js `buildProgress`, `nw = t > since`): beim Übernehmen
   eines Fortschritts am Relay die Ankunftszeit merken (`ra` je Element o. ä., nicht mitsenden bzw.
   beim Empfänger ignorieren) und „neu seit“ = `max(t, ra) > since`. Gilt für alle Arten (Umrisse,
   Raster, Felder, Tracks, Meldungen, Lage-Orte, Wege, Protokoll …). Nach Empfang eines Fortschritts
   am Gerät, das selbst nicht der Grund-EL ist bzw. weitere Empfänger hat: Toast-Hinweis
   „Neues von UA Nord – an EL weiterleiten?“ mit Knopf, der den Fortschritt-Senden-Dialog öffnet.
2. **F1 Einfügen dupliziert** (elw.js `mergeElwItems`): vor dem Anlegen gegen vorhandene Items prüfen
   (Quell-ID `src.id` bzw. Herkunft, sonst Art + Name + Punkte-Hash, Rundung 6 Stellen – wie
   `dedupeImport` in gpx.js). Rückgabe `{ added, skipped }`, Toast wie oben.
3. **L1/F5 Live-Kanal** wie oben (share.js:184 `newLiveKey`; Übergabe `lv`). Unit-Test: Übergabe eines
   frischen Einsatzes enthält Live-Daten.
4. **F8 BaseCamp-Re-Import** (gpx.js `parseGpx` ~494, `dedupeImport` ~533): Namen
   `^(Rasterlinien|Feldnamen|Suchgebiet)\b` sowie unsere eigenen Export-Hilfstracks überspringen
   (Namen so prüfen, wie unser Export sie schreibt – im Export nachsehen); Striche (`stroke`/Zeichnungen),
   B-Ort und Lage-Orte wie Umrisse deduplizieren (Text-Punkte mit gleichem Namen ≈ gleicher Ort ≤ 15 m
   = vorhanden). Unit-Test mit der Datei aus `mission-fixtures.mjs` (BaseCamp_Export, 7 Nachkommastellen):
   nur „Rex“ kommt neu.
5. **F3 Umteilen still wirkungslos** (app.js `guardAssigned` ~6251): im offenen Umriss-Dialog die Sperre
   sichtbar machen (eigener Dialog nach Schließen des Umriss-Dialogs bzw. Hinweis im Dialog) und bei
   **abgeschlossenem** Auftrag gar nicht sperren. e2e: umteilen wirkt.
6. **F4 doppelte Teamnamen**: beim Anlegen/Umbenennen prüfen („Gibt es schon: Team 1 – trotzdem?“ bzw.
   neues Team bekommt automatisch nächste freie Nummer); Hundename im Dringend-Fenster mit anzeigen.
7. **F6 Wegnamen**: „Weg Team 1 (Rex) ab 19:47“ – Hundename in den Wegnamen; beim Zusammenführen
   `uniqueTeamLabel` auch auf Wegnamen anwenden.
8. **F7 GPX-Schnellexport** (`shareGpx`/`gpxSelFile`): Meldungen mit Ort standardmäßig mitgeben.
9. **F9 KML `gx:Track`** (`parseKml` ~558): `<gx:coord>lon lat alt</gx:coord>` lesen. Unit-Test.
10. **HF „Standort melden“**: Kategorie 🎒 „Fundstück (Kleidung/Gegenstand)“ ergänzen (aus `HF_MARKS`
    in `SPOT_LIST`), Textvorschläge „Jacke, Schuh, Mütze, Rucksack“.
11. Prüfen: im Audit liefen „Abschließen“ (HF Kira/Luna/Rex) und „Nachricht + Antwort“ beim ersten Lauf
    in Timeouts – klären, ob App-Fehler (z. B. verdeckter Knopf) oder Skript; falls App: beheben.

## Tests
- Unit: je Punkt; alle bisherigen (378) grün.
- e2e im Scratchpad: `mission-e2e.mjs` komplett grün mit den Fixes, ohne „Alles seit Beginn erneut senden“
  muss am EL alles ankommen; zusätzlich grün: progress, multi, status, v116, v117, v118, ua125, hfreply,
  elw, nav, update, bedienung. BKG-Kacheln per PNG-Route. Screenshots ansehen.
- e2e-Skripte nur aus dem Scratchpad ausführen (sie schreiben Screenshots relativ).

## Nicht tun (Agent)
Kein Commit, kein Push, kein `deploy.sh`, keine Versionsnummern, kein `ROADMAP.md`, kein `pkill -f`,
`apps-script/Code.gs` nicht ändern.
