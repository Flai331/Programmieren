# Plan v101: ✅ Auftrag abschließen / abbrechen · Markierungen gehen an das nächste Team mit

Mit Klaas abgestimmt (30.10.2026). Das Selbst-Update (`PLAN-v100-update-und-tippen.md`) rückt auf v102.

## 1. Hundeführer: eigener Knopf „✅ Auftrag abschließen“
- Neue Taste im 📣 Status-Fenster, **getrennt** von „📊 Stand / fertig“: Ein Auftrag kann auch bei 80 % beendet
  oder abgebrochen werden.
- Rückfrage-Dialog „✅ Auftrag abschließen?“:
  - Wie viel ist abgesucht? Je Gebiet (wie „Stand“, vorausgefüllt mit dem letzten Stand), Kurztext optional
    („Grund, z. B. Hund müde, Dunkelheit“).
  - Knöpfe **Abschließen** / **Abbrechen**.
- Meldung `s: 'zu'` („✅ Auftrag abgeschlossen“) mit `ar`/`pc` und `txt`, ohne Standort; geht über den Status-Server
  bzw. mit der nächsten QR-Rückmeldung.
- Danach schlägt die App direkt **📤 Zurückgeben** vor (QR der Rückmeldung). Der Auftrag bleibt im HF-Handy offen,
  Kopfzeile zeigt „✅ abgeschlossen – bitte zurückgeben“.

## 2. Einsatzleitung: Auftrag als abgeschlossen markieren
- Meldung `zu` kommt an → Auftragskarte und Team-Chip zeigen „✅ meldet abgeschlossen hh:mm (80 %)“.
- **Rückfrage „Auftrag {Team} abschließen?“** („Das Team meldet ihn als erledigt (80 % abgesucht), die Rückmeldung ist da.“
  → **✅ Abschließen** / **Noch offen lassen**) kommt, sobald **beides** da ist: Meldung `zu` und eine QR-Rückmeldung
  dieses Auftrags – egal in welcher Reihenfolge.
- Zusätzlich auf jeder übernommenen Auftragskarte Knopf **„✅ Abschließen“** (auch ohne Meldung des Teams), mit Rückfrage.
- Abgeschlossen (`sent.done = Zeit`, `sent.pct`):
  - Karte grau in einem eigenen Bereich „✅ Abgeschlossen“ (aufklappbar), mit „↩ Wieder öffnen“.
  - Chip verschwindet aus der Teamleiste; das Team gilt als frei.
  - Plakette am Gebiet grün „✅ {Team} · 80 %“.
  - Der 🔒-Schutz der Felder/Zeichnungen dieses Auftrags entfällt (das Gebiet kann neu vergeben werden).

## 3. Markierungen bleiben beim Gebiet und gehen an das nächste Team
- Wege, Markierungen, Felder und Windmessungen, die das Team zurückgemeldet hat (`it.resultKey`), bleiben im Einsatz
  wie bisher.
- **Neue Vergabe eines Gebiets** (Teilen → Team, `buildAssignment`): Rückmeldungen früherer Aufträge, die in den
  gewählten Feldern/Umrissen liegen, werden **automatisch mitgeschickt** (bisher ausgeschlossen:
  „Rückmeldungen der Hundeführer nicht zurückschicken“).
  - In der Auswahl als eigene Gruppe „Vom vorherigen Team (Team 1, 80 %)“, vorausgewählt, abwählbar.
  - Beim neuen Team erscheinen sie **gedämpft und nur zum Ansehen** (🔒 „vom vorherigen Team“), mit Namen des Teams;
    sie gehen **nicht** mit der Rückmeldung des neuen Teams zurück (nichts doppelt).
  - Der abgesuchte Stand („80 % von Team 1“) steht im Auftragstext.

## Tests
- Unit: Meldung `zu` (Text/Icon/Prozent), „Rückfrage fällig?“ als reine Funktion (Meldung + Rückmeldung in beiden
  Reihenfolgen, nicht doppelt nach „Noch offen lassen“ für dieselbe Rückmeldung), Auswahl der Vorgänger-Rückmeldungen
  nach Gebiet.
- Playwright (Scratchpad `close-e2e.mjs`, 1280×800 + 412×860, Screenshots): HF schließt bei 80 % ab → EL Chip/Karte,
  QR-Rückmeldung → Rückfrage → abgeschlossen (grau, Chip weg, Plakette grün); andere Reihenfolge; manueller Knopf;
  Wieder öffnen; Gebiet an Team 2 → Vorgänger-Wege/Markierungen im Auftrag, beim HF 2 gedämpft, gehen nicht zurück.
- Bestehende Tests/E2E grün (status, statusbar, send, accept, multi, share …).
