package de.klaas.filament

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Base64
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.webkit.WebViewAssetLoader
import org.json.JSONObject
import java.io.File

// Die App ist eine Hülle um die Web-App (assets = filament_manager/web).
// Sie ergänzt, was der Browser sonst selbst kann: Dateiauswahl, Kamera, Speichern, Teilen, Selbst-Update.
class MainActivity : ComponentActivity() {

    private lateinit var webView: WebView
    private val host = "appassets.androidplatform.net"
    private val startUrl = "https://$host/assets/index.html"

    private var fileCallback: ValueCallback<Array<Uri>>? = null

    // Per „Teilen“ / „Öffnen mit“ empfangene Druckdatei; die Web-App holt sie mit AndroidBridge.takeSharedFile() ab.
    @Volatile private var sharedFile: String? = null

    private fun deliver(uris: Array<Uri>?) {
        fileCallback?.onReceiveValue(uris)
        fileCallback = null
    }

    private val pickOne = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        deliver(if (uri != null) arrayOf(uri) else null)
    }
    private val pickMany = registerForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        deliver(if (uris.isNotEmpty()) uris.toTypedArray() else null)
    }

    // Foto für einen Auftrag: Kamera-App nimmt in eine Datei im Cache auf
    private var photoUri: Uri? = null
    private val takePhoto = registerForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val uri = photoUri
        deliver(if (ok && uri != null) arrayOf(uri) else null)
    }
    private val photoPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) launchCamera() else {
            toast("Ohne Kamera-Freigabe kein Foto")
            deliver(null)
        }
    }

    private fun launchCamera() {
        try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val file = File(dir, "foto-${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
            photoUri = uri
            takePhoto.launch(uri)
        } catch (e: Exception) {
            toast("Keine Kamera-App gefunden")
            deliver(null)
        }
    }

    // „Sicherung speichern“ und Datei-Anhänge: Android fragt nach Ordner und Dateiname
    private class CreateDoc : ActivityResultContracts.CreateDocument("*/*") {
        var mime = "*/*"
        override fun createIntent(context: android.content.Context, input: String): Intent =
            super.createIntent(context, input).setType(mime)
    }
    private val createDoc = CreateDoc()
    private var pendingSave: ByteArray? = null
    private val saveDoc = registerForActivityResult(createDoc) { uri ->
        val bytes = pendingSave
        pendingSave = null
        if (uri == null || bytes == null) return@registerForActivityResult
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            toast("Gespeichert")
        } catch (e: Exception) {
            Log.e("Filament", "Speichern fehlgeschlagen", e)
            toast("Speichern fehlgeschlagen: ${e.message}")
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val assetLoader = WebViewAssetLoader.Builder()
            .setDomain(host)
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView = WebView(this)
        setContentView(webView)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = false
            allowContentAccess = false
        }
        webView.addJavascriptInterface(Bridge(), "AndroidBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                assetLoader.shouldInterceptRequest(request.url)

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.host == host) return false
                // Modell-Links (MakerWorld, Printables …), mailto:, tel: in anderen Apps öffnen
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, request.url))
                } catch (e: ActivityNotFoundException) {
                    toast("Keine App zum Öffnen gefunden")
                }
                return true
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                view: WebView,
                callback: ValueCallback<Array<Uri>>,
                params: FileChooserParams
            ): Boolean {
                fileCallback?.onReceiveValue(null)
                fileCallback = callback
                val image = params.acceptTypes.any { it.startsWith("image/") }
                if (image && params.isCaptureEnabled) {
                    if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) launchCamera()
                    else photoPermission.launch(Manifest.permission.CAMERA)
                    return true
                }
                // .3mf/.gcode haben auf Android keinen festen Dateityp → alle Dateien anbieten, die Web-App prüft selbst
                val types = if (image) arrayOf("image/*") else arrayOf("*/*")
                return try {
                    if (params.mode == FileChooserParams.MODE_OPEN_MULTIPLE) pickMany.launch(types) else pickOne.launch(types)
                    true
                } catch (e: ActivityNotFoundException) {
                    fileCallback = null
                    false
                }
            }

            override fun onConsoleMessage(msg: ConsoleMessage): Boolean {
                Log.println(
                    if (msg.messageLevel() == ConsoleMessage.MessageLevel.ERROR) Log.ERROR else Log.INFO,
                    "FilamentJS",
                    "${msg.message()} (${msg.sourceId()}:${msg.lineNumber()})"
                )
                return true
            }
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Offenes Fenster schließen statt die App zu beenden
                webView.evaluateJavascript(
                    "(function(){var d=document.getElementById('modal');if(d&&d.open){d.close();return true}return false})()"
                ) { closed ->
                    if (closed != "true") {
                        isEnabled = false
                        onBackPressedDispatcher.onBackPressed()
                        isEnabled = true
                    }
                }
            }
        })

        receiveFile(intent)
        if (savedInstanceState != null) webView.restoreState(savedInstanceState) else webView.loadUrl(startUrl)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (receiveFile(intent)) webView.evaluateJavascript("window.onSharedFile&&window.onSharedFile()", null)
    }

    // Datei aus ACTION_SEND (Teilen) bzw. ACTION_VIEW (Öffnen mit) lesen – nur content:-Adressen
    private fun receiveFile(i: Intent?): Boolean {
        if (i == null) return false
        val uri: Uri = when (i.action) {
            Intent.ACTION_SEND -> (if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_STREAM)) ?: return false
            Intent.ACTION_VIEW -> i.data ?: return false
            else -> return false
        }
        if (uri.scheme != "content") return false
        try {
            var name = uri.lastPathSegment?.substringAfterLast('/') ?: "Datei"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0)
            }
            val bytes = contentResolver.openInputStream(uri)?.use { inp ->
                val out = java.io.ByteArrayOutputStream()
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = inp.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                    if (out.size() > 60 * 1024 * 1024) throw IllegalStateException("Datei zu groß (über 60 MB)")
                }
                out.toByteArray()
            } ?: return false
            sharedFile = JSONObject()
                .put("name", name)
                .put("data", Base64.encodeToString(bytes, Base64.NO_WRAP))
                .toString()
            i.action = Intent.ACTION_MAIN // nach Drehen/Neustart nicht erneut importieren
            return true
        } catch (e: Exception) {
            toast("Datei konnte nicht gelesen werden: ${e.message}")
            return false
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    private fun toast(text: String) = runOnUiThread {
        Toast.makeText(this, text, Toast.LENGTH_LONG).show()
    }

    private fun sendUpdate(state: JSONObject) = runOnUiThread {
        webView.evaluateJavascript("window.fmUpdate&&window.fmUpdate(" + state.toString() + ")", null)
    }

    inner class Bridge {
        // Empfangene Datei als JSON {name, data(Base64)} – einmalig, danach leer
        @JavascriptInterface
        fun takeSharedFile(): String {
            val f = sharedFile ?: return ""
            sharedFile = null
            return f
        }

        // Datei speichern (Sicherung, Anhang): Android fragt nach dem Speicherort
        @JavascriptInterface
        fun saveFile(name: String, mime: String, b64: String) {
            val bytes = try { Base64.decode(b64, Base64.DEFAULT) } catch (e: Exception) { toast("Speichern fehlgeschlagen"); return }
            runOnUiThread {
                pendingSave = bytes
                createDoc.mime = mime.ifEmpty { "application/octet-stream" }
                saveDoc.launch(name)
            }
        }

        // ---------- Selbst-Update (siehe Updater); Antworten kommen über window.fmUpdate({state, …}) ----------

        @JavascriptInterface
        fun appVersion(): String = Updater.versionJson()

        @JavascriptInterface
        fun updateCheck() = Updater.check { sendUpdate(it) }

        @JavascriptInterface
        fun updateDownload() = Updater.download(this@MainActivity) { sendUpdate(it) }

        @JavascriptInterface
        fun updateCanInstall(): Boolean = Updater.canInstall(this@MainActivity)

        // Rückgabe: "installer" | "settings" | "error"
        @JavascriptInterface
        fun updateInstall(): String {
            var result = "error"
            val latch = java.util.concurrent.CountDownLatch(1)
            runOnUiThread {
                result = Updater.install(this@MainActivity)
                latch.countDown()
            }
            latch.await(5, java.util.concurrent.TimeUnit.SECONDS)
            return result
        }
    }
}
