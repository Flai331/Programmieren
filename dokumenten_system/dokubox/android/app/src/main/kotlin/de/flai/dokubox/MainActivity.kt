package de.flai.dokubox

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity wird von local_auth (Biometrie) benötigt.
//
// Nimmt zusätzlich PDFs aus dem „Teilen"-Menü an (Dateimanager, Mail, Drive …):
// Die Dateien werden in den Cache kopiert und über den Kanal "dokubox/share"
// an Flutter gegeben.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokubox/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedPdfs") {
                    result.success(pending.toList())
                    pending.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
        // Netzwerk-Scanner suchen (mDNS): Android verwirft Multicast ohne Lock.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokubox/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        if (multicastLock == null) {
                            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifi.createMulticastLock("dokubox-scanner").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(null)
                    }
                    "release" -> {
                        multicastLock?.takeIf { it.isHeld }?.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // E-Mail mit Empfänger, Betreff, Text und Anhängen (share_plus kann
        // keinen Empfänger setzen).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokubox/email")
            .setMethodCallHandler { call, result ->
                if (call.method != "send") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val to = call.argument<List<String>>("to") ?: emptyList()
                    val files = call.argument<List<String>>("files") ?: emptyList()
                    val uris = ArrayList(files.map {
                        androidx.core.content.FileProvider.getUriForFile(
                            this, "$packageName.dokubox.files", File(it))
                    })
                    val send = Intent(
                        if (uris.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND
                    ).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_EMAIL, to.toTypedArray())
                        putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject") ?: "")
                        putExtra(Intent.EXTRA_TEXT, call.argument<String>("body") ?: "")
                        if (uris.size > 1) putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                        else if (uris.size == 1) putExtra(Intent.EXTRA_STREAM, uris[0])
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, "E-Mail senden"))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("email", e.message, null)
                }
            }
        collect(intent)
    }

    override fun onDestroy() {
        multicastLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        collect(intent)
        if (pending.isNotEmpty()) channel?.invokeMethod("sharedPdfsAvailable", null)
    }

    private fun collect(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> streamExtra(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> uris.addAll(streamListExtra(intent))
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            else -> return
        }
        val dir = File(cacheDir, "shared_pdfs").apply { mkdirs() }
        for ((i, uri) in uris.withIndex()) {
            try {
                val target = File(dir, "shared_${System.currentTimeMillis()}_$i.pdf")
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                if (target.length() > 0) pending.add(target.absolutePath)
            } catch (_: Exception) {
                // Nicht lesbare Freigabe überspringen.
            }
        }
        // Nicht erneut verarbeiten, wenn die Activity neu erstellt wird.
        intent.action = Intent.ACTION_MAIN
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)) ?: emptyList()
}
