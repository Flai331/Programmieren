package com.klaasotte.spotify_merker

import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private const val TAG = "ResumeHelper"
private const val WAIT_FOR_SESSION_MS = 15_000L
private const val WAIT_FOR_TITLE_MS = 120_000L
private const val POLL_MS = 500L

/**
 * Springt zu einem gemerkten Stück an eine gemerkte Stelle:
 * Spotify starten → richtiges Stück anstoßen → warten, bis es läuft → spulen.
 * Jeder Schritt landet im Protokoll (sichtbar in der Diagnose).
 */
object ResumeHelper {
    private val handler = Handler(Looper.getMainLooper())
    private val log = ArrayList<String>()
    private var generation = 0

    fun lastLog(): List<String> = synchronized(log) { ArrayList(log) }

    private fun note(msg: String) {
        val time = SimpleDateFormat("HH:mm:ss", Locale.GERMANY).format(Date())
        synchronized(log) {
            log.add("$time $msg")
            while (log.size > 40) log.removeAt(0)
        }
        Log.d(TAG, msg)
    }

    fun resume(
        context: Context,
        title: String,
        artist: String,
        album: String,
        spotifyUri: String?,
        mediaId: String?,
        positionMs: Long,
    ): String? {
        val gen = ++generation // ein neuer Versuch bricht den alten ab
        synchronized(log) { log.clear() }
        // Spotify legt die URI oft als Media-ID ab – dann taugt sie auch zum Öffnen.
        val uri = spotifyUri?.takeIf { it.isNotBlank() }
            ?: mediaId?.takeIf { it.startsWith("spotify:") }
        note("Start: „$title“ – $artist bei ${positionMs / 1000}s, URI=${uri ?: "-"}, MediaId=${mediaId ?: "-"}")

        val service = MediaListenerService.instance
        if (service == null) {
            note("Fehler: Benachrichtigungszugriff nicht aktiv")
            return "Benachrichtigungszugriff ist nicht aktiv – bitte in der Einrichtung erlauben."
        }

        val controller = service.spotifyController
        if (controller != null) {
            startItem(context, controller, title, artist, album, uri, mediaId, positionMs, gen)
            return null
        }

        note("Spotify-Session fehlt – starte Spotify")
        if (!launchSpotify(context, uri)) {
            note("Fehler: Spotify ist nicht installiert")
            return "Spotify konnte nicht gestartet werden."
        }
        val started = System.currentTimeMillis()
        handler.post(object : Runnable {
            override fun run() {
                if (gen != generation) return
                val c = MediaListenerService.instance?.spotifyController
                when {
                    c != null -> {
                        note("Spotify-Session gefunden")
                        startItem(context, c, title, artist, album, uri, mediaId, positionMs, gen)
                    }
                    System.currentTimeMillis() - started < WAIT_FOR_SESSION_MS ->
                        handler.postDelayed(this, POLL_MS)
                    else -> {
                        note("Keine Spotify-Session nach 15 s – Suche öffnen")
                        openSearch(context, title, artist)
                        waitForTitleThenSeek(title, positionMs, gen)
                    }
                }
            }
        })
        return null
    }

