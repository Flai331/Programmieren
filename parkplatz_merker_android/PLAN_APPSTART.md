# Parkplatz-Merker – Plan „App starten, wenn das Gerät im Auto erkannt wird“

Wunsch: Ist der Transmitter/Beacon in der Nähe (= ich sitze in meinem Auto),
soll eine gewählte App (z. B. Blitzer.de) **geöffnet** werden; ist er wieder
weg (Motor aus), soll sie **geschlossen** werden.

## Was Android zulässt (ehrlich)

- **Öffnen aus dem Hintergrund** ist seit Android 10 gesperrt – außer die
  App hat die Sonderberechtigung **„Über anderen Apps einblenden“**
  (`SYSTEM_ALERT_WINDOW`, Einstellungsseite
  `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`). Ohne sie zeigen wir
  stattdessen eine Benachrichtigung „Blitzer.de öffnen“ (ein Tipp öffnet).
- **Schließen** einer fremden App ist nicht möglich (kein Root). Wir können:
  1. zum **Startbildschirm** wechseln (die App verschwindet vom Bildschirm) und
  2. danach `ActivityManager.killBackgroundProcesses(paket)` versuchen
     (Berechtigung `KILL_BACKGROUND_PROCESSES`). Das beendet die App nur,
     wenn sie **keinen** eigenen Hintergrunddienst mit Benachrichtigung hat.
     Blitzer-Apps haben meist einen – dann bleibt deren Warnung aktiv und
     muss in der App selbst beendet werden. Das steht so auch in der
     Oberfläche und im README.
- Erkannt wird das Gerät nur so schnell wie bisher: Transmitter-Suche
  startet, sobald die Aktivitätserkennung „im Fahrzeug“ meldet (erste Runde
  sofort, dann alle 2 min); Beacon zusätzlich über den Hintergrund-Scan
  (meist innerhalb ~1 min nach Einstecken).

## Einstellungen (Kotlin `Config`, neue Schlüssel)

| Schlüssel | Typ | Standard | Bedeutung |
|---|---|---|---|
| `launchPackage` | String | `""` | Paketname der App; `""` = aus |
| `launchLabel` | String | `""` | Anzeigename der App |
| `closeOnGone` | Boolean | `true` | beim Verschwinden schließen |
| `devicePresent` | Boolean | `false` | intern: Gerät zuletzt gesehen |
| `devicePresentAt` | Long | `0` | intern: Zeitpunkt |

`getConfig` liefert zusätzlich `launchPackage`, `launchLabel`, `closeOnGone`.
`setConfig` übernimmt diese drei (String/Boolean wie bisher über `as?`;
`launchPackage = ""` schaltet aus).

## Kotlin

### Neue Datei `AppLauncher.kt` – `object AppLauncher`
```kotlin
private const val FRESH_MS = 10 * 60_000L   // „gesehen“ gilt 10 min
private var misses = 0                       // aufeinanderfolgende Fehlrunden

fun seen(ctx: Context)
    // misses = 0
    // val now = System.currentTimeMillis()
    // val wasPresent = Config.devicePresent && now - Config.devicePresentAt < FRESH_MS
    // Config.devicePresent = true; Config.devicePresentAt = now
    // if (!wasPresent) launch(ctx)

fun miss(ctx: Context, strong: Boolean)
    // nur wenn Config.devicePresent:
    // misses++ ; wenn strong || misses >= 2 → Config.devicePresent = false, misses = 0,
    //   if (Config.closeOnGone) close(ctx)
    // (Einzelne Fehlrunde während der Fahrt schließt NICHT – klassische Suche
    //  verpasst Geräte gelegentlich. strong = letzte Runde beim Aussteigen.)

fun reset()            // beim Service-Ende: Config.devicePresent = false, misses = 0 (ohne schließen)

fun launch(ctx: Context)
    // pkg = Config.launchPackage; leer → return
    // val intent = ctx.packageManager.getLaunchIntentForPackage(pkg) ?: run { EventLog.info(ctx, "App-Start: $pkg nicht gefunden"); return }
    // intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
    // if (Settings.canDrawOverlays(ctx)) try { ctx.startActivity(intent); EventLog.info(ctx, "App geöffnet: $label") ; return } catch (e: Exception) { EventLog.info(...) }
    // sonst/Fehler: Benachrichtigung Kanal CHANNEL_APP (IMPORTANCE_HIGH, Name „App-Start“),
    //   Titel "$label öffnen", Text "Dein Auto ist erkannt – tippe zum Öffnen.",
    //   ContentIntent = PendingIntent.getActivity(ctx, 6, intent, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT),
    //   autoCancel, Icon R.drawable.ic_car, ID 4; Berechtigung wie in TripService.notifyParked prüfen.
    //   EventLog.info(ctx, "App-Start: Hinweis gezeigt (Berechtigung „Über anderen Apps“ fehlt)")

fun close(ctx: Context)
    // pkg leer → return; Benachrichtigung ID 4 entfernen (NotificationManagerCompat.cancel)
    // if (Settings.canDrawOverlays(ctx)) try { ctx.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch …
    // Handler(Looper.getMainLooper()).postDelayed({ try { (ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager)?.killBackgroundProcesses(pkg) } catch … ; EventLog.info(ctx, "App geschlossen (Startbildschirm + beenden versucht): $label") }, 1500L)

fun listApps(ctx: Context): List<Map<String, String>>
    // queryIntentActivities(Intent(ACTION_MAIN).addCategory(CATEGORY_LAUNCHER), 0)
    // → package = activityInfo.packageName, label = loadLabel(pm).toString()
    // ohne eigenes Paket, doppelte Pakete entfernen, nach label (ignoreCase) sortieren
    // API 33+: queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0)), sonst @Suppress("DEPRECATION")
```
Als `ctx` immer `ctx.applicationContext` verwenden (Handler-Verzögerung).

