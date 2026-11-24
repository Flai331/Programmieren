package com.klaasotte.beebrain

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Nimmt von Dart den Auftrag an, ein geladenes Paket zu installieren.
 *
 * Installieren darf nur Android selbst, und es fragt den Imker dabei. Die
 * App kann nichts weiter tun als das Paket vorzulegen — über einen
 * FileProvider, denn seit Android 7 wirft ein `file://`-Verweis an eine
 * fremde App eine FileUriExposedException.
 *
 * Absichtlich eigenes Kotlin statt eines Pakets wie install_plugin: Dieses
 * Projekt hat file_picker wegen AGP 9 ganz verloren und den Bau an
 * connectivity_plus 5 fast. Diese fünfzig Zeilen tragen dieses Risiko nicht.
 *
 * Die Rückgaben sind Zeichenketten, die UpdateService.install in
 * InstallOutcome übersetzt: "started", "permission", "failed".
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL)
            .setMethodCallHandler { aufruf, antwort ->
                when (aufruf.method) {
                    "install" -> {
                        val pfad = aufruf.argument<String>("path")
                        if (pfad.isNullOrEmpty()) {
                            antwort.error(
                                "kein_pfad",
                                "Ohne Pfad gibt es nichts zu installieren.",
                                null
                            )
                        } else {
                            antwort.success(installiere(pfad))
                        }
                    }
                    else -> antwort.notImplemented()
                }
            }
    }

    private fun installiere(pfad: String): String {
        val paket = File(pfad)
        if (!paket.exists() || paket.length() == 0L) return "failed"

        // Ab Android 8 darf nur installieren, wer die Erlaubnis „unbekannte
        // Apps installieren" hat. Die lässt sich nicht wie eine normale
        // Berechtigung erfragen — sie wird in den Einstellungen gegeben.
        // Also dorthin schicken, statt stumm zu scheitern.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            return try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    )
                )
                "permission"
            } catch (fehler: Exception) {
                "failed"
            }
        }

        // packageName trägt bei Testbauten das Suffix ".test" — die Kennung
        // des Providers wächst mit, weil im Manifest ${applicationId} steht.
        val uri = try {
            FileProvider.getUriForFile(this, "$packageName.updates", paket)
        } catch (fehler: IllegalArgumentException) {
            // Die Datei liegt außerhalb der freigegebenen Pfade, siehe
            // res/xml/provider_paths.xml.
            return "failed"
        }

        return try {
            startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            )
            "started"
        } catch (fehler: Exception) {
            "failed"
        }
    }

    companion object {
        private const val KANAL = "beebrain/installer"
    }
}
