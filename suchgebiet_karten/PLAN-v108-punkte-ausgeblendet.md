# Plan v108: Umriss-Punkte bearbeiten und Ausgeblendetes nicht veränderbar

Mit Klaas abgestimmt am 30.10.2026. Er wünscht Verschieben, Einfügen und Löschen von Punkten. Bei Ausgeblendetem soll
ein Tipp gar nichts tun.

## 1. ✋ Punkte eines Umrisses bearbeiten
- **Einstieg:** `outlineDialog` (app.js ~1059) bekommt einen neuen Knopf „✋ Punkte bearbeiten“. Das Fenster öffnet
  sich beim Antippen eines Umrisses bzw. über `renameItem`. Der Knopf gilt für Items mit `kind: 'track'` und `pts`
  (geschlossene Umrisse und offene Linien).
- **Sperren:** Vorher die üblichen Sperren prüfen, nämlich `isLocked`/`blocked(it, 'edit')`/`guardAssigned(assignedOf(P, it))`
  und `prev`/`fromEl`, genau so, wie das Fenster heute für Ändern prüft.
- **Ablauf:**
  - Das Fenster schließt sich, `snapshot()` wird einmal aufgerufen.
  - Auf jeden Eckpunkt kommt ein Leaflet-Marker mit `draggable: true`, Icon `L.divIcon({className: 'vtx-h', iconSize:[24,24]})`.
    Vorbild ist der Raster-Anpasser v106 in app.js (`startGridFit`, `.gfit-h`, CSS in style.css).
  - Auf der Mitte jeder Kante sitzt ein kleiner halbtransparenter Anfasser `vtx-mid` mit 16 px.
    - Offene Linien: kein Anfasser auf der Kante vom letzten zum ersten Punkt.
    - Geschlossene Umrisse: Die Kante vom letzten zum ersten Punkt hat einen Anfasser, außer der Umriss speichert den
      ersten Punkt am Ende doppelt. Prüfen, wie `pts` bei geschlossenen Umrissen gespeichert wird; falls doppelt,
      beide Punkte gemeinsam bewegen.
- **Eckpunkt ziehen:** Bei `drag` wird `it.pts[i]` live gesetzt und `redraw()` aufgerufen. Bei `dragend` wird
  `changed()` aufgerufen; danach werden die Mitten-Anfasser neu gesetzt.
- **Kanten-Anfasser ziehen:** Bei `dragstart` wird an dieser Stelle ein neuer Punkt eingefügt und während des Ziehens
  mitbewegt. Bei `dragend` werden alle Anfasser neu aufgebaut.
- **Eckpunkt antippen ohne Ziehen** (Leaflet `click` am Marker): Es kommt die Rückfrage „🗑 Punkt löschen?“ mit
  `openDlg`, Knöpfe „🗑 Löschen“ und „Abbrechen“.
  - Geschlossener Umriss: mindestens 3 Punkte bleiben, offene Linie: mindestens 2. Sonst nur der Toast
    „Mindestens 3 Punkte“ bzw. „… 2 Punkte“.
  - Für das Löschen vorher `snapshot()` aufrufen. Das ist erlaubt, damit Rückgängig schrittweise geht; jede Aktion
    bekommt ein eigenes `snapshot()`. Statt des einmaligen Aufrufs beim Start also besser `snapshot()` bei jedem
    `dragstart` und vor jedem Löschen.
- **Leiste** `#vtxbar` (class `trackbar`, in index.html neben `#gridfitbar`): Text „✋ Punkte ziehen · Mitte ziehen =
  neuer Punkt · Punkt antippen = löschen“ und Knopf `#vtx-done` „Fertig“.
- **Ende:** Fertig, Werkzeugwechsel (`setTool`), `switchProject`, Löschen des Items oder ein Undo, das das Item
  entfernt, beenden den Modus. Dabei Marker entfernen und die Leiste ausblenden. Nach Undo/Redo die Anfasser neu
  setzen, wenn das Item noch existiert. Das Item über die ID finden, falls Undo die Objekte ersetzt. Prüfen, wie
  `snapshot`/undo arbeiten.
