# Plan: Einsatz-Assistent, Kontakte im Auftrag, Übergabe, ELW-Infos

Stand: v66, 29.10.2026. Der Plan wurde von einem Plan-Agenten erstellt und gegen den Code geprüft. Er ist noch nicht umgesetzt und wartet auf Freigabe.

## Geprüft am Code

| Stelle | Befund |
|---|---|
| `QR_MAX` | 1800 Zeichen (`app.js`). Ein QR-Code vom Handybildschirm ist darüber nicht mehr sicher lesbar. |
| `parseShared` | Kennt nur `#a=` (Auftrag) und `#r=` (Rückmeldung). |
| Android `sharedHash` | Lässt nur `a=`/`r=` durch. Neue Linkarten brauchen eine neue APK. |
| `sw.js` `APP_FILES` | Neue JS-Dateien müssen dort eingetragen werden, sonst fehlen sie offline. |
| `store.js` `cellRects` | Fasst Felder zu Rechtecken zusammen. Damit lassen sich Raster in der Übergabe kompakt übertragen. |
| `contacts.js` `normalizeContact`/`mergeContacts` | Wiederverwendbar für Einsatz-Kontakte und das Zusammenführen ohne Duplikate. |

Feste EL-PIN 110112, keine neuen PINs. Alte Links bleiben gültig.

---

## A) Kontakte im Auftrag

**Einsatz-Fenster:** neuer Abschnitt „📇 Kontakte für diesen Einsatz“.
- Kontakte aus dem Adressbuch anhaken oder neu anlegen.
- Die Einsatzleitung (Name und Handy) steht automatisch dabei.
- Die Kontakte werden als Kopie im Einsatz gespeichert (`P.contacts`). So bleibt der Einsatz vollständig, auch ohne Adressbuch.

**Auftrag:** Häkchen „Kontakte mitgeben“, darunter einzeln abwählbar.
- Mit gehen nur Name, Funktion, Funkrufname, Telefon und Telefon 2. E-Mail und Notizen bleiben aus Datenschutzgründen weg.
- Je Kontakt etwa 40–50 Zeichen. Ein Auftrag mit 8 Kontakten passt noch in einen QR-Code.

**Hundeführer:** Im Menü erscheint „📞 Kontakte (n)“, aber nur wenn welche mitkamen.
- Große Zeilen, Antippen ruft an.
- Kein Bearbeiten, das Adressbuch bleibt im HF-Modus ausgeblendet.
- Alte App-Versionen ignorieren die Kontakte einfach.

## B) Assistent „Neuen Einsatz anlegen“

Der Assistent ersetzt beim „Neu“-Knopf die bisherige Namensabfrage. „Ohne Assistent“ bleibt als Weg erhalten.
- Jeder Schritt lässt sich überspringen.
- Eingaben werden sofort gespeichert.
- Ein abgebrochener Assistent lässt sich fortsetzen.

1. **Einsatz:** Name (Vorschlag „Einsatz TT.MM.JJJJ“).
2. **Einsatzleitung:**
   - Name, Handynummer, Funkrufname EL, Funkrufname ELW.
   - Weitere Funkrufnamen als Liste (Funkrufname + wer).
   - Übernahme aus dem Adressbuch bzw. „wie letztes Mal“.
3. **B-Ort:** drei große Knöpfe:
   - 📍 Mein Standort (GPS, mit Genauigkeit)
   - 🔎 Adresse/Kreuzung (vorhandene Suche)
   - 🗺️ Auf der Karte tippen (danach zurück in den Assistenten)
4. **Vermisste Person:** kurzes Textfeld, optional der letzte bekannte Ort.
5. **Zeiten:** Alarmierung mit „Jetzt“, optional Eintreffen.
6. **Kontakte für den Einsatz:** wie in A.
7. **Abschluss:** Knöpfe „Raster aufziehen“, „Umriss zeichnen“, „An Tablet/PC übergeben“, „Fertig“.

