# Plan v90: 🔒 Unterabschnitt-Sperren · 🔄 Fortschritt senden · 📤 Rückmeldung über Google Sheets

Baut auf v89 (Status-Meldungen, `web/status.js`, Apps-Script, `P.live`) auf.

## A. Sperr-Regeln im Unterabschnitt (UA)

- Beim Erstellen des UA (`subsetProject(..., { base: true })`) geht der **ganze Grund-Einsatz** mit:
  Elemente außerhalb der Auswahl werden als `lock: 'base'` markiert (Items, Raster, Lage-Orte, B-Ort).
  Ausgewählte Elemente des UA: `lock: 'ua'`.
- `lock: 'base'`: ausgegraut dargestellt, nicht auswählbar zum Bearbeiten; Antippen →
  „🔒 Gehört zum Grund-Einsatz – nur ansehen“. Felder dieser Raster nicht einfärbbar.
- `lock: 'ua'`: bearbeitbar (Form, Name, Farbe, Felder, Status), **nicht löschbar** →
  „🔒 Nur der Grund-Einsatz kann das löschen“. Gilt für Löschen-Knopf, Radierer, „Alles löschen“.
- Neu im UA angelegte Elemente: kein `lock`, frei.
- Zentrale Prüfung `canEdit(p, el)` / `canDelete(p, el)` in neuem `web/locks.js` (mit Tests);
  alle Lösch-/Bearbeitungswege in `app.js` darüber leiten. Im Grund-Einsatz selbst keine Sperren.

## B. 🔄 Fortschritt senden (`#f=`, Logik in `web/progress.js`, mit Tests)

- Inhalt: Feld-Status und Team-Zuteilungen, neue/geänderte Items (mit `id`, `t`, `by`),
  Lage-Orte (wie `infos.js`), Wind-Messungen, Protokolleinträge, `P.sent`-Übersicht,
  importierte HF-Rückmeldungen (Wege/Markierungen mit `resultKey`, Team, Zeit), Status-Meldungen.
- Zusammenführen nur ergänzend (gleiche Regeln wie `mergeInfos`): Neues kommt dazu; Geändertes nur,
  wenn Absender es zuletzt bearbeitet hat (`by === from`) und neuer; nichts wird gelöscht;
  Löschvermerke des Empfängers blockieren Wiederanlegen. Feldkonflikt: neuere Änderung gewinnt,
  im UA-Gebiet entscheidet der UA.
- Richtung: UA → EL nur UA-Gebiet + Neues des UA + Rückmeldungen seiner Teams.
  EL → UA alles, beim UA mit `lock: 'base'` (außer UA-eigene Elemente).
  EL ↔ EL/ELW alles, beidseitig ergänzend.
- Zuordnung über `eid`/`parentEid` (wie `infoTarget`).
- Wege: per QR (mehrteilig `#m` wie Übergabe) und per Google Sheets (automatisch alle 2 min,
  wenn `P.live` und online; nur Änderungen seit letztem Senden, `P.live.progSent`).
- Meldung: „🔄 Fortschritt von <Gerät>: 12 Felder, 2 Wege, 3 Protokolleinträge“.
- Knopf in „📤 Weitergeben“ neben „Infos senden“; Gerätename wie bei Infos.

## C. 📤 HF-Rückmeldung über Google Sheets

- Mit `P.hf.ls`: „📤 Rückmeldung senden“ schickt `buildResult` verschlüsselt über die Tabelle
  (Outbox wie v89, ohne Netz später). QR bleibt als Option im selben Dialog.
- Große Inhalte in Teile ≤ 15 000 Zeichen zerlegen (`part`, `of`, gemeinsame `gid`);
  EL setzt zusammen und wendet `applyResult` an. Doppelte (QR + Sheets) werden über
  `p.imported`/Meldungs-ID erkannt.
- Apps-Script unverändert nutzbar (gleiches Format `{ r, id, d }`).

## Tests

Unit: locks, progress-merge (Richtungen, keine Löschung, Konflikte, Idempotenz), Teilung/Zusammensetzen.
Playwright: UA mit gesperrten Elementen; Fortschritt UA → EL per Link; HF-Rückmeldung über
gemockte Tabelle inkl. großem Weg (mehrteilig).
