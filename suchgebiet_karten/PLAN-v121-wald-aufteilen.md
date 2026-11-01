# PLAN v121 – 🌲 Wald erkennen und aufteilen

## Ziel (Wunsch des Nutzers)
Die EL umkreist mit dem Finger ein Waldstück. Die App erkennt die Waldflächen
im Kreis aus OpenStreetMap und teilt sie auf Wunsch in N Teilgebiete auf, z. B.
„3 gleich groß“ oder „2 gleich groß, das 3. kleiner“. Die Teilgebiete werden als
normale Umrisse (`kind: 'track'`) eingezeichnet.

Entscheidungen des Nutzers:
- **Grenzen: Wege bevorzugen.** Schnitte möglichst entlang von Waldwegen und
  Bächen aus OSM, damit die Teams klare Grenzen im Gelände haben. Die Flächen
  sind dann nur ungefähr gleich (Toleranz ±15 % je Teil gegenüber dem Soll).
  Gibt es keinen passenden Weg, wird gerade geschnitten (exakt).
- **Eingabe über ein Fenster mit Teilen**, kein Freitext.
- **„Kleiner“ hat keinen Standardwert.** Wählt man bei einem Teil „kleiner“
  (oder „größer“), muss man einen Prozentwert eingeben: „% eines normalen Teils“.
  Ohne Wert ist „Vorschau“ und „Übernehmen“ gesperrt, mit Hinweis.

## Bedienung (EL)
1. Neuer Knopf **„🌲 Wald“** in der Umriss-Leiste (`#trackbar`, neben „↶ Punkt“,
   „Fertig“, „Abbrechen“). Er ist auch im Menü „Mehr“ als „🌲 Wald umkreisen
   und aufteilen“ erreichbar.
2. Werkzeug `forestdraw`: ein Zug mit dem Finger oder der Maus um das Gebiet,
   wie das HF-Werkzeug `hfdraw` („Bereich umkreisen“, app.js um Zeile 3186).
   Die Karte bewegt sich dabei nicht. Toast: „Mit dem Finger einmal um den
   Wald herum malen“. Ist die Fläche zu klein (< 30 m Umfang), kommt ein Toast.
   Ist sie zu groß (> 25 km²), kommt ein Toast „Bitte kleiner umkreisen
   (höchstens 25 km²)“.
3. Laden mit Toast „Waldflächen werden geladen …“ (abbrechbar). Die Anfrage geht
   an Overpass (`landuse=forest`, `natural=wood`, Ways und Multipolygon-Relationen
   im umschließenden Rechteck) und holt im selben Aufruf die Wege und Gewässer
   (siehe unten).
4. Waldfläche = Schnitt aus Umkreisung und Waldpolygonen. Lichtungen (innere
   Ringe) zählen mit dazu, da Umrisse keine Löcher haben. Kleinstteile unter
   0,5 % der Gesamtfläche oder unter 2000 m² entfallen.
   - **Kein Wald im Kreis:** Rückfrage „Kein Wald erkannt – die umkreiste Fläche
     selbst aufteilen?“.
   - **Netzfehler oder Overpass überlastet:** gleiche Rückfrage mit dem Grund.
5. **Fenster „🌲 Wald aufteilen“** (Dialog wie die anderen: `openDlg`, `dlgHead`,
   `dlgButton`):
   - Kopf: „Erkannt: 12,4 ha Wald (2 Stücke)“.
   - Anzahl Teile: Knöpfe 1–8. Standard 2. Bei „1“ wird nur der Waldumriss
     übernommen.
   - Je Teil eine Zeile mit:
     - Name, Vorschlag `${outlineName(...)} A/B/C…`;
     - Größe als Auswahl „gleich groß“ / „kleiner“ / „größer“; bei kleiner oder
       größer ein Pflichtfeld „% eines normalen Teils“ (kleiner: 1–99,
       größer: 101–400);
     - Team-Auswahl, Standard „ohne Team“ (`it.to` wie bei Umrissen);
     - angezeigte Soll-Fläche in ha, live berechnet.
   - Checkbox „Grenzen an Wegen/Bächen ausrichten“, Standard an.
   - Knöpfe: „👁 Vorschau“ (zeichnet die Teile, Fenster bleibt offen bzw. kann
     eingeklappt werden), „✅ Übernehmen“, „Abbrechen“.
   - In der Vorschau trägt jedes Teil sein Ist in ha und die Abweichung zum Soll
     („A 4,1 ha (Soll 4,1)“). Teile, deren Grenze einem Weg folgt, sind mit „🛤“
     markiert.
