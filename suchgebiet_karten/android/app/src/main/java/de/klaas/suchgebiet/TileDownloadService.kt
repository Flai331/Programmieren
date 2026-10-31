package de.klaas.suchgebiet

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.min

// Lädt einen Offline-Bereich im Hintergrund – auch bei ausgeschaltetem Bildschirm und wenn
// die App nicht im Vordergrund ist. Bereits gespeicherte Bilder werden übersprungen, ein
// angehaltener Download läuft also einfach weiter. Fortschritt in der Benachrichtigung.
class TileDownloadService : Service() {
    companion object {
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val ACTION_CANCEL = "cancel"
        const val EXTRA_JOB = "job"
        private const val CHANNEL = "offline"
        private const val NOTIF_ID = 7
        private const val THREADS = 4

        fun start(context: Context, job: String) {
            val i = Intent(context, TileDownloadService::class.java).setAction(ACTION_START).putExtra(EXTRA_JOB, job)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        }

        fun stop(context: Context) {
            context.startService(Intent(context, TileDownloadService::class.java).setAction(ACTION_STOP))
        }
    }

    private val stopFlag = AtomicBoolean(false)
    private val cancelFlag = AtomicBoolean(false)
    private var worker: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        OfflineTiles.init(this)
        if (intent?.action == ACTION_STOP || intent?.action == ACTION_CANCEL) {
            if (intent?.action == ACTION_CANCEL) cancelFlag.set(true)
            stopFlag.set(true)
            if (worker == null) stopSelf()
            return START_NOT_STICKY
        }
        val jobJson = intent?.getStringExtra(EXTRA_JOB)
        startForegroundNow(notification("Offline-Karte wird vorbereitet …", 0, 0))
        if (jobJson == null || worker != null) return START_NOT_STICKY
        stopFlag.set(false)
        cancelFlag.set(false)
        worker = Thread { run(JSONObject(jobJson)) }.also { it.start() }
        return START_NOT_STICKY
    }

    private fun startForegroundNow(n: Notification) {
        ServiceCompat.startForeground(
            this, NOTIF_ID, n,
            if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0
        )
    }

    private fun notification(text: String, done: Long, total: Long): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Offline-Karten", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, TileDownloadService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val pct = if (total > 0) (100 * done / total).toInt() else 0
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Offline-Karte")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, pct, total == 0L)
            .setContentIntent(open)
            .addAction(0, "Anhalten", stop)
            .addAction(0, "Abbrechen", PendingIntent.getService(
                this, 2, Intent(this, TileDownloadService::class.java).setAction(ACTION_CANCEL),
                PendingIntent.FLAG_IMMUTABLE
            ))
            .build()
    }

    private fun online(wifiOnly: Boolean): String? {
        val cm = getSystemService(ConnectivityManager::class.java)
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        if (caps == null || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return "Netz"
        if (wifiOnly && cm.isActiveNetworkMetered) return "WLAN"
        return null
    }

    @Suppress("DEPRECATION")
    private fun run(job: JSONObject) {
        val id = job.getString("id")
        val name = job.optString("name", "Offline-Karte")
        val wifiOnly = job.optBoolean("wifiOnly", false)
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Suchgebiet:offline").apply { acquire(24 * 3600_000L) }
        wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
            .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "Suchgebiet:offline").apply { acquire() }
        OfflineTiles.runningId = id
        OfflineTiles.lastError = ""
        val nm = getSystemService(NotificationManager::class.java)
        val done = AtomicLong(0)
        val failed = AtomicLong(0)
        val prev = OfflineTiles.getStatus(id)
        val bytes = AtomicLong(prev?.optLong("bytes", 0L) ?: 0L)
        var total = 0L
        fun publish(finished: Boolean) {
            OfflineTiles.setStatus(id, JSONObject()
                .put("done", done.get()).put("total", total).put("failed", failed.get())
                .put("bytes", bytes.get()).put("finished", finished)
                .put("cancelled", cancelFlag.get())) // in der Benachrichtigung abgebrochen: App löscht den Bereich
        }
        try {
            val arr = job.getJSONArray("layers")
            val layers = (0 until arr.length()).map { OfflineTiles.Layer(arr.getJSONObject(it)) }
            layers.forEach { l -> l.check()?.let { throw IllegalStateException(it) } }
            total = OfflineTiles.total(job, layers)
            publish(false)

            // alle Kacheln der Reihe nach – Stufe für Stufe, damit grobe Übersichten zuerst da sind
            val areas = OfflineTiles.areas(job)
            val queue = sequence {
                for (z in job.getInt("zMin")..job.getInt("zMax")) for (l in layers) for (b in areas) {
                    if (z > l.maxZoom) continue
                    val r = OfflineTiles.range(l, b, z) ?: continue
                    for (y in r.y0..r.y1) for (x in r.x0..r.x1) yield(l.url(r.zu, x, y))
                }
            }.iterator()
            val next = { synchronized(queue) { if (queue.hasNext()) queue.next() else null } }

            var lastNote = 0L
            var lastSave = System.currentTimeMillis()
            val threads = (1..THREADS).map {
                Thread {
                    while (!stopFlag.get()) {
                        val url = next() ?: break
                        val f = OfflineTiles.fileFor(url)
                        if (!f.exists()) {
                            val n = fetch(url, f, wifiOnly)
                            if (n < 0 && stopFlag.get()) break // abgebrochen: weder fertig noch Fehler
                            if (n < 0) failed.incrementAndGet() else bytes.addAndGet(n)
                        }
                        done.incrementAndGet()
                    }
                }.also { it.start() }
            }
            while (threads.any { it.isAlive }) {
                Thread.sleep(700)
                publish(false)
                val now = System.currentTimeMillis()
                if (now - lastNote > 1500) {
                    lastNote = now
                    val wait = OfflineTiles.waitingFor
                    val text = if (wait.isNotEmpty()) "$name – wartet auf $wait"
                    else "$name – ${done.get()} von $total · ${bytes.get() / 1048576} MB"
                    nm.notify(NOTIF_ID, notification(text, done.get(), total))
                }
                if (now - lastSave > 30_000) { lastSave = now; OfflineTiles.saveStatus() }
            }
            val finished = !stopFlag.get() && done.get() >= total
            publish(finished)
        } catch (e: Exception) {
            OfflineTiles.lastError = e.message ?: e.toString()
            publish(false)
        } finally {
            OfflineTiles.saveStatus()
            OfflineTiles.runningId = null
            OfflineTiles.waitingFor = ""
            wakeLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
            worker = null
            val s = OfflineTiles.getStatus(id)
            val msg = when {
                cancelFlag.get() -> "$name abgebrochen – wird beim nächsten Öffnen der App gelöscht"
                OfflineTiles.lastError.isNotEmpty() -> "$name: Fehler – ${OfflineTiles.lastError}"
                s?.optBoolean("finished") == true -> "$name ist fertig (${s.optLong("bytes") / 1048576} MB)"
                else -> "$name angehalten – in der App mit ▶ weiterladen"
            }
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            nm.notify(NOTIF_ID + 1, NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("Offline-Karte")
                .setContentText(msg)
                .setAutoCancel(true)
                .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE))
                .build())
            stopSelf()
        }
    }

    // Ein Bild laden und speichern: Bytes, oder -1 nach 3 Fehlversuchen.
    // Ohne Netz (oder ohne WLAN bei „nur WLAN“) wird gewartet statt gezählt.
    private fun fetch(url: String, f: File, wifiOnly: Boolean): Long {
        var attempt = 0
        while (attempt < 3 && !stopFlag.get()) {
            val wait = online(wifiOnly)
            if (wait != null) {
                OfflineTiles.waitingFor = wait
                Thread.sleep(3000)
                continue
            }
            OfflineTiles.waitingFor = ""
            try {
                val c = URL(url).openConnection() as HttpURLConnection
                c.connectTimeout = 15000
                c.readTimeout = 30000
                c.setRequestProperty("User-Agent", "Suchgebiet-Karten (Android)")
                try {
                    val type = c.contentType ?: ""
                    if (c.responseCode == 200 && type.startsWith("image/")) {
                        val data = c.inputStream.use { it.readBytes() }
                        f.parentFile?.mkdirs()
                        val tmp = File(f.parentFile, f.name + ".part")
                        tmp.writeBytes(data)
                        if (!tmp.renameTo(f)) { tmp.delete(); return -1 }
                        OfflineTiles.addBytes(data.size.toLong())
                        return data.size.toLong()
                    }
                    // 4xx (z. B. 404 außerhalb der Abdeckung): ein neuer Versuch bringt nichts
                    if (c.responseCode in 400..499) return -1
                } finally {
                    c.disconnect()
                }
            } catch (_: Exception) { }
            attempt++
            Thread.sleep(800L * min(attempt, 3))
        }
        return -1
    }

    override fun onDestroy() {
        stopFlag.set(true)
        super.onDestroy()
    }
}
