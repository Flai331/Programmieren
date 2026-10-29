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
| **Gebiete** | Name des Einsatzes, mehrere Suchgebiete speichern, wechseln, kopieren, löschen · Einsatzleitung, Notizen, B-Ort · Suchgebiet als Datei senden / Datei öffnen |
| **Raster** | Feldgröße (25 m – 1 km; bei neuer Feldgröße oder neuem Gebiet wandern Teams und Status auf die neuen Felder mit – kleinere Felder erben die Markierung des großen Feldes, ein größeres Feld behält sie, sobald ein Teil markiert war), Suchgebiet aufziehen oder Ausschnitt nehmen, Feld suchen („C4“), **Auf der Karte zeigen**: Raster, Randbeschriftung, B-Ort, jedes Team, jede Markierung, jede Zeichnung, jeder Umriss und Text einzeln ausblendbar; „Alles ausblenden“ / „Alles einblenden“ (nur Anzeige), **UTM-Schalter** |
| **Teams** | Teams (Name, Hund, Farbe) und Status („abgesucht“, „nicht begehbar“ …) anlegen. Ein Feld behält sein Team; der Status liegt zusätzlich schraffiert darüber |
| **Karte** | TopPlusOpen (topografisch, mit Waldwegen), basemap.de farbig/grau, Luftbild Niedersachsen (LGLN), Luftbild NRW – über Luftbildern zuschaltbar: Wege, Straßen, Ortsnamen |
| **GPS** | Eigener Standort, oben steht das aktuelle Feld (mit UTM-Schalter auch UTMREF) |
| **Export** | PDF, GPX für Garmin/BaseCamp, Garmin-Karte (KMZ) – jeweils **📤 Teilen** (WhatsApp, Mail, Signal …) oder **💾 Speichern** |
| **Mehrere Rastergebiete** | Raster → „+ Weiteres Rastergebiet“ und Fläche aufziehen. Jedes Gebiet hat eigenen Namen (✏️, z. B. „Nord“), eigene Feldgröße und eigene Felder ab A1; der Name steht auf der Karte über dem Gebiet. In der Liste antippen = bearbeiten und hinzoomen; mit dem Feld-Werkzeug einfach im anderen Gebiet tippen. Im Export-Fenster ankreuzen, welche Gebiete ins PDF (je Gebiet eigene Blätter), GPX (ein Raster-Track je Gebiet, Team-Tracks mit Gebietsnamen) und in die Garmin-Karte kommen |
| **Notizen** (📝, Seitenleiste) | Schnellzugriff: getippte Notizen, Notizblock (Handschrift), Foto vom Papier (direkt mit der Kamera aufnehmen oder ein Bild wählen) und die Vorschaubilder – dieselben Daten wie im Einsatz-Fenster |
| **Notizblock klein** (Tablet/PC) | Im Notizblock „🗗 Klein“: Handschrift als Bild-in-Bild-Fenster neben der Karte, an der oberen Leiste verschiebbar (am PC an der Ecke auch größer ziehbar); „⛶ Groß“ zurück. Auf kleinen Handys immer ganzseitig |
| **Kontakte** (Adressbuch) | Für alle Einsätze gemeinsam: Name, Funktion, Organisation, Funkrufname, zwei Nummern, E-Mail, Notiz; Suche über alles; Nummer/Adresse antippen ruft an bzw. schreibt Mail. Import von Handy-Kontakten (vCard .vcf, auch ältere Android-Exporte) oder JSON ohne Doppelte; „Teilen“/„Speichern“ als vCard (z. B. per WhatsApp an andere Handys). Beim E-Mail-Versand im Einsatz-Fenster Empfänger per 📇 aus den Kontakten wählen |
| **Hundeführer per QR-Code** (ohne App) | Eine App, zwei Modi: Einsatzleitung (alles) und Hundeführer (stark vereinfacht: Auftrag oben, große Knöpfe ⏺ Weg aufzeichnen · 📍 Markieren (Anzeige, Fund, Spur, Gegenstand, Gefahr, Hinweis) · ✅ Feld abgesucht/teilweise/nicht begehbar · 🧭 Wind · 📤 Zurückgeben; Menü mit Rettungspunkt, B-Ort, Notizen; Knopf „Karte“ zum Wechseln der Kartenart und Wege-Ebene). Wechsel zur Einsatzleitung nur mit der festen PIN der Einsatzleitung (eine für alle Geräte, nicht änderbar). **Auftrag** (Teams → „📲 Auftrag an Hundeführer“, auch ohne Raster nur mit Umrissen): Team, Rastergebiete, Felder (des Teams / ganzes Gebiet mit anderen Teams grau / auf der Karte antippen), Umrisse und Zeichnungen, B-Ort, Forst-Rettungspunkte im Umkreis von 2 km um die Mitte jedes übertragenen Rastergebiets bzw. Umrisses (höchstens 80, nächste zuerst), Hinweis, vermisste Person nur auf Wunsch – als QR-Code oder Link (WhatsApp/SMS); Größe wird angezeigt. Der Inhalt steckt komprimiert im Link, kein Server. **Rückmeldung** (Weg, Markierungen, Feldstatus) als QR-Code/Link zurück; die Einsatzleitung scannt mit der Kamera oder fügt den Link ein – Zuordnung zum Team automatisch, doppelt Übernehmen schadet nicht |
| **Wetter & Wind** (🌬️ links, zuschaltbar) | DWD-Daten über Bright Sky (frei, ohne Anmeldung) für die Mitte des Suchgebiets: Wind aus Richtung/Grad, km/h, Böen, Beaufort, Station mit Entfernung und Uhrzeit, Temperatur, Regen, Vorhersage der nächsten Stunden, Sonnenuntergang mit Restzeit; alle 15 Min. neu, offline letzter Stand. Ansatz-Hinweis gegen den Wind (Startseite). **➚ Wind** (links, ein/aus): Windpfeile auf der Karte. **Einsatzleitung:** blauer DWD-Pfeil in der Mitte jedes Rasters und jedes Umrisses (mit Name), dazu im Vergleich grün die Messpunkte der Teams aus den Rückmeldungen. **Hundeführer:** blau mit Quadrat = DWD-Messstationen im Umkreis von 40 km (je aktueller Wind), blau mit Kreis = DWD am Windpunkt bzw. über dem Suchgebiet, grün = selbst gemessener Wind an der Messstelle (auch von Hundeführern mit der Rückmeldung übertragen, mit Uhrzeit und Team; älter als 2 Std. blass). **Windpunkt** (Einsatzleitung): „📍 Windpunkt setzen“ und auf die Karte tippen – dort zeigt ein großer Pfeil, wohin der Wind laut DWD weht (Länge je nach Stärke), mit Richtung/km/h/Böen; Wetter wird für diesen Punkt geladen. Beim Hundeführer steht der Pfeil über dem erhaltenen Suchgebiet. Das Wetter-Fenster zeigt in beiden Modi immer den DWD-Wind; eine Messung vor Ort steht darunter (ohne DWD-Daten ersatzweise oben). **🧭 Wind messen** (nur Hundeführer-Modus): Handy flach in Flugrichtung des Puders halten, der Kompass liefert die Richtung (ohne Kompass: 8 Richtungen antippen), dann nur leicht/mittel/stark wählen. Windprotokoll mit Uhrzeit (gemessen + deutliche DWD-Änderungen) steht im Bericht und in der Mail |
| **Karte bewegen in allen Werkzeugen** | Ein Finger zeichnet/markiert, zwei Finger verschieben und zoomen die Karte (ein angefangener Strich bzw. ein angefangenes Feld wird dabei verworfen). Bei Umriss und Text verschiebt auch ein Finger (Antippen setzt Punkt/Text). Am PC: rechte Maustaste verschiebt, Mausrad zoomt |
| **Rettungspunkte** (Karte-Fenster) | Forst-Rettungspunkte einmal als GPX/KML/CSV importieren (KWF/Landesforsten; CSV mit Breite/Länge oder UTM, Dezimalkomma), offline in IndexedDB für alle Einsätze; grünes Schild mit Nummer ab Zoomstufe 11, auch im PDF; Antippen zeigt Nummer und Koordinaten; „🚑 RP“ links: nächster Rettungspunkt vom GPS-Standort (sonst Kartenmitte) mit Entfernung, Richtung, Koordinaten und MGRS zum Durchgeben |
| **Nachtmodus** (🌙 links) | aus → dunkel (Bedienung dunkel, Karte abgedunkelt) → rot (schont die Nachtsicht) |
| **Offline-Karten** (eigener Knopf „Offline“) | Vorab herunterladen: Kartenart (Luftbild mit/ohne Wege-Ebene, Topo, basemap) und Zoomstufen von–bis frei wählbar (Vorgabe: ganzes Land 12–15, Quadrate 15–18; Stufe steht am Zoom-Regler, „👁 ansehen“ zeigt sie vorab). Bereich: ganz Niedersachsen / NRW, Quadrate (ca. 5,5 × 5,5 km) auf der Karte antippen (gespeicherte grün), Suchgebiet, Ausschnitt oder Rechteck. Größe je Stufe, Schätzung von Anzahl, Größe, Dauer und freiem Speicher vorab. Gespeicherte Kartenbilder werden immer zuerst genommen (Anzeige, PDF, Garmin-Karte) – sofort, ohne Netz; Fehlendes kommt aus dem Internet. Download anhalten/fortsetzen oder abbrechen (✕, auf Wunsch samt bereits Geladenem löschen – auch über „Abbrechen“ in der Android-Benachrichtigung), Bereiche löschen. Im Browser im Cache-Speicher. **Android-App:** eigener Hintergrund-Dienst lädt weiter bei ausgeschaltetem Bildschirm oder geschlossener App (Fortschritt und „Anhalten“ in der Benachrichtigung), optional nur über WLAN, wartet bei Netzausfall statt abzubrechen; speichert als Dateien im App-Ordner mit dem meisten Platz (SD-Karte, falls vorhanden) ohne Browser-Speichergrenze und liefert die Bilder beim Anzeigen direkt aus |
| **Leiste links** | „#“ Raster und „▦“ Felder (Teams und Markierungen) mit einem Tipp aus-/einblenden, darunter die **Zoomleiste** (ziehen, tippen oder +/−) |
| Stift / Text / Feld / Umriss / Radierer (nochmal antippen = zurück zu „Bewegen“) | Freihand zeichnen, Punkt mit Text, Felder einem Team zuteilen (antippen oder drüberwischen), Gebiet Punkt für Punkt umranden (im GPX ein Track; Namensvorschlag: Himmelsrichtung vom B-Ort und fortlaufende Nummer, z. B. „Nord 1“, „Nordwest 2“, „Nord 3“), löschen |
| **Einsatz** (📋) | Einsatzprotokoll mit Eckdaten, kein ETB. Reiter **Lage**: vermisste Person, **Zeiten** (Alarmierung mit Datum, Abfahrt, Eintreffen, Einsatzbeginn, Einsatzende, Rückkehr – „Jetzt“ oder von Hand), Kräfte je Organisation (Stärke als Zahlen: Führung/Helfer//Gesamt + Hunde), Notizen getippt, **Notizblock** für Handschrift mit Stift oder Finger (Seiten, 3 Farben, Rückgängig), **Fotos** vom Papier (Kamera oder Galerie). Reiter **Einsatzende**: Notizen und Fotos links ansehen (zoombar; gezoomt mit Finger oder Maus frei verschieben, Doppelklick/-tippen zoomt), rechts zusammenfassen; Legende für die Stiftfarben auf der Karte; Verfasser; E-Mail-Empfänger. **Abschlussbericht** (PDF, ohne Karte) mit Bericht, Notizseiten und Fotos; Versand siehe unten. Im Browser hängt das Teilen-Menü die Dateien an, die Empfänger werden in die Zwischenablage kopiert |
| **Einsatzende – Versand** | Je Empfänger-Zeile ankreuzen, was mitgeht. **Abschlussbericht**: Zeiten, Vermisste Person, Kräfte, Zusammenfassung, Notizen, Notizblock, Fotos, Karte (ohne Raster, Flächen beschriftet, automatisch so gezoomt, dass alle Markierungen, Zeichnungen, Umrisse, Texte und der B-Ort samt Beschriftung drauf sind; voreingestellt aus) – dazu je Empfänger, ob die Karte Teams und/oder Status (abgesucht, teilweise, nicht begehbar) zeigt. **Zusätzlich:** JUH-Formular, GPX. „Senden“ öffnet das Mailprogramm mit genau diesen Anhängen, auch der Mailtext enthält nur die angekreuzten Inhalte (Android-App: inkl. Empfänger) |
| **JUH-Formular** | Vorlage „Einsatzbericht Rettungshundestaffel“ wird mit den vorhandenen Daten vorausgefüllt (Kräfte eigene/fremde, Lage, Verlauf, Besonderheiten, Einsatzleitung …); alle Felder bleiben im PDF ausfüllbar. Bei den Kräften „eigene“ anhaken |
| Stift und Umriss offen lassen | Eine Stift-Zeichnung besteht aus allen Strichen bis „Fertig“ (Leiste: „↶ Strich“, „Fertig“ mit Name, „Abbrechen“). Zwischendurch auf „Bewegen“ und zurück – Zeichnung bzw. Umriss bleiben offen, auch nach Neustart der App. Im GPX ist jeder Strich ein Track („Name“, „Name (Teil 2)“ …) |
| Zeichnung benennen | Beim Stift „Fertig“ (fragt den Namen) oder später eine Zeichnung (auch einen Umriss) im Stift-Werkzeug antippen. Der Name steht auf der Karte, im PDF und als Trackname im GPX |

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
UTM/UTMREF für B-Ort und A1 im PDF. Ohne Schalter bleibt alles bei A1-Feldern.

### PDF

- **Übersicht:** ganzes Raster, Umrisse der Detailblätter mit Seitenzahl
- **Einsatzinformationen:** Einsatzleitung, B-Ort mit Koordinaten,
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
   B-Ort und Textpunkte

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
