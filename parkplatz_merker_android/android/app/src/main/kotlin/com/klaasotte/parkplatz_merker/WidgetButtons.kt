package com.klaasotte.parkplatz_merker

import android.app.Notification
import android.content.Context
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews

/**
 * Knöpfe in einem eigenen Benachrichtigungs-Layout („Widget“ in der Leiste, z. B. Blitzer.de).
 *
 * Solche Knöpfe sind keine Notification.Actions. Wir bauen das Layout mit der öffentlichen
 * API RemoteViews.apply() unsichtbar nach (wie ein Launcher seine Widgets) und klicken den
 * gewünschten View – dessen Klick-Handler löst den PendingIntent der fremden App aus.
 * Die nachgebauten Views werden nie angezeigt.
 */
object WidgetButtons {
    private val STOP_WORDS = listOf(
        "exit", "close", "quit", "stop", "power", "shutdown", "beenden", "schließen", "schliessen", "ausschalten",
    )

    /** Eigene Layouts der ersten Benachrichtigung von [pkg], mit Schlüssel ("big", "normal", "headsup"). */
    private fun layouts(pkg: String): List<Pair<String, RemoteViews>> {
        val sbn = try {
            NotifListener.instance?.activeNotifications?.firstOrNull { it.packageName == pkg }
        } catch (e: Exception) {
            null
        } ?: return emptyList()
        val n: Notification = sbn.notification ?: return emptyList()
        val out = mutableListOf<Pair<String, RemoteViews>>()
        @Suppress("DEPRECATION")
        n.bigContentView?.let { out.add("big" to it) }
        @Suppress("DEPRECATION")
        n.contentView?.let { out.add("normal" to it) }
        @Suppress("DEPRECATION")
        n.headsUpContentView?.let { out.add("headsup" to it) }
        return out
    }

    /** Layout aufbauen und alle klickbaren Views in fester Reihenfolge liefern. */
    private fun clickables(ctx: Context, rv: RemoteViews): List<View> {
        val root = rv.apply(ctx, FrameLayout(ctx))
        val out = mutableListOf<View>()
        fun walk(v: View) {
            if (v.hasOnClickListeners()) out.add(v)
            if (v is ViewGroup) {
                for (i in 0 until v.childCount) walk(v.getChildAt(i))
            }
        }
        walk(root)
        return out
    }

    private fun idName(v: View): String {
        if (v.id == View.NO_ID) return ""
        return try {
            v.resources.getResourceEntryName(v.id)
        } catch (e: Exception) {
            ""
        }
    }

    private fun onMainThread(): Boolean = Looper.myLooper() == Looper.getMainLooper()

    /** Alle Widget-Knöpfe: key ("big:3"), name (Ressourcen-Name), desc (Beschreibung). */
    fun list(ctx: Context, pkg: String): List<Map<String, Any>> {
        if (!onMainThread()) return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        for ((key, rv) in layouts(pkg)) {
            try {
                clickables(ctx.applicationContext, rv).forEachIndexed { i, v ->
                    result.add(
                        mapOf(
                            "key" to "$key:$i",
                            "name" to idName(v),
                            "desc" to (v.contentDescription?.toString() ?: ""),
                        )
                    )
                }
            } catch (e: Exception) {
                EventLog.info(ctx, "Widget-Knöpfe ($key) nicht lesbar: ${e.javaClass.simpleName}")
            }
        }
        return result
    }

    /** Drückt den Knopf [key] ("big:3"). true = geklickt. Misserfolg mit Grund in der Diagnose. */
    fun press(ctx: Context, pkg: String, key: String): Boolean {
        if (!onMainThread()) return false
        val parts = key.split(":")
        val index = parts.getOrNull(1)?.toIntOrNull()
        if (parts.size != 2 || index == null) {
            EventLog.info(ctx, "Widget-Knopf $key: ungültige Auswahl")
            return false
        }
        val all = layouts(pkg)
        val rv = all.firstOrNull { it.first == parts[0] }?.second
        if (rv == null) {
            val available = all.joinToString(", ") { it.first }.ifEmpty { "keine" }
            EventLog.info(ctx, "Widget-Knopf $key: Ansicht „${parts[0]}“ gerade nicht vorhanden (vorhanden: $available)")
            return false
        }
        return try {
            val views = clickables(ctx.applicationContext, rv)
            if (index < 0 || index >= views.size) {
                EventLog.info(ctx, "Widget-Knopf $key: nur ${views.size} Knöpfe in dieser Ansicht")
                false
            } else {
                val clicked = views[index].performClick()
                if (!clicked) EventLog.info(ctx, "Widget-Knopf $key: Klick ohne Wirkung")
                clicked
            }
        } catch (e: Exception) {
            EventLog.info(ctx, "Widget-Knopf $key nicht drückbar: ${e.javaClass.simpleName} ${e.message}")
            false
        }
    }

    /** Genau ein Knopf, dessen Name/Beschreibung nach Beenden klingt → drücken. */
    fun pressAuto(ctx: Context, pkg: String): Boolean {
        val all = list(ctx, pkg)
        val candidates = all.filter { b ->
            val text = ((b["name"] as? String).orEmpty() + " " + (b["desc"] as? String).orEmpty()).lowercase()
            STOP_WORDS.any { w -> text.contains(w) }
        }
        // Gleicher Knopf kann in mehreren Layouts (groß/klein) vorkommen – nach Name zusammenfassen.
        val distinct = candidates.distinctBy { b -> (b["name"] as? String).orEmpty() + "|" + (b["desc"] as? String).orEmpty() }
        if (distinct.size != 1) {
            // Was gibt es überhaupt? Damit man im Protokoll sieht, welchen Knopf man wählen muss.
            val seen = all.joinToString(", ") { b ->
                val label = listOf(b["name"] as? String, b["desc"] as? String)
                    .filter { !it.isNullOrEmpty() }.joinToString("/")
                if (label.isEmpty()) "${b["key"]}" else "${b["key"]} ($label)"
            }.ifEmpty { "keine" }
            val why = if (distinct.isEmpty()) "keiner klingt nach Beenden" else "${distinct.size} möglich, nicht eindeutig"
            EventLog.info(ctx, "Widget-Knöpfe automatisch: $why – gefunden: $seen")
            return false
        }
        val key = distinct[0]["key"] as? String ?: return false
        return press(ctx, pkg, key)
    }
}
