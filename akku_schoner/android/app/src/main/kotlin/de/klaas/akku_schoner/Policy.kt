package de.klaas.akku_schoner

/**
 * Welche App wie stark beendet wird.
 *  keep = nie anfassen, soft = nur aus dem Speicher werfen (killBackgroundProcesses,
 *  Push-Nachrichten und Kopfhörer-Play funktionieren weiter), full = "Beenden erzwingen".
 * Nur hier entschieden; die App zeigt "autoLevel"/"level" aus Apps.list() an.
 */
object Policy {
    const val KEEP = "keep"
    const val SOFT = "soft"
    const val FULL = "full"
    val LEVELS = setOf(KEEP, SOFT, FULL)

    /** An so vielen der letzten 7 Tage benutzt -> wichtig (Kaltstart kostet mehr als Weiterlaufen). */
    const val DAILY_DAYS = 4

    /** Nie komplett beenden: sonst keine Nachrichten, kein Wecker, kein Play am Kopfhörer. */
    val NEVER_FULL = setOf(
        "com.whatsapp", "com.whatsapp.w4b", "org.thoughtcrime.securesms", "org.telegram.messenger",
        "ch.threema.app", "com.google.android.deskclock", "com.sec.android.app.clockpackage",
        "com.android.deskclock", "com.google.android.dialer", "com.samsung.android.dialer",
        "com.google.android.apps.messaging", "com.samsung.android.messaging", "com.google.android.gm",
        "com.google.android.calendar", "com.samsung.android.calendar",
        "com.spotify.music", "com.google.android.apps.youtube.music", "com.amazon.mp3",
        "deezer.android.app", "com.audible.application", "com.samsung.android.app.watchmanager",
        "com.google.android.apps.maps", "com.google.android.projection.gearhead",
    )

    /**
     * @param days7 Tage mit Nutzung in den letzten 7 Tagen, null = unbekannt (kein Nutzungszugriff)
     */
    fun autoLevel(pkg: String, system: Boolean, isProtected: Boolean, audio: Boolean, days7: Int?): String {
        if (isProtected || system) return KEEP
        if (days7 != null && days7 >= DAILY_DAYS) return KEEP
        if (audio || NEVER_FULL.contains(pkg)) return SOFT
        if (days7 == null || days7 >= 1) return SOFT
        return FULL
    }
}
