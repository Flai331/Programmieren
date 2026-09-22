package com.klaas.nfc_riegel

/**
 * Rechnet die Kalendersperre aus den zwischengespeicherten Fenstern und der
 * Uhrzeit. Bewusst kein gespeicherter Zustand: verschiebst oder löschst du einen
 * laufenden Termin, verschwindet die Sperre mit — der Kalender bleibt die
 * Wahrheit über sich selbst. Ausnahme sind festgenagelte Enden.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object CalendarPlanner {

    /**
     * Fenster, die jetzt sperren. Ein festgenageltes Ende schlägt das Ende aus
     * dem Kalender und überlebt sogar das Löschen des Termins.
     */
    fun activeWindows(c: CalendarSettings, now: Long): List<CalendarWindow> {
        if (!c.enabled) return emptyList()
        if (c.suppressedUntil != null && now < c.suppressedUntil) return emptyList()

        val ausKalender = c.cachedWindows.filter { fenster ->
            val ende = c.pinnedEnds[fenster.eventId] ?: fenster.endsAt
            fenster.startsAt <= now && now < ende
        }

        // Genagelte Fenster, deren Termin aus dem Kalender verschwunden ist. Genau
        // dafür gibt es das Festnageln: Löschen darf die Sperre nicht abkürzen.
        val bekannt = c.cachedWindows.map { it.eventId }.toSet()
        val verwaist = c.pinnedEnds
            .filter { (id, ende) -> id !in bekannt && now < ende }
            // Ohne gespeichertes Fenster ist das Profil nicht mehr bekannt.
            // `updateWindows` behält genagelte Fenster deshalb im Speicher; dieser
            // Rest sperrt kein Profil, hält aber die Grenze fest.
            .map { (id, ende) -> CalendarWindow(id, "Termin", 0L, ende, "") }

        return ausKalender + verwaist
    }

    fun lockedProfileIds(c: CalendarSettings, now: Long): Set<String> =
        activeWindows(c, now).map { it.profileId }.filter { it.isNotEmpty() }.toSet()

    /**
     * Enden, die jetzt festzunageln sind: laufende Fenster, deren Profil
     * [Profile.pinCalendarEnd] gesetzt hat und die noch keinen Nagel haben.
     */
    fun pinsToAdd(
        c: CalendarSettings,
        profiles: List<Profile>,
        now: Long,
    ): Map<String, Long> {
        val nagelnde = profiles.filter { it.pinCalendarEnd }.map { it.id }.toSet()
        return activeWindows(c, now)
            .filter { it.profileId in nagelnde && it.eventId !in c.pinnedEnds }
            .associate { it.eventId to it.endsAt }
    }

    /** Nägel, deren Zeitpunkt vergangen ist, fallen weg. */
    fun prunePins(c: CalendarSettings, now: Long): Map<String, Long> =
        c.pinnedEnds.filter { now < it.value }

    /**
     * Wann sich die Sperrlage das nächste Mal ändert: der frühere von Beginn des
     * nächsten und Ende des laufenden Fensters. Darauf wird der Wecker gesetzt.
     */
    fun nextBoundary(c: CalendarSettings, now: Long): Long? {
        if (!c.enabled) return null
        val grenzen = mutableListOf<Long>()
        for (fenster in c.cachedWindows) {
            if (now < fenster.startsAt) grenzen += fenster.startsAt
            val ende = c.pinnedEnds[fenster.eventId] ?: fenster.endsAt
            if (now < ende) grenzen += ende
        }
        for ((_, ende) in c.pinnedEnds) {
            if (now < ende) grenzen += ende
        }
        return grenzen.minOrNull()
    }

    /**
     * Welche Profile ein Termin sperrt. Ein Profil trifft, wenn es den Kalender
     * auf [CalendarMatch.ALL] gesetzt hat — oder wenn der Titel den Marker
     * enthält und das Profil den Kalender auf [CalendarMatch.KEYWORD] oder
     * [Profile.keywordEverywhere] gesetzt hat. Alle Treffer sperren; es gibt
     * keine Rangfolge mehr.
     */
    fun profilesForEvent(
        profiles: List<Profile>,
        marker: String,
        calendarId: String,
        title: String,
    ): Set<String> {
        val trifftMarker = marker.isNotEmpty() && title.contains(marker)
        return profiles.filter { p ->
            when (p.calendars[calendarId]) {
                CalendarMatch.ALL -> true
                CalendarMatch.KEYWORD -> trifftMarker
                null -> trifftMarker && p.keywordEverywhere
            }
        }.map { it.id }.toSet()
    }
}
