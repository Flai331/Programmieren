package com.klaas.nfc_riegel

enum class ScanOutcome { LOCKED, UNLOCKED, UNKNOWN_TAG, NO_TAG_ENROLLED }

data class ScanResult(val state: LockState, val outcome: ScanOutcome)

/**
 * Alle Zustandsübergänge des Riegels. Kennt nur [LockStore] — keine Android-Klassen,
 * keine Nebenwirkungen. Alarm und Benachrichtigung setzt [LockController] anhand des
 * zurückgegebenen Zustands.
 */
class LockEngine(private val store: LockStore) {

    fun state(): LockState = store.load()

    /** Chip gescannt: sperrt oder gibt frei. Fremde UID lässt den Zustand unberührt. */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        val enrolled = s.tagUid ?: return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        if (!uid.equals(enrolled, ignoreCase = true)) {
            return ScanResult(s, ScanOutcome.UNKNOWN_TAG)
        }
        return if (s.locked) ScanResult(unlock(s), ScanOutcome.UNLOCKED)
        else ScanResult(lock(s, now), ScanOutcome.LOCKED)
    }

    private fun lock(s: LockState, now: Long): LockState {
        val endsAt = if (s.mode == LockMode.TIMER) now + s.durationMinutes * 60_000L else null
        val next = s.copy(locked = true, endsAt = endsAt)
        store.save(next)
        return next
    }

    private fun unlock(s: LockState): LockState {
        val next = s.copy(
            locked = false,
            endsAt = null,
            failedAttempts = 0,
            codeLockedUntil = null,
        )
        store.save(next)
        return next
    }
}
