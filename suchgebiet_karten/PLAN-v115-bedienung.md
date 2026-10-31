# Plan v115: Eindeutige Bedien- und Darstellungsfehler (Prüfung vom 31.10.2026)

## Grundlage

Zwei Prüfberichte, die Kürzel unten beziehen sich auf sie; dort stehen auch Screenshots und Auslöser:

- `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/audit/el.md`, Kürzel D, B und U.
- `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/audit/hf.md`, Kürzel HF-Abschnitt.Nr.

Klaas hat entschieden, eindeutige Fehler sofort zu beheben. Größere Umbauten sind **nicht** Teil dieses Plans, Klaas entscheidet
darüber später. Dazu gehören:

- „EL einfach“
- Rückkanal EL → HF
- Begleiter-Rolle
- SOS-Knopf
- Live-Senden von Funden aus „Markieren“
- Navigation
- Assistent umsortieren
- Fund im GPX/PDF

## A. Gefährliches und Falsches

1. **D1 – Zoom „−“ unter der Umriss-Leiste**

   Die Leiste `#trackbar` (und ebenso `#gridfitbar`, D9, sowie `#vtxbar`) darf die Zoom-Knöpfe nicht verdecken. Dafür eine der beiden
   Möglichkeiten nehmen:
   - die Leisten über der Zoomleiste bzw. mit Abstand zu ihr platzieren, oder
   - die Zoomleiste anheben, solange eine dieser Leisten offen ist (z. B. eine Body-Klasse).

   Prüfen mit `elementFromPoint` auf „−“: auf Tablet 1280×800 und Handy 412×860 muss das Ergebnis das Zoom-Element sein.

2. **U1/D12 – Plakette zeigt „Standort“ statt der Meldung**

   Plakette am Gebiet, Handy-Aufträge-Liste und Aufträge-Liste zeigen bei einer Standortmeldung mit Art (Person gefunden, Hund zeigt an,
   Hilfe, Hinweis …) die Art, also z. B. „🟢 Person gefunden 00:21“, wie Chip und Status-Fenster es tun.

   Eine dringende Meldung (Fund, Hilfe) bleibt dort sichtbar, auch wenn danach eine Routinemeldung kam. Ein späterer Fund bzw. eine
   spätere Hilfe ersetzt sie. Code: Funktion für Plakettentext und Aufträge-Zeile suchen (grep „📌 Standort“ bzw. „Standort“) und
   mit der Chip-Logik vereinheitlichen.

3. **B20 – Wechsel in den Hundeführer-Modus**

   „Mehr → Hundeführer-Modus“ fragt mit `openDlg` nach:

   > „In den Hundeführer-Modus wechseln? Zurück zur Einsatzleitung geht nur mit der EL-PIN.“

   Knöpfe: „🐕 Wechseln“ und „Abbrechen“.

4. **HF 2.3 – Vorauswahl beim Standort melden**

   „Standort melden“ hat keine Art mehr vorausgewählt. „📍 Hier melden“ bzw. „Senden“ sind deaktiviert bzw. melden „Bitte erst
   auswählen, was gemeldet wird“, bis eine Art gewählt ist.

5. **HF 2.9 – Vorbelegung beim Abschließen**

   „Auftrag abschließen“ belegt den Regler mit dem zuletzt gemeldeten Stand vor. Ohne Stand bleibt 100 %.

6. **HF 2.14 – Zweiter Auftrag**

   Ein zweiter Auftrag (Link oder QR) fragt nach, wenn der laufende Auftrag noch nicht abgeschlossen ist:

   > „Neuer Auftrag für ‹Team› – laufenden Auftrag ‹Team/Gebiet› ersetzen? (Er bleibt unter ‚Frühere Aufträge‘.)“

   Knöpfe: „Neuen übernehmen“ und „Abbrechen“. Ist es derselbe Auftrag (gleiche ID), passiert alles wie bisher ohne Rückfrage.

7. **B7 – Gebiete im Auftrags-Fenster vorankreuzen**

   Gebiete bzw. Umrisse, die dem Team zugeteilt sind, sind vorangekreuzt, so wie der Text es verspricht. Das gilt für Felder des Teams
   im Rastergebiet und für Umrisse mit `to` gleich diesem Team.

8. **U7 – GPX-Import ohne Duplikate**

   Ein GPX-Import legt keine Duplikate an. Ein Track, eine Route oder ein Wegpunkt, der mit gleichem Namen und gleichen Punkten schon
   existiert, wird übersprungen. Die Meldung nennt das: „3 übernommen, 5 schon vorhanden“.

   Danach zoomt die Karte auf die importierten Elemente (U8).

## B. Darstellung

9. **D2/HF 1.12 – Untertitel auf „Einsatzleitung“**

   Der Untertitel auf dem roten Moduswahl-Knopf „Einsatzleitung“ wird lesbar, z. B. weiß mit Deckkraft 0,9.

10. **D3 – Feld „Handy EL“**

    „Handy EL“ im Einsatz-Fenster bekommt denselben Feldaufbau wie die anderen Felder (Beschriftung darüber, gleiche Höhe).
    „Funkrufname EL“ ragt auf 412 px nicht mehr heraus; die Zeile darf umbrechen.

11. **HF 1.1 – Wetter-Fenster beim HF**

    Das Wetter-Fenster wird im HF-Modus nicht mehr von der Auftragskarte verdeckt. Es liegt unterhalb davon bzw. die Position
    berücksichtigt deren Höhe.

