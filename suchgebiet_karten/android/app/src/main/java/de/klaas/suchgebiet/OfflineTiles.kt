package de.klaas.suchgebiet

import android.content.Context
import android.os.Environment
import android.webkit.WebResourceResponse
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.Locale
import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

// Offline-Karten der Android-App: Kartenbilder als Dateien (Name = SHA-1 der Adresse).
// Speicherort: der App-Ordner mit dem meisten freien Platz (SD-Karte, falls vorhanden),
// beim ersten Download festgelegt. Beim Anzeigen liefert die WebView-Abfangfunktion
// gespeicherte Bilder sofort aus, nur Fehlendes kommt aus dem Internet.
object OfflineTiles {
    val TILE_HOSTS = listOf("geodatenzentrum.de", "lgln.niedersachsen.de", "wms.nrw.de")
    private const val PREFS = "offline"
    private const val HALF = 20037508.342789244

    private lateinit var app: Context
    @Volatile private var rootDir: File? = null

    // Fortschritt je Bereich (id -> JSON), in einer Datei gesichert
    private val status = HashMap<String, JSONObject>()
    @Volatile var runningId: String? = null
    @Volatile var waitingFor: String = "" // z. B. „WLAN“, „Netz“
    @Volatile var deleting = false
    @Volatile var lastError: String = ""

    fun init(context: Context) {
        if (::app.isInitialized) return
        app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString("root", null)?.let { rootDir = File(it) }
        usedBytes.set(prefs.getLong("bytes", 0))
        try {
            val f = File(app.filesDir, "offline-status.json")
            if (f.exists()) {
                val o = JSONObject(f.readText())
                for (k in o.keys()) status[k] = o.getJSONObject(k)
            }
        } catch (_: Exception) { }
    }

    // Ordner wählen: einmalig der mit dem meisten Platz (interner Speicher oder SD-Karte)
    fun root(): File {
        rootDir?.let { return it }
        val dirs = app.getExternalFilesDirs("tiles").filterNotNull()
            .filter { Environment.getExternalStorageState(it) == Environment.MEDIA_MOUNTED }
        val best = (dirs + File(app.filesDir, "tiles")).maxByOrNull { it.apply { mkdirs() }.usableSpace }!!
        best.mkdirs()
        rootDir = best
        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("root", best.absolutePath).apply()
        return best
    }

    fun onSdCard(): Boolean {
        val r = rootDir ?: return false
        return try { Environment.isExternalStorageRemovable(r) } catch (_: Exception) { false }
    }

    // Die WebView schreibt Adressen manchmal mit %2C/%3A/%2F – vorher vereinheitlichen
    fun canonical(url: String): String =
        url.replace("%2C", ",").replace("%2c", ",").replace("%3A", ":").replace("%3a", ":")
            .replace("%2F", "/").replace("%2f", "/")

    fun fileFor(url: String): File {
        val md = MessageDigest.getInstance("SHA-1").digest(canonical(url).toByteArray())
        val hex = md.joinToString("") { "%02x".format(it) }
        return File(File(root(), hex.substring(0, 2)), hex.substring(2))
    }

    fun isTileHost(host: String?) = host != null && TILE_HOSTS.any { host.endsWith(it) }

    // Für shouldInterceptRequest: gespeichertes Bild oder null (dann aus dem Netz)
    fun serve(url: String): WebResourceResponse? {
        if (rootDir == null) return null // noch nie etwas geladen
        val f = fileFor(url)
        if (!f.exists()) return null
        return try {
            val input = FileInputStream(f).buffered()
            // JPEG beginnt mit FF D8, sonst PNG
            input.mark(2)
            val jpeg = input.read() == 0xFF
            input.reset()
            WebResourceResponse(if (jpeg) "image/jpeg" else "image/png", null, 200, "OK", mapOf(
                "Access-Control-Allow-Origin" to "*",
                "Cache-Control" to "max-age=86400",
            ), input)
        } catch (_: Exception) { null }
    }

    // ---------- Kachelnummern und Adressen (wie offline.js / layers.js) ----------
    class Layer(o: JSONObject) {
        val zoomOffset = o.optInt("zoomOffset", 0)
        val maxZoom = o.optInt("maxZoom", 18)
        val template: String? = o.optString("template").ifEmpty { null }
        val subdomains = o.optString("subdomains")
        val wmsPrefix: String? = o.optString("wmsPrefix").ifEmpty { null }
        val samples: JSONArray = o.optJSONArray("samples") ?: JSONArray()

        fun url(z: Int, x: Int, y: Int): String {
            val n = 2.0.pow(z)
            val wx = (((x % n.toLong()) + n.toLong()) % n.toLong()).toInt()
            wmsPrefix?.let {
                val size = 2 * HALF / n
                val minx = -HALF + wx * size
                val maxy = HALF - y * size
                return it + listOf(minx, maxy - size, minx + size, maxy)
                    .joinToString(",") { v -> String.format(Locale.US, "%.2f", v) }
            }
            val sub = if (subdomains.isNotEmpty()) subdomains[Math.abs(wx + y) % subdomains.length].toString() else ""
            return template!!.replace("{s}", sub).replace("{z}", z.toString())
                .replace("{x}", wx.toString()).replace("{y}", y.toString())
        }

        // Stimmen die Adressen mit denen der Web-App überein? Sonst würde nichts gefunden.
        fun check(): String? {
            for (i in 0 until samples.length()) {
                val s = samples.getJSONObject(i)
                val mine = url(s.getInt("z"), s.getInt("x"), s.getInt("y"))
                if (mine != s.getString("url")) return "Adressen weichen ab: $mine ≠ ${s.getString("url")}"
            }
            return null
        }
    }

