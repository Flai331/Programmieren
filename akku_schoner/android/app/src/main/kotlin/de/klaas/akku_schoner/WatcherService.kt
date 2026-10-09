package de.klaas.akku_schoner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Hintergrund-Dienst für Akku-Wächter und Automatik. Hört nur auf System-Meldungen,
 * die ohnehin verschickt werden (Akku, Bildschirm an/aus, Entsperren) – kein Timer, kein GPS, kein Netz.
 *  - Wächter: warnt bei Ladegrenze, niedrigem Stand und Hitze.
 *  - Bildschirm aus: Apps der Stufen sanft/komplett sanft beenden.
 *  - Entsperren nach längerer Pause: Apps der Stufe komplett erzwungen beenden.
 */
class WatcherService : Service() {

    companion object {
        private const val CH_STATUS = "waechter"
        private const val CH_ALARM = "alarm"
        private const val ID_STATUS = 1
        private const val ID_ALARM = 2
        @Volatile var running = false

        fun sync(ctx: Context) {
            val intent = Intent(ctx, WatcherService::class.java)
            if (Prefs.serviceNeeded(ctx)) {
                try {
                    if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent) else ctx.startService(intent)
                } catch (_: Exception) {
                }
            } else {
                ctx.stopService(intent)
            }
        }