12. **HF 1.2 – PDF-Hinweis beim HF**

    Der Hinweis „Diese Karte lässt sich nur anzeigen, aber nicht ins PDF übernehmen“ erscheint nicht im HF-Modus und nicht beim
    Start, sondern nur, wenn die EL eine solche Karte aktiv auswählt.

13. **HF 1.6/1.5 – Dialoge im Querformat**

    Im Querformat 860×412 und auf 360×740 passen Dialoge in den Bildschirm: `max-height` auf die sichtbare Höhe (`dvh`), innen
    scrollbar. Titel und Knopfzeile bleiben sichtbar (sticky), soweit das mit dem bestehenden `openDlg`-Aufbau einfach geht.

14. **HF 1.7 – Linke Schnellleiste**

    Die Beschriftung der linken Schnellleiste wird kontrastreicher (mindestens #555, 11 px). Der Zustand „aus“ ist trotzdem erkennbar,
    z. B. am Rahmen oder Hintergrund statt über graue Schrift.

15. **HF 2.12/D11 – Tippziele**

    - Dialog-Knöpfe in `#dlg-box` sind mindestens 48 px hoch.
    - Checkboxen in Dialogen und Panels sind mindestens 22×22 px.
    - Team-Chips oben sind mindestens 34 px hoch.

    Mit Screenshots auf Tablet und Handy prüfen, dass dadurch nichts umbricht oder abgeschnitten wird.

16. **HF 1.3 – Leiste auf 360 px**

    Auf 360 px bricht „Zurückgeben“ in der HF-Leiste nicht auf drei Zeilen um. Möglich sind ein kürzeres Label („Zurück“) oder eine
    passende Schriftgröße bzw. ein passender Umbruch.

## C. Texte und Kleinigkeiten

17. **HF 2.15 – Menüzeile**

    Die Menüzeile „Team 1 – Vermisstensuche – Team 1“ nennt das Team nur einmal.

18. **HF 2.17 – Scan-Hinweis beim HF**

    Text: „Alternativ: Den Link aus WhatsApp/SMS direkt antippen.“

19. **HF 2.19 – Rettungspunkte beim HF**

    Text: „Die Einsatzleitung hat keine Rettungspunkte mitgeschickt.“

20. **HF 2.21 – „zuletzt gesendet“**

    Steht die Zeile „zuletzt gesendet“ ohne echtes Senden da, lautet sie „noch nie gesendet“. Gesendet zählt erst ab dem ersten
    tatsächlichen Senden, nicht ab der Übernahme.

21. **B15 – Status-Server unter „Mehr“**

    Platzhalter und Erklärtext zum Status-Server widersprechen sich nicht mehr. Leer bedeutet den eingebauten Standard-Server; „aus“
    gibt es nicht bzw. wird klar benannt. Erst den Code prüfen, was leer bewirkt.

22. **B16/U2 – Reihenfolge von Chips und Aufträgen**

    Chips oben und Aufträge-Listen stehen in fester Team-Reihenfolge (Reihenfolge von `P.marks`, wie im Teams-Fenster). Dringende
    Meldungen werden farblich hervorgehoben, aber nicht nach vorn sortiert.

    Ausnahme: Passen nicht alle Chips hin (D8, „+1“), stehen Teams mit ungequittiertem Fund bzw. Hilfe zuerst, damit sie nicht hinter
    „+n“ verschwinden.

23. **HF 2.13 – Zweimal „Wind“**

    Links heißt der Knopf „Windpfeile“, unten „Wind messen“. Hat der Platz dafür nicht gereicht, nur links ändern.

24. **U5 – Symbole in „Teilen“**

    „UA“ und „EL/ELW“ haben in „Teilen“ unterschiedliche Symbole, z. B. UA 🧭 und EL/ELW 🚐.

## Tests

- **Unit-Tests:** `node --test test/*.mjs` muss grün sein. Wo Logik rein ist (Plakettentext, GPX-Duplikate, Chip-Sortierung), dafür
  Unit-Tests schreiben.

- **Playwright-Skript:** `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/bedienung-e2e.mjs` mit
  Tablet 1280×800, Handy 412×860, 360×740 und Querformat 860×412.
  - Je Punkt eine Prüfung, wo sinnvoll.
  - Von den geänderten Ansichten Screenshots machen und ansehen.
  - Skripte und Hilfen der Prüfer dürfen als Vorlage dienen, liegen aber nur als Vorlage vor:
    - `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/audit/el/*.mjs`
    - `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/audit/hf/*.mjs`

- **Bestehende e2e-Skripte** bleiben grün: areas, progress, tapclose, accept, close, status, park, longpress, hidden, licence, vertex,
  gridfit, noteam, reorder und robust. Ändert sich durch einen Plan-Punkt gewolltes Verhalten (z. B. die Vorauswahl in Punkt 4, die
  Rückfrage in Punkt 3 oder 6), das betroffene Skript anpassen und im Bericht nennen.

- **Testserver:** Liefert curl nicht 200, starten mit `cd web && (nohup python3 -m http.server 8765 >/dev/null 2>&1 &)`. Niemals
  `pkill -f`. Skripte laufen mit `NODE_PATH=$(npm root -g) node …`.

- **Nicht** committen, deployen oder die Version ändern; kein git checkout, stash oder reset.
