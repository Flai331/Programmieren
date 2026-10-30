# Suchgebiet-Karten – Fahrplan

Dieser Fahrplan wird vom stündlichen Autopiloten abgearbeitet (siehe `AUTOPILOT.md`).
Live ist **v81**. Häkchen setzt der Autopilot; Klaas kann Einträge jederzeit ergänzen,
umsortieren oder streichen.

Legende: `[ ]` offen · `[~]` gebaut, wartet auf Klaas' Test (Testversion) · `[x]` freigegeben und live

## Neue Funktionen (gehen erst nach Klaas' Test live)

- [x] **v75 – GPX/KML aus WhatsApp & Co.** „Teilen“ bzw. „Öffnen mit“ → nach Nachfrage in den laufenden Einsatz (direkt mit Klaas gebaut).

- [x] **v76 – 🐛 Fehler melden (nur Android-APK)** (direkt mit Klaas gebaut)
- [x] **v77 – Abschließen räumt auf**: nach dem Abschluss freie Karte; abgeschlossene Einsätze nur ansehen/exportieren, Ändern erst nach „Wieder öffnen“ (direkt mit Klaas gebaut).
  - Kachel „⚙️ Mehr“ → „🐛 Fehler melden“: Beschreibung eintippen, senden. Nur in der APK
    sichtbar (Web-Version bekommt keine Meldefunktion).
  - Automatische Meldung bei JavaScript-Fehlern (`window.onerror`, `unhandledrejection`) und
    bei nativen Abstürzen; gleicher Fehler höchstens alle 30 s (Fingerprint). Kurzer Hinweis
    „Fehler wurde gemeldet“, kein Dialog mitten im Einsatz.
  - Mitgeschickt: Version, Modus (EL/HF), offenes Fenster/Werkzeug, Fehlertext + Stack,
    die letzten ca. 50 Bedienschritte (Fenster geöffnet, Werkzeug gewechselt, Knopf gedrückt),
    Gerät (`Build.MODEL`), Android-Version. **Keine Einsatzdaten**: keine Namen, Personen-
    beschreibung, Kontakte, Telefonnummern, Koordinaten, Notizen, Fotos.
  - Senden nativ in Kotlin (`@JavascriptInterface`), POST an die Notion-API
    (`https://api.notion.com/v1/pages`, `Notion-Version: 2022-06-28`) in die Datenbank
    `5574dcecd7e84a0aa79446bab3915a47` (🐞 Fehlerzentrale → 🐛 Suchgebiet-Karten).
    Eigenschaften: Titel, Status=Offen, Art (Absturz/Auto-Fehler/Manuelle Meldung),
    Plattform=Android, Beschreibung, Fehler, Protokoll, Seite, Benutzerrolle (EL/HF), Gerät,
    OS, Version, Fingerprint, Zeitstempel. Texte auf 2000 Zeichen je Feld kürzen.
  - Token: `BuildConfig.NOTION_TOKEN` aus der Umgebungsvariable `NOTION_TOKEN` (GitHub-Secret,
    im Workflow schon durchgereicht). Ohne Token oder ohne Netz: Meldung in einer Warteschlange
    (SharedPreferences) speichern und beim nächsten Start erneut senden; bei manueller Meldung
    ohne Token stattdessen Mail-App mit dem Bericht an klaasotte99@gmail.com öffnen.
  - Tests: Unit-Test für das Zusammenstellen des Berichts (keine Einsatzdaten enthalten,
    Kürzung, Fingerprint); im CI-Emulator-Test darf kein Bericht ausgelöst werden.

- [x] **v80 – 📤 Weitergeben** statt Export: „Was?“ (ganzer Einsatz, Team, Gebiet, eigene Auswahl) und „Wie?“ (QR an HF oder EL/ELW, Garmin-App, Mail/BaseCamp, Speichern, PDF, Einsatz-Datei) (direkt mit Klaas gebaut).
- [ ] **Ein „📷 Scannen“-Knopf** für alles (Auftrag, Rückmeldung, Übergabe, Infos) und einheitliche Dateinamen.
- [x] **v79 – GPX-Auswahl für die Garmin-App**: einzelne Umrisse, Striche, Texte, Lage-Orte, Felder antippen; Umriss nimmt alles darin mit, „Ganzes Raster“ alles im Gebiet (direkt mit Klaas gebaut).
- [x] **v78 – Freie Karte ohne Einsatz nur ansehen** (Einzeichnen erst nach „+ Neuer Einsatz“; Suchnadel verschwindet beim Wechsel).
- [x] **v78 – 📍 Lage-Orte** (direkt mit Klaas gebaut; Details: `PLAN-einsatz-assistent.md`, Abschnitt D)
  - Werkzeug „📍 Lage-Ort“ für EL-Geräte; Kategorien 🚐 ELW, 🅱️ Bereitstellungsraum,
    🅿️ Parkplatz, 🚻 Toilette, 🍲 Verpflegung, 🚰 Ver-/Entsorgung, 🚑 Sanität,
    ❓ letzter bekannter Ort, 📌 Sonstiges.
  - Ort per GPS, Kartentipp oder Adresse; Name und Beschreibung; antippen = bearbeiten/löschen.
  - Auf der Karte, im PDF (Karte + Liste auf der Infoseite) und im GPX (Wegpunkte für BaseCamp).
  - Gehen bei der Übergabe an ein weiteres EL-Gerät (`#e=`) mit.
  - Neue Logik in `web/pois.js` mit Unit-Tests.

- [x] **v81 – 📑 Unterabschnitt an andere EL**: Gebiet/Umriss per QR an EL/ELW → Frage „ganzer Einsatz“ oder „Unterabschnitt“ (nur das Gebiet + B-Ort, Lage-Orte, Stammdaten, Protokoll; Infos fließen zum Grund-Einsatz zurück).
- [x] **v81 – 📍 Infos an EL senden** (in „📤 Weitergeben“, `#i=`, Logik in `web/infos.js`; ergänzt beim Einsatzleiter nur – löschen nur er selbst; direkt mit Klaas gebaut)
  - „📤 Infos senden“: neue/geänderte/gelöschte Lage-Orte (optional Kontakte) per QR-Code
    oder Link, mit Gerätename (`db.deviceName`) als Absender; beide Richtungen.
  - Zusammenführen ohne Duplikate (feste IDs + Änderungszeit), gelöschte verschwinden auch
    beim Empfänger, mehrfach scannen schadet nicht. Meldung z. B.
    „📥 Infos von ELW 11-1: 3 neu, 1 geändert“.
  - `#i=` in `parseShared`, Android-`sharedHash` und Tab-Übergabe (`handOff`) ist schon vorbereitet.
  - Ohne Gerätename vor dem ersten Senden danach fragen.

- [x] **v80 – Lage-Orte an Hundeführer**: im Auftrag anhakbar (alle vorausgewählt), erscheinen auf der HF-Karte (mit v80 gebaut).

## Aus „💡 Ideen & Features“ übernommen

(Der Autopilot trägt hier neue Ideen mit App = „RHS Einsatz App“ ein.)

## Fehlerbehebungen (gehen sofort live)

(Der Autopilot trägt hier behobene Meldungen aus der 🐞 Fehlerzentrale ein: Datum, Version, Kurzbeschreibung.)

## Rückfragen an Klaas

(Offene Fragen zu Ideen oder Meldungen; die Frage steht zusätzlich als Kommentar in Notion.)
