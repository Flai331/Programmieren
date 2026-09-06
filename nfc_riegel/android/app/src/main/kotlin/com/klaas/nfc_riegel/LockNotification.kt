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

    fun show(context: Context, state: LockState, now: Long = System.currentTimeMillis()) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val freigabe = state.release?.takeIf { now < it.endsAt }

        val gesperrteProfile = buildSet {
            state.chipLock?.let { add(it.profileId) }
            state.timeLocks.forEach { add(it.profileId) }
        }
        if (gesperrteProfile.isEmpty()) return

        val namen = gesperrteProfile.mapNotNull { state.profileById(it)?.name }
        val anzahlApps = gesperrteProfile
            .flatMap { state.profileById(it)?.blockedPackages ?: emptySet() }
            .distinct()
            .size

        val fruehestesEnde = state.timeLocks.minOfOrNull { it.endsAt }
        val text = when {
            freigabe != null -> "Frei bis ${uhrzeit(freigabe.endsAt)} — danach wieder zu"
            fruehestesEnde != null && state.chipLock != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)}, der Rest nach erneutem Scan"
            fruehestesEnde != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)} — vorher nur mit Generalschlüssel"
            else -> "Chip scannen, um freizugeben"
        }

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(
                if (freigabe != null) {
                    "Freigabe läuft — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}"
                } else {
                    "Riegel aktiv — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}, " +
                        "$anzahlApps Apps gesperrt"
                }
            )
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun uhrzeit(millis: Long): String =
        SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(millis))

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
