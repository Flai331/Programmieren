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

/**
 * Alles, was der Nutzer an der Kalenderfunktion einstellt, plus der
 * Zwischenspeicher. Eigene Klasse statt sieben Felder in [LockState] — sie
 * gehören zusammen und werden gemeinsam geschrieben.
 */
data class CalendarSettings(
    val enabled: Boolean = false,
    /** Kalender-ID des Geräts → Profil-ID. */
    val calendarProfiles: Map<String, String> = emptyMap(),
    val keywordMarker: String = "[Riegel]",
    val keywordProfileId: String? = null,
    val cachedWindows: List<CalendarWindow> = emptyList(),
    val windowsFetchedAt: Long = 0L,
    /** eventId → festgenageltes Ende, siehe [Profile.pinCalendarEnd]. */
    val pinnedEnds: Map<String, Long> = emptyMap(),
    /**
     * Vom Generalschlüssel oder Notfall-Code gesetzt: bis hierhin sperrt der
     * Kalender nicht. Ohne dieses Feld griffe die Sperre sofort wieder, weil sie
     * ja aus dem Kalender gerechnet wird.
     */
    val suppressedUntil: Long? = null,
)
