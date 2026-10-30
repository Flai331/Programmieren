# Plan: 📣 Status-Meldungen über Google Sheets (v89)

Ziel: Hundeführer (HF) schicken bei Internet **Status** und **wichtige Standorte** an die
Einsatzleitung (EL). Keine Live-Verfolgung. Übertragung verschlüsselt über eine Google-Tabelle
(Apps-Script-Web-App). Ohne Netz: Warteschlange, automatisches Nachsenden. Die bisherige
QR-Rückmeldung (`#r`) bleibt unverändert als Rückfallweg.

## 1. Server: Google Apps Script (`apps-script/Code.gs` + `apps-script/ANLEITUNG.md`)

- Tabellenblatt `Meldungen`, Spalten: `Serverzeit | Raum | MeldungsID | Daten`.
- `doPost(e)`: Body ist JSON-Text `{ r, id, d }` (`r` = Raum-Kennung, `id` = Meldungs-ID,
  `d` = verschlüsselte Daten, base64url). Prüfen: `r` 8–64 Zeichen `[A-Za-z0-9_-]`, `id` ≤ 40,
  `d` ≤ 20 000 Zeichen. Doppelte `id` im selben Raum nicht erneut anhängen (`LockService`).
  Antwort JSON `{ ok: true }`.
- `doGet(e)`: `?r=<raum>&since=<serverzeit ms>` → JSON `{ ok, now, rows: [[serverzeit, id, d], …] }`
  nur für diesen Raum und neuer als `since`.
- Zeitgesteuerter Trigger `cleanup()` täglich: Zeilen älter als 7 Tage löschen
  (Funktion `setup()` legt Blatt und Trigger einmalig an).
- Anleitung für Klaas (Deutsch, Schritt für Schritt, Handy-/PC-tauglich): Tabelle anlegen →
  Erweiterungen → Apps Script → Code einfügen → `setup` einmal ausführen → Bereitstellen →
  Web-App, „Ausführen als: Ich“, „Zugriff: Jeder“ → URL kopieren und in der App eintragen.

## 2. Verschlüsselung und Format (`web/status.js`, reine Logik, mit Unit-Tests)

- Pro Einsatz (EL-Projekt) einmalig: `P.live = { url, key }`. `key` = 16 Zufallsbytes base64url.
- Raum-Kennung: `room = base64url(SHA-256("sgk-room|" + key))[0..22]` – der Server sieht den
  Schlüssel nie.
- Verschlüsselung: WebCrypto AES-GCM 128, IV 12 Byte zufällig, `d = base64url(iv + ciphertext)`.
  Klartext = JSON der Meldung.
- Meldung (Klartext):
  ```
  { v:1, id, a: <Auftrags-ID>, tm: <Teamname>, t: <Zeit ms>, s: <Status-Code>,
    lat?, lon?, acc?, txt?, pc?: <Prozent HF>, pa?: <Prozent App>, cat?: <Standort-Art> }
  ```
- Status-Codes (`STATUS_LIST`, Reihenfolge = Tasten):
  `anfahrt` 🚗 Anfahrt · `start` ▶️ Suche begonnen · `pause` ⏸ Pause · `fertig` ✅ Gebiet fertig ·
  `zurueck` 🏁 Zurück am B-Ort · `anzeige` 🐕 Hund zeigt an · `fund` 🟢 Person gefunden ·
  `hilfe` 🆘 Brauche Hilfe.
- Standort-Arten (`SPOT_LIST`): `anzeige` 🐕 Anzeige · `fund` 🟢 Fund · `hinweis` 👕 Hinweis ·
  `gefahr` ⚠️ Gefahr · `sonst` 📌 Sonstiges. Als Meldung mit `s:'ort'` und `cat`.
- Dringend (`URGENT`): `fund`, `hilfe` (auch Standort-Art `fund`).
- Funktionen: `newLiveKey()`, `roomOf(key)`, `encryptMsg(key, obj)`, `decryptMsg(key, d)`,
  `statusLabel(code)`, `mergeStatus(list, msgs)` (dedupliziert nach `id`, sortiert nach `t`).
- Prozent: `coveragePct(track, grids/area-Polygone, radiusM)` → 0–100, gerundet auf 5.
  Umsetzung über ein Raster mit 5 m Schritt: Anteil der Gebiets-Punkte, die ≤ `radiusM` vom
  Laufweg entfernt sind (Gebiet = vom HF zugeteilte Felder, sonst ganze Rasterflächen/Umrisse des
  Auftrags). Rechenaufwand begrenzen (max. ~200 000 Prüfpunkte, sonst Schritt vergrößern).
  Zusätzlich `coverageGaps(...)` → Liste nicht abgedeckter Zellen (für die Lücken-Ansicht).

## 3. Auftrag trägt die Verbindung

- Einstellungen „⚙️ Mehr → Dieses Gerät“: Feld **„📣 Status-Server (Web-App-Adresse)“**
  (`db.statusUrl`, nur auf EL-Geräten nötig). Ohne Adresse ist alles Live-bezogene ausgeblendet.
