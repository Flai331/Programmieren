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

## Zweiter Film: „Einsatz Scheuen“ (erfundener Einsatz)

Ein kompletter, frei erfundener Einsatz von der Alarmierung (15:10) bis zum Bericht (17:40), mit
fortlaufender Einsatzuhr: Einsatzleitung am Tablet, drei Hundeführer-Handys (zwei suchen unsichtbar im
Hintergrund), Feuerwehr-Kette und Drohne per Funkmeldung, Mütze als Fund, Wärmequelle mit Prüfauftrag,
Fund durch Rex, Nachricht an alle, „Wer ist noch draußen?“, alle Wege auf einer Karte, Bericht.

```bash
REC_DIR=rec-einsatz node einsatz.js
REC_DIR=rec-einsatz BUILD_DIR=build-einsatz OUT_NAME=RHS-Einsatz-Scheuen.mp4 node compose.js
```

Die Uhrzeit der App wird dafür gestellt und zwischen den Szenen vorgespult (`advance`/`at` in `lib.js`).

### Sprecher (Erklärungen)

Die Erklärungen kommen aus `sprecher-einsatz.json` (ein Text je Szene bzw. Karte) und werden mit der freien
deutschen Stimme „Thorsten“ von Piper erzeugt. Ist ein Satz länger als die Szene, bleibt das letzte Bild
stehen; Titelkarten werden passend verlängert.

```bash
pip install piper-tts
mkdir -p tts && cd tts   # Stimme von huggingface.co/rhasspy/piper-voices (de/de_DE/thorsten/high) laden
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high/de_DE-thorsten-high.onnx
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high/de_DE-thorsten-high.onnx.json
cd ..
REC_DIR=rec-einsatz BUILD_DIR=build-einsatz OUT_NAME=RHS-Einsatz-Scheuen.mp4 NARR=sprecher-einsatz.json node compose.js
```

### Fassung mit Untertiteln und Musik (ohne Stimme)

```bash
SUBS=1 REC_DIR=rec-einsatz BUILD_DIR=build-ut OUT_NAME=RHS-Einsatz-Scheuen-Untertitel-ohne-Ton.mp4 NARR=sprecher-einsatz.json node compose.js
python3 musik.py <Ordner mit den Musikstücken>   # -> RHS-Einsatz-Scheuen-Musik-Untertitel.mp4
```

Die Sprechertexte erscheinen Satz für Satz als Untertitel (im Tempo der Sprecherfassung); dazu entsteht eine
`.srt`-Datei. Musik: drei Stücke von **John Bartmann**, auf Wikimedia Commons als **CC0** (gemeinfrei)
veröffentlicht – „above-the-clouds“ (Planung und Suche), „broken-suspense“ (Dämmerung bis zum Fund),
„10 – Heart of Acceptance“ (ab dem Fund). Download über die umgewandelten MP3-Fassungen von Commons, z. B.
`https://upload.wikimedia.org/wikipedia/commons/transcoded/<x>/<xy>/<Datei>.ogg/<Datei>.ogg.mp3`
(die Originaldateien werden bei vielen Abrufen gedrosselt).
