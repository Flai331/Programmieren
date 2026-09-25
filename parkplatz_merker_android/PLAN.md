# Parkplatz-Merker Android – Plan

Flutter-App (nur Android), die **automatisch** merkt, wo das Auto abgestellt
wurde. Beim Öffnen: „Dein Auto steht seit 14:32 hier“ + Karte + Knopf
„Navigation zum Auto“ (Fußweg in Google Maps).

Das Handy wird im Auto **nicht** per Bluetooth verbunden. Ein
Bluetooth-FM-Transmitter (oder ein USB-BLE-Beacon) darf nur **gesehen**
werden (Gerätesuche), **niemals** gekoppelt oder verbunden:
kein `createBond`, kein `connectGatt`, kein `createRfcommSocket…`,
kein `BluetoothProfile`/`getProfileProxy`. Das wird bei der Prüfung per grep
kontrolliert.

Oberfläche und Texte: Deutsch, Anrede „du“. Kein Server, alle Daten lokal.

**Regel für jede neue Funktion:** Die Anleitung kommt immer auch in die App –
neuer bzw. ergänzter Abschnitt in `lib/pages/help_page.dart` (Seite „Anleitung“,
erreichbar über das ?-Symbol auf der Startseite und in den Einstellungen; passende
Einstellungs-Abschnitte verlinken per `HelpPage.show(context, HelpTopic.…)`).
Zusätzlich kurz im README.

Ordner: `parkplatz_merker_android/` (bereits mit `flutter create` angelegt,
Paket `parkplatz_merker`, Application-ID und Kotlin-Paket
`com.klaasotte.parkplatz_merker`, App-Name „Parkplatz-Merker“).
Flutter: `/tmp/claude-0/sdk/flutter/bin` (3.47.1) – vorher
`export PATH=/tmp/claude-0/sdk/flutter/bin:$PATH`. Kein Android-SDK im
Container: Kotlin kann lokal **nicht** gebaut werden → besonders sorgfältig
schreiben; die APK baut GitHub Actions.

---

## 1. Aufteilung

- **Kotlin** (`android/app/src/main/kotlin/com/klaasotte/parkplatz_merker/`)
  läuft auch bei geschlossener App: empfängt Aktivitätsübergänge, betreibt
  während der Fahrt einen Foreground-Service (Standort alle 30 s,
  Bluetooth-Suche, Ladezustand) und schreibt **nur Rohereignisse** als
  JSON-Zeilen in ein Journal. Keine Parkplatz-Entscheidung in Kotlin
  (Ausnahme: wann der Service sich beendet, Abschnitt 4.4).
- **Dart** holt beim Öffnen/Fortsetzen der App die Rohereignisse ab,
  speichert sie und berechnet daraus mit **reinen, getesteten Funktionen**
  die Parkplätze (kurze Fahrten/Halte filtern, Quellen zusammenführen,
  Bus/Taxi-Regel, Standortwahl). Dart zeigt die Oberfläche.
- Verbindung: `MethodChannel('parkplatz_merker/native')`.

## 2. Rohereignisse (Journal-Format, verbindlich für Kotlin UND Dart)

Datei `filesDir/events.jsonl`, eine JSON-Zeile pro Ereignis. Kotlin hängt an
(`EventLog.append`), Dart holt mit `drainEvents` ab (liefert Zeilen und leert
die Datei; beides unter derselben Sperre – wie `EventLog.kt` im
Spotify-Merker). Maximal 20 000 Zeilen, sonst ältere Hälfte verwerfen.

Alle Zeiten: Millisekunden seit Epoche (`Long`). Gemeinsame Felder:
`"type"` (String) und `"t"` (Zeitpunkt des Ereignisses).

| type | weitere Felder | Bedeutung |
|---|---|---|
| `activity` | `activity` (`IN_VEHICLE`, `WALKING`, `RUNNING`, `STILL`, `ON_BICYCLE`, `UNKNOWN`), `transition` (`ENTER`/`EXIT`), `rx` (Empfangszeit) | Aktivitätsübergang. `t` = aus `elapsedRealTimeNanos` umgerechnet (siehe 4.2) |
| `loc` | `lat`, `lng` (Double), `acc` (Double, Meter), `reason` (`periodic`, `exit`, `manual`, `last_known`) | Standort. `t` = `location.time` |
| `service` | `state` (`start`/`stop`), `mode` (`none`/`transmitter`/`beacon`), `target` (Adresse oder null), `reason` (String) | Fahrt-Service gestartet/beendet |
| `scan` | `mode` (`transmitter`/`beacon`), `target` (Adresse), `end` (Long), `ok` (Bool), `found` (Bool), `rssi` (Int oder null), `error` (String oder null) | Eine Suchrunde (Transmitter: klassisch ~12 s + BLE; Beacon: 2-Min.-Fenster). `t` = Start der Runde |
| `beacon_bg` | `target`, `rssi` | Treffer des Hintergrund-PendingIntent-Scans (höchstens 1 pro Minute geloggt) |
| `power` | `plugged` (Bool), `reason` (`initial`/`change`) | Ladekabel dran/ab |
| `manual` | `source` (`widget`/`tile`/`app`), `lat`, `lng`, `acc` (alle drei fehlen/null, wenn kein Standort), `error` (String oder null) | „Hier geparkt“ gedrückt |
| `info` | `msg` (String) | Freitext für Diagnose (Fehler, Registrierung ok, …) |

Dart muss unbekannte `type`-Werte und fehlende Felder tolerieren (nicht
abstürzen, Zeile ignorieren bzw. nur in der Diagnose zeigen).

## 3. MethodChannel `parkplatz_merker/native`

Alle Zahlen aus Dart kommen als `Number` an: in Kotlin
`(call.argument<Any>("lat") as? Number)?.toDouble()`. Jeder Aufruf in
`try/catch` → `result.error("NATIVE_ERROR", e.message, null)`.

