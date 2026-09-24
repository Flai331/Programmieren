package com.klaasotte.parkplatz_merker

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import org.json.JSONObject
import kotlin.math.max

class DeviceScanner(val ctx: Context) {
    private val adapter: BluetoothAdapter?
        get() = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    data class DeviceInfo(
        val address: String,
        val name: String? = null,
        var rssi: Int = Int.MIN_VALUE,
        var classic: Boolean = false,
        var ble: Boolean = false
    )

    private val searchResults = LinkedHashMap<String, DeviceInfo>()
    private var searchRunning = false
    private var discoveryReceiver: BroadcastReceiver? = null
    private var searchScanCallback: ScanCallback? = null

    fun hasScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= 31) {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    fun runTransmitterRound(target: String, onDone: () -> Unit) {
        if (!hasScanPermission()) {
            logScan(target, ok = false, error = "Berechtigung fehlt")
            onDone()
            return
        }

        val adapter = adapter
        if (adapter == null) {
            logScan(target, ok = false, error = "Bluetooth nicht verfügbar")
            onDone()
            return
        }

        if (!adapter.isEnabled) {
            logScan(target, ok = false, error = "Bluetooth ausgeschaltet")
            onDone()
            return
        }

        var bestRssi: Int? = null
        var found = false
        var roundError: String? = null
        var scanFinished = false

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device?.address?.equals(target, ignoreCase = true) == true) {
                            found = true
                            val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
                            if (rssi != Int.MIN_VALUE) {
                                bestRssi = if (bestRssi == null) rssi else max(bestRssi!!, rssi)
                            }
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        finishRound()
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        try {
            ContextCompat.registerReceiver(ctx, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        } catch (e: Exception) {
            roundError = "Receiver Fehler: ${e.message}"
            logScan(target, ok = false, error = roundError!!)
            onDone()
            return
        }

        try {
            @Suppress("MissingPermission")
            adapter.cancelDiscovery()
            @Suppress("MissingPermission")
            adapter.startDiscovery()
        } catch (e: SecurityException) {
            roundError = "Discovery Fehler"
        }

        // BLE scan parallel
        val scanner = adapter.bluetoothLeScanner
        val filter = ScanFilter.Builder()
            .setDeviceAddress(target)
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
            .build()

        val bleScanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                if (result != null && result.device?.address?.equals(target, ignoreCase = true) == true) {
                    found = true
                    val rssi = result.rssi
                    bestRssi = if (bestRssi == null) rssi else max(bestRssi!!, rssi)
                }
            }
        }

        try {
            @Suppress("MissingPermission")
            scanner?.startScan(listOf(filter), settings, bleScanCallback)
        } catch (e: SecurityException) {
            // ignore
        } catch (e: Exception) {
            // ignore
        }

        val h = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            finishRound()
        }
        h.postDelayed(timeoutRunnable, 12_000L)

        fun finishRound() {
            if (scanFinished) return
            scanFinished = true
            h.removeCallbacks(timeoutRunnable)
            try {
                @Suppress("MissingPermission")
                adapter.cancelDiscovery()
            } catch (e: Exception) {
                // ignore
            }
            try {
                @Suppress("MissingPermission")
                scanner?.stopScan(bleScanCallback)
            } catch (e: Exception) {
                // ignore
            }
            try {
                ctx.unregisterReceiver(receiver)
            } catch (e: Exception) {
                // ignore
            }

            logScan(target, ok = true, found = found, rssi = bestRssi)
            onDone()
        }
    }

    fun startSearch() {
        if (searchRunning) return
        if (!hasScanPermission()) return

        searchRunning = true
        searchResults.clear()

        val adapter = adapter ?: return
        if (!adapter.isEnabled) {
            searchRunning = false
            return
        }

        // Discovery receiver
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device != null) {
                            val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
                            val name = intent.getStringExtra(BluetoothDevice.EXTRA_NAME)
                            val info = searchResults.getOrPut(device.address) {
                                DeviceInfo(device.address, name)
                            }
                            info.rssi = if (rssi != Int.MIN_VALUE) max(info.rssi, rssi) else info.rssi
                            info.classic = true
                            if (name != null) info.name = name
                        }
                    }
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
        try {
            ContextCompat.registerReceiver(ctx, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        } catch (e: Exception) {
            searchRunning = false
            return
        }

        discoveryReceiver = receiver

        try {
            @Suppress("MissingPermission")
            adapter.cancelDiscovery()
            @Suppress("MissingPermission")
            adapter.startDiscovery()
        } catch (e: SecurityException) {
            // ignore
        }

        // BLE unfiltered scan
        val scanner = adapter.bluetoothLeScanner
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val bleScanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                if (result != null) {
                    val device = result.device
                    val rssi = result.rssi
                    val name = result.scanRecord?.deviceName
                    val info = searchResults.getOrPut(device.address) {
                        DeviceInfo(device.address, name)
                    }
                    info.rssi = if (rssi != Int.MIN_VALUE) max(info.rssi, rssi) else info.rssi
                    info.ble = true
                    if (name != null) info.name = name
                }
            }
        }

        searchScanCallback = bleScanCallback

        try {
            @Suppress("MissingPermission")
            scanner?.startScan(emptyList(), settings, bleScanCallback)
        } catch (e: Exception) {
            // ignore
        }

        val h = Handler(Looper.getMainLooper())
        h.postDelayed({
            stopSearch()
        }, 15_000L)
    }

    fun results(): Pair<Boolean, List<Map<String, Any?>>> {
        val list = searchResults.values.map {
            mapOf(
                "address" to it.address,
                "name" to it.name,
                "rssi" to it.rssi,
                "classic" to it.classic,
                "ble" to it.ble
            )
        }
        return searchRunning to list
    }

    fun stopSearch() {
        searchRunning = false
        try {
            if (discoveryReceiver != null) {
                ctx.unregisterReceiver(discoveryReceiver)
                discoveryReceiver = null
            }
        } catch (e: Exception) {
            // ignore
        }

        val adapter = adapter ?: return
        try {
            @Suppress("MissingPermission")
            adapter.cancelDiscovery()
        } catch (e: Exception) {
            // ignore
        }

        val scanner = adapter.bluetoothLeScanner
        if (searchScanCallback != null) {
            try {
                @Suppress("MissingPermission")
                scanner?.stopScan(searchScanCallback)
            } catch (e: Exception) {
                // ignore
            }
            searchScanCallback = null
        }
    }

    private fun logScan(target: String, ok: Boolean, found: Boolean = false, rssi: Int? = null, error: String? = null) {
        val obj = JSONObject()
        obj.put("type", "scan")
        obj.put("t", System.currentTimeMillis())
        obj.put("mode", "transmitter")
        obj.put("target", target)
        obj.put("end", System.currentTimeMillis())
        obj.put("ok", ok)
        obj.put("found", found)
        if (rssi != null && rssi != Int.MIN_VALUE) obj.put("rssi", rssi)
        if (error != null) obj.put("error", error)
        EventLog.append(ctx, obj)
    }
}
