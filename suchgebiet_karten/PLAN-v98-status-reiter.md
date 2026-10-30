# Plan v98: 📣 Status-Reiter · Status-Leiste oben (Tablet) · Suchfeld einklappbar

Wünsche von Klaas (30.10.2026), nur Einsatzleitung (EL):

## 1. Eigener Reiter „📣 Status“
- Neue Kachel in der rechten Randleiste (EL-Modus) **„📣 Status“** mit eigenem Panel `panel-status`
  (wie die anderen Panels über `SIDE_PANELS`/`openPanel`, zweiter Tipp schließt).
- Inhalt: alle Status-Meldungen des Einsatzes (`allMsgs()`, also Status-Server + QR, ohne gelöschte),
  **neueste oben**, je Zeile: Teamfarbe, Team, Meldung (`msgLabel`), Uhrzeit (hh:mm, „vor x min“), Text,
  📍 wenn mit Standort. Dringende (Fund/Hilfe) rot hervorgehoben.
- Zeile antippen: mit Standort → Karte springt hin (`showStatusMark`) und Panel schließt; Löschen über den
  vorhandenen `msgDialog` (Warnung) per kleinem 🗑-Knopf in der Zeile.
- Filter oben: „Alle Teams“ / einzelnes Team (Select). Leer: „Noch keine Status-Meldungen“.
- Aktualisiert sich bei neuen Meldungen (pollLive, QR-Rückmeldung, Löschen), wenn offen.
- Kachel zeigt ein Zähler-Badge mit ungelesenen Meldungen seit dem letzten Öffnen (`P.live.seen` bzw.
  `P.msgSeen` = Zeit des letzten Öffnens; normalisieren in store.js).

## 2. Status-Leiste oben neben dem Suchfeld (Tablet/breite Bildschirme)
- Oben in der roten Kopfzeile rechts neben dem Suchfeld (`#search-form`) eine Leiste `#status-strip` mit den
  **letzten 3 Meldungen** als kompakte Chips: „<Teamfarbe-Punkt> Team · Meldung · 14:32“. Antippen wie im Reiter.
- Nur im EL-Modus und nur, wenn es Meldungen gibt; nur bei Breite ≥ 700 px (Tablet/Querformat).
  Auf schmalen Handys ausgeblendet (dort gibt es den Reiter).
- **Suchfeld kleiner und einklappbar**: auf breiten Bildschirmen ist das Suchfeld standardmäßig
  eingeklappt zu einem 🔍-Knopf; Antippen klappt es auf (Fokus ins Feld), nach dem Suchen bzw. Verlassen
  (blur ohne Text, Ergebnisliste geschlossen, ✕) klappt es wieder zu. Eingeklappt bekommt die Status-Leiste
  den Platz und zeigt **so viele Meldungen, wie hineinpassen** (mindestens 3, dynamisch nach Breite, z. B.
  per Messen der Chips oder feste Chipbreite). Aufgeklappt: Suchfeld schmaler als heute, Leiste zeigt 3.
- Auf schmalen Handys bleibt das Suchfeld wie bisher (immer sichtbar).
- Auch im HF-Modus bleibt alles wie bisher.

## Tests
- Unit (reine Logik in `web/status.js`): `recentMsgs(list, n, teamFilter)` (neueste zuerst, Filter, ohne gelöschte),
  `unreadCount(list, seen)`.
- Playwright `statusbar-e2e.mjs` im Scratchpad: Viewport 1280×800 (Tablet): EL mit Meldungen (P.qmsgs/P.live.msgs
  setzen) → Leiste zeigt ≥ 3 Chips, Suchfeld eingeklappt; 🔍 aufklappen → Suchfeld sichtbar, Leiste 3 Chips;
  Reiter „📣 Status“ öffnet Liste neueste oben, Filter nach Team, Zeile antippen springt; 🗑 löscht mit Warnung.
  Viewport 412×860 (Handy): Leiste aus, Suchfeld wie bisher. Screenshots ansehen.
- Alle bisherigen Tests grün: `node --test test/*.mjs` (187) und im Scratchpad status-e2e, accept-e2e, progress-e2e,
  badge-e2e, area-badge-e2e, multi-e2e, send-e2e, time-e2e (Versions-Checks auf v98 anpassen).