| Methode | Argumente | Rückgabe |
|---|---|---|
| `drainEvents` | – | `List<String>` (JSON-Zeilen) |
| `getConfig` | – | Map: `activityEnabled` (Bool, Std. true), `chargerEnabled` (Bool, Std. true), `deviceMode` (`none`/`transmitter`/`beacon`, Std. `none`), `deviceAddress` (String?), `deviceName` (String?) |
| `setConfig` | dieselben Schlüssel (nur vorhandene werden geändert) | `null`; danach Transitions (neu) registrieren bzw. abmelden und Hintergrund-Beacon-Scan starten/stoppen |
| `registerTransitions` | – | Map `{ok: Bool, error: String?}` |
| `getCurrentLocation` | – | Map `{lat, lng, acc, t}` oder `null` (hohe Genauigkeit, max. 30 s, sonst letzte bekannte) – asynchron, `result.success` im Callback auf dem Main-Thread |
| `getLastLocation` | – | wie oben, nur letzte bekannte (schnell) oder `null` |
| `reverseGeocode` | `lat`, `lng` | String (z. B. „Hauptstraße 5, 12345 Musterstadt“) oder `null` |
| `openNavigation` | `lat`, `lng` | `Bool` (gestartet) |
| `startDeviceSearch` | – | `{ok, error}`; startet klassische Discovery + unfiltertem BLE-Scan für 15 s |
| `getSearchResults` | – | `{running: Bool, devices: List<Map>}`; je Gerät `address`, `name` (String?), `rssi` (Int), `classic` (Bool), `ble` (Bool) |
| `stopDeviceSearch` | – | `null` |
| `scheduleReminder` | `atMs` (Long), `text` (String) | `Bool` |
| `cancelReminder` | – | `null` |
| `getNativeStatus` | – | Map: `sdkInt`, `playServices` (Bool), `transitionsRegistered` (Bool), `transitionsError` (String?), `transitionsAt` (Long?), `bluetoothEnabled` (Bool), `locationEnabled` (Bool), `ignoringBatteryOptimizations` (Bool), `serviceRunning` (Bool), `inVehicle` (Bool), `exactAlarms` (Bool) |
| `openAppDetails` | – | `null` (Settings.ACTION_APPLICATION_DETAILS_SETTINGS) |
| `openBatterySettings` | – | `null` (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS mit `package:`-Uri, Fallback ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS) |

Nur ein Reminder gleichzeitig (gilt immer für den aktuellen Parkplatz).

## 4. Kotlin im Detail

### 4.1 Gradle / Manifest
`android/app/build.gradle.kts` (Aufbau wie
`spotify_merker_android/android/app/build.gradle.kts`, **gleiche**
Signatur-Logik), Unterschiede:
- `minSdk = 26`
- Signatur-Datei **mitbenutzen**, nicht kopieren:
  `storeFile = file("../../../spotify_merker_android/android/app/merker-release.p12")`,
  `storeType = "pkcs12"`, `keyAlias = "merker"`, Passwort aus
  `System.getenv("MERKER_KEYSTORE_PASSWORD")`, sonst Debug-Signatur.
- `dependencies { implementation("com.google.android.gms:play-services-location:21.3.0"); implementation("androidx.core:core-ktx:1.16.0") }`

`AndroidManifest.xml` (main), Berechtigungen:
```
INTERNET
ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION
ACTIVITY_RECOGNITION
com.google.android.gms.permission.ACTIVITY_RECOGNITION   (für Android < 10)
FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION
POST_NOTIFICATIONS
RECEIVE_BOOT_COMPLETED
REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
BLUETOOTH (android:maxSdkVersion="30"), BLUETOOTH_ADMIN (android:maxSdkVersion="30")
BLUETOOTH_SCAN   (OHNE android:usesPermissionFlags="neverForLocation"!)
BLUETOOTH_CONNECT (nur für Gerätenamen)
USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM (android:maxSdkVersion="32")
```
`<uses-feature android:name="android.hardware.bluetooth" android:required="false"/>`,
dito `bluetooth_le`. KEIN `CAMERA` (sonst scheitert der Kamera-Intent von image_picker).

`<queries>`: PROCESS_TEXT (Vorlage), `<package android:name="com.google.android.apps.maps"/>`,
`<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="geo"/></intent>`,
`<intent><action android:name="android.media.action.IMAGE_CAPTURE"/></intent>`.

Komponenten:
- `TripService` – `android:foregroundServiceType="location"`, `exported="false"`.
- `TransitionReceiver` (exported=false).
- `BootReceiver` (exported=true) mit `BOOT_COMPLETED` und `MY_PACKAGE_REPLACED`.
- `BeaconScanReceiver` (exported=false).
- `ReminderReceiver` (exported=false).
- `ParkWidgetProvider` (exported=true, `APPWIDGET_UPDATE`, meta-data
  `android.appwidget.provider` → `@xml/park_widget_info`).
- `ParkTileService` – `android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"`,
  exported=true, Intent-Filter `android.service.quicksettings.action.QS_TILE`,
  `android:icon="@drawable/ic_parking"`, `android:label="Hier geparkt"`.
- `ParkHereActivity` – transparent (`@android:style/Theme.Translucent.NoTitleBar`),
  `exported="false"`, `excludeFromRecents="true"`, `noHistory="true"`,
  `taskAffinity=""`.

Ladezustand: `ACTION_POWER_CONNECTED/DISCONNECTED` sind seit Android 8
**nicht** mehr per Manifest empfangbar → dynamisch im `TripService`
registrieren (der läuft genau dann, wenn es zählt).

Ressourcen: `res/drawable/ic_parking.xml` (Vektor, weißes „P“ im
abgerundeten Quadrat, 24dp), `res/drawable/ic_car.xml` (Vektor Auto, für
Benachrichtigung), `res/layout/park_widget.xml` (LinearLayout mit
abgerundetem Hintergrund `res/drawable/widget_bg.xml`, ImageView ic_parking
+ TextView „Hier geparkt“, Gesamt-ID `widget_root`),
`res/xml/park_widget_info.xml` (minWidth 110dp, minHeight 40dp,
`updatePeriodMillis="0"`, `initialLayout="@layout/park_widget"`,
`resizeMode="horizontal"`, `widgetCategory="home_screen"`,
`description="@string/widget_description"`), `res/values/strings.xml`
(`widget_description` = „Merkt den aktuellen Standort als Parkplatz“).

### 4.2 Dateien und Klassen

**`EventLog.kt`** – `object EventLog { fun append(ctx, json: JSONObject); fun drain(ctx): List<String>; fun info(ctx, msg) }`
wie Spotify-Merker (Sperre, Kürzung). `info` hängt `{type:"info", t, msg}` an.

**`Config.kt`** – `object Config` über SharedPreferences `"parkplatz_config"`:
`activityEnabled`, `chargerEnabled`, `deviceMode`, `deviceAddress`,
`deviceName`, plus Status `transitionsRegistered`, `transitionsError`,
`transitionsAt`, `reminderAt` (Long, 0 = keiner), `reminderText`,
`lastBeaconBgLog` (Long). Getter/Setter als Funktionen mit `Context`.

**`Transitions.kt`** – `object Transitions`:
- `register(ctx, callback: ((Boolean, String?) -> Unit)? = null)`:
  Wenn `activityEnabled == false` → `unregister` und fertig. Sonst Anfrage mit
  ENTER+EXIT für `IN_VEHICLE`, `WALKING`, `RUNNING`, `STILL`
  (**nicht** `ON_FOOT` – wird von der Transition-API nicht unterstützt).
  `ActivityRecognition.getClient(ctx).requestActivityTransitionUpdates(request, pendingIntent(ctx))`
  mit Success/Failure-Listener → Config-Status + `EventLog.info` + callback.
  Fehlende Berechtigung (`SecurityException`) abfangen.
  Vor dem Aufruf prüfen: API ≥ 29 → `ACTIVITY_RECOGNITION` erteilt?
  (`ContextCompat.checkSelfPermission`); sonst Fehler „Berechtigung
  Aktivitätserkennung fehlt“ melden.