    private fun startItem(
        context: Context,
        controller: MediaController,
        title: String,
        artist: String,
        album: String,
        uri: String?,
        mediaId: String?,
        positionMs: Long,
        gen: Int,
    ) {
        if (titleMatches(controller, title)) {
            note("Stück ist schon geladen")
            seekAndPlay(controller, positionMs)
            return
        }
        val actions = controller.playbackState?.actions ?: 0L
        val tc = controller.transportControls
        var triedDirect = true
        try {
            when {
                uri != null && (actions and PlaybackState.ACTION_PLAY_FROM_URI) != 0L -> {
                    note("playFromUri($uri)")
                    tc.playFromUri(Uri.parse(uri), Bundle())
                }
                !mediaId.isNullOrBlank() && (actions and PlaybackState.ACTION_PLAY_FROM_MEDIA_ID) != 0L -> {
                    note("playFromMediaId($mediaId)")
                    tc.playFromMediaId(mediaId, Bundle())
                }
                (actions and PlaybackState.ACTION_PLAY_FROM_SEARCH) != 0L -> {
                    note("playFromSearch(„$title $artist“)")
                    val extras = Bundle().apply {
                        putString(MediaStore.EXTRA_MEDIA_FOCUS, "vnd.android.cursor.item/audio")
                        putString(MediaStore.EXTRA_MEDIA_TITLE, title)
                        putString(MediaStore.EXTRA_MEDIA_ARTIST, artist)
                        putString(MediaStore.EXTRA_MEDIA_ALBUM, album)
                    }
                    tc.playFromSearch("$title $artist", extras)
                }
                else -> triedDirect = false
            }
        } catch (e: Exception) {
            note("Direktstart abgelehnt: ${e.javaClass.simpleName}: ${e.message}")
            triedDirect = false
        }

        if (!triedDirect) {
            openFallback(context, title, artist, uri)
        } else {
            // Reagiert Spotify nicht innerhalb weniger Sekunden, Spotify selbst öffnen.
            handler.postDelayed({
                if (gen != generation) return@postDelayed
                val c = MediaListenerService.instance?.spotifyController
                if (c == null || !titleMatches(c, title)) {
                    note("Spotify hat nach 5 s nicht reagiert – öffne Spotify")
                    openFallback(context, title, artist, uri)
                }
            }, 5000)
        }
        waitForTitleThenSeek(title, positionMs, gen)
    }

    /** Spotify beim Stück (URI) oder bei der Suche öffnen – der Nutzer tippt es an, wir spulen. */
    private fun openFallback(context: Context, title: String, artist: String, uri: String?) {
        if (uri != null && launchSpotify(context, uri)) {
            note("Spotify bei $uri geöffnet – ggf. auf Play tippen, dann spule ich")
        } else {
            note("Spotify-Suche geöffnet – bitte Titel antippen, dann spule ich")
            openSearch(context, title, artist)
        }
    }

    private fun waitForTitleThenSeek(title: String, positionMs: Long, gen: Int) {
        val started = System.currentTimeMillis()
        handler.post(object : Runnable {
            override fun run() {
                if (gen != generation) return
                val c = MediaListenerService.instance?.spotifyController
                if (c != null && titleMatches(c, title)) {
                    note("Richtiges Stück läuft – spule")
                    // Kurz warten, damit Spotify das Stück fertig geladen hat.
                    handler.postDelayed({ if (gen == generation) seekAndPlay(c, positionMs) }, 800)
                    return
                }
                if (System.currentTimeMillis() - started < WAIT_FOR_TITLE_MS) {
                    handler.postDelayed(this, POLL_MS)
                } else {
                    val now = c?.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "-"
                    note("Aufgegeben nach 2 Min. – Spotify spielt „$now“")
                }
            }
        })
    }

    private fun seekAndPlay(controller: MediaController, positionMs: Long) {
        val actions = controller.playbackState?.actions ?: 0L
        if (actions != 0L && (actions and PlaybackState.ACTION_SEEK_TO) == 0L) {
            note("Warnung: Spotify meldet kein SEEK_TO – versuche es trotzdem")
        }
        controller.transportControls.seekTo(positionMs)
        controller.transportControls.play()
        note("seekTo(${positionMs / 1000}s) + play gesendet")
        // Nachkontrolle
        handler.postDelayed({
            val pos = MediaListenerService.currentPosition(controller.playbackState, 0L)
            note("Kontrolle: Position jetzt ${pos / 1000}s")
        }, 2000)
    }

    private fun titleMatches(c: MediaController, title: String): Boolean {
        val now = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: return false
        return now.trim().equals(title.trim(), ignoreCase = true)
    }

    private fun launchSpotify(context: Context, spotifyUri: String?): Boolean {
        val intent = if (!spotifyUri.isNullOrBlank()) {
            Intent(Intent.ACTION_VIEW, Uri.parse(spotifyUri)).setPackage(SPOTIFY_PACKAGE)
        } else {
            context.packageManager.getLaunchIntentForPackage(SPOTIFY_PACKAGE)
        } ?: return false
        return try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            note("Spotify-Start fehlgeschlagen: ${e.message}")
            false
        }
    }

    private fun openSearch(context: Context, title: String, artist: String) {
        val query = Uri.encode("$title $artist".trim())
        launchSpotify(context, "spotify:search:$query")
    }
}
