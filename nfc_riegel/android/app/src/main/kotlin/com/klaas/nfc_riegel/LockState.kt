package com.klaas.nfc_riegel

/**
 * OPEN = Chipsperre bis erneuter Scan. TIMER = Zeitsperre für eine Dauer,
 * UNTIL = Zeitsperre bis zu einem absoluten Zeitpunkt. Zeitsperren enden
 * vorzeitig nur durch Generalschlüssel oder Notfall-Code.
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
    /** Höchstens eine — es gibt höchstens eine Chipsperre. */
    val release: Release? = null,
    val calendar: CalendarSettings = CalendarSettings(),
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
) {
    fun profileById(id: String): Profile? = profiles.firstOrNull { it.id == id }

    fun tagByUid(uid: String): TagBinding? =
        tags.firstOrNull { it.uid.equals(uid, ignoreCase = true) }
}