- `pendingIntent(ctx)`: `PendingIntent.getBroadcast(ctx, 1, Intent(ctx, TransitionReceiver::class.java), FLAG_UPDATE_CURRENT or FLAG_MUTABLE)`
  (FLAG_MUTABLE ist Pflicht, Play Services füllt Extras ein; minSdk 26 →
  `FLAG_MUTABLE` gibt es erst ab API 31: `val flags = if (Build.VERSION.SDK_INT >= 31) FLAG_UPDATE_CURRENT or FLAG_MUTABLE else FLAG_UPDATE_CURRENT`).
- `unregister(ctx)`: `removeActivityTransitionUpdates(pendingIntent(ctx))`.
- Name-Hilfen: `activityName(Int)`, `transitionName(Int)`.

**`TransitionReceiver.kt`** – `onReceive`:
`if (!ActivityTransitionResult.hasResult(intent)) return`;
`val result = ActivityTransitionResult.extractResult(intent) ?: return`.
Für jedes Ereignis:
`t = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - e.elapsedRealTimeNanos) / 1_000_000`
→ `activity`-Ereignis loggen (`rx = System.currentTimeMillis()`).
Danach (nur einmal pro Intent, letztes relevantes Ereignis zählt, in
zeitlicher Reihenfolge verarbeiten):
- `IN_VEHICLE ENTER` → `TripService.start(ctx, TripService.ACTION_ENTER)`
- `IN_VEHICLE EXIT` → `TripService.start(ctx, TripService.ACTION_EXIT)`
- `WALKING`/`RUNNING` `ENTER` → nur wenn `TripService.running` →
  `TripService.start(ctx, TripService.ACTION_WALKING)`

**`TripService.kt`** – `class TripService : Service()`.
Companion: `@Volatile var running = false`, `@Volatile var inVehicle = false`,
Actions `ACTION_ENTER`, `ACTION_EXIT`, `ACTION_WALKING`, `ACTION_MANUAL`
(Extra `source`), `fun start(ctx, action, source: String? = null)` →
`ContextCompat.startForegroundService` in try/catch (Fehler → `EventLog.info`).

`onStartCommand`: **immer zuerst** `startInForeground()`:
`ServiceCompat.startForeground(this, NOTIF_ID, notification, if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0)`
in try/catch (Exception → `EventLog.info("Service-Start fehlgeschlagen: …")`,
`stopSelf()`, `return START_NOT_STICKY`). Benachrichtigung: Kanal `trip`
(IMPORTANCE_LOW, Name „Fahrt“), Titel „Fahrt erkannt“, Text „Parkplatz wird
beim Aussteigen gemerkt“ (bei MANUAL: „Standort wird bestimmt …“),
`ongoing`, kleines Icon `R.drawable.ic_car`, ContentIntent öffnet MainActivity
(`FLAG_IMMUTABLE`). Beim ersten Start: `running = true`,
`service start`-Ereignis (mit `mode`/`target` aus Config, wobei
`mode = none` wenn keine Adresse gesetzt), Hard-Timeout 8 h.
Rückgabe `START_NOT_STICKY`.

Aktionen:
- `ENTER`: `inVehicle = true`, geplantes Beenden abbrechen, Standort-Updates
  starten (falls nicht aktiv), Ladeempfänger registrieren (falls
  `chargerEnabled` und nicht aktiv) und aktuellen Zustand als
  `power reason=initial` loggen (sticky `ACTION_BATTERY_CHANGED`,
  `EXTRA_PLUGGED != 0`), Suchschleife starten (falls `deviceMode != none`
  und Adresse gesetzt und nicht aktiv).
- `EXIT`: `inVehicle = false`; eine **letzte** Suchrunde sofort
  (nur Transmitter-Modus; im Beacon-Modus das laufende Fenster sofort
  abschließen und `scan`-Ereignis loggen), danach Suchschleife stoppen;
  `getCurrentLocation` (hoch, 30 s) → `loc reason=exit`; Beenden planen in
  **3 min** (Standort-Updates laufen bis dahin weiter).
- `WALKING`: wenn `!inVehicle` und Beenden geplant → Beenden auf
  „in 60 s“ vorziehen (nie später als bereits geplant).
- `MANUAL`: `getCurrentLocation` → `manual`-Ereignis mit `source`, Standort
  bzw. `error`; zusätzlich `loc reason=manual`. Danach Benachrichtigung
  (Kanal `parked`, IMPORTANCE_DEFAULT, auto-cancel) „Parkplatz gemerkt ✓“
  bzw. „Standort nicht verfügbar“. Wenn der Service nur für MANUAL lief
  (`!inVehicle` und kein Beenden geplant und keine Standort-Updates) →
  `stopEverything()`.

Standort: `LocationServices.getFusedLocationProviderClient(this)`,
`LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 30_000L).setMinUpdateIntervalMillis(15_000L).build()`,
`LocationCallback` → jede Position als `loc reason=periodic`.
Einmal-Standort (gemeinsame Hilfsfunktion `LocationHelper.current(ctx, cb: (Location?) -> Unit)`
in eigener Datei `LocationHelper.kt`, auch vom MethodChannel genutzt):
`CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY).setDurationMillis(30_000L).setMaxUpdateAgeMillis(10_000L).build()`
→ `getCurrentLocation(request, null)`; bei `null` oder Fehler →
`lastLocation`; Callback genau **einmal** aufrufen (AtomicBoolean). Alle
Aufrufe in try/catch `SecurityException` → callback(null). `LocationHelper.toMap(Location)`
und `LocationHelper.toJson(Location, reason)` bereitstellen.

Suchschleife: `Handler(Looper.getMainLooper())`, alle **120 s** (erste
Runde sofort) eine Runde über `DeviceScanner` (unten).

`stopEverything()`: Handler-Callbacks entfernen, Standort-Updates entfernen,
Ladeempfänger abmelden (try/catch), `DeviceScanner` stoppen
(cancelDiscovery/stopScan), `service stop`-Ereignis, `running = false`,
`inVehicle = false`, `ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)`,
`stopSelf()`. Auch aus `onDestroy` (idempotent über Flag).

**`DeviceScanner.kt`** – Klasse mit `Context`, **nie** koppeln/verbinden.
- `hasScanPermission(ctx)`: API ≥ 31 → `BLUETOOTH_SCAN`, sonst
  `ACCESS_FINE_LOCATION`. Ohne Berechtigung, ohne Adapter oder bei
  ausgeschaltetem Bluetooth → Runde mit `ok=false, error=…` loggen.
