package com.klaas.nfc_riegel

/**
 * Ein Wechsel im Vordergrund, reduziert auf das Nötige. Bewusst ohne
 * Android-Typen, damit [ScreenTimeCalculator] per JUnit prüfbar bleibt.
 */
data class UsageEvent(
    val packageName: String,
    val type: UsageEventType,
    val timestamp: Long,
)

enum class UsageEventType {
    /** App kommt nach vorn. */
    FOREGROUND,

    /** App geht nach hinten. */
    BACKGROUND,

    /**
     * Bildschirm aus oder Sperrbildschirm an. Beendet alles, was gerade offen
     * ist — auf manchen Geräten kommt sonst kein Pausenereignis, und eine über
     * Nacht offen gelassene App sammelte acht Stunden an.
     */
    SCREEN_OFF,

    /**
     * Ein Vordergrunddienst des Pakets faengt an. Musik, Navigation, Aufnahme,
     * laufende Uebertragung — die einzige Hintergrundarbeit, die Android
     * ueberhaupt nach aussen meldet. Stille Dienste ohne Benachrichtigung
     * tauchen nirgends auf und lassen sich deshalb auch nicht zaehlen.
     */
    SERVICE_START,

    /** Der letzte Vordergrunddienst des Pakets hoert auf. */
    SERVICE_STOP,
}
