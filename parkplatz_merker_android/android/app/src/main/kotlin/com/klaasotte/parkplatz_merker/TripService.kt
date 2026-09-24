package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject

/**
 * Foreground-Service während einer Fahrt: merkt alle 30 s die Position,
 * sucht alle 2 min nach Transmitter/Beacon und beobachtet das Ladekabel.
 * Schreibt nur Rohereignisse; beendet sich nach dem Aussteigen selbst.
 * Wird auch kurz für „Hier geparkt“ (Widget/Kachel) benutzt.
 */
class TripService : Service() {
    companion object {
        const val ACTION_ENTER = "com.klaasotte.parkplatz_merker.ENTER"
        const val ACTION_EXIT = "com.klaasotte.parkplatz_merker.EXIT"
        const val ACTION_WALKING = "com.klaasotte.parkplatz_merker.WALKING"
        const val ACTION_MANUAL = "com.klaasotte.parkplatz_merker.MANUAL"
        private const val NOTIF_ID = 1
        private const val NOTIF_PARKED_ID = 2
        private const val SCAN_INTERVAL_MS = 120_000L
        private const val STOP_AFTER_EXIT_MS = 3 * 60_000L
        private const val STOP_AFTER_WALK_MS = 60_000L
        private const val HARD_TIMEOUT_MS = 8 * 60 * 60_000L

        @Volatile
        var running = false
            private set

        @Volatile
        var inVehicle = false
            private set

        fun start(ctx: Context, action: String, source: String? = null) {
            val intent = Intent(ctx, TripService::class.java).setAction(action)
            if (source != null) intent.putExtra("source", source)
            try {
                ContextCompat.startForegroundService(ctx, intent)
            } catch (e: Exception) {
                EventLog.info(ctx, "Service-Start fehlgeschlagen: ${e.javaClass.simpleName} ${e.message}")
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var started = false
    private var stopped = false
    private var locationCallback: LocationCallback? = null
    private var powerReceiver: BroadcastReceiver? = null
    private var scanner: DeviceScanner? = null
    private var scanMode = "none"
    private var scanTarget: String? = null
    private var stopAt = 0L // 0 = kein Beenden geplant
    private var pendingManual = 0

    private val stopRunnable = Runnable { stopEverything("nach dem Aussteigen") }
    private val hardTimeout = Runnable { stopEverything("Zeitlimit 8 h") }
    private val scanTick = object : Runnable {
        override fun run() {
            scanRound()
            handler.postDelayed(this, SCAN_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        // Immer zuerst in den Vordergrund (Pflicht nach startForegroundService).
        try {
            val text = if (action == ACTION_MANUAL && !inVehicle) "Standort wird bestimmt …" else "Parkplatz wird beim Aussteigen gemerkt"
            val type = if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0
            ServiceCompat.startForeground(this, NOTIF_ID, buildNotification(text), type)
        } catch (e: Exception) {
            EventLog.info(this, "Vordergrund-Start fehlgeschlagen: ${e.javaClass.simpleName} ${e.message}")
            if (!started) {
                stopped = true
                stopSelf()
            }
            return START_NOT_STICKY
        }

        if (!started) {
            started = true
            running = true
            val address = Config.deviceAddress
            scanMode = if (address.isNullOrEmpty()) "none" else Config.deviceMode
            scanTarget = if (scanMode == "none") null else address
            logService("start", action ?: "?")
            handler.postDelayed(hardTimeout, HARD_TIMEOUT_MS)
        }

        when (action) {
            ACTION_ENTER -> onEnter()
            ACTION_EXIT -> onExit()
            ACTION_WALKING -> onWalking()
            ACTION_MANUAL -> onManual(intent?.getStringExtra("source") ?: "widget")
        }
        // Nichts mehr zu tun (z. B. WALKING ohne vorherige Fahrt)? Dann gleich wieder beenden.
        if (!inVehicle && stopAt == 0L && pendingManual == 0) stopEverything("ohne Fahrt")
        return START_NOT_STICKY
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, Notifications.CHANNEL_TRIP)
            .setSmallIcon(R.drawable.ic_car)
            .setContentTitle("Fahrt erkannt")
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .build()
    }

    // ---------- Aktionen ----------

    private fun onEnter() {
        inVehicle = true
        cancelPlannedStop()
        startLocationUpdates()
        if (Config.chargerEnabled) startPowerWatch()
        startScanning()
    }

    private fun onExit() {
        if (!inVehicle && stopAt != 0L) return // doppeltes EXIT
        inVehicle = false
        // Letzte Suchrunde bzw. Fenster abschließen, dann Suche beenden.
        val s = scanner
        val target = scanTarget
        handler.removeCallbacks(scanTick)
        if (s != null && target != null) {
            if (scanMode == "transmitter") {
                // Läuft gerade eine Runde, hängt sich das an sie an; sonst eine letzte Runde.
                s.runTransmitterRound(target) { s.stopAll() }
            } else {
                s.closeBeaconWindow()
                s.stopAll()
            }
        }
        scanner = null
        LocationHelper.current(this) { loc -> if (loc != null) logLocation(loc, "exit") }
        planStop(System.currentTimeMillis() + STOP_AFTER_EXIT_MS)
    }

    private fun onWalking() {
        if (inVehicle || stopAt == 0L) return
        val earlier = System.currentTimeMillis() + STOP_AFTER_WALK_MS
        if (earlier < stopAt) planStop(earlier)
    }

    private fun onManual(source: String) {
        pendingManual++
        LocationHelper.current(this) { loc ->
            pendingManual--
            val obj = JSONObject()
            obj.put("type", "manual")
            obj.put("t", System.currentTimeMillis())
            obj.put("source", source)
            if (loc != null) {
                obj.put("lat", loc.latitude)
                obj.put("lng", loc.longitude)
                obj.put("acc", loc.accuracy.toDouble())
                obj.put("error", JSONObject.NULL)
                logLocation(loc, "manual")
            } else {
                obj.put("error", "Standort nicht verfügbar")
            }
            EventLog.append(this, obj)
            notifyParked(loc != null)
            if (!inVehicle && stopAt == 0L && pendingManual == 0) stopEverything("Hier geparkt erledigt")
        }
    }

    @SuppressLint("MissingPermission")
    private fun notifyParked(ok: Boolean) {
        val nm = NotificationManagerCompat.from(this)
        if (!nm.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(
            this, 5, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(this, Notifications.CHANNEL_PARKED)
            .setSmallIcon(R.drawable.ic_parking)
            .setContentTitle(if (ok) "Parkplatz gemerkt ✓" else "Standort nicht verfügbar")
            .setContentText(if (ok) "Tippe, um ihn anzusehen." else "Ist GPS eingeschaltet?")
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            nm.notify(NOTIF_PARKED_ID, n)
        } catch (e: SecurityException) {
            // Benachrichtigungen nicht erlaubt
        }
    }

    // ---------- Beenden ----------

    private fun planStop(at: Long) {
        stopAt = at
        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, (at - System.currentTimeMillis()).coerceAtLeast(0L))
    }

    private fun cancelPlannedStop() {
        stopAt = 0L
        handler.removeCallbacks(stopRunnable)
    }

    private fun stopEverything(reason: String) {
        if (stopped) return
        stopped = true
        handler.removeCallbacksAndMessages(null)
        stopLocationUpdates()
        stopPowerWatch()
        scanner?.stopAll()
        scanner = null
        if (started) logService("stop", reason)
        running = false
        inVehicle = false
        stopAt = 0L
        try {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            // ignorieren
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopEverything("vom System beendet")
        super.onDestroy()
    }

    // ---------- Standort ----------

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates() {
        if (locationCallback != null) return
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 30_000L)
            .setMinUpdateIntervalMillis(15_000L)
            .build()
        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (loc in result.locations) logLocation(loc, "periodic")
            }
        }
        try {
            LocationServices.getFusedLocationProviderClient(this)
                .requestLocationUpdates(request, cb, Looper.getMainLooper())
            locationCallback = cb
        } catch (e: Exception) {
            EventLog.info(this, "Standort-Updates fehlgeschlagen: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        val cb = locationCallback ?: return
        locationCallback = null
        try {
            LocationServices.getFusedLocationProviderClient(this).removeLocationUpdates(cb)
        } catch (e: Exception) {
            // ignorieren
        }
    }

    private fun logLocation(loc: Location, reason: String) {
        EventLog.append(this, LocationHelper.toJson(loc, reason))
    }

    // ---------- Ladekabel ----------

    private fun logPower(plugged: Boolean, reason: String) {
        val obj = JSONObject()
        obj.put("type", "power")
        obj.put("t", System.currentTimeMillis())
        obj.put("plugged", plugged)
        obj.put("reason", reason)
        EventLog.append(this, obj)
    }

    private fun startPowerWatch() {
        if (powerReceiver != null) return
        // Aktueller Zustand aus dem „sticky“ Batterie-Broadcast.
        try {
            val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val plugged = (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
            logPower(plugged, "initial")
        } catch (e: Exception) {
            EventLog.info(this, "Ladezustand unbekannt: ${e.message}")
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_POWER_CONNECTED -> logPower(true, "change")
                    Intent.ACTION_POWER_DISCONNECTED -> logPower(false, "change")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        try {
            ContextCompat.registerReceiver(this, r, filter, ContextCompat.RECEIVER_EXPORTED)
            powerReceiver = r
        } catch (e: Exception) {
            EventLog.info(this, "Ladekabel-Empfänger fehlgeschlagen: ${e.message}")
        }
    }

    private fun stopPowerWatch() {
        val r = powerReceiver ?: return
        powerReceiver = null
        try {
            unregisterReceiver(r)
        } catch (e: Exception) {
            // ignorieren
        }
    }

    // ---------- Gerätesuche (nur während IN_VEHICLE) ----------

    private fun startScanning() {
        val target = scanTarget ?: return
        if (scanner != null) return
        val s = DeviceScanner(this)
        scanner = s
        if (scanMode == "beacon") s.startBeacon(target)
        handler.removeCallbacks(scanTick)
        if (scanMode == "transmitter") {
            handler.post(scanTick) // erste Runde sofort
        } else {
            handler.postDelayed(scanTick, SCAN_INTERVAL_MS)
        }
    }

    private fun scanRound() {
        val s = scanner ?: return
        val target = scanTarget ?: return
        if (!inVehicle) return
        if (scanMode == "transmitter") s.runTransmitterRound(target) {} else s.closeBeaconWindow()
    }

    private fun logService(state: String, reason: String) {
        val obj = JSONObject()
        obj.put("type", "service")
        obj.put("t", System.currentTimeMillis())
        obj.put("state", state)
        obj.put("mode", scanMode)
        obj.put("target", scanTarget ?: JSONObject.NULL)
        obj.put("reason", reason)
        EventLog.append(this, obj)
    }
}
