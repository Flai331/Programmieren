package de.flai.dokubox

import android.content.Intent
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
        collect(intent)
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
