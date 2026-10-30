# Plan v98: 📣 Team-Stati auf der Karte · Status-Verlauf · Suchfeld einklappbar (Tablet)

Mit Klaas abgestimmt (30.10.2026). Gilt nur im EL-Modus; HF-Modus bleibt unverändert.
Schon gebaut (Commit d935625): Plakette je Umriss/Raster mit Team, Status und Stand; Sammel-Plakette entfällt.

## 1. Team-Chips (aktueller Status je Team)
- Ein Chip **pro Team mit laufendem Auftrag**: Teamfarbe-Punkt · Team (Hund) · Gebietsname(n) des Auftrags ·
  letzter Status mit Uhrzeit. Beispiel: „● Juh 1 (Kira) · Umriss 2 · ⏸ Pause 14:32“.
  Ohne Meldung: „📲 wartet“ (nicht übernommen) bzw. „📲 übernommen 13:10“.
- Fund/Hilfe: Chip rot. Sortierung: neueste Aktivität zuerst.
- **Verschwindet**, sobald die QR-Rückmeldung dieses Auftrags eingelesen wurde (`x.last`); kommt danach eine neuere
  Meldung (m.t > x.last), erscheint er wieder. Team mit mehreren Aufträgen: der neueste nicht zurückgemeldete.
- Reine Logik `teamChips(sent, msgs, marks, items)` in `web/status.js` (oder eigenes Modul) mit Unit-Tests.

### Platz
- **Tablet (Breite ≥ 700 px)**: Chips in der roten Kopfleiste neben dem Suchfeld. Suchfeld standardmäßig
  eingeklappt zu 🔍-Knopf; Antippen klappt es auf (Fokus), nach Suche/✕/Verlassen ohne Text klappt es zu.
  Eingeklappt so viele Chips wie passen, Rest als „+n“-Chip (öffnet den Verlauf). Aufgeklappt Suchfeld schmaler als heute.
- **Handy (< 700 px)**: kleiner Knopf **„📣 Teams“** oben links unter der Kopfleiste (keine Überlappung mit der
  linken Werkzeugspalte). Antippen klappt eine kompakte, scrollbare Liste der Chips auf (max. ~40 % Höhe);
  nochmal tippen oder Tipp auf die Karte klappt zu. Offen/zu wird pro Gerät gemerkt (`db.teamsOpen`).

### Antippen eines Chips
- Karte springt auf das Gebiet des Auftrags (alle Gebiete umfassend, `fitBounds`) und ein kleines Infofenster zeigt
  die **letzten 3 Meldungen** dieses Teams + Knopf „Alle Meldungen“ (öffnet den Verlauf gefiltert auf das Team).

### Neue Meldungen (außer Fund/Hilfe, die bleiben beim Dringend-Dialog)
- Kein Toast mehr für normale Meldungen. Der Chip des Teams **blinkt** einige Sekunden.
- Meldungen gelten als **ungelesen**, bis man sie gesehen hat (`P.msgSeen` = Set/Objekt gelesener IDs, normalisieren).
- **Mehrere ungelesene Meldungen**: unter den Chips klappt automatisch eine kurze Liste der ungelesenen auf
  (Team · Meldung · Uhrzeit, neueste oben). **Ein Tipp irgendwohin** schließt sie und markiert sie als gelesen.
- Eine einzelne ungelesene Meldung: Chip blinkt und trägt einen Punkt, bis man den Chip antippt oder die Liste
  schließt (dann gelesen).
- Auf dem Handy: ist die Team-Liste zu, blinkt der Knopf „📣 Teams“ und zeigt die Zahl ungelesener; mehrere
  ungelesene klappen die Liste der ungelesenen auf wie oben.

### Erinnerung, wenn ungelesen (Klaas)
- Ist eine Meldung **5 Minuten** ungelesen: Hinweis auf dem Hauptbildschirm (gut sichtbares Banner oben auf der
  Karte: „📣 3 ungelesene Meldungen seit 5 min – antippen“), bleibt stehen bis gelesen. Antippen öffnet die Liste der
  ungelesenen; Tipp irgendwohin danach = gelesen.
- Nach **7 Minuten** ungelesen zusätzlich ein **Piepton** (wie Dringend, aber kürzer), danach alle 2 Minuten erneut,
  bis gelesen. Zeit zählt ab Eingang der ältesten ungelesenen Meldung auf diesem Gerät (`P.msgRecv[id]`).
- Prüfung im bestehenden Takt (z. B. alle 15 s zusammen mit dem Abholen bzw. eigenem 15-s-Timer).
- Logik testbar: `unreadAlert(unread, recvTimes, now)` -> 'none' | 'banner' | 'beep'.

## 2. Verlauf: eigene Kachel „📣 Status“
- Neue Kachel in der rechten Randleiste (EL), Panel `panel-status` (über `SIDE_PANELS`, zweiter Tipp schließt).
- Alle Meldungen (`allMsgs()`), neueste oben: Teamfarbe, Team, Meldung, Uhrzeit („vor x min“), Text, 📍 wenn mit
  Standort; Fund/Hilfe rot. Filter „Alle Teams“ / Team. Zeile mit Standort antippen → Karte springt (`showStatusMark`).
  🗑 je Zeile → `msgDialog`-Löschen mit Warnung. Öffnen markiert alle als gelesen. Kachel zeigt Zahl ungelesener.

## Tests
- Unit: `teamChips` (Inhalt, Sortierung, Ausblenden nach QR-Rückmeldung, Wiedererscheinen, mehrere Aufträge),
  ungelesen/gelesen-Logik, Filter für den Verlauf.
- Playwright `statusbar-e2e.mjs` (Scratchpad), beide Viewports 1280×800 und 412×860, Screenshots ansehen:
  Chips/Knopf sichtbar, Suchfeld ein-/ausklappen (Tablet), Chip antippen → Karte + Infofenster, neue Meldungen →
  Blinken / Liste der ungelesenen, Tipp schließt und markiert gelesen, QR-Rückmeldung → Chip weg, neue Meldung → wieder da,
  Verlauf mit Filter und Löschen. Keine Überlappung mit Randleisten/Suchergebnissen.
- Alle bisherigen Tests grün (`node --test test/*.mjs`, Scratchpad-E2E; Versions-Checks auf v98).