- Transmitter-Runde (`runTransmitterRound(target, onDone)`):
  Empfänger für `BluetoothDevice.ACTION_FOUND` + `BluetoothAdapter.ACTION_DISCOVERY_FINISHED`
  registrieren (API ≥ 33: `registerReceiver(r, filter, Context.RECEIVER_EXPORTED)`
  – System-Broadcasts; darunter ohne Flag. `ContextCompat.registerReceiver(ctx, r, filter, ContextCompat.RECEIVER_EXPORTED)` erledigt beides),
  `adapter.cancelDiscovery()` dann `adapter.startDiscovery()`; parallel
  BLE-Scan mit `ScanFilter.Builder().setDeviceAddress(target)`,
  `ScanSettings.SCAN_MODE_BALANCED`. Treffer, wenn `device.address.equals(target, ignoreCase = true)`;
  RSSI klassisch aus `intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)`,
  BLE aus `result.rssi`; bester RSSI merken. Nach **12 s** (Handler):
  `cancelDiscovery()`, `stopScan`, Empfänger abmelden, `scan`-Ereignis
  (`ok=true`, `found`, `rssi`), `onDone()`. `BluetoothDevice` aus Intent:
  API ≥ 33 `getParcelableExtra(EXTRA_DEVICE, BluetoothDevice::class.java)`,
  sonst `@Suppress("DEPRECATION") getParcelableExtra<BluetoothDevice>(EXTRA_DEVICE)`
  (oder `IntentCompat.getParcelableExtra`).
- Beacon-Betrieb (`startBeaconWindowed(target)`): dauerhafter gefilterter
  BLE-Scan (`SCAN_MODE_LOW_POWER`) mit Callback; `lastHitRssi`/`hitInWindow`
  merken. Alle 120 s (vom TripService-Handler aufgerufen:
  `closeBeaconWindow()`) → `scan`-Ereignis mit `t` = Fensterstart,
  `found = hitInWindow`, dann Fenster zurücksetzen.
- Setup-Suche (`startSearch()`, `results()`, `stopSearch()`): Discovery +
  **unfilterter** BLE-Scan (`SCAN_MODE_LOW_LATENCY`) für 15 s, Ergebnisse in
  `LinkedHashMap<String, DeviceInfo>` (Adresse → name, rssi, classic, ble).
  Name: klassisch `intent.getStringExtra(BluetoothDevice.EXTRA_NAME)`, BLE
  `result.scanRecord?.deviceName`; zusätzlich `device.name` **nur** wenn
  (API < 31 oder `BLUETOOTH_CONNECT` erteilt), in try/catch
  `SecurityException`. Als Singleton im MethodChannel-Handler halten.
- Alle BT-Aufrufe mit `@SuppressLint("MissingPermission")` nach eigener
  Berechtigungsprüfung, zusätzlich `try/catch (SecurityException)`.
- Adapter: `(ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter`.

**`BeaconBackground.kt`** – `object`: `start(ctx)` wenn `deviceMode == beacon`
und Adresse gesetzt: `bluetoothLeScanner.startScan(listOf(filter), settings(LOW_POWER), pendingIntent)`,
PendingIntent → `BeaconScanReceiver`, requestCode 2,
Flags wie bei Transitions (`FLAG_MUTABLE` ab 31). `stop(ctx)` →
`stopScan(pendingIntent)`. Fehler → `EventLog.info`.
**`BeaconScanReceiver.kt`**: Ergebnisse aus
`BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT` (API ≥ 33 typisiert, sonst
deprecated), bei Treffer höchstens 1× pro 60 s (Config `lastBeaconBgLog`)
`beacon_bg`-Ereignis. Kein Service-Start von hier.

**`BootReceiver.kt`**: `Transitions.register(ctx)`, `BeaconBackground.start(ctx)`,
Reminder neu setzen, falls `reminderAt > now`.

**`Reminder.kt`** – `object Reminder`: `schedule(ctx, atMs, text)`:
Config speichern, `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, atMs, pi)`;
wenn API ≥ 31 und `!alarmManager.canScheduleExactAlarms()` →
`setAndAllowWhileIdle`. `cancel(ctx)`. PendingIntent → `ReminderReceiver`,
`FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE`.
**`ReminderReceiver.kt`**: Benachrichtigung Kanal `reminder`
(IMPORTANCE_HIGH, „Parkschein“), Titel „Parkschein läuft bald ab“, Text aus
Config, öffnet App; danach Config `reminderAt = 0`. Vor `notify`
Berechtigung `POST_NOTIFICATIONS` prüfen (API ≥ 33) bzw.
`NotificationManagerCompat.areNotificationsEnabled()`.

**`Notifications.kt`** – `object Notifications { fun ensureChannels(ctx) }`
legt Kanäle `trip`, `parked`, `reminder` an (minSdk 26 → immer).

**`ParkHereActivity.kt`** – `onCreate`: `TripService.start(this, ACTION_MANUAL, intent.getStringExtra("source") ?: "widget")`,
Toast „Standort wird gemerkt …“, `finish()`. (Aus einer sichtbaren
Activity darf der Foreground-Service gestartet werden.)

**`ParkWidgetProvider.kt`** – `onUpdate`: für jede ID
`RemoteViews(packageName, R.layout.park_widget)` mit
`setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(ctx, 3, Intent(ctx, ParkHereActivity::class.java).putExtra("source","widget").addFlags(FLAG_ACTIVITY_NEW_TASK), FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE))`.

**`ParkTileService.kt`** – `TileService`: `onStartListening` → Tile-Label
„Hier geparkt“, `state = Tile.STATE_INACTIVE`, `updateTile()`.
`onClick` → Intent auf ParkHereActivity (`source=tile`, NEW_TASK); API ≥ 34:
`startActivityAndCollapse(PendingIntent.getActivity(this, 4, intent, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT))`,
sonst `@Suppress("DEPRECATION") startActivityAndCollapse(intent)`.

**`MainActivity.kt`** – MethodChannel aus Abschnitt 3. In `onCreate`/
`configureFlutterEngine`: `Notifications.ensureChannels(this)`.
- `openNavigation`: `String.format(Locale.US, "%.7f,%.7f", lat, lng)`
  (**Locale.US**, sonst Komma im deutschen Gebietsschema!).
  Zuerst `Intent(ACTION_VIEW, Uri.parse("google.navigation:q=$ll&mode=w")).setPackage("com.google.android.apps.maps")`;
  bei `ActivityNotFoundException` → `geo:$ll?q=$ll(Mein Auto)` (Uri-encodiert
  mit `Uri.encode("Mein Auto")`); gelingt beides nicht → `false`.
- `reverseGeocode`: `Geocoder.isPresent()` prüfen; API ≥ 33
  `getFromLocation(lat, lng, 1, listener)` (Callback, dann `runOnUiThread { result.success(...) }`,
  `onError` → null); darunter in einem `Thread { }` die deprecated
  synchrone Variante, Ergebnis per `runOnUiThread`. Text:
  `address.getAddressLine(0)`, sonst aus thoroughfare/subThoroughfare/postalCode/locality.
  `Geocoder(this, Locale.GERMANY)`.
