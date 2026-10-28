# Suchgebiet-Karten

Web-App (auch als App auf Android installierbar) für Rettungshundestaffeln:
Online-Karte wählen, ein festes Raster über das Suchgebiet legen, einzeichnen,
als PDF ausgeben und direkt per E-Mail/Messenger verschicken.

**App öffnen:** https://flai331.github.io/Programmieren/suchgebiet-karten/

## Auf Android installieren

**Variante A – APK (eigene App):**
[Suchgebiet-Karten.apk](https://github.com/Flai331/Programmieren/releases/download/suchgebiet-karten/Suchgebiet-Karten.apk) (oder als [ZIP](https://github.com/Flai331/Programmieren/releases/download/suchgebiet-karten/Suchgebiet-Karten-APK.zip))
herunterladen, Installation aus unbekannten Quellen erlauben, installieren.
Neue Versionen lassen sich einfach drüber installieren.

**Variante B – Web-App:** Link oben in **Chrome** öffnen → Menü ⋮ →
**„Zum Startbildschirm hinzufügen“**. Updates kommen automatisch.

Beide Varianten speichern getrennt – ein Suchgebiet lässt sich per Datei
von der einen in die andere übernehmen.

## Bedienung

| Knopf | Funktion |
|---|---|
| **Suchfeld (oben)** | Adresse, Ort, Straße suchen (OpenStreetMap), **Kreuzungen** („Hauptstraße Ecke Bahnhofstraße, Celle“ oder „Hauptstr./Bahnhofstr.“), außerdem Feldnamen („C4“) und Koordinaten („50.12, 8.61“) |
| **Gebiete** | Name des Einsatzes, mehrere Suchgebiete speichern, wechseln, kopieren, löschen · Einsatzleitung, Notizen, Treffpunkt · Suchgebiet als Datei senden / Datei öffnen |
| **Raster** | Feldgröße (25 m – 1 km; bei neuer Feldgröße oder neuem Gebiet wandern Teams und Status auf die neuen Felder mit – kleinere Felder erben die Markierung des großen Feldes, ein größeres Feld behält sie, sobald ein Teil markiert war), Suchgebiet aufziehen oder Ausschnitt nehmen, Feld suchen („C4“), **Auf der Karte zeigen**: Raster, Randbeschriftung, Treffpunkt, jedes Team, jede Markierung, jede Zeichnung, jeder Umriss und Text einzeln ausblendbar; „Alles ausblenden“ / „Alles einblenden“ (nur Anzeige), **UTM-Schalter** |
| **Teams** | Teams (Name, Hund, Farbe) und Status („abgesucht“, „nicht begehbar“ …) anlegen. Ein Feld behält sein Team; der Status liegt zusätzlich schraffiert darüber |
| **Karte** | TopPlusOpen (topografisch, mit Waldwegen), basemap.de farbig/grau, Luftbild Niedersachsen (LGLN), Luftbild NRW – über Luftbildern zuschaltbar: Wege, Straßen, Ortsnamen |
| **GPS** | Eigener Standort, oben steht das aktuelle Feld (mit UTM-Schalter auch UTMREF) |
| **Export** | PDF, GPX für Garmin/BaseCamp, Garmin-Karte (KMZ) – jeweils **📤 Teilen** (WhatsApp, Mail, Signal …) oder **💾 Speichern** |
| **Mehrere Rastergebiete** | Raster → „+ Weiteres Rastergebiet“ und Fläche aufziehen. Jedes Gebiet hat eigenen Namen (✏️, z. B. „Nord“), eigene Feldgröße und eigene Felder ab A1; der Name steht auf der Karte über dem Gebiet. In der Liste antippen = bearbeiten und hinzoomen; mit dem Feld-Werkzeug einfach im anderen Gebiet tippen. Im Export-Fenster ankreuzen, welche Gebiete ins PDF (je Gebiet eigene Blätter), GPX (ein Raster-Track je Gebiet, Team-Tracks mit Gebietsnamen) und in die Garmin-Karte kommen |
| **Leiste links** | „#“ Raster und „▦“ Felder (Teams und Markierungen) mit einem Tipp aus-/einblenden, darunter die **Zoomleiste** (ziehen, tippen oder +/−) |
| Stift / Text / Feld / Umriss / Radierer (nochmal antippen = zurück zu „Bewegen“) | Freihand zeichnen, Punkt mit Text, Felder einem Team zuteilen (antippen oder drüberwischen), Gebiet Punkt für Punkt umranden (im GPX ein Track), löschen |
| **Einsatz** (📋) | Einsatzprotokoll mit Eckdaten, kein ETB. Reiter **Lage**: vermisste Person, **Zeiten** (Alarmierung mit Datum, Abfahrt, Eintreffen, Einsatzbeginn, Einsatzende, Rückkehr – „Jetzt“ oder von Hand), Kräfte je Organisation (Stärke als Zahlen: Führung/Helfer//Gesamt + Hunde), Notizen getippt, **Notizblock** für Handschrift mit Stift oder Finger (Seiten, 3 Farben, Rückgängig), **Fotos** vom Papier. Reiter **Einsatzende**: Notizen und Fotos links ansehen (zoombar; gezoomt mit Finger oder Maus frei verschieben, Doppelklick/-tippen zoomt), rechts zusammenfassen; Legende für die Stiftfarben auf der Karte; Verfasser; E-Mail-Empfänger. **Abschlussbericht** (PDF, ohne Karte) mit Bericht, Notizseiten und Fotos; Versand siehe unten. Im Browser hängt das Teilen-Menü die Dateien an, die Empfänger werden in die Zwischenablage kopiert |
| **Einsatzende – Versand** | Je Empfänger-Zeile ankreuzen, was mitgeht. **Abschlussbericht**: Zeiten, Vermisste Person, Kräfte, Zusammenfassung, Notizen, Notizblock, Fotos, Karte (ohne Raster, Flächen beschriftet, automatisch so gezoomt, dass alle Markierungen, Zeichnungen, Umrisse, Texte und der Treffpunkt samt Beschriftung drauf sind; voreingestellt aus) – dazu je Empfänger, ob die Karte Teams und/oder Status (abgesucht, teilweise, nicht begehbar) zeigt. **Zusätzlich:** JUH-Formular, GPX. „Senden“ öffnet das Mailprogramm mit genau diesen Anhängen, auch der Mailtext enthält nur die angekreuzten Inhalte (Android-App: inkl. Empfänger) |
| **JUH-Formular** | Vorlage „Einsatzbericht Rettungshundestaffel“ wird mit den vorhandenen Daten vorausgefüllt (Kräfte eigene/fremde, Lage, Verlauf, Besonderheiten, Einsatzleitung …); alle Felder bleiben im PDF ausfüllbar. Bei den Kräften „eigene“ anhaken |
| Zeichnung benennen | Im Stift-Werkzeug „🏷️ Letzte Zeichnung benennen“ oder eine Zeichnung (auch einen Umriss) antippen. Der Name steht auf der Karte, im PDF und als Trackname im GPX |

Antippen der Karte im Modus „Bewegen“ zeigt Feld, zugeteiltes Team und ggf. UTMREF.

### Warum stimmt A1 überall überein?

Das Raster hängt an festen Koordinaten: A1 beginnt an der Nordwest-Ecke des
Suchgebiets, jedes Feld ist exakt *n* Meter breit und hoch. Alle Karten und
PDF-Blätter rechnen aus denselben Koordinaten – egal in welchem Maßstab.
Spalten = Buchstaben (A, B, … Z, AA …) von West nach Ost, Zeilen = Zahlen von
Nord nach Süd.

### UTM

Mit dem Schalter „UTM-Koordinaten anzeigen“ (Raster-Fenster) erscheinen ein
blaues UTM-Gitter mit Kilometerwerten, UTMREF-Angaben bei GPS/Antippen und
UTM/UTMREF für Treffpunkt und A1 im PDF. Ohne Schalter bleibt alles bei A1-Feldern.

### PDF

- **Übersicht:** ganzes Raster, Umrisse der Detailblätter mit Seitenzahl
- **Einsatzinformationen:** Einsatzleitung, Treffpunkt mit Koordinaten,
  Teams mit zugeteilten Feldern (z. B. „Team Nord (Bello): A2–C2, A3“),
  Legende, Notizen
- **Detailblätter:** größerer Maßstab, Bereich außerhalb des Blatts aufgehellt
- Jede Karte mit Maßstab, Maßstabsleiste, Nordpfeil und Farblegende

„Senden / Teilen“ öffnet das Teilen-Menü (Gmail, Outlook, WhatsApp, Signal …)
mit dem PDF als Anhang. Am PC wird es heruntergeladen und das E-Mail-Programm geöffnet.

### Wohin wird gespeichert?

- **Browser:** „Speichern“ legt die Datei im **Download-Ordner** ab.
- **Android-App:** „Speichern“ fragt nach Ordner und Dateinamen.
- **Teilen** öffnet immer das Teilen-Menü des Handys (WhatsApp, Gmail, Outlook, Signal, Threema …).
  Am PC gibt es kein Teilen-Menü – dort wird heruntergeladen und das E-Mail-Programm geöffnet.

### Garmin (BaseCamp und GPS-Gerät)

**Umriss zeichnen:** Werkzeug „📐 Umriss“ → Punkte auf die Karte tippen (Ziehen verschiebt die Karte) →
„Fertig“ → Namen eingeben. Länge und ab 3 Punkten die **Fläche in ha** werden angezeigt (der Umriss gilt als geschlossen, die Verbindung zurück zum Start ist gestrichelt); die Fläche steht auch am Namen auf Karte/PDF und in der GPX-Beschreibung. Umrisse erscheinen im PDF und als Track im GPX.

**GPX importieren (z. B. aus BaseCamp):** Gebiete → „Datei öffnen (Suchgebiet, PDF oder GPX)“. Tracks und Routen kommen als Linien (mit Garmin-Farbe und Namen) ins aktuelle Suchgebiet, Wegpunkte als Textpunkte. Geschlossene Tracks (Ende am Anfang) zeigen ihre Fläche in ha. Raster und Feldnamen aus dem eigenen GPX-Export werden übersprungen.

**GPX (Export → Garmin: GPX):** zwei Dateien, BaseCamp macht aus jeder eine eigene Liste:
1. **…_Raster.gpx** – alle Rasterlinien (als eine durchgehende Linie, ohne Schrägen) und die
   Feldnamen: als **Linienschrift** unten links in jedem Feld (Voreinstellung – Rasterlinien und
   Feldnamen sind zusammen *ein einziger* Track „Raster …“ in der Liste), als Wegpunkte (ein
   Eintrag pro Feld) oder keine
2. **…_Markierungen.gpx** – Umrisse, Stift-Markierungen (mit ihrem Namen, sonst „Stift 1 (rot)“), Ränder der Team-/Status-Flächen,
   Treffpunkt und Textpunkte

In BaseCamp: im Einsatz-Ordner zwei Listen anlegen (Rechtsklick → *Neue Liste*, z. B. „Raster“ und
„Markierungen“), Liste anklicken, dann *Datei → Importieren in „…“* – BaseCamp importiert immer in
die links ausgewählte Liste. Danach an das Gerät senden.

Getrennte Bereiche (z. B. zweimal „abgesucht“) sind je ein eigener Track mit den Feldern im Namen
(„abgesucht: D3–E4“). In einem einzigen Track würden BaseCamp und Garmin die Teile mit Linien verbinden.
GPX-Linien liegen **über deiner Karte auf dem Gerät** (z. B. der Wanderkarte).

**Garmin-Karte (Export → Garmin: Karte):** Das Kartenbild mit Raster, Teams und Tracks als
KMZ-Datei („Custom Map“). Per USB in den Ordner **Garmin/CustomMaps** auf dem Gerät kopieren
(Ordner anlegen, falls er fehlt). Läuft auf GPSMAP, eTrex 22x/32x, Oregon, Montana u. a.;
BaseCamp selbst zeigt KMZ-Karten nicht an. Die Custom Map ist ein Bild und **verdeckt** in ihrem
Bereich die Gerätekarte – auf dem Gerät lässt sie sich unter *Einrichten → Karte → Kartenoptionen/
Karteninformationen* ein- und ausschalten. Wer die eigene Wanderkarte sehen will, nimmt das GPX.

### Suchgebiet an die Staffel weitergeben

- „Gebiete → Suchgebiet als Datei senden“ verschickt eine kleine Datei.
- **Jedes PDF aus der App enthält das Suchgebiet ebenfalls.** Wer das PDF
  bekommt, kann es unter „Gebiete → Datei öffnen“ laden und mit Raster,
  Teams und Zeichnungen weiterarbeiten.

## Hinweise

- Alles bleibt lokal auf dem Gerät gespeichert.
- Bereits angesehene Kartenkacheln werden zwischengespeichert und sind bei
  schlechtem Empfang verfügbar.
- Google Maps ist nicht enthalten: Die Nutzungsbedingungen verbieten das
  Abfotografieren/Exportieren der Karten. Luftbilder kommen von den Landesvermessungen
  (Niedersachsen, NRW).

## Lizenzen (auch bei Verkauf der App kostenlos)

| Dienst | Wofür | Lizenz / Bedingung |
|---|---|---|
| TopPlusOpen (BKG) | Topografische Karte, Wege-Ebene über Luftbildern | dl-de/by-2-0 – frei, auch kommerziell, mit Namensnennung |
| basemap.de (BKG/Länder) | Karte farbig und grau | CC BY 4.0 – frei, auch kommerziell, mit Namensnennung |
| LGLN Niedersachsen | Luftbild Niedersachsen | CC BY 4.0 – frei, auch kommerziell, mit Namensnennung |
| Geobasis NRW | Luftbild NRW | dl-de/zero-2-0 – frei, ohne Bedingungen |
| Photon (komoot) / Nominatim | Adresssuche | Daten ODbL (Namensnennung); öffentliche Server kostenlos bei fairer Nutzung, ohne Garantie. Bei vielen Nutzern eigenen Photon-Server betreiben (freie Software) |
| Overpass API | Kreuzungssuche | Daten ODbL (Namensnennung); öffentliche Server kostenlos bei fairer Nutzung (unter 10 000 Abfragen am Tag), ohne Garantie |
| Leaflet, jsPDF, pdf-lib | Programmbibliotheken | BSD-2 / MIT – frei, auch kommerziell |

Die Namensnennung steht unten rechts auf der Karte und in der Fußzeile jedes PDFs.
Bewusst **nicht** verwendet: Google Maps (Export verboten), die Kachelserver von
OpenStreetMap und OpenTopoMap (Nutzungsregeln verbieten Massenabruf, wie ihn PDF
und Garmin-Karte brauchen) und Esri (Konto bzw. Lizenz nötig).

Keine Rechtsberatung – vor einem Verkauf die Lizenztexte der Anbieter einmal selbst lesen.

## Entwicklung

```bash
npm test          # Tests: Raster, UTM (gegen pyproj-Referenzwerte), Teams, Import/Export, PDF-Planung, GPX, KMZ
./deploy.sh       # web/ nach docs/suchgebiet-karten kopieren (GitHub Pages)
```

Die Android-App (`android/`) ist eine schlanke WebView-Hülle, die direkt
`web/` als Assets einbindet und Standort, Dateiauswahl und Teilen nativ
ergänzt. Gebaut wird sie per GitHub Actions
(`.github/workflows/suchgebiet-karten-apk.yml`):

```bash
cd android && gradle assembleRelease   # braucht ein Android-SDK
```
