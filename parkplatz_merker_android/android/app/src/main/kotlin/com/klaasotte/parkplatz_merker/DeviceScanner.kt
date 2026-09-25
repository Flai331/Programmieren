package com.klaasotte.parkplatz_merker

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Sucht Bluetooth-Geräte – nur „sehen“, NIE koppeln oder verbinden.
 * Alle Aufrufe und Rückrufe laufen auf dem Main-Thread.
 */
@SuppressLint("MissingPermission")
class DeviceScanner(context: Context) {
    private val ctx: Context = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())

    // Listener und Hit-Callback für App-Launcher
    var listener: ((found: Boolean, ok: Boolean) -> Unit)? = null
    var onHit: (() -> Unit)? = null

    private val adapter: BluetoothAdapter?
        get() = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // ---------- gemeinsame Hilfen ----------

    fun hasScanPermission(): Boolean {
        val perm = if (Build.VERSION.SDK_INT >= 31) Manifest.permission.BLUETOOTH_SCAN else Manifest.permission.ACCESS_FINE_LOCATION
        return ContextCompat.checkSelfPermission(ctx, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    /** Fehlertext, wenn nicht gesucht werden kann, sonst null. */
    private fun problem(): String? {
        if (!hasScanPermission()) return "Berechtigung Bluetooth-Suche fehlt"
        val a = adapter ?: return "Kein Bluetooth vorhanden"
        if (!a.isEnabled) return "Bluetooth ist ausgeschaltet"
        return null
    }

    private fun deviceFrom(intent: Intent): BluetoothDevice? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

    private fun safeName(device: BluetoothDevice): String? {
        if (!hasConnectPermission()) return null
        return try {
            device.name
        } catch (e: SecurityException) {
            null
        }
    }

    private fun cancelDiscoverySafe() {
        try {
            adapter?.cancelDiscovery()
        } catch (e: Exception) {
            // ignorieren
        }
    }

    private fun stopLeScanSafe(scanner: BluetoothLeScanner?, cb: ScanCallback?) {
        if (scanner == null || cb == null) return
        try {
            scanner.stopScan(cb)
        } catch (e: Exception) {
            // ignorieren
        }
    }

    private fun unregisterSafe(r: BroadcastReceiver?) {
        if (r == null) return
        try {
            ctx.unregisterReceiver(r)
        } catch (e: Exception) {
            // ignorieren
        }
    }

    private fun logScan(mode: String, target: String, start: Long, ok: Boolean, found: Boolean, rssi: Int?, error: String?) {
        val obj = JSONObject()
        obj.put("type", "scan")
        obj.put("t", start)
        obj.put("end", System.currentTimeMillis())
        obj.put("mode", mode)
        obj.put("target", target)
        obj.put("ok", ok)
        obj.put("found", found)
        obj.put("rssi", rssi ?: JSONObject.NULL)
        obj.put("error", error ?: JSONObject.NULL)
        EventLog.append(ctx, obj)
    }

    // ---------- Transmitter: eine Suchrunde (klassisch ~12 s + BLE) ----------

    private var roundActive = false
    private var roundTarget = ""
    private var roundStart = 0L
    private var roundFound = false
    private var roundRssi: Int? = null
    private var roundReceiver: BroadcastReceiver? = null
    private var roundLeScanner: BluetoothLeScanner? = null
    private var roundLeCallback: ScanCallback? = null
    private var roundOnDone: (() -> Unit)? = null
    private val roundTimeout = Runnable { finishRound() }

    private fun noteRssi(rssi: Int) {
        val best = roundRssi
        roundRssi = if (best == null || rssi > best) rssi else best
    }

    fun runTransmitterRound(target: String, onDone: () -> Unit) {
        if (roundActive) {
            // Runde läuft schon: nach ihrem Ende zusätzlich [onDone] aufrufen.
            val previous = roundOnDone
            roundOnDone = { previous?.invoke(); onDone() }
            return
        }
        val start = System.currentTimeMillis()
        val err = problem()
        val a = adapter
        if (err != null || a == null) {
            logScan("transmitter", target, start, false, false, null, err ?: "Kein Bluetooth vorhanden")
            listener?.invoke(false, false)
            onDone()
            return
        }
        roundActive = true
        roundTarget = target
        roundStart = start
        roundFound = false
        roundRssi = null
        roundOnDone = onDone

        // Klassische Suche. ACTION_DISCOVERY_FINISHED wird bewusst NICHT genutzt:
        // unser eigenes cancelDiscovery() löst es auch aus. Die Runde endet per Zeit.
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_FOUND) return
                val device = deviceFrom(intent) ?: return
                if (!device.address.equals(roundTarget, ignoreCase = true)) return
                roundFound = true
                onHit?.invoke()
                val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
                if (rssi != Short.MIN_VALUE) noteRssi(rssi.toInt())
            }
        }
        roundReceiver = receiver
        ContextCompat.registerReceiver(ctx, receiver, IntentFilter(BluetoothDevice.ACTION_FOUND), ContextCompat.RECEIVER_EXPORTED)
        var discoveryStarted = false
        try {
            a.cancelDiscovery()
            discoveryStarted = a.startDiscovery()
        } catch (e: Exception) {
            EventLog.info(ctx, "Klassische Suche fehlgeschlagen: ${e.message}")
        }

        // BLE-Suche mit Filter auf genau diese Adresse.
        var leStarted = false
        try {
            val scanner = a.bluetoothLeScanner
            if (scanner != null) {
                val filter = ScanFilter.Builder().setDeviceAddress(target.uppercase()).build()
                val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
                val cb = object : ScanCallback() {
                    override fun onScanResult(callbackType: Int, result: ScanResult) {
                        if (result.device.address.equals(roundTarget, ignoreCase = true)) {
                            roundFound = true
                            onHit?.invoke()
                            noteRssi(result.rssi)
                        }
                    }
                }
                scanner.startScan(listOf(filter), settings, cb)
                roundLeScanner = scanner
                roundLeCallback = cb
                leStarted = true
            }
        } catch (e: Exception) {
            EventLog.info(ctx, "BLE-Suche fehlgeschlagen: ${e.message}")
        }

        if (!discoveryStarted && !leStarted) {
            unregisterSafe(receiver)
            roundReceiver = null
            roundActive = false
            roundOnDone = null
            logScan("transmitter", target, start, false, false, null, "Suche ließ sich nicht starten")
            onDone()
            return
        }
        handler.postDelayed(roundTimeout, 12_000L)
    }

    private fun finishRound() {
        if (!roundActive) return
        roundActive = false
        handler.removeCallbacks(roundTimeout)
        cancelDiscoverySafe()
        stopLeScanSafe(roundLeScanner, roundLeCallback)
        roundLeScanner = null
        roundLeCallback = null
        unregisterSafe(roundReceiver)
        roundReceiver = null
        logScan("transmitter", roundTarget, roundStart, true, roundFound, roundRssi, null)
        listener?.invoke(roundFound, true)
        val done = roundOnDone
        roundOnDone = null
        done?.invoke()
    }

    // ---------- Beacon: dauerhafter, gefilterter BLE-Scan in 2-Min.-Fenstern ----------

    private var beaconTarget: String? = null
    private var beaconScanner: BluetoothLeScanner? = null
    private var beaconCallback: ScanCallback? = null
    private var windowStart = 0L
    private var windowHit = false
    private var windowRssi: Int? = null
    private var beaconError: String? = null

    fun startBeacon(target: String) {
        if (beaconTarget != null) return
        beaconTarget = target
        windowStart = System.currentTimeMillis()
        windowHit = false
        windowRssi = null
        beaconError = problem()
        val a = adapter
        if (beaconError != null || a == null) return
        try {
            val scanner = a.bluetoothLeScanner ?: run {
                beaconError = "BLE-Scanner nicht verfügbar"
                return
            }
            val filter = ScanFilter.Builder().setDeviceAddress(target.uppercase()).build()
            val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build()
            val cb = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    if (result.device.address.equals(beaconTarget, ignoreCase = true)) {
                        windowHit = true
                        onHit?.invoke()
                        val best = windowRssi
                        windowRssi = if (best == null || result.rssi > best) result.rssi else best
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    beaconError = "BLE-Scan-Fehler $errorCode"
                }
            }
            scanner.startScan(listOf(filter), settings, cb)
            beaconScanner = scanner
            beaconCallback = cb
        } catch (e: Exception) {
            beaconError = "BLE-Scan fehlgeschlagen: ${e.message}"
        }
    }

    /** Aktuelles Fenster als `scan`-Ereignis abschließen und neues beginnen. */
    fun closeBeaconWindow() {
        val target = beaconTarget ?: return
        val err = beaconError
        logScan("beacon", target, windowStart, err == null, windowHit, windowRssi, err)
        listener?.invoke(windowHit, err == null)
        windowStart = System.currentTimeMillis()
        windowHit = false
        windowRssi = null
    }

    fun stopBeacon() {
        stopLeScanSafe(beaconScanner, beaconCallback)
        beaconScanner = null
        beaconCallback = null
        beaconTarget = null
    }

    // ---------- Einrichtung: alle Geräte in der Nähe (15 s) ----------

    class DeviceInfo(val address: String) {
        var name: String? = null
        var rssi: Int = -127
        var classic = false
        var ble = false
    }

    private val searchResults = LinkedHashMap<String, DeviceInfo>()
    private var searchRunning = false
    private var searchReceiver: BroadcastReceiver? = null
    private var searchLeScanner: BluetoothLeScanner? = null
    private var searchLeCallback: ScanCallback? = null
    private val searchTimeout = Runnable { stopSearch() }

    private fun remember(address: String, name: String?, rssi: Int?, classic: Boolean) {
        val info = searchResults.getOrPut(address.uppercase()) { DeviceInfo(address.uppercase()) }
        if (!name.isNullOrBlank()) info.name = name
        if (rssi != null && rssi > info.rssi) info.rssi = rssi
        if (classic) info.classic = true else info.ble = true
    }

    /** Startet die Suche. Rückgabe: Fehlertext oder null. */
    fun startSearch(): String? {
        stopSearch()
        searchResults.clear()
        val err = problem()
        val a = adapter
        if (err != null || a == null) return err ?: "Kein Bluetooth vorhanden"

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_FOUND) return
                val device = deviceFrom(intent) ?: return
                val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
                val name = intent.getStringExtra(BluetoothDevice.EXTRA_NAME) ?: safeName(device)
                remember(device.address, name, if (rssi == Short.MIN_VALUE) null else rssi.toInt(), true)
            }
        }
        searchReceiver = receiver
        ContextCompat.registerReceiver(ctx, receiver, IntentFilter(BluetoothDevice.ACTION_FOUND), ContextCompat.RECEIVER_EXPORTED)
        var anyStarted = false
        try {
            a.cancelDiscovery()
            anyStarted = a.startDiscovery()
        } catch (e: Exception) {
            EventLog.info(ctx, "Einrichtungssuche klassisch fehlgeschlagen: ${e.message}")
        }
        try {
            val scanner = a.bluetoothLeScanner
            if (scanner != null) {
                val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
                val cb = object : ScanCallback() {
                    override fun onScanResult(callbackType: Int, result: ScanResult) {
                        val name = result.scanRecord?.deviceName ?: safeName(result.device)
                        remember(result.device.address, name, result.rssi, false)
                    }
                }
                scanner.startScan(null, settings, cb)
                searchLeScanner = scanner
                searchLeCallback = cb
                anyStarted = true
            }
        } catch (e: Exception) {
            EventLog.info(ctx, "Einrichtungssuche BLE fehlgeschlagen: ${e.message}")
        }
        if (!anyStarted) {
            stopSearch()
            return "Suche ließ sich nicht starten"
        }
        searchRunning = true
        handler.postDelayed(searchTimeout, 15_000L)
        return null
    }

    fun searchRunning(): Boolean = searchRunning

    fun results(): List<Map<String, Any?>> = searchResults.values.map {
        mapOf(
            "address" to it.address,
            "name" to it.name,
            "rssi" to it.rssi,
            "classic" to it.classic,
            "ble" to it.ble,
        )
    }

    fun stopSearch() {
        handler.removeCallbacks(searchTimeout)
        searchRunning = false
        unregisterSafe(searchReceiver)
        searchReceiver = null
        cancelDiscoverySafe()
        stopLeScanSafe(searchLeScanner, searchLeCallback)
        searchLeScanner = null
        searchLeCallback = null
    }

    /** Alles beenden, ohne Ereignisse zu schreiben. */
    fun stopAll() {
        if (roundActive) {
            roundActive = false
            handler.removeCallbacks(roundTimeout)
            cancelDiscoverySafe()
            stopLeScanSafe(roundLeScanner, roundLeCallback)
            roundLeScanner = null
            roundLeCallback = null
            unregisterSafe(roundReceiver)
            roundReceiver = null
            roundOnDone = null
        }
        stopBeacon()
        stopSearch()
    }
}
