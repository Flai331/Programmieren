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
            .map { (id, ende) -> CalendarWindow(id, "Termin", 0L, ende, profileIdFor(c, id)) }

        return ausKalender + verwaist
    }

    /**
     * Ein verwaistes Fenster kennt sein Profil nicht mehr — der Termin ist weg.
     * Die Zuordnung stand im zwischengespeicherten Fenster, das mit ihm
     * verschwunden ist; als Rückfall dient das Stichwortprofil.
     */
    private fun profileIdFor(c: CalendarSettings, eventId: String): String =
        c.cachedWindows.firstOrNull { it.eventId == eventId }?.profileId
            ?: c.keywordProfileId
            ?: ""

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
     * Welches Profil ein Termin bekommt. Zwei Regelarten in fester Rangfolge:
     *
     * 1. Die Regel des Kalenders, in dem der Termin steht — die spezifischere
     *    Angabe. Steht sie auf [CalendarMatch.ALL], gilt sie für jeden Termin;
     *    auf [CalendarMatch.KEYWORD] nur bei Treffer im Titel.
     * 2. Die eigenständige Stichwortregel, sofern der Kalender in
     *    [CalendarSettings.keywordCalendarIds] steht oder diese Menge leer ist.
     *
     * Trifft weder noch, sperrt der Termin nicht.
     */
    fun profileForEvent(c: CalendarSettings, calendarId: String, title: String): String? {
        val trifftMarker = c.keywordMarker.isNotEmpty() && title.contains(c.keywordMarker)

        val regel = c.calendarRules[calendarId]
        if (regel != null) {
            when (regel.match) {
                CalendarMatch.ALL -> return regel.profileId
                // Kein Treffer heißt nicht „fertig": die eigenständige Regel darf
                // es noch versuchen. Nur wenn die Kalenderregel greift, hat sie
                // Vorrang.
                CalendarMatch.KEYWORD -> if (trifftMarker) return regel.profileId
            }
        }

        if (!trifftMarker) return null
        val imSuchbereich = c.keywordCalendarIds.isEmpty() || calendarId in c.keywordCalendarIds
        return if (imSuchbereich) c.keywordProfileId else null
    }
}
