package com.klaas.nfc_riegel

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager

/**
 * Setzt den Klingelmodus des Telefons, solange eine Ruhe ihn vorgibt.
 *
 * Der vorherige Modus wird beim ersten Setzen gemerkt und am Ende
 * wiederhergestellt — wie [QuietDnd] es mit „Bitte nicht stören" hält. Das
 * Vorhandensein des Schlüssels heißt: Riegel hat den Modus gesetzt.
 *
 * Android verlangt den „Bitte nicht stören"-Zugriff nur, wenn ein Wechsel den
 * Zustand *lautlos* betritt oder verlässt (`AudioService.wouldToggleZenMode`).
 * Vibrieren geht deshalb ohne Sonderrecht; lautlos nicht. Fehlt das Recht und
 * ist lautlos gewünscht, wird vibriert — halbe Ruhe ist besser als keine, und
 * der Profilschirm sagt es an.
 */
class QuietRinger(context: Context) {

    private val app = context.applicationContext

    private val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val notifications =
        app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val prefs = app.getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    /** Der Modus, den das Telefon gerade hat. */
    fun current(): RingerMode = when (audio.ringerMode) {
        AudioManager.RINGER_MODE_SILENT -> RingerMode.LAUTLOS
        AudioManager.RINGER_MODE_VIBRATE -> RingerMode.VIBRIEREN
        else -> RingerMode.LAUT
    }

    /** Setzt den Modus oder stellt bei [RingerMode.UNVERAENDERT] den alten her. */
    fun apply(mode: RingerMode) {
        if (mode == RingerMode.UNVERAENDERT) {
            zuruecksetzen()
            return
        }

        if (!prefs.contains(KEY_VORHER)) {
            prefs.edit().putInt(KEY_VORHER, audio.ringerMode).apply()
        }
        setze(machbar(mode))
    }

    /**
     * Lautlos ohne Recht wird zu Vibrieren. Alles andere bleibt, wie gewünscht —
     * scheitert es trotzdem, fängt [setze] es ab.
     */
    private fun machbar(mode: RingerMode): RingerMode =
        if (mode == RingerMode.LAUTLOS && !notifications.isNotificationPolicyAccessGranted) {
            RingerMode.VIBRIEREN
        } else {
            mode
        }

    private fun zuruecksetzen() {
        if (!prefs.contains(KEY_VORHER)) return
        val vorher = prefs.getInt(KEY_VORHER, AudioManager.RINGER_MODE_NORMAL)
        prefs.edit().remove(KEY_VORHER).apply()
        runCatching { audio.ringerMode = vorher }
    }

    /**
     * `setRingerMode` wirft `SecurityException`, wenn der Wechsel lautlos
     * berührt und der Zugriff fehlt. Ein Fehlschlag darf die übrige Wirkung
     * einer Sperre nicht abbrechen.
     */
    private fun setze(mode: RingerMode) {
        val wert = when (mode) {
            RingerMode.LAUT -> AudioManager.RINGER_MODE_NORMAL
            RingerMode.VIBRIEREN -> AudioManager.RINGER_MODE_VIBRATE
            RingerMode.LAUTLOS -> AudioManager.RINGER_MODE_SILENT
            RingerMode.UNVERAENDERT -> return
        }
        if (audio.ringerMode == wert) return
        runCatching { audio.ringerMode = wert }
    }

    private companion object {
        const val KEY_VORHER = "ringerVorher"
    }
}
