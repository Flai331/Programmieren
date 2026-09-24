package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.os.Build

@SuppressLint("MissingPermission")
object BeaconBackground {
    fun start(ctx: Context) {
        if (Config.deviceMode != "beacon") return
        if (Config.deviceAddress.isNullOrEmpty()) return

        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter ?: return
        if (!adapter.isEnabled) return

        val scanner = adapter.bluetoothLeScanner ?: return

        val flags = if (Build.VERSION.SDK_INT >= 31) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pi = PendingIntent.getBroadcast(
            ctx,
            2,
            Intent(ctx, BeaconScanReceiver::class.java),
            flags
        )

        try {
            val filter = ScanFilter.Builder()
                .setDeviceAddress(Config.deviceAddress?.uppercase())
                .build()
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                .build()
            val code = scanner.startScan(listOf(filter), settings, pi)
            if (code != 0) EventLog.info(ctx, "Hintergrund-Beacon-Scan Fehlercode $code")
        } catch (e: Exception) {
            EventLog.info(ctx, "BeaconBackground start Fehler: ${e.message}")
        }
    }

    fun stop(ctx: Context) {
        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter ?: return
        val scanner = adapter.bluetoothLeScanner ?: return

        val flags = if (Build.VERSION.SDK_INT >= 31) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pi = PendingIntent.getBroadcast(
            ctx,
            2,
            Intent(ctx, BeaconScanReceiver::class.java),
            flags
        )

        try {
            scanner.stopScan(pi)
        } catch (e: Exception) {
            EventLog.info(ctx, "BeaconBackground stop Fehler: ${e.message}")
        }
    }
}
