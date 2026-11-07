# Vorstellungsfilm „RHS Einsatz“

Animierter Film (ca. 4 min, 1920×1080, ohne Ton), der die Grundfunktionen der App zeigt.
Er wird **automatisch aus der echten App** aufgenommen: Ein Skript bedient die Web-App
(Einsatzleitung am Tablet, Hundeführerin am Handy), ein eingeblendeter „Finger“ zeigt jeden Tipp,
danach kommen Titelkarten, Untertitel und Geräterahmen dazu.

| Kapitel | Inhalt |
|---|---|
| 1 Einsatz anlegen | Assistent, B-Ort per Adresssuche, DWD-Wetter, vermisste Person |
| 2 Raster, Teams, Suchgebiete | Raster aufziehen, Teams, Felder wischen, Umriss |
| 3 Auftrag per QR-Code | Auftrag zusammenstellen, QR-Code |
| 4 Hundeführer im Gelände | Auftrag am Handy, Status, Weg aufzeichnen, Markieren |
| 5 Live bei der Einsatzleitung | Team-Chips, Fund-Alarm (Tablet und Handy nebeneinander) |
| 6 Rückmeldung & Überblick | Rückmelde-QR, Weg/Markierungen auf der EL-Karte, Status-Verlauf |
| 7 Wetter, Wind & Nacht | Wetterfenster, Windpfeile, Nachtmodus |
| 8 Bericht & Export | Teilen „An wen?“, Karten-PDF, Abschlussbericht, JUH-Formular |

## Neu erzeugen

Voraussetzungen: Node mit Playwright/Chromium, `ffmpeg`, `pdftoppm`, Internet für Kartenbilder
(sgx.geodatenzentrum.de), Ortssuche (photon.komoot.io) und Wetter (api.brightsky.dev).

```bash
cd suchgebiet_karten/web && python3 -m http.server 8765 &   # App ausliefern
cd ../film
node film.js        # Aufnahme (ca. 8 min) -> rec/
node compose.js     # Schnitt (ca. 6 min)  -> RHS-Einsatz-Film.mp4
```

- `film.js` – Drehbuch (Szenen, Untertitel, Tempo je Abschnitt über `speed`)
- `lib.js` – Aufnahme: Finger-Einblendung, Screencast, nachgebildeter Status-Server
  (die Live-Meldungen laufen im Film lokal, nichts geht an den echten Server)
- `compose.js` – Titelkarten, Layouts (Tablet / Handy / beides), ffmpeg-Zusammenbau
- `SHOTS=1 node film.js` legt zusätzlich Kontrollbilder `chk_*.png` ab, `STOP=3` hält nach Kapitel 3 an.

Einsatz, Teams und vermisste Person im Film sind erfunden (Ort: Waldgebiet bei Celle-Scheuen).
