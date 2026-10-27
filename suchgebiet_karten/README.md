# Suchgebiet-Karten

Web-App (auch als App auf Android installierbar) für Rettungshundestaffeln:
Online-Karte wählen, ein festes Raster über das Suchgebiet legen, einzeichnen,
als PDF ausgeben und direkt per E-Mail/Messenger verschicken.

**App öffnen:** https://flai331.github.io/Programmieren/suchgebiet-karten/

## Auf Android installieren

1. Link oben in **Chrome** öffnen
2. Menü ⋮ → **„Zum Startbildschirm hinzufügen“** bzw. **„App installieren“**
3. Die App startet danach wie jede andere App im Vollbild.

## Bedienung

| Knopf | Funktion |
|---|---|
| **Raster** | Feldgröße wählen (25 m – 1 km), Suchgebiet aufziehen oder aktuellen Ausschnitt nehmen, Feld suchen (z. B. „C4“) |
| **Karte** | OpenStreetMap, OpenTopoMap, basemap.de (amtlich), Luftbild |
| **GPS** | Eigener Standort, oben wird das aktuelle Feld angezeigt |
| **PDF** | Übersicht + Detailblätter (2×2 … 5×5 Felder) + aktueller Ausschnitt, A4/A3, hoch/quer |
| Stift / Text / Feld / Radierer | Freihand zeichnen, Punkt mit Text setzen, Feld einfärben (z. B. „abgesucht“ / Team-Farbe), Zeichnung löschen |

Antippen der Karte im Modus „Bewegen“ zeigt, in welchem Feld man getippt hat.

### Warum stimmt A1 überall überein?

Das Raster hängt an festen Koordinaten: A1 beginnt an der Nordwest-Ecke des
Suchgebiets, jedes Feld ist exakt *n* Meter breit und hoch. Alle Karten und
PDF-Blätter rechnen aus denselben Koordinaten – egal in welchem Maßstab.
Spalten = Buchstaben (A, B, … Z, AA …) von West nach Ost, Zeilen = Zahlen von
Nord nach Süd. Im PDF stehen Ursprung und Feldgröße in der Fußzeile.

### PDF senden

„Senden / Teilen“ öffnet auf dem Handy das Teilen-Menü (Gmail, Outlook,
WhatsApp, Signal …) mit dem PDF als Anhang. Am PC wird das PDF
heruntergeladen und das E-Mail-Programm geöffnet.

## Hinweise

- Alles bleibt lokal im Browser gespeichert (Raster, Zeichnungen, Titel).
- Bereits angesehene Kartenkacheln werden zwischengespeichert und sind bei
  schlechtem Empfang verfügbar.
- Google Maps ist nicht enthalten: Die Nutzungsbedingungen verbieten das
  Abfotografieren/Exportieren der Karten. Luftbilder kommen stattdessen von Esri.

## Entwicklung

```bash
npm test          # Tests für Raster-Logik und PDF-Blattplanung
./deploy.sh       # web/ nach docs/suchgebiet-karten kopieren (GitHub Pages)
```
