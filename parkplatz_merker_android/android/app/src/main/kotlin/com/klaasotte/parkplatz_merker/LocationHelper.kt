package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

object LocationHelper {
    /**
     * Aktuelle Position (hohe Genauigkeit, max. 30 s), sonst letzte bekannte.
     * [cb] wird genau einmal aufgerufen (auf dem Main-Thread).
     */
    @SuppressLint("MissingPermission")
    fun current(ctx: Context, cb: (Location?) -> Unit) {
        val done = AtomicBoolean(false)
        val finish: (Location?) -> Unit = { loc -> if (!done.getAndSet(true)) cb(loc) }
        try {
            val client = LocationServices.getFusedLocationProviderClient(ctx)
            val request = CurrentLocationRequest.Builder()
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setDurationMillis(30_000L)
                .setMaxUpdateAgeMillis(10_000L)
                .build()
            client.getCurrentLocation(request, null)
                .addOnSuccessListener { location ->
                    if (location != null) finish(location) else last(ctx, finish)
                }
                .addOnFailureListener { last(ctx, finish) }
        } catch (e: Exception) {
            finish(null)
        }
    }

    /** Letzte bekannte Position oder null. [cb] wird genau einmal aufgerufen. */
    @SuppressLint("MissingPermission")
    fun last(ctx: Context, cb: (Location?) -> Unit) {
        try {
            LocationServices.getFusedLocationProviderClient(ctx).lastLocation
                .addOnSuccessListener { location -> cb(location) }
                .addOnFailureListener { cb(null) }
        } catch (e: Exception) {
            cb(null)
        }
    }

    fun toMap(location: Location): Map<String, Any?> = mapOf(
        "lat" to location.latitude,
        "lng" to location.longitude,
        "acc" to location.accuracy.toDouble(),
        "t" to location.time,
    )

    fun toJson(location: Location, reason: String): JSONObject {
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
