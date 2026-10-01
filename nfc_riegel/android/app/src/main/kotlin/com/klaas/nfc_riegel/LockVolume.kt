package com.klaas.nfc_riegel

import android.content.Context
import android.media.AudioManager
import android.os.Build

/**
 * Setzt die Lautstärken, die [VolumePlanner] vorgibt, und stellt die alten
 * wieder her, sobald keine Sperre sie mehr verlangt — wie [QuietRinger] es mit
 * dem Klingelmodus hält. Gemerkt wird je Strom beim ersten Setzen; das
 * Vorhandensein des Schlüssels heißt: Riegel hat diesen Strom verändert.
 *
 * Klingelton und Benachrichtigungen hängen am Klingelmodus: Android schaltet
 * bei Stufe null auf Vibrieren und bei jeder anderen zurück auf Laut. Darum
 * fasst Riegel beide nur an, solange das Telefon auf Laut steht, und senkt sie
 * nie unter Stufe eins. Ganz still ist Sache des Klingelmodus unter „Ruhe".
 */
class LockVolume(context: Context) {

    private val app = context.applicationContext

    private val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val prefs = app.getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    /** Die Stufe je Strom in Prozent, wie das Telefon sie gerade hat. */
    fun current(): Map<VolumeStream, Int> = VolumeStream.entries.associateWith { s ->
        val max = audio.getStreamMaxVolume(stream(s)).coerceAtLeast(1)
        audio.getStreamVolume(stream(s)) * 100 / max
    }

    fun apply(targets: Map<VolumeStream, Int>) {
        for (s in VolumeStream.entries) {
            val prozent = targets[s]
            if (prozent == null) zuruecksetzen(s) else setze(s, prozent)
        }
    }

    private fun setze(s: VolumeStream, prozent: Int) {
        if (haengtAmKlingelmodus(s) && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return

        val stream = stream(s)
        val ziel = VolumePlanner.stufe(prozent, audio.getStreamMaxVolume(stream), untergrenze(s))
        val vorher = audio.getStreamVolume(stream)
        if (vorher == ziel) return

        // Ein Fehlschlag darf die übrige Wirkung der Sperre nicht abbrechen.
        runCatching { audio.setStreamVolume(stream, ziel, 0) }.onSuccess {
            val key = key(s)
            if (!prefs.contains(key)) prefs.edit().putInt(key, vorher).apply()
        }
    }

    /**
     * Erst schreiben, dann vergessen. Steht das Telefon inzwischen nicht mehr auf
     * Laut, hat jemand es bewusst leise gestellt — der Klingelton zurück auf die
     * alte Stufe schaltete es wieder laut. Dann wird nur vergessen.
     */
    private fun zuruecksetzen(s: VolumeStream) {
        val key = key(s)
        if (!prefs.contains(key)) return
        if (haengtAmKlingelmodus(s) && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
            prefs.edit().remove(key).apply()
            return
        }
        val vorher = prefs.getInt(key, 0)
        runCatching { audio.setStreamVolume(stream(s), vorher, 0) }
            .onSuccess { prefs.edit().remove(key).apply() }
    }

    private fun untergrenze(s: VolumeStream): Int {
        val systemMin = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            audio.getStreamMinVolume(stream(s))
        } else {
            0
        }
        return if (haengtAmKlingelmodus(s)) maxOf(systemMin, 1) else systemMin
    }

    private fun haengtAmKlingelmodus(s: VolumeStream) =
        s == VolumeStream.KLINGELTON || s == VolumeStream.BENACHRICHTIGUNG

    private fun stream(s: VolumeStream): Int = when (s) {
        VolumeStream.MEDIEN -> AudioManager.STREAM_MUSIC
        VolumeStream.KLINGELTON -> AudioManager.STREAM_RING
        VolumeStream.BENACHRICHTIGUNG -> AudioManager.STREAM_NOTIFICATION
        VolumeStream.WECKER -> AudioManager.STREAM_ALARM
    }

    private fun key(s: VolumeStream) = "lautstaerkeVorher_${s.name}"
}
