# Plan v99: 📤 Teilen neu – erst „An wen?“, dann „Was?“, dann „Wie?“

Mit Klaas abgestimmt (30.10.2026). Nur EL-Modus (Panel `panel-share`, `web/index.html` + `web/app.js` ab `shareScope`).

## Ablauf im Teilen-Fenster
**1. An wen?** (neue Kachelreihe ganz oben, wie `share-grid`; Standard: nichts gewählt bzw. zuletzt gewählter)
- 🐕 **Hundeführer / Team** – darunter sofort die Team-Auswahl (`share-team`)
- 🚐 **Unterabschnitt (UA)**
- 🚐 **EL / ELW: ganzer Einsatz** (weiteres Tablet, Einsatzleitwagen)
- 👥 **Sonstige** (ohne App: Polizei, Feuerwehr, Druck, Garmin, Mail …)

**2. Was?** (bisherige Kacheln, aber **ohne „👥 Für ein Team“**)
- Team: 🗺️ Ein Gebiet / 🎯 Eigene Auswahl (+ 🗂️ Ganzer Einsatz). **Vorausgewählt**: das, was bisher
  `selectTeam(P, teamId)` liefert (Felder/Umrisse des Teams); „✏️ Auswahl auf der Karte ändern“ ergänzt.
- UA: 🗺️ Ein Gebiet / 🎯 Eigene Auswahl.
- EL/ELW ganzer Einsatz: Schritt 2 ausgeblendet (immer ganzer Einsatz).
- Sonstige: 🗂️ Ganzer Einsatz / 🗺️ Ein Gebiet / 🎯 Eigene Auswahl (wie heute).

**3. Wie?** (bleibt wie heute: 📲 QR-Code, 🧭 Garmin, 📧 Mail, 💾 Speichern, 📄 PDF, ggf. „Suchgebiet als Datei“)
- Team: **alle** Wege. 📲 QR-Code = Auftrag (bisher `prefillSend(shareSel, teamId)`, ohne Zwischendialog).
- UA: 📲 QR-Code = Unterabschnitt (`handoverQr(subsetProject(..., { base: true }), false)`); die übrigen Wege
  ausgeblendet (sinnlos ohne App-Übergabe).
- EL/ELW: 📲 QR-Code = ganzer Einsatz (`handoverQr(P, true)`); übrige Wege ausgeblendet.
- Sonstige: alle Wege außer QR-Code (QR braucht die App); PDF/Garmin/Mail/Speichern wie heute.
- Der Zwischendialog „📲 QR-Code für …“ entfällt.

## Details
- Texte/Hinweise je Empfänger kurz unter „1. An wen?“ (z. B. UA: „bearbeitbar nur das ausgewählte Gebiet, Rest nur ansehen“).
- Einstiege, die heute direkt ins Teilen springen (`mode === 'share'` aus der Kartenauswahl, Auftrag senden aus der
  Teams-Übersicht usw.), setzen sinnvoll vor: z. B. aus der Teams-Übersicht → Empfänger Team + Team gewählt.
  Alle Aufrufer von `renderShare`/`shareScope` prüfen.
- Gewählter Empfänger wird pro Gerät gemerkt (`db.shareTo`), Team nicht.

## Tests
- Playwright (Scratchpad `share-e2e.mjs`, 1280×800 und 412×860, Screenshots ansehen): jeder Empfänger zeigt die
  richtigen Schritte/Knöpfe; Team → Vorauswahl = Teamfelder, QR erzeugt Auftrag (wie `send-e2e`); UA → QR ist
  Unterabschnitt (`#`-Link prüfen); EL/ELW → QR ganzer Einsatz ohne „Was?“; Sonstige → kein QR-Knopf, PDF/GPX gehen.
- Bestehende Tests/E2E grün (`node --test test/*.mjs`, send/multi/accept/statusbar …; Versionen auf v99).
