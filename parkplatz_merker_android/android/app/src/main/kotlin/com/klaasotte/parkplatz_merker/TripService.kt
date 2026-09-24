package com.klaasotte.parkplatz_merker

import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject

class TripService : Service() {
    companion object {
        const val ACTION_ENTER = "action_enter"
        const val ACTION_EXIT = "action_exit"
        const val ACTION_WALKING = "action_walking"
        const val ACTION_MANUAL = "action_manual"
        const val NOTIF_ID = 1

        @Volatile
        var running = false

        @Volatile
        var inVehicle = false

        fun start(ctx: Context, action: String, source: String? = null) {
            val intent = Intent(ctx, TripService::class.java)
            intent.action = action
            if (source != null) {
                intent.putExtra("source", source)
            }
            try {
                ContextCompat.startForegroundService(ctx, intent)
            } catch (e: Exception) {
                EventLog.info(ctx, "Service start fehlgeschlagen: ${e.message}")
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var locationCallback: LocationCallback? = null
    private var chargerReceiver: BroadcastReceiver? = null
    private var scanner: DeviceScanner? = null
    private var hardTimeoutTime: Long = 0
    private var endTimeoutTime: Long = 0
    private var endTimeoutRunnable: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startInForeground()
        } catch (e: Exception) {
            EventLog.info(this, "Service-Start fehlgeschlagen: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        val action = intent?.action
        val source = intent?.getStringExtra("source")

        if (!running) {
            running = true
            hardTimeoutTime = System.currentTimeMillis() + 8 * 60 * 60 * 1000
            logService("start", Config.deviceMode.ifEmpty { "none" }, Config.deviceAddress)
        }

        when (action) {
            ACTION_ENTER -> handleEnter()
            ACTION_EXIT -> handleExit()
            ACTION_WALKING -> handleWalking()
            ACTION_MANUAL -> handleManual(source ?: "widget")
        }

        return START_NOT_STICKY
    }

    private fun startInForeground() {
        val notif = NotificationCompat.Builder(this, "trip")
            .setSmallIcon(R.drawable.ic_car)
            .setContentTitle("Fahrt erkannt")
            .setContentText("Parkplatz wird beim Aussteigen gemerkt")
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            .build()

        val flags = if (Build.VERSION.SDK_INT >= 29) {
            com.google.android.gms.location.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        } else {
            0
        }

        ServiceCompat.startForeground(this, NOTIF_ID, notif, flags)
    }

    private fun handleEnter() {
        inVehicle = true
        cancelEndTimeout()
        startLocationUpdates()
        if (Config.chargerEnabled) {
            registerChargerReceiver()
            logPowerInitial()
        }
        if (Config.deviceMode != "none" && !Config.deviceAddress.isNullOrEmpty()) {
            startScanLoop()
        }
    }

    private fun handleExit() {
        inVehicle = false
        if (Config.deviceMode == "transmitter") {
            scanner?.runTransmitterRound(Config.deviceAddress!!) {}
        }
        stopScanLoop()
        getCurrentLocationAndLog("exit") {
            scheduleEndTimeout()
        }
    }

    private fun handleWalking() {
        if (!inVehicle && endTimeoutTime > 0) {
            val newTime = System.currentTimeMillis() + 60 * 1000
            if (newTime < endTimeoutTime) {
                endTimeoutTime = newTime
                rescheduleEndTimeout()
            }
        }
    }

    private fun handleManual(source: String) {
        getCurrentLocationAndLog("manual", source) { hasLocation ->
            val notif = if (hasLocation) {
                NotificationCompat.Builder(this, "parked")
                    .setSmallIcon(R.drawable.ic_parking)
                    .setContentTitle("Parkplatz gemerkt ✓")
                    .setAutoCancel(true)
                    .build()
            } else {
                NotificationCompat.Builder(this, "parked")
                    .setSmallIcon(R.drawable.ic_parking)
                    .setContentTitle("Standort nicht verfügbar")
                    .setAutoCancel(true)
                    .build()
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.notify(2, notif)

            if (!inVehicle && endTimeoutTime == 0L && locationCallback == null) {
                stopEverything()
            }
        }
    }

    private fun startLocationUpdates() {
        if (locationCallback != null) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 30_000L)
            .setMinUpdateIntervalMillis(15_000L)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (location in result.locations) {
                    logLocation(location, "periodic")
                }
            }
        }

        try {
            locationCallback = callback
            LocationServices.getFusedLocationProviderClient(this)
                .requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            locationCallback = null
        }
    }

    private fun stopLocationUpdates() {
        val callback = locationCallback ?: return
        try {
            LocationServices.getFusedLocationProviderClient(this)
                .removeLocationUpdates(callback)
        } catch (e: Exception) {
            // ignore
        }
        locationCallback = null
    }

    private fun registerChargerReceiver() {
        if (chargerReceiver != null) return

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                if (intent == null) return
                val plugged = intent.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, 0) != 0
                val obj = JSONObject()
                obj.put("type", "power")
                obj.put("t", System.currentTimeMillis())
                obj.put("plugged", plugged)
                obj.put("reason", "change")
                EventLog.append(context, obj)
            }
        }

        chargerReceiver = receiver
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        try {
            ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        } catch (e: Exception) {
            chargerReceiver = null
        }
    }

    private fun unregisterChargerReceiver() {
        if (chargerReceiver != null) {
            try {
                unregisterReceiver(chargerReceiver)
            } catch (e: Exception) {
                // ignore
            }
            chargerReceiver = null
        }
    }

    private fun startScanLoop() {
        if (scanner != null) return
        scanner = DeviceScanner(this)
        scheduleScan()
    }

    private fun scheduleScan() {
        handler.post {
            val s = scanner ?: return@post
            if (!inVehicle) return@post
            s.runTransmitterRound(Config.deviceAddress!!) {
                handler.postDelayed({
                    if (scanner != null && inVehicle) {
                        scheduleScan()
                    }
                }, 120_000L)
            }
        }
    }

    private fun stopScanLoop() {
        scanner = null
    }

    private fun scheduleEndTimeout() {
        endTimeoutTime = System.currentTimeMillis() + 3 * 60 * 1000
        endTimeoutRunnable?.let { handler.removeCallbacks(it) }
        endTimeoutRunnable = Runnable {
            stopEverything()
        }
        handler.postDelayed(endTimeoutRunnable!!, 3 * 60 * 1000)
    }

    private fun rescheduleEndTimeout() {
        endTimeoutRunnable?.let { handler.removeCallbacks(it) }
        endTimeoutRunnable = Runnable {
            stopEverything()
        }
        val delay = endTimeoutTime - System.currentTimeMillis()
        if (delay > 0) {
            handler.postDelayed(endTimeoutRunnable!!, delay)
        } else {
            stopEverything()
        }
    }

    private fun cancelEndTimeout() {
        endTimeoutTime = 0L
        endTimeoutRunnable?.let { handler.removeCallbacks(it) }
        endTimeoutRunnable = null
    }

    private fun getCurrentLocationAndLog(reason: String, source: String? = null, onDone: (Boolean) -> Unit = {}) {
        LocationHelper.current(this) { location ->
            if (location != null) {
                logLocation(location, reason)
                if (reason == "manual" && source != null) {
                    logManual(location, source)
                }
                onDone(true)
            } else {
                if (reason == "manual" && source != null) {
                    logManual(null, source)
                }
                onDone(false)
            }
        }
    }

    private fun logLocation(location: Location, reason: String) {
        val obj = LocationHelper.toJson(location, reason)
        EventLog.append(this, obj)
    }

    private fun logManual(location: Location?, source: String) {
        val obj = JSONObject()
        obj.put("type", "manual")
        obj.put("t", System.currentTimeMillis())
        obj.put("source", source)
        if (location != null) {
            obj.put("lat", location.latitude)
            obj.put("lng", location.longitude)
            obj.put("acc", location.accuracy.toDouble())
        }
        EventLog.append(this, obj)
    }

    private fun logPowerInitial() {
        try {
            val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = registerReceiver(null, ifilter)
            val plugged = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, 0) ?: 0
            val obj = JSONObject()
            obj.put("type", "power")
            obj.put("t", System.currentTimeMillis())
            obj.put("plugged", (plugged and 0xFF) != 0)
            obj.put("reason", "initial")
            EventLog.append(this, obj)
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun logService(state: String, mode: String, address: String?) {
        val obj = JSONObject()
        obj.put("type", "service")
        obj.put("t", System.currentTimeMillis())
        obj.put("state", state)
        obj.put("mode", mode)
        if (!address.isNullOrEmpty()) {
            obj.put("target", address)
        } else {
            obj.put("target", null)
        }
        obj.put("reason", "transition")
        EventLog.append(this, obj)
    }

    private fun stopEverything() {
        handler.removeCallbacksAndMessages(null)
        stopLocationUpdates()
        unregisterChargerReceiver()
        stopScanLoop()
        logService("stop", Config.deviceMode.ifEmpty { "none" }, Config.deviceAddress)
        running = false
        inVehicle = false
        try {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            // ignore
        }
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopEverything()
    }
}
