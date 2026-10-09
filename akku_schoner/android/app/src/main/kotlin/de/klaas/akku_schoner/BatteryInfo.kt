package de.klaas.akku_schoner

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager

object BatteryInfo {

    /** Letzter Akku-Stand (Sticky-Broadcast, kostet keinen Strom). */
    fun sticky(ctx: Context): Intent? =
        ctx.applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

    fun level(intent: Intent?): Int {
        if (intent == null) return -1
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        if (level < 0 || scale <= 0) return -1
        return level * 100 / scale
    }

    /** Temperatur in °C (Android liefert Zehntelgrad). */
    fun temp(intent: Intent?): Double =
        (intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0

    fun isCharging(intent: Intent?): Boolean {
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        return status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
    }

    fun read(ctx: Context): Map<String, Any?> {
        val i = sticky(ctx)
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as? PowerManager

        val health = when (i?.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "overvoltage"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
            BatteryManager.BATTERY_HEALTH_COLD -> "cold"
            else -> "unknown"
        }
        val plug = when (i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)) {
            BatteryManager.BATTERY_PLUGGED_AC -> "Netzteil"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Kabellos"
            else -> ""
        }

        // Strom in Mikroampere; manche Hersteller liefern Milliampere oder 0/MIN_VALUE.
        val currentNow = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            ?.takeIf { it != Int.MIN_VALUE && it != 0 }
        val chargeCounter = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            ?.takeIf { it != Int.MIN_VALUE && it > 0 }

        var cycles: Int? = null
        if (Build.VERSION.SDK_INT >= 34) {
            cycles = i?.getIntExtra(BatteryManager.EXTRA_CYCLE_COUNT, -1)?.takeIf { it >= 0 }
        }

        return mapOf(
            "level" to level(i),
            "charging" to isCharging(i),
            "plug" to plug,
            "temp" to temp(i),
            "voltage" to (i?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0),
            "health" to health,
            "technology" to (i?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY) ?: ""),
            "currentNow" to currentNow,
            "chargeCounter" to chargeCounter,
            "cycles" to cycles,
            "powerSave" to (pm?.isPowerSaveMode ?: false),
        )
    }
}
