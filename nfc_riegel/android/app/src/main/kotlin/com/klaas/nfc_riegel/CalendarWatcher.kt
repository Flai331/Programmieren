package com.klaas.nfc_riegel

import android.content.Context
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

    fun start() {
        if (observer != null) return
        val beobachter = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                LockController(context).refreshCalendar()
            }
        }
        context.contentResolver.registerContentObserver(
            CalendarContract.CONTENT_URI, true, beobachter,
        )
        observer = beobachter
    }

    fun stop() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }
}
