package com.klaas.nfc_riegel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

/**
 * Dauerhafte Benachrichtigung während einer Sperre. Bewusst eine gewöhnliche
 * ongoing-Notification: den AccessibilityService hält das System selbst am Leben,
 * ein Foreground Service wäre überflüssig.
 *
 * Was drinsteht, rechnet [NotificationText] aus — hier bleibt nur das Anfassen
 * von Android übrig.
 */
object LockNotification {

    private const val CHANNEL_ID = "riegel_lock"
    private const val NOTIFICATION_ID = 1

    fun show(context: Context, state: LockState, now: Long = System.currentTimeMillis()) {
        val inhalt = NotificationText.content(state, now) ?: return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(inhalt.title)
            .setContentText(inhalt.text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    fun hide(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(manager: NotificationManager) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Riegel-Status",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Zeigt an, ob der Riegel gerade sperrt"
        manager.createNotificationChannel(channel)
    }
}
