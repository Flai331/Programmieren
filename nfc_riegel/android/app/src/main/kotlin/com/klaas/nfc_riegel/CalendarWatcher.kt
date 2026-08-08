package com.klaas.nfc_riegel

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract

/**
 * Meldet Änderungen am Kalender und lässt neu einlesen. Lebt nur, solange der
 * Prozess lebt — deshalb hängt die Richtigkeit nicht an ihm, sondern am Wecker
 * in [LockController], der spätestens alle zwölf Stunden nachsieht.
 */
class CalendarWatcher(private val context: Context) {

    private var observer: ContentObserver? = null

    /**
     * Ohne `READ_CALENDAR` wirft `registerContentObserver` eine
     * `SecurityException` — und die Berechtigung fehlt bei jeder frischen
     * Installation. Deshalb erst prüfen und danach trotzdem absichern: zwischen
     * Prüfung und Registrierung kann sie entzogen werden, und ein Absturz beim
     * App-Start wäre die schlechteste denkbare Antwort darauf.
     *
     * Nach dem Erteilen ruft [MainActivity] erneut; die Methode ist gutmütig
     * gegen Mehrfachaufrufe.
     */
    fun start() {
        if (observer != null) return
        val erlaubt = context.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
        if (!erlaubt) return

        val beobachter = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                LockController(context).refreshCalendar()
            }
        }
        runCatching {
            context.contentResolver.registerContentObserver(
                CalendarContract.CONTENT_URI, true, beobachter,
            )
        }.onSuccess { observer = beobachter }
    }

    fun stop() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }
}