- `getCurrentLocation`/`getLastLocation` über `LocationHelper`, Ergebnis
  immer auf dem Main-Thread liefern.
- `setConfig` → Config speichern, dann `Transitions.register(this)` und
  `BeaconBackground.stop(this)`; `BeaconBackground.start(this)`.
- `getNativeStatus`: `GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this) == ConnectionResult.SUCCESS`;
  `LocationManagerCompat.isLocationEnabled(lm)`;
  `PowerManager.isIgnoringBatteryOptimizations(packageName)`;
  `exactAlarms` = API < 31 oder `canScheduleExactAlarms()`.
- `onResume` der Activity: nichts Besonderes (Dart holt selbst ab).

### 4.3 Kotlin-Stolpersteine (beim Schreiben beachten)
- Bitoperationen: `or`/`and` sind Infix-Funktionen mit **niedrigerer**
  Priorität als `==`, `!=`, `<`. Immer klammern:
  `(flags and X) != 0`, niemals `flags and X != 0`.
- Jede Klasse, die man benutzt, importieren (z. B. `android.os.Build`,
  `android.content.pm.ServiceInfo`, `androidx.core.app.ServiceCompat`,
  `androidx.core.content.ContextCompat`, `com.google.android.gms.location.*`
  einzeln importieren, keine Sternchen-Importe nötig aber erlaubt).
- APIs über minSdk 26 nur hinter `if (Build.VERSION.SDK_INT >= N)`.
- Nullbarkeit: `intent` in `onStartCommand` ist `Intent?`; `intent?.action`.
- Kein `!!` außer wo garantiert; lieber `?: return`.

### 4.4 Wann der Service endet (einzige Logik in Kotlin)
Beenden geplant = 3 min nach EXIT, bei WALKING/RUNNING-ENTER nach EXIT
vorgezogen auf 60 s danach; neues IN_VEHICLE-ENTER hebt es auf. Hard-Timeout
8 h. MANUAL ohne Fahrt: nach dem Standort beenden.

## 5. Dart

### 5.1 Pakete
Schon in `pubspec.yaml`: `flutter_map`, `latlong2`, `path_provider`,
`permission_handler`, `image_picker`. Sonst keine neuen Pakete.

### 5.2 Dateien
```
lib/
  main.dart                 App, Theme (Material 3, seedColor Colors.indigo), Startseite als home
  native.dart               NativeBridge (MethodChannel-Wrapper, Methoden aus Abschnitt 3)
  storage.dart              JSON-Dateien im App-Dokumente-Ordner
  controller.dart           AppController (ChangeNotifier): abholen, speichern, berechnen
  logic/
    models.dart             RawEvent, LocSample, ParkingSpot
    detection.dart          detectParkings(...) und Hilfsfunktionen
    spots.dart              mergeSpots(...)
    format.dart             Zeit-/Distanz-Texte, haversine
    diagnostics.dart        Diagnose-Text
  pages/
    home_page.dart
    spot_view.dart          Karte + Details eines Parkplatzes (Startseite & Verlauf)
    history_page.dart
    settings_page.dart
    search_page.dart
    diagnostics_page.dart
test/
  detection_test.dart
  spots_test.dart
  format_test.dart
  diagnostics_test.dart
```
`test/widget_test.dart` (Vorlage) löschen.

### 5.3 Modelle (`logic/models.dart`)
```dart
class RawEvent {
  final String type; final int t; final Map<String, dynamic> data;
  // data = komplette JSON-Map (inkl. type/t)
  static RawEvent? tryParse(String line);           // null bei Müll
  factory RawEvent.fromJson(Map<String, dynamic> m); // t fehlt → 0
  Map<String, dynamic> toJson();                    // = data
  String? str(String k); double? dbl(String k); int? integer(String k); bool? boolean(String k);
}
class LocSample { final int t; final double lat, lng, acc; }
class ParkingSpot {
  final String id;           // 'auto-<tripStart>' oder 'manual-<t>'
  final int time;            // Ausstiegszeitpunkt (ms)
  final double lat, lng, acc;
  final List<String> sources;  // z. B. ['Aussteigen', 'Transmitter weg']
  final bool manual;
  final String? note, photoPath, address;
  final int? reminderAt;     // Parkschein-Ende (ms) oder null
  String get sourceLabel;    // sources.join(' + ')
  ParkingSpot copyWith({...}); // für note/photoPath/address/reminderAt; Nullen erlauben über clear-Flags (clearNote, clearPhoto, clearReminder)
  Map<String, dynamic> toJson(); factory ParkingSpot.fromJson(Map<String, dynamic>);
}
```

### 5.4 Erkennung (`logic/detection.dart`) – reine Funktionen
Konstanten (oben in der Datei):
```dart
const minTripMs = 3 * 60 * 1000;        // Fahrten < 3 min ignorieren
const shortHaltMs = 2 * 60 * 1000;      // Halte < 2 min gehören zur Fahrt
const noWalkFinalizeMs = 15 * 60 * 1000;// ohne Gehen: nach 15 min trotzdem Parkplatz
const chargerBeforeExitMs = 10 * 60 * 1000;
const afterExitMs = 5 * 60 * 1000;
const locWindowMs = 2 * 60 * 1000;
const locFallbackMs = 10 * 60 * 1000;
```

`class Trip { int start; int exit?; bool walkedAfterExit; ... }`

`List<Trip> buildTrips(List<RawEvent> events)` (Ereignisse nach `t`
sortieren; nur `activity`-Ereignisse zählen):
1. Keine offene Fahrt + `IN_VEHICLE ENTER` → neue Fahrt `start = t`.
2. Offene Fahrt + `IN_VEHICLE EXIT` → `exit = t`, `walkedAfterExit = false`.
3. Fahrt mit `exit` + `WALKING`/`RUNNING` `ENTER` mit `t >= exit - 60 s`
   → `walkedAfterExit = true`, `walkT` = erstes solches `t`.
4. Fahrt mit `exit` + erneutes `IN_VEHICLE ENTER` bei `t2`:
   - `t2 - exit < shortHaltMs` → **gleiche Fahrt** (Ampel/Stau/kurzer Halt):
     `exit = null`, `walkedAfterExit = false`.
   - sonst, wenn **nicht** `walkedAfterExit` und kein starker Hinweis
     (Ladekabel ab / Gerät weg, s. u.) im Fenster `[exit - chargerBeforeExitMs, t2]`
     → **gleiche Fahrt** (langer Stau ohne Aussteigen).
   - sonst Fahrt abschließen, neue Fahrt ab `t2`.
5. Doppelte `ENTER` (Fahrt schon offen, ohne exit) ignorieren; `EXIT` ohne
   offene Fahrt ignorieren.

