package de.klaas.akku_schoner

import android.bluetooth.BluetoothManager
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.nfc.NfcAdapter
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Sparprofil: setzt Stromspar-Einstellungen selbst um.
 *  - direkt (Erlaubnis "Systemeinstellungen ändern"): Bildschirm-Timeout, Auto-Helligkeit, Vibration bei Berührung
 *  - direkt (normale Berechtigung): automatische Konten-Synchronisierung
 *  - über die Bedienungshilfe (Seite öffnen, Hauptschalter drücken): Energiesparmodus, Bluetooth, NFC, Standort
 * Vor dem Anwenden werden die alten Werte gesichert, restore() stellt sie wieder her.
 */
object SaverProfile {
    const val SAVER = "saver"
    const val TIMEOUT = "timeout"
    const val BRIGHTNESS = "brightness"
    const val HAPTIC = "haptic"
    const val SYNC = "sync"
    const val BLUETOOTH = "bluetooth"
    const val NFC = "nfc"
    const val LOCATION = "location"

    val ALL = listOf(SAVER, TIMEOUT, BRIGHTNESS, HAPTIC, SYNC, BLUETOOTH, NFC, LOCATION)
    /** Standard: was niemandem wehtut. Bluetooth (Kopfhörer!), Standort und Sync nur auf Wunsch. */
    val DEFAULT = listOf(SAVER, TIMEOUT, BRIGHTNESS, HAPTIC, NFC)
    /** Diese Schalter kann nur die Bedienungshilfe umlegen. */
    val TOGGLES = setOf(SAVER, BLUETOOTH, NFC, LOCATION)

    const val SAVE_TIMEOUT_MS = 30_000

    fun canWrite(ctx: Context): Boolean = Settings.System.canWrite(ctx)

    // ---------- aktueller Zustand ----------

    fun saverOn(ctx: Context): Boolean =
        (ctx.getSystemService(Context.POWER_SERVICE) as PowerManager).isPowerSaveMode

