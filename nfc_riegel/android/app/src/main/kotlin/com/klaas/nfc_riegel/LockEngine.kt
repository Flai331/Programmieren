package com.klaas.nfc_riegel

enum class ScanOutcome { LOCKED, UNLOCKED, UNKNOWN_TAG, NO_TAG_ENROLLED }

data class ScanResult(val state: LockState, val outcome: ScanOutcome)

enum class CodeOutcome { UNLOCKED, WRONG, LOCKED_OUT, NOT_SET }

data class CodeResult(val state: LockState, val outcome: CodeOutcome)

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

    /**
     * Vom Alarm gerufen. Gibt frei, wenn die Endzeit erreicht ist — sonst nichts.
     * Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val endsAt = s.endsAt ?: return s
        if (!s.locked || s.mode != LockMode.TIMER) return s
        return if (now >= endsAt) unlock(s) else s
    }

    /**
     * Nach dem Neustart. Modus OPEN bleibt gesperrt; im Modus TIMER entscheidet
     * die Endzeit, ob die Sperre noch gilt.
     */
    fun restoreAfterBoot(now: Long): LockState {
        val s = store.load()
        if (!s.locked) return s
        if (s.mode != LockMode.TIMER) return s
        val endsAt = s.endsAt ?: return s
        return if (now >= endsAt) unlock(s) else s
    }

    /** Notfall-Code aus dem Sperrschirm. Drei Fehlversuche sperren die Eingabe 60 s. */
    fun submitCode(input: String, now: Long): CodeResult {
        val s = store.load()
        val hash = s.codeHash ?: return CodeResult(s, CodeOutcome.NOT_SET)

        val lockedUntil = s.codeLockedUntil
        if (lockedUntil != null && now < lockedUntil) {
            return CodeResult(s, CodeOutcome.LOCKED_OUT)
        }

        val normalized = input.trim().uppercase()
        if (Hashing.sha256(normalized) == hash) {
            return CodeResult(unlock(s), CodeOutcome.UNLOCKED)
        }

        val attempts = s.failedAttempts + 1
        return if (attempts >= MAX_ATTEMPTS) {
            val next = s.copy(failedAttempts = 0, codeLockedUntil = now + LOCKOUT_MILLIS)
            store.save(next)
            CodeResult(next, CodeOutcome.LOCKED_OUT)
        } else {
            val next = s.copy(failedAttempts = attempts, codeLockedUntil = null)
            store.save(next)
            CodeResult(next, CodeOutcome.WRONG)
        }
    }

    /** Vom AccessibilityService bei jedem Fensterwechsel gefragt. */
    fun isBlocked(packageName: String): Boolean {
        val s = store.load()
        return s.locked && packageName in s.blockedPackages
    }

    /** Blockliste setzen. Während einer Sperre abgelehnt — sonst wäre sie wertlos. */
    fun setBlockedPackages(packages: Set<String>): Boolean {
        val s = store.load()
        if (s.locked) return false
        store.save(s.copy(blockedPackages = packages))
        return true
    }

    /** Modus und Dauer setzen. Während einer Sperre abgelehnt. */
    fun setMode(mode: LockMode, durationMinutes: Int): Boolean {
        val s = store.load()
        if (s.locked) return false
        store.save(s.copy(mode = mode, durationMinutes = durationMinutes))
        return true
    }

    fun enrollTag(uid: String) {
        store.save(store.load().copy(tagUid = uid))
    }

    /** Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig zurück. */
    fun generateCode(): String {
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(store.load().copy(codeHash = Hashing.sha256(code)))
        return code
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

    companion object {
        const val MAX_ATTEMPTS = 3
        const val LOCKOUT_MILLIS = 60_000L
        /** Ohne 0/O und 1/I — der Code wird abgeschrieben. */
        const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }
}
