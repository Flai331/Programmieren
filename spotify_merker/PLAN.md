# Spotify-Merker – Plan

Ziel: Eine Web-App (PWA), die mitschreibt, was man auf Spotify hört (Lieder,
Hörbuch-Kapitel, Podcast-Folgen) inklusive Minutenstand. Später kann man im
Verlauf nachsehen und mit einem Tipp genau dort in Spotify weiterhören.
Hauptfall: Hörbuch läuft → man hört zwischendurch Musik → „Zurück zum Hörbuch“
springt ins richtige Kapitel an die richtige Minute.

## Architektur

- Reines HTML/CSS/JS (ES-Module), **kein Build, kein Framework, kein eigener Server**.
- Keine externen Ressourcen (keine Google Fonts, kein CDN) – nur Systemschriften.
- Spotify Web API direkt aus dem Browser mit **Authorization Code + PKCE**
  (keine Client-Secret nötig). Die Client-ID gibt der Nutzer in den
  Einstellungen ein (eigene App im Spotify Developer Dashboard).
- Daten liegen in `localStorage` (pro Gerät). Export/Import als JSON.
- Quellcode: `spotify_merker/web/`. Veröffentlichung: `spotify_merker/deploy.sh`
  kopiert `web/` nach `docs/spotify-merker/` (GitHub Pages, wie `docs/rettungshunde`).
- Tests: `spotify_merker/test/logic.test.mjs` mit `node --test` für `web/logic.js`.

## Dateien

| Datei | Inhalt |
|---|---|
| `web/logic.js` | **Fertig.** Reine Funktionen: `normalizePlayback`, `recordSample`, `mergeRecentlyPlayed`, `findResumeCandidate`, `buildPlayBody`, `computeBookResume`, `filterHistory`, `formatMs`, `uriType`, `uriId`. Nicht umschreiben, nur nutzen (kleine Bugfixes erlaubt, dann Test ergänzen). |
| `web/auth.js` | PKCE-Login, Token-Speicherung, Refresh. |
| `web/api.js` | Dünner Spotify-API-Wrapper mit automatischem Token-Refresh, 401-Retry, 429 (Retry-After) Behandlung. |
| `web/app.js` | UI, Polling, Speicherung, Weiterhören. |
| `web/index.html` | Gerüst, Tabs. |
| `web/style.css` | Styling, hell/dunkel über `prefers-color-scheme`, mobil zuerst. |
| `web/manifest.json`, `web/icon.svg`, `web/sw.js` | PWA (installierbar, App-Shell offline-cachen; API-Aufrufe nie cachen). |
| `test/logic.test.mjs` | Unit-Tests für logic.js. |
| `deploy.sh` | `rm -rf docs/spotify-merker && cp -r web docs/spotify-merker` (Pfade relativ zum Skript). |
| `README.md` | Einrichtung auf Deutsch (Spotify-App anlegen, Redirect-URI, Client-ID, Premium-Hinweis, Grenzen). |

## Auth (auth.js)

- Scopes: `user-read-currently-playing user-read-playback-state user-modify-playback-state user-read-recently-played user-read-playback-position user-library-read`.
- Redirect-URI = `location.origin + location.pathname` (ohne Query/Hash). In den
  Einstellungen anzeigen mit „Kopieren“-Button, damit man sie im Dashboard einträgt.
- Ablauf: `code_verifier` (64 Zeichen zufällig) + SHA-256 `code_challenge`
  (base64url) → Weiterleitung zu `https://accounts.spotify.com/authorize`.
  Nach Rückkehr `?code=` gegen Token tauschen (`POST https://accounts.spotify.com/api/token`,
  `grant_type=authorization_code`), danach Query mit `history.replaceState` entfernen.
  `state` prüfen.
- Speichern: `sm.clientId`, `sm.token` = `{access_token, refresh_token, expires_at}`.
- `getAccessToken()`: 60 s vor Ablauf per `grant_type=refresh_token` erneuern
  (neuen refresh_token übernehmen, falls geliefert). Gleichzeitige Refreshes
  zusammenfassen (ein Promise).
- `logout()` löscht Token (Verlauf bleibt).

## API (api.js)

- `api(path, {method, body})` → JSON oder `null` bei 204. Basis `https://api.spotify.com/v1`.
- 401 → einmal Refresh + Wiederholung. 429 → `Retry-After` abwarten, einmal wiederholen.
- Fehler als `Error` mit `.status` und `.reason` (aus `error.reason`, z. B. `NO_ACTIVE_DEVICE`, `PREMIUM_REQUIRED`).
- Genutzte Endpunkte:
  - `GET /me/player?additional_types=track,episode` (Polling; 204 = nichts läuft)
  - `GET /me/player/recently-played?limit=50`
  - `GET /me/player/devices`
  - `PUT /me/player/play?device_id=…` mit Body aus `buildPlayBody`
  - `GET /me/audiobooks?limit=50`
  - `GET /audiobooks/{id}/chapters?limit=50&offset=…&market=from_token` (seitenweise bis alle da)

## Überwachung (app.js)

- Polling nur wenn eingeloggt: alle **5 s** bei sichtbarer Seite, alle **30 s** wenn verborgen
  (Browser drosseln sowieso). Kein Overlap (nächster Tick erst nach Ende des vorigen).
- Jede Messung: `normalizePlayback` → `recordSample(history, sample, Date.now())` → speichern
  (`sm.history`) → UI aktualisieren.
- Beim Start + beim Zurückkehren in die App (`visibilitychange`): zusätzlich
  `recently-played` holen und mit `mergeRecentlyPlayed` einarbeiten (füllt Lücken bei Musik).
