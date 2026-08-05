package com.klaas.nfc_riegel

/**
 * Einmalige Überführung eines v1-Zustands. Der bestehende Chip wird
 * Generalschlüssel — sonst käme man nach dem Update an eine spätere
 * Kalendersperre nicht mehr heran.
 */
object LockMigration {

    const val LEGACY_PROFILE_ID = "legacy"

    fun fromV1(
        locked: Boolean,
        mode: LockMode,
        endsAt: Long?,
        durationMinutes: Int,
        blockedPackages: Set<String>,
        tagUid: String?,
        codeHash: String?,
    ): LockState {
        val profile = Profile(
            id = LEGACY_PROFILE_ID,
            name = "Standard",
            blockedPackages = blockedPackages,
            defaultMode = mode,
            durationMinutes = durationMinutes,
        )
        val tags = if (tagUid.isNullOrEmpty()) emptyList()
        else listOf(TagBinding(tagUid, "Chip 1", LEGACY_PROFILE_ID, isMaster = true))

        val chipLock = if (locked && mode == LockMode.OPEN) ChipLock(LEGACY_PROFILE_ID) else null
        val timeLocks = if (locked && mode != LockMode.OPEN && endsAt != null) {
            listOf(TimeLock(LEGACY_PROFILE_ID, mode, endsAt))
        } else {
            emptyList()
        }

        return LockState(
            profiles = listOf(profile),
            tags = tags,
            chipLock = chipLock,
            timeLocks = timeLocks,
            codeHash = codeHash,
        )
    }
}
