# Spotify-Merker Android – Plan „Eingeschlafen?“

Problem: Beim Einschlafen läuft das Hörbuch weiter. Gesucht ist die Stelle,
an der man **eingeschlafen** ist, nicht die zuletzt gespielte.

Zwei Bausteine:
1. **Handy-Aktivität** (immer an, automatisch): Bildschirm an/aus/entsperrt
   wird mitgeschrieben. Lief das Hörbuch nach dem letzten Weglegen des Handys
   noch lange weiter, schlägt die App die Stelle zum Zeitpunkt des Weglegens vor.
2. **Einschlaf-Modus mit Wach-Check** (manuell starten): Alle N Minuten eine
   kurze Vibration + Benachrichtigung „Noch wach?“. Schütteln oder Antippen →
   weiter. Keine Reaktion binnen 60 s → Spotify pausieren, die Stelle beim
   **letzten bestätigten Wach-Check** merken.

## Ereignis-Format (EventLog, `events.jsonl`)

Bisherige Media-Ereignisse bleiben unverändert (kein `type`-Feld = Media).
Neu, jeweils mit `ts` (ms):

| type | Felder | Bedeutung |
|---|---|---|
| `screen` | `action`: `on` / `off` / `unlock` | Bildschirm an, aus, entsperrt |
| `sleep` | `action`: `start`, `intervalMin` | Einschlaf-Modus gestartet |
| `sleep` | `action`: `check` | Wach-Check ausgelöst |
| `sleep` | `action`: `awake`, `via` (`shake`/`tap`/`start`), + Snapshot-Felder (`title`, `artist`, `album`, `mediaId`, `spotifyUri`, `contextUri`, `contextTitle`, `durationMs`, `positionMs`, `state`) | Wach bestätigt; Snapshot = was gerade läuft (oder leer) |
| `sleep` | `action`: `asleep`, `lastAwakeTs` | keine Reaktion → Spotify pausiert |
| `sleep` | `action`: `stop` | vom Nutzer beendet |

Beim `start` wird sofort auch ein `awake` (via `start`) mit Snapshot geschrieben.

## Kotlin

### Bildschirm (in `MediaListenerService`)
Dynamischer Receiver für `Intent.ACTION_SCREEN_ON`, `ACTION_SCREEN_OFF`,
`ACTION_USER_PRESENT` (nur dynamisch möglich; Service läuft dauerhaft).
In `onListenerConnected` registrieren (kein Export-Flag nötig für System-
Broadcasts, aber ab API 33 `RECEIVER_NOT_EXPORTED` verwenden), in
`onListenerDisconnected` abmelden. Jeweils `EventLog.append(type=screen …)`.

### Neue Datei `SleepMode.kt` (object)
- Zustand: `active`, `intervalMs`, `nextCheckAt` (wall clock), `lastAwakeTs`,
  `waitingForAnswer`.
- `start(ctx, intervalMin)`: aktiv setzen, `sleep/start` + `sleep/awake(via=start)`
  loggen, dauerhafte Status-Benachrichtigung (ID 2, `setOngoing(true)`, Text
  „🌙 Einschlaf-Modus – nächster Wach-Check 23:30“, Aktion „Beenden“),
  ersten Check planen.
- Timer mit `Handler(Looper.getMainLooper())`. (Solange Spotify spielt, hält
  Spotify die CPU wach; Doze ist kein Problem. Nach dem Pausieren braucht es
  keine Timer mehr.)
- `check()`: `sleep/check` loggen; Benachrichtigung ID 3 „Noch wach? Schüttle
  das Handy oder tippe hier.“ mit Aktion „Ich bin wach“; kurze Vibration
  (2× 150 ms, `VibrationEffect.createWaveform`, API ≥ 26 – minSdk der App ist
  ≥ 24, also Fallback `vibrate(long[], -1)` mit `@Suppress("DEPRECATION")`);
  Schüttel-Erkennung (`SensorManager`, `TYPE_ACCELEROMETER`,
  `SENSOR_DELAY_UI`; Schütteln = Betrag/9.81 > 2.2 an 2 Messungen innerhalb
  800 ms) **nur während der 60-s-Antwortzeit** registrieren. Timeout 60 s.
- `confirmAwake(ctx, via)`: Sensor abmelden, Benachrichtigung 3 entfernen,
  `sleep/awake` mit Snapshot (`MediaListenerService.instance?.snapshot()`)
  loggen, `lastAwakeTs` setzen, nächsten Check planen, Status aktualisieren.
- Timeout ohne Antwort: Spotify pausieren
  (`MediaListenerService.instance?.spotifyController?.transportControls?.pause()`),
  `sleep/asleep(lastAwakeTs)` loggen, Modus beenden, Status-Benachrichtigung
  ersetzen durch nicht-dauerhafte „😴 Eingeschlafen – zuletzt wach um 23:14.
  Öffne die App, um dort weiterzuhören.“ (Tippen öffnet MainActivity).
- **Spielt beim Check gar nichts** (Snapshot null oder state != PLAYING): keine
  Vibration, einfach nächsten Check planen (Modus bleibt an, stört nicht).
