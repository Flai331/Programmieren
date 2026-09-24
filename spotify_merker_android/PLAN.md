# Spotify-Merker Android – Plan

Flutter-App (nur Android), die **ohne Spotify-Developer-Zugang und ohne Premium**
im Hintergrund mitschreibt, was in der Spotify-App läuft (Titel, Interpret bzw.
Hörbuch, Minute), und mit einem Tipp zur gemerkten Stelle zurückspringt.

Hauptfall: Hörbuch läuft → zwischendurch Musik → „Zurück zu: Der Hobbit –
Kapitel 7 · bei 12:34“ → Tipp → Spotify spielt das Kapitel ab 12:34.

## Grundprinzip

Android erlaubt einer App mit **Benachrichtigungszugriff**
(`NotificationListenerService`) die aktiven Media-Sessions anderer Apps zu
lesen und zu steuern (`MediaSessionManager.getActiveSessions`). Spotify
veröffentlicht dort Titel, Interpret, Album, Dauer, Position und Status.
Der Dienst läuft vom System gehalten im Hintergrund, auch wenn die App zu ist.

Zusätzlich (optional, verbessert das Zurückspringen): Spotify sendet bei
eingeschalteter Einstellung **„Geräte-Broadcast-Status“** Broadcasts
`com.spotify.music.metadatachanged` / `com.spotify.music.playbackstatechanged`
mit der Spotify-URI (`id`-Extra). Der Dienst registriert dafür dynamisch einen
Receiver.

## Aufteilung

- **Kotlin (native, `android/app/src/main/kotlin/com/klaasotte/spotify_merker/`)**
  sammelt nur **Rohereignisse** und führt Steuerbefehle aus. Keine
  Verlaufs-Logik in Kotlin.
- **Dart** verarbeitet Rohereignisse zum Verlauf (reine, getestete Logik) und
  zeigt die Oberfläche.
- Verbindung über einen `MethodChannel('spotify_merker/native')`.

Ordner: `spotify_merker_android/` (Flutter-Projekt, Paket `spotify_merker`,
Application-ID `com.klaasotte.spotify_merker` (so von `flutter create` erzeugt; Kotlin-Paket gleich), App-Name „Spotify-Merker“).

## Kotlin

### `MediaListenerService : NotificationListenerService`
Im Manifest mit `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` und
Intent-Filter `android.service.notification.NotificationListenerService`.

- `onListenerConnected`: `MediaSessionManager.addOnActiveSessionsChangedListener(listener, ComponentName(this, MediaListenerService::class.java))`
  und sofort `getActiveSessions(...)` auswerten. `onListenerDisconnected`: alles abmelden.
- Für jede Session mit `packageName == "com.spotify.music"`: `MediaController.Callback`
  registrieren (`onMetadataChanged`, `onPlaybackStateChanged`, `onSessionDestroyed`).
  Controller merken (für Steuerung).
- **Momentaufnahme** (`Snapshot`): title (`METADATA_KEY_TITLE`), artist
  (`METADATA_KEY_ARTIST`), album (`METADATA_KEY_ALBUM`), durationMs
  (`METADATA_KEY_DURATION`), mediaId (`METADATA_KEY_MEDIA_ID`), mediaUri
  (`METADATA_KEY_MEDIA_URI`), artUri (`METADATA_KEY_ART_URI` oder `ALBUM_ART_URI`),
  state (`PLAYING`/`PAUSED`/…), positionMs **hochgerechnet**:
  `position + (SystemClock.elapsedRealtime() - lastPositionUpdateTime) * playbackSpeed`
  nur wenn PLAYING, auf `[0, duration]` begrenzt; `actions` (Bitmaske),
  spotifyUri (aus letztem Broadcast, falls Titel passt – s. u.), ts (`System.currentTimeMillis()`).
- **Wann ein Ereignis geschrieben wird:**
  1. Metadaten ändern sich (anderer Titel): **zuerst** ein Ereignis für das
     **vorige** Stück mit seiner hochgerechneten Endposition (`reason:"end"`),
     dann eins für das neue (`reason:"start"`).
  2. Wiedergabestatus ändert sich (Play/Pause/Stop/Seek): `reason:"state"`.
  3. Während PLAYING alle **20 s** per `Handler.postDelayed`: `reason:"tick"`.
  4. Session verschwindet: `reason:"end"` für das laufende Stück.
- Ereignisse als JSON-Zeile an `filesDir/events.jsonl` anhängen (synchronized).
  Datei max. 20 000 Zeilen – ältere Hälfte verwerfen, wenn überschritten.
- **Broadcast-Receiver** (im Service dynamisch registriert, `RECEIVER_EXPORTED`
  ab API 33): bei `metadatachanged` `id`, `track`, `artist`, `album`, `length`
  merken; `playbackstatechanged` ignorieren oder nur `playbackPosition` merken.
  Beim Snapshot `spotifyUri` setzen, wenn `track == title`.