6. Übernehmen erzeugt je Teil einen Umriss in `P.items`: `kind: 'track'`, Name,
   Farbe (Team-Farbe bzw. „ohne Team“-Regel aus v107), `w: 4`, `pts`, optional
   `to`. Die Aktion steht als ein `snapshot()` für Rückgängig, danach
   `changed()`. Besteht ein Teil aus mehreren getrennten Stücken, wird jedes
   Stück ein eigener Umriss, ab dem zweiten mit Namenszusatz „(2)“, „(3)“ und
   gleichem Team.
7. Quellenhinweis im Toast und im Fenster: „Wald und Wege: © OpenStreetMap-Mitwirkende“.

## Technik

### Neue reine Logik: `web/forest.js` (ohne DOM und ohne Leaflet, mit Unit-Tests)
- `forestQuery(bbox)`: Overpass-QL mit `[out:json][timeout:25]` für
  - Wald: `way/relation[landuse=forest]`, `way/relation[natural=wood]`;
  - Wege: `way[highway~"^(track|path|footway|bridleway|cycleway|service|unclassified|residential|tertiary|secondary)$"]`;
  - Gewässer: `way[waterway~"^(stream|river|ditch|canal)$"]`, `way[natural=water]` wird nicht gebraucht;
  - alles mit `out geom;`.
- `parseForest(json)` → `{ forests: [rings…], lines: [[[lat,lon]…]…] }`.
  Multipolygon-Relationen: die `outer`-Ways zu geschlossenen Ringen
  zusammensetzen (Enden verbinden, auch umgedreht). Offene Reste werden
  verworfen.
- Projektion: lokal äquirektangulär um die Mitte, in Metern (wie `polygonArea`
  in gpx.js), `toXY`/`toLL`.
- Polygon-Operationen über **polygon-clipping** (MIT, npm `polygon-clipping`
  0.15.x). Als ESM-Einzeldatei nach `web/lib/polygon-clipping.esm.js` legen,
  dazu `web/lib/LICENSE-polygon-clipping`. Mit `npm pack` holen, nicht in
  package.json aufnehmen. Der Service Worker muss die Datei cachen; dazu prüfen,
  wie sw.js die lib-Dateien listet.
- `forestInLasso(forests, lasso)` → MultiPolygon (in XY) ohne Kleinstteile.
- `shares(parts)`: aus den Zeilen (`gleich`, `kleiner`/`größer` mit `pct`)
  normierte Anteile berechnen, z. B. `[gleich, gleich, kleiner 50 %]` →
  `[0.4, 0.4, 0.2]`. Fehlt bei kleiner/größer der Prozentwert oder liegt er
  außerhalb des Bereichs, gibt es einen Fehler mit Text für das Fenster.
- `splitArea(mp, shares, lines, { followWays })` → `[{ polys: [ring…], area, onWay }]`:
  1. Hauptachse = längere Seite des minimalen Hüllrechtecks bzw.
     Hauptkomponente der Punkte. Teile werden von einem Ende zum anderen
     nacheinander abgeschnitten (Teil 1 zuerst usw.).
  2. Gerader Schnitt: senkrecht zur Achse, Position per Bisektion, bis die
     abgeschnittene Fläche = Soll (Toleranz 0,5 %). Abschneiden = Schnitt mit
     der Halbebene (großes Rechteck), Rest = Differenz.
  3. Bei `followWays`: Kandidaten sind Linien (Wege/Bäche), die das Restgebiet
     durchqueren, also vom Rand zum Rand. Linienenden bis 60 m vor dem Rand
     werden verlängert. Gilt nur, wenn der Winkel zur Schnittrichtung unter
     45° liegt. Der Schnitt entlang der Linie ergibt sich aus der Differenz mit
     der Linie, gepuffert auf 0,5 m (schmales Polygon). Die Stücke werden der
     Seite des Achsenanfangs bzw. -endes zugeordnet (Schwerpunkt-Projektion auf
     die Achse, Vergleich mit der Projektion des Linienmittelpunkts). Man kann
     auch zwei Wege verketten, wenn das einfacher ist; einfache Variante zuerst.
     Der Kandidat mit der kleinsten Abweichung gewinnt, wenn |Ist − Soll| ≤ 15 %
     des Solls. Sonst wird gerade geschnitten.
  4. Das letzte Teil ist der Rest.
