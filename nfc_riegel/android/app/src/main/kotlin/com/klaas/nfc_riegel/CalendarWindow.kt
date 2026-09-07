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
 * Regel für einen Kalender des Geräts. Kalender ohne Regel sperren nicht — es
 * gibt bewusst kein „aus" als eigenen Wert, das Fehlen der Regel ist das Aus.
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
    /** Kalender-ID des Geräts → Regel. Nicht enthaltene Kalender sperren nicht. */
    val calendarRules: Map<String, CalendarRule> = emptyMap(),
    val keywordMarker: String = "[Riegel]",
    /** Profil für Treffer der eigenständigen Stichwortregel. */
    val keywordProfileId: String? = null,
    /**
     * In welchen Kalendern die eigenständige Stichwortregel sucht.
     * **Leer heißt: in allen.** Das ist die Vorgabe und der häufige Fall — wer
     * einen Marker vergibt, will ihn meist überall wirken lassen.
     */
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
