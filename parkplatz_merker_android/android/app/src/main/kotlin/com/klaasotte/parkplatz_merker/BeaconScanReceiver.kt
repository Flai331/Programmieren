package com.klaasotte.parkplatz_merker

import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

class BeaconScanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val results = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(
                "android.bluetooth.le.extra.LIST_SCAN_RESULT",
                ScanResult::class.java
            ) ?: emptyList()
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra("android.bluetooth.le.extra.LIST_SCAN_RESULT") ?: emptyList()
        }

        for (result in results) {
            if (result.device?.address?.equals(Config.deviceAddress, ignoreCase = true) == true) {
                val now = System.currentTimeMillis()
                val lastLog = Config.lastBeaconBgLog
                if (now - lastLog >= 60_000) {
                    Config.lastBeaconBgLog = now
                    val obj = JSONObject()
                    obj.put("type", "beacon_bg")
                    obj.put("t", now)
                    obj.put("target", Config.deviceAddress)
                    obj.put("rssi", result.rssi)
                    EventLog.append(context, obj)
                }
            }
        }
    }
}
