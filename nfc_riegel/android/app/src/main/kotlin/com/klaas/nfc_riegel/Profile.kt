package com.klaas.nfc_riegel

/** Was gesperrt wird. Mindestens eines existiert immer. */
data class Profile(
    val id: String,
    val name: String,
    val blockedPackages: Set<String> = emptySet(),
    val defaultMode: LockMode = LockMode.TIMER,
    val durationMinutes: Int = 60,
    /** Absolutes Ende für [LockMode.UNTIL]. */
    val untilAt: Long? = null,
    /**
     * Nur für die Kalender-Spec: hält das Ende eines Terminfensters fest, damit
     * Löschen des Termins die Sperre nicht abkürzt. Hier mitgeführt, damit das
     * Modell später nicht wandern muss.
     */
    val pinCalendarEnd: Boolean = false,
)

/** Womit gesperrt wird. Jeder Chip hat ein Profil — auch ein Generalschlüssel. */
data class TagBinding(
    val uid: String,
    val label: String,
    val profileId: String,
    /** Beendet jede laufende Sperre, auch Kalendersperren. */
    val isMaster: Boolean = false,
)

/** Die eine aktive Chipsperre. Höchstens eine gleichzeitig. */
data class ChipLock(
    val profileId: String,
    val mode: LockMode,
    /** Bei TIMER und UNTIL gesetzt, bei OPEN null. */
    val endsAt: Long? = null,
)