- `buildAssignment`: wenn `db.statusUrl` gesetzt → `P.live` anlegen falls fehlt,
  `out.ls = [url, key]`. `projectFromAssignment`: `p.hf.ls = a.ls`.
- Bei Übergabe an weiteres EL-Gerät (`#e`) `live` mitgeben, damit beide dieselben Meldungen sehen.

## 4. Hundeführer-Seite

- Neuer großer Knopf **„📣 Status“** im HF-Menü/HF-Leiste (nur wenn `P.hf.ls` vorhanden).
  Dialog mit den 8 Status-Tasten und darunter „📍 Standort melden“.
- **Standort bei jeder Meldung**: aktueller GPS-Punkt (`getCurrentPosition`, bis 10 s auf
  Genauigkeit ≤ 30 m warten, sonst besten Wert nehmen und `acc` mitsenden; ohne GPS ohne
  Standort). Standort wird im Moment der Meldung festgehalten.
- „📍 Standort melden“: Art wählen → „📍 Hier“ oder „Auf Karte tippen“ → kurzer Text (optional).
- **„✅ Gebiet fertig“**: Regler 0–100 % in 10er-Schritten, Startwert = `coveragePct` aus dem
  eigenen Laufweg (Reichweite 20/30/50 m wählbar, Standard 30, gemerkt in `db.coverR`),
  optional Grund-Text. Gesendet werden `pc` und `pa`.
- 🆘 und 🟢 fragen kurz „Wirklich senden?“ und senden immer mit Standort.
- Warteschlange `P.hf.outbox` (im Projekt gespeichert): sofort senden versuchen; bei Fehler
  bleibt sie; erneut versuchen bei `online`-Ereignis, alle 60 s und beim App-Start.
- Anzeige im Knopf/Dialog: „✓ gesendet 14:32“ bzw. „⏳ wartet auf Netz (2)“.
- Eigene Meldungen erscheinen auch auf der HF-Karte als kleine Symbole.

## 5. Einsatzleitung

- Solange ein offener EL-Einsatz `P.live` hat und gesendete Aufträge mit Live existieren:
  alle 30 s `GET ?r=room&since=` (nur wenn `navigator.onLine` und Seite sichtbar).
  `since` und empfangene Meldungen in `P.live.since`, `P.status = [...]` speichern.
- **Karte**: jede Meldung mit Standort als Symbol (Emoji der Meldung, Rand in Teamfarbe)
  im Canvas-Overlay bzw. als Leaflet-Marker; antippen → Team, Status, Uhrzeit, ± Genauigkeit,
  Text, Prozent. Ältere Status-Punkte desselben Teams kleiner/blasser, neuester groß.
  Schalter in der Ebenen-/Karten-Ansicht „📣 Meldungen anzeigen“.
- **Auftrags-Übersicht** (`renderSentList`): Zeile „📣 ⏸ Pause · 14:50 · 📍“ (letzter Status);
  bei `fertig`: „HF: 70 % · App: 65 %“. Tipp → Karte springt zum Punkt.
  `last`-Zeit der Karte zählt auch Status-Meldungen (für „nachfragen?“).
- **Dringend** (Fund/Hilfe): Ton (WebAudio-Piepen), Vibration, Hinweis-Dialog der stehen bleibt
  bis „Gesehen“; gesehene IDs in `P.live.ack`.
- **Lücken**: in der Auftrags-Karte Knopf „Lücken zeigen“ – nur möglich, wenn eine QR-Rückmeldung
  mit Weg vorliegt (Status-Meldungen tragen keinen Weg); schraffiert nicht abgedeckte Zellen.

## 6. Technik / Randbedingungen

- Fetch an `script.google.com`: POST mit `Content-Type: text/plain;charset=utf-8` (kein
  CORS-Preflight), `redirect: 'follow'`. GET normal. Service Worker darf fremde Origins nicht
  abfangen bzw. nicht cachen (prüfen in `sw.js`).
- Funktioniert in der Android-App (WebViewAssetLoader-Origin) und im Browser (github.io).
- Keine Einsatzdaten der vermissten Person, keine Kontakte in Meldungen.
- `APP_VERSION`/`sw.js VERSION` → v89, neue Dateien in `APP_FILES` aufnehmen.

## 7. Tests

- `test/status.test.mjs`: Ver-/Entschlüsseln rund (Node hat `crypto.webcrypto`), falscher
  Schlüssel scheitert, Raum-Kennung stabil und ohne Schlüssel, `mergeStatus` dedupliziert,
  `coveragePct` (gerader Weg durch Rechteck ≈ erwarteter Anteil; leerer Weg = 0; voller = 100),
  `buildAssignment` mit/ohne `ls`.
- Playwright: Fake-Server per `page.route('**/script.google.com/**')` (In-Memory doPost/doGet):
  EL trägt URL ein, sendet Auftrag, HF übernimmt, meldet „▶️ Suche begonnen“ und „Anzeige“,
  EL-Seite holt ab → Symbol auf Karte, Zeile in Übersicht; Offline → Warteschlange → online → gesendet;
  Fund → Dringend-Dialog.
- Alle bisherigen Tests (`node --test test/*.mjs`) müssen grün bleiben.
