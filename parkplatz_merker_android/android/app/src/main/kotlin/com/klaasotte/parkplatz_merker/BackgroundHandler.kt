package com.klaasotte.parkplatz_merker

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

class BackgroundHandler(
    private val ctx: Context,
    private val onDone: () -> Unit
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "drainEvents" -> {
                    result.success(EventLog.drain(ctx))
                }
                "getConfig" -> {
                    result.success(Config.getConfig())
                }
                "registerTransitions" -> {
                    result.success(mapOf("ok" to true, "error" to null))
                }
                "getLastLocation" -> {
                    LocationHelper.last(ctx) { location ->
                        Handler(Looper.getMainLooper()).post {
                            result.success(location?.let { LocationHelper.toMap(it) })
                        }
                    }
                }
                "reverseGeocode" -> {
                    val lat = (call.argument<Any>("lat") as? Number)?.toDouble()
                    val lng = (call.argument<Any>("lng") as? Number)?.toDouble()
                    if (lat != null && lng != null) {
                        Geo.reverse(ctx, lat, lng) { text ->
                            Handler(Looper.getMainLooper()).post { result.success(text) }
                        }
                    } else {
                        result.success(null)
                    }
                }
                "updateWidget" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any?>
                    CarWidget.save(ctx, args)
                    result.success(null)
                }
                "backgroundDone" -> {
                    result.success(null)
                    onDone()
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("NATIVE_ERROR", e.message, null)
        }
    }
}
