package com.klaasotte.parkplatz_merker

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33) {
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                return
            }
        }

        val text = Config.reminderText
        val notif = NotificationCompat.Builder(context, "reminder")
            .setSmallIcon(R.drawable.ic_parking)
            .setContentTitle("Parkschein läuft bald ab")
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(
                android.app.PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(3, notif)

        Config.reminderAt = 0L
    }
}
