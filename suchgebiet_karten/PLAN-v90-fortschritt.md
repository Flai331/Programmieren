# Plan v90: 🔒 Unterabschnitt-Sperren · 🔄 Fortschritt senden (nur QR)

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
  importierte HF-Rückmeldungen (Wege/Markierungen mit `resultKey`, Team, Zeit), empfangene Status-Meldungen.
- Zusammenführen nur ergänzend (gleiche Regeln wie `mergeInfos`): Neues kommt dazu; Geändertes nur,
  wenn Absender es zuletzt bearbeitet hat (`by === from`) und neuer; nichts wird gelöscht;
  Löschvermerke des Empfängers blockieren Wiederanlegen. Feldkonflikt: neuere Änderung gewinnt,
  im UA-Gebiet entscheidet der UA.
- Richtung: UA → EL nur UA-Gebiet + Neues des UA + Rückmeldungen seiner Teams.
  EL → UA alles, beim UA mit `lock: 'base'` (außer UA-eigene Elemente).
  EL ↔ EL/ELW alles, beidseitig ergänzend.
- Zuordnung über `eid`/`parentEid` (wie `infoTarget`).
- Übertragung **nur per QR-Code bzw. Link** (mehrteilig `#m` wie Übergabe). **Nicht** über
  Google Sheets: die Tabelle trägt ausschließlich die Status-Meldungen aus v89.
- **Nur zwischen Geräten der Einsatzleitung** (EL, UA, ELW) in beide Richtungen – nicht an/von
  Hundeführern (die nutzen Auftrag/Rückmeldung wie bisher).
- **Nur das Neue senden statt des ganzen Einsatzes** (Klaas, 30.10.2026): jedes Element trägt
  eine Änderungszeit (`t`, bei Feldern `g.statusT[k]`/`g.fillT[k]`, Protokoll-/Wind-Einträge
  ihre Zeit). Beim Senden fragt die App „An wen?“ (gemerkte Empfänger je Einsatz,
  `P.peers = [{ name, lastSent }]`, neuer Empfänger per Name) und packt nur, was seit
  `lastSent` dieses Empfängers neu/geändert ist; danach `lastSent = jetzt`.
  Zusätzlich Knopf „Alles seit Beginn erneut senden“ (falls ein QR nicht ankam).
  Der Empfänger verträgt doppelte Inhalte (feste IDs), daher ist erneutes Senden unschädlich.
  „Nichts Neues seit HH:MM“ statt eines leeren QR-Codes.
- Die bisherige Übergabe des ganzen Einsatzes (`#e`) bleibt nur für den ersten Start eines
  weiteren EL-Geräts bzw. UA; danach läuft alles über „🔄 Fortschritt senden“.
- Meldung: „🔄 Fortschritt von <Gerät>: 12 Felder, 2 Wege, 3 Protokolleinträge“.
- Knopf in „📤 Weitergeben“ neben „Infos senden“; Gerätename wie bei Infos.

## C. Abgrenzung (Klaas, 30.10.2026)

Über die Google-Tabelle laufen **nur Rückmeldungen im Sinne von Status-Meldungen** (v89).
Einsatzdaten – Laufwege, markierte Punkte, Zeichnungen, Feld-Status, HF-Rückmeldung (`#r`),
Übergabe, Fortschritt – gehen weiterhin **nur per QR-Code/Link**.

## Tests

Unit: locks, progress-merge (Richtungen, keine Löschung, Konflikte, Idempotenz).
Playwright: UA mit gesperrten Elementen; Fortschritt UA → EL per Link (auch mehrteilig).
