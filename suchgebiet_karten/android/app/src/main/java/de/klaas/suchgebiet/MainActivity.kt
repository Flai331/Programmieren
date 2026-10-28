package de.klaas.suchgebiet

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.util.Base64
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
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
import org.json.JSONArray
import java.io.File

// Die App ist eine Hülle um die Web-App (assets = suchgebiet_karten/web).
// Sie ergänzt, was der Browser sonst selbst kann: Standort, Dateiauswahl und Teilen.
class MainActivity : ComponentActivity() {

    private lateinit var webView: WebView
    private val host = "appassets.androidplatform.net"
    private val startUrl = "https://$host/assets/index.html"

    private var pendingGeo: Pair<String, GeolocationPermissions.Callback>? = null
    private var fileCallback: ValueCallback<Array<Uri>>? = null

    private val locationPermission = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val granted = result.values.any { it }
        pendingGeo?.let { (origin, cb) -> cb.invoke(origin, granted, false) }
        pendingGeo = null
        if (!granted) toast("Ohne Standortfreigabe kein GPS")
    }

    private val pickFile = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        fileCallback?.onReceiveValue(if (uri != null) arrayOf(uri) else null)
        fileCallback = null
    }

    // „Speichern“: Android fragt nach Ordner und Dateiname, dann wird die Datei geschrieben
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
            Log.e("Suchgebiet", "Speichern fehlgeschlagen", e)
            toast("Speichern fehlgeschlagen: ${e.message}")
        }
    }

    // „Alles speichern“: einmal einen Ordner wählen, alle Dateien landen dort
    private var pendingFiles: List<Triple<String, String, ByteArray>>? = null
    private val pickDir = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { tree ->
        val files = pendingFiles
        pendingFiles = null
        if (tree == null || files == null) return@registerForActivityResult
        try {
            val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            for ((name, _, bytes) in files) {
                // octet-stream: Dateiname (mit .gpx) bleibt unverändert
                val doc = DocumentsContract.createDocument(contentResolver, parent, "application/octet-stream", name) ?: continue
                contentResolver.openOutputStream(doc)?.use { it.write(bytes) }
            }
            toast("${files.size} Dateien gespeichert")
        } catch (e: Exception) {
            Log.e("Suchgebiet", "Speichern fehlgeschlagen", e)
            toast("Speichern fehlgeschlagen: ${e.message}")
        }
    }

    private fun parseFiles(json: String): List<Triple<String, String, ByteArray>> {
        val arr = JSONArray(json)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            Triple(o.getString("name"), o.optString("mime"), Base64.decode(o.getString("b64"), Base64.DEFAULT))
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
            setGeolocationEnabled(true)
            allowFileAccess = false
            allowContentAccess = false
        }
        webView.addJavascriptInterface(Bridge(), "AndroidBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                assetLoader.shouldInterceptRequest(request.url)

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.host == host) return false
                // mailto:, Links zu Lizenzen usw. in anderen Apps öffnen
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, request.url))
                } catch (e: ActivityNotFoundException) {
                    toast("Keine App zum Öffnen gefunden")
                }
                return true
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) {
                val fine = ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION)
                if (fine == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, false)
                } else {
                    pendingGeo = origin to callback
                    locationPermission.launch(
                        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                    )
                }
            }

            override fun onShowFileChooser(
                view: WebView,
                callback: ValueCallback<Array<Uri>>,
                params: FileChooserParams
            ): Boolean {
                fileCallback?.onReceiveValue(null)
                fileCallback = callback
                return try {
                    pickFile.launch(arrayOf("application/pdf", "application/json", "text/plain", "application/octet-stream"))
                    true
                } catch (e: ActivityNotFoundException) {
                    fileCallback = null
                    false
                }
            }

            override fun onConsoleMessage(msg: ConsoleMessage): Boolean {
                Log.println(
                    if (msg.messageLevel() == ConsoleMessage.MessageLevel.ERROR) Log.ERROR else Log.INFO,
                    "SuchgebietJS",
                    "${msg.message()} (${msg.sourceId()}:${msg.lineNumber()})"
                )
                return true
            }
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Offenes Fenster schließen statt die App zu beenden
                webView.evaluateJavascript(
                    "(function(){var n=document.getElementById('notepad');if(n&&!n.hidden){document.getElementById('pad-done').click();return true}" +
                        "var p=[...document.querySelectorAll('.panel')].find(function(x){return !x.hidden});" +
                        "if(p){p.hidden=true;return true}return false})()"
                ) { closed ->
                    if (closed != "true") {
                        isEnabled = false
                        onBackPressedDispatcher.onBackPressed()
                        isEnabled = true
                    }
                }
            }
        })

        if (savedInstanceState != null) webView.restoreState(savedInstanceState)
        else webView.loadUrl(startUrl)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    private fun toast(text: String) = runOnUiThread {
        Toast.makeText(this, text, Toast.LENGTH_LONG).show()
    }

    inner class Bridge {
        // Mehrere Dateien in einen frei wählbaren Ordner speichern (JSON: [{b64, name, mime}])
        @JavascriptInterface
        fun saveFiles(json: String) {
            val files = try { parseFiles(json) } catch (e: Exception) { toast("Speichern fehlgeschlagen"); return }
            runOnUiThread {
                pendingFiles = files
                pickDir.launch(null)
            }
        }

        // Mehrere Dateien in einem Teilen-Dialog senden
        @JavascriptInterface
        fun shareFiles(json: String, title: String, text: String) {
            sendMultiple(json, title, text, emptyArray())
        }

        // Mail mit mehreren Anhängen an bestimmte Empfänger (Komma-getrennt), nur Mail-Apps
        @JavascriptInterface
        fun emailFilesTo(json: String, subject: String, text: String, to: String) {
            val list = to.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toTypedArray()
            sendMultiple(json, subject, text, list, emailOnly = true)
        }

        private fun sendMultiple(json: String, title: String, text: String, to: Array<String>, emailOnly: Boolean = false) {
            try {
                val dir = File(cacheDir, "shared").apply { mkdirs() }
                dir.listFiles()?.forEach { it.delete() }
                val uris = ArrayList<Uri>()
                for ((name, _, bytes) in parseFiles(json)) {
                    val file = File(dir, name.replace(Regex("[^A-Za-z0-9._-]"), "_"))
                    file.writeBytes(bytes)
                    uris.add(FileProvider.getUriForFile(this@MainActivity, "$packageName.files", file))
                }
                val send = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                    type = "*/*"
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                    putExtra(Intent.EXTRA_SUBJECT, title)
                    putExtra(Intent.EXTRA_TEXT, text)
                    if (to.isNotEmpty()) putExtra(Intent.EXTRA_EMAIL, to)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    if (emailOnly) selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
                }
                runOnUiThread {
                    try {
                        startActivity(Intent.createChooser(send, if (emailOnly) "E-Mail senden mit …" else "Senden an …"))
                    } catch (e: ActivityNotFoundException) {
                        toast(if (emailOnly) "Keine E-Mail-App gefunden" else "Keine App zum Teilen gefunden")
                    }
                }
            } catch (e: Exception) {
                Log.e("Suchgebiet", "Teilen fehlgeschlagen", e)
                toast("Teilen fehlgeschlagen: ${e.message}")
            }
        }

        // Wird aus app.js aufgerufen: Datei (Base64) an einem frei wählbaren Ort speichern
        @JavascriptInterface
        fun saveFile(base64: String, name: String, mime: String) {
            val bytes = try {
                Base64.decode(base64, Base64.DEFAULT)
            } catch (e: IllegalArgumentException) {
                toast("Speichern fehlgeschlagen")
                return
            }
            runOnUiThread {
                pendingSave = bytes
                createDoc.mime = mime.ifEmpty { "application/octet-stream" }
                saveDoc.launch(name)
            }
        }

        // Wird aus app.js aufgerufen: Datei (Base64) über den Android-Teilen-Dialog senden
        @JavascriptInterface
        fun shareFile(base64: String, name: String, mime: String, title: String, text: String) {
            send(base64, name, mime, title, text, emailOnly = false)
        }

        // Wie shareFile, aber nur Mail-Apps (Gmail, Outlook …) – die Datei ist bereits angehängt
        @JavascriptInterface
        fun emailFile(base64: String, name: String, mime: String, subject: String, text: String) {
            send(base64, name, mime, subject, text, emailOnly = true)
        }

        // Mail mit Empfängern (durch Komma getrennt) und Anhang, z. B. Einsatzbericht
        @JavascriptInterface
        fun emailFileTo(base64: String, name: String, mime: String, subject: String, text: String, to: String) {
            val list = to.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toTypedArray()
            send(base64, name, mime, subject, text, emailOnly = true, to = list)
        }

        private fun send(
            base64: String, name: String, mime: String, title: String, text: String, emailOnly: Boolean,
            to: Array<String> = emptyArray(),
        ) {
            try {
                val dir = File(cacheDir, "shared").apply { mkdirs() }
                dir.listFiles()?.forEach { it.delete() }
                val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val file = File(dir, safe)
                file.writeBytes(Base64.decode(base64, Base64.DEFAULT))
                val uri = FileProvider.getUriForFile(this@MainActivity, "$packageName.files", file)
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = mime.ifEmpty { "application/octet-stream" }
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_SUBJECT, title)
                    putExtra(Intent.EXTRA_TEXT, text)
                    if (to.isNotEmpty()) putExtra(Intent.EXTRA_EMAIL, to)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    // Selektor mailto: -> Android bietet nur E-Mail-Apps an
                    if (emailOnly) selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
                }
                runOnUiThread {
                    try {
                        startActivity(Intent.createChooser(send, if (emailOnly) "E-Mail senden mit …" else "Senden an …"))
                    } catch (e: ActivityNotFoundException) {
                        toast(if (emailOnly) "Keine E-Mail-App gefunden" else "Keine App zum Teilen gefunden")
                    }
                }
            } catch (e: Exception) {
                Log.e("Suchgebiet", "Teilen fehlgeschlagen", e)
                toast("Teilen fehlgeschlagen: ${e.message}")
            }
        }
    }
}
