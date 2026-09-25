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

    fun apply(ctx: Context) {
        if (!Config.volumeEnabled) return
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        if (Config.savedVolumes.isEmpty()) {
            val saved = JSONObject()
            try {
                saved.put("musicVolume", am.getStreamVolume(AudioManager.STREAM_MUSIC))
                saved.put("ringVolume", am.getStreamVolume(AudioManager.STREAM_RING))
                saved.put("notifVolume", am.getStreamVolume(AudioManager.STREAM_NOTIFICATION))
                saved.put("ringerMode", am.ringerMode)
            } catch (e: Exception) {
                // ignore
            }
            Config.savedVolumes = saved.toString()
        }

        val ringerModeStr = Config.ringerMode
        if (ringerModeStr != "keep") {
            val mode = when (ringerModeStr) {
                "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                "silent" -> AudioManager.RINGER_MODE_SILENT
                else -> AudioManager.RINGER_MODE_NORMAL
            }
            try {
                if (mode == AudioManager.RINGER_MODE_SILENT) {
                    if (nm?.isNotificationPolicyAccessGranted != true) {
                        EventLog.info(ctx, "Lautstärke: Nicht-stören-Zugriff fehlt")
                        return
                    }
                }
                am.ringerMode = mode
            } catch (e: SecurityException) {
                EventLog.info(ctx, "Lautstärke: Ringer-Modus konnte nicht geändert werden")
            }
        }

        val volMusic = Config.volMusic
        if (volMusic >= 0) {
            try {
                am.setStreamVolume(AudioManager.STREAM_MUSIC, volMusic, 0)
            } catch (e: SecurityException) {
                EventLog.info(ctx, "Lautstärke: Medien konnte nicht geändert werden")
            }
        }

        val volRing = Config.volRing
        if (volRing >= 0) {
            try {
                if (volRing == 0) {
                    if (nm?.isNotificationPolicyAccessGranted != true) {
                        EventLog.info(ctx, "Lautstärke: Nicht-stören-Zugriff fehlt für Klingelton 0")
                        return
                    }
                }
                am.setStreamVolume(AudioManager.STREAM_RING, volRing, 0)
            } catch (e: SecurityException) {
                EventLog.info(ctx, "Lautstärke: Klingelton konnte nicht geändert werden")
            }
        }

        val volNotif = Config.volNotification
        if (volNotif >= 0) {
            try {
                if (volNotif == 0) {
                    if (nm?.isNotificationPolicyAccessGranted != true) {
                        EventLog.info(ctx, "Lautstärke: Nicht-stören-Zugriff fehlt für Benachrichtigungen 0")
                        return
                    }
                }
                am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, volNotif, 0)
            } catch (e: SecurityException) {
                EventLog.info(ctx, "Lautstärke: Benachrichtigungen konnte nicht geändert werden")
            }
        }

        EventLog.info(ctx, "Lautstärke-Profil angewendet")
    }

    fun restore(ctx: Context) {
        if (!Config.volumeRestore || Config.savedVolumes.isEmpty()) return
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return

        try {
            val obj = JSONObject(Config.savedVolumes)
            val musicVol = obj.optInt("musicVolume", -1)
            val ringVol = obj.optInt("ringVolume", -1)
            val notifVol = obj.optInt("notifVolume", -1)
            val ringerMode = obj.optInt("ringerMode", AudioManager.RINGER_MODE_NORMAL)

            if (musicVol >= 0) {
                am.setStreamVolume(AudioManager.STREAM_MUSIC, musicVol, 0)
            }
            if (ringVol >= 0) {
                am.setStreamVolume(AudioManager.STREAM_RING, ringVol, 0)
            }
            if (notifVol >= 0) {
                am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, notifVol, 0)
            }
            am.ringerMode = ringerMode

            Config.savedVolumes = ""
            EventLog.info(ctx, "Lautstärke-Profil zurückgesetzt")
        } catch (e: Exception) {
            EventLog.info(ctx, "Lautstärke: Zurücksetzen fehlgeschlagen – ${e.message}")
        }
    }
}
