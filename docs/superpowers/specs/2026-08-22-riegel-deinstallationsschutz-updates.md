# Riegel – Deinstallationsschutz mit Update-Ausnahme

Backlog-Eintrag (Notion, 20.08.2026, offen):

> „bei aktualisierungen soll der deinstallierungsschutz nicht greifen – bei normaler
> deinstalierung der App nur wenn eine Sperre aktiv ist"

Dieses Dokument ist die Umsetzungsvorlage dafür. Es wurde geschrieben, **ohne** den
Riegel-Quellcode einsehen zu können (der liegt lokal auf Branch `feature/nfc-riegel`).
Alle Stellen, die vom bestehenden Code abhängen, sind als *Annahme* markiert.

---

## 1. Was heute passiert (vermutete Ursache)

Der Deinstallationsschutz besteht bei solchen Apps typischerweise aus zwei Bausteinen:

| Baustein | Wirkung | Blockiert Updates? |
|---|---|---|
| **Device Admin** (`DeviceAdminReceiver`) | Android verweigert die Deinstallation, solange der Admin aktiv ist | **Nein** – ein Update über dasselbe Signatur-Zertifikat läuft normal durch |
| **Accessibility-Guard** | erkennt Installer-/Einstellungs-Screens und drückt sie mit `GLOBAL_ACTION_BACK` weg | **Ja** – wenn er pauschal auf das Installer-Paket reagiert |

