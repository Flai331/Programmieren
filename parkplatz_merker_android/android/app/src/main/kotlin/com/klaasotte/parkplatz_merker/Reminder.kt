package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import kotlin.math.ceil
import kotlin.math.max

/**
 * Parkschein-Erinnerung, angepasst an den Fußweg zum Auto.
 *
 * Statt fest 15 Minuten vorher prüft ein Wecker in Abständen den eigenen Standort,
 * schätzt die Gehzeit zum Auto und erinnert, sobald es Zeit wird loszugehen:
 * Vorlauf = Gehzeit + 5 Minuten Puffer, mindestens 10 Minuten.
 * Ohne Standort gilt wie früher: 15 Minuten vorher.
 */
@SuppressLint("MissingPermission", "ScheduleExactAlarm")
object Reminder {
    /** Gehgeschwindigkeit ca. 4,5 km/h. */
    private const val WALK_M_PER_MIN = 75.0
    /** Umwege gegenüber der Luftlinie. */
    private const val DETOUR = 1.3
    private const val BUFFER_MIN = 5
    private const val MIN_LEAD_MIN = 10
    private const val FALLBACK_LEAD_MIN = 15

    /** Parkschein bis [untilMs] für das Auto bei [lat]/[lng]. */
    fun scheduleTicket(ctx: Context, untilMs: Long, lat: Double, lng: Double, text: String): Boolean {
        Config.ticketUntil = untilMs
        Config.ticketLat = lat
        Config.ticketLng = lng
        Config.reminderText = text
        // Erste Prüfung: gleich jetzt (schätzt Gehzeit und plant weiter).
        return schedule(ctx, System.currentTimeMillis() + 5_000L)
    }

    /** Stellt den Prüf-Wecker auf [atMs]. */
    fun schedule(ctx: Context, atMs: Long): Boolean {
        Config.reminderAt = atMs
        val alarmMgr = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        val pi = pendingIntent(ctx)
        return try {
            if (Build.VERSION.SDK_INT >= 31 && !alarmMgr.canScheduleExactAlarms()) {
                alarmMgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
            } else {
                alarmMgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Nach Neustart: laufenden Parkschein weiter überwachen. */
    fun onBoot(ctx: Context) {
        if (Config.ticketUntil > System.currentTimeMillis()) {
            schedule(ctx, max(Config.reminderAt, System.currentTimeMillis() + 60_000L))
        }
    }

    fun cancel(ctx: Context) {
        Config.reminderAt = 0L
        Config.reminderText = ""
        Config.ticketUntil = 0L
        val alarmMgr = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        alarmMgr?.cancel(pendingIntent(ctx))
    }

    private fun pendingIntent(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx,
        1,
        Intent(ctx, ReminderReceiver::class.java),
        (PendingIntent.FLAG_UPDATE_CURRENT) or (PendingIntent.FLAG_IMMUTABLE),
    )

    /** Geschätzte Gehzeit in Minuten und Weg in Metern, oder null ohne Standort. */
    fun walk(loc: Location?): Pair<Int, Int>? {
        if (loc == null) return null
        val out = FloatArray(1)
        Location.distanceBetween(loc.latitude, loc.longitude, Config.ticketLat, Config.ticketLng, out)
        val meters = out[0] * DETOUR
        return Pair(ceil(meters / WALK_M_PER_MIN).toInt(), meters.toInt())
    }

    /** Vorlauf in Minuten für die Gehzeit [walkMin] (null = unbekannt). */
    fun leadMinutes(walkMin: Int?): Int =
        if (walkMin == null) FALLBACK_LEAD_MIN else max(MIN_LEAD_MIN, walkMin + BUFFER_MIN)

    /**
     * Nächste Prüfung: kurz bevor es bei gleicher Entfernung Zeit wäre,
     * spätestens in 20 Minuten (man kann sich ja weiter entfernen), frühestens in 2 Minuten.
     */
    fun nextCheck(now: Long, untilMs: Long, leadMin: Int): Long {
        val due = untilMs - leadMin * 60_000L
        val wanted = due - BUFFER_MIN * 60_000L
        return wanted.coerceIn(now + 2 * 60_000L, now + 20 * 60_000L)
    }
}
