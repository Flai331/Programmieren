package com.klaasotte.parkplatz_merker

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

private const val CHANNEL = "parkplatz_merker/native"

class MainActivity : FlutterActivity() {

    companion object {
        @Volatile var visible = false
    }

    private var deviceSearcher: DeviceScanner? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)


        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "drainEvents" -> {
                            result.success(EventLog.drain(this))
                        }
                        "getConfig" -> {
                            result.success(Config.getConfig())
                        }
                        "setConfig" -> {
                            val config = call.arguments as? Map<String, Any?> ?: emptyMap()
                            Config.setConfig(config)
                            Transitions.register(this)
                            BeaconBackground.stop(this)
                            BeaconBackground.start(this)
                            result.success(null)
                        }
                        "registerTransitions" -> {
                            Transitions.register(this) { ok, error ->
                                runOnUiThread {
                                    result.success(mapOf("ok" to ok, "error" to error))
                                }
                            }
                        }
                        "getCurrentLocation" -> {
                            LocationHelper.current(this) { location ->
                                runOnUiThread {
                                    if (location != null) {
                                        result.success(LocationHelper.toMap(location))
                                    } else {
                                        result.success(null)
                                    }
                                }
                            }
                        }
                        "getLastLocation" -> {
                            LocationHelper.last(this) { location ->
                                runOnUiThread { result.success(location?.let { LocationHelper.toMap(it) }) }
                            }
                        }
                        "reverseGeocode" -> {
                            val lat = (call.argument<Any>("lat") as? Number)?.toDouble()
                            val lng = (call.argument<Any>("lng") as? Number)?.toDouble()
                            if (lat == null || lng == null) {
                                result.success(null)
                            } else {
                                Geo.reverse(this@MainActivity, lat, lng) { text -> runOnUiThread { result.success(text) } }
                            }
                        }
                        "updateWidget" -> {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as? Map<String, Any?>
                            CarWidget.save(this@MainActivity, args)
                            result.success(null)
                        }
                        "backgroundDone" -> {
                            result.success(null)
                        }
                        "openNavigation" -> {
                            val lat = (call.argument<Any>("lat") as? Number)?.toDouble()
                            val lng = (call.argument<Any>("lng") as? Number)?.toDouble()
                            result.success(lat != null && lng != null && openNavigation(lat, lng))
                        }
                        "startDeviceSearch" -> {
                            val scanner = deviceSearcher ?: DeviceScanner(this).also { deviceSearcher = it }
                            val error = scanner.startSearch()
                            result.success(mapOf("ok" to (error == null), "error" to error))
                        }
                        "getSearchResults" -> {
                            val scanner = deviceSearcher
                            result.success(
                                mapOf(
                                    "running" to (scanner?.searchRunning() ?: false),
                                    "devices" to (scanner?.results() ?: emptyList()),
                                )
                            )
                        }
                        "stopDeviceSearch" -> {
                            deviceSearcher?.stopSearch()
                            result.success(null)
                        }
                        "scheduleReminder" -> {
                            val atMs = (call.argument<Any>("atMs") as? Number)?.toLong() ?: 0L
                            val text = call.argument<String>("text") ?: ""
                            val ok = Reminder.schedule(this, atMs, text)
                            result.success(ok)
                        }
                        "cancelReminder" -> {
                            Reminder.cancel(this)
                            result.success(null)
                        }
                        "listApps" -> {
                            result.success(AppLauncher.listApps(this))
                        }
                        "listCloseActions" -> {
                            val pkg = call.argument<String>("package") ?: Config.launchPackage
                            val map = HashMap<String, Any>(NotifListener.listCloseActions(pkg))
                            map["widgetButtons"] = WidgetButtons.list(this, pkg)
                            // Auch mit Widget-Knöpfen gilt die Benachrichtigung als vorhanden.
                            if ((map["widgetButtons"] as List<*>).isNotEmpty()) map["hasNotification"] = true
                            result.success(map)
                        }
                        "testWidgetButton" -> {
                            val pkg = call.argument<String>("package") ?: ""
                            val key = call.argument<String>("key") ?: ""
                            result.success(WidgetButtons.press(this, pkg, key))
                        }
                        "openOverlaySettings" -> {
                            val uri = Uri.parse("package:$packageName")
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, uri)
                            try {
                                startActivity(intent)
                            } catch (e: Exception) {
                                try {
                                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                                } catch (e2: Exception) {
                                    // ignore
                                }
                            }
                            result.success(null)
                        }
                        "openNotificationListenerSettings" -> {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        }
                        "openAccessibilitySettings" -> {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(null)
                        }
                        "testLaunch" -> {
                            AppLauncher.launchAll(this, fromForeground = true)
                            result.success(null)
                        }
                        "routineStart" -> {
                            CarSession.testStart(this)
                            result.success(null)
                        }
                        "routineEnd" -> {
                            CarSession.testEnd(this)
                            result.success(null)
                        }
                        "appRunning" -> {
                            // Läuft die App noch? (hat sie noch eine Benachrichtigung)
                            val pkg = call.argument<String>("package") ?: ""
                            result.success(NotifListener.hasNotification(pkg))
                        }
                        "scanOnce" -> {
                            // Eine Suchrunde nach dem eingerichteten Gerät (ca. 12 s).
                            val target = Config.deviceAddress
                            if (!Config.hasDevice || target == null) {
                                result.success(mapOf("ok" to false, "found" to false, "error" to "Kein Transmitter/Beacon eingerichtet"))
                            } else {
                                val answered = java.util.concurrent.atomic.AtomicBoolean(false)
                                val scanner = DeviceScanner(this)
                                scanner.listener = { found, ok ->
                                    if (!answered.getAndSet(true)) {
                                        result.success(mapOf("ok" to ok, "found" to found, "error" to (if (ok) null else "Suche nicht möglich (Bluetooth an? Berechtigung?)")))
                                    }
                                }
                                scanner.runTransmitterRound(target) {
                                    if (!answered.getAndSet(true)) {
                                        result.success(mapOf("ok" to false, "found" to false, "error" to "Keine Antwort"))
                                    }
                                }
                            }
                        }
                        "testClose" -> {
                            AppLauncher.closeAll(this, fromForeground = true)
                            result.success(null)
                        }
                        "getVolumeInfo" -> {
                            result.success(VolumeProfile.info(this))
                        }
                        "applyVolumeNow" -> {
                            VolumeProfile.apply(this)
                            result.success(null)
                        }
                        "restoreVolumeNow" -> {
                            VolumeProfile.restore(this)
                            result.success(null)
                        }
                        "openDndSettings" -> {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                            result.success(null)
                        }
                        "getNativeStatus" -> {
                            val playServices = GoogleApiAvailability.getInstance()
                                .isGooglePlayServicesAvailable(this) == ConnectionResult.SUCCESS
                            val lm = getSystemService(android.content.Context.LOCATION_SERVICE) as? android.location.LocationManager
                            val locationEnabled = if (Build.VERSION.SDK_INT >= 28) {
                                lm?.isLocationEnabled == true
                            } else {
                                @Suppress("DEPRECATION")
                                lm?.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) == true
                            }
                            val pm = getSystemService(POWER_SERVICE) as? android.os.PowerManager
                            val batteryIgnored = pm?.isIgnoringBatteryOptimizations(packageName) == true
                            val exactAlarms = if (Build.VERSION.SDK_INT >= 31) {
                                val alarmMgr = getSystemService(android.content.Context.ALARM_SERVICE) as? android.app.AlarmManager
                                alarmMgr?.canScheduleExactAlarms() == true
                            } else {
                                true
                            }

                            val nm = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            val dndAccess = nm?.isNotificationPolicyAccessGranted ?: false
                            result.success(mapOf(
                                "sdkInt" to Build.VERSION.SDK_INT,
                                "playServices" to playServices,
                                "transitionsRegistered" to Config.transitionsRegistered,
                                "transitionsError" to Config.transitionsError,
                                "transitionsAt" to Config.transitionsAt,
                                "bluetoothEnabled" to ((getSystemService(android.content.Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager)?.adapter?.isEnabled == true),
                                "locationEnabled" to locationEnabled,
                                "ignoringBatteryOptimizations" to batteryIgnored,
                                "serviceRunning" to TripService.running,
                                "inVehicle" to TripService.inVehicle,
                                "exactAlarms" to exactAlarms,
                                "overlayAllowed" to Settings.canDrawOverlays(this),
                                "notificationListener" to NotifListener.isEnabled(this),
                                "accessibility" to ForceStopService.isEnabled(this),
                                "dndAccess" to dndAccess
                            ))
                        }
                        "openAppDetails" -> {
                            val uri = Uri.fromParts("package", packageName, null)
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
                            startActivity(intent)
                            result.success(null)
                        }
                        "openBatterySettings" -> {
                            try {
                                val uri = Uri.parse("package:$packageName")
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, uri)
                                startActivity(intent)
                            } catch (e: Exception) {
                                try {
                                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    startActivity(intent)
                                } catch (e2: Exception) {
                                    // ignore
                                }
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }


    /** Fußweg-Navigation in Google Maps, sonst beliebige Karten-App über geo:. */
    private fun openNavigation(lat: Double, lng: Double): Boolean {
        // Locale.US: sonst Dezimalkomma im deutschen Gebietsschema.
        val ll = String.format(Locale.US, "%.7f,%.7f", lat, lng)
        try {
            val nav = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=$ll&mode=w"))
                .setPackage("com.google.android.apps.maps")
            startActivity(nav)
            return true
        } catch (e: ActivityNotFoundException) {
            // weiter mit geo:
        }
        return try {
            val label = Uri.encode("$ll(Mein Auto)")
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$ll?q=$label")))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    override fun onResume() {
        super.onResume()
        visible = true
    }

    override fun onPause() {
        visible = false
        super.onPause()
    }

    override fun onDestroy() {
        deviceSearcher?.stopSearch()
        super.onDestroy()
    }
}
