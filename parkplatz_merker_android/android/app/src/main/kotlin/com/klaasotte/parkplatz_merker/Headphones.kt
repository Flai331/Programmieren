package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.IntentCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Kopfhörer: Wird ein gewählter (gekoppelter) Kopfhörer getrennt, merken wir uns,
 * wo das Handy in dem Moment war – so findet man verlorene Kopfhörer wieder.
 * Nur für Geräte, die der Nutzer selbst mit dem Handy gekoppelt hat; der Transmitter
 * im Auto ist davon nicht betroffen (der wird nie gekoppelt).
 */
object Headphones {
    private const val PREFS = "headphones"
    private const val KEY_SPOTS = "spots"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Gewählte Kopfhörer (Adressen, groß geschrieben). */
    private fun chosen(): Set<String> = try {
        val ja = JSONArray(Config.headphones.ifEmpty { "[]" })
        (0 until ja.length()).map { ja.getJSONObject(it).optString("address").uppercase() }.toSet()
    } catch (e: Exception) {
        emptySet()
    }

    private fun chosenName(address: String): String = try {
        val ja = JSONArray(Config.headphones.ifEmpty { "[]" })
        (0 until ja.length()).map { ja.getJSONObject(it) }
            .firstOrNull { it.optString("address").equals(address, ignoreCase = true) }
            ?.optString("name") ?: ""
    } catch (e: Exception) {
        ""
    }

    private fun spots(ctx: Context): JSONObject = try {
        JSONObject(prefs(ctx).getString(KEY_SPOTS, "{}") ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    private fun saveSpots(ctx: Context, obj: JSONObject) {
        prefs(ctx).edit().putString(KEY_SPOTS, obj.toString()).apply()
    }

    /** Gekoppelte Bluetooth-Geräte zur Auswahl (Audio-Geräte zuerst). */
    @SuppressLint("MissingPermission")
    fun bonded(ctx: Context): List<Map<String, Any?>> {
        return try {
            val bm = ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return emptyList()
            val devices = bm.adapter?.bondedDevices ?: return emptyList()
            devices.map { d ->
                val major = d.bluetoothClass?.majorDeviceClass
                mapOf(
                    "address" to d.address,
                    "name" to (d.name ?: d.address),
                    "audio" to (major == BluetoothClass.Device.Major.AUDIO_VIDEO),
                )
            }.sortedWith(compareBy<Map<String, Any?>>({ it["audio"] != true }, { (it["name"] as String).lowercase() }))
        } catch (e: SecurityException) {
            emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** Letzte Orte aller gewählten Kopfhörer. */
    fun all(ctx: Context): List<Map<String, Any?>> {
        val obj = spots(ctx)
        val out = mutableListOf<Map<String, Any?>>()
        for (address in chosen()) {
            val s = obj.optJSONObject(address)
            out.add(
                mapOf(
                    "address" to address,
                    "name" to (s?.optString("name")?.ifEmpty { null } ?: chosenName(address).ifEmpty { address }),
                    "connected" to (s?.optBoolean("connected", false) ?: false),
                    "changedAt" to (s?.optLong("changedAt", 0L) ?: 0L),
                    "lat" to s?.let { if (it.has("lat")) it.optDouble("lat") else null },
                    "lng" to s?.let { if (it.has("lng")) it.optDouble("lng") else null },
                    "acc" to s?.let { if (it.has("acc")) it.optDouble("acc") else null },
                    "fixAt" to (s?.optLong("fixAt", 0L) ?: 0L),
                )
            )
        }
        return out
    }

    fun forget(ctx: Context, address: String) {
        val obj = spots(ctx)
        obj.remove(address.uppercase())
        saveSpots(ctx, obj)
    }

    fun onConnected(ctx: Context, address: String, name: String) {
        val key = address.uppercase()
        val obj = spots(ctx)
        val s = obj.optJSONObject(key) ?: JSONObject()
        if (s.optBoolean("connected", false)) return
        s.put("name", name)
        s.put("connected", true)
        s.put("changedAt", System.currentTimeMillis())
        obj.put(key, s)
        saveSpots(ctx, obj)
        EventLog.info(ctx, "Kopfhörer verbunden: $name")
    }

    /** Getrennt: sofort letzte bekannte Position, dann genauere nachtragen. [done] genau einmal. */
    fun onDisconnected(ctx: Context, address: String, name: String, done: () -> Unit) {
        val key = address.uppercase()
        val obj = spots(ctx)
        val s = obj.optJSONObject(key) ?: JSONObject()
        val now = System.currentTimeMillis()
        // A2DP, Headset und ACL melden dieselbe Trennung – nur einmal behandeln.
        if (s.has("changedAt") && !s.optBoolean("connected", true) && now - s.optLong("changedAt") < 60_000L) {
            done()
            return
        }
        s.put("name", name)
        s.put("connected", false)
        s.put("changedAt", now)
        obj.put(key, s)
        saveSpots(ctx, obj)
        EventLog.info(ctx, "Kopfhörer getrennt: $name – Ort wird gespeichert")

        LocationHelper.current(ctx) { loc ->
            if (loc != null) {
                val latest = spots(ctx)
                val entry = latest.optJSONObject(key) ?: JSONObject()
                // Nur speichern, wenn inzwischen nicht wieder verbunden.
                if (!entry.optBoolean("connected", false)) {
                    entry.put("lat", loc.latitude)
                    entry.put("lng", loc.longitude)
                    entry.put("acc", loc.accuracy.toDouble())
                    entry.put("fixAt", loc.time)
                    latest.put(key, entry)
                    saveSpots(ctx, latest)
                    EventLog.info(ctx, "Kopfhörer $name: Ort gespeichert (± ${loc.accuracy.toInt()} m)")
                }
            } else {
                EventLog.info(ctx, "Kopfhörer $name: kein Standort verfügbar")
            }
            done()
        }
    }

    fun isChosen(address: String): Boolean = chosen().contains(address.uppercase())
}

/** Verbindungswechsel von Bluetooth-Geräten (Systemmeldungen). */
class HeadphoneReceiver : BroadcastReceiver() {
    @SuppressLint("MissingPermission")
    override fun onReceive(context: Context, intent: Intent) {
        Config.init(context)
        val device = IntentCompat.getParcelableExtra(intent, BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            ?: return
        val address = device.address ?: return
        if (!Headphones.isChosen(address)) return

        val connected: Boolean = when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> true
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> false
            BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED,
            BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED -> {
                when (intent.getIntExtra(BluetoothProfile.EXTRA_STATE, -1)) {
                    BluetoothProfile.STATE_CONNECTED -> true
                    BluetoothProfile.STATE_DISCONNECTED -> false
                    else -> return
                }
            }
            else -> return
        }
        val name = try {
            device.name ?: address
        } catch (e: SecurityException) {
            address
        }

        val app = context.applicationContext
        if (connected) {
            Headphones.onConnected(app, address, name)
        } else {
            val pending = goAsync()
            Headphones.onDisconnected(app, address, name) {
                try {
                    pending.finish()
                } catch (e: Exception) {
                    // schon beendet
                }
            }
        }
    }
}
