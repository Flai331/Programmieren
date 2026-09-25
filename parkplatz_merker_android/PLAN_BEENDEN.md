# Parkplatz-Merker – Plan „App beim Aussteigen komplett beenden“

Ergänzt `PLAN_APPSTART.md`. Bisher: Startbildschirm + `killBackgroundProcesses`
– das beendet Blitzer.de nicht, weil es mit eigener Benachrichtigung weiterläuft.
Neu, in dieser Reihenfolge in `AppLauncher.close()`:

1. **Ausschaltknopf in der Benachrichtigung** der App auslösen
   (NotificationListenerService). Funktioniert im Hintergrund, auch bei
   gesperrtem Bildschirm. Blitzer.de hat so einen Knopf.
2. Startbildschirm + `killBackgroundProcesses` wie bisher.
3. **Notfalls „Beenden erzwingen“ per Bedienungshilfe** (AccessibilityService):
   nur wenn eingeschaltet UND nach 4 s noch eine Benachrichtigung der App da ist
   (bzw. Schritt 1 nichts auslösen konnte). Braucht entsperrten Bildschirm;
   ist er gesperrt, wird es beim nächsten Entsperren erledigt (max. 30 min später).

## Neue Einstellungen (`Config`)
| Schlüssel | Typ | Standard | Bedeutung |
|---|---|---|---|
| `closeActionTitle` | String | `""` | gewählter Knopftext; `""` = automatisch |
| `forceStopFallback` | Boolean | `false` | Weg 3 erlaubt |

`getConfig`/`setConfig` um beide erweitern (wie bisher per `as?`).

## Kotlin

### `NotifListener.kt` – `class NotifListener : NotificationListenerService()`
Manifest:
```xml
<service android:name=".NotifListener" android:exported="true"
    android:label="Parkplatz-Merker"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter><action android:name="android.service.notification.NotificationListenerService"/></intent-filter>
</service>
```
```kotlin
companion object {
    @Volatile var instance: NotifListener? = null
    val STOP_WORDS = listOf("ausschalten", "beenden", "stopp", "stop", "aus", "schließen",
                            "exit", "quit", "close", "turn off", "off")

    /** Alle Knopftexte der Benachrichtigungen von [pkg] (für die Auswahl in der App). */
    fun actionTitles(pkg: String): List<String>
        // instance?.activeNotifications (in try/catch) → filter { it.packageName == pkg }
        // → notification.actions (kann null sein!) → title?.toString() → nicht leer, distinct

    /** Löst den Ausschaltknopf aus. true = etwas ausgelöst. */
    fun pressStop(pkg: String, wanted: String): Boolean
        // für jede aktive Benachrichtigung von pkg, jede action:
        //   title = action.title?.toString()?.trim() ?: continue
        //   passt, wenn wanted nicht leer: title.equals(wanted, ignoreCase = true)
        //          sonst: STOP_WORDS.any { w -> title.lowercase() == w || title.lowercase().startsWith("$w ") || title.lowercase().contains(w) && w.length >= 5 }
        //   → try { action.actionIntent.send() ; return true } catch (e: Exception) { weiter }
        // false

    fun hasNotification(pkg: String): Boolean
        // instance?.activeNotifications?.any { it.packageName == pkg } ?: false

    fun isEnabled(ctx: Context): Boolean
        // Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners")
        //   ?.split(":")?.any { ComponentName.unflattenFromString(it) == ComponentName(ctx, NotifListener::class.java) } == true
}
override fun onListenerConnected() { instance = this }
override fun onListenerDisconnected() { instance = null }
override fun onDestroy() { instance = null; super.onDestroy() }
```
`activeNotifications` kann `null` sein oder eine SecurityException werfen → abfangen.

