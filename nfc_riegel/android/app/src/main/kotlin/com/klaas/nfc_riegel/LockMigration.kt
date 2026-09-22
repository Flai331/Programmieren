package com.klaas.nfc_riegel

/**
 * Einmalige Überführung eines v1-Zustands. Der bestehende Chip wird
 * gewöhnlicher Chip — sonst käme man nach dem Update an eine spätere
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
        else listOf(TagBinding(tagUid, "Chip 1", LEGACY_PROFILE_ID))

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

    /**
     * Zieht die früher zentralen Kalenderregeln an die Profile. Die Wirkung
     * bleibt dieselbe — bis auf die Rangfolge: früher sperrte bei Kalender- und
     * Stichworttreffer nur das Profil der Kalenderregel, jetzt sperren beide.
     *
     * Ist nichts umzuziehen, kommt **dasselbe Objekt** zurück; daran erkennt der
     * Speicher, dass er nicht zurückschreiben muss.
     */
    fun calendarRulesIntoProfiles(state: LockState): LockState {
        val c = state.calendar
        if (c.calendarRules.isEmpty() &&
            c.keywordProfileId == null &&
            c.keywordCalendarIds.isEmpty()
        ) {
            return state
        }

        val profile = state.profiles.map { p ->
            val auswahl = p.calendars.toMutableMap()
            for ((kalender, regel) in c.calendarRules) {
                if (regel.profileId == p.id) auswahl[kalender] = regel.match
            }
            var ueberall = p.keywordEverywhere
            if (c.keywordProfileId == p.id) {
                if (c.keywordCalendarIds.isEmpty()) {
                    ueberall = true
                } else {
                    for (kalender in c.keywordCalendarIds) {
                        // „Alle Termine" schließt die mit Stichwort schon ein.
                        if (auswahl[kalender] != CalendarMatch.ALL) {
                            auswahl[kalender] = CalendarMatch.KEYWORD
                        }
                    }
                }
            }
            p.copy(calendars = auswahl, keywordEverywhere = ueberall)
        }

        return state.copy(
            profiles = profile,
            calendar = c.copy(
                calendarRules = emptyMap(),
                keywordProfileId = null,
                keywordCalendarIds = emptySet(),
            ),
        )
    }
}