Die Einsatzleitung landet zusätzlich im bisherigen Feld `leader`. PDF, JUH-Formular und Bericht laufen so unverändert weiter.

## C) Übergabe Handy → Tablet/PC (neuer Link `#e=`)

Ein Dialog „📲 Einsatz übergeben“ bietet drei Wege:

| Weg | Inhalt | Wann |
|---|---|---|
| **QR-Code** | Einsatz ohne Fotos/Notizblock, Linien automatisch vereinfacht. Passt das nicht in 1800 Zeichen, gehen nur die Stammdaten (EL, Funk, B-Ort, Person, Zeiten, Kontakte, Teams, Aufträge), mit deutlichem Hinweis. | Tablet daneben, auch ohne Netz |
| **Link** | Alles außer Fotos und Notizblock | PC (WhatsApp Web, Mail) |
| **Datei** | Alles inkl. Fotos (vorhanden) | Vollständiger Stand |

- **Wichtig:** Die gesendeten Aufträge (`sent`) gehen mit. Sonst ordnet das Tablet spätere Rückmeldungen der Hundeführer nicht zu.
- Schon übernommene Rückmeldungen werden auf dem Tablet erkannt, es entstehen also keine Duplikate.
- Jeder Einsatz bekommt eine feste Einsatz-ID. Ist der Einsatz auf dem Ziel schon da, fragt die App: „Ersetzen / Als Kopie / Abbrechen“.
- Nach der Übergabe führt das Tablet. Das Handy zeigt das Banner „an Tablet übergeben“.

**Faustregel:** Ein früher Einsatz passt in einen QR-Code, ein laufender Einsatz mit vielen Wegen braucht den Link oder die Datei.

**Optional später (C2):** mehrteiliger QR-Code, der automatisch durchwechselt. Dann gehen große Einsätze auch ohne Netz rüber, aber nur mit dem Scanner in der App.

## D) ELW-Besatzung → Einsatzleitung (neuer Link `#i=`)

**Empfehlung:** kein dritter Modus. Das ELW-Gerät arbeitet im EL-Modus und kennt also die PIN. Es bekommt den Einsatz per Übergabe (C), dadurch passt die Einsatz-ID.

**Neues Werkzeug „📍 Lage-Ort“** für alle EL-Geräte:
- Kategorie wählen:
  - 🚐 ELW, 🅱️ Bereitstellungsraum, 🅿️ Parkplatz
  - 🚻 Toilette, 🍲 Verpflegung, 🚰 Ver-/Entsorgung
  - 🚑 Sanität, ❓ letzter bekannter Ort, 📌 Sonstiges
- Ort per GPS, Kartentipp oder Adresse.
- Dazu Name und Beschreibung.

**„📤 Infos an EL senden“:**
- Gesendet werden standardmäßig nur neue oder geänderte Orte, optional mit Kontakten.
- Übertragung per QR-Code oder Link. Etwa 25–30 Orte passen in einen QR-Code.

**Beim EL:** Scannen oder Link öffnen.
- Zusammenführen ohne Duplikate: Neues kommt dazu, Geändertes wird aktualisiert, Gelöschtes verschwindet.
- Mehrfach scannen schadet nicht.
- Meldung z. B. „📥 Infos von ELW 11-1: 3 neu, 1 geändert“.

**Lage-Orte auf der Karte, im PDF und im GPX:** als Wegpunkte für BaseCamp. Optional können sie mit dem Auftrag an Hundeführer gehen.

---

## Reihenfolge

| Paket | Inhalt | Größe | Version |
|---|---|---|---|
| 1 | Grundlagen: neue Datenfelder, Links `#e=`/`#i=` erkennen (Web, Tabs, Android), gemeinsame Kürz-Logik für Links | klein | v67 |
| 2 | A Kontakte im Auftrag | klein | v67 |
| 3 | B Assistent inkl. Ortswahl (GPS/Suche/Karte) | mittel–groß | v68 |
| 4 | C Übergabe (QR/Link/Datei) | mittel | v69 |
| 5 | D Lage-Orte + ELW-Infos | groß | v70 |
| 6 | C2 mehrteiliger QR-Code (optional) | mittel | v71 |

