# Filament-Manager

Web-App (PWA) für Filament-Lager und 3D-Druck-Aufträge. Läuft im Browser auf PC und Handy, ist installierbar und funktioniert offline. Daten liegen lokal im Browser (IndexedDB) und werden optional über eine eigene Google-Tabelle zwischen Geräten abgeglichen (Fotos über Google Drive).

Online (nach Merge in `main`): `https://flai331.github.io/Programmieren/filament-manager/`

## Funktionen

**Filament & Lagerplatz**
- Rollen mit Marke, Material, Farbe (Farbwähler), Netto-/Leerspulengewicht, Preis, Kaufdatum
- Lagerplatz: luftdichte Boxen mit je 4 Plätzen (Anzahl einstellbar), AMS-Slots, externe Halterung, Freitext
- Neue Rollen landen automatisch auf dem ersten freien Platz; belegte Plätze werden angezeigt, Tauschen möglich
- Suche: „petg schwarz“, „bambu weiß“, „box 3“ – Grundfarben werden auch ohne Farbnamen erkannt (Umlaute egal); Farbwähler findet die ähnlichste Rolle
- „Ins AMS legen“ merkt sich den Box-Platz, „Zurück in Box …“ legt die Rolle wieder dorthin
- Boxen-Ansicht mit Belegung und Trockenmittel-Alter
- Mehrere gleiche Rollen auf einmal anlegen, Rolle duplizieren

**Restmenge aus der Druckhistorie**
- Import aus Bambu Studio: geslicte `.gcode.3mf` (Gramm pro Filament, Farbe, Material, Zeit, Vorschaubild), `.gcode` (Bambu/Orca/Prusa) oder die Bambu-Cloud-Historie als JSON
- Automatischer Rollen-Vorschlag (Material + Farbabstand + AMS-Slot), vor dem Buchen prüfbar
- Doppelte Importe werden erkannt
- Abgebrochene Drucke zählen nur anteilig („Gedruckt bis %“)
- Wiegen: Waagengewicht eingeben → ab dann wird von diesem Wert weitergerechnet
- Warnung bei wenig Rest (Schwelle einstellbar), Restlänge in Metern

**Aufträge**
- Zwei Arten: Modell aus dem Netz (Links zu MakerWorld/Printables/Thingiverse …, Lizenz-Hinweis bei NC-Modellen) oder selbst konstruieren (Maße/Beschreibung)
- Fotos direkt mit der Handykamera, weitere Dateien (STL, 3MF, PDF) anhängen
- Stückzahl, Termin (Überfällig-Warnung), Material/Farbwunsch, Preis, bezahlt
- Status: Anfrage → Angebot → Konstruktion → Druckbereit → Im Druck → Fertig → Übergeben
- Importierte Drucke einem Auftrag zuordnen → Stückzahl zählt hoch, Status springt automatisch auf „Im Druck“/„Fertig“
- Materialkosten aus den echten Rollenpreisen, Preisvorschlag aus Gramm/Stück, Stunden/Stück, Maschinenkosten und Aufschlag
- Zeigt passende Rollen mit Lagerplatz und ob sie für den Rest reichen

**Abgleich zwischen Geräten (Google-Tabelle)**
- Eigene Google-Tabelle als Server (Apps Script, `apps-script/Code.gs`, Anleitung in `apps-script/ANLEITUNG.md`)
- Rollen, Drucke, Aufträge, Boxen und Einstellungen; Fotos/Dateien im eigenen Google-Drive-Ordner
- Automatisch beim Öffnen, nach Änderungen und alle 1½ Minuten; offline weiterarbeiten
- Pro Eintrag gewinnt die neuere Änderung; geschützt durch geheimen Schlüssel
- Die Tabelle zeigt eine lesbare Übersicht (Restmenge, Lagerplatz, Auftragsstand) zum Filtern/Drucken

**Bambu-Cloud: Drucke automatisch**
- Anmeldung in der App (E-Mail + Code aus der Bambu-Mail); das Google-Script speichert nur das Token
- Alle 30 Minuten holt das Script neue, fertige Drucke (Gramm je AMS-Slot, Farbe, Material, Vorschaubild) in den „Eingang“ – ohne dass ein Gerät an sein muss
- Die App zeigt „Neue Drucke vom Drucker“ mit vorgeschlagenen Rollen (AMS-Slot) zum Bestätigen; erledigte verschwinden auf allen Geräten
- Rückfall vom Laptop: `tools/bambu_cloud_export.py --server … --key …`

**Sonstiges**
- Statistik: Lagerbestand, Restwert, Verbrauch im Monat
- Sicherung als JSON (inkl. Fotos) speichern/laden – zum Übertragen zwischen PC und Handy
- Drag & Drop von Dateien überall im Fenster

## Druckhistorie aus Bambu Studio

1. Platte slicen → **Datei → Exportieren → Geslicte Datei exportieren** (`.gcode.3mf`)
2. Datei in der App unter „Drucke“ importieren (oder ins Fenster ziehen)

Komplette Cloud-Historie (wenn über die Bambu-Cloud gedruckt wird):

```bash
python filament_manager/tools/bambu_cloud_export.py
```

Fragt E-Mail, Passwort und ggf. den E-Mail-Code ab und schreibt `bambu_history.json`. Die Bambu-Cloud-Schnittstelle ist nicht offiziell dokumentiert und konnte hier nicht gegen ein echtes Konto getestet werden.

## Entwicklung

```bash
cd filament_manager
npm test          # Logik- und Parser-Tests (Node 20+)
./deploy.sh       # kopiert web/ nach docs/filament-manager (GitHub Pages)
```

Lokal starten: `cd web && python3 -m http.server 8000` → http://localhost:8000

Struktur:
- `web/logic.js` – reine Logik: Parser (3MF slice_info, G-Code, Cloud-JSON), Restmenge, Farbabgleich, Suche, Aufträge
- `web/zip.js` – kleiner ZIP-Leser (liest nur benötigte Einträge, nie den G-Code)
- `web/importer.js` – Datei → Druck-Entwürfe
- `web/db.js` – IndexedDB (Zustand + Fotos), Sicherung
- `web/sync.js` – Abgleich mit der Google-Tabelle (in `test/sync.test.mjs` gegen den echten `Code.gs` mit nachgebauten Google-Diensten getestet)
- `apps-script/Code.gs` – Server (Google Apps Script)
- `web/app.js` – Oberfläche
- `tools/bambu_cloud_export.py` – Cloud-Historie herunterladen
