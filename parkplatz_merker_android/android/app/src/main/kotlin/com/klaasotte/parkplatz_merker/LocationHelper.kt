package com.klaasotte.parkplatz_merker

import android.content.Context
import android.location.Location
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

object LocationHelper {
    fun current(ctx: Context, cb: (Location?) -> Unit) {
        try {
            val client = LocationServices.getFusedLocationProviderClient(ctx)
            val request = CurrentLocationRequest.Builder()
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setDurationMillis(30_000L)
                .setMaxUpdateAgeMillis(10_000L)
                .build()

            val callbackExecuted = AtomicBoolean(false)
            client.getCurrentLocation(request, null)
                .addOnSuccessListener { location ->
                    if (!callbackExecuted.getAndSet(true)) {
                        cb(location)
                    }
                }
                .addOnFailureListener {
                    if (!callbackExecuted.getAndSet(true)) {
                        cb(null)
                    }
                }
        } catch (e: SecurityException) {
            cb(null)
        }
    }

    fun toMap(location: Location): Map<String, Any?> {
        return mapOf(
            "lat" to location.latitude,
            "lng" to location.longitude,
            "acc" to location.accuracy.toDouble(),
            "t" to location.time
        )
    }

    fun toJson(location: Location, reason: String = "periodic"): JSONObject {
        val obj = JSONObject()
        obj.put("type", "loc")
        obj.put("t", location.time)
        obj.put("lat", location.latitude)
        obj.put("lng", location.longitude)
        obj.put("acc", location.accuracy.toDouble())
        obj.put("reason", reason)
        return obj
    }
}
