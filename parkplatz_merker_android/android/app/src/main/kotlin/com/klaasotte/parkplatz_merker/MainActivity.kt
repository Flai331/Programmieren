package com.klaasotte.parkplatz_merker

import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

private const val CHANNEL = "parkplatz_merker/native"

class MainActivity : FlutterActivity() {

    private var deviceSearcher: DeviceScanner? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Config.init(this)
        Notifications.ensureChannels(this)

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
                            try {
                                val client = LocationServices.getFusedLocationProviderClient(this)
                                @Suppress("MissingPermission")
                                client.lastLocation.addOnSuccessListener { location ->
                                    if (location != null) {
                                        result.success(LocationHelper.toMap(location))
                                    } else {
                                        result.success(null)
                                    }
                                }
                            } catch (e: SecurityException) {
                                result.success(null)
                            }
                        }
                        "reverseGeocode" -> {
                            val lat = (call.argument<Any>("lat") as? Number)?.toDouble() ?: return@setMethodCallHandler
                            val lng = (call.argument<Any>("lng") as? Number)?.toDouble() ?: return@setMethodCallHandler

                            if (!Geocoder.isPresent()) {
                                result.success(null)
                                return@setMethodCallHandler
                            }

                            if (Build.VERSION.SDK_INT >= 33) {
                                val geocoder = Geocoder(this, Locale.GERMANY)
                                geocoder.getFromLocation(lat, lng, 1) { addresses ->
                                    runOnUiThread {
                                        if (addresses.isNotEmpty()) {
                                            val address = addresses[0]
                                            val text = address.getAddressLine(0) ?: buildAddressText(address)
                                            result.success(text)
                                        } else {
                                            result.success(null)
                                        }
                                    }
                                }
                            } else {
                                Thread {
                                    try {
                                        val geocoder = Geocoder(this, Locale.GERMANY)
                                        @Suppress("DEPRECATION")
                                        val addresses = geocoder.getFromLocation(lat, lng, 1)
                                        runOnUiThread {
                                            if (addresses != null && addresses.isNotEmpty()) {
                                                val address = addresses[0]
                                                val text = address.getAddressLine(0) ?: buildAddressText(address)
                                                result.success(text)
                                            } else {
                                                result.success(null)
                                            }
                                        }
                                    } catch (e: Exception) {
                                        runOnUiThread { result.success(null) }
                                    }
                                }.start()
                            }
                        }
                        "openNavigation" -> {
                            val lat = (call.argument<Any>("lat") as? Number)?.toDouble() ?: return@setMethodCallHandler
                            val lng = (call.argument<Any>("lng") as? Number)?.toDouble() ?: return@setMethodCallHandler
                            val ll = String.format(Locale.US, "%.7f,%.7f", lat, lng)

                            try {
                                val uri = Uri.parse("google.navigation:q=$ll&mode=w")
                                val intent = Intent(Intent.ACTION_VIEW, uri)
                                intent.setPackage("com.google.android.apps.maps")
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                try {
                                    val encodedName = Uri.encode("Mein Auto")
                                    val uri = Uri.parse("geo:$ll?q=$encodedName")
                                    val intent = Intent(Intent.ACTION_VIEW, uri)
                                    startActivity(intent)
                                    result.success(true)
                                } catch (e2: Exception) {
                                    result.success(false)
                                }
                            }
                        }
                        "startDeviceSearch" -> {
                            deviceSearcher?.stopSearch()
                            deviceSearcher = DeviceScanner(this)
                            deviceSearcher?.startSearch()
                            result.success(mapOf("ok" to true, "error" to null))
                        }
                        "getSearchResults" -> {
                            val (running, devices) = deviceSearcher?.results() ?: (false to emptyList())
                            result.success(mapOf("running" to running, "devices" to devices))
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

                            result.success(mapOf(
                                "sdkInt" to Build.VERSION.SDK_INT,
                                "playServices" to playServices,
                                "transitionsRegistered" to Config.transitionsRegistered,
                                "transitionsError" to Config.transitionsError,
                                "transitionsAt" to Config.transitionsAt,
                                "bluetoothEnabled" to (getSystemService(android.content.Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager)?.adapter?.isEnabled == true,
                                "locationEnabled" to locationEnabled,
                                "ignoringBatteryOptimizations" to batteryIgnored,
                                "serviceRunning" to TripService.running,
                                "inVehicle" to TripService.inVehicle,
                                "exactAlarms" to exactAlarms
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

    private fun buildAddressText(address: android.location.Address): String {
        val parts = mutableListOf<String>()
        address.thoroughfare?.let { parts.add(it) }
        address.subThoroughfare?.let { parts.add(it) }
        address.postalCode?.let { parts.add(it) }
        address.locality?.let { parts.add(it) }
        return parts.joinToString(", ")
    }
}
