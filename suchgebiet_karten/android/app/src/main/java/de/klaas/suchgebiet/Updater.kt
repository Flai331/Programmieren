package de.klaas.suchgebiet

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

// Selbst-Update der App: version.json und APK kommen aus dem GitHub-Release (UPDATE_TAG),
// das das CI bei jedem Build aktualisiert. Android zeigt zum Schluss immer sein eigenes
// „Aktualisieren?“-Fenster; die Daten der App bleiben erhalten (gleicher Schlüssel, höherer versionCode).
// Rückmeldungen an die Web-App als JSON {state: 'available'|'progress'|'ready'|'error'|'none', code, name, pct, msg}.
object Updater {
    private const val BASE = "https://github.com/Flai331/Programmieren/releases/download/"
    private const val APK_NAME = "Suchgebiet-Karten.apk"
    private const val DIR = "update"

    @Volatile private var busy = false
    @Volatile private var latestCode = 0

    // Ohne UPDATE_TAG (z. B. lokaler Build) gibt es keinen Update-Check
    val enabled: Boolean get() = BuildConfig.UPDATE_TAG.isNotEmpty()

    fun versionJson(): String = JSONObject()
        .put("code", BuildConfig.VERSION_CODE)
        .put("name", BuildConfig.VERSION_NAME)
        .put("tag", BuildConfig.UPDATE_TAG)
        .put("enabled", enabled)
        .toString()

    private fun open(url: String): HttpURLConnection {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.instanceFollowRedirects = true
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000
        return conn
    }

    private fun state(state: String, code: Int = 0, name: String = "", pct: Int = 0, msg: String = ""): JSONObject =
        JSONObject().put("state", state).put("code", code).put("name", name).put("pct", pct).put("msg", msg)

    // Neue Version im Release? Fehler (kein Netz, kein Release) werden still übergangen.
    fun check(report: (JSONObject) -> Unit) {
        if (!enabled) return report(state("none"))
        Thread {
            try {
                val conn = open(BASE + BuildConfig.UPDATE_TAG + "/version.json")
                try {
                    if (conn.responseCode != 200) { report(state("none")); return@Thread }
                    val j = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
                    val code = j.optInt("code", 0)
                    if (code > BuildConfig.VERSION_CODE) {
                        latestCode = code
                        report(state("available", code, j.optString("name", "1.0.$code")))
                    } else {
                        report(state("none", code, j.optString("name")))
                    }
                } finally {
                    conn.disconnect()
                }
            } catch (e: Exception) {
                report(state("none"))
            }
        }.start()
    }

    private fun apkFile(context: Context): File = File(File(context.cacheDir, DIR).apply { mkdirs() }, APK_NAME)

    // APK laden, Fortschritt melden und prüfen: gleiches Paket, höherer versionCode als installiert
    fun download(context: Context, report: (JSONObject) -> Unit) {
        if (!enabled || busy) return
        busy = true
        val app = context.applicationContext
        Thread {
            val code = latestCode
            val part = File(apkFile(app).parentFile, "$APK_NAME.part")
            try {
                val conn = open(BASE + BuildConfig.UPDATE_TAG + "/" + APK_NAME)
                try {
                    conn.readTimeout = 30_000
                    if (conn.responseCode != 200) throw IllegalStateException("Download nicht möglich (HTTP ${conn.responseCode})")
                    val total = conn.contentLengthLong
                    var done = 0L
                    var lastPct = -1
                    report(state("progress", code, pct = 0))
                    conn.inputStream.use { input ->
                        part.outputStream().use { out ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                out.write(buf, 0, n)
                                done += n
                                if (total > 0) {
                                    val pct = (done * 100 / total).toInt()
                                    if (pct != lastPct) { lastPct = pct; report(state("progress", code, pct = pct)) }
                                }
                            }
                        }
                    }
                } finally {
                    conn.disconnect()
                }
                @Suppress("DEPRECATION")
                val info = app.packageManager.getPackageArchiveInfo(part.absolutePath, 0)
                    ?: throw IllegalStateException("Die geladene Datei ist keine gültige App")
                if (info.packageName != app.packageName) throw IllegalStateException("Die geladene App passt nicht zu Suchgebiet-Karten")
                if (PackageInfoCompat.getLongVersionCode(info) <= BuildConfig.VERSION_CODE.toLong()) {
                    throw IllegalStateException("Die geladene Version ist nicht neuer als die installierte")
                }
                val apk = apkFile(app)
                apk.delete()
                if (!part.renameTo(apk)) throw IllegalStateException("Datei konnte nicht gespeichert werden")
                report(state("ready", code, pct = 100))
            } catch (e: Exception) {
                part.delete()
                report(state("error", code, msg = e.message ?: "Download fehlgeschlagen"))
            } finally {
                busy = false
            }
        }.start()
    }

    // Darf die App andere Apps (bzw. sich selbst) installieren? Vor Android 8 gilt eine globale Einstellung.
    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    // Fehlt die Erlaubnis „Unbekannte Apps installieren“, öffnet sich die Einstellung für diese App.
    // Rückgabe: "settings" (Einstellung geöffnet), "installer" (Android-Installer gestartet), "error"
    fun install(activity: Activity): String {
        val file = apkFile(activity)
        if (!file.exists()) return "error"
        try {
            if (!canInstall(activity)) {
                val settings = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
                activity.startActivity(settings)
                return "settings"
            }
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            activity.startActivity(intent)
            return "installer"
        } catch (e: ActivityNotFoundException) {
            return "error"
        } catch (e: Exception) {
            return "error"
        }
    }
}
