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
}
