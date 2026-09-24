package com.klaasotte.spotify_merker

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.util.Log
import org.json.JSONObject

const val SPOTIFY_PACKAGE = "com.spotify.music"
private const val TAG = "MediaListenerService"
private const val TICK_MS = 20_000L

/** Momentaufnahme dessen, was Spotify gerade meldet. */
data class Snapshot(
    val title: String,
    val artist: String,
    val album: String,
    val durationMs: Long,
    val positionMs: Long,
    val state: String,
    val mediaId: String,
    val mediaUri: String,
    val artUri: String,
    val actions: Long,
    val spotifyUri: String,
    val contextUri: String = "",
    val contextTitle: String = "",
) {
    fun toMap(): Map<String, Any> = mapOf(
        "title" to title,
        "artist" to artist,
        "album" to album,
        "durationMs" to durationMs,
        "positionMs" to positionMs,
        "state" to state,
        "mediaId" to mediaId,
        "mediaUri" to mediaUri,
        "artUri" to artUri,
        "actions" to actions,
        "spotifyUri" to spotifyUri,
        "contextUri" to contextUri,
        "contextTitle" to contextTitle,
    )

    fun toEvent(reason: String, ts: Long): JSONObject = JSONObject(toMap()).apply {
        put("ts", ts)
        put("reason", reason)
    }

    fun sameItem(other: Snapshot?): Boolean =
        other != null && title == other.title && artist == other.artist
}

/**
 * Liest über den Benachrichtigungszugriff die Media-Session von Spotify
 * mit und schreibt Rohereignisse in [EventLog]. Läuft vom System gehalten
 * im Hintergrund, auch wenn die App geschlossen ist.
 */
class MediaListenerService : NotificationListenerService() {

    companion object {
        @Volatile
        var instance: MediaListenerService? = null
            private set

        fun statusName(state: Int?): String = when (state) {
            PlaybackState.STATE_PLAYING -> "PLAYING"
            PlaybackState.STATE_PAUSED -> "PAUSED"
            PlaybackState.STATE_STOPPED -> "STOPPED"
            PlaybackState.STATE_BUFFERING -> "BUFFERING"
            PlaybackState.STATE_CONNECTING -> "CONNECTING"
            PlaybackState.STATE_FAST_FORWARDING -> "FAST_FORWARDING"
            PlaybackState.STATE_REWINDING -> "REWINDING"
            PlaybackState.STATE_SKIPPING_TO_NEXT,
            PlaybackState.STATE_SKIPPING_TO_PREVIOUS,
            PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM -> "SKIPPING"
            PlaybackState.STATE_ERROR -> "ERROR"
            PlaybackState.STATE_NONE -> "NONE"
            else -> "UNKNOWN"
        }

        /** Aktuelle Position, bei laufender Wiedergabe hochgerechnet. */
        fun currentPosition(ps: PlaybackState?, durationMs: Long): Long {
            if (ps == null) return 0L
            var pos = ps.position
            if (ps.state == PlaybackState.STATE_PLAYING && ps.lastPositionUpdateTime > 0) {
                val elapsed = SystemClock.elapsedRealtime() - ps.lastPositionUpdateTime
                pos += (elapsed * ps.playbackSpeed).toLong()
            }
            if (pos < 0) pos = 0
            if (durationMs > 0 && pos > durationMs) pos = durationMs
            return pos
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var sessionManager: MediaSessionManager? = null
    private var controller: MediaController? = null
    private var lastSnapshot: Snapshot? = null
    private var receiverRegistered = false
    private var sessionsListenerRegistered = false
    private var motionWatcher: MotionWatcher? = null

    /** Letzte Spotify-Broadcast-Daten (nur mit „Geräte-Broadcast-Status“). */
    @Volatile
    var lastBroadcast: Map<String, String> = emptyMap()
        private set

    var connected = false
        private set

    val spotifyController: MediaController? get() = controller

    val lastMotionAt: Long?
        get() = motionWatcher?.lastMotionAt?.takeIf { it > 0 }

    val motionListening: Boolean
        get() = motionWatcher?.listening == true

    private val sessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { sessions ->
            onSessionsChanged(sessions ?: emptyList())
        }

    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = onChange("metadata")
        override fun onPlaybackStateChanged(state: PlaybackState?) = onChange("state")
        override fun onSessionDestroyed() {
            record("end")
            stopMotionWatcher()
            detach()
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            val snap = snapshot()
            if (snap != null && snap.state == "PLAYING") {
                emit(snap, "tick")
                handler.postDelayed(this, TICK_MS)
            }
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != "com.spotify.music.metadatachanged") return
            lastBroadcast = mapOf(
                "id" to (intent.getStringExtra("id") ?: ""),
                "track" to (intent.getStringExtra("track") ?: ""),
                "artist" to (intent.getStringExtra("artist") ?: ""),
                "album" to (intent.getStringExtra("album") ?: ""),
                "length" to intent.getIntExtra("length", 0).toString(),
                "receivedAt" to System.currentTimeMillis().toString(),
            )
        }
    }