`List<ParkingSpot> detectParkings(List<RawEvent> events, int now)`:
für jede Fahrt mit `exit != null`:
- **Kurz**: `exit - start < minTripMs` → verwerfen.
- **Fertig?** Nur wenn kein erneutes IN_VEHICLE ENTER folgt (sonst hätte
  buildTrips zusammengeführt/abgeschlossen) und `now - exit >= shortHaltMs`
  und (`walkedAfterExit` **oder** starker Hinweis **oder**
  `now - exit >= noWalkFinalizeMs`). Bei abgeschlossener Fahrt (es folgte
  eine neue Fahrt) ist sie fertig, wenn Schritt 4 sie abgeschlossen hat.
- Ereignisfenster der Fahrt: `[start - 2 min, min(exit + afterExitMs, nächster Fahrtstart)]`.
- **Gerät** (`scan`-Ereignisse im Fenster, nach `t` sortiert):
  - `deviceChecked` = mind. ein `scan` mit `ok == true`.
  - `seen` = ein `scan` mit `found == true` im Fenster **oder** ein `beacon_bg`
    im Fenster.
  - `gone`: letzter Scan mit `found == true` sei `lastSeen`; der erste
    spätere Scan mit `ok == true && found == false` sei `firstMiss`. Wenn
    beide existieren → Gerät weg im Intervall `(lastSeen.t, firstMiss.t]`.
  - Modus-Name für den Text: `mode` des Scans: `transmitter` → „Transmitter
    weg“, `beacon` → „Beacon weg“.
  - **Bus/Taxi-Regel**: `deviceChecked && !seen` → **kein** Parkplatz
    (`rejected = 'Gerät nie gesehen – vermutlich nicht dein Auto'`).
    Schlagen alle Scans fehl (`ok == false`), gilt die Regel **nicht**.
- **Ladekabel**: `power`-Ereignisse im Fenster. Kandidat = das **letzte**
  `plugged == false` mit `reason == 'change'`, dessen `t` in
  `[exit - chargerBeforeExitMs, exit + afterExitMs]` liegt, vor dem der
  Zustand „eingesteckt“ war (ein früheres `plugged == true` im Fenster) und
  nach dem bis Fensterende kein `plugged == true` mehr kommt.
- **Ausstiegszeitpunkt** (bester verfügbarer):
  1. Ladekabel-Kandidat → `t` = Abziehzeit.
  2. sonst Gerät weg → wenn `exit` im Intervall `(lastSeen.t, firstMiss.t]`
     liegt: `exit`, sonst `firstMiss.t`.
  3. sonst `exit`.
- **Quellen** (`sources`, in dieser Reihenfolge, nur vorhandene):
  „Aussteigen“ (immer), „Ladekabel ab“, „Transmitter weg“/„Beacon weg“.
- **Standort**: `pickLocation(samples, t)` mit allen `loc`-Ereignissen
  (alle `reason`s):
  - Kandidaten mit `|s.t - t| <= locWindowMs`; Bewertung
    `score = |s.t - t| / 1000 + s.acc / 2` (kleiner = besser) → bester.
  - sonst nächster nach Zeit innerhalb `locFallbackMs`.
  - sonst `null` → kein Parkplatz (Fahrt ohne Standort).
- Ergebnis: `ParkingSpot(id: 'auto-${trip.start}', time: t, lat/lng/acc aus Probe, sources, manual: false)`.

Zusätzlich jedes `manual`-Ereignis mit `lat`/`lng` →
`ParkingSpot(id: 'manual-${t}', time: t, sources: ['Manuell (Widget)'|'Manuell (Kachel)'|'Manuell (App)'], manual: true)`.

Für Tests und Diagnose zusätzlich öffentlich:
`class TripResult { Trip trip; ParkingSpot? spot; String status; }` und
`List<TripResult> evaluateTrips(events, now)` – `status` z. B. „läuft“,
„zu kurz“, „wartet auf Aussteigen“, „Gerät nie gesehen – vermutlich nicht
dein Auto“, „kein Standort“, „Parkplatz“. `detectParkings` baut darauf auf.
`bool tripInProgress(events, now)` = letzte Fahrt ohne `exit`.

### 5.5 Parkplatzliste (`logic/spots.dart`)
`List<ParkingSpot> mergeSpots(List<ParkingSpot> existing, List<ParkingSpot> detected, Set<String> deletedIds, {int max = 30})`:
- IDs in `deletedIds` nie aufnehmen.
- Neue IDs hinzufügen.
- Existierende ID + erkannter Eintrag: `time/lat/lng/acc/sources`
  übernehmen, `note/photoPath/reminderAt` **behalten**; `address` nur
  behalten, wenn lat/lng gleich geblieben sind, sonst `null`.
- Existierende, die nicht mehr erkannt werden (z. B. alte Rohereignisse
  schon gelöscht) **behalten**.
- Nach `time` absteigend sortieren, auf `max` kürzen.

### 5.6 Texte (`logic/format.dart`)
- `double haversineMeters(lat1, lng1, lat2, lng2)`.
- `String formatDistance(double m)`: `< 1000` → „350 m“ (auf 10 m gerundet,
  unter 100 m auf 5 m), sonst „1,2 km“ (Komma!).
- `String formatClock(DateTime)` → „14:32“.
- `String sinceText(DateTime parked, DateTime now)`: gleicher Tag →
  „seit 14:32“, gestern → „seit gestern, 14:32“, sonst „seit Mo., 22.09., 14:32“
  (Wochentage `Mo. Di. Mi. Do. Fr. Sa. So.`, ohne intl-Paket).
- `String headline(ParkingSpot s, DateTime now)` → „Dein Auto steht seit 14:32 hier“.
- `String accuracyText(double acc)` → „Genauigkeit ± 12 m“.
- `String formatDateTime(DateTime)` → „22.09. 14:32“.

### 5.7 Diagnose (`logic/diagnostics.dart`)
- `List<RawEvent> diagnosticEvents(List<RawEvent> all, {int limit = 100})`:
  nach `t` sortiert; `loc` mit `reason == 'periodic'` ausdünnen (höchstens
  eins pro 5 Minuten), dann die letzten `limit`.
- `String describeEvent(RawEvent e)` → eine Zeile, z. B.
  `22.09. 14:32:05  Aktivität IN_VEHICLE ENTER`,
  `…  Suche Transmitter: gefunden (RSSI -61)` / `nicht gefunden` / `Fehler: …`,
  `…  Laden: eingesteckt`, `…  Standort 52.52001, 13.40495 ± 8 m (exit)`,
  `…  Manuell (widget)`, `…  Service start (transmitter AA:BB:…)`, `…  Info: …`,
  unbekannt → JSON.
- `DeviceStats deviceStats(List<RawEvent> all, String? address)`:
  `scans` (Anzahl ok), `hits`, `lastSeen` (int?), `lastRssi` (int?).
- `String buildDiagnosticText({events, permissions (Map<String,String>), nativeStatus (Map), config (Map), tripResults (List<TripResult>)})`
  → kompletter Text zum Kopieren: Kopf („Parkplatz-Merker Diagnose“, Zeit),
  Berechtigungen, Native-Status, Einstellungen, Gerät-Statistik, letzte
  10 Fahrten mit Status, dann die Ereignisse.

