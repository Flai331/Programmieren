package com.klaas.nfc_riegel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Dauerhafte Benachrichtigung während einer Sperre. Bewusst eine gewöhnliche
 * ongoing-Notification: den AccessibilityService hält das System selbst am Leben,
 * ein Foreground Service wäre überflüssig.
 */
object LockNotification {

    private const val CHANNEL_ID = "riegel_lock"
    private const val NOTIFICATION_ID = 1

    fun show(context: Context, state: LockState) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val lock = state.chipLock ?: return
        val profile = state.profileById(lock.profileId)
        val endsAt = lock.endsAt

        val text = if (endsAt != null) {
            "Frei ab ${SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(endsAt))} " +
                "oder nach erneutem Scan"
        } else {
            "Chip scannen, um freizugeben"
        }

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(
                "Riegel aktiv — ${profile?.name ?: "Unbekannt"}, " +
                    "${profile?.blockedPackages?.size ?: 0} Apps gesperrt"
            )
            .setContentText(text)
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
