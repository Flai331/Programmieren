package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

@SuppressLint("MissingPermission", "ScheduleExactAlarm")
object Reminder {
    fun schedule(ctx: Context, atMs: Long, text: String): Boolean {
        Config.reminderAt = atMs
        Config.reminderText = text

        val intent = Intent(ctx, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmMgr = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        alarmMgr ?: return false

        return try {
            if (Build.VERSION.SDK_INT >= 31 && alarmMgr.canScheduleExactAlarms()) {
                alarmMgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
                true
            } else if (Build.VERSION.SDK_INT >= 31) {
                alarmMgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
                true
            } else {
                alarmMgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    fun cancel(ctx: Context) {
        Config.reminderAt = 0L
        Config.reminderText = ""

        val intent = Intent(ctx, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmMgr = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        alarmMgr?.cancel(pi)
    }
}
