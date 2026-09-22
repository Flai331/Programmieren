package com.klaas.nfc_riegel

/**
 * Ein Termin, der sperren soll, reduziert auf das Nötige. Zwischenspeicher —
 * die Wahrheit steht im Kalender des Geräts.
 */
data class CalendarWindow(
    val eventId: String,
    val title: String,
    val startsAt: Long,
    val endsAt: Long,
    val profileId: String,
)

/** Welche Termine eines Kalenders sperren. */
enum class CalendarMatch {
    /** Jeder Termin des Kalenders. */
    ALL,

    /** Nur Termine, deren Titel den Stichwortmarker enthält. */
    KEYWORD,
}

/**
 * Frühere zentrale Regel für einen Kalender. Wird nur noch gelesen, um sie mit
 * [LockMigration.calendarRulesIntoProfiles] an die Profile zu ziehen; die
 * Auswahl steht heute in [Profile.calendars].
 */
data class CalendarRule(
    val profileId: String,
    val match: CalendarMatch = CalendarMatch.ALL,
)

/**
 * Alles, was der Nutzer an der Kalenderfunktion einstellt, plus der
 * Zwischenspeicher. Eigene Klasse statt neun Felder in [LockState] — sie
 * gehören zusammen und werden gemeinsam geschrieben.
 */
data class CalendarSettings(
    val enabled: Boolean = false,
    /** Nur noch für den Umzug, siehe [LockMigration.calendarRulesIntoProfiles]. */
    val calendarRules: Map<String, CalendarRule> = emptyMap(),
    val keywordMarker: String = "[Riegel]",
    /** Nur noch für den Umzug, siehe [LockMigration.calendarRulesIntoProfiles]. */
    val keywordProfileId: String? = null,
    /** Nur noch für den Umzug, siehe [LockMigration.calendarRulesIntoProfiles]. */
    val keywordCalendarIds: Set<String> = emptySet(),
    val cachedWindows: List<CalendarWindow> = emptyList(),
    val windowsFetchedAt: Long = 0L,
    /** eventId → festgenageltes Ende, siehe [Profile.pinCalendarEnd]. */
    val pinnedEnds: Map<String, Long> = emptyMap(),
    /**
     * Vom Notfall-Code gesetzt: bis hierhin sperrt der
     * Kalender nicht. Ohne dieses Feld griffe die Sperre sofort wieder, weil sie
     * ja aus dem Kalender gerechnet wird.
     */
    val suppressedUntil: Long? = null,
)
