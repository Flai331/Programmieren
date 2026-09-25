# Parkplatz-Merker – Plan „Im Auto: mehrere Apps + Lautstärke-Profil“

Ergänzt `PLAN_APPSTART.md` und `PLAN_BEENDEN.md`.

Wunsch: Wenn ich in meinem Auto sitze, sollen **mehrere Apps** aufgehen
(z. B. Blitzer.de + Spotify + Google Maps) und ein **Lautstärke-Profil** gelten.
Beim Aussteigen werden die Apps beendet (wie bisher) und die Lautstärke
**zurückgesetzt**.

## „Auto-Sitzung“ – wann gilt „im Auto“?
Neues `object CarSession` bündelt Start/Ende:
- **Mit Gerät** (`deviceMode != none` und Adresse gesetzt): Start = `AppLauncher.seen`
  (Transmitter/Beacon erkannt, wie bisher), Ende = `AppLauncher.miss` (zwei Fehlrunden
  oder letzte Runde beim Aussteigen, wie bisher).
- **Ohne Gerät**: Start = `TripService.onEnter()`, Ende = `TripService.onExit()`.
  (Hinweis in der Oberfläche: „Ohne Transmitter gilt jede Fahrt – auch Bus/Taxi.“)

`AppLauncher.seen/miss/reset` bleiben die Stellen, an denen der Gerätezustand
geführt wird; statt direkt `launch`/`close` rufen sie `CarSession.start(ctx)` bzw.
`CarSession.end(ctx)`. `TripService.onEnter()`: wenn kein Gerät konfiguriert →
`CarSession.start(this)`. `TripService.onExit()`: wenn kein Gerät konfiguriert →
`CarSession.end(this)`.

```kotlin
object CarSession {
    fun start(ctx: Context) {            // idempotent über Config.sessionActive
        if (Config.sessionActive) return
        Config.sessionActive = true
        EventLog.info(ctx, "Im Auto: Sitzung beginnt")
        VolumeProfile.apply(ctx)
        AppLauncher.launchAll(ctx)
    }
    fun end(ctx: Context) {
        if (!Config.sessionActive) return
        Config.sessionActive = false
        EventLog.info(ctx, "Im Auto: Sitzung endet")
        if (Config.closeOnGone) AppLauncher.closeAll(ctx)
        VolumeProfile.restore(ctx)
    }
}
```
`TripService.stopEverything()`: `AppLauncher.reset()` wie bisher; `Config.sessionActive`
**nicht** zurücksetzen, wenn das Gerät noch da ist – nur `reset()` wie bisher.
Zusätzlich: Ist `sessionActive` seit > 12 h (`Config.sessionSince`), beim nächsten
`start` trotzdem neu starten (Schutz vor hängendem Zustand).

## Mehrere Apps

### Config
- Neuer Schlüssel `launchApps`: JSON-Array (String in SharedPreferences), je Eintrag
  `{"package": String, "label": String, "closeActionIndex": Int, "closeActionTitle": String}`.
- **Migration** beim Lesen: Ist `launchApps` leer/fehlt und `launchPackage` nicht leer →
  Liste mit diesem einen Eintrag (Index/Titel aus `closeActionIndex`/`closeActionTitle`)
  anlegen und speichern.
- `getConfig` liefert `launchApps` als `List<Map<String, Any>>`; `setConfig` nimmt
  `launchApps` als Liste von Maps (Zahlen als `Number`).
- Die alten Schlüssel `launchPackage/launchLabel/closeActionIndex/closeActionTitle`
  werden nicht mehr benutzt (nur für die Migration gelesen).

### AppLauncher
- `launchAll(ctx, fromForeground = false)`: Apps **nacheinander** mit 1,5 s Abstand
  (Handler) öffnen – die **letzte** in der Liste liegt danach vorn. Pro App dieselbe
  Logik wie bisher `launch` (direkt mit Overlay-Berechtigung, sonst Benachrichtigung;
  Benachrichtigungs-ID `40 + index`, requestCode `60 + index`).