### 5.8 Speicher (`storage.dart`)
Dateien in `getApplicationDocumentsDirectory()`: `events.json`
(Liste der Roh-JSON-Maps), `spots.json`, `deleted.json` (IDs). Schreiben
atomar (`.tmp` schreiben, dann `rename`). Rohereignisse älter als **3 Tage**
und über **5000** verwerfen. Fotos in `photos/<spotId>.jpg` (Datei aus
image_picker dorthin kopieren).

### 5.9 Controller (`controller.dart`)
`AppController extends ChangeNotifier` mit `NativeBridge` und `Storage`
(beide per Konstruktor, für Tests austauschbar).
- `refresh()`: `drainEvents` → parsen → an gespeicherte anhängen (nach
  `t` sortiert, doppelte Zeilen vermeiden über gleiche JSON-Zeichenkette),
  speichern → `detectParkings(events, now)` → `mergeSpots` → speichern →
  fehlende Adresse für den neuesten Parkplatz per `reverseGeocode` holen
  und speichern → `getLastLocation` für Entfernung → `notifyListeners()`.
- Aufrufe: beim Start, bei `AppLifecycleState.resumed`, und alle 15 s per
  `Timer.periodic` solange die App im Vordergrund ist.
- `parkHere()`: `getCurrentLocation`; bei Erfolg `manual`-RawEvent
  (`source: 'app'`) in die Ereignisliste, dann neu berechnen; sonst Fehler
  zurückgeben („Standort nicht verfügbar – ist GPS an?“).
- `deleteSpot(id)`: aus Liste, zu `deleted`, Foto löschen, falls es der
  neueste war und ein Reminder läuft → `cancelReminder`.
- `setNote`, `setPhoto`, `removePhoto`, `setReminder(spotId, DateTime until)`:
  Erinnerung = `until - 15 min`; liegt die in der Vergangenheit → Fehler
  „Das ist in weniger als 15 Minuten – keine Erinnerung möglich.“;
  `scheduleReminder(at, 'Dein Parkschein läuft um HH:MM ab.')`.
  `clearReminder`.
- Getter: `spots`, `latest`, `myLocation` (LocSample?), `tripRunning`,
  `events`, `config`.

### 5.10 Oberfläche
**Startseite** (`home_page.dart`, AppBar „Parkplatz-Merker“, Aktionen:
Verlauf-Icon, Einstellungen-Icon):
- Wenn Einrichtung unvollständig (Standort „Immer“, Aktivitätserkennung
  oder Benachrichtigungen fehlen): Karte oben „Einrichtung unvollständig –
  tippe hier“ → Einstellungen.
- Wenn `tripRunning`: Hinweis-Zeile „🚗 Fahrt läuft – der Parkplatz wird
  beim Aussteigen gemerkt.“
- Kein Parkplatz: Leerzustand „Noch kein Parkplatz gemerkt. Fahr einfach
  los – oder tippe auf „Hier geparkt“.“
- Sonst `SpotView(spot, myLocation)`.
- Unten groß: `FilledButton.icon` „Hier geparkt“ (Spinner während der
  Standortsuche; Ergebnis per SnackBar „Parkplatz gemerkt“).

**SpotView** (`spot_view.dart`):
- Überschrift `headline(...)` (groß).
- Karte (`FlutterMap`, Höhe 260, `MapOptions(initialCenter: LatLng, initialZoom: 17)`,
  `TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.klaasotte.parkplatz_merker')`,
  `MarkerLayer` mit Auto-Marker (Icons.directions_car in Kreis) und – falls
  bekannt – „Ich“-Marker (blauer Punkt), `RichAttributionWidget` mit
  `TextSourceAttribution('OpenStreetMap-Mitwirkende')`). `key: ValueKey(spot.id)`,
  damit die Karte bei neuem Parkplatz neu zentriert.
- Zeilen: Adresse (oder „Adresse wird gesucht …“/„Keine Adresse
  verfügbar“), `accuracyText`, „Entfernung: 350 m“ (wenn eigener Standort
  bekannt), „erkannt über: Aussteigen + Transmitter weg“.
- `FilledButton.icon` „Navigation zum Auto“ → `openNavigation`; `false` →
  SnackBar „Keine Karten-App gefunden“.
- Notiz (Text, falls vorhanden) + Foto (`Image.file`, Tippen = Vollbild).
  Knöpfe: „Notiz“ (Dialog mit TextField, Hinweis „z. B. Parkhaus Ebene 3,
  Platz 112“), „Foto“ (BottomSheet: „Kamera“ / „Galerie“ / „Foto
  entfernen“; `ImagePicker().pickImage(source, maxWidth: 1600, imageQuality: 80)`),
  „Parkschein“ (`showTimePicker` → „Parkschein bis 16:00 · Erinnerung
  15:45“ anzeigen, zweiter Tipp: „Erinnerung löschen“). Liegt die
  gewählte Uhrzeit vor jetzt → nächster Tag.
- „Falsch erkannt“ (TextButton, rot) → Bestätigungsdialog „Diesen Eintrag
  löschen?“ → `deleteSpot`.

**Verlauf** (`history_page.dart`): Liste der bis zu 30 Einträge:
`formatDateTime`, Adresse bzw. Koordinaten, Quelle; Tippen → Seite mit
`SpotView`; Wischen/Knopf „Falsch erkannt“ mit Bestätigung.

**Einstellungen** (`settings_page.dart`):
- Abschnitt „Erkennung“: Schalter „Aktivitätserkennung (Aussteigen)“,
  „Ladekabel als Hinweis“; Auswahl „Gerät im Auto“ (`SegmentedButton`:
  Keins / Transmitter / Beacon); gewähltes Gerät (Name + Adresse) mit
  Knopf „Transmitter suchen“ bzw. „Beacon suchen“ → SearchPage.
  Kurzer Erklärtext: „Die App verbindet sich nie mit dem Gerät – sie
  schaut nur, ob es in der Nähe ist.“
- Abschnitt „Einrichtung“ (je Zeile Status ✓/✗ + Knopf „Erlauben“):
  1. Standort (`Permission.locationWhenInUse`), 2. Standort „Immer
  erlauben“ (`Permission.locationAlways`, erst nach 1; Hinweis: „Im
  nächsten Fenster ‚Immer zulassen‘ wählen“), 3. Aktivitätserkennung
  (`Permission.activityRecognition`), 4. Bluetooth-Suche
  (`Permission.bluetoothScan` + `Permission.bluetoothConnect`, nur nötig
  bei Gerät ≠ Keins), 5. Benachrichtigungen (`Permission.notification`),
  6. Akku „Nicht eingeschränkt“ (`getNativeStatus.ignoringBatteryOptimizations`,
  Knopf → `openBatterySettings`). Nach jedem Erteilen `registerTransitions`.
  `permanentlyDenied` → `openAppSettings()`.