- Ein Singleton (`MerkerBridge`/companion object) hält die aktuelle Instanz,
  damit der MethodChannel die Controller erreicht.

### MethodChannel-Methoden (in `MainActivity`)
| Methode | Ergebnis |
|---|---|
| `isPermissionGranted` | bool – `NotificationManagerCompat.getEnabledListenerPackages(ctx).contains(packageName)` |
| `openPermissionSettings` | öffnet `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` |
| `drainEvents` | Liste der JSON-Strings aus `events.jsonl`, danach Datei leeren (atomar, synchronized) |
| `getCurrent` | aktueller Snapshot als Map oder null |
| `isSpotifyInstalled` | bool |
| `resume` (args: title, artist, album, spotifyUri?, positionMs) | startet den Ablauf unten, gibt sofort `{"started":true}` zurück |
| `getDiagnostics` | Map: permission, serviceConnected, spotifySessionFound, lastMetadata (alle Keys als Strings), actions als Liste von Namen, lastBroadcast, lastResumeLog (Liste der letzten 30 Log-Zeilen) |

### Zurückspringen (`resume`)
Ablauf mit Protokoll (`resumeLog`, sichtbar in der Diagnose):
1. Falls keine Spotify-Session existiert: Spotify starten
   (`packageManager.getLaunchIntentForPackage("com.spotify.music")`, bzw. bei
   bekannter `spotifyUri` `Intent(ACTION_VIEW, Uri.parse(spotifyUri)).setPackage("com.spotify.music")`),
   bis 10 s auf eine Session warten.
2. Wiedergabe des richtigen Stücks anstoßen, in dieser Reihenfolge je nach
   `PlaybackState.actions`:
   a. `spotifyUri` bekannt und `ACTION_PLAY_FROM_URI` → `playFromUri(uri, null)`
   b. `ACTION_PLAY_FROM_SEARCH` → `playFromSearch("<title> <artist>", extras)`
      mit `MediaStore.EXTRA_MEDIA_TITLE`, `EXTRA_MEDIA_ARTIST`, `EXTRA_MEDIA_ALBUM`
   c. sonst: Spotify per Intent öffnen (`spotify:search:<title artist>` URL-kodiert),
      Toast-Hinweis „Bitte Titel antippen – ich spule dann automatisch“.
   Ist das gewünschte Stück bereits das aktuelle (Titel gleich), direkt zu 3.
3. **Warten auf den richtigen Titel** (max. 60 s, Metadaten-Callback):
   sobald `title` (case-insensitive, getrimmt) übereinstimmt → `seekTo(positionMs)`,
   dann `play()`. Protokollieren. Nach Timeout: Protokoll „nicht gefunden“.
- Alles auf dem Main-Looper, keine Blockierung des UI-Threads.

### Manifest
- `<queries><package android:name="com.spotify.music"/></queries>`
- Service-Eintrag (exported=true, permission BIND_NOTIFICATION_LISTENER_SERVICE).
- Keine weiteren Berechtigungen. Kein Internet nötig (INTERNET-Permission weglassen im Release; Debug-Manifest bringt sie ohnehin mit).

## Dart

Abhängigkeiten nur: `path_provider`, `share_plus` (Export). Kein file_picker.

### `lib/logic.dart` (rein, voll getestet – Port der Web-Logik)
- `RawEvent.fromJson` (ts, reason, title, artist, album, durationMs, positionMs,
  state, mediaId, mediaUri, artUri, spotifyUri).
- `Entry` (id, key, title, artist, album, spotifyUri, mediaId, artUri, kind
  `music|spoken`, durationMs, startPositionMs, positionMs, startedAt,
  lastSeenAt, pinned) mit toJson/fromJson.
- `String entryKey(e)` = spotifyUri ?? mediaId ?? "$title|$artist" (lowercase).
- `bool isSpoken(e)`: URI/mediaId enthält `:episode:`, `:chapter:`, `:audiobook:`,
  `:show:` → true; sonst `durationMs >= 15 min` → true; sonst false.
- `List<Entry> applyEvents(List<Entry> history, List<RawEvent> events)`:
  Ereignisse nach ts sortiert. Leere Titel ignorieren. Gleicher key wie
  jüngster Eintrag und `ts - lastSeenAt <= 5 min` → Eintrag aktualisieren
  (positionMs, lastSeenAt, fehlende Felder ergänzen). Sonst neuer Eintrag
  (aber nicht bei state!="playing" und positionMs==0). Max. 3000 Einträge,
  neueste zuerst.
- `Entry? findResumeCandidate(history, Current? current)` – jüngster spoken-Eintrag,
  außer er läuft gerade (gleicher key und playing).
