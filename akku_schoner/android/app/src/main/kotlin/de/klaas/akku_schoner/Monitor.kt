package de.klaas.akku_schoner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Akku-Wächter und Automatik – ohne eigenen Vordergrund-Dienst und damit ohne dauerhafte
 * Benachrichtigung. Läuft im Prozess der Bedienungshilfe (ForceStopService), die Android
 * ohnehin dauerhaft am Leben hält. Hört nur auf System-Meldungen (Akku, Bildschirm, Entsperren).
 *  - Wächter: einzelne Warnung bei Ladegrenze, niedrigem Stand und Hitze.
 *  - Bildschirm aus: Apps der Stufen sanft/komplett sanft beenden.
 *  - Entsperren nach längerer Pause: Apps der Stufe komplett erzwungen beenden.
 */
class Monitor(private val ctx: Context) {

    companion object {
        private const val CH_ALARM = "alarm"
        private const val ID_ALARM = 2
        @Volatile var instance: Monitor? = null

        /** Nach geänderten Einstellungen: Warnungen neu bewerten. */
        fun refresh() {
            instance?.let { m -> m.handler.post { m.reset() } }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var batteryReceiver: BroadcastReceiver? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var screenOffAt = 0L
    private val softRun = Runnable { softCleanup() }
    private var lastLevel = -1
    private var lastCharging = false
    private var lastTempTenth = Int.MIN_VALUE
    private var upperWarned = false
    private var lowerWarned = false
    private var heatWarned = false

    fun start() {
        instance = this
        channels()

        val br = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = onBattery(intent)
        }
        val sr = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = onScreen(intent.action ?: "")
        }
        val sf = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        // Geschützte System-Broadcasts kommen auch bei NOT_EXPORTED an.
        if (Build.VERSION.SDK_INT >= 33) {
            ctx.registerReceiver(br, IntentFilter(Intent.ACTION_BATTERY_CHANGED), Context.RECEIVER_NOT_EXPORTED)
            ctx.registerReceiver(sr, sf, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(br, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ctx.registerReceiver(sr, sf)
        }
        batteryReceiver = br
        screenReceiver = sr
    }

    fun stop() {
        try { batteryReceiver?.let { ctx.unregisterReceiver(it) } } catch (_: Exception) {}
        try { screenReceiver?.let { ctx.unregisterReceiver(it) } } catch (_: Exception) {}
        batteryReceiver = null
        screenReceiver = null
        handler.removeCallbacksAndMessages(null)
        if (instance === this) instance = null
    }

    private fun reset() {
        upperWarned = false
        lowerWarned = false
        heatWarned = false
        BatteryInfo.sticky(ctx)?.let { onBattery(it, force = true) }
    }

    private fun channels() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        // Alter Kanal der früheren Dauer-Benachrichtigung
        nm.deleteNotificationChannel("waechter")
        nm.createNotificationChannel(
            NotificationChannel(CH_ALARM, "Akku-Warnungen", NotificationManager.IMPORTANCE_HIGH)
        )
    }

    private fun onScreen(action: String) {
        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                screenOffAt = System.currentTimeMillis()
                // Kurz warten: wer den Bildschirm gleich wieder anmacht, merkt nichts.
                if (Prefs.autoSoft(ctx)) handler.postDelayed(softRun, 15_000L)
            }
            Intent.ACTION_SCREEN_ON -> handler.removeCallbacks(softRun)
            Intent.ACTION_USER_PRESENT -> {
                val off = screenOffAt
                screenOffAt = 0L
                if (!Prefs.autoFull(ctx) || off == 0L) return
                if (System.currentTimeMillis() - off < Prefs.unlockAfterMin(ctx) * 60_000L) return
                if (inCall() || ForceStopService.busy()) return
                Thread {
                    val pkgs = try { Apps.running(ctx, Policy.FULL) } catch (_: Exception) { emptyList() }
                    if (pkgs.isEmpty()) return@Thread
                    Apps.killBackground(ctx, pkgs)
                    // Erst den Startbildschirm fertig zeigen lassen.
                    handler.postDelayed({ ForceStopService.request(ctx, pkgs, returnToApp = false) }, 1200L)
                }.start()
            }
        }
    }

    private fun softCleanup() {
        Thread {
            try {
                Apps.killBackground(ctx, Apps.running(ctx, Policy.SOFT) + Apps.running(ctx, Policy.FULL))
            } catch (_: Exception) {
            }
        }.start()
    }

    private fun inCall(): Boolean {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        return am.mode == AudioManager.MODE_IN_CALL || am.mode == AudioManager.MODE_IN_COMMUNICATION
    }

    private fun onBattery(intent: Intent, force: Boolean = false) {
        if (!Prefs.watcherEnabled(ctx)) return
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

        val upper = Prefs.upperLimit(ctx)
        val lower = Prefs.lowerLimit(ctx)
        val maxTemp = Prefs.maxTemp(ctx)

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

    private fun alarm(title: String, text: String) {
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        val pi = PendingIntent.getActivity(ctx, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CH_ALARM)
        else @Suppress("DEPRECATION") Notification.Builder(ctx)
        val n = b.setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(ID_ALARM, n)
    }
}
