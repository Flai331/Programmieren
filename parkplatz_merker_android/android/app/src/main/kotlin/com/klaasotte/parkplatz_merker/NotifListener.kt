package com.klaasotte.parkplatz_merker

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationCompat

class NotifListener : NotificationListenerService() {

    companion object {
        @Volatile var instance: NotifListener? = null
        val STOP_WORDS = listOf("ausschalten", "beenden", "stopp", "stop", "aus", "schliessen",
                                "exit", "quit", "close", "turn off", "off")

        /** Alle Knopftexte und Indizes der Benachrichtigungen von [pkg] (fuer die Auswahl in der App). */
        fun actions(pkg: String): List<Map<String, Any>> {
            try {
                instance?.activeNotifications?.forEach { sn ->
                    if (sn.packageName == pkg) {
                        val notification = sn.notification
                        val actions = notification?.actions ?: return@forEach
                        if (actions.isEmpty()) return@forEach
                        val result = mutableListOf<Map<String, Any>>()
                        for ((idx, action) in actions.withIndex()) {
                            val title = (action.title?.toString() ?: "").trim()
                            result.add(mapOf("index" to idx, "title" to title))
                        }
                        return result
                    }
                }
            } catch (e: SecurityException) {
                // ignore
            }
            return emptyList()
        }

        /** Liefert Knopftexte und ob Benachrichtigung vorhanden ist – wird in Dart auch direkt mit Package aufgerufen. */
        fun listCloseActions(pkg: String): Map<String, Any> {
            val acts = actions(pkg)
            val hasNotif = acts.isNotEmpty() || hasActionlessNotification(pkg)
            return mapOf(
                "actions" to acts,
                "actionless" to hasActionlessNotification(pkg),
                "hasNotification" to hasNotif
            )
        }

        /** Prueft, ob Benachrichtigung von [pkg] ohne actions vorhanden ist. */
        fun hasActionlessNotification(pkg: String): Boolean {
            try {
                instance?.activeNotifications?.forEach { sn ->
                    if (sn.packageName == pkg) {
                        val notification = sn.notification
                        val actions = notification?.actions
                        if (actions == null || actions.isEmpty()) return true
                    }
                }
            } catch (e: SecurityException) {
                // ignore
            }
            return false
        }

        /** Loest den Ausschaltknopf aus. true = etwas ausgeloest. */
        fun pressStop(pkg: String, wanted: String, index: Int): Boolean {
            try {
                instance?.activeNotifications?.forEach { sn ->
                    if (sn.packageName == pkg) {
                        val notification = sn.notification ?: return@forEach
                        val actions = notification.actions ?: return@forEach
                        if (actions.isEmpty()) return@forEach

                        // Per Index wenn index >= 0
                        if (index >= 0 && index < actions.size) {
                            val action = actions[index]
                            try {
                                action.actionIntent?.send()
                                return true
                            } catch (e: Exception) {
                                // weiter
                            }
                        }

                        // Hat genau EINE action mit leerem Titel? Diese ausloesen.
                        if (actions.size == 1) {
                            val title = (actions[0].title?.toString() ?: "").trim()
                            if (title.isEmpty()) {
                                try {
                                    actions[0].actionIntent?.send()
                                    return true
                                } catch (e: Exception) {
                                    // weiter
                                }
                            }
                        }

                        // Sonst per Text suchen
                        if (wanted.isNotEmpty()) {
                            for (action in actions) {
                                val title = (action.title?.toString() ?: "").trim()
                                if (title.equals(wanted, ignoreCase = true)) {
                                    try {
                                        action.actionIntent?.send()
                                        return true
                                    } catch (e: Exception) {
                                        // weiter
                                    }
                                }
                            }
                        } else {
                            // Automatisch: STOP_WORDS suchen
                            for (action in actions) {
                                val title = (action.title?.toString() ?: "").trim().lowercase()
                                if (STOP_WORDS.any { w -> (title == w) or (title.startsWith("$w ")) or ((title.contains(w)) and (w.length >= 5)) }) {
                                    try {
                                        action.actionIntent?.send()
                                        return true
                                    } catch (e: Exception) {
                                        // weiter
                                    }
                                }
                            }
                        }
                        return false
                    }
                }
            } catch (e: SecurityException) {
                // ignore
            }
            return false
        }

        fun hasNotification(pkg: String): Boolean {
            try {
                return instance?.activeNotifications?.any { it.packageName == pkg } ?: false
            } catch (e: SecurityException) {
                return false
            }
        }

        fun isEnabled(ctx: Context): Boolean {
            val listeners = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners")
            val myComponent = ComponentName(ctx, NotifListener::class.java).flattenToString()
            return listeners?.split(":")?.any { it.equals(myComponent, ignoreCase = true) } ?: false
        }
    }

    override fun onListenerConnected() {
        instance = this
    }

    override fun onListenerDisconnected() {
        instance = null
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