- `closeAll(ctx, fromForeground = false)`: für jede App: Ausschaltknopf
  (`NotifListener.pressStop(pkg, title, index)`), Benachrichtigung `40+i` entfernen;
  danach einmal Startbildschirm, nach 1,5 s `killBackgroundProcesses` für alle;
  wenn `forceStopFallback`: nach 4 s für jede App, die noch eine Benachrichtigung hat
  oder deren Knopf nicht gedrückt werden konnte → `ForceStopService.request(ctx, pkg)`.
- `ForceStopService` muss dafür eine **Warteschlange** bekommen:
  `pendingPkgs: ArrayDeque<String>`; `request` hängt an (ohne Duplikate);
  `finish()` nimmt das nächste und ruft nach 1,5 s `tryRun()` erneut.
- `NotifListener.actions(pkg)`/`listCloseActions(pkg)`: Paket kommt jetzt als Argument.
- `MainActivity`: `listCloseActions` mit Argument `package`; `testLaunch` → `launchAll(this, true)`;
  `testClose` → `closeAll(this, true)`.

## Lautstärke-Profil

### Config
| Schlüssel | Typ | Standard | Bedeutung |
|---|---|---|---|
| `volumeEnabled` | Bool | false | Profil an |
| `volMusic` | Int | -1 | Medien (STREAM_MUSIC), -1 = nicht ändern |
| `volRing` | Int | -1 | Klingelton (STREAM_RING) |
| `volNotification` | Int | -1 | Benachrichtigungen (STREAM_NOTIFICATION) |
| `ringerMode` | String | "keep" | "keep" / "normal" / "vibrate" / "silent" |
| `volumeRestore` | Bool | true | beim Aussteigen zurücksetzen |
| `savedVolumes` | String | "" | intern: JSON der Werte vor dem Anwenden |
| `sessionActive`, `sessionSince` | Bool, Long | false, 0 | intern (s. o.) |

Werte sind **Stufen** (0 … `getStreamMaxVolume`), die Oberfläche zeigt Prozent.

### `VolumeProfile.kt` – `object VolumeProfile`
```kotlin
fun info(ctx): Map<String, Any>   // max + aktuell je Stream, ringerMode, dndAccess
    // "musicMax","musicNow","ringMax","ringNow","notificationMax","notificationNow",
    // "ringerMode" ("normal"/"vibrate"/"silent"), "dndAccess" (Bool)
fun apply(ctx)
    // nur wenn volumeEnabled. AudioManager holen.
    // Vorher (nur wenn savedVolumes leer!) aktuelle Werte + Ringer-Modus als JSON in savedVolumes.
    // Reihenfolge: erst ringerMode (≠ "keep"), dann Lautstärken (≠ -1) mit setStreamVolume(stream, wert, 0).
    // Ringer „silent“ und Klingelton/Benachrichtigung auf 0 brauchen „Nicht stören“-Zugriff:
    //   NotificationManager.isNotificationPolicyAccessGranted – fehlt er, diese Schritte
    //   überspringen und EventLog.info("Lautstärke: Nicht-stören-Zugriff fehlt").
    // Jede Änderung in try/catch (SecurityException) → EventLog.info.
    // EventLog.info("Lautstärke-Profil angewendet")
fun restore(ctx)
    // nur wenn volumeRestore und savedVolumes nicht leer: Werte zurückschreiben
    // (erst Lautstärken, dann Ringer-Modus), savedVolumes = "". EventLog.info(...)
```
Ringer-Modus-Werte: `AudioManager.RINGER_MODE_NORMAL / _VIBRATE / _SILENT`.
Manifest: `<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY"/>`.

### MainActivity neue Methoden
- `getVolumeInfo` → `VolumeProfile.info(this)`
- `applyVolumeNow` → `VolumeProfile.apply(this)` (Test), `restoreVolumeNow` → `VolumeProfile.restore(this)`
- `openDndSettings` → `Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`
- `getNativeStatus` zusätzlich `"dndAccess"`.

## Dart