Der Update-Dialog („App aktualisieren?") kommt aus **demselben Paket** wie der
Deinstallations-Dialog (`com.android.packageinstaller` bzw.
`com.google.android.packageinstaller`). Wer nur auf `event.packageName` prüft, wirft
beide Dialoge weg – deshalb lässt sich die App nicht mehr aktualisieren.

**Kernaussage:** Es reicht nicht, das Installer-*Paket* zu erkennen. Es muss der
*Screen* unterschieden werden.

---

## 2. Zielverhalten

| Situation | Sperre aktiv | Verhalten |
|---|---|---|
| APK-Update wird installiert (eigenes Paket) | egal | **durchlassen** |
| Deinstallation der App | ja | **blockieren** + Hinweis anzeigen |
| Deinstallation der App | nein | **erlauben** (inkl. Device-Admin sauber lösen) |
| Deinstallation einer *anderen* App | egal | **durchlassen** |
| „Beenden erzwingen" / Daten löschen (Riegel) | ja | blockieren (Bestandsverhalten) |
| nach abgeschlossenem Update | ja | Sperre und Guard müssen automatisch weiterlaufen |

---

## 3. Update vs. Deinstallation unterscheiden

### Weg A (primär): Activity-Klassenname aus dem AccessibilityEvent

AOSP nutzt getrennte Activities, und `AccessibilityEvent.className` liefert sie mit:

* Installieren/Aktualisieren: `…packageinstaller.InstallStart`,
  `…PackageInstallerActivity`, `…InstallStaging`, `…InstallInstalling`, `…InstallSuccess`
* Deinstallieren: `…packageinstaller.UninstallerActivity`, `…UninstallUninstalling`

Wichtig: „Uninstall" enthält die Zeichenkette „install" – **zuerst auf Uninstall prüfen**.

```kotlin
object InstallerScreens {
    private val INSTALLER_PACKAGES = setOf(
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.samsung.android.packageinstaller",   // One UI
        "com.miui.packageinstaller",
        "com.oplus.packageinstaller",
    )

    fun isInstallerPackage(pkg: String?) = pkg != null && pkg in INSTALLER_PACKAGES

    fun isUninstallScreen(className: String?) =
        className?.contains("uninstall", ignoreCase = true) == true

    fun isInstallScreen(className: String?) =
        className?.contains("install", ignoreCase = true) == true && !isUninstallScreen(className)
}
```

### Weg B (Absicherung): `PackageInstaller.SessionCallback`

Ein Update erzeugt immer eine Installer-Session mit `appPackageName == packageName`;
eine Deinstallation erzeugt **keine** Session. Damit lässt sich ein kurzes Update-Fenster
öffnen, *bevor* der Dialog überhaupt erscheint – nützlich bei Hersteller-Skins, deren
Klassennamen von AOSP abweichen.

```kotlin
private val sessionCallback = object : PackageInstaller.SessionCallback() {
    override fun onCreated(sessionId: Int) = check(sessionId)
    override fun onBadgingChanged(sessionId: Int) = check(sessionId)   // appPackageName erst hier sicher gesetzt
    override fun onFinished(sessionId: Int, success: Boolean) { updateWindow.close(sessionId) }
    override fun onActiveChanged(sessionId: Int, active: Boolean) {}
    override fun onProgressChanged(sessionId: Int, progress: Float) {}

    private fun check(sessionId: Int) {
        val info = packageManager.packageInstaller.getSessionInfo(sessionId) ?: return
        if (info.appPackageName == packageName) {
            updateWindow.open(sessionId, ttl = 3.minutes)   // Guard pausiert Installer-Screens
        }
    }
}
```

Registrierung im Guard-Service (`registerSessionCallback(sessionCallback, handler)`),
Deregistrierung in `onDestroy`. Das Fenster ist bewusst kurz und wird beim
`onFinished` sofort geschlossen; es erlaubt **nur** Install-Screens, nie den
Uninstall-Screen.

### Weg C (Fallback): Textprüfung im Dialog

Wenn weder Klassenname noch Session greifen: `rootInActiveWindow` nach Schlüsselwörtern
absuchen („deinstallieren" / „uninstall" vs. „aktualisieren" / „update") **und** prüfen,
ob der eigene App-Name überhaupt im Dialog vorkommt. Nur dann blockieren – sonst würde
Riegel auch die Deinstallation fremder Apps verhindern.

```kotlin
private fun dialogMentionsOurApp(): Boolean {
    val root = rootInActiveWindow ?: return false
    val label = applicationInfo.loadLabel(packageManager).toString()
    return root.findAccessibilityNodeInfosByText(label).isNotEmpty()
}
```

### Warum `ACTION_MY_PACKAGE_REPLACED` nicht ausreicht

Der Broadcast kommt **nach** dem Update – er kann den weggedrückten Dialog nicht retten.
Er wird trotzdem gebraucht, siehe Abschnitt 5.

---

## 4. Guard nur bei aktiver Sperre

Zweiter Teil des Backlog-Eintrags: ohne aktive Sperre soll sich Riegel normal
deinstallieren lassen.

```kotlin
// eine einzige Wahrheit, überall verwendet
private fun guardActive(): Boolean = lockState.isAnyLockActive()   // Annahme: existiert bereits als StateFlow/Repository
```

Im Accessibility-Service:

```kotlin
override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
    val pkg = event.packageName?.toString()
    val cls = event.className?.toString()

    if (InstallerScreens.isInstallerPackage(pkg)) {
        when {
            InstallerScreens.isUninstallScreen(cls) ->
                if (guardActive() && dialogMentionsOurApp()) block(Reason.UNINSTALL)
            // Install-/Update-Screens: nie blockieren
            else -> Unit
        }
        return
    }
    // Einstellungen → App-Info, Force-Stop usw. wie bisher, aber ebenfalls hinter guardActive()
}

private fun block(reason: Reason) {
    performGlobalAction(GLOBAL_ACTION_BACK)
    notifyBlocked(reason)   // kurzer Toast/Notification: „Sperre aktiv – erst entsperren"
}
```

### Device-Admin-Seite

Solange der Device Admin aktiv ist, verweigert Android die Deinstallation **immer** –
auch ohne aktive Sperre. Damit „normal deinstallieren" wirklich funktioniert, gehört
dazu:

```kotlin
// DeviceAdminReceiver
override fun onDisableRequested(context: Context, intent: Intent): CharSequence? =
    if (lockState.isAnyLockActive())
        context.getString(R.string.admin_disable_warning_lock_active)
    else
        null   // keine Sperre → keine Abschreckung

// In-App-Button „Riegel deinstallieren", nur sichtbar wenn keine Sperre aktiv
fun uninstallSelf(context: Context) {
    check(!lockState.isAnyLockActive())
    dpm.removeActiveAdmin(adminComponent)      // eigene App darf sich selbst als Admin entfernen
    context.startActivity(
        Intent(Intent.ACTION_DELETE, Uri.parse("package:${context.packageName}"))
    )
}
```

Alternative (falls kein extra Button gewünscht): Admin automatisch entfernen, sobald die
letzte Sperre endet, und beim Aktivieren der nächsten Sperre neu anfordern. Nachteil:
bei jeder Sperre erscheint der System-Dialog zur Admin-Aktivierung. Deshalb ist der
In-App-Button die bessere Wahl.

---

## 5. Zustand nach dem Update wiederherstellen

Ein Update stoppt die App, killt Foreground-Services und löscht alle `AlarmManager`-Alarme.
Ohne Wiederherstellung wäre eine laufende Sperre nach dem Update tot.

```xml
<receiver android:name=".update.PackageReplacedReceiver" android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
    </intent-filter>
</receiver>
```

Der Receiver muss:
1. den Foreground-/Guard-Service neu starten,
2. aktive Sperren aus der DB laden und Ablauf-Alarme neu setzen,
3. ein eventuell offenes Update-Fenster schließen,
4. die neue Build-Nummer für Fehlerberichte übernehmen.

Der Accessibility-Service selbst bleibt aktiviert (die Systemeinstellung überlebt das
Update), wird aber neu gebunden – Zustand im Service also nicht als „läuft schon"
voraussetzen.

---

## 6. Grenzen (bewusst offen)

* **Abgesicherter Modus:** Accessibility-Services sind dort aus. Nur der Device Admin
  schützt weiterhin vor Deinstallation.
* **`adb uninstall`:** scheitert bei aktivem Device Admin mit
  `DELETE_FAILED_DEVICE_POLICY_MANAGER` – gewollt.
* **`adb install -r` / Play-Store-Update:** kein Dialog, also nie betroffen. Das Problem
  tritt nur beim manuellen APK-Update auf dem Gerät auf.
* **Hersteller-Skins:** One UI/MIUI benennen Installer-Activities teils anders – dafür
  ist Weg B die Absicherung.
* **Mehrbenutzer/Arbeitsprofil:** nicht betrachtet.

---

## 7. Testmatrix

| # | Aktion | Sperre aktiv | Erwartet |
|---|---|---|---|
| 1 | APK-Update über Dateimanager installieren | ja | Dialog bleibt stehen, Update läuft durch |
| 2 | APK-Update über Dateimanager installieren | nein | wie 1 |
| 3 | Nach Test 1: App öffnen | ja | Sperre unverändert aktiv, Restzeit stimmt, Guard scharf |
| 4 | Icon lange drücken → Deinstallieren | ja | blockiert, Hinweis erscheint |
| 5 | Icon lange drücken → Deinstallieren | nein | Deinstallation möglich |
| 6 | Einstellungen → Apps → Riegel → Deinstallieren | ja | blockiert |
| 7 | Einstellungen → Apps → Riegel → Beenden erzwingen | ja | blockiert |
| 8 | Fremde App deinstallieren | ja | nicht blockiert |
| 9 | In-App „Riegel deinstallieren" | nein | Admin weg, System-Dialog erscheint |
| 10 | Neustart nach Update | ja | Sperre und Guard laufen weiter |

---

## 8. Zu prüfen, sobald der Code vorliegt

1. Wird der Schutz über Device Admin, Accessibility oder beides umgesetzt?
2. Wie heißt die zentrale Abfrage „ist gerade eine Sperre aktiv"? Gibt es sie schon,
   oder prüft der Guard bisher unabhängig davon?
3. Reagiert der Guard aktuell auf `packageName` (dann Abschnitt 3 A einbauen) oder schon
   auf Screens?
4. Existiert bereits ein `MY_PACKAGE_REPLACED`-Receiver oder nur `BOOT_COMPLETED`?
5. Gibt es einen Wiederherstellungspfad für Alarme, den der Receiver mitbenutzen kann?
