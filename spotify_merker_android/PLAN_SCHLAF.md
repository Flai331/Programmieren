# Spotify-Merker Android – Plan „Eingeschlafen?”

Problem: Beim Einschlafen läuft das Hörbuch weiter. Gesucht ist die Stelle,
an der man **eingeschlafen** ist, nicht die zuletzt gespielte.

**Baustein: Automatische Aktivitäts-Erkennung** (Bildschirm + Bewegung):
- Bildschirm an/aus/entsperrt wird mitgeschrieben.
- Passive Bewegungs-Erkennung: Nur während Spotify PLAYING, drosselt auf 1 Event/60s.
- Letztes Zeichen von Wachsein = neuestes screen- oder motion-Ereignis.
- Wenn Hörbuch danach ≥ 15 min weiter lief → Stelle zum Zeitpunkt dieses Ereignisses vorschlagen.

## Ereignis-Format (EventLog, `events.jsonl`)

Bisherige Media-Ereignisse bleiben unverändert (kein `type`-Feld = Media).
Neu, jeweils mit `ts` (ms):

| type | Felder | Bedeutung |
|---|---|---|
| `screen` | `action`: `on` / `off` / `unlock` | Bildschirm an, aus, entsperrt |
| `motion` | `level` | Bewegung (m/s²), max. 1 Event pro 60s |

## Kotlin

### Bildschirm (in `MediaListenerService`)
Dynamischer Receiver für `Intent.ACTION_SCREEN_ON`, `ACTION_SCREEN_OFF`,
`ACTION_USER_PRESENT` (nur dynamisch möglich; Service läuft dauerhaft).
In `onListenerConnected` registrieren (ab API 33 `RECEIVER_NOT_EXPORTED`),
in `onListenerDisconnected` abmelden. Jeweils `EventLog.append(type=screen …)`.

### Neue Datei `MotionWatcher.kt`
- Registriert TYPE_ACCELEROMETER **nur während Spotify PLAYING** (via MediaListenerService).
- Low-pass filter (alpha 0.8) für Erdbeschleunigung; lineare Beschleunigung = raw - gravity.
- Erkennt Bewegung: magnitude > 1.2 m/s².
- Throttle: max. 1 Event pro 60s. Ignoriert erste 2s nach Start (filter settling).
- Loggt `{“type”:”motion”, “ts”: ..., “level”: <Magnitude auf 0.1 gerundet>}`.

### MediaListenerService
- `startMotionWatcher()`: MotionWatcher starten wenn PLAYING.
- `stopMotionWatcher()`: Sensor abmelden bei PAUSED/STOPPED/session end.
- Properties: `lastMotionAt` (ts oder null), `motionListening` (bool).
- Diese zu Diagnostics hinzufügen.

## Dart

### `lib/logic.dart` (rein, getestet)
- `ActivityEvent` (`ts`, `type`, `action` optional, `level` optional) mit fromJson/toJson.
  - type: `'screen'` oder `'motion'`
  - action (nur screen): `'on'` / `'off'` / `'unlock'`
  - level (nur motion): Magnitude m/s²
- `splitEvents(List<Map>)` → Media-Ereignisse (`type` fehlt) vs. Aktivitäts-Ereignisse.
- `int positionAt(Entry e, int ts)` = `clamp(e.startPositionMs + (ts - e.startedAt), 0, e.durationMs>0 ? e.durationMs : ∞)`;
  `Entry? entryAt(history, ts)` = Eintrag mit `startedAt <= ts <= lastSeenAt`.
- `SleepGuess? guessSleep(history, activity, now)`:
  - Letztes Zeichen von Wachsein = neuestes screen- oder motion-Ereignis (egal wann).
  - Hörbuch-Einträge der letzten 18h: wenn jüngste `lastSeenAt - lastSign >= 15 min` →
    Vorschlag `entryAt(history, lastSign)` + `positionAt(entry, lastSign)`.
    Quelle: `'Handy-Nutzung'` oder `'Bewegung'` (je nach Event-Typ).
  - Sonst null.
  - `SleepGuess`: `entry`, `at` (Zeitpunkt des letzten Vorzeichens), `source` (String),
    `playedAfterMin`.
- Aktivitätsliste begrenzen: nur letzte 14 Tage behalten.

### `lib/storage.dart`
`loadActivity` / `saveActivity` → `activity.json` (gleiches atomares Muster).

### `lib/native.dart`
`drainEvents` liefert künftig die rohen Maps; Aufteilung in main.dart über
`splitEvents`. `sleepStart(int)`, `sleepStop()`, `sleepStatus()`.

### Oberfläche (Tab „Jetzt”, ganz oben)
- **„😴 Eingeschlafen?”-Karte**, wenn `guessSleep` etwas liefert:
  Erste Zeile: „Vermutlich eingeschlafen um 23:14”.
  Zweite Zeile: „Letzte Handy-Nutzung/Bewegung um 23:14, danach lief es noch 47 Min.”
  Darunter: Hörbuch-Name (`groupTitle`), Kapitel, „bei 8:40”.
  Buttons: **„▶ Dort weiterhören”** → `startResume` mit geschätzter Position.
  Button „Ausblenden” → merkt sich `at` zum Ausblenden für diese Nacht.
- Die bisherige „Zurück zu”-Karte bleibt darunter.

## Tests (`test/logic_test.dart`)
- `positionAt`, `entryAt`.
- `guessSleep` Bildschirm-only: Screen off 23:14, Hörbuch bis 23:59 → Vorschlag 23:14.
- `guessSleep` Motion-only: Bewegung 23:14, Hörbuch bis 23:59 → Vorschlag 23:14, source='Bewegung'.
- Kein Vorschlag, wenn danach < 15 min lief.
- `guessSleep` bevorzugt neuestes Event (screen/motion).
- `splitEvents`.
- Bestehende Tests bleiben grün.
