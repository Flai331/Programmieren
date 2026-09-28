package com.klaasotte.parkplatz_merker

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/** Prüf-Wecker der Parkschein-Erinnerung: Gehzeit schätzen, erinnern oder neu planen. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Config.init(context)
        val app = context.applicationContext
        val until = Config.ticketUntil
        if (until <= 0L) {
            // Alte Erinnerung ohne Parkschein-Daten (vor dem Update gestellt): wie früher melden.
            if (Config.reminderAt > 0L) notify(app, "Parkschein läuft bald ab", Config.reminderText)
            Config.reminderAt = 0L
            return
        }
        val pending = goAsync()
        LocationHelper.current(app) { loc ->
            try {
                handle(app, until, Reminder.walk(loc))
            } finally {
                try {
                    pending.finish()
                } catch (e: Exception) {
                    // schon beendet
                }
            }
        }
    }

    private fun handle(ctx: Context, until: Long, walk: Pair<Int, Int>?) {
        val now = System.currentTimeMillis()
        val lead = Reminder.leadMinutes(walk?.first)
        if (now < until - lead * 60_000L) {
            val next = Reminder.nextCheck(now, until, lead)
            Reminder.schedule(ctx, next)
            EventLog.info(ctx, "Parkschein: " +
                (if (walk != null) "${walk.first} Min zu Fuß (${walk.second} m)" else "Standort unbekannt") +
                ", nächste Prüfung ${clock(next)}")
            return
        }
        val text = when {
            now >= until -> "Dein Parkschein ist um ${clock(until)} abgelaufen."
            walk != null && walk.second >= 150 ->
                "Parkschein läuft um ${clock(until)} ab – zum Auto sind es ca. ${walk.first} Min zu Fuß " +
                    "(${walk.second} m). Am besten jetzt losgehen."
            else -> "Dein Parkschein läuft um ${clock(until)} ab."
        }
        val title = if (walk != null && walk.second >= 150 && now < until) "Zeit, zum Auto zu gehen" else "Parkschein läuft bald ab"
        notify(ctx, title, text)
        EventLog.info(ctx, "Parkschein: erinnert – $text")
        Reminder.cancel(ctx)
    }

    private fun clock(ms: Long): String {
        val c = Calendar.getInstance()
        c.timeInMillis = ms
        return String.format("%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun notify(ctx: Context, title: String, text: String) {
        if (Build.VERSION.SDK_INT >= 33 && !NotificationManagerCompat.from(ctx).areNotificationsEnabled()) return
        val notif = NotificationCompat.Builder(ctx, "reminder")
            .setSmallIcon(R.drawable.ic_parking)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(
                android.app.PendingIntent.getActivity(
                    ctx,
                    0,
                    Intent(ctx, MainActivity::class.java),
                    (android.app.PendingIntent.FLAG_IMMUTABLE) or (android.app.PendingIntent.FLAG_UPDATE_CURRENT),
                )
            )
            .build()
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(3, notif)
    }
}
