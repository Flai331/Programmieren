package com.klaas.nfc_riegel

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QuietPlannerTest {

    private val zone = TimeZone.getTimeZone("Europe/Berlin")
    private val minute = 60_000L

    /** Ein fester Zeitpunkt in der Berliner Zone. Montag, 2026-08-24. */
    private fun am(tag: Int, stunde: Int, minuten: Int = 0): Long =
        Calendar.getInstance(zone).apply {
            clear()
            set(2026, Calendar.AUGUST, tag, stunde, minuten, 0)
        }.timeInMillis

    private fun profil(quiet: QuietSettings, id: String = "p1") =
        Profile(id = id, name = "Arbeit", quiet = quiet)

    private fun zustand(vararg profile: Profile, kalender: CalendarSettings = CalendarSettings()) =
        LockState(profiles = profile.toList(), calendar = kalender)

    // ---------------------------------------------------------------- Wochenplan

    private val nachts = QuietSettings(
        enabled = true,
        whileLocked = false,
        schedules = listOf(
            QuietSchedule(
                days = setOf(Calendar.MONDAY, Calendar.TUESDAY),
                startMinute = 22 * 60,
                endMinute = 6 * 60,
            ),
        ),
    )

    @Test
    fun `Wochenplan gilt innerhalb seines Fensters`() {
        val state = zustand(profil(nachts))

        assertTrue(QuietPlanner.isQuiet(state, am(24, 23), zone))
    }

    @Test
    fun `Wochenplan gilt davor nicht`() {
        val state = zustand(profil(nachts))

        assertFalse(QuietPlanner.isQuiet(state, am(24, 21, 59), zone))
    }

    @Test
    fun `Fenster ueber Mitternacht gilt am naechsten Morgen weiter`() {
        val state = zustand(profil(nachts))

        // Dienstag 05:59 gehoert noch zum Fenster, das Montag 22:00 begann.
        assertTrue(QuietPlanner.isQuiet(state, am(25, 5, 59), zone))
        assertFalse(QuietPlanner.isQuiet(state, am(25, 6), zone))
    }

    @Test
    fun `an einem Tag ohne Plan gilt nichts`() {
        val state = zustand(profil(nachts))

        // Mittwoch 23 Uhr - der Plan nennt nur Montag und Dienstag.
        assertFalse(QuietPlanner.isQuiet(state, am(26, 23), zone))
    }

    @Test
    fun `naechste Grenze ist der Beginn des Fensters`() {
        val state = zustand(profil(nachts))

        assertEquals(am(24, 22), QuietPlanner.nextBoundary(state, am(24, 20), zone))
    }

    @Test
    fun `naechste Grenze im Fenster ist dessen Ende`() {
        val state = zustand(profil(nachts))

        assertEquals(am(25, 6), QuietPlanner.nextBoundary(state, am(24, 23), zone))
    }

    @Test
    fun `ohne Ruhe gibt es keine Grenze`() {
        val state = zustand(profil(nachts.copy(enabled = false)))

        assertNull(QuietPlanner.nextBoundary(state, am(24, 20), zone))
    }

    // ------------------------------------------------------------------ Termine

    private fun mitTermin(start: Long, ende: Long, profileId: String = "p1") = CalendarSettings(
        enabled = true,
        cachedWindows = listOf(CalendarWindow("e1", "Besprechung", start, ende, profileId)),
    )

    @Test
    fun `Termin schaltet still, Nachlauf haelt es`() {
        val state = zustand(
            profil(QuietSettings(enabled = true, whileLocked = false, afterEventMinutes = 15)),
            kalender = mitTermin(am(24, 9), am(24, 10)),
        )

        assertTrue(QuietPlanner.isQuiet(state, am(24, 9, 30), zone))
        assertTrue(QuietPlanner.isQuiet(state, am(24, 10, 14), zone))
        assertFalse(QuietPlanner.isQuiet(state, am(24, 10, 15), zone))
    }

    @Test
    fun `ohne Nachlauf endet die Ruhe mit dem Termin`() {
        val state = zustand(
            profil(QuietSettings(enabled = true, whileLocked = false)),
            kalender = mitTermin(am(24, 9), am(24, 10)),
        )

        assertTrue(QuietPlanner.isQuiet(state, am(24, 9, 59), zone))
        assertFalse(QuietPlanner.isQuiet(state, am(24, 10), zone))
    }

    @Test
    fun `Termin eines anderen Profils schaltet nicht still`() {
        val state = zustand(
            profil(QuietSettings(enabled = true, whileLocked = false)),
            kalender = mitTermin(am(24, 9), am(24, 10), profileId = "p2"),
        )

        assertFalse(QuietPlanner.isQuiet(state, am(24, 9, 30), zone))
    }

    @Test
    fun `Grenze liegt am Terminende plus Nachlauf`() {
        val state = zustand(
            profil(QuietSettings(enabled = true, whileLocked = false, afterEventMinutes = 15)),
            kalender = mitTermin(am(24, 9), am(24, 10)),
        )

        assertEquals(
            am(24, 10) + 15 * minute,
            QuietPlanner.nextBoundary(state, am(24, 9, 30), zone),
        )
    }

    // ------------------------------------------------------------------- Sperre

    @Test
    fun `laufende Zeitsperre schaltet still, wenn gewuenscht`() {
        val state = LockState(
            profiles = listOf(profil(QuietSettings(enabled = true, whileLocked = true))),
            timeLocks = listOf(TimeLock("p1", LockMode.TIMER, am(24, 12))),
        )

        assertTrue(QuietPlanner.isQuiet(state, am(24, 11), zone))
        assertFalse(QuietPlanner.isQuiet(state, am(24, 12), zone))
    }

    @Test
    fun `ohne whileLocked laesst die Sperre die Anrufe klingeln`() {
        val state = LockState(
            profiles = listOf(profil(QuietSettings(enabled = true, whileLocked = false))),
            timeLocks = listOf(TimeLock("p1", LockMode.TIMER, am(24, 12))),
        )

        assertFalse(QuietPlanner.isQuiet(state, am(24, 11), zone))
    }

    @Test
    fun `Chipsperre schaltet still`() {
        val state = LockState(
            profiles = listOf(profil(QuietSettings(enabled = true, whileLocked = true))),
            chipLock = ChipLock("p1"),
        )

        assertTrue(QuietPlanner.isQuiet(state, am(24, 11), zone))
    }

    // ---------------------------------------------------------------- Auswahl

    private val nummer = "+49 151 2345678"
    private val andere = "+49 30 9998887"

    @Test
    fun `ALLE schaltet jeden Anruf still`() {
        val profile = listOf(profil(QuietSettings(enabled = true, scope = QuietScope.ALLE)))

        assertTrue(QuietPlanner.silences(profile, nummer))
        assertTrue(QuietPlanner.silences(profile, andere))
        assertTrue(QuietPlanner.silences(profile, null))
    }

    @Test
    fun `AUSGEWAEHLTE schaltet nur die Liste still`() {
        val profile = listOf(
            profil(
                QuietSettings(
                    enabled = true,
                    scope = QuietScope.AUSGEWAEHLTE,
                    numbers = setOf(PhoneNumbers.normalize(nummer)),
                ),
            ),
        )

        assertTrue(QuietPlanner.silences(profile, nummer))
        assertFalse(QuietPlanner.silences(profile, andere))
        assertFalse(QuietPlanner.silences(profile, null))
    }

    @Test
    fun `ALLE_AUSSER laesst die Liste klingeln`() {
        val profile = listOf(
            profil(
                QuietSettings(
                    enabled = true,
                    scope = QuietScope.ALLE_AUSSER,
                    numbers = setOf(PhoneNumbers.normalize(nummer)),
                ),
            ),
        )

        assertFalse(QuietPlanner.silences(profile, nummer))
        assertTrue(QuietPlanner.silences(profile, andere))
        assertTrue(QuietPlanner.silences(profile, null))
    }

    @Test
    fun `ein stummschaltendes Profil genuegt`() {
        val profile = listOf(
            profil(
                QuietSettings(
                    enabled = true,
                    scope = QuietScope.ALLE_AUSSER,
                    numbers = setOf(PhoneNumbers.normalize(nummer)),
                ),
                id = "p1",
            ),
            profil(QuietSettings(enabled = true, scope = QuietScope.ALLE), id = "p2"),
        )

        assertTrue(QuietPlanner.silences(profile, nummer))
    }
}
