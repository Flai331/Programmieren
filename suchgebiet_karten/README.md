# Suchgebiet-Karten

Web-App (auch als App auf Android installierbar) für Rettungshundestaffeln:
Online-Karte wählen, ein festes Raster über das Suchgebiet legen, einzeichnen,
als PDF ausgeben und direkt per E-Mail/Messenger verschicken.

**App öffnen:** https://flai331.github.io/Programmieren/suchgebiet-karten/

## Auf Android installieren

**Variante A – APK (eigene App):**
[Suchgebiet-Karten.apk](https://github.com/Flai331/Programmieren/releases/download/suchgebiet-karten/Suchgebiet-Karten.apk)
herunterladen, Installation aus unbekannten Quellen erlauben, installieren.
Neue Versionen lassen sich einfach drüber installieren.

**Variante B – Web-App:** Link oben in **Chrome** öffnen → Menü ⋮ →
**„Zum Startbildschirm hinzufügen“**. Updates kommen automatisch.

Beide Varianten speichern getrennt – ein Suchgebiet lässt sich per Datei
von der einen in die andere übernehmen.

## Bedienung

| Knopf | Funktion |
|---|---|
| **🔍 (oben)** | Adresse, Ort, Straße suchen (OpenStreetMap), außerdem Feldnamen („C4“) und Koordinaten („50.12, 8.61“) |
| **Gebiete** | Mehrere Suchgebiete speichern, wechseln, kopieren, löschen · Einsatzleitung, Notizen, Treffpunkt · Suchgebiet als Datei senden / Datei öffnen |
| **Raster** | Feldgröße (25 m – 1 km), Suchgebiet aufziehen oder Ausschnitt nehmen, Feld suchen („C4“), **UTM-Schalter** |
| **Teams** | Teams (Name, Hund, Farbe) und Markierungen („abgesucht“, „nicht begehbar“ …) anlegen |
| **Karte** | OpenStreetMap, OpenTopoMap, basemap.de, Luftbild Niedersachsen (LGLN), Luftbild NRW (Geobasis NRW), Luftbild Esri |
| **GPS** | Eigener Standort, oben steht das aktuelle Feld (mit UTM-Schalter auch UTMREF) |
| **Export** | PDF, GPX für Garmin/BaseCamp, Garmin-Karte (KMZ) – jeweils **📤 Teilen** (WhatsApp, Mail, Signal …) oder **💾 Speichern** |
| Stift / Text / Feld / Track / Radierer | Freihand zeichnen, Punkt mit Text, Felder einem Team zuteilen (antippen oder drüberwischen), Track Punkt für Punkt setzen, löschen |

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

**Track zeichnen:** Werkzeug „Track“ → Punkte auf die Karte tippen (Ziehen verschiebt die Karte) →
„Fertig“ → Namen eingeben. Länge wird angezeigt; Tracks erscheinen auch im PDF.

**GPX (Export → Garmin: GPX):** Tracks, Team-Bereiche als farbige Umrisse, Raster-Linien,
Treffpunkt/Textpunkte und optional Feldnamen als Wegpunkte. In BaseCamp über *Datei → Importieren*
öffnen und an das Gerät senden. GPX-Linien liegen **über deiner Karte auf dem Gerät** (z. B. der Wanderkarte).

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
  Abfotografieren/Exportieren der Karten. Luftbilder kommen stattdessen von Esri.

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
