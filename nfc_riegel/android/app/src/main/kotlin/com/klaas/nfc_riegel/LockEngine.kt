package com.klaas.nfc_riegel

enum class ScanOutcome {
    LOCKED,
    UNLOCKED,
    /** Anderer Chip hat übernommen: alte Sperre beendet, neue gestartet. */
    SWITCHED,
    /** Generalschlüssel hat alle Sperren beendet. */
    MASTER_CLEARED,
    UNKNOWN_TAG,
    NO_TAG_ENROLLED,
    /** Chip zeigt auf ein Profil, das es nicht mehr gibt. */
    NO_PROFILE,
    /** UNTIL-Zeitpunkt liegt in der Vergangenheit. */
    UNTIL_IN_PAST,
}

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

    /**
     * Chip gescannt. Ein normaler Chip schaltet nur sein eigenes Profil; ein
     * Generalschlüssel beendet jede laufende Sperre.
     */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        if (s.tags.isEmpty()) return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        val tag = s.tagByUid(uid) ?: return ScanResult(s, ScanOutcome.UNKNOWN_TAG)

        val active = activeChipLock(s, now)

        if (tag.isMaster && active != null) {
            return ScanResult(clearLocks(s), ScanOutcome.MASTER_CLEARED)
        }

        val profile = s.profileById(tag.profileId)
            ?: return ScanResult(s, ScanOutcome.NO_PROFILE)

        if (active != null && active.profileId == profile.id) {
            return ScanResult(clearLocks(s), ScanOutcome.UNLOCKED)
        }

        val endsAt = when (profile.defaultMode) {
            LockMode.OPEN -> null
            LockMode.TIMER -> now + profile.durationMinutes * 60_000L
            LockMode.UNTIL -> {
                val until = profile.untilAt
                if (until == null || until <= now) {
                    return ScanResult(s, ScanOutcome.UNTIL_IN_PAST)
                }
                until
            }
        }

        val next = s.copy(chipLock = ChipLock(profile.id, profile.defaultMode, endsAt))
        store.save(next)
        return ScanResult(
            next,
            if (active != null) ScanOutcome.SWITCHED else ScanOutcome.LOCKED,
        )
    }

    /** Die Chipsperre, sofern sie jetzt noch gilt. Abgelaufene zählen nicht. */
    private fun activeChipLock(s: LockState, now: Long): ChipLock? {
        val lock = s.chipLock ?: return null
        val endsAt = lock.endsAt ?: return lock
        return if (now >= endsAt) null else lock
    }

    private fun clearLocks(s: LockState): LockState {
        val next = s.copy(chipLock = null, failedAttempts = 0, codeLockedUntil = null)
        store.save(next)
        return next
    }

    /**
     * Vom Alarm gerufen. Gibt frei, wenn das Ende erreicht ist — sonst nichts.
     * Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val lock = s.chipLock ?: return s
        val endsAt = lock.endsAt ?: return s
        return if (now >= endsAt) clearLocks(s) else s
    }

    /**
     * Nach dem Neustart. OPEN bleibt gesperrt; bei TIMER und UNTIL entscheidet
     * das gespeicherte Ende.
     */
    fun restoreAfterBoot(now: Long): LockState = onTimerElapsed(now)

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
            return CodeResult(clearLocks(s), CodeOutcome.UNLOCKED)
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
    fun isBlocked(packageName: String, now: Long): Boolean =
        packageName in blockedPackages(now)

    /**
     * Vereinigung aller aktiven Sperren. Aktuell nur die Chipsperre — die
     * Kalendersperre kommt in einer eigenen Ausbaustufe dazu.
     */
    fun blockedPackages(now: Long): Set<String> {
        val s = store.load()
        val lock = activeChipLock(s, now) ?: return emptySet()
        return s.profileById(lock.profileId)?.blockedPackages ?: emptySet()
    }

    /** Legt ein Profil an und gibt es zurück. Immer erlaubt. */
    fun addProfile(name: String): Profile {
        val s = store.load()
        val profile = Profile(id = newId(), name = name)
        store.save(s.copy(profiles = s.profiles + profile))
        return profile
    }

    /**
     * Speichert ein geändertes Profil. Abgelehnt, solange genau dieses Profil
     * sperrt — andere Profile bleiben bearbeitbar.
     */
    fun updateProfile(profile: Profile): Boolean {
        val s = store.load()
        if (s.chipLock?.profileId == profile.id) return false
        if (s.profileById(profile.id) == null) return false
        store.save(s.copy(profiles = s.profiles.map { if (it.id == profile.id) profile else it }))
        return true
    }

    /**
     * Löscht ein Profil. Das letzte bleibt bestehen, ein sperrendes ebenfalls.
     * Zugeordnete Chips ziehen auf das erste verbleibende Profil.
     */
    fun deleteProfile(id: String): Boolean {
        val s = store.load()
        if (s.profiles.size <= 1) return false
        if (s.chipLock?.profileId == id) return false
        val remaining = s.profiles.filterNot { it.id == id }
        val fallback = remaining.first().id
        store.save(
            s.copy(
                profiles = remaining,
                tags = s.tags.map { if (it.profileId == id) it.copy(profileId = fallback) else it },
            )
        )
        return true
    }

    /**
     * Chip anlernen oder einen bekannten aktualisieren. Während einer Sperre
     * abgelehnt — sonst läge man sich mitten in der Sperre einen neuen Schlüssel an.
     */
    fun enrollTag(uid: String, label: String, profileId: String, isMaster: Boolean): Boolean {
        val s = store.load()
        if (s.chipLock != null) return false
        val binding = TagBinding(uid, label, profileId, isMaster)
        val existing = s.tagByUid(uid)
        val tags = if (existing == null) s.tags + binding
        else s.tags.map { if (it.uid.equals(uid, ignoreCase = true)) binding else it }
        store.save(s.copy(tags = tags))
        return true
    }

    fun deleteTag(uid: String): Boolean {
        val s = store.load()
        if (s.chipLock != null) return false
        store.save(s.copy(tags = s.tags.filterNot { it.uid.equals(uid, ignoreCase = true) }))
        return true
    }

    /**
     * Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig
     * zurück. Während einer Sperre nicht möglich — sonst wäre der Notausgang
     * jederzeit neu ausstellbar.
     */
    fun generateCode(): String? {
        val s = store.load()
        if (s.chipLock != null) return null
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(s.copy(codeHash = Hashing.sha256(code)))
        return code
    }

    private fun newId(): String =
        System.currentTimeMillis().toString(36) + (0..999).random().toString(36)

    companion object {
        const val MAX_ATTEMPTS = 3
        const val LOCKOUT_MILLIS = 60_000L
        /** Ohne 0/O und 1/I — der Code wird abgeschrieben. */
        const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }
}