    fun bluetoothOn(ctx: Context): Boolean? = try {
        (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.isEnabled
    } catch (_: Exception) {
        null
    }

    fun nfcOn(ctx: Context): Boolean? = try {
        NfcAdapter.getDefaultAdapter(ctx)?.isEnabled
    } catch (_: Exception) {
        null
    }

    fun locationOn(ctx: Context): Boolean {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
        else @Suppress("DEPRECATION") Settings.Secure.getInt(
            ctx.contentResolver, Settings.Secure.LOCATION_MODE, 0
        ) != 0
    }

    private fun sysInt(ctx: Context, key: String, def: Int) =
        try { Settings.System.getInt(ctx.contentResolver, key) } catch (_: Exception) { def }

    /** Ist-Zustand je Punkt: Boolean (an/aus), Zahl (Timeout) oder null (gibt es nicht). */
    fun state(ctx: Context): Map<String, Any?> = mapOf(
        SAVER to saverOn(ctx),
        TIMEOUT to sysInt(ctx, Settings.System.SCREEN_OFF_TIMEOUT, 0),
        BRIGHTNESS to (sysInt(ctx, Settings.System.SCREEN_BRIGHTNESS_MODE, 0) ==
            Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC),
        HAPTIC to (sysInt(ctx, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0),
        SYNC to ContentResolver.getMasterSyncAutomatically(),
        BLUETOOTH to bluetoothOn(ctx),
        NFC to nfcOn(ctx),
        LOCATION to locationOn(ctx),
    )

    /** Ist der Punkt schon im Sparzustand? */
    fun isSaving(ctx: Context, id: String): Boolean = when (id) {
        SAVER -> saverOn(ctx)
        TIMEOUT -> sysInt(ctx, Settings.System.SCREEN_OFF_TIMEOUT, Int.MAX_VALUE) <= SAVE_TIMEOUT_MS
        BRIGHTNESS -> sysInt(ctx, Settings.System.SCREEN_BRIGHTNESS_MODE, 0) ==
            Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
        HAPTIC -> sysInt(ctx, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 0
        SYNC -> !ContentResolver.getMasterSyncAutomatically()
        BLUETOOTH -> bluetoothOn(ctx) != true
        NFC -> nfcOn(ctx) != true
        LOCATION -> !locationOn(ctx)
        else -> true
    }

    /** Für die Bedienungshilfe: soll der Schalter danach an sein, und wie prüft man das? */
    fun toggleTarget(id: String, saving: Boolean): Boolean = when (id) {
        SAVER -> saving            // Energiesparmodus AN = sparen
        else -> !saving            // Bluetooth/NFC/Standort AUS = sparen
    }

    fun toggleIntent(id: String): Intent = when (id) {
        SAVER -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        BLUETOOTH -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        NFC -> Intent(Settings.ACTION_NFC_SETTINGS)
        else -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
    }

    fun toggleIsOn(ctx: Context, id: String): Boolean? = when (id) {
        SAVER -> saverOn(ctx)
        BLUETOOTH -> bluetoothOn(ctx)
        NFC -> nfcOn(ctx)
        LOCATION -> locationOn(ctx)
        else -> null
    }

    // ---------- anwenden / zurücksetzen ----------

    private fun setSys(ctx: Context, key: String, value: Int): Boolean = try {
        Settings.System.putInt(ctx.contentResolver, key, value)
    } catch (_: Exception) {
        false
    }

    /** Direkte Punkte setzen. saving=false = alte Werte aus der Sicherung. Ergebnis je Punkt. */
    private fun applyDirect(ctx: Context, ids: List<String>, saving: Boolean): Map<String, String> {
        val out = mutableMapOf<String, String>()
        val backup = Prefs.profileBackup(ctx)
        val write = canWrite(ctx)
        for (id in ids) {
            if (id in TOGGLES) continue
            if (id != SYNC && !write) {
                out[id] = "Erlaubnis „Systemeinstellungen ändern“ fehlt"
                continue
            }
            val ok = when (id) {
                TIMEOUT -> setSys(ctx, Settings.System.SCREEN_OFF_TIMEOUT,
                    if (saving) SAVE_TIMEOUT_MS else backup[id] ?: 60_000)
                BRIGHTNESS -> setSys(ctx, Settings.System.SCREEN_BRIGHTNESS_MODE,
                    if (saving) Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
                    else backup[id] ?: Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC)
                HAPTIC -> setSys(ctx, Settings.System.HAPTIC_FEEDBACK_ENABLED,
                    if (saving) 0 else backup[id] ?: 1)
                SYNC -> try {
                    ContentResolver.setMasterSyncAutomatically(if (saving) false else (backup[id] ?: 1) != 0)
                    true
                } catch (_: Exception) {
                    false
                }
                else -> false
            }
            out[id] = if (ok) "erledigt" else "nicht erlaubt"
        }
        return out
    }

    /** Alte Werte sichern – nur wenn noch keine Sicherung da ist (sonst überschreibt Sparen das Original). */
    private fun backup(ctx: Context, ids: List<String>) {
        val b = Prefs.profileBackup(ctx).toMutableMap()
        for (id in ids) {
            if (b.containsKey(id)) continue
            val v: Int? = when (id) {
                TIMEOUT -> sysInt(ctx, Settings.System.SCREEN_OFF_TIMEOUT, 60_000)
                BRIGHTNESS -> sysInt(ctx, Settings.System.SCREEN_BRIGHTNESS_MODE, 0)
                HAPTIC -> sysInt(ctx, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
                SYNC -> if (ContentResolver.getMasterSyncAutomatically()) 1 else 0
                else -> toggleIsOn(ctx, id)?.let { if (it) 1 else 0 }
            }
            if (v != null) b[id] = v
        }
        Prefs.setProfileBackup(ctx, b)
    }

    /**
     * Profil anwenden. Direkte Punkte sofort, Schalter über die Bedienungshilfe.
     * runToggles=false: Schalter später (z. B. erst beim Entsperren).
     */
    fun apply(ctx: Context, ids: List<String>, runToggles: Boolean = true, returnToApp: Boolean = true): Map<String, Any> {
        backup(ctx, ids)
        val direct = applyDirect(ctx, ids, saving = true)
        val toggles = ids.filter { it in TOGGLES && toggleIsOn(ctx, it) != null && !isSaving(ctx, it) }
        val started = if (runToggles && toggles.isNotEmpty())
            ForceStopService.requestToggles(ctx, toggles.map { it to toggleTarget(it, true) }, returnToApp)
        else false
        return mapOf("direct" to direct, "toggles" to toggles, "started" to started)
    }

    /** Gesicherte Werte wiederherstellen und Sicherung löschen. */
    fun restore(ctx: Context): Map<String, Any> {
        val backup = Prefs.profileBackup(ctx)
        val ids = backup.keys.toList()
        val direct = applyDirect(ctx, ids, saving = false)
        val toggles = ids.filter { it in TOGGLES && toggleIsOn(ctx, it) != null }
            .map { it to ((backup[it] ?: 0) != 0) }
            .filter { (id, want) -> toggleIsOn(ctx, id) != want }
        val started = if (toggles.isNotEmpty()) ForceStopService.requestToggles(ctx, toggles, true) else false
        // Ohne Bedienungshilfe die Schalter-Werte behalten, damit ein späteres Zurücksetzen sie noch kennt.
        Prefs.setProfileBackup(ctx, if (started || toggles.isEmpty()) emptyMap()
            else backup.filterKeys { k -> toggles.any { it.first == k } })
        return mapOf("direct" to direct, "toggles" to toggles.map { it.first }, "started" to started)
    }
}
