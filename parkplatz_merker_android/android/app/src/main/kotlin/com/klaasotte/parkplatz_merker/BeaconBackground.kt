package com.klaasotte.parkplatz_merker

import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.os.Build

object BeaconBackground {
    fun start(ctx: Context) {
        if (Config.deviceMode != "beacon") return
        if (Config.deviceAddress.isNullOrEmpty()) return

        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter ?: return
        if (!adapter.isEnabled) return

        val scanner = adapter.bluetoothLeScanner ?: return
        val filter = ScanFilter.Builder()
            .setDeviceAddress(Config.deviceAddress)
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
            .build()

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
            @Suppress("MissingPermission")
            scanner.startScan(listOf(filter), settings, pi)
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
            @Suppress("MissingPermission")
            scanner.stopScan(pi)
        } catch (e: Exception) {
            EventLog.info(ctx, "BeaconBackground stop Fehler: ${e.message}")
        }
    }
}