### `ForceStopService.kt` – `class ForceStopService : AccessibilityService()`
Manifest:
```xml
<service android:name=".ForceStopService" android:exported="true"
    android:label="Parkplatz-Merker: App beenden"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter><action android:name="android.accessibilityservice.AccessibilityService"/></intent-filter>
    <meta-data android:name="android.accessibilityservice" android:resource="@xml/force_stop_service"/>
</service>
```
`res/xml/force_stop_service.xml`:
```xml
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows"
    android:canRetrieveWindowContent="true"
    android:notificationTimeout="200"
    android:description="@string/force_stop_description" />
```
`strings.xml`: `force_stop_description` = „Beendet beim Aussteigen die gewählte App (z. B. Blitzer.de), indem in der App-Info ‚Beenden erzwingen‘ gedrückt wird. Sonst liest oder ändert der Dienst nichts.“

Ablauf (alles Main-Thread):
```kotlin
companion object {
    @Volatile var instance: ForceStopService? = null
    private var pendingPkg: String? = null
    private var pendingSince = 0L
    fun isEnabled(ctx: Context): Boolean   // Settings.Secure ENABLED_ACCESSIBILITY_SERVICES enthält
                                           // ComponentName(ctx, ForceStopService::class.java).flattenToString() (ignoreCase)
    fun request(ctx: Context, pkg: String) // pendingPkg = pkg; pendingSince = now; instance?.tryRun()
                                           // instance == null → EventLog.info("Bedienungshilfe nicht aktiv")
}
private val FORCE_TEXTS = listOf("beenden erzwingen", "stopp erzwingen", "erzwungenes beenden",
    "erzwungener stopp", "force stop", "stoppen erzwingen")
private val FORCE_IDS = listOf("com.android.settings:id/force_stop_button",
    "com.android.settings:id/button3", "com.miui.securitycenter:id/am_force_stop")
private val OK_IDS = listOf("android:id/button1")
private val OK_TEXTS = listOf("ok", "beenden erzwingen", "stopp erzwingen", "force stop")
private var step = 0          // 0 frei, 1 warte auf Knopf, 2 warte auf Bestätigung
private var stepSince = 0L
private val handler = Handler(Looper.getMainLooper())
private var unlockReceiver: BroadcastReceiver? = null
```
- `onServiceConnected`: `instance = this`; Empfänger für `Intent.ACTION_USER_PRESENT`
  mit `ContextCompat.registerReceiver(this, r, IntentFilter(Intent.ACTION_USER_PRESENT), ContextCompat.RECEIVER_EXPORTED)` → `tryRun()`.
- `onUnbind`/`onDestroy`: Empfänger abmelden, `instance = null`.
- `tryRun()`: `pkg = pendingPkg ?: return`; älter als 30 min → verwerfen.
  Nur wenn `step == 0` und Bildschirm an und entsperrt:
  `(getSystemService(POWER_SERVICE) as PowerManager).isInteractive` und
  `!(getSystemService(KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked`.
  Dann `startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null)).addFlags(FLAG_ACTIVITY_NEW_TASK or FLAG_ACTIVITY_NO_HISTORY or FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS))`,
  `step = 1`, `stepSince = now`, Zeitlimit: nach 8 s `finish("Zeitlimit")`.
- `onAccessibilityEvent(event)`: `if (step == 0) return`; `root = rootInActiveWindow ?: return`.
  - `step == 1`: Knopf suchen: erst `FORCE_IDS` per `root.findAccessibilityNodeInfosByViewId(id)`,
    dann jeden Text aus `FORCE_TEXTS` per `root.findAccessibilityNodeInfosByText(text)`
    (Treffer mit `node.text?.toString()?.lowercase()?.contains(text) == true`).
    Gefunden: wenn `!node.isEnabled` → App läuft schon nicht mehr → `finish("lief nicht mehr")`.
    Sonst `click(node)` → `step = 2`.
  - `step == 2`: erst `OK_IDS`, dann `OK_TEXTS` (Text genau gleich, ignoreCase) → `click(node)` →
    `finish("beendet")`.
- `click(node)`: node oder erster klickbarer Elternknoten (`node.parent` Schleife, max. 5)
  → `performAction(AccessibilityNodeInfo.ACTION_CLICK)`.
