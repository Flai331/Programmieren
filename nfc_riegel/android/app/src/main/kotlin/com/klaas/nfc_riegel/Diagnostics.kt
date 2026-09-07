package com.klaas.nfc_riegel

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Fasst den Sperrzustand für einen Fehlerbericht zusammen.
 *
 * Bewusst ohne Tag-UIDs und ohne den Hash des Notfall-Codes: ein Bericht wandert
 * in eine Notion-Datenbank, und beides wäre dort ein Schlüssel zur Wohnung.
 * Paketnamen bleiben drin — ohne sie ist ein Blockier-Fehler nicht zu deuten.
 */
object Diagnostics {

    fun summarize(state: LockState, now: Long): Map<String, String> {
        val zeilen = mutableListOf<String>()

        state.chipLock?.let { lock ->
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            zeilen += "Chip · $name"
        }

        state.timeLocks.filter { now < it.endsAt }.forEach { lock ->
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            val ende = SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(lock.endsAt))
            zeilen += "Zeit · $name · ${lock.mode.name} bis $ende"
        }

        // Die Freigabe steht neben der Chipsperre, nicht an ihrer Stelle — im
        // Bericht muss sie deshalb eigens auftauchen, sonst sieht ein
        // freigegebener Riegel wie ein gesperrter aus.
        state.release?.takeIf { now < it.endsAt }?.let { freigabe ->
            val name = state.profileById(freigabe.profileId)?.name ?: "unbekanntes Profil"
            val ende = SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(freigabe.endsAt))
            zeilen += "Freigabe · $name · frei bis $ende"
        }

        val lockLine = if (zeilen.isEmpty()) "offen" else "gesperrt · " + zeilen.joinToString(" + ")

        val profiles = if (state.profiles.isEmpty()) "keine"
        else state.profiles.joinToString(" | ") { p ->
            val ende = p.untilAt?.let {
                " bis " + SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(it))
            } ?: ""
            "${p.name}: ${p.blockedPackages.size} Apps, ${p.defaultMode.name}, " +
                "${p.durationMinutes} min$ende" +
                (if (p.timedRelease) ", Freigabe auf Zeit" else "")
        }

        val chips = if (state.tags.isEmpty()) "keine"
        else state.tags.joinToString(" | ") { t ->
            val profil = state.profileById(t.profileId)?.name ?: "?"
            "${t.label} → $profil"
        }

        val packages = state.profiles
            .flatMap { it.blockedPackages }
            .distinct()
            .sorted()
            .joinToString(", ")
            .ifEmpty { "keine" }

        return linkedMapOf(
            "Sperre" to lockLine,
            "Profile" to profiles,
            "Chips" to chips,
            "Kalender" to kalenderZeile(state, now),
            "Gesperrte Pakete" to packages,
            "Notfall-Code" to if (state.codeHash != null) "ja" else "nein",
        )
    }

    /**
     * Bewusst ohne Termintitel: der Bericht landet in einer Notion-Datenbank, und
     * Termine sind persönlich. Anzahl und Zeiten reichen, um eine falsch greifende
     * Sperre zu verstehen.
     */
    private fun kalenderZeile(state: LockState, now: Long): String {
        val c = state.calendar
        if (!c.enabled) return "aus"

        val laufend = CalendarPlanner.activeWindows(c, now).size
        val grenze = CalendarPlanner.nextBoundary(c, now)
        val nurStichwort = c.calendarRules.values.count { it.match == CalendarMatch.KEYWORD }
        val stichwortBereich =
            if (c.keywordCalendarIds.isEmpty()) "alle" else "${c.keywordCalendarIds.size}"
        val teile = mutableListOf(
            "an",
            "${c.calendarRules.size} Kalender zugeordnet ($nurStichwort nur Stichwort)",
            "Stichwortregel in $stichwortBereich Kalendern",
            "${c.cachedWindows.size} Termine im Speicher",
            "$laufend Termin(e) sperren gerade",
        )
        if (c.pinnedEnds.isNotEmpty()) teile += "${c.pinnedEnds.size} festgenagelt"
        if (c.suppressedUntil != null && now < c.suppressedUntil) teile += "unterdrückt"
        if (grenze != null) teile += "nächste Änderung in ${(grenze - now) / 60_000} min"
        return teile.joinToString(", ")
    }
}
