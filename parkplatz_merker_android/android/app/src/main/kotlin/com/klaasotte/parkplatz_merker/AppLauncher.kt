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
        if (!wasPresent) {
            if (Config.hasDevice) {
                CarSession.start(appCtx)
            }
        }
    }

    fun miss(ctx: Context, strong: Boolean) {
        if (!Config.devicePresent) return
        misses++
        if ((strong) || (misses >= 2)) {
            Config.devicePresent = false
            misses = 0
            if (Config.hasDevice) {
                CarSession.end(ctx.applicationContext)
            }
        }
    }

    fun reset() {
        Config.devicePresent = false
        misses = 0
    }

    fun launchAll(ctx: Context, fromForeground: Boolean = false) {
        val appCtx = ctx.applicationContext
        val appsJson = Config.launchApps
        if (appsJson.isEmpty()) return

        try {
            val ja = org.json.JSONArray(appsJson)
            for (i in 0 until ja.length()) {
                val obj = ja.getJSONObject(i)
                val pkg = obj.getString("package")
                val label = obj.getString("label")
                val closeActionIdx = obj.getInt("closeActionIndex")
                val closeActionTitle = obj.getString("closeActionTitle")

                Handler(Looper.getMainLooper()).postDelayed({
                    launchOne(appCtx, pkg, label, closeActionIdx, closeActionTitle, fromForeground, i)
                }, i * 1500L)
            }
        } catch (e: Exception) {
            EventLog.info(appCtx, "launchAll Fehler: ${e.message}")
        }
    }

    private fun launchOne(ctx: Context, pkg: String, label: String, closeActionIdx: Int, closeActionTitle: String, fromForeground: Boolean, notifId: Int) {
        if (pkg.isEmpty()) return
        val pm = ctx.packageManager
        val intent = pm.getLaunchIntentForPackage(pkg) ?: run {
            EventLog.info(ctx, "App-Start: $pkg nicht gefunden")
            return
        }
        intent.addFlags((Intent.FLAG_ACTIVITY_NEW_TASK) or (Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED))

        if (fromForeground || Settings.canDrawOverlays(ctx)) {
            try {
                ctx.startActivity(intent)
                EventLog.info(ctx, "App geöffnet: $label")
                return
            } catch (e: Exception) {
                EventLog.info(ctx, "App-Start Fehler: ${e.message}")
            }
        }

        val nm = NotificationManagerCompat.from(ctx)
        if (!nm.areNotificationsEnabled()) return

        val pendingIntent = android.app.PendingIntent.getActivity(
            ctx, (60 + notifId), intent,
            (android.app.PendingIntent.FLAG_IMMUTABLE) or (android.app.PendingIntent.FLAG_UPDATE_CURRENT)
        )
        val notification = NotificationCompat.Builder(ctx, Notifications.CHANNEL_APP)
            .setSmallIcon(R.drawable.ic_car)
            .setContentTitle("$label öffnen")
            .setContentText("Dein Auto ist erkannt – tippe zum Öffnen.")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            nm.notify((40 + notifId), notification)
        } catch (e: SecurityException) {
            // Benachrichtigungen nicht erlaubt
        }
        EventLog.info(ctx, "App-Start: Hinweis gezeigt (Berechtigung „Über anderen Apps“ fehlt)")
    }

    fun closeAll(ctx: Context, fromForeground: Boolean = false) {
        val appCtx = ctx.applicationContext
        val appsJson = Config.launchApps
        if (appsJson.isEmpty()) return

        try {
            val ja = org.json.JSONArray(appsJson)
            val nm = NotificationManagerCompat.from(appCtx)
            for (i in 0 until ja.length()) {
                val obj = ja.getJSONObject(i)
                val pkg = obj.getString("package")
                val closeActionTitle = obj.getString("closeActionTitle")
                val closeActionIdx = obj.getInt("closeActionIndex")
                nm.cancel((40 + i))
                NotifListener.pressStop(pkg, closeActionTitle, closeActionIdx)
            }

            if (fromForeground || Settings.canDrawOverlays(appCtx)) {
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
                    val am = appCtx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    for (i in 0 until ja.length()) {
                        val obj = ja.getJSONObject(i)
                        val pkg = obj.getString("package")
                        am?.killBackgroundProcesses(pkg)
                    }
                } catch (e: Exception) {
                    // ignore
                }
                EventLog.info(appCtx, "Apps geschlossen (Startbildschirm + beenden versucht)")
            }, 1500L)

            if (Config.forceStopFallback) {
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        for (i in 0 until ja.length()) {
                            val obj = ja.getJSONObject(i)
                            val pkg = obj.getString("package")
                            if (NotifListener.hasNotification(pkg)) {
                                ForceStopService.request(appCtx, pkg)
                            }
                        }
                    } catch (e: Exception) {
                        // ignore
                    }
                }, 4000L)
            }
        } catch (e: Exception) {
            EventLog.info(appCtx, "closeAll Fehler: ${e.message}")
        }
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

    fun close(ctx: Context, fromForeground: Boolean = false) {
        val pkg = Config.launchPackage
        if (pkg.isEmpty()) return
        val label = Config.launchLabel
        val appCtx = ctx.applicationContext
        val nm = NotificationManagerCompat.from(appCtx)
        nm.cancel(4)

        val pressed = NotifListener.pressStop(pkg, Config.closeActionTitle, Config.closeActionIndex)
        EventLog.info(appCtx, if (pressed) "Ausschaltknopf von $label gedrückt" else "Kein Ausschaltknopf gefunden (Benachrichtigungszugriff an?)")

        if (fromForeground || Settings.canDrawOverlays(appCtx)) {
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

        if (Config.forceStopFallback) {
            Handler(Looper.getMainLooper()).postDelayed({
                if (!pressed || NotifListener.hasNotification(pkg)) {
                    ForceStopService.request(appCtx, pkg)
                }
            }, 4000L)
        }
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