- `filterHistory(history, range, kind, query, around, now)` wie Web-Version
  (hour/today/yesterday/week/all; all/spoken/music/pinned; ±30 min um `around`).
- `formatMs`, `formatAgo` (deutsch: „gerade eben“, „vor 5 Min.“, „vor 2 Std.“, „vor 3 Tagen“).

### `lib/storage.dart`
Verlauf als JSON in `getApplicationDocumentsDirectory()/history.json`
(atomar schreiben: tmp-Datei + rename). Export: Datei teilen via share_plus.

### Oberfläche (Material 3, Farbe grün `#1DB954`, hell/dunkel nach System, Deutsch)
Beim Start und bei `AppLifecycleState.resumed`, sowie alle 5 s solange sichtbar:
`drainEvents` → `applyEvents` → speichern; `getCurrent` → Anzeige.

- **Einrichtung** (statt der Tabs, solange Berechtigung fehlt): Erklärung,
  Knopf „Benachrichtigungszugriff erlauben“ → `openPermissionSettings`;
  Hinweis auf Spotify → Einstellungen → „Geräte-Broadcast-Status“ einschalten
  (optional, macht das Zurückspringen zuverlässiger); Hinweis Akku-Optimierung
  (Samsung/Xiaomi: App nicht einschränken). Knopf „Weiter“ prüft erneut.
- **Tab Jetzt**: „Zurück zu …“-Karte (Buch/Interpret, Titel, „bei 12:34 · vor 5 Min.“,
  Knopf „▶ Weiterhören“), darunter aktuelles Stück mit Fortschrittsbalken
  und „📌 Merken“.
- **Tab Verlauf**: Filter-Chips Zeitraum und Art, Suchfeld, „Was lief um …?“
  (Datum+Uhrzeit-Picker, mit ✕), gruppiert nach Tag („Heute“, „Gestern“, Datum).
  Eintrag: Titel, Interpret/Album, Uhrzeit von–bis, Minute, Art; Aktionen
  ▶ Weiterhören, 📌 Pin, 🗑 Löschen (Bestätigung).
- **Tab Einstellungen**: Status der Berechtigung, Einrichtungshinweise erneut,
  „Verlauf exportieren“, „Verlauf löschen“, **„Diagnose“** (zeigt
  `getDiagnostics` als lesbare Liste + Knopf „Kopieren“ für die Zwischenablage –
  wichtig zum Fehlersuchen, da nicht in der Cloud testbar).
- Weiterhören: `resume` aufrufen, SnackBar „Spotify wird gestartet – springe zu 12:34 …“.

## Tests
- `test/logic_test.dart`: applyEvents (neu, Update innerhalb 5 min, neuer
  Eintrag nach Pause, end-Ereignis setzt Endposition, Paused+0 ignoriert,
  Limit), entryKey/isSpoken, findResumeCandidate, filterHistory, formatMs/formatAgo.
- `test/widget_test.dart`: App startet mit gemocktem MethodChannel
  (`TestDefaultBinaryMessengerBinding`), Berechtigung erteilt, Verlauf mit
  Beispieldaten → Banner „Zurück zu“ sichtbar.
- `flutter analyze` ohne Fehler.
- Kotlin wird nur im CI kompiliert (lokal kein Android-SDK) – daher sorgfältig
  schreiben, keine exotischen APIs, `compileSdk`/`minSdk` aus Flutter-Defaults
  (minSdk mindestens 23).

## CI: `.github/workflows/spotify-merker-apk.yml`
Nach Vorlage `beebrain-apk.yml` (auf Branch `claude/youthful-ride-ps4nsg`):
Flutter 3.47.1, JDK 21, `pub get`, `analyze --no-fatal-warnings --no-fatal-infos`,
`flutter test`, `flutter build apk --release` (Signierung mit Debug-Key ist
für private Installation ok – Flutter-Standard), Trigger: push auf `main` und
`claude/**` mit Pfaden `spotify_merker_android/**` und der Workflow-Datei,
plus `workflow_dispatch`. Ergebnis:
- immer als Actions-Artefakt hochladen;
- auf `main` zusätzlich GitHub-Release mit festem Tag `spotify-merker-android`
  aktualisieren (`gh release` mit `GITHUB_TOKEN`, `permissions: contents: write`;
  Release löschen/neu anlegen oder `gh release upload --clobber`), Datei
  `Spotify-Merker.apk`. Stabiler Download-Link:
  `https://github.com/Flai331/Programmieren/releases/download/spotify-merker-android/Spotify-Merker.apk`

## README.md (Deutsch)
Installation (APK-Link, „Aus unbekannten Quellen installieren“ erlauben),
Berechtigung, Spotify-Einstellung „Geräte-Broadcast-Status“, Akku-Hinweis,
Grenzen (nur Android; Zurückspringen hängt davon ab, was Spotify erlaubt – bei
Problemen Diagnose kopieren und schicken).