- Hinweis-Karte: „Schalter ausgegraut oder ‚Eingeschränkte Einstellung‘?
  Android sperrt manche Einstellungen für Apps, die nicht aus dem Play
  Store kommen. Freigeben: App-Info öffnen → oben rechts ⋮ →
  ‚Eingeschränkte Einstellungen zulassen‘.“ + Knopf „App-Info öffnen“.
- Eintrag „Diagnose“ → DiagnosticsPage.

**Gerätesuche** (`search_page.dart`, Titel „Transmitter suchen“ bzw.
„Beacon suchen“):
- Hinweis-Karte: „Auto an, Handy NICHT mit dem Transmitter verbunden.“
  (Beacon: „Auto an, Beacon eingesteckt.“)
- Vor dem Start Berechtigungen `bluetoothScan`, `bluetoothConnect`,
  `locationWhenInUse` anfragen.
- Knopf „Suche starten“ → `startDeviceSearch`, dann jede Sekunde
  `getSearchResults` bis `running == false` (Fortschrittsbalken 15 s).
- Liste nach RSSI absteigend: Name (oder „(ohne Namen)“), Adresse,
  „RSSI -58 dBm“, Chips „klassisch“/„BLE“. Tippen → Dialog „Dieses Gerät
  verwenden?“ → `setConfig(deviceMode, deviceAddress, deviceName)` →
  zurück. Tipp-Text: „Tipp: Schalte den Transmitter einmal aus und wieder
  an – das Gerät, das dann erscheint/verschwindet, ist deins.“
- Beim Verlassen `stopDeviceSearch`.

**Diagnose** (`diagnostics_page.dart`): Gerät (Name, Adresse, „zuletzt
gesehen: 22.09. 14:32 (RSSI -61)“ bzw. „noch nie gesehen“, Anzahl Suchen/
Treffer), Berechtigungen (Status-Namen), Native-Status, letzte Fahrten mit
Status, dann die letzten 100 Ereignisse (`describeEvent`, Monospace,
`SelectableText`). Knopf „Kopieren“ (AppBar) →
`Clipboard.setData(ClipboardData(text: buildDiagnosticText(...)))` +
SnackBar „Diagnose kopiert“.

## 6. Tests (Pflicht, `flutter test` muss grün sein)
`test/detection_test.dart` – Hilfsfunktionen zum Bauen von Ereignissen
(`act(tMin, 'IN_VEHICLE', 'ENTER')`, `loc(tMin, lat, lng, acc)`, `scan(...)`,
`power(...)`); Zeiten in Minuten ab einer Basis:
1. Normale Fahrt 0–20 min, EXIT 20, WALKING 21, loc bei 20 → Parkplatz bei
   loc(20), Quellen `['Aussteigen']`, id `auto-<start>`.
2. Fahrt 2 min → kein Parkplatz („zu kurz“).
3. Ampel: EXIT 10, ENTER 11, EXIT 30, WALKING 31 → **ein** Parkplatz
   (Zeit 30).
4. Langer Stau: EXIT 10, ENTER 15 ohne WALKING, EXIT 30, WALKING 31 → ein
   Parkplatz (30).
5. Noch nicht fertig: EXIT 20, now = 21 → keiner; now = 23 + WALKING 21 → einer.
6. Ohne WALKING: now = exit + 16 min → Parkplatz.
7. Bus/Taxi: Scans ok & nie gefunden → kein Parkplatz; Status enthält
   „nicht dein Auto“.
8. Scans alle `ok: false` → Parkplatz trotzdem.
9. Transmitter weg: gefunden 12,14,16; nicht gefunden 18; EXIT 20 →
   Zeit 18 (firstMiss), Quellen enthalten „Transmitter weg“.
10. Transmitter weg + EXIT im Intervall (16,18] (EXIT 17) → Zeit 17.
11. Ladekabel: plugged true (initial) 1, false (change) 19, EXIT 20 →
    Zeit 19, Quellen `['Aussteigen','Ladekabel ab', …]`, Vorrang vor
    Transmitter.
12. Ladekabel ab mitten in der Fahrt (min 5) und wieder dran 6, ab 19 → 19.
13. pickLocation: nähere, ungenaue vs. etwas spätere genaue Probe (Score).
14. Kein Standort innerhalb 10 min → kein Parkplatz.
15. Manuelles Ereignis → Parkplatz `manual-…`, Quelle „Manuell (Widget)“.
16. Zwei Fahrten hintereinander (mit Gehen dazwischen) → zwei Parkplätze.

`test/spots_test.dart`: Notiz/Foto bleiben bei Aktualisierung, gelöschte
IDs bleiben weg, max 30, Sortierung, Adresse wird bei neuer Position
verworfen.
`test/format_test.dart`: sinceText (heute/gestern/älter), formatDistance
(„350 m“, „1,2 km“), haversine (bekannte Strecke ±1 %).
`test/diagnostics_test.dart`: Ausdünnen periodischer Standorte, Limit 100,
describeEvent für jeden Typ, deviceStats.

## 7. Bau & Auslieferung
`.github/workflows/parkplatz-merker-apk.yml` = Kopie von
`spotify-merker-apk.yml` mit: Name „Parkplatz-Merker APK Build“, Pfade
`parkplatz_merker_android/**` und die eigene Workflow-Datei,
`working-directory: parkplatz_merker_android`, Artefakt
`Parkplatz-Merker-${{ github.sha }}`, Release-Tag `parkplatz-merker-android`,
Datei `Parkplatz-Merker.apk`, Titel „Parkplatz-Merker“, Notes „Automatisch
gebaut aus main. Installation: siehe parkplatz_merker_android/README.md“.
Gleiche Signatur-Prüfung (Secret `MERKER_KEYSTORE_PASSWORD`).
`--build-number=${{ github.run_number }}`.

`README.md`: Installation (Download-Link
`https://github.com/Flai331/Programmieren/releases/download/parkplatz-merker-android/Parkplatz-Merker.apk`),
Einrichtung Schritt für Schritt, „So testest du, ob die App deinen
Transmitter sieht“, Funktionsweise, Datenschutz (alles lokal), Diagnose.

## 8. Arbeitspakete
1. **Native** (Kotlin, Manifest, Gradle, Ressourcen, Workflow).
2. **Logik + Tests** (`lib/logic/*`, `test/*`) – `flutter test` grün.
3. **Oberfläche** (`native.dart`, `storage.dart`, `controller.dart`,
   `pages/*`, `main.dart`, README) – `flutter analyze` ohne Fehler.
4. **Prüfung** durch den Planer: Kotlin Zeile für Zeile (Imports,
   Nullbarkeit, API-Level, `and`/`or`-Klammerung), grep auf
   `createBond|connectGatt|createRfcomm|getProfileProxy`, CI-Lauf grün.