Neue Logik kommt in eigene, testbare Dateien (`handover.js`, `pois.js`, `wizard.js`). `app.js` hat schon 4580 Zeilen.

## Tests

**Unit-Tests:**
- Alte `#a=`/`#r=`-Links gehen weiter; ein Auftrag mit und ohne Kontakte wird gelesen.
- Übergabe ohne Verluste: Raster, Teams, Aufträge, keine doppelten Rückmeldungen.
- Kürzen auf 1800 Zeichen.
- ELW-Infos zweimal scannen ergibt beim zweiten Mal 0 neu; Ändern und Löschen werden übernommen.
- Alte Projekte bekommen die neuen Felder.

**Browser/Gerät:**
- Assistent mit allen B-Ort-Wegen, Abbruch und Fortsetzen.
- Auftrag mit Kontakten an ein zweites Handy, dort anrufen.
- Übergabe Handy → Tablet (QR) und → PC (Link).
- Danach Rückmeldung am Tablet scannen.
- ELW sendet Lage-Orte.
- PIN-Abfrage im HF-Modus.
- Neue APK öffnet die neuen Links.
- Offline-Start.

## Risiken

- **Alte APKs:** Sie öffnen `#e=`/`#i=` im Browser statt in der App. Dann erscheint der Hinweis „Einsatz hier unbekannt“, deshalb muss das APK-Update angekündigt werden.
- **Lange Links:** SMS und manche Messenger kürzen sie. Die Größe wird angezeigt; bei großen Einsätzen rät die App zur Datei.
- **Nachtmodus:** Ein großer QR-Code auf rotem Bildschirm ist schwer lesbar. Der QR-Dialog bleibt deshalb immer schwarz auf weiß.
- **Zwei Geräte arbeiten weiter:** Nach der Übergabe gibt es kein echtes Zusammenführen, das Tablet führt.
- **Datenschutz:** Telefonnummern und vermisste Person stehen im Link. Deshalb Auswahl je Kontakt; die Person geht nur auf Wunsch mit.

## Offene Fragen an dich

1. **Kontakte im Auftrag:** Sollen standardmäßig alle Einsatz-Kontakte mitgehen oder nur angehakte? Ist die EL-Nummer immer dabei?
2. **Hundeführer:** Soll er Kontakte ins Handy-Telefonbuch speichern können oder nur anrufen?
3. **Assistent:** Fehlt ein Schritt? Zum Beispiel Einsatzstichwort, Leitstelle mit Nummer oder Anforderer (Polizei)?
4. **Funkrufnamen:** Freie Liste oder feste Felder (Leitstelle, Polizei, Staffelführer)? Sollen sie ins PDF bzw. JUH-Formular?
5. **Übergabe:** Ist der mehrteilige QR-Code (ohne Netz, große Einsätze) wichtig, oder reichen QR klein + Link + Datei?
6. **Handy nach der Übergabe:** Weiter normal arbeiten, nur anzeigen oder löschen?
7. **ELW-Gerät:** Passt es, dass die ELW-Besatzung die EL-PIN kennt (EL-Modus)? Oder braucht es einen eingeschränkten ELW-Modus ohne PIN?
8. **Richtung der Infos:** Nur ELW → EL, oder auch EL → ELW? Das kostet kaum mehr.
9. **Kategorien der Lage-Orte:** Passen sie? Fehlen z. B. Hubschrauber-Landeplatz, Hydrant, Sammelstelle, Presse?
10. **Lage-Orte an Hundeführer:** Sollen sie optional mit dem Auftrag gehen?
11. **Vom ELW gelöschte Orte:** Sollen sie beim EL verschwinden oder nur markiert werden?
12. **Gerätename:** Soll beim ersten Senden nach einem Gerätenamen gefragt werden (Vorschlag: Funkrufname ELW), oder reicht „ELW“?
