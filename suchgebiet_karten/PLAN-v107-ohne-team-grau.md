# Plan v107: Feste Farbe Grau für „ohne Team“ (Umrisse und Felder)

Mit Klaas abgestimmt (30.10.2026). Er hat sich für Grau entschieden und will „ohne Team“ zusätzlich in der Feld-Leiste.

## Farbe
- Neue Konstante `NO_TEAM_COLOR = '#616161'` (Dunkelgrau) in store.js, exportiert.
- Grau wird aus `MARK_COLORS` (app.js:72) entfernt. Neue Teams und Markierungen können Grau also nicht mehr bekommen, auch
  nicht über die Farbauswahl (app.js ~1287, ~1708).
- Alte Projekte, in denen ein Team schon Grau hat: Beim Laden (Migration in store.js, falls vorhanden; sonst beim
  Öffnen eines Projekts) bekommt dieses Team die erste freie Teamfarbe. Dazu gibt es einen Unit-Test.

## Umrisse (kind 'track', geschlossen, also ohne `open`)
- Ohne `it.to` werden sie **immer grau** gezeichnet: render.js `drawTrack` nimmt `NO_TEAM_COLOR` statt `it.color`,
  wenn `!it.to && !it.open`. Dazu kommt ein **gestrichelter Rand** (`setLineDash([10*s, 6*s])`), damit „noch offen“
  auch ohne Farbsehen erkennbar ist. Label und Notiz bekommen dieselbe Farbe.
- Mit Team bleibt alles wie bisher (Teamfarbe, durchgezogen). In `applyOutline` (app.js ~1085): Wird das Team
  entfernt, wird nichts umgefärbt; das Zeichnen nimmt dann automatisch Grau.
- Offene Linien (Stift, `open`) bleiben in ihrer Stiftfarbe, das sind Wege und keine Gebiete.
- Die Ebenen-Liste und die Legende (app.js ~1528, `row(..., it.color)`) zeigen Grau, wenn ein geschlossener Umriss ohne
  Team ist. Dafür gibt es einen gemeinsamen Helfer `outlineColor(it)` in render.js, der exportiert und überall benutzt
  wird.
- Der HF-Bereich (`hfAreaDone`) bleibt unverändert, denn er hat ein Team bzw. stammt vom HF. Nur EL-Umrisse ohne `to`
  werden grau. Hinweis: Items mit `fromEl`/`prev` nicht anfassen.

## Felder „ohne Team“
- Reservierte ID `NO_TEAM = '-'` (store.js, exportiert) als Wert in `P.fills[key]`. Das Feld gehört dann zum Suchgebiet,
  ist aber noch keinem Team zugeteilt.
- In der Feld-Leiste (`renderPalette`, app.js ~1215) steht als erster Eintrag der Knopf **„⬜ ohne Team“** mit grauem
  Punkt. Er setzt `db.activeMark = NO_TEAM`. `activeMark()` liefert dafür ein Pseudo-Mark
  `{ id: NO_TEAM, kind: 'team', label: 'ohne Team', color: NO_TEAM_COLOR }`, das nicht in `P.marks` steht.
  `fillAt`/`mapFor` funktionieren damit unverändert (Team-Map = `fills`). Bitte prüfen, ob `mapFor(P, m)` über
  `m.kind` entscheidet.
- Beim Zeichnen (render.js, Team-Flächen) bekommt `fills[key] === NO_TEAM` Grau und einen gestrichelten Innenrand. In
  der Feldmitte steht kein Teamname.
- **Überall, wo `fills` als Teamzuteilung ausgewertet wird, muss `NO_TEAM` als „kein Team“ gelten:** Team-Zähler
  (app.js ~3505, ~3523, ~4160), Aufträge senden/Plaketten (`assignTargets`, `sentBadges`), Team-Chips im
  Feld-Fenster (app.js ~1745: der Chip „ohne Team“ ist aktiv bei `!fills[key] || fills[key] === NO_TEAM`; ein Tipp
  darauf setzt `NO_TEAM`, ein zweiter Tipp löscht), `assigneeName`, `assignedCell`/`guardAssigned` (ein graues Feld
  ist NICHT zugeteilt, also keine Sperre), Export/PDF-Legende (Eintrag „ohne Team“ in Grau, wenn ein Feld oder ein
  Umriss ohne Team vorkommt), QR/Share (`fills` mit `'-'` muss durchgehen; prüfen, ob share.js die Team-IDs
  validiert), die Feld-Liste und die Fortschrittsanzeige. Mit `grep -n "fills" web/*.js` alles durchgehen.
- Teamzuteilung per Auftragsdialog (app.js ~3050ff., „ohne Team (nur Gebiet)“) bleibt, wie sie ist.

## Tests
- Unit-Tests: Farbmigration, `outlineColor`, `NO_TEAM` gilt nicht als zugeteilt (`assignedCell`/Zähler, je nachdem,
  was rein in store.js oder anderen Modulen liegt).
- Playwright im Scratchpad `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/noteam-e2e.mjs`
  (Vorlage `gridfit-e2e.mjs`; Server `python3 -m http.server 8765` in `web/`, `NODE_PATH=$(npm root -g) node …`),
  jeweils für 1280×800 und 412×860 mit Touch. Ablauf:
  1. Raster anlegen.
  2. „ohne Team“ wählen und Felder malen, das ergibt grau.
  3. Ein Team anlegen und ein Feld umfärben, das ergibt die Teamfarbe.
  4. Einen Umriss zeichnen: ohne Team grau und gestrichelt; Team zuteilen ergibt die Teamfarbe; Team entfernen ergibt
     wieder Grau.
  5. Prüfen, dass ein neues Team nie Grau bekommt.
  6. Pixel-Farbe auf dem Canvas prüfen.
  7. Screenshots machen.
- Bestehende Tests bleiben grün: `node --test test/*.mjs` und die e2e-Skripte gridfit, text, tapclose, close, accept,
  progress, labels, orders, status und park.
- **Nicht** deployen, committen oder die Version erhöhen. Das mache ich selbst.