- `toTracks(parts, names, teams)`: Ringe → `pts` in `[lat, lon]`, auf
  6 Nachkommastellen gerundet. Mit `simplify` (share.js, Toleranz 3 m)
  ausdünnen, sodass höchstens etwa 400 Punkte je Umriss bleiben.

### Overpass
`overpass()` in search.js ist privat und meldet Fehler als „Kreuzungssuche …“.
Neu: `export async function overpass(query, signal, what = 'Kreuzungssuche')`
mit dem Text als Parameter; die Kreuzungssuche bleibt unverändert.

### Vorschau auf der Karte
Eine eigene Leaflet-LayerGroup `forestPreview` mit gestrichelten Polygonen in
Vorschaufarben (eigene Palette, nicht Grau), dazu Beschriftung
`L.tooltip(permanent)` mit „A 4,1 ha“. Sie wird bei „Abbrechen“ und
„Übernehmen“ entfernt. Kein Speichern während der Vorschau.

### HF
Nicht betroffen. Das Werkzeug gibt es nur im EL-Modus.

## Tests
- **Unit (`test/forest.test.mjs`), mindestens:**
  - `parseForest`: Way-Wald, Multipolygon aus 2 gestückelten outer-Ways
    (eines umgedreht), Linien.
  - `forestInLasso`: Quadrat-Wald 1 × 1 km, Lasso über die halbe Fläche →
    ca. 50 ha. Kein Schnitt → leer. Kleinstteil entfällt.
  - `shares`: gleich/gleich/kleiner 50 → 0.4/0.4/0.2; fehlender Prozentwert →
    Fehler; größer 150.
  - `splitArea` ohne Wege: Rechteck 3 × 1 km, 3 gleich → je ±1 %. 2 gleich und
    1 kleiner 50 % → 40/40/20 ±1 %.
  - `splitArea` mit Weg: Rechteck 2 × 1 km, ein Weg quer bei x = 1,1 km
    (leicht schräg), 2 gleich → Schnitt folgt dem Weg (`onWay`), Flächen
    ±15 %. Weg bei x = 1,6 km (außerhalb der Toleranz) → gerader Schnitt.
  - Bestehende 325 Tests bleiben grün.
- **e2e (Scratchpad `wald-e2e.mjs`):**
  - Overpass per `page.route('**/api/interpreter', …)` mit fester JSON-Antwort
    abfangen: ein Waldpolygon und ein Waldweg quer.
  - Ablauf: EL → Umriss-Leiste → „🌲 Wald“ → Kreis per Maus-Zug, und auf dem
    Telefon per Touch über CDP wie in `arealist-e2e.mjs` → Fenster mit
    „Erkannt: … ha“ → 3 Teile, das 3. kleiner. Ohne Prozentwert ist
    Übernehmen gesperrt; mit 50 → Vorschau → Übernehmen → 3 neue Umrisse mit
    den Namen, Flächen im Verhältnis ±15 %, ein Schritt Rückgängig entfernt alle.
  - Fall ohne Wald (leere Antwort) → Rückfrage → umkreiste Fläche wird aufgeteilt.
  - Overpass-Fehler 429 → Rückfrage mit Grund.
  - Telefon (412 × 860) und Tablet (1280 × 800), Screenshots
    `wald-{phone,tablet}-{fenster,vorschau,fertig}.png`, keine JS-Fehler.
  - Ausführen: `cd web && python3 -m http.server 8765` (prüfen, ob er schon
    läuft), dann `NODE_PATH=$(npm root -g) node wald-e2e.mjs`.

## Nicht tun (Agent)
Kein Commit, kein Deploy (`deploy.sh`), keine Versionsnummern ändern
(`APP_VERSION`, sw.js `VERSION`, ROADMAP), nichts pushen, kein `pkill -f`. Das
macht der Hauptprozess nach dem Review.