### Anbindung
- `DeviceScanner`: neue Eigenschaft `var listener: ((found: Boolean, ok: Boolean) -> Unit)? = null`.
  - In `finishRound()` nach `logScan(...)`: `listener?.invoke(roundFound, true)`.
  - Bei fehlgeschlagener Runde (`logScan(..., false, ...)` in `runTransmitterRound`): `listener?.invoke(false, false)`.
  - In `closeBeaconWindow()` nach `logScan`: `listener?.invoke(windowHit, err == null)`.
  - Sofort-Treffer: `var onHit: (() -> Unit)? = null` – im ACTION_FOUND-Zweig und im
    BLE-Callback der Runde sowie im Beacon-Callback bei Treffer `onHit?.invoke()` aufrufen
    (alles läuft auf dem Main-Thread).
- `TripService.startScanning()`: nach `DeviceScanner(this)`:
  `s.onHit = { AppLauncher.seen(this) }` und
  `s.listener = { found, ok -> if (found) AppLauncher.seen(this) else if (ok) AppLauncher.miss(this, strong = !inVehicle) }`.
  (Nach EXIT ist `inVehicle == false` → letzte Runde zählt als „stark“.)
- `TripService.stopEverything()`: `AppLauncher.reset()`.
- `BeaconScanReceiver`: im Zweig, in dem `beacon_bg` geloggt wird, zusätzlich `AppLauncher.seen(context)`.
- `Notifications`: `CHANNEL_APP = "app"` (IMPORTANCE_HIGH, „App-Start“).
- Manifest: `<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>`,
  `<uses-permission android:name="android.permission.KILL_BACKGROUND_PROCESSES"/>`,
  in `<queries>`: `<intent><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent>`.
- `MainActivity` neue Methoden:
  - `listApps` → `AppLauncher.listApps(this)`
  - `openOverlaySettings` → `Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))`, Fallback ohne Uri
  - `testLaunch` → `AppLauncher.launch(this)`; `result.success(null)`
  - `getNativeStatus` zusätzlich `"overlayAllowed" to Settings.canDrawOverlays(this)`.

## Dart
- `NativeBridge`: `listApps()` → `List<Map<String,String>>`, `openOverlaySettings()`,
  `testLaunch()`; `setConfig` um `launchPackage`, `launchLabel`, `closeOnGone`
  erweitern (leerer String erlaubt!).
- `AppController.updateConfig` entsprechend erweitern.
- `SettingsPage`: neuer Abschnitt **„App im Auto“** (nur sichtbar, wenn
  `deviceMode != 'none'`):
  - ListTile „App öffnen, wenn das Gerät erkannt wird“, Untertitel = gewählte
    App oder „Keine“; Tippen → neue Seite `AppPickerPage` (Suchfeld + Liste
    Label/Paket; oben Eintrag „Keine App“) → `updateConfig(launchPackage, launchLabel)`.
  - SwitchListTile „Beim Aussteigen schließen“ (`closeOnGone`), Untertitel:
    „Wechselt zum Startbildschirm und beendet die App, wenn Android es erlaubt.
    Läuft sie mit eigener Benachrichtigung weiter, beende sie dort.“
  - Berechtigungszeile „Über anderen Apps einblenden“ (Status aus
    `getNativeStatus.overlayAllowed`, Knopf → `openOverlaySettings`), Hinweis:
    „Nötig, damit die App von selbst aufgeht. Ohne kommt eine Benachrichtigung
    zum Antippen.“
  - Knopf „Jetzt testen“ → `testLaunch`.
- `SetupState` um `overlay` erweitern (nicht Teil von `essentialsOk`).
- Diagnose-Text: `buildDiagnosticText` listet Config ohnehin; `describeEvent`
  zeigt `info` bereits.

## README
Abschnitt „Blitzer-App automatisch öffnen“ mit Einrichtung und der ehrlichen
Einschränkung beim Schließen.

## Tests
Keine neue Dart-Logik; `flutter analyze` ohne Fehler/Warnungen, `flutter test` grün.
