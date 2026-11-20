package de.klaas.hundekeks;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;

/** Zeigt die Hundekeks-Web-App offline aus den Assets an. */
public class MainActivity extends Activity {
    private static final int REQ_PHOTO = 1;
    private static final int REQ_SAVE = 2;
    /** Interne Adresse: Assets werden wie von einem Webserver geliefert (nötig für KI-Module und WebAssembly). */
    private static final String HOST = "appassets.androidplatform.net";

    private WebView web;
    private ValueCallback<Uri[]> photoCallback;
    private byte[] pendingZip;
    private Uri sharedImage;
    private boolean pageReady;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        web = new WebView(this);
        setContentView(web);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        web.addJavascriptInterface(new Bridge(), "AndroidBridge");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (!HOST.equals(u.getHost())) return null;
                String path = u.getPath();
                if (path == null || path.equals("/")) path = "/index.html";
                Map<String, String> headers = new HashMap<>();
                headers.put("Access-Control-Allow-Origin", "*");
                try {
                    InputStream in = getAssets().open(path.substring(1));
                    String mime = mimeFor(path);
                    String enc = mime.startsWith("text/") || mime.endsWith("javascript") ? "utf-8" : null;
                    return new WebResourceResponse(mime, enc, 200, "OK", headers, in);
                } catch (Exception e) {
                    return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", headers, null);
                }
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                pageReady = true;
                deliverSharedImage();
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> cb, FileChooserParams params) {
                if (photoCallback != null) photoCallback.onReceiveValue(null);
                photoCallback = cb;
                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.addCategory(Intent.CATEGORY_OPENABLE);
                pick.setType("image/*");
                try {
                    startActivityForResult(Intent.createChooser(pick, "Foto wählen"), REQ_PHOTO);
                } catch (Exception e) {
                    photoCallback = null;
                    return false;
                }
                return true;
            }
        });
        handleIntent(getIntent());
        web.loadUrl("https://" + HOST + "/index.html");
    }

    private static String mimeFor(String path) {
        if (path.endsWith(".html")) return "text/html";
        if (path.endsWith(".js") || path.endsWith(".mjs")) return "text/javascript";
        if (path.endsWith(".wasm")) return "application/wasm";
        if (path.endsWith(".png")) return "image/png";
        return "application/octet-stream";
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
        deliverSharedImage();
    }

    /** Foto, das aus der Galerie per "Teilen" an die App geschickt wurde. */
    private void handleIntent(Intent intent) {
        if (intent != null && Intent.ACTION_SEND.equals(intent.getAction())) {
            Object extra = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (extra instanceof Uri) sharedImage = (Uri) extra;
        }
    }

    private void deliverSharedImage() {
        if (!pageReady || sharedImage == null) return;
        Uri uri = sharedImage;
        sharedImage = null;
        try (InputStream in = getContentResolver().openInputStream(uri)) {
            ByteArrayOutputStream buf = new ByteArrayOutputStream();
            byte[] chunk = new byte[65536];
            int n;
            while ((n = in.read(chunk)) > 0) buf.write(chunk, 0, n);
            String type = getContentResolver().getType(uri);
            if (type == null) type = "image/jpeg";
            String data = "data:" + type + ";base64," + Base64.encodeToString(buf.toByteArray(), Base64.NO_WRAP);
            web.evaluateJavascript("openDataUrl('" + data + "')", null);
        } catch (Exception e) {
            web.evaluateJavascript("toast('Geteiltes Foto konnte nicht gelesen werden.')", null);
        }
    }

    @Override
    protected void onActivityResult(int req, int result, Intent data) {
        super.onActivityResult(req, result, data);
        if (req == REQ_PHOTO) {
            Uri[] res = null;
            if (result == RESULT_OK && data != null && data.getData() != null) res = new Uri[]{data.getData()};
            if (photoCallback != null) photoCallback.onReceiveValue(res);
            photoCallback = null;
        } else if (req == REQ_SAVE) {
            if (result == RESULT_OK && data != null && data.getData() != null && pendingZip != null) {
                try (OutputStream out = getContentResolver().openOutputStream(data.getData())) {
                    out.write(pendingZip);
                    web.evaluateJavascript("toast('ZIP gespeichert')", null);
                } catch (Exception e) {
                    web.evaluateJavascript("toast('Speichern fehlgeschlagen')", null);
                }
            } else {
                web.evaluateJavascript("toast('Speichern abgebrochen')", null);
            }
            pendingZip = null;
        }
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    /** Wird aus JavaScript als window.AndroidBridge aufgerufen. */
    private class Bridge {
        @JavascriptInterface
        public void saveFile(final String name, String base64) {
            pendingZip = Base64.decode(base64, Base64.DEFAULT);
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Intent save = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    save.addCategory(Intent.CATEGORY_OPENABLE);
                    save.setType("application/zip");
                    save.putExtra(Intent.EXTRA_TITLE, name);
                    startActivityForResult(save, REQ_SAVE);
                }
            });
        }
    }
}
