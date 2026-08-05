package com.klaas.nfc_riegel

/**
 * Listen ⇄ String für SharedPreferences. Bewusst kein `org.json`: das steckt im
 * Android-SDK und wäre in reinen JUnit-Tests nicht verfügbar. Getrennt wird mit
 * Steuerzeichen, die in Paketnamen und Labels nicht vorkommen.
 */
object LockCodec {

    private const val RECORD = ''
    private const val FIELD = ''
    private const val ITEM = ''

    fun encodeProfiles(profiles: List<Profile>): String =
        profiles.joinToString(RECORD.toString()) { p ->
            listOf(
                p.id,
                p.name,
                p.blockedPackages.joinToString(ITEM.toString()),
                p.defaultMode.name,
                p.durationMinutes.toString(),
                p.untilAt?.toString() ?: "",
                if (p.pinCalendarEnd) "1" else "0",
            ).joinToString(FIELD.toString())
        }

    fun decodeProfiles(raw: String): List<Profile> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 7) return@mapNotNull null
            Profile(
                id = f[0],
                name = f[1],
                blockedPackages = if (f[2].isEmpty()) emptySet() else f[2].split(ITEM).toSet(),
                defaultMode = runCatching { LockMode.valueOf(f[3]) }.getOrDefault(LockMode.TIMER),
                durationMinutes = f[4].toIntOrNull() ?: 60,
                untilAt = f[5].toLongOrNull(),
                pinCalendarEnd = f[6] == "1",
            )
        }
    }

    fun encodeTags(tags: List<TagBinding>): String =
        tags.joinToString(RECORD.toString()) { t ->
            listOf(t.uid, t.label, t.profileId, if (t.isMaster) "1" else "0")
                .joinToString(FIELD.toString())
        }

    fun decodeTags(raw: String): List<TagBinding> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 4) return@mapNotNull null
            TagBinding(uid = f[0], label = f[1], profileId = f[2], isMaster = f[3] == "1")
        }
    }

    /** v3: nur noch die Profil-Kennung. Eine Chipsperre hat weder Modus noch Ende. */
    fun encodeChipLock(lock: ChipLock?): String = lock?.profileId ?: ""

    /**
     * Liest v3 (ein Feld) und v2 (drei Felder: Kennung, Modus, Ende). Aus einem
     * v2-Datensatz bleibt nur `OPEN` eine Chipsperre; `TIMER` und `UNTIL` holt
     * [decodeLegacyTimeLock] ab.
     */
    fun decodeChipLock(raw: String): ChipLock? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size == 1) return ChipLock(f[0])
        if (f.size != 3) return null
        return if (f[1] == LockMode.OPEN.name) ChipLock(f[0]) else null
    }

    /** Die Zeitsperre, die in einem v2-Datensatz steckt — oder null. */
    fun decodeLegacyTimeLock(raw: String): TimeLock? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size != 3) return null
        val mode = runCatching { LockMode.valueOf(f[1]) }.getOrNull() ?: return null
        if (mode == LockMode.OPEN) return null
        val endsAt = f[2].toLongOrNull() ?: return null
        return TimeLock(f[0], mode, endsAt)
    }

    fun encodeTimeLocks(locks: List<TimeLock>): String =
        locks.joinToString(RECORD.toString()) { l ->
            listOf(l.profileId, l.mode.name, l.endsAt.toString())
                .joinToString(FIELD.toString())
        }

    fun decodeTimeLocks(raw: String): List<TimeLock> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 3) return@mapNotNull null
            TimeLock(
                profileId = f[0],
                mode = runCatching { LockMode.valueOf(f[1]) }.getOrNull()
                    ?: return@mapNotNull null,
                endsAt = f[2].toLongOrNull() ?: return@mapNotNull null,
            )
        }
    }
}
