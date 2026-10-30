# Plan v95: 📲 Auftrag erst bei Übernahme protokollieren · 🔒 Schutz übernommener Aufträge · 🗑 Standort-Meldungen löschen

Wünsche von Klaas (30.10.2026):
1. Ein Auftrag gilt erst als vergeben („protokolliert“), wenn das Team ihn **übernommen** hat – nicht schon,
   wenn der QR-Code/Link erstellt wird.
2. Nach der Übernahme darf das Gebiet des Auftrags (Felder, Umrisse/Zeichnungen/Texte des Auftrags)
   nur noch nach einer **bestätigten Warnung** verändert oder gelöscht werden.
3. Status-/Standort-Meldungen (über Google Sheets oder QR) auf der EL-Karte kann die EL **löschen**,
   ebenfalls nur nach bestätigter Warnung.

## 1. Übernahme

- `prepareSend` (`web/app.js`) legt den Eintrag in `P.sent` weiter an (die ID wird für Zuordnung gebraucht),
  aber mit `acc: 0` (= noch nicht übernommen). Zusätzlich merken: `items: [Item-IDs]` (ausgewählte
  Zeichnungen/Umrisse/Texte; Items haben seit v90 eine `id`) und `cells: { gridId: ["c,r", …] }`
  (die mitgeschickten Team-Felder `a.g[].f`).
- **Übernahme-Quittung**: `takeAssignment` (HF) sendet bei neuem Auftrag automatisch eine Status-Meldung
  `s: 'ok'` („📲 Auftrag übernommen“, ohne GPS-Warten: `pos: null`) – über den Status-Server, sonst in `hf.log`
  (geht mit der QR-Rückmeldung mit). In `web/status.js`: Label/Icon für `ok`, aber **keine** Taste in `STATUS_LIST`.
- Die EL setzt `x.acc = Zeit` beim ersten Eingang von: irgendeiner Status-Meldung zu `x.id` (Server oder QR)
  oder einer QR-Rückmeldung (`handleShared`). Zusätzlich auf der Auftragskarte ein Knopf
  **„✓ Team hat übernommen“** (manuell, z. B. wenn das Team ohne Netz losgeht) und **„✕ Verwerfen“**
  (nicht übernommene Aufträge ohne Rückfrage entfernen).
- Auftrags-Übersicht (`renderSentList`): nicht übernommene Aufträge abgesetzt („⏳ QR erstellt 11:55 –
  noch nicht übernommen“, grau), übernommene wie bisher, „seit“ und „nachfragen?“ ab `acc`.
  Status-Plakette auf der Karte: nicht übernommen → „📲 wartet auf Übernahme“ (gestrichelter Rand).
- Fortschritt/Übergabe (`progress.js` `se`) überträgt `acc`, `items`, `cells` mit (Merge: `acc` = früheste > 0).

## 2. Schutz übernommener Aufträge

- Neue reine Logik in `web/locks.js` (mit Tests): `assignedOf(p, el)` → übernommener Auftrag (`P.sent` mit `acc`),
  zu dem ein Item gehört (`x.items` enthält `el.id`); `assignedCell(p, gridId, key)` → Auftrag, dessen
  `cells[gridId]` den Schlüssel enthält. Gilt nur in der Einsatzleitung (nicht HF).
- In allen Bearbeitungs-/Löschwegen, die schon die UA-Sperren prüfen (Radierer, Feld lange drücken, Feld-Werkzeug,
  Item antippen/umbenennen/löschen, „Alle Zeichnungen löschen“, „Alle Feldfarben löschen“, Raster entfernen,
  Gebiet ändern): vorher `guardAssigned(...)`. Ist das Element geschützt und nicht freigegeben, Aktion
  **abbrechen** und Dialog zeigen: „🔒 Gehört zum übernommenen Auftrag <Team> (seit 12:03). Wirklich ändern?“
  → „Ändern freigeben“ setzt `x.unlock = jetzt + 5 min` (dann geht die Aktion beim nächsten Versuch durch,
  Hinweis „Freigegeben für 5 Minuten – bitte nochmal ausführen“) / „Abbrechen“.
  Massen-Aktionen („Alle … löschen“) lassen geschützte Elemente stehen und sagen das (oder einmal fragen).
- Auftrag in der Übersicht löschen/verwerfen nach Übernahme: ebenfalls nur nach Warnung.

## 3. Status-/Standort-Meldungen löschen (EL)

- Antippen eines Meldungs-Symbols (EL) öffnet statt Toast einen kleinen Dialog: Text wie bisher
  (`statusText`), Knöpfe „🗑 Löschen“ und „Schließen“. Löschen → Warnung „Meldung von <Team> (14:32)
  wirklich löschen? Sie wird auf diesem Gerät nicht mehr angezeigt.“ → bestätigen.
- Gelöschte Meldungs-IDs in `P.msgDel` (Objekt id → Zeit; in `store.js` normalisieren), `allMsgs()` filtert sie
  heraus, damit sie weder beim nächsten Abholen noch über QR/Fortschritt wiederkommen. Fortschritt (`#f`)
  überträgt Löschvermerke ergänzend mit, damit ELW/UA sie auch ausblenden.
- Löschen nur in der Google-Tabelle ist nicht nötig (dort verschlüsselt, löscht sich nach 7 Tagen).

## 4. HF-Menü schließen (Fehler)

- Im Hundeführer-Modus öffnet „☰ Menü“ (`btn-hfmenu`) das Menü, ein zweiter Tipp auf denselben Knopf schließt es
  nicht. Ändern: erneuter Tipp schließt das Menü (wie die anderen Kacheln der Randleiste). Prüfen, dass das
  Klick-außerhalb-Schließen (`closePanels`) den Knopf nicht vorher schließt und dann wieder öffnet.

## Tests
- Unit: Guard-Logik (Item/Feld im übernommenen Auftrag, nicht übernommen = frei, Freigabe läuft ab),
  `acc`-Merge in progress, `msgDel` filtert, Quittung `ok` erzeugt.
- Playwright: Auftrag senden → Karte „noch nicht übernommen“; HF öffnet Link → Quittung (gemockter Server) →
  EL „übernommen seit …“; Feld des Teams einfärben → Warnung → abbrechen bleibt unverändert, freigeben →
  Änderung geht; Meldung antippen → löschen mit Warnung → weg und kommt beim nächsten Abholen nicht wieder; HF-Menü auf/zu per Doppeltipp.
- Alle bisherigen Tests (`node --test test/*.mjs`, 174) grün; `status-e2e.mjs`, `progress-e2e.mjs`,
  `badge-e2e.mjs`, `multi-e2e.mjs`, `send-e2e.mjs` im Scratchpad weiter grün (Versions-Checks dort ggf. anpassen).
