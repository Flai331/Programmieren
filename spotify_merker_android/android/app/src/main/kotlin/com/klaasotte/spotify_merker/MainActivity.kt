package com.klaasotte.spotify_merker

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.media.session.PlaybackState
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "spotify_merker/native"

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isPermissionGranted" -> result.success(isPermissionGranted())
                        "openPermissionSettings" -> {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        }
                        "openAppDetails" -> {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.fromParts("package", packageName, null),
                                )
                            )
                            result.success(null)
                        }
                        "drainEvents" -> result.success(EventLog.drain(this))
                        "getCurrent" -> result.success(MediaListenerService.instance?.snapshot()?.toMap())
                        "isSpotifyInstalled" -> result.success(isSpotifyInstalled())
                        "resume" -> {
                            // Zahlen kommen aus Dart je nach Größe als Integer oder Long.
                            val position = (call.argument<Any>("positionMs") as? Number)?.toLong() ?: 0L
                            val error = ResumeHelper.resume(
                                this,
                                call.argument<String>("title") ?: "",
                                call.argument<String>("artist") ?: "",
                                call.argument<String>("album") ?: "",
                                call.argument<String>("spotifyUri"),
                                call.argument<String>("mediaId"),
                                position,
                            )
                            result.success(mapOf("started" to (error == null), "error" to error))
                        }
                        "getDiagnostics" -> result.success(diagnostics())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, e.javaClass.simpleName)
                }
            }
    }

    private fun isPermissionGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val me = ComponentName(this, MediaListenerService::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == me }
    }

    private fun isSpotifyInstalled(): Boolean = try {
        packageManager.getPackageInfo(SPOTIFY_PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun diagnostics(): Map<String, Any?> {
        val service = MediaListenerService.instance
        val controller = service?.spotifyController
        val actions = controller?.playbackState?.actions ?: 0L
        val actionNames = listOf(
            PlaybackState.ACTION_PLAY to "PLAY",
            PlaybackState.ACTION_PAUSE to "PAUSE",
            PlaybackState.ACTION_SEEK_TO to "SEEK_TO",
            PlaybackState.ACTION_SKIP_TO_NEXT to "SKIP_TO_NEXT",
            PlaybackState.ACTION_PLAY_FROM_MEDIA_ID to "PLAY_FROM_MEDIA_ID",
            PlaybackState.ACTION_PLAY_FROM_SEARCH to "PLAY_FROM_SEARCH",
            PlaybackState.ACTION_PLAY_FROM_URI to "PLAY_FROM_URI",
        ).filter { (flag, _) -> (actions and flag) != 0L }.map { it.second }
        return mapOf(
            "permission" to isPermissionGranted(),
            "serviceConnected" to (service?.connected == true),
            "spotifyInstalled" to isSpotifyInstalled(),
            "spotifySessionFound" to (controller != null),
            "current" to service?.snapshot()?.toMap(),
            "lastMetadata" to (service?.rawMetadata() ?: emptyMap<String, String>()),
            "actions" to actionNames,
            "lastBroadcast" to (service?.lastBroadcast ?: emptyMap<String, String>()),
            "lastResumeLog" to ResumeHelper.lastLog(),
            "lastMotionAt" to service?.lastMotionAt,
            "motionListening" to service?.motionListening,
        )
    }
}