        fun channels(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
            nm.createNotificationChannel(
                NotificationChannel(CH_STATUS, "Akku-Wächter (Status)", NotificationManager.IMPORTANCE_MIN).apply {
                    setShowBadge(false)
                }
            )
            nm.createNotificationChannel(
                NotificationChannel(CH_ALARM, "Akku-Warnungen", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    private var receiver: BroadcastReceiver? = null
    private var screenReceiver: BroadcastReceiver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var screenOffAt = 0L
    private val softRun = Runnable { softCleanup() }
    private var lastLevel = -1
    private var lastCharging = false
    private var lastTempTenth = Int.MIN_VALUE
    private var upperWarned = false
    private var lowerWarned = false
    private var heatWarned = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        channels(this)
        goForeground()
        running = true

        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = onBattery(intent)
        }
        receiver = r
        // ACTION_BATTERY_CHANGED ist ein geschützter System-Broadcast.
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(r, IntentFilter(Intent.ACTION_BATTERY_CHANGED), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(r, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        }

        val sr = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = onScreen(intent.action ?: "")
        }
        screenReceiver = sr
        val f = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(sr, f, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(sr, f)
        }
    }

    private fun onScreen(action: String) {
        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                screenOffAt = System.currentTimeMillis()
                // Kurz warten: wer den Bildschirm gleich wieder anmacht, merkt nichts.
                if (Prefs.autoSoft(this)) handler.postDelayed(softRun, 15_000L)
            }
            Intent.ACTION_SCREEN_ON -> handler.removeCallbacks(softRun)
            Intent.ACTION_USER_PRESENT -> {
                val off = screenOffAt
                screenOffAt = 0L
                if (!Prefs.autoFull(this) || off == 0L) return
                if (System.currentTimeMillis() - off < Prefs.unlockAfterMin(this) * 60_000L) return
                if (inCall() || ForceStopService.busy() || ForceStopService.instance == null) return
                Thread {
                    val pkgs = try { Apps.running(this, Policy.FULL) } catch (_: Exception) { emptyList() }
                    if (pkgs.isEmpty()) return@Thread
                    Apps.killBackground(this, pkgs)
                    // Erst den Startbildschirm fertig zeigen lassen.
                    handler.postDelayed({ ForceStopService.request(this, pkgs, returnToApp = false) }, 1200L)
                }.start()
            }
        }
    }

    private fun softCleanup() {
        Thread {
            try {
                val pkgs = Apps.running(this, Policy.SOFT) + Apps.running(this, Policy.FULL)
                Apps.killBackground(this, pkgs)
            } catch (_: Exception) {
            }
        }.start()
    }

    private fun inCall(): Boolean {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        return am.mode == AudioManager.MODE_IN_CALL || am.mode == AudioManager.MODE_IN_COMMUNICATION
    }

    /** Muss nach jedem startForegroundService() aufgerufen werden, sonst beendet Android die App. */
    private fun goForeground() {
        val n = statusNotification(BatteryInfo.sticky(this))
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ID_STATUS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID_STATUS, n)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        if (!Prefs.serviceNeeded(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Neue Grenzen sofort anwenden.
        upperWarned = false
        lowerWarned = false
        heatWarned = false
        BatteryInfo.sticky(this)?.let { onBattery(it, force = true) }
        return START_STICKY
    }

    override fun onDestroy() {
        receiver?.let { unregisterReceiver(it) }
        receiver = null
        screenReceiver?.let { unregisterReceiver(it) }
        screenReceiver = null
        handler.removeCallbacksAndMessages(null)
        running = false
        super.onDestroy()
    }

    private fun onBattery(intent: Intent, force: Boolean = false) {
        val level = BatteryInfo.level(intent)
        val charging = BatteryInfo.isCharging(intent)
        val temp = BatteryInfo.temp(intent)
        val tempTenth = (temp * 10).toInt()

        // Die Meldung kommt oft (Spannung ändert sich ständig) – nur bei echter Änderung arbeiten.
        val changed = force || level != lastLevel || charging != lastCharging ||
            Math.abs(tempTenth - lastTempTenth) >= 10
        if (!changed) return
        if (charging != lastCharging) upperWarned = false
        lastLevel = level
        lastCharging = charging
        lastTempTenth = tempTenth

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(ID_STATUS, statusNotification(intent))
        if (!Prefs.watcherEnabled(this)) return

        val upper = Prefs.upperLimit(this)
        val lower = Prefs.lowerLimit(this)
        val maxTemp = Prefs.maxTemp(this)

        if (charging && upper < 100 && level >= upper && !upperWarned) {
            upperWarned = true
            alarm("Ladegrenze $upper % erreicht", "Jetzt das Ladekabel abziehen – das schont den Akku.")
        }
        if (!charging && level <= lower && !lowerWarned) {
            lowerWarned = true
            alarm("Akku nur noch $level %", "Bald laden – tiefe Entladung schadet einem schwachen Akku.")
        }
        if (charging || level > lower + 5) lowerWarned = false

        if (temp >= maxTemp && !heatWarned) {
            heatWarned = true
            alarm(
                "Akku ist ${"%.1f".format(temp)} °C warm",
                if (charging) "Laden unterbrechen und Handy abkühlen lassen (Hülle ab, nicht in die Sonne)."
                else "Handy kurz in Ruhe lassen, Spiele/Navigation/Kamera beenden."
            )
        }
        if (temp < maxTemp - 3) heatWarned = false
    }

    private fun openApp(): PendingIntent {
        val i = packageManager.getLaunchIntentForPackage(packageName) ?: Intent()
        return PendingIntent.getActivity(this, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
        else @Suppress("DEPRECATION") Notification.Builder(this)

    private fun statusNotification(intent: Intent?): Notification {
        val level = BatteryInfo.level(intent)
        val temp = BatteryInfo.temp(intent)
        val charging = BatteryInfo.isCharging(intent)
        val text = buildString {
            append("$level %")
            append(" · ${"%.1f".format(temp)} °C")
            if (charging && Prefs.watcherEnabled(this@WatcherService)) {
                append(" · lädt (Grenze ${Prefs.upperLimit(this@WatcherService)} %)")
            }
            if (Prefs.autoSoft(this@WatcherService) || Prefs.autoFull(this@WatcherService)) {
                append(" · Automatik an")
            }
        }
        return builder(CH_STATUS)
            .setSmallIcon(android.R.drawable.ic_lock_idle_low_battery)
            .setContentTitle("Akku-Schoner")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp())
            .build()
    }

    private fun alarm(title: String, text: String) {
        val n = builder(CH_ALARM)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(openApp())
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(ID_ALARM, n)
    }
}
