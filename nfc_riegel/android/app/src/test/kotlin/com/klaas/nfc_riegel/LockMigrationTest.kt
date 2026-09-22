package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class LockMigrationTest {

    @Test
    fun `v1-Zustand ergibt ein Profil namens Standard`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.TIMER,
            endsAt = null,
            durationMinutes = 90,
            blockedPackages = setOf("com.a"),
            tagUid = null,
            codeHash = "abc",
        )

        assertEquals(1, state.profiles.size)
        val profile = state.profiles.first()
        assertEquals("Standard", profile.name)
        assertEquals(setOf("com.a"), profile.blockedPackages)
        assertEquals(90, profile.durationMinutes)
        assertEquals("abc", state.codeHash)
    }

    @Test
    fun `bestehender Chip wird Generalschluessel`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.OPEN,
            endsAt = null,
            durationMinutes = 60,
            blockedPackages = emptySet(),
            tagUid = "04AA",
            codeHash = null,
        )

        assertEquals(1, state.tags.size)
        val tag = state.tags.first()
        assertEquals("04AA", tag.uid)
        assertEquals("Chip 1", tag.label)
        assertEquals(state.profiles.first().id, tag.profileId)
    }

    @Test
    fun `ohne Chip bleibt die Liste leer`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = null,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertTrue(state.tags.isEmpty())
    }

    @Test
    fun `laufende TIMER-Sperre wird zur Zeitsperre`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.TIMER, endsAt = 1_700_000_000_000,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        assertNull(state.chipLock)
        val lock = state.timeLocks.single()
        assertEquals(state.profiles.first().id, lock.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(1_700_000_000_000, lock.endsAt)
    }

    @Test
    fun `laufende OPEN-Sperre bleibt eine Chipsperre`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.OPEN, endsAt = null,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        assertEquals(state.profiles.first().id, state.chipLock!!.profileId)
        assertTrue(state.timeLocks.isEmpty())
    }

    @Test
    fun `ohne laufende Sperre bleibt chipLock null`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = 123,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertNull(state.chipLock)
    }

    private val arbeit = Profile("p1", "Arbeit")
    private val nacht = Profile("p2", "Nacht")

    private fun mitKalender(c: CalendarSettings) =
        LockState(profiles = listOf(arbeit, nacht), calendar = c)

    @Test
    fun `ohne alte Regeln bleibt der Zustand dasselbe Objekt`() {
        val zustand = mitKalender(CalendarSettings(enabled = true))

        assertSame(zustand, LockMigration.calendarRulesIntoProfiles(zustand))
    }

    @Test
    fun `Kalenderregeln ziehen mit Trefferart an ihr Profil`() {
        val zustand = mitKalender(
            CalendarSettings(
                calendarRules = mapOf(
                    "cal1" to CalendarRule("p1", CalendarMatch.ALL),
                    "cal2" to CalendarRule("p1", CalendarMatch.KEYWORD),
                    "cal3" to CalendarRule("p2", CalendarMatch.ALL),
                ),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertEquals(
            mapOf("cal1" to CalendarMatch.ALL, "cal2" to CalendarMatch.KEYWORD),
            neu.profileById("p1")!!.calendars,
        )
        assertEquals(mapOf("cal3" to CalendarMatch.ALL), neu.profileById("p2")!!.calendars)
    }

    @Test
    fun `Stichwortregel ohne Kalenderauswahl wird Stichwort ueberall`() {
        val zustand = mitKalender(CalendarSettings(keywordProfileId = "p2"))

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertTrue(neu.profileById("p2")!!.keywordEverywhere)
        assertEquals(false, neu.profileById("p1")!!.keywordEverywhere)
    }

    @Test
    fun `Stichwortregel mit Kalenderauswahl wird nur Stichwort, alle Termine bleibt`() {
        val zustand = mitKalender(
            CalendarSettings(
                calendarRules = mapOf("cal1" to CalendarRule("p2", CalendarMatch.ALL)),
                keywordProfileId = "p2",
                keywordCalendarIds = setOf("cal1", "cal2"),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertEquals(
            mapOf("cal1" to CalendarMatch.ALL, "cal2" to CalendarMatch.KEYWORD),
            neu.profileById("p2")!!.calendars,
        )
        assertEquals(false, neu.profileById("p2")!!.keywordEverywhere)
    }

    @Test
    fun `Regeln auf verschwundene Profile fallen weg und Altfelder sind danach leer`() {
        val zustand = mitKalender(
            CalendarSettings(
                enabled = true,
                keywordMarker = "[Fokus]",
                calendarRules = mapOf("cal1" to CalendarRule("weg", CalendarMatch.ALL)),
                keywordProfileId = "weg",
                keywordCalendarIds = setOf("cal1"),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertTrue(neu.profiles.all { it.calendars.isEmpty() && !it.keywordEverywhere })
        assertTrue(neu.calendar.calendarRules.isEmpty())
        assertNull(neu.calendar.keywordProfileId)
        assertTrue(neu.calendar.keywordCalendarIds.isEmpty())
        assertTrue(neu.calendar.enabled)
        assertEquals("[Fokus]", neu.calendar.keywordMarker)
    }
}