    private var screenReceiverRegistered = false
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (context == null) return
            val action = intent?.action ?: return
            val ts = System.currentTimeMillis()
            val screenAction = when (action) {
                Intent.ACTION_SCREEN_ON -> "on"
                Intent.ACTION_SCREEN_OFF -> "off"
                Intent.ACTION_USER_PRESENT -> "unlock"
                else -> return
            }
            EventLog.append(context, JSONObject(mapOf(
                "ts" to ts,
                "type" to "screen",
                "action" to screenAction,
            )))
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        connected = true
        registerSpotifyReceiver()
        registerScreenReceiver()
        try {
            val sm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            sessionManager = sm
            val component = ComponentName(this, MediaListenerService::class.java)
            if (!sessionsListenerRegistered) {
                sm.addOnActiveSessionsChangedListener(sessionsListener, component)
                sessionsListenerRegistered = true
            }
            onSessionsChanged(sm.getActiveSessions(component))
        } catch (e: SecurityException) {
            Log.e(TAG, "Kein Zugriff auf Media-Sessions", e)
        }
    }

    override fun onListenerDisconnected() {
        record("end")
        detach()
        if (sessionsListenerRegistered) {
            sessionManager?.removeOnActiveSessionsChangedListener(sessionsListener)
            sessionsListenerRegistered = false
        }
        stopMotionWatcher()
        unregisterSpotifyReceiver()
        unregisterScreenReceiver()
        connected = false
        if (instance === this) instance = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun onSessionsChanged(sessions: List<MediaController>) {
        val spotify = sessions.firstOrNull { it.packageName == SPOTIFY_PACKAGE }
        if (spotify?.sessionToken == controller?.sessionToken) return
        record("end")
        detach()
        if (spotify != null) {
            controller = spotify
            spotify.registerCallback(callback, handler)
            onChange("start")
        }
    }

    private fun detach() {
        handler.removeCallbacks(tick)
        stopMotionWatcher()
        controller?.unregisterCallback(callback)
        controller = null
        lastSnapshot = null
    }

    /** Neuer Stand von Spotify: bei Titelwechsel erst das alte Stück abschließen. */
    private fun onChange(cause: String) {
        val snap = snapshot() ?: return
        val prev = lastSnapshot
        if (prev != null && !snap.sameItem(prev)) {
            // Endposition des vorigen Stücks, hochgerechnet ab der letzten Messung.
            emit(prev.copy(positionMs = extrapolate(prev)), "end", remember = false)
            emit(snap, "start")
        } else {
            emit(snap, if (prev == null) "start" else "state")
        }
        handler.removeCallbacks(tick)
        if (snap.state == "PLAYING") {
            handler.postDelayed(tick, TICK_MS)
            startMotionWatcher()
        } else {
            stopMotionWatcher()
        }
        Log.d(TAG, "Änderung ($cause): ${snap.title} ${snap.state} ${snap.positionMs}")
    }

    private var lastEmitWall = 0L

    private fun extrapolate(prev: Snapshot): Long {
        if (prev.state != "PLAYING") return prev.positionMs
        val elapsed = System.currentTimeMillis() - lastEmitWall
        val pos = prev.positionMs + elapsed.coerceAtLeast(0)
        return if (prev.durationMs > 0) pos.coerceAtMost(prev.durationMs) else pos
    }

    private fun record(reason: String) {
        val prev = lastSnapshot ?: return
        emit(prev.copy(positionMs = extrapolate(prev)), reason, remember = false)
    }

    private fun emit(snap: Snapshot, reason: String, remember: Boolean = true) {
        val now = System.currentTimeMillis()
        EventLog.append(this, snap.toEvent(reason, now))
        if (remember) {
            lastSnapshot = snap
            lastEmitWall = now
        }
    }

    /** Aktueller Stand von Spotify oder null, wenn keine Session / kein Titel. */
    fun snapshot(): Snapshot? {
        val c = controller ?: return null
        val md = c.metadata ?: return null
        val title = md.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        if (title.isBlank()) return null
        val ps = c.playbackState
        val duration = md.getLong(MediaMetadata.METADATA_KEY_DURATION).coerceAtLeast(0)
        val artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: ""
        val bc = lastBroadcast
        val uri = if (bc["track"].equals(title, ignoreCase = true)) bc["id"] ?: "" else ""
        return Snapshot(
            title = title,
            artist = artist,
            album = md.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: "",
            durationMs = duration,
            positionMs = currentPosition(ps, duration),
            state = statusName(ps?.state),
            mediaId = md.getString(MediaMetadata.METADATA_KEY_MEDIA_ID) ?: "",
            mediaUri = md.getString(MediaMetadata.METADATA_KEY_MEDIA_URI) ?: "",
            artUri = md.getString(MediaMetadata.METADATA_KEY_ART_URI)
                ?: md.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
                ?: md.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI) ?: "",
            actions = ps?.actions ?: 0L,
            spotifyUri = uri,
            contextUri = md.getString("com.spotify.music.extra.CONTEXT_URI") ?: "",
            contextTitle = md.getString("com.spotify.music.extra.CONTEXT_TITLE") ?: "",
        )
    }

    /** Alle Metadaten-Schlüssel als Text – für die Diagnose. */
    fun rawMetadata(): Map<String, String> {
        val md = controller?.metadata ?: return emptyMap()
        val out = linkedMapOf<String, String>()
        for (key in md.keySet()) {
            val text = try {
                md.getText(key)?.toString()
            } catch (e: Exception) {
                null
            } ?: try {
                md.getLong(key).toString()
            } catch (e: Exception) {
                "?"
            }
            out[key] = text
        }
        return out
    }

    private fun registerSpotifyReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction("com.spotify.music.metadatachanged")
            addAction("com.spotify.music.playbackstatechanged")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            receiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Receiver-Registrierung fehlgeschlagen", e)
        }
    }

    private fun unregisterSpotifyReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(receiver)
        } catch (e: Exception) {
            Log.e(TAG, "Receiver-Abmeldung fehlgeschlagen", e)
        }
        receiverRegistered = false
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(screenReceiver, filter)
            }
            screenReceiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Screen-Receiver-Registrierung fehlgeschlagen", e)
        }
    }

    private fun unregisterScreenReceiver() {
        if (!screenReceiverRegistered) return
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Screen-Receiver-Abmeldung fehlgeschlagen", e)
        }
        screenReceiverRegistered = false
    }

    private fun startMotionWatcher() {
        if (motionWatcher == null) {
            motionWatcher = MotionWatcher(this)
        }
        motionWatcher?.start()
    }

    private fun stopMotionWatcher() {
        motionWatcher?.stop()
    }
}
