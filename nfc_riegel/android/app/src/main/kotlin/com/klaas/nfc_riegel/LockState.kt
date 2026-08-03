package com.klaas.nfc_riegel

/** Modus A = OPEN (bis erneuter Scan), Modus B = TIMER (bis Ablauf oder Scan). */
enum class LockMode { OPEN, TIMER }

/**
 * Vollständiger Zustand des Riegels. Reine Daten, keine Android-Abhängigkeit —
 * damit die Logik in [LockEngine] ohne Emulator testbar bleibt.
 */
data class LockState(
    val locked: Boolean = false,
    val mode: LockMode = LockMode.TIMER,
    /** Ende der Sperre in Millis (Wall Clock). Nur gesetzt, wenn locked && mode == TIMER. */
    val endsAt: Long? = null,
    val durationMinutes: Int = 60,
    val blockedPackages: Set<String> = emptySet(),
    val tagUid: String? = null,
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
)
