package com.klaasotte.parkplatz_merker

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import org.json.JSONObject

object VolumeProfile {
    fun info(ctx: Context): Map<String, Any> {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        val musicMax = am?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 0
        val musicNow = am?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
        val ringMax = am?.getStreamMaxVolume(AudioManager.STREAM_RING) ?: 0
        val ringNow = am?.getStreamVolume(AudioManager.STREAM_RING) ?: 0
        val notifMax = am?.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION) ?: 0
        val notifNow = am?.getStreamVolume(AudioManager.STREAM_NOTIFICATION) ?: 0
        val ringerMode = when (am?.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }
        val dndAccess = nm?.isNotificationPolicyAccessGranted ?: false

        return mapOf(
            "musicMax" to musicMax,
            "musicNow" to musicNow,
            "ringMax" to ringMax,
            "ringNow" to ringNow,
            "notificationMax" to notifMax,
            "notificationNow" to notifNow,
            "ringerMode" to ringerMode,
            "dndAccess" to dndAccess
        )
    }

    private fun dndGranted(ctx: Context): Boolean =
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
            ?.isNotificationPolicyAccessGranted == true

    /** Setzt eine Lautstärke; Fehler werden nur protokolliert (die übrigen Schritte laufen weiter). */
    private fun setVolume(ctx: Context, am: AudioManager, stream: Int, value: Int, name: String) {
        if (value < 0) return
        if (value == 0 && stream != AudioManager.STREAM_MUSIC && !dndGranted(ctx)) {
            EventLog.info(ctx, "Lautstärke: $name auf 0 braucht Nicht-stören-Zugriff – übersprungen")
            return
        }
        try {
            am.setStreamVolume(stream, value.coerceAtMost(am.getStreamMaxVolume(stream)), 0)
        } catch (e: Exception) {
            EventLog.info(ctx, "Lautstärke: $name nicht änderbar (${e.message})")
        }
    }

    private fun setRinger(ctx: Context, am: AudioManager, mode: Int) {
        if (mode == AudioManager.RINGER_MODE_SILENT && !dndGranted(ctx)) {
            EventLog.info(ctx, "Lautstärke: Lautlos braucht Nicht-stören-Zugriff – übersprungen")
            return
        }
        try {
            am.ringerMode = mode
        } catch (e: Exception) {
            EventLog.info(ctx, "Lautstärke: Klingelmodus nicht änderbar (${e.message})")
        }
    }

    fun apply(ctx: Context) {
        if (!Config.volumeEnabled) return
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return

        // Vorherige Werte nur einmal merken (nicht bei wiederholtem Anwenden überschreiben).
        if (Config.savedVolumes.isEmpty()) {
            try {
                val saved = JSONObject()
                saved.put("musicVolume", am.getStreamVolume(AudioManager.STREAM_MUSIC))
                saved.put("ringVolume", am.getStreamVolume(AudioManager.STREAM_RING))
                saved.put("notifVolume", am.getStreamVolume(AudioManager.STREAM_NOTIFICATION))
                saved.put("ringerMode", am.ringerMode)
                Config.savedVolumes = saved.toString()
            } catch (e: Exception) {
                EventLog.info(ctx, "Lautstärke: Merken fehlgeschlagen (${e.message})")
            }
        }

        // Erst Lautstärken, zuletzt den Klingelmodus – eine Klingelton-Lautstärke > 0
        // würde „Vibration/Lautlos“ sonst wieder auf „Normal“ stellen.
        setVolume(ctx, am, AudioManager.STREAM_MUSIC, Config.volMusic, "Medien")
        setVolume(ctx, am, AudioManager.STREAM_RING, Config.volRing, "Klingelton")
        setVolume(ctx, am, AudioManager.STREAM_NOTIFICATION, Config.volNotification, "Benachrichtigungen")
        when (Config.ringerMode) {
            "normal" -> setRinger(ctx, am, AudioManager.RINGER_MODE_NORMAL)
            "vibrate" -> setRinger(ctx, am, AudioManager.RINGER_MODE_VIBRATE)
            "silent" -> setRinger(ctx, am, AudioManager.RINGER_MODE_SILENT)
        }
        EventLog.info(ctx, "Lautstärke-Profil angewendet")
    }

    fun restore(ctx: Context) {
        val savedJson = Config.savedVolumes
        if (savedJson.isEmpty()) return
        Config.savedVolumes = ""
        if (!Config.volumeRestore) return
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            val obj = JSONObject(savedJson)
            // Zuerst in „Normal“ wechseln, damit die Klingelton-Lautstärke gesetzt werden kann …
            setRinger(ctx, am, AudioManager.RINGER_MODE_NORMAL)
            setVolume(ctx, am, AudioManager.STREAM_MUSIC, obj.optInt("musicVolume", -1), "Medien")
            setVolume(ctx, am, AudioManager.STREAM_RING, obj.optInt("ringVolume", -1), "Klingelton")
            setVolume(ctx, am, AudioManager.STREAM_NOTIFICATION, obj.optInt("notifVolume", -1), "Benachrichtigungen")
            // … und den alten Klingelmodus zuletzt.
            setRinger(ctx, am, obj.optInt("ringerMode", AudioManager.RINGER_MODE_NORMAL))
            EventLog.info(ctx, "Lautstärke-Profil zurückgesetzt")
        } catch (e: Exception) {
            EventLog.info(ctx, "Lautstärke: Zurücksetzen fehlgeschlagen – ${e.message}")
        }
    }
}
