package com.klaasotte.parkplatz_merker

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Rohereignisse als JSON-Zeilen in filesDir/events.jsonl.
 * Der Dienst hängt an, die App holt sie mit [drain] ab (und leert die Datei).
 * Beides läuft über dieselbe Sperre.
 */
object EventLog {
    private const val TAG = "EventLog"
    private const val FILE_NAME = "events.jsonl"
    private const val MAX_LINES = 20000
    private val lock = Any()
    private var appendsSinceCheck = 0

    private fun file(context: Context) = File(context.filesDir, FILE_NAME)

    fun append(context: Context, event: JSONObject) {
        synchronized(lock) {
            try {
                val f = file(context)
                f.appendText(event.toString() + "\n")
                appendsSinceCheck++
                if (appendsSinceCheck >= 500) {
                    appendsSinceCheck = 0
                    val lines = f.readLines().filter { it.isNotBlank() }
                    if (lines.size > MAX_LINES) {
                        f.writeText(lines.takeLast(MAX_LINES / 2).joinToString("\n", postfix = "\n"))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "append fehlgeschlagen", e)
            }
        }
    }

    fun drain(context: Context): List<String> {
        synchronized(lock) {
            return try {
                val f = file(context)
                if (!f.exists()) return emptyList()
                val lines = f.readLines().filter { it.isNotBlank() }
                f.writeText("")
                lines
            } catch (e: Exception) {
                Log.e(TAG, "drain fehlgeschlagen", e)
                emptyList()
            }
        }
    }

    fun info(context: Context, msg: String) {
        val event = JSONObject()
        event.put("type", "info")
        event.put("t", System.currentTimeMillis())
        event.put("msg", msg)
        append(context, event)
    }
}
