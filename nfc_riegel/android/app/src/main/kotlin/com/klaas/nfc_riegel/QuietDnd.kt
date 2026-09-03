package com.klaas.nfc_riegel

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Rückfall, solange Riegel nicht die Anruffilter-App ist: „Bitte nicht stören".
 *
 * Deutlich gröber als der Anruffilter. Android kennt dort keine eigene
 * Nummernliste, und der Filter stellt alles stumm außer den Kategorien, die in
 * der Richtlinie stehen. Eine Auswahl einzelner Kontakte lässt sich damit nicht
 * abbilden — der Weg dafür ist [CallScreening].
 *
 * Der Zustand von vorher wird gemerkt und beim Ende wiederhergestellt: Wer
 * „Bitte nicht stören" selbst eingeschaltet hatte, soll es hinterher nicht aus
 * vorfinden.
 */
class QuietDnd(context: Context) {

    private val app = context.applicationContext

    private val manager =
        app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val prefs = app.getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    fun granted(): Boolean = manager.isNotificationPolicyAccessGranted

    fun openSettings() {
        app.startActivity(
            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** Schaltet den Filter an oder aus. Mehrfaches Aufrufen ändert nichts. */
    fun apply(stumm: Boolean) {
        if (!granted()) return
        if (stumm) einschalten() else ausschalten()
    }

    private fun einschalten() {
        if (prefs.contains(KEY_FILTER)) return

        val vorher = manager.notificationPolicy
        prefs.edit()
            .putInt(KEY_FILTER, manager.currentInterruptionFilter)
            .putInt(KEY_KATEGORIEN, vorher.priorityCategories)
            .putInt(KEY_ANRUFER, vorher.priorityCallSenders)
            .putInt(KEY_NACHRICHTEN, vorher.priorityMessageSenders)
            .apply()

        // Anrufe und Wiederholungsanrufer aus den erlaubten Kategorien nehmen,
        // alles andere so lassen, wie es eingestellt war.
        val ohneAnrufe = vorher.priorityCategories and
            NotificationManager.Policy.PRIORITY_CATEGORY_CALLS.inv() and
            NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS.inv()

        manager.notificationPolicy = NotificationManager.Policy(
            ohneAnrufe,
            vorher.priorityCallSenders,
            vorher.priorityMessageSenders,
        )
        manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
    }

    private fun ausschalten() {
        if (!prefs.contains(KEY_FILTER)) return

        manager.notificationPolicy = NotificationManager.Policy(
            prefs.getInt(KEY_KATEGORIEN, 0),
            prefs.getInt(KEY_ANRUFER, 0),
            prefs.getInt(KEY_NACHRICHTEN, 0),
        )
        manager.setInterruptionFilter(
            prefs.getInt(KEY_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL),
        )

        prefs.edit()
            .remove(KEY_FILTER)
            .remove(KEY_KATEGORIEN)
            .remove(KEY_ANRUFER)
            .remove(KEY_NACHRICHTEN)
            .apply()
    }

    private companion object {
        /** Das Vorhandensein dieses Schlüssels heißt: Riegel hat den Filter gesetzt. */
        const val KEY_FILTER = "dndFilterVorher"
        const val KEY_KATEGORIEN = "dndKategorienVorher"
        const val KEY_ANRUFER = "dndAnruferVorher"
        const val KEY_NACHRICHTEN = "dndNachrichtenVorher"
    }
}