- `finish(reason)`: `EventLog.info(this, "Beenden erzwingen ($pkg): $reason")`; `pendingPkg = null`;
  `step = 0`; Zeitlimit-Runnable entfernen; nach 500 ms `performGlobalAction(GLOBAL_ACTION_HOME)`.
- `onInterrupt() {}`.
- Nie etwas anderes anklicken; außerhalb von step 1/2 nichts tun.

### `AppLauncher.close(ctx, fromForeground: Boolean = false)` neu
```
pkg leer → return; Benachrichtigung 4 entfernen
val pressed = NotifListener.pressStop(pkg, Config.closeActionTitle)
EventLog.info(… if (pressed) "Ausschaltknopf von $label gedrückt" else "Kein Ausschaltknopf gefunden (Benachrichtigungszugriff an?)")
Startbildschirm (wenn fromForeground || canDrawOverlays) wie bisher
nach 1,5 s killBackgroundProcesses wie bisher
if (Config.forceStopFallback) nach 4 s:
    if (!pressed || NotifListener.hasNotification(pkg)) ForceStopService.request(appCtx, pkg)
```

### `MainActivity` neue Methoden
- `listCloseActions` → `NotifListener.actionTitles(Config.launchPackage)` (Liste Strings)
- `testClose` → `AppLauncher.close(this, fromForeground = true)`; `result.success(null)`
- `openNotificationListenerSettings` → `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`
- `openAccessibilitySettings` → `Settings.ACTION_ACCESSIBILITY_SETTINGS`
- `getNativeStatus` zusätzlich `"notificationListener" to NotifListener.isEnabled(this)`,
  `"accessibility" to ForceStopService.isEnabled(this)`.

## Dart
- `NativeBridge`: `listCloseActions()`, `testClose()`, `openNotificationListenerSettings()`,
  `openAccessibilitySettings()`; `setConfig` + `AppController.updateConfig` um
  `closeActionTitle` (String, leer erlaubt) und `forceStopFallback` (bool).
- `SetupState` um `notificationListener`, `accessibility` erweitern.
- `SettingsPage`, Abschnitt „App im Auto“, unter „Beim Aussteigen schließen“
  (nur sichtbar, wenn eine App gewählt ist und `closeOnGone` an):
  1. `_PermTile` „Benachrichtigungszugriff“ – Hinweis: „Damit der Ausschaltknopf in der
     Benachrichtigung der App gedrückt werden kann – klappt auch bei gesperrtem Handy.“ →
     `openNotificationListenerSettings`.
  2. ListTile „Ausschaltknopf“, Untertitel: gewählter Text oder „automatisch (Ausschalten,
     Beenden, Stopp …)“. Knopf „Wählen“ → `listCloseActions()`; leer → SnackBar
     „Öffne zuerst ${launchLabel}, damit ihre Benachrichtigung da ist.“; sonst Dialog mit
     „Automatisch“ + den Texten → `updateConfig(closeActionTitle: …)`.
  3. SwitchListTile „Notfalls ‚Beenden erzwingen‘ (Bedienungshilfe)“ (`forceStopFallback`),
     Untertitel: „Öffnet kurz die App-Info und drückt ‚Beenden erzwingen‘. Nur bei entsperrtem
     Handy – sonst beim nächsten Entsperren.“
  4. Wenn `forceStopFallback`: `_PermTile` „Bedienungshilfe“ → `openAccessibilitySettings`,
     Hinweis: „Einstellungen → Bedienungshilfen → Installierte Apps → ‚Parkplatz-Merker: App
     beenden‘ einschalten. Ausgegraut? Erst ‚Eingeschränkte Einstellungen zulassen‘.“
  5. ListTile „Beenden jetzt testen“ → `testClose()`.

## README
Abschnitt „Blitzer-App komplett beenden“: beide Wege, Einrichtung, Einschränkungen.

## Prüfen
`flutter analyze` ohne Fehler/Warnungen, `flutter test` grün, Kotlin Zeile für Zeile.
