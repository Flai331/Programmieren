package de.klaas.akku_schoner

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Process
import android.provider.Settings
import java.io.ByteArrayOutputStream

object Apps {

    fun hasUsageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Startbildschirm, Tastatur und diese App selbst werden nie beendet. */
    fun protectedPackages(ctx: Context): Set<String> {
        val result = mutableSetOf(ctx.packageName)
        try {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            ctx.packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { result.add(it) }
        } catch (_: Exception) {
        }
        Settings.Secure.getString(ctx.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.substringBefore("/")?.takeIf { it.isNotBlank() }?.let { result.add(it) }
        return result
    }

    fun isStopped(ctx: Context, pkg: String): Boolean = try {
        val info = ctx.packageManager.getApplicationInfo(pkg, 0)
        (info.flags and ApplicationInfo.FLAG_STOPPED) != 0
    } catch (_: Exception) {
        true
    }

    private data class Usage(val lastUsed: Long, val foreground: Long, val fgService: Long)

    /** Alle Apps mit Symbol im App-Menü, inkl. Nutzungsdaten und Stufe (keep/soft/full). */
    fun list(ctx: Context, withIcons: Boolean = true): List<Map<String, Any?>> {
        val pm = ctx.packageManager
        val protected = protectedPackages(ctx)
        val overrides = Prefs.overrides(ctx)

        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launchable = pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.packageName }
            .toSet()

        val usage = mutableMapOf<String, Usage>()
        // Paket -> an wie vielen der letzten 7 Tage benutzt; null-Map = kein Nutzungszugriff
        var days: Map<String, Int>? = null
        if (hasUsageAccess(ctx)) {
            val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            val now = System.currentTimeMillis()
            try {
                usm?.queryAndAggregateUsageStats(now - 24 * 3600_000L, now)?.forEach { (pkg, s) ->
                    val fgs = if (Build.VERSION.SDK_INT >= 29) s.totalTimeForegroundServiceUsed else 0L
                    usage[pkg] = Usage(s.lastTimeUsed, s.totalTimeInForeground, fgs)
                }
                val daySets = mutableMapOf<String, MutableSet<Long>>()
                usm?.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 7 * 24 * 3600_000L, now)
                    ?.filter { it.totalTimeInForeground > 30_000L }
                    ?.forEach { s ->
                        daySets.getOrPut(s.packageName) { mutableSetOf() }.add(s.firstTimeStamp / (24 * 3600_000L))
                    }
                days = daySets.mapValues { it.value.size }
            } catch (_: Exception) {
            }
        }

        val out = mutableListOf<Map<String, Any?>>()
        for (pkg in launchable) {
            if (pkg == ctx.packageName) continue
            val info = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (_: Exception) {
                continue
            }
            val u = usage[pkg]
            val system = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isProtected = protected.contains(pkg)
            val audio = Build.VERSION.SDK_INT >= 26 && info.category == ApplicationInfo.CATEGORY_AUDIO
            val days7 = days?.let { it[pkg] ?: 0 }
            val auto = Policy.autoLevel(pkg, system, isProtected, audio, days7)
            val level = if (isProtected) Policy.KEEP else overrides[pkg] ?: auto
            out.add(
                mapOf(
                    "pkg" to pkg,
                    "label" to info.loadLabel(pm).toString(),
                    "system" to system,
                    "stopped" to ((info.flags and ApplicationInfo.FLAG_STOPPED) != 0),
                    "protected" to isProtected,
                    "audio" to audio,
                    "days7" to days7,
                    "autoLevel" to auto,
                    "level" to level,
                    "lastUsed" to (u?.lastUsed ?: 0L),
                    "foregroundMs" to (u?.foreground ?: 0L),
                    "fgServiceMs" to (u?.fgService ?: 0L),
                    "icon" to if (withIcons) icon(ctx, info) else null,
                )
            )
        }
        return out
    }

    /** Laufende Apps einer Stufe (für Automatik), ohne Symbole. */
    fun running(ctx: Context, level: String): List<String> =
        list(ctx, withIcons = false)
            .filter { it["level"] == level && it["stopped"] != true && it["protected"] != true }
            .map { it["pkg"] as String }

    private fun icon(ctx: Context, info: ApplicationInfo): ByteArray? = try {
        val d = info.loadIcon(ctx.packageManager)
        val size = 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(c)
        val bos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, bos)
        bmp.recycle()
        bos.toByteArray()
    } catch (_: Exception) {
        null
    }

    /**
     * Sanfter Weg: Android beendet zwischengespeicherte Prozesse der Apps.
     * Apps mit laufendem Dienst (Musik, Navigation, …) überleben das.
     */
    fun killBackground(ctx: Context, pkgs: List<String>): Int {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return 0
        val protected = protectedPackages(ctx)
        var n = 0
        for (pkg in pkgs) {
            if (protected.contains(pkg)) continue
            try {
                am.killBackgroundProcesses(pkg)
                n++
            } catch (_: Exception) {
            }
        }
        return n
    }
}
