package com.klaas.nfc_riegel

/**
 * OPEN = bis erneuter Scan, TIMER = für eine Dauer, UNTIL = bis zu einem
 * absoluten Zeitpunkt. TIMER und UNTIL enden beide auch durch erneuten Scan.
 */
enum class LockMode { OPEN, TIMER, UNTIL }

/**
 * Vollständiger Zustand des Riegels. Reine Daten, keine Android-Abhängigkeit —
 * damit die Logik in [LockEngine] ohne Emulator testbar bleibt.
 */
data class LockState(
    val profiles: List<Profile> = emptyList(),
    val tags: List<TagBinding> = emptyList(),
    val chipLock: ChipLock? = null,
    val timeLocks: List<TimeLock> = emptyList(),
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
) {
    fun profileById(id: String): Profile? = profiles.firstOrNull { it.id == id }

    fun tagByUid(uid: String): TagBinding? =
        tags.firstOrNull { it.uid.equals(uid, ignoreCase = true) }
}
