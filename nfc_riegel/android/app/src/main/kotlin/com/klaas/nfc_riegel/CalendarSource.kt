package com.klaas.nfc_riegel

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract

/** Ein Kalender des Geräts, für die Auswahlliste. */
data class DeviceCalendar(val id: String, val name: String, val account: String)

/**
 * Liest Kalender und Termine des Geräts. Hinter einer Schnittstelle, damit die
 * Rechenlogik in [CalendarPlanner] ohne Android prüfbar bleibt.
 */
interface CalendarSource {
    fun calendars(): List<DeviceCalendar>
    fun windows(settings: CalendarSettings, from: Long, to: Long): List<CalendarWindow>
}

/** Lesezeitraum: so weit schaut Riegel in die Zukunft. */
const val CALENDAR_LOOKAHEAD_MILLIS = 48L * 60 * 60 * 1000

class ContentCalendarSource(private val context: Context) : CalendarSource {

    private fun darfLesen(): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    override fun calendars(): List<DeviceCalendar> {
        if (!darfLesen()) return emptyList()
        val spalten = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
        )
        val ergebnis = mutableListOf<DeviceCalendar>()
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, spalten, null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                ergebnis += DeviceCalendar(
                    id = c.getLong(0).toString(),
                    name = c.getString(1) ?: "Kalender",
                    account = c.getString(2) ?: "",
                )
            }
        }
        return ergebnis
    }

    /**
     * Fragt die `Instances`-Tabelle ab, nicht `Events`: sie liefert Wiederholungen
     * bereits als einzelne Termine mit konkreten Zeiten.
     */
    override fun windows(settings: CalendarSettings, from: Long, to: Long): List<CalendarWindow> {
        if (!darfLesen()) return emptyList()

        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().let {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
            it.build()
        }
        val spalten = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.ALL_DAY,
        )

        val ergebnis = mutableListOf<CalendarWindow>()
        context.contentResolver.query(uri, spalten, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                // Ganztägige Termine würden 24 Stunden sperren — praktisch immer
                // ein Versehen. Wer das will, legt einen Termin mit Uhrzeit an.
                if (c.getInt(5) != 0) continue

                val beginn = c.getLong(2)
                val ende = c.getLong(3)
                if (ende <= beginn) continue

                val titel = c.getString(1) ?: ""
                val kalenderId = c.getLong(4).toString()
                val profil = CalendarPlanner.profileForEvent(settings, kalenderId, titel)
                    ?: continue

                // Beginn angehängt: eine wiederkehrende Serie hat für alle Termine
                // dieselbe EVENT_ID, das Festnageln muss aber den einzelnen treffen.
                ergebnis += CalendarWindow(
                    eventId = "${c.getLong(0)}_$beginn",
                    title = titel,
                    startsAt = beginn,
                    endsAt = ende,
                    profileId = profil,
                )
            }
        }
        return ergebnis
    }
}
