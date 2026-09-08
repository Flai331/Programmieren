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
    private const val PAIR = ''

    /** Feldzahlen, die je Ausbaustufe entstanden sind: 7, 10/11, 17, 18, 19. */
    private val GUELTIGE_PROFILFELDER = setOf(7, 10, 11, 17, 18, 19)

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
                if (p.pause.enabled) "1" else "0",
                p.pause.stepMinutes.toString(),
                p.pause.baseSeconds.toString(),
                p.pause.resetMinutes.toString(),
                if (p.quiet.enabled) "1" else "0",
                p.quiet.scope.name,
                p.quiet.numbers.joinToString(ITEM.toString()),
                p.quiet.afterEventMinutes.toString(),
                if (p.quiet.whileLocked) "1" else "0",
                encodeSchedules(p.quiet.schedules),
                if (p.timedRelease) "1" else "0",
                p.quiet.ringer.name,
            ).joinToString(FIELD.toString())
        }

    /**
     * Liest siebzehn Felder (mit Ruhe), elf und zehn (mit Atempause) und sieben
     * (davor). Ein alter Satz bekommt die Vorgaben — stillschweigend zu
     * verwerfen hieße, gesperrte Apps zu vergessen.
     */
    fun decodeProfiles(raw: String): List<Profile> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size !in GUELTIGE_PROFILFELDER) return@mapNotNull null
            Profile(
                id = f[0],
                name = f[1],
                blockedPackages = if (f[2].isEmpty()) emptySet() else f[2].split(ITEM).toSet(),
                defaultMode = runCatching { LockMode.valueOf(f[3]) }.getOrDefault(LockMode.TIMER),
                durationMinutes = f[4].toIntOrNull() ?: 60,
                untilAt = f[5].toLongOrNull(),
                pinCalendarEnd = f[6] == "1",
                pause = if (f.size >= 10) {
                    PauseSettings(
                        enabled = f[7] == "1",
                        stepMinutes = f[8].toIntOrNull() ?: 15,
                        baseSeconds = f[9].toIntOrNull() ?: 5,
                        // Feld 11 kam mit dem Wechsel auf Sitzungszeit dazu.
                        resetMinutes = if (f.size >= 11) f[10].toIntOrNull() ?: 15 else 15,
                    )
                } else {
                    PauseSettings()
                },
                quiet = if (f.size >= 17) {
                    QuietSettings(
                        enabled = f[11] == "1",
                        scope = runCatching { QuietScope.valueOf(f[12]) }
                            .getOrDefault(QuietScope.ALLE),
                        numbers = if (f[13].isEmpty()) {
                            emptySet()
                        } else {
                            f[13].split(ITEM).filter { it.isNotEmpty() }.toSet()
                        },
                        afterEventMinutes = f[14].toIntOrNull() ?: 0,
                        whileLocked = f[15] == "1",
                        schedules = decodeSchedules(f[16]),
                        // Feld 19 kam mit dem Klingelmodus dazu.
                        ringer = if (f.size >= 19) {
                            runCatching { RingerMode.valueOf(f[18]) }
                                .getOrDefault(RingerMode.UNVERAENDERT)
                        } else {
                            RingerMode.UNVERAENDERT
                        },
                    )
                } else {
                    QuietSettings()
                },
                timedRelease = f.size >= 18 && f[17] == "1",
            )
        }
    }

    fun encodeTags(tags: List<TagBinding>): String =
        tags.joinToString(RECORD.toString()) { t ->
            listOf(t.uid, t.label, t.profileId).joinToString(FIELD.toString())
        }

    fun decodeTags(raw: String): List<TagBinding> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            // Vier Felder: der alte Stand mit dem Generalschlüssel-Merkmal. Es
            // wird gelesen und weggeworfen — alle Chips sind gleich.
            if (f.size !in setOf(3, 4)) return@mapNotNull null
            TagBinding(uid = f[0], label = f[1], profileId = f[2])
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

    /** Freigabe: Profil und Ende. Leer heißt: keine. */
    fun encodeRelease(release: Release?): String =
        release?.let { "${it.profileId}$FIELD${it.endsAt}" } ?: ""

    fun decodeRelease(raw: String): Release? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size != 2) return null
        val endsAt = f[1].toLongOrNull() ?: return null
        return Release(f[0], endsAt)
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

    fun encodeWindows(windows: List<CalendarWindow>): String =
        windows.joinToString(RECORD.toString()) { w ->
            listOf(
                w.eventId,
                w.title,
                w.startsAt.toString(),
                w.endsAt.toString(),
                w.profileId,
            ).joinToString(FIELD.toString())
        }

    fun decodeWindows(raw: String): List<CalendarWindow> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 5) return@mapNotNull null
            CalendarWindow(
                eventId = f[0],
                title = f[1],
                startsAt = f[2].toLongOrNull() ?: return@mapNotNull null,
                endsAt = f[3].toLongOrNull() ?: return@mapNotNull null,
                profileId = f[4],
            )
        }
    }

    /**
     * Ein Wochenplan als `wochentage PAIR beginn PAIR ende`, Pläne durch ITEM
     * getrennt. Die Wochentage stehen als sieben Zeichen, Sonntag zuerst — dann
     * entspricht die Stelle dem Wert aus `Calendar.DAY_OF_WEEK`.
     */
    private fun encodeSchedules(schedules: List<QuietSchedule>): String =
        schedules.joinToString(ITEM.toString()) { plan ->
            "${encodeDays(plan.days)}$PAIR${plan.startMinute}$PAIR${plan.endMinute}"
        }

    private fun decodeSchedules(raw: String): List<QuietSchedule> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(ITEM).mapNotNull { eintrag ->
            val teile = eintrag.split(PAIR)
            if (teile.size != 3) return@mapNotNull null
            QuietSchedule(
                days = decodeDays(teile[0]),
                startMinute = teile[1].toIntOrNull() ?: return@mapNotNull null,
                endMinute = teile[2].toIntOrNull() ?: return@mapNotNull null,
            )
        }
    }

    private fun encodeDays(days: Set<Int>): String =
        (1..7).joinToString("") { if (it in days) "1" else "0" }

    private fun decodeDays(raw: String): Set<Int> =
        raw.mapIndexedNotNull { stelle, zeichen -> (stelle + 1).takeIf { zeichen == '1' } }.toSet()

    private fun encodeMap(map: Map<String, String>): String =
        map.entries.joinToString(ITEM.toString()) { "${it.key}$PAIR${it.value}" }

    private fun decodeMap(raw: String): Map<String, String> {
        if (raw.isEmpty()) return emptyMap()
        return raw.split(ITEM).mapNotNull { paar ->
            val teile = paar.split(PAIR)
            if (teile.size != 2) null else teile[0] to teile[1]
        }.toMap()
    }

    /**
     * Eine Kalenderregel als `id PAIR profilId PAIR trefferart`, Regeln durch
     * ITEM getrennt.
     */
    private fun encodeRules(rules: Map<String, CalendarRule>): String =
        rules.entries.joinToString(ITEM.toString()) { (id, regel) ->
            "$id$PAIR${regel.profileId}$PAIR${regel.match.name}"
        }

    private fun decodeRules(raw: String): Map<String, CalendarRule> {
        if (raw.isEmpty()) return emptyMap()
        return raw.split(ITEM).mapNotNull { eintrag ->
            val teile = eintrag.split(PAIR)
            if (teile.size != 3) return@mapNotNull null
            teile[0] to CalendarRule(
                profileId = teile[1],
                match = runCatching { CalendarMatch.valueOf(teile[2]) }
                    .getOrDefault(CalendarMatch.ALL),
            )
        }.toMap()
    }

    /**
     * Die Fensterliste steckt als eigenes Feld mit RECORD- und FIELD-Trennern in
     * einem FIELD-getrennten Datensatz. Das geht nur, weil die äußere Aufteilung
     * mit `limit` arbeitet und das Fensterfeld zuletzt steht.
     */
    fun encodeCalendar(c: CalendarSettings): String = listOf(
        if (c.enabled) "1" else "0",
        encodeRules(c.calendarRules),
        c.keywordMarker,
        c.keywordProfileId ?: "",
        c.keywordCalendarIds.joinToString(ITEM.toString()),
        c.windowsFetchedAt.toString(),
        encodeMap(c.pinnedEnds.mapValues { it.value.toString() }),
        c.suppressedUntil?.toString() ?: "",
        encodeWindows(c.cachedWindows),
    ).joinToString(FIELD.toString())

    fun decodeCalendar(raw: String): CalendarSettings {
        if (raw.isEmpty()) return CalendarSettings()
        val f = raw.split(FIELD, limit = 9)
        if (f.size != 9) return CalendarSettings()
        return CalendarSettings(
            enabled = f[0] == "1",
            calendarRules = decodeRules(f[1]),
            keywordMarker = f[2],
            keywordProfileId = f[3].takeIf { it.isNotEmpty() },
            keywordCalendarIds = if (f[4].isEmpty()) emptySet() else f[4].split(ITEM).toSet(),
            windowsFetchedAt = f[5].toLongOrNull() ?: 0L,
            pinnedEnds = decodeMap(f[6]).mapNotNull { (k, v) ->
                v.toLongOrNull()?.let { k to it }
            }.toMap(),
            suppressedUntil = f[7].toLongOrNull(),
            cachedWindows = decodeWindows(f[8]),
        )
    }
}
