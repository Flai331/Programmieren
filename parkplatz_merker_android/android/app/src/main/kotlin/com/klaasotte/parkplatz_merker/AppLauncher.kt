package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

@SuppressLint("MissingPermission")
object AppLauncher {
    private const val FRESH_MS = 10 * 60_000L
    private var misses = 0

    fun seen(ctx: Context) {
        misses = 0
        val appCtx = ctx.applicationContext
        val now = System.currentTimeMillis()
        val wasPresent = (Config.devicePresent && (now - Config.devicePresentAt) < FRESH_MS)
        Config.devicePresent = true
        Config.devicePresentAt = now
        if (!wasPresent) launch(appCtx)
    }

    fun miss(ctx: Context, strong: Boolean) {
        if (!Config.devicePresent) return
        misses++
        if ((strong) || (misses >= 2)) {
            Config.devicePresent = false
            misses = 0
            if (Config.closeOnGone) close(ctx.applicationContext)
        }
    }

    fun reset() {
        Config.devicePresent = false
        misses = 0
    }

    /** [fromForeground]: Aufruf aus der sichtbaren App (Test) – dann ist Starten immer erlaubt. */
    fun launch(ctx: Context, fromForeground: Boolean = false) {
        val pkg = Config.launchPackage
        if (pkg.isEmpty()) return
        val label = Config.launchLabel
        val appCtx = ctx.applicationContext
        val pm = appCtx.packageManager
        val intent = pm.getLaunchIntentForPackage(pkg) ?: run {
            EventLog.info(appCtx, "App-Start: $pkg nicht gefunden")
            return
        }
        intent.addFlags((Intent.FLAG_ACTIVITY_NEW_TASK) or (Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED))

        if (fromForeground || Settings.canDrawOverlays(appCtx)) {
            try {
                appCtx.startActivity(intent)
                EventLog.info(appCtx, "App geöffnet: $label")
                return
            } catch (e: Exception) {
                EventLog.info(appCtx, "App-Start Fehler: ${e.message}")
            }
        }

        // Benachrichtigung zeigen
        val nm = NotificationManagerCompat.from(appCtx)
        if (!nm.areNotificationsEnabled()) return

        val pendingIntent = android.app.PendingIntent.getActivity(
            appCtx, 6, intent,
            (android.app.PendingIntent.FLAG_IMMUTABLE) or (android.app.PendingIntent.FLAG_UPDATE_CURRENT)
        )
        val notification = NotificationCompat.Builder(appCtx, Notifications.CHANNEL_APP)
            .setSmallIcon(R.drawable.ic_car)
            .setContentTitle("$label öffnen")
            .setContentText("Dein Auto ist erkannt – tippe zum Öffnen.")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            nm.notify(4, notification)
        } catch (e: SecurityException) {
            // Benachrichtigungen nicht erlaubt
        }
        EventLog.info(appCtx, "App-Start: Hinweis gezeigt (Berechtigung „Über anderen Apps“ fehlt)")
    }

    fun close(ctx: Context) {
        val pkg = Config.launchPackage
        if (pkg.isEmpty()) return
        val label = Config.launchLabel
        val appCtx = ctx.applicationContext
        val nm = NotificationManagerCompat.from(appCtx)
        nm.cancel(4)

        if (Settings.canDrawOverlays(appCtx)) {
            try {
                val homeIntent = Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                appCtx.startActivity(homeIntent)
            } catch (e: Exception) {
                // ignore
            }
        }

        Handler(Looper.getMainLooper()).postDelayed({
            try {
                (appCtx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager)
                    ?.killBackgroundProcesses(pkg)
            } catch (e: Exception) {
                // ignore
            }
            EventLog.info(appCtx, "App geschlossen (Startbildschirm + beenden versucht): $label")
        }, 1500L)
    }

    fun listApps(ctx: Context): List<Map<String, String>> {
        val appCtx = ctx.applicationContext
        val pm = appCtx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val allApps = if (android.os.Build.VERSION.SDK_INT >= 33) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }

        val apps = LinkedHashMap<String, String>()
        val own = appCtx.packageName
        for (info in allApps) {
            val pkg = info.activityInfo.packageName
            if (pkg == own) continue
            val lbl = info.loadLabel(pm).toString()
            apps[pkg] = lbl
        }

        // Nach Label sortieren
        return apps.entries
            .sortedBy { it.value.lowercase() }
            .map { mapOf("package" to it.key, "label" to it.value) }
    }
}
