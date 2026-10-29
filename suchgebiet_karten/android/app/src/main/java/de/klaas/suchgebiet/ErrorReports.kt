package de.klaas.suchgebiet

import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Fehlerberichte an die Notion-Fehlerzentrale (🐞 Fehlerzentrale → 🐛 Suchgebiet-Karten).
// Die Web-App stellt den Bericht zusammen (ohne Einsatzdaten), hier wird er gesendet.
// Ohne Netz oder bei einem Fehler landet er in einer Warteschlange und geht beim nächsten Start raus.
object ErrorReports {
    private const val TAG = "SuchgebietReport"
    private const val DB_ID = "5574dcecd7e84a0aa79446bab3915a47"
    private const val PREFS = "error_reports"
    private const val QUEUE = "queue"
    private const val MAX_QUEUE = 20

    val hasToken: Boolean get() = BuildConfig.NOTION_TOKEN.isNotEmpty()

    fun device(): String = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
    fun os(): String = "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})"

    // Bericht (JSON aus der Web-App) im Hintergrund senden, bei Fehler in die Warteschlange
    fun send(context: Context, report: JSONObject) {
        val app = context.applicationContext
        Thread {
            if (!post(report)) enqueue(app, report)
        }.start()
    }

    // Warteschlange abarbeiten (beim Start der App)
    fun flush(context: Context) {
        if (!hasToken) return
        val app = context.applicationContext
        Thread {
            val list = takeQueue(app)
            for (i in 0 until list.length()) {
                val r = list.optJSONObject(i) ?: continue
                if (!post(r)) enqueue(app, r)
            }
        }.start()
    }

    // Absturz der App selbst (nicht der Web-App): synchron vormerken, gesendet wird beim nächsten Start
    private var crashHandlerInstalled = false
    fun installCrashHandler(context: Context) {
        if (crashHandlerInstalled) return // onCreate läuft z. B. nach dem Drehen erneut
        crashHandlerInstalled = true
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            try {
                val stack = Log.getStackTraceString(e)
                enqueue(app, JSONObject()
                    .put("title", "Absturz: ${e.javaClass.simpleName}: ${e.message ?: ""}".take(120))
                    .put("kind", "Absturz")
                    .put("error", "${e.javaClass.name}: ${e.message ?: ""}")
                    .put("stack", stack)
                    .put("fingerprint", "native-" + (e.javaClass.name + (e.stackTrace.firstOrNull()?.toString() ?: "")).hashCode().toString(16))
                    .put("time", now()), sync = true)
            } catch (_: Throwable) { /* nie den Absturz verdecken */ }
            previous?.uncaughtException(thread, e)
        }
    }

    private fun post(r: JSONObject): Boolean {
        if (!hasToken) return false
        return try {
            val conn = URL("https://api.notion.com/v1/pages").openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 15000
            conn.readTimeout = 20000
            conn.doOutput = true
            conn.setRequestProperty("Authorization", "Bearer ${BuildConfig.NOTION_TOKEN}")
            conn.setRequestProperty("Notion-Version", "2022-06-28")
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.outputStream.use { it.write(body(r).toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.w(TAG, "Notion $code: ${err.take(300)}")
            }
            conn.disconnect()
            // 4xx außer 429: Bericht ist kaputt bzw. Token falsch – nicht endlos wiederholen
            code in 200..299 || (code in 400..499 && code != 429)
        } catch (e: Exception) {
            Log.w(TAG, "Senden fehlgeschlagen: ${e.message}")
            false
        }
    }

    // Notion-Seite in der Datenbank 🐛 Suchgebiet-Karten
    private fun body(r: JSONObject): JSONObject {
        fun text(s: String) = JSONObject().put("rich_text", JSONArray().put(
            JSONObject().put("text", JSONObject().put("content", s.take(2000)))
        ))
        fun select(s: String) = JSONObject().put("select", JSONObject().put("name", s))
        val props = JSONObject()
            .put("Titel", JSONObject().put("title", JSONArray().put(
                JSONObject().put("text", JSONObject().put("content", r.optString("title", "Fehlerbericht").take(200)))
            )))
            .put("Status", select("Offen"))
            .put("Art", select(r.optString("kind", "Auto-Fehler")))
            .put("Plattform", select("Android"))
            .put("Beschreibung", text(r.optString("desc")))
            .put("Fehler", text(listOf(r.optString("error"), r.optString("stack")).filter { it.isNotEmpty() }.joinToString("\n")))
            .put("Protokoll", text(r.optString("log")))
            .put("Seite", text(r.optString("page")))
            .put("Benutzerrolle", text(r.optString("role")))
            .put("Gerät", text(device()))
            .put("OS", text(os()))
            .put("Version", text(r.optString("version", "App ${BuildConfig.VERSION_NAME}")))
            .put("Fingerprint", text(r.optString("fingerprint")))
            .put("Zeitstempel", JSONObject().put("date", JSONObject().put("start", r.optString("time", now()))))
        return JSONObject()
            .put("parent", JSONObject().put("database_id", DB_ID))
            .put("properties", props)
    }

    private fun enqueue(context: Context, r: JSONObject, sync: Boolean = false) {
        synchronized(this) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val list = try { JSONArray(prefs.getString(QUEUE, "[]")) } catch (_: Exception) { JSONArray() }
            list.put(r)
            while (list.length() > MAX_QUEUE) list.remove(0)
            val ed = prefs.edit().putString(QUEUE, list.toString())
            if (sync) ed.commit() else ed.apply()
        }
    }

    private fun takeQueue(context: Context): JSONArray = synchronized(this) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val list = try { JSONArray(prefs.getString(QUEUE, "[]")) } catch (_: Exception) { JSONArray() }
        prefs.edit().remove(QUEUE).commit()
        list
    }

    private fun now(): String {
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        f.timeZone = TimeZone.getTimeZone("UTC")
        return f.format(Date())
    }
}
