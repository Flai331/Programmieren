package com.klaasotte.parkplatz_merker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object Notifications {
    const val CHANNEL_TRIP = "trip"
    const val CHANNEL_PARKED = "parked"
    const val CHANNEL_REMINDER = "reminder"

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val tripChannel = NotificationChannel("trip", "Fahrt", NotificationManager.IMPORTANCE_LOW)
        tripChannel.description = "Fahrt-Benachrichtigungen"
        nm.createNotificationChannel(tripChannel)

        val parkedChannel = NotificationChannel("parked", "Geparkt", NotificationManager.IMPORTANCE_DEFAULT)
        parkedChannel.description = "Parkplatz-Bestätigung"
        nm.createNotificationChannel(parkedChannel)

        val reminderChannel = NotificationChannel("reminder", "Parkschein", NotificationManager.IMPORTANCE_HIGH)
        reminderChannel.description = "Parkschein-Erinnerung"
        nm.createNotificationChannel(reminderChannel)
    }
}
