package de.klaas.suchgebiet

import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

// Fehlermeldungen an die Notion-Fehlerzentrale (🐞 → 🐛 Suchgebiet-Karten).
// Den Bericht stellt die Web-App zusammen (web/report.js, ohne Einsatzdaten); hier kommen Gerät und
// Android-Version dazu. Jede Meldung landet zuerst in einer Warteschlange (SharedPreferences) und
// wird dann im Hintergrund gesendet – ohne Netz beim nächsten Start bzw. bei der nächsten Meldung.
object BugReporter {
    private const val TAG = "Suchgebiet"
    private const val PREFS = "bugreports"
    private const val KEY = "queue"
    private const val MAX_QUEUE = 20
    private const val MAX_FIELD = 2000
    private const val DATABASE = "5574dcecd7e84a0aa79446bab3915a47"

    private lateinit var app: Context
    private val worker = Executors.newSingleThreadExecutor()
    private val lock = Any()

    val hasToken: Boolean get() = BuildConfig.NOTION_TOKEN.isNotEmpty()

    fun init(ctx: Context) {
        app = ctx.applicationContext
        installCrashHandler()
        flushAsync()
    }

    /** Bericht (JSON aus report.js) einreihen und senden. Gibt das ergänzte JSON zurück. */
    fun report(json: String): JSONObject {
        val o = withDevice(JSONObject(json))
        // Ohne Token geht eine manuelle Meldung per Mail (MainActivity) – dann nicht zusätzlich einreihen
        if (hasToken || o.optString("kind") != "Manuelle Meldung") enqueue(o, commit = false)
        flushAsync()
        return o
    }

    fun device(): String = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
    fun os(): String = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

    private fun withDevice(o: JSONObject): JSONObject = o.put("device", device()).put("os", os())

    // Native Abstürze: Bericht sofort speichern (commit), beim nächsten Start senden
    private fun installCrashHandler() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            try {
                val msg = "${e.javaClass.simpleName}: ${e.message ?: ""}"
                val stack = Log.getStackTraceString(e)
                val o = JSONObject()
                    .put("title", "Absturz: $msg".take(120))
                    .put("kind", "Absturz")
                    .put("description", "")
                    .put("error", "$msg\n$stack")
                    .put("log", "")
                    .put("page", "Android (Thread ${thread.name})")
                    .put("role", "")
                    .put("version", "Android ${BuildConfig.VERSION_NAME}")
                    .put("fingerprint", fingerprint("crash|${e.javaClass.name}|" + e.stackTrace.take(3).joinToString("|")))
                    .put("time", nowIso())
                enqueue(withDevice(o), commit = true)
            } catch (_: Throwable) { /* beim Absturz nichts weiter riskieren */ }
            previous?.uncaughtException(thread, e)
        }
    }

    private fun nowIso(): String = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.ROOT)
        .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(java.util.Date())

    private fun fingerprint(s: String): String {
        var h = 0x811c9dc5.toInt()
        for (c in s) { h = h xor c.code; h *= 0x01000193 }
        return String.format("%08x", h)
    }

    private fun prefs() = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun readQueue(): JSONArray = try { JSONArray(prefs().getString(KEY, "[]")) } catch (_: Exception) { JSONArray() }

    private fun writeQueue(q: JSONArray, commit: Boolean) {
        val ed = prefs().edit().putString(KEY, q.toString())
        if (commit) ed.commit() else ed.apply()
    }

    private fun enqueue(o: JSONObject, commit: Boolean) = synchronized(lock) {
        val q = readQueue()
        q.put(o)
        while (q.length() > MAX_QUEUE) q.remove(0)
        writeQueue(q, commit)
    }

    fun flushAsync() {
        if (!hasToken) return
        worker.execute {
            while (true) {
                val next = synchronized(lock) { readQueue().optJSONObject(0) } ?: break
                when (send(next)) {
                    Result.OK, Result.DROP -> synchronized(lock) {
                        val q = readQueue()
                        // nur entfernen, wenn es noch derselbe Eintrag ist
                        if (q.length() > 0 && q.optJSONObject(0)?.optString("fingerprint") == next.optString("fingerprint")) {
                            q.remove(0)
                            writeQueue(q, commit = false)
                        }
                    }
                    Result.RETRY -> break
                }
            }
        }
    }

    private enum class Result { OK, RETRY, DROP }

    private fun text(s: String?): JSONObject {
        val v = (s ?: "").take(MAX_FIELD)
        val arr = JSONArray()
        if (v.isNotEmpty()) arr.put(JSONObject().put("text", JSONObject().put("content", v)))
        return JSONObject().put("rich_text", arr)
    }

    private fun select(name: String) = JSONObject().put("select", JSONObject().put("name", name))

    private fun body(o: JSONObject): String {
        val title = JSONArray().put(JSONObject().put("text", JSONObject().put("content", o.optString("title", "Fehler").take(MAX_FIELD))))
        val props = JSONObject()
            .put("Titel", JSONObject().put("title", title))
            .put("Status", select("Offen"))
            .put("Art", select(o.optString("kind", "Auto-Fehler")))
            .put("Plattform", select("Android"))
            .put("Beschreibung", text(o.optString("description")))
            .put("Fehler", text(o.optString("error")))
            .put("Protokoll", text(o.optString("log")))
            .put("Seite", text(o.optString("page")))
            .put("Benutzerrolle", text(o.optString("role")))
            .put("Gerät", text(o.optString("device")))
            .put("OS", text(o.optString("os")))
            .put("Version", text(o.optString("version")))
            .put("Fingerprint", text(o.optString("fingerprint")))
        val time = o.optString("time")
        if (time.isNotEmpty()) props.put("Zeitstempel", JSONObject().put("date", JSONObject().put("start", time)))
        return JSONObject()
            .put("parent", JSONObject().put("database_id", DATABASE))
            .put("properties", props)
            .toString()
    }

    private fun send(o: JSONObject): Result {
        var con: HttpURLConnection? = null
        return try {
            con = (URL("https://api.notion.com/v1/pages").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 20000
                doOutput = true
                setRequestProperty("Authorization", "Bearer ${BuildConfig.NOTION_TOKEN}")
                setRequestProperty("Notion-Version", "2022-06-28")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
            }
            con.outputStream.use { it.write(body(o).toByteArray(Charsets.UTF_8)) }
            val code = con.responseCode
            when {
                code in 200..299 -> Result.OK
                // 400: Bericht passt nicht (wird nie klappen) → verwerfen statt ewig erneut senden
                code == 400 -> { Log.w(TAG, "Fehlermeldung abgelehnt (400)"); Result.DROP }
                else -> { Log.w(TAG, "Fehlermeldung später erneut senden ($code)"); Result.RETRY }
            }
        } catch (e: Exception) {
            Log.i(TAG, "Fehlermeldung ohne Netz – später erneut (${e.javaClass.simpleName})")
            Result.RETRY
        } finally {
            con?.disconnect()
        }
    }
}
