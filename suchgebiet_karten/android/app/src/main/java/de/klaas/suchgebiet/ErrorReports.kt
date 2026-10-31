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
// Die Web-App stellt den Bericht zusammen (ohne Einsatzdaten), hier wird er gesendet – nicht direkt an Notion,
// sondern an den Status-Server (Apps Script, POST { rep: { … } }). Der Notion-Token liegt nur dort (Skripteigenschaft),
// nie in der APK. Die Adresse steht im Bericht (Feld "url"); die zuletzt benutzte wird für Abstürze ohne Web-App gemerkt.
// Ohne Netz oder bei einem Fehler landet der Bericht in einer Warteschlange und geht beim nächsten Start raus.
object ErrorReports {
    private const val TAG = "SuchgebietReport"
    private const val PREFS = "error_reports"
    private const val QUEUE = "queue"
    private const val LAST_URL = "last_url"
    private const val URL_PREFIX = "https://script.google.com/"
    private const val MAX_QUEUE = 20

    // Nur Adressen des Apps-Script-Dienstes werden angenommen
    fun validUrl(url: String?): Boolean = url != null && url.startsWith(URL_PREFIX) && url.length <= 400 && !url.any { it.isWhitespace() }

    fun device(): String = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
    fun os(): String = "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})"

    // Bericht (JSON aus der Web-App) im Hintergrund senden, bei Fehler in die Warteschlange
    fun send(context: Context, report: JSONObject) {
        val app = context.applicationContext
        val url = report.optString("url")
        if (validUrl(url)) rememberUrl(app, url)
        Thread {
            if (post(app, report)) flushQueue(app) else enqueue(app, report)
        }.start()
    }

    // Warteschlange abarbeiten (beim Start der App)
    fun flush(context: Context) {
        val app = context.applicationContext
        Thread { flushQueue(app) }.start()
    }

    private fun flushQueue(app: Context) {
        val list = takeQueue(app)
        for (i in 0 until list.length()) {
            val r = list.optJSONObject(i) ?: continue
            if (!post(app, r)) enqueue(app, r)
        }
    }

    private fun rememberUrl(context: Context, url: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(LAST_URL, url).apply()
    }

    // Adresse des Berichts, sonst die zuletzt benutzte (Abstürze entstehen ohne Web-App); leer = keine bekannt
    private fun urlFor(context: Context, r: JSONObject): String {
        val own = r.optString("url")
        if (validUrl(own)) return own
        val last = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(LAST_URL, "") ?: ""
        return if (validUrl(last)) last else ""
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

    // Bericht an den Status-Server senden. true = erledigt (angenommen oder bewusst verworfen), false = später nochmal.
    // Apps Script antwortet auf den POST mit einer 302-Umleitung; die Antwort holt ein GET an die Adresse aus "Location"
    // (wie fetch(..., redirect: 'follow') in status.js). HttpURLConnection würde nur im Einzelfall selbst folgen, daher von Hand.
    private fun post(context: Context, r: JSONObject): Boolean {
        val url = urlFor(context, r)
        if (url.isEmpty()) return false // noch kein Status-Server bekannt: in der Warteschlange lassen
        return try {
            var conn = URL(url).openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 15000
            conn.readTimeout = 20000
            conn.instanceFollowRedirects = false
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "text/plain; charset=utf-8")
            conn.outputStream.use { it.write(payload(r).toString().toByteArray(Charsets.UTF_8)) }
            var code = conn.responseCode
            var hops = 0
            while (code in 301..303 || code == 307 || code == 308) {
                val next = conn.getHeaderField("Location")
                conn.disconnect()
                if (next == null || hops++ >= 5 || !next.startsWith("https://")) return false
                conn = URL(next).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 15000
                conn.readTimeout = 20000
                conn.instanceFollowRedirects = false
                code = conn.responseCode
            }
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)?.bufferedReader()?.use { it.readText() } ?: ""
            conn.disconnect()
            if (code !in 200..299) {
                Log.w(TAG, "Status-Server $code: ${text.take(300)}")
                return false
            }
            // { ok: true } (auch verworfen) = fertig; { ok: false, fehler } (kein Token, zu viele) = später nochmal
            val ok = try { JSONObject(text).optBoolean("ok", false) } catch (_: Exception) { false }
            if (!ok) Log.w(TAG, "Status-Server lehnt ab: ${text.take(300)}")
            ok
        } catch (e: Exception) {
            Log.w(TAG, "Senden fehlgeschlagen: ${e.message}")
            false
        }
    }

    // Body für den Status-Server: { rep: { …Bericht ohne url…, device, os, platform } } (wie reportPayload in report.js)
    private fun payload(r: JSONObject): JSONObject {
        val rep = JSONObject(r.toString())
        rep.remove("url")
        if (rep.optString("version").isEmpty()) rep.put("version", "App ${BuildConfig.VERSION_NAME}")
        rep.put("device", device())
        rep.put("os", os())
        rep.put("platform", "Android")
        return JSONObject().put("rep", rep)
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
