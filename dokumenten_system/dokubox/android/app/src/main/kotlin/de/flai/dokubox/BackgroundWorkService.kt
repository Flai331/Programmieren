package de.flai.dokubox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/// Hält die App am Leben, während ein Scan bzw. dessen Verarbeitung läuft –
/// auch wenn das Handy gesperrt oder die App im Hintergrund ist
/// (Vordergrunddienst mit Benachrichtigung + Wake-/WLAN-Lock).
class BackgroundWorkService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra("text") ?: "Scan läuft …"
        val notification = build(this, text, ongoing = true)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(ID_RUNNING, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(ID_RUNNING, notification)
        }
        if (wakeLock == null) {
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "dokubox:scan").apply {
                    setReferenceCounted(false)
                    acquire(60 * 60 * 1000L) // höchstens 1 Stunde
                }
        }
        if (wifiLock == null) {
            @Suppress("DEPRECATION")
            wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "dokubox:scan").apply {
                    setReferenceCounted(false)
                    acquire()
                }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wifiLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "dokubox_scan"
        const val ID_RUNNING = 4711
        const val ID_DONE = 4712

        fun build(ctx: Context, text: String, ongoing: Boolean): Notification {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Scannen", NotificationManager.IMPORTANCE_LOW))
            }
            val open = PendingIntent.getActivity(
                ctx, 0,
                Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            @Suppress("DEPRECATION")
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL)
                    else Notification.Builder(ctx)
            return b.setContentTitle("DokuBox")
                .setContentText(text)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(open)
                .setOngoing(ongoing)
                .setAutoCancel(!ongoing)
                .build()
        }

        fun start(ctx: Context, text: String) {
            val i = Intent(ctx, BackgroundWorkService::class.java).putExtra("text", text)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context, doneText: String?) {
            ctx.stopService(Intent(ctx, BackgroundWorkService::class.java))
            if (doneText != null) {
                val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(ID_DONE, build(ctx, doneText, ongoing = false))
            }
        }
    }
}
