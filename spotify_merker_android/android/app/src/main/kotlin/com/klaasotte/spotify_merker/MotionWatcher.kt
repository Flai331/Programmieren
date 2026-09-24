package com.klaasotte.spotify_merker

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import org.json.JSONObject

private const val TAG = "MotionWatcher"

/**
 * Passive Bewegungserkennung: registriert TYPE_ACCELEROMETER nur während PLAYING,
 * erkennt Bewegung (lineare Beschleunigung > 1.2 m/s²), drosselt auf 1 Event/60s.
 */
class MotionWatcher(private val ctx: Context) : SensorEventListener {
    private val sensorManager = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accel: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gravity = FloatArray(3) // Tiefpass-Schätzung der Erdbeschleunigung
    private val alpha = 0.8f
    private var gravityInitialized = false

    /** Seit wann der Sensor läuft (0 = aus). */
    var registeredSince = 0L
        private set

    /** Zeitpunkt der zuletzt aufgezeichneten Bewegung (0 = noch keine). */
    @Volatile
    var lastMotionAt = 0L
        private set

    private var lastEventAt = 0L
    private var maxMagnitude = 0f

    val listening: Boolean get() = registeredSince > 0

    fun start() {
        if (accel == null || listening) return // schon aktiv: nichts zurücksetzen
        registeredSince = System.currentTimeMillis()
        gravityInitialized = false
        maxMagnitude = 0f
        try {
            sensorManager.registerListener(this, accel, SensorManager.SENSOR_DELAY_NORMAL)
        } catch (e: Exception) {
            registeredSince = 0L
            Log.e(TAG, "registerListener fehlgeschlagen", e)
        }
    }

    fun stop() {
        if (!listening) return
        try {
            sensorManager.unregisterListener(this)
        } catch (e: Exception) {
            Log.e(TAG, "unregisterListener fehlgeschlagen", e)
        }
        registeredSince = 0L
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.values.size < 3) return
        val now = System.currentTimeMillis()
        val v = event.values

        // Schwerkraft immer nachführen – auch in der Einschwingphase.
        if (!gravityInitialized) {
            gravity[0] = v[0]; gravity[1] = v[1]; gravity[2] = v[2]
            gravityInitialized = true
            return
        }
        for (i in 0..2) gravity[i] = alpha * gravity[i] + (1 - alpha) * v[i]

        // Erste 2 Sekunden nur einschwingen, nicht auswerten.
        if (now - registeredSince < 2000) return

        val x = v[0] - gravity[0]
        val y = v[1] - gravity[1]
        val z = v[2] - gravity[2]
        val magnitude = kotlin.math.sqrt(x * x + y * y + z * z)

        if (magnitude > 1.2f) {
            if (magnitude > maxMagnitude) maxMagnitude = magnitude
            // Höchstens ein Ereignis pro Minute.
            if (now - lastEventAt >= 60_000) {
                val level = kotlin.math.round(maxMagnitude * 10) / 10.0
                EventLog.append(ctx, JSONObject(mapOf(
                    "ts" to now,
                    "type" to "motion",
                    "level" to level,
                )))
                lastEventAt = now
                lastMotionAt = now
                maxMagnitude = 0f
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
