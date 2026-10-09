package de.klaas.akku_schoner

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "akku_schoner/native"

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getBattery" -> result.success(BatteryInfo.read(this))
                        "getStatus" -> result.success(status())
                        "listApps" -> Thread {
                            val apps = try { Apps.list(this) } catch (e: Exception) { emptyList() }
                            runOnUiThread { result.success(apps) }
                        }.start()
                        "setLevel" -> {
                            Prefs.setOverride(this, call.argument<String>("pkg") ?: "", call.argument<String>("level"))
                            result.success(null)
                        }
                        "killBackground" ->
                            result.success(Apps.killBackground(this, call.argument<List<String>>("pkgs") ?: emptyList()))
                        "forceStop" ->
                            result.success(ForceStopService.request(this, call.argument<List<String>>("pkgs") ?: emptyList()))
                        "cancelForceStop" -> {
                            ForceStopService.cancel()
                            result.success(null)
                        }
                        "forceStopState" -> result.success(ForceStopService.state())
                        "getWatcher" -> result.success(Prefs.getWatcher(this))
                        "setWatcher" -> {
                            val map = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                            Prefs.setWatcher(this, map)
                            if (Prefs.serviceNeeded(this)) askNotificationPermission()
                            WatcherService.sync(this)
                            result.success(null)
                        }
                        "openAppDetails" -> {
                            val pkg = call.argument<String>("pkg") ?: ""
                            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null)))
                            result.success(null)
                        }
                        "openSettings" -> {
                            open(settingsIntent(call.argument<String>("name") ?: ""))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native", e.message, null)
                }
            }
    }

    private fun status(): Map<String, Any> {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return mapOf(
            "usageAccess" to Apps.hasUsageAccess(this),
            "accessibility" to ForceStopService.isEnabled(this),
            "accessibilityConnected" to (ForceStopService.instance != null),
            "notifications" to nm.areNotificationsEnabled(),
            "watcherRunning" to WatcherService.running,
            "unrestricted" to pm.isIgnoringBatteryOptimizations(packageName),
            "sdk" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
        )
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    private fun settingsIntent(name: String): Intent = when (name) {
        "usage" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        "batterySaver" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        "batteryUsage" -> Intent(Intent.ACTION_POWER_USAGE_SUMMARY)
        "batteryOptimization" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
        "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
        "nfc" -> Intent(Settings.ACTION_NFC_SETTINGS)
        "sync" -> Intent(Settings.ACTION_SYNC_SETTINGS)
        "dataSaver" -> if (Build.VERSION.SDK_INT >= 28) Intent(Settings.ACTION_DATA_USAGE_SETTINGS)
            else Intent(Settings.ACTION_WIRELESS_SETTINGS)
        "notifications" -> if (Build.VERSION.SDK_INT >= 26)
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
        "appInfo" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
        "samsungBattery" -> samsungIntent("com.samsung.android.sm.ui.battery.BatteryActivity")
        "samsungSleeping" -> samsungIntent("com.samsung.android.sm.ui.appsleeping.AppSleepSettingActivity")
        else -> Intent(Settings.ACTION_SETTINGS)
    }

    /** Samsung "Gerätewartung" – Klassennamen ändern sich mit One UI, daher mit Ausweichziel. */
    private fun samsungIntent(cls: String): Intent {
        for (pkg in listOf("com.samsung.android.lool", "com.samsung.android.sm")) {
            val i = Intent().setClassName(pkg, cls)
            if (i.resolveActivity(packageManager) != null) return i
        }
        return Intent(Intent.ACTION_POWER_USAGE_SUMMARY)
    }

    /** Einstellungsseite öffnen; gibt es sie auf dem Handy nicht, die Einstellungen-Startseite. */
    private fun open(intent: Intent) {
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }
}
