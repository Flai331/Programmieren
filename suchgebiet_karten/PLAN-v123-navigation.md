# PLAN v123 – 🧭 Navigation zu jedem Ziel über Google Maps

## Ziel
Von jedem Ziel aus öffnet sich die Route in Google Maps bzw. in der Karten-/Navi-App
des Handys, wahlweise **🚗 Auto** oder **🚶 zu Fuß**. Das gilt für Einsatzleitung (EL)
und Hundeführer (HF).

Entscheidung des Nutzers: **keine Navigation in der App**. Es gibt kein Routing in der
App, keinen Zielpfeil und keinen Kompass. Die App öffnet nur den Link.

## Bestand
- `hfnav.js`: `navUrl(lat, lon)` erzeugt den Google-Maps-Link
  `https://www.google.com/maps/dir/?api=1&destination=lat,lon`.
- `navTargets(p)` liefert die Ziele des HF-Auftrags: Parkplätze, B-Ort, Gebietsmitte.
- app.js: Knopf `#hfm-nav` (☰ Mein Auftrag → 🧭 Navigation) öffnet eine Zielliste.
  Links öffnet `openLink(url)`; die APK öffnet damit externe Apps.

## Umsetzung

### 1. Reine Logik (`hfnav.js`, mit Unit-Tests)
- `navUrl(lat, lon, mode = 'driving')` hängt `&travelmode=driving` bzw. `walking` an.
  Andere Werte für `mode` werden zu `driving`. Bestehende Aufrufe bleiben gültig.
- `navTargetsAll(p)` ist für die EL und liefert `[{ key, icon, label, sub, lat, lon }]`:
  - 🎯 B-Ort;
  - jeder Lage-Ort (alle `p.pois`, Icon je Kategorie, Name über `poiName`);
  - jeder geschlossene Umriss (`kind: 'track'`, nicht `open`, mindestens 3 Punkte).
    Ziel ist die Mitte des umschließenden Rechtecks bzw. der Schwerpunkt; `sub` nennt
    das Team (über `assigneeName`).
  - jedes Raster: Mitte, Label `gridLabel`;
  - Meldungen mit Ort: Funde/Hilfe/Anzeigen. Wie sie gespeichert sind, im Code
    nachsehen (`msgDialog`, `statusText`, `drawMsgMarks`). Label wie `msgLabel`
    mit Team und Uhrzeit.
- `cellCenter(grid, label)` für Rasterfelder wie „C4“, falls es so etwas noch nicht
  gibt. Die Suche versteht „C4“ bereits; die vorhandene Funktion wiederverwenden.

### 2. Auswahlfenster `navChooser(label, lat, lon)` (app.js)
- Titel „🧭 Navigieren zu …“ mit dem Zielnamen, darunter klein die Koordinaten.
- Knöpfe „🚗 Auto“ (primary) und „🚶 Zu Fuß“ öffnen `openLink(navUrl(lat, lon, mode))`.
  Dazu „Abbrechen“.
- Kein GPS nötig: Google Maps nimmt selbst den aktuellen Standort als Start.

### 3. Einstiegspunkte
1. **Gebiete-Liste** (Knopf „Gebiete“ neben der Suche, `areaResults` in app.js): Jede
   Zeile bekommt rechts einen eigenen kleinen Knopf „🧭“ (eigenes Element, mindestens
   44 px Tippziel). Er öffnet `navChooser` für die Gebietsmitte und wählt das Gebiet
   nicht aus. Das Scrollen per Finger (v120: Auswahl erst bei pointerup ohne Wischen)
   darf dabei nicht kaputtgehen; der 🧭-Knopf braucht dieselbe Wisch-Erkennung.
2. **Suche nach Rasterfeld** (z. B. „C4“): Unter dem bestehenden Treffer kommt ein
   zweiter Eintrag „🧭 Navigieren zu C4“.
3. **Objekt-Fenster** bekommen einen Knopf „🧭 Navigieren“:
   - Meldung (`msgDialog`);
   - Lage-Ort, also das Fenster beim Antippen eines Lage-Orts (im Code suchen);
   - Umriss (`outlineDialog`, nur gespeicherte, geschlossene Umrisse);
   - B-Ort beim Antippen;
   - Text-Marker (`📍 Text`, Zeile ~1148).
4. **Zielliste „🧭 Navigation“**:
   - EL: neu im Panel „Mehr“ als Abschnitt mit Knopf „🧭 Navigation zu …“. Er öffnet
     eine Liste aus `navTargetsAll(P)`; Antippen öffnet `navChooser`.
   - HF: der bestehende `#hfm-nav` nutzt `navTargets(P)` wie bisher, Antippen öffnet
     aber jetzt `navChooser` mit Auto/zu Fuß. Der Knopf ist nicht mehr gesperrt, wenn
     es nur die Kartenmitte gibt.
   - In beiden Listen steht als letzter Eintrag „⌖ Kartenmitte (Karte vorher aufs Ziel
     schieben)“. So lässt sich jeder beliebige Punkt ansteuern.
   - Lange Listen scrollen, Fenster passt aufs Handy.

### 4. Texte
Kurz und deutsch, Stil wie bisher. Kommentare neuer Stellen beginnen mit `// v123:`.

## Tests
- **Unit (`test/nav123.test.mjs`):**
  - `navUrl` mit beiden Modi und ungültigem Modus;
  - `navTargetsAll` mit B-Ort, 2 Lage-Orten, 1 geschlossenem und 1 offenem Umriss
    (der offene kommt nicht vor), 2 Rastern und 1 Meldung mit Ort;
  - Mittelpunkte plausibel;
  - leeres Projekt ergibt `[]`.
  - Die bestehenden 343 Tests bleiben grün.
- **e2e im Scratchpad (`nav-e2e.mjs`):**
  - `window.open`/`openLink` abfangen, z. B. per `page.exposeFunction` oder
    `window.open` überschreiben, und die URL prüfen.
  - EL, Gebiete-Liste: 🧭 an einer Zeile → Auto → URL mit `travelmode=driving` und
    den richtigen Koordinaten; Liste vorher per Touch gewischt, damit nichts versehentlich
    gewählt wird.
  - Suche „C4“ → „🧭 Navigieren zu C4“ → zu Fuß → `travelmode=walking`.
  - Meldung, Lage-Ort und Umriss: jeweils der 🧭-Knopf im Fenster.
  - Mehr → Navigation zu … → Liste enthält B-Ort, Lage-Orte, Umrisse, Raster,
    Kartenmitte.
  - HF: ☰ → 🧭 Navigation → Ziel → Auto/zu Fuß.
  - Telefon (412 × 860) und Tablet (1280 × 800) mit Screenshots, ohne JS-Fehler.
  - BKG-Kacheln wie in `fallback-e2e.mjs` per Route mit PNG beantworten, sonst
    erscheint der Ersatzkarten-Hinweis.
  - Server: `cd web && python3 -m http.server 8765`; vorher mit `curl` prüfen, ob er
    schon läuft. Ausführen mit `NODE_PATH=$(npm root -g) node nav-e2e.mjs`.
  - Zusätzlich müssen `arealist-e2e.mjs`, `areas-e2e.mjs`, `bedienung-e2e.mjs`,
    `v116-e2e.mjs` und `edit-e2e.mjs` grün bleiben.

## Nicht tun (Agent)
Kein Commit, kein Push, kein `deploy.sh`, keine Versionsnummern (`APP_VERSION`,
`sw.js` `VERSION`, `ROADMAP.md`), kein `pkill -f`.