    class Range(val zu: Int, val x0: Int, val x1: Int, val y0: Int, val y1: Int) {
        val count get() = (x1 - x0 + 1).toLong() * (y1 - y0 + 1)
        fun contains(x: Int, y: Int) = x in x0..x1 && y in y0..y1
    }

    private fun mercX(lon: Double) = (lon + 180) / 360 * 256
    private fun mercY(lat: Double): Double {
        val s = sin(max(-85.0511, min(85.0511, lat)) * PI / 180)
        return (0.5 - ln((1 + s) / (1 - s)) / (4 * PI)) * 256
    }

    fun range(layer: Layer, b: JSONObject, z: Int): Range? {
        val zu = z - layer.zoomOffset
        if (zu < 0) return null
        val n = 2.0.pow(zu)
        val nn = n.toInt()
        fun clamp(v: Int) = max(0, min(nn - 1, v))
        fun px(lon: Double) = clamp(floor(mercX(lon) / 256 * n).toInt())
        fun py(lat: Double) = clamp(floor(mercY(lat) / 256 * n).toInt())
        return Range(zu, px(b.getDouble("west")), px(b.getDouble("east")), py(b.getDouble("north")), py(b.getDouble("south")))
    }

    // Ein Bereich: ein Rechteck („bounds“) oder mehrere Quadrate („areas“)
    fun areas(o: JSONObject): List<JSONObject> {
        val a = o.optJSONArray("areas")
        if (a == null || a.length() == 0) return listOf(o.getJSONObject("bounds"))
        return (0 until a.length()).map { a.getJSONObject(it) }
    }

    fun total(job: JSONObject, layers: List<Layer>): Long {
        var t = 0L
        val list = areas(job)
        for (l in layers) for (z in job.getInt("zMin")..min(job.getInt("zMax"), l.maxZoom)) {
            for (b in list) range(l, b, z)?.let { t += it.count }
        }
        return t
    }

    // ---------- Fortschritt ----------
    @Synchronized fun setStatus(id: String, o: JSONObject) {
        status[id] = o
    }

    @Synchronized fun getStatus(id: String): JSONObject? = status[id]

    @Synchronized fun saveStatus() {
        try {
            val o = JSONObject()
            for ((k, v) in status) o.put(k, v)
            File(app.filesDir, "offline-status.json").writeText(o.toString())
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong("bytes", usedBytes.get()).apply()
        } catch (_: Exception) { }
    }

    @Synchronized fun statusJson(): String {
        val o = JSONObject()
        val regions = JSONObject()
        for ((k, v) in status) regions.put(k, v)
        o.put("regions", regions)
        o.put("running", runningId ?: JSONObject.NULL)
        o.put("waiting", waitingFor)
        o.put("deleting", deleting)
        o.put("error", lastError)
        return o.toString()
    }

    // belegter Platz aller Offline-Bilder (laufend mitgezählt, Ordner durchzählen wäre zu langsam)
    private val usedBytes = java.util.concurrent.atomic.AtomicLong(0)

    fun addBytes(n: Long) {
        usedBytes.updateAndGet { max(0, it + n) }
    }

    fun storageJson(): String {
        val r = rootDir
        val o = JSONObject()
        o.put("usedMB", usedBytes.get() / 1048576.0)
        val dir = r ?: run {
            val dirs = app.getExternalFilesDirs("tiles").filterNotNull()
            (dirs + app.filesDir).maxByOrNull { it.apply { mkdirs() }.usableSpace } ?: app.filesDir
        }
        o.put("freeMB", dir.usableSpace / 1048576.0)
        o.put("place", if (r == null) "" else if (onSdCard()) "SD-Karte" else "Gerätespeicher")
        return o.toString()
    }

    // Bereich löschen – außer Bildern, die ein anderer gespeicherter Bereich auch nutzt
    fun delete(json: String) {
        if (deleting) return
        deleting = true
        Thread {
            try {
                val o = JSONObject(json)
                val job = o.getJSONObject("region")
                val layers = (0 until job.getJSONArray("layers").length()).map { Layer(job.getJSONArray("layers").getJSONObject(it)) }
                val others = o.optJSONArray("others") ?: JSONArray()
                var freed = 0L
                for ((li, l) in layers.withIndex()) {
                    val ids = job.getJSONArray("layerIds")
                    for (z in job.getInt("zMin")..min(job.getInt("zMax"), l.maxZoom)) for (b in areas(job)) {
                        val r = range(l, b, z) ?: continue
                        // Bereiche anderer Downloads mit derselben Karte in dieser Stufe
                        val keep = ArrayList<Range>()
                        for (i in 0 until others.length()) {
                            val other = others.getJSONObject(i)
                            val oIds = other.getJSONArray("layerIds")
                            if ((0 until oIds.length()).none { oIds.getString(it) == ids.getString(li) }) continue
                            if (z < other.getInt("zMin") || z > other.getInt("zMax")) continue
                            for (ob in areas(other)) range(l, ob, z)?.let { keep.add(it) }
                        }
                        for (y in r.y0..r.y1) for (x in r.x0..r.x1) {
                            if (keep.any { it.contains(x, y) }) continue
                            val f = fileFor(l.url(r.zu, x, y))
                            val len = f.length()
                            if (f.delete()) freed += len
                        }
                    }
                }
                addBytes(-freed)
                synchronized(this) { status.remove(job.getString("id")) }
                saveStatus()
            } catch (e: Exception) {
                lastError = "Löschen: ${e.message}"
            } finally {
                deleting = false
            }
        }.start()
    }
}