- **Tap-Schließen:** In `tapIsEmpty` (app.js ~6340, dort steht `.gfit-h`) auch `.vtx-h, .vtx-mid` ausnehmen.
- **Fläche:** Fläche bzw. ha werden aus `pts` berechnet und passen sich daher automatisch an.
- **Sync:** Für Sync/Teilen ist nichts extra nötig, weil `changed()` das erledigt.
- **HF:** Hundeführer können in ihrem eigenen Bereich (`hfAreaEdit`) denselben Knopf benutzen, soweit sich das
  einfach einbauen lässt. Die Sperren bleiben gleich.

## 2. Ausgeblendetes nicht veränderbar (Tipp tut gar nichts, keine Meldung)
- **Raster ausgeblendet** (`P.hide.grid`, Schalter „Raster“ `#quick-grid` bzw. Ebenen „Rasterlinien und Feldnamen“):
  - Das Feld-Werkzeug (`fillAt` ~641) tut nichts.
  - Das Feld-Fenster per Tipp/Langdruck (`fieldDialog` ~1675 und seine Aufrufer) öffnet sich nicht.
  - Der Radierer auf Feldern (`eraseAt`, Zweig `hitGrid`) tut nichts.
  - `useGridAt` per Tipp wechselt nicht das aktive Raster, falls es dadurch etwas verändern würde.
  - Raster aufziehen (Werkzeug `grid`) bleibt erlaubt. Ebenso bleiben Aufträge über Dialoge/Listen erlaubt, sie sind
    kein Tipp auf die Karte.
- **Feldfarben ausgeblendet:** Schalter „Felder“ `#quick-marks` setzt `m.hidden` an den Teams/Markierungen.
  - Ist ein Feld nur über ausgeblendete Markierungen belegt, also Team in `fills[key]` und/oder Status in
    `status[key]` mit `m.hidden`, dann ändern Radierer und Feld-Werkzeug dieses Feld nicht.
  - Das Feld-Werkzeug mit einer ausgeblendeten aktiven Markierung (`activeMark().hidden`) tut gar nichts.
  - Wird ein Feld mit der sichtbaren Markierung bemalt, wird nur diese Ebene geändert. Team und Status liegen getrennt
    (`mapFor`), eine versteckte Ebene darf nicht überschrieben oder gelöscht werden.
  - Das Feld-Fenster darf sich öffnen, wenn das Raster sichtbar ist. Es zeigt aber nur sichtbare Markierungen als
    aktiv und ändert versteckte nicht.
- Die Logik möglichst rein und testbar halten, z. B. `cellEditable({ hideGrid, fillMark, statusMark })` in einem Modul.
  Dazu Unit-Tests.

## Tests
- Unit-Tests für die Hilfslogik (Punkt löschen mit Mindestzahl, Punkt einfügen an Kante, `cellEditable`).
- Playwright `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/vertex-e2e.mjs`
  (Vorlage `gridfit-e2e.mjs`), jeweils 1280×800 und 412×860 mit Touch:
  1. Umriss zeichnen (`setTool('track')`, Punkte tippen, fertig).
  2. Antippen → „✋ Punkte bearbeiten“, einen Punkt ziehen und die Koordinaten prüfen.
  3. Kante ziehen, dann ist ein Punkt mehr da.
  4. Einen Punkt antippen und löschen, dann ist ein Punkt weniger da.
  5. Mindestzahl prüfen.
  6. Fertig, dann sind die Anfasser weg.
  7. Undo stellt den alten Zustand wieder her.
  8. Screenshots machen.
- Playwright `hidden-e2e.mjs`:
  1. Raster plus bemalte Felder anlegen.
  2. Raster ausblenden, dann mit Feld-Werkzeug, Radierer und Pan-Tipp auf ein Feld tippen: keine Änderung, kein
     Fenster.
  3. Felder ausblenden (`#quick-marks`), dann Feld-Werkzeug und Radierer: keine Änderung.
  4. Wieder einblenden, dann funktioniert alles normal.
- Bestehende Tests bleiben grün: `node --test test/*.mjs` und die Scratchpad-e2e-Skripte gridfit, noteam (falls
  vorhanden), text, tapclose, close, accept, progress, labels, orders, status und park.
- **Nicht** deployen, committen oder die Version erhöhen.
