# Plan v103 (Teil 2): ✏️ Eigene Meldungen und Markierungen ändern, verlegen, löschen

Mit Klaas abgestimmt (30.10.2026): „Alles soll mindestens durch die Person geändert oder gelöscht werden können.“
Kommt mit in v103 (Selbst-Update, Tippen schließt, Texte ändern/löschen, Plaketten am Gebiet sind schon im Branch).

## 1. Korrektur-Meldung (status.js, rein und getestet)
- Neue Meldungsart `s: 'kor'` mit `ref` (ID der geänderten Meldung). Felder:
  - `del: 1` → Meldung gelöscht
  - `lat`/`lon` (neuer Ort) oder `nopos: 1` (Standort entfernt)
  - `txt` (neue Notiz, `''` = Notiz entfernt → als `txt: ''` speichern, `buildMsg` dafür erweitern: `txt` nur weglassen,
    wenn `undefined`)
- `buildKor({ a, tm, ref, del, pos, nopos, txt })` → Meldung (eigene ID, Zeit).
- `applyKor(list)` → Liste ohne `kor`-Meldungen; jede Ziel-Meldung bekommt die Änderungen aller ihrer `kor` (nach Zeit)
  und `ed: Zeit der letzten Änderung`; gelöschte fallen weg. Für **Fund/Hilfe (isUrgent)** nicht still entfernen:
  sie bleiben als `{ ...m, gone: Zeit }` in der Liste (siehe EL), alle anderen gelöschten verschwinden ganz.
- `msgLabel`/`NO_POS` usw. unverändert; `kor` darf nirgends als eigene Meldung erscheinen (Chips, Verlauf,
  Ungelesen, „letzte Meldung“ `latestFor`, Dringend-Alarm) – deshalb überall `applyKor` vor der Nutzung.

## 2. Hundeführer
- Eigene Meldung auf der Karte antippen (heute nur Toast in `map.on('click')`, HF-Zweig) → Fenster
  „{Icon} {Label} hh:mm“ mit:
  - Notiz-Feld (vorbelegt, `defaultValue` setzen) + **💾 Speichern**
  - **📍 Verlegen** → `setTool('hfmovept')`, Toast „Neuen Ort auf der Karte antippen“, beim Tipp Korrektur mit neuem Ort
  - **📍 Standort entfernen** (nur wenn Ort da) – Meldung bleibt ohne Ort
  - **🗑 Löschen** → Rückfrage „🗑 Meldung löschen?“ (bei Fund/Hilfe Text: „Die Einsatzleitung sieht, dass die Meldung
    zurückgezogen wurde.“)
  - **Abbrechen**
- Im 📣-Status-Fenster neuer Knopf **„🗂 Meine Meldungen (n)“** → Liste aller eigenen Meldungen (neueste oben, mit
  `applyKor`), je Zeile antippen = dasselbe Fenster (Verlegen nur, wenn Karte erreichbar; Fenster schließt dafür).
- Senden: Korrektur wie jede Meldung (`h.log` + bei `h.ls` in `h.outbox`, `flushStatus`), ohne Standortabfrage. Die
  QR-Rückmeldung (share.js `sm = h.log.slice(-20)`) nimmt `kor` mit; dafür das Limit so anpassen, dass `kor`-Meldungen
  zu enthaltenen Meldungen nicht abgeschnitten werden (z. B. die letzten 20 Nicht-kor + deren kor).
- Anzeige beim HF (`statusMarks`, Liste, „letzter Stand“ in `pctRows`) immer über `applyKor(h.log)`.
- **Eigene Markierungen/Bereiche** (Items ohne `fromEl`/`prev`): Text-Fenster (`textDialog` in app.js, gibt es schon)
  bekommt **📍 Verlegen** (für EL und HF, `setTool('textmove')`, nächster Tipp setzt `lat/lon`, `snapshot()`/
  `changed()`); HF: eigenen Bereich (Track, `hfAreaDone`) antippen → Name/Notiz ändern + 🗑 Löschen (wie
  `outlineDialog`/Radierer, mit Rückfrage). 🔒-Regeln (`blocked`, `guardAssigned`, `isPrev`) bleiben.

## 3. Einsatzleitung
- `allMsgs()` = `applyKor` auf die gemischte Liste (vor `withoutDeleted`), ebenso überall, wo `P.live.msgs`/`P.qmsgs`
  direkt gelesen werden (Ungelesen/Dringend-Prüfung um Zeile 4300–4370, Team-Chips, Verlauf, Plaketten-Stand).
- Geänderte Meldung: im Verlauf/Infofenster/`msgDialog` „✏️ geändert hh:mm“; Kartenpunkt am neuen Ort.
- Gelöschte Fund/Hilfe (`gone`): nicht auf der Karte, im Verlauf durchgestrichen „↩ vom Team zurückgezogen hh:mm“;
  ein noch offener Dringend-Alarm dazu wird beendet. Neue Korrektur → Toast „{Team}: Meldung geändert/zurückgezogen“.
- Korrekturen lösen keinen Dringend-Alarm aus und zählen nicht als ungelesene neue Meldung.

## Tests
- Unit (test/status.test.mjs o. neu): buildKor, applyKor (Notiz, Verlegen, Ort entfernen, Löschen normal vs. Fund →
  `gone`, mehrere kor in Zeitfolge, kor ohne Ziel ignoriert, kor erscheint nie selbst), `txt: ''` entfernt Notiz,
  QR-Auswahl behält kor.
- Playwright im Scratchpad `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/edit-e2e.mjs`
  (Vorlage: `status-e2e.mjs`, `park-e2e.mjs` dort; Server `python3 -m http.server 8765` in `web/`),
  1280×800 und 412×860 mit Touch, Screenshots: HF meldet Anzeige mit Notiz → Antippen → Notiz ändern → verlegen →
  Ort entfernen → löschen; „Meine Meldungen“; EL sieht Änderungen (über QR-Rückmeldung bzw. Status-Server-Mock wie in
  status-e2e); Fund löschen → EL durchgestrichen, Alarm aus; Text verlegen; HF-Bereich umbenennen/löschen.
  **Achtung:** Fenster, die bei pointerup aufgehen, schlucken den direkt folgenden Geisterklick (app.js `dlgOpenedAt`);
  im Test nach dem Öffnen per Touch ≥ 250 ms warten.
- Bestehende Tests grün: `node --test test/*.mjs` und die e2e-Skripte status, statusbar, park, close, accept, text,
  tapclose, update im Scratchpad.