- `stop(ctx)`: alles abbrechen, `sleep/stop` loggen, Benachrichtigungen weg.
- `status()`: Map `active`, `intervalMin`, `nextCheckAt`, `lastAwakeTs`, `waitingForAnswer`.
- Notification-Channel `sleep` („Einschlaf-Modus“), `IMPORTANCE_DEFAULT`, aber
  `setSound(null, null)` und `enableVibration(false)` (wir vibrieren selbst).
- Aktionen per `PendingIntent.getBroadcast` an einen **nicht exportierten**
  Receiver `SleepActionReceiver` (im Manifest, `exported=false`), Actions
  `com.klaasotte.spotify_merker.AWAKE` / `.STOP`. PendingIntent-Flags
  `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT`.

### Manifest
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
- `<uses-permission android:name="android.permission.VIBRATE"/>`
- `<receiver android:name=".SleepActionReceiver" android:exported="false"/>`

### MethodChannel (MainActivity) – neu
| Methode | |
|---|---|
| `sleepStart` (`intervalMin`: Number) | ab API 33 vorher `POST_NOTIFICATIONS` per `requestPermissions` (Framework-API, kein androidx) anfragen, falls nicht erteilt; dann `SleepMode.start` |
| `sleepStop` | `SleepMode.stop` |
| `sleepStatus` | `SleepMode.status()` |

## Dart

### `lib/logic.dart` (rein, getestet)
- `ActivityEvent` (`ts`, `type`, `action`, `via`, `lastAwakeTs`, optional `snapshot` als `RawEvent`-ähnliche Felder) mit fromJson/toJson.
- `splitEvents(List<Map>)` → Media-Ereignisse (`type` fehlt) vs. Aktivitäts-Ereignisse.
- `int positionAt(Entry e, int ts)` = `clamp(e.startPositionMs + (ts - e.startedAt), 0, e.durationMs>0 ? e.durationMs : ∞)`;
  `Entry? entryAt(history, ts)` = Eintrag mit `startedAt <= ts <= lastSeenAt` (neuester zuerst).
- `SleepGuess? guessSleep(history, activity, now)`:
  1. Jüngstes `sleep/asleep` in den letzten 18 h → Vorschlag aus dem zugehörigen
     `sleep/awake`-Snapshot mit `ts == lastAwakeTs` (falls vorhanden),
     sonst `entryAt(history, lastAwakeTs)` + `positionAt`. Quelle `wachcheck`.
  2. Sonst: Hörbuch-Einträge (spoken) der letzten 18 h. Letztes Bildschirm-
     Ereignis `off` (bzw. `on`/`unlock`, falls danach kein `off`) = `lastPhoneUse`.
     Lief nach `lastPhoneUse` noch **≥ 10 min** Hörbuch weiter
     (jüngster spoken-Eintrag `lastSeenAt - lastPhoneUse >= 10 min`), dann
     Vorschlag `entryAt(history, lastPhoneUse)` + `positionAt`. Quelle `handy`.
  3. Sonst null.
  - `SleepGuess`: `entry` (für Weiterhören, Position = geschätzte Position),
    `at` (Zeitpunkt), `source`, `playedAfterMin` (wie lange danach noch lief).
- Aktivitätsliste begrenzen: nur letzte 14 Tage behalten.

### `lib/storage.dart`
`loadActivity` / `saveActivity` → `activity.json` (gleiches atomares Muster).

### `lib/native.dart`
`drainEvents` liefert künftig die rohen Maps; Aufteilung in main.dart über
`splitEvents`. `sleepStart(int)`, `sleepStop()`, `sleepStatus()`.

### Oberfläche (Tab „Jetzt“, ganz oben)
- **„😴 Eingeschlafen?“-Karte**, wenn `guessSleep` etwas liefert:
  „Vermutlich eingeschlafen um 23:14“ (Quelle handy: „Handy zuletzt benutzt um
  23:14“; Quelle wachcheck: „Letzter Wach-Check um 23:14“), darunter Hörbuch-
  Name (`groupTitle`), Kapitel, „bei 8:40“, „danach lief es noch 47 Min.“,
  Knopf **„▶ Dort weiterhören“** → `startResume` mit der geschätzten Position.
  Knopf „Ausblenden“ (merkt sich das `at` in shared state/Datei, damit die
  Karte für diese Nacht verschwindet).
- **„🌙 Einschlaf-Modus“-Karte**: Auswahl Intervall (10/15/20/30 Min, Chips),
  Knopf Starten/Beenden, Status „Nächster Wach-Check um 23:30“. Kurzer
  Hilfetext: „Alle X Minuten vibriert das Handy kurz. Schütteln oder
  Benachrichtigung antippen = wach. Keine Reaktion in 60 s → Spotify pausiert,
  und die Stelle vom letzten Wach-Check wird gemerkt.“
- Die bisherige „Zurück zu“-Karte bleibt darunter.

## Tests (`test/logic_test.dart`)
- `positionAt`, `entryAt`.
- `guessSleep` Quelle handy: Hörbuch 22:00–01:00, Bildschirm aus 23:14 → Vorschlag
  23:14, Position = start + 74 min (Kapitel-Grenzen beachten: richtiger Eintrag).
- Kein Vorschlag, wenn nach dem Weglegen < 10 min lief.
- Quelle wachcheck: `awake` 23:14 mit Snapshot, `asleep` 23:29 → Snapshot-Stelle.
- `splitEvents`.
- Bestehende Tests bleiben grün.