### Neue Seite `lib/pages/car_page.dart` („Im Auto“)
Erreichbar aus den Einstellungen: der bisherige Abschnitt „App im Auto“ wird ersetzt durch
**eine** ListTile „Im Auto: Apps & Lautstärke“ (Untertitel: „2 Apps · Lautstärke-Profil an“ o. ä.)
mit ?-Knopf → `HelpTopic.appInCar`. Die Seite ist **immer** erreichbar (auch ohne Gerät);
ohne Gerät oben Hinweis: „Ohne Transmitter/Beacon gilt jede erkannte Fahrt – auch Bus oder Taxi.“

Aufbau (ListView, Abschnitte mit `?` zur passenden Anleitung):
1. **Apps öffnen** (`HelpTopic.appInCar`)
   - Liste der gewählten Apps (Label, Paket). Je Eintrag: Pfeile hoch/runter (Reihenfolge),
     Mülleimer, Knopf „Ausschaltknopf“ (öffnet den bestehenden Auswahldialog für DIESE App –
     Logik aus settings_page hierher verschieben, Paket als Argument).
   - „App hinzufügen“ → `AppPickerPage` (liefert jetzt die Auswahl per `Navigator.pop(context, {package,label})`
     zurück statt selbst zu speichern; „Keine App“ entfällt) → an Liste anhängen (keine Duplikate).
   - Hinweis: „Die letzte App in der Liste liegt danach vorn.“
   - `_PermTile` „Über anderen Apps einblenden“ (wie bisher).
   - „Apps jetzt öffnen (Test)“ → `testLaunch`.
2. **Beim Aussteigen** (`HelpTopic.closeApp`)
   - Schalter „Apps beim Aussteigen beenden“ (`closeOnGone`), Benachrichtigungszugriff,
     Schalter „Notfalls Beenden erzwingen“ + Bedienungshilfe (alles wie bisher, hierher verschoben),
     „Beenden jetzt testen“ → `testClose`.
3. **Lautstärke im Auto** (`HelpTopic.volume`, neu)
   - Schalter „Lautstärke-Profil“ (`volumeEnabled`).
   - Je Stream (Medien, Klingelton, Benachrichtigungen): Checkbox „ändern“ + Slider
     0 … max (Stufen, `divisions: max`), Anzeige „60 %“. Aus = -1.
   - Klingelmodus: `SegmentedButton` Nicht ändern / Normal / Vibration / Lautlos.
   - Schalter „Beim Aussteigen zurücksetzen“ (`volumeRestore`).
   - Wenn Lautlos oder ein Klingelton/Benachrichtigungswert 0 gewählt und `dndAccess == false`:
     `_PermTile` „Nicht-stören-Zugriff“ → `openDndSettings`.
   - Knöpfe „Jetzt anwenden“ / „Zurücksetzen“ (Test).
   - Änderungen werden sofort mit `updateConfig` gespeichert (Slider: bei `onChangeEnd`).

`_PermTile` und `_Header` aus settings_page in eine gemeinsame Datei
`lib/pages/common_widgets.dart` verschieben (öffentlich: `PermTile`, `SectionHeader`).

### NativeBridge / Controller
- `setConfig`/`updateConfig`: `launchApps` (List<Map<String, dynamic>>), `volumeEnabled`,
  `volMusic`, `volRing`, `volNotification`, `ringerMode`, `volumeRestore`.
- Neue Methoden: `getVolumeInfo`, `applyVolumeNow`, `restoreVolumeNow`, `openDndSettings`,
  `listCloseActions(String package)`.
- Rückgaben wie bisher tolerant umwandeln (Maps/Listen von Android sind `Map<Object?, Object?>`!).

### Anleitung (Pflicht, siehe CLAUDE.md)
- `help_page.dart`: Abschnitt `appInCar` auf mehrere Apps umschreiben (Reihenfolge,
  letzte liegt vorn, gilt ohne Gerät bei jeder Fahrt), `closeApp` auf „alle Apps“ anpassen,
  **neuer** Abschnitt `HelpTopic.volume` „Lautstärke im Auto“ (was es tut, zurücksetzen,
  Nicht-stören-Zugriff nur für Lautlos/0 nötig).
- README kurz ergänzen.

## Tests
- `test/help_page_test.dart` um den neuen Abschnitt erweitern.
- `flutter analyze` ohne Fehler/Warnungen, `flutter test` grün.