- **Grenze (im README + in der App erklären):** Minutenstände für Musik werden nur
  erfasst, solange die App offen ist. Für Hörbücher/Podcasts merkt sich Spotify
  selbst die Position – die holt der Tab „Hörbücher“.

## Oberfläche

Kopfzeile: Name „Spotify-Merker“, Status (verbunden / nicht verbunden).

1. **„Jetzt“-Karte**: aktuelles Stück (Cover, Titel, Untertitel, Art: Musik/Hörbuch/Podcast,
   Fortschritt `formatMs(progress) / formatMs(duration)` + Balken, läuft lokal
   zwischen den Polls weiter). Button „📌 Merken“ → pinnt den aktuellen Verlaufseintrag.
2. **„Zurück zu …“-Banner** (wichtigster Teil): `findResumeCandidate(history, current)`.
   Zeigt Hörbuch/Podcast-Titel, Kapitel, Minute, „vor X Minuten“. Buttons
   „▶ Weiterhören“ und „In Spotify öffnen“.
3. **Tabs**:
   - **Verlauf**: Filter-Chips Zeitraum (Letzte Stunde, Heute, Gestern, 7 Tage, Alle),
     Art (Alle, Hörbücher/Podcasts, Musik, Gemerkt), Suchfeld, und
     „Was lief um …?“ (`<input type="datetime-local">` → `around`, ±30 min, mit X zum Löschen).
     Liste gruppiert nach Tag („Heute“, „Gestern“, Datum). Jeder Eintrag: Cover,
     Titel, Untertitel, Uhrzeit (Start–Ende), Minutenstand beim letzten Stand
     (bei `source==='recent'` stattdessen „vollständig/ohne Minute“), Buttons
     ▶ (weiterhören an gespeicherter Minute), ↗ (in Spotify öffnen), 📌 (pin umschalten),
     🗑 (löschen, mit Bestätigung).
   - **Hörbücher**: gespeicherte Hörbücher (`/me/audiobooks`). Pro Buch Button
     „Stand laden“ (bzw. automatisch nacheinander, max. 1 Anfrage gleichzeitig):
     Kapitel holen, `computeBookResume` → „Kapitel N: Name – bei 12:34“ + ▶ Weiterhören
     (`buildPlayBody({uri: chapter.uri, bookUri: book.uri}, positionMs)`). Fertig gehörte
     Bücher als „✓ Fertig“.
   - **Einstellungen**: Client-ID-Feld, Redirect-URI + Kopieren, Anmelden/Abmelden,
     Kurzanleitung, Export (Download `spotify-merker-verlauf.json`), Import (Datei,
     mit vorhandenem Verlauf zusammenführen über `id`, sortieren), Verlauf löschen (Bestätigung).
- Toast-Meldungen für Fehler/Erfolg. Alles auf Deutsch.
- HTML-Ausgabe **immer escapen** (Titel kommen von Spotify) – eine `esc()`-Hilfsfunktion
  oder DOM-APIs mit `textContent`; kein ungeprüftes `innerHTML` mit Spotify-Daten.

## Weiterhören (app.js, `resume(entry, positionMs)`)

1. `PUT /me/player/play` mit `buildPlayBody`. Wenn ein Gerät aktiv ist: fertig, Toast
   „Weiter bei 12:34“, danach sofort einen Poll auslösen.
2. Fehler 404 / `NO_ACTIVE_DEVICE`: `GET /me/player/devices`; wenn Geräte vorhanden,
   das erste (bevorzugt Typ `Smartphone`, sonst erstes) per `device_id` nutzen.
3. Kein Gerät: Spotify-App öffnen über den Web-Link
   (`entry.webUrl` oder `https://open.spotify.com/{type}/{id}`, bei Kapiteln/Episoden
   `episode`, Hörbuch `audiobook`), den Wunsch als `pendingResume` merken und beim
   nächsten `visibilitychange` → sichtbar automatisch erneut ab Schritt 1 versuchen
   (einmal). Toast: „Spotify wird geöffnet – komm danach zurück, dann springe ich zur Stelle.“
4. 403 / `PREMIUM_REQUIRED`: Toast „Fernsteuerung braucht Spotify Premium – öffne Spotify
   stattdessen“ und Link öffnen.
- „In Spotify öffnen“ öffnet nur den Link (neuer Tab / App), ohne Minute.

## Tests (test/logic.test.mjs)

Mit `node:test` + `node:assert/strict`, Import über relativen Pfad `../web/logic.js`
(dafür `spotify_merker/package.json` mit `{"type":"module","scripts":{"test":"node --test test/"}}`).
Mindestens: normalizePlayback (Track, Episode mit Hörbuch-Kontext, Chapter, null),
recordSample (neuer Eintrag, Update innerhalb 5 min, neuer Eintrag nach Pause,
MAX_HISTORY), mergeRecentlyPlayed (Duplikat-Erkennung), findResumeCandidate,
buildPlayBody (Hörbuch-Kontext mit offset, Artist-Kontext → uris),
computeBookResume (mitten im Kapitel, Kapitel fertig → nächstes, alles fertig, nichts gehört),
filterHistory (Zeitraum, Art, Suche, around), formatMs.

## Abnahme

- `cd spotify_merker && npm test` grün.
- `node --check` für jede JS-Datei in `web/`.
- Seite lokal mit `python3 -m http.server` aus `web/` öffnen und per Playwright
  (Chromium unter `/opt/pw-browsers`) prüfen: lädt ohne Konsolenfehler, Tabs
  wechseln, Einstellungen zeigen Redirect-URI; mit einem in `localStorage` gesetzten
  Beispiel-Verlauf werden Verlauf, Filter und „Zurück zu …“-Banner korrekt gerendert.
- `deploy.sh` ausgeführt, `docs/spotify-merker/` aktuell.
