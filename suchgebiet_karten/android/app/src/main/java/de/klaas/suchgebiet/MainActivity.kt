package de.klaas.suchgebiet

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Base64
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.view.WindowManager
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

    // Per „Teilen“ (z. B. WhatsApp) oder „Öffnen mit“ empfangene Datei (GPX, KML, Suchgebiet, PDF).
    // Die Web-App holt sie mit AndroidBridge.takeSharedFile() ab.
    @Volatile private var sharedFile: String? = null

    private val locationPermission = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val granted = result.values.any { it }
        pendingGeo?.let { (origin, cb) -> cb.invoke(origin, granted, false) }
        pendingGeo = null
        if (!granted) toast("Ohne Standortfreigabe kein GPS")
    }

    // Kamera für den QR-Scanner (Rückmeldungen der Hundeführer)
    private var pendingCamera: PermissionRequest? = null
    private val cameraPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingCamera?.let { req -> if (granted) req.grant(req.resources) else req.deny() }
        pendingCamera = null
        if (!granted) toast("Ohne Kamera-Freigabe kein QR-Scan")
    }

    // Für die Fortschrittsanzeige des Offline-Downloads (Android 13+); ohne geht es trotzdem
    private val notifyPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    private val pickFile = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        fileCallback?.onReceiveValue(if (uri != null) arrayOf(uri) else null)
        fileCallback = null
    }

    // Foto vom Papier: Kamera-App nimmt in eine Datei im Cache auf, die dann an die Web-App geht
    private var photoUri: Uri? = null
    private val takePhoto = registerForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val uri = photoUri
        fileCallback?.onReceiveValue(if (ok && uri != null) arrayOf(uri) else null)
        fileCallback = null
    }
    private val photoPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) launchCamera() else {
            toast("Ohne Kamera-Freigabe kein Foto")
            fileCallback?.onReceiveValue(null)
            fileCallback = null
        }
    }

    private fun launchCamera() {
        try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val file = File(dir, "foto.jpg")
            val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
            photoUri = uri
            takePhoto.launch(uri)
        } catch (e: Exception) {
            toast("Keine Kamera-App gefunden")
            fileCallback?.onReceiveValue(null)
            fileCallback = null
        }
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
        ErrorReports.installCrashHandler(this)
        ErrorReports.flush(this)
        OfflineTiles.init(this)
        val assetLoader = WebViewAssetLoader.Builder()
            .setDomain(host)
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView = WebView(this)
        setContentView(webView)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false // Kamera-Vorschau beim QR-Scan
            setGeolocationEnabled(true)
            allowFileAccess = false
            allowContentAccess = false
        }
        webView.addJavascriptInterface(Bridge(), "AndroidBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                // Offline gespeicherte Kartenbilder sofort aus dem Speicher, sonst aus dem Netz
                if (request.method == "GET" && OfflineTiles.isTileHost(request.url.host)) {
                    return OfflineTiles.serve(request.url.toString())
                }
                return assetLoader.shouldInterceptRequest(request.url)
            }

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

            override fun onPermissionRequest(request: PermissionRequest) {
                runOnUiThread {
                    if (!request.resources.contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE)) {
                        request.deny()
                    } else if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                        request.grant(arrayOf(PermissionRequest.RESOURCE_VIDEO_CAPTURE))
                    } else {
                        pendingCamera = request
                        cameraPermission.launch(Manifest.permission.CAMERA)
                    }
                }
            }

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
                return try {
                    if (image) pickFile.launch(arrayOf("image/*")) else pickFile.launch(arrayOf("application/pdf", "application/json", "text/plain", "application/octet-stream", "application/gpx+xml", "application/xml", "text/xml", "text/vcard", "text/x-vcard", "text/directory", "application/vnd.google-earth.kml+xml", "text/csv", "text/comma-separated-values"))
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

        val link = sharedHash(intent)
        receiveFile(intent)
        if (savedInstanceState != null && link == null) webView.restoreState(savedInstanceState)
        else webView.loadUrl(startUrl + (link ?: ""))
    }

    // Auftrags-/Rückmelde-Link (https://flai331.github.io/…#a=… bzw. #r=…) in der App öffnen
    private fun sharedHash(i: Intent?): String? {
        // #… direkt aus dem Link, oder ?h=… aus dem „In der App öffnen“-Knopf der Webseite (intent:-Link)
        val frag = i?.data?.fragment ?: i?.data?.takeIf { it.isHierarchical }?.getQueryParameter("h") ?: return null
        // a = Auftrag, r = Rückmeldung, e = Einsatz-Übergabe, i = Lage-Infos, f = Fortschritt
        return if (Regex("^[areimf]=.+").matches(frag)) "#$frag" else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (receiveFile(intent)) {
            // App läuft schon: Web-App holt die Datei sofort ab
            webView.evaluateJavascript("window.onSharedFile&&window.onSharedFile()", null)
            return
        }
        val link = sharedHash(intent) ?: return
        // App läuft schon: nur den Hash setzen, die Web-App übernimmt die Daten (hashchange)
        webView.evaluateJavascript("location.hash=" + org.json.JSONObject.quote(link), null)
    }

    // Datei aus ACTION_SEND (Teilen) bzw. ACTION_VIEW mit content:-Adresse (Öffnen mit) lesen
    private fun receiveFile(i: Intent?): Boolean {
        if (i == null) return false
        val uri: Uri = when (i.action) {
            Intent.ACTION_SEND -> (if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_STREAM)) ?: return false
            Intent.ACTION_VIEW -> i.data?.takeIf { it.scheme == "content" || it.scheme == "file" } ?: return false
            else -> return false
        }
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
                    if (out.size() > 20 * 1024 * 1024) throw IllegalStateException("Datei zu groß (über 20 MB)")
                }
                out.toByteArray()
            } ?: return false
            sharedFile = org.json.JSONObject()
                .put("name", name)
                .put("data", Base64.encodeToString(bytes, Base64.NO_WRAP))
                .toString()
            i.action = Intent.ACTION_MAIN // nicht nach Drehen/Neustart erneut importieren
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

    inner class Bridge {
        // Fehlerbericht aus der Web-App (JSON, ohne Einsatzdaten) an die Notion-Fehlerzentrale.
        // Rückgabe: "sent" (wird gesendet), "mail" (kein Token: Mail-App geöffnet), "none" (Auto-Fehler ohne Token)
        @JavascriptInterface
        fun reportError(json: String): String {
            val r = try { org.json.JSONObject(json) } catch (_: Exception) { return "none" }
            if (ErrorReports.hasToken) {
                ErrorReports.send(this@MainActivity, r)
                return "sent"
            }
            if (r.optString("kind") != "Manuelle Meldung") return "none"
            val body = listOf(
                "Beschreibung: " + r.optString("desc"),
                "Fehler: " + r.optString("error"),
                "Seite: " + r.optString("page"),
                "Rolle: " + r.optString("role"),
                "Version: " + r.optString("version"),
                "Gerät: " + ErrorReports.device() + ", " + ErrorReports.os(),
                "", "Protokoll:", r.optString("log"),
            ).joinToString("\n")
            val mail = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:klaasotte99@gmail.com")).apply {
                putExtra(Intent.EXTRA_SUBJECT, "Suchgebiet-Karten: " + r.optString("title", "Fehlerbericht"))
                putExtra(Intent.EXTRA_TEXT, body)
            }
            runOnUiThread {
                try { startActivity(mail) } catch (e: ActivityNotFoundException) { toast("Keine Mail-App gefunden") }
            }
            return "mail"
        }

        // Empfangene Datei als JSON {name, data(Base64)} – einmalig, danach leer
        @JavascriptInterface
        fun takeSharedFile(): String {
            val f = sharedFile ?: return ""
            sharedFile = null
            return f
        }

        // Text (z. B. Auftrags-Link) über den Teilen-Dialog senden – WhatsApp, SMS …
        @JavascriptInterface
        fun shareText(title: String, text: String) {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, title)
                putExtra(Intent.EXTRA_TEXT, text)
            }
            runOnUiThread {
                try { startActivity(Intent.createChooser(send, "Senden an …")) } catch (e: ActivityNotFoundException) { toast("Keine App zum Teilen gefunden") }
            }
        }

        // Bildschirm anlassen (Weg aufzeichnen)
        @JavascriptInterface
        fun keepScreenOn(on: Boolean) = runOnUiThread {
            if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        // ---------- Offline-Karten (siehe OfflineTiles / TileDownloadService) ----------
        @JavascriptInterface
        fun offlineStart(job: String) {
            if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) runOnUiThread { notifyPermission.launch(Manifest.permission.POST_NOTIFICATIONS) }
            TileDownloadService.start(this@MainActivity, job)
        }

        @JavascriptInterface
        fun offlineStop() = TileDownloadService.stop(this@MainActivity)

        @JavascriptInterface
        fun offlineStatus(): String = OfflineTiles.statusJson()

        @JavascriptInterface
        fun offlineStorage(): String = OfflineTiles.storageJson()

        // JSON: { region: {id, bounds, zMin, zMax, layerIds, layers}, others: [{bounds, zMin, zMax, layerIds}] }
        @JavascriptInterface
        fun offlineDelete(json: String) = OfflineTiles.delete(json)

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
