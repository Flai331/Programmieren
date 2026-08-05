package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockCodecTest {

    @Test
    fun `Profile ueberstehen Kodieren und Dekodieren`() {
        val profiles = listOf(
            Profile("p1", "Arbeit", setOf("com.a", "com.b"), LockMode.TIMER, 45, null, false),
            Profile("p2", "Nacht", emptySet(), LockMode.UNTIL, 60, 1_700_000_000_000, true),
        )

        val decoded = LockCodec.decodeProfiles(LockCodec.encodeProfiles(profiles))

        assertEquals(profiles, decoded)
    }

    @Test
    fun `Chips ueberstehen Kodieren und Dekodieren`() {
        val tags = listOf(
            TagBinding("04AA", "Schreibtisch", "p1", false),
            TagBinding("04BB", "Schlüsselbund", "p2", true),
        )

        assertEquals(tags, LockCodec.decodeTags(LockCodec.encodeTags(tags)))
    }

    @Test
    fun `leere Liste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeProfiles(emptyList()))
        assertTrue(LockCodec.decodeProfiles("").isEmpty())
        assertTrue(LockCodec.decodeTags("").isEmpty())
    }

    @Test
    fun `Chipsperre uebersteht Kodieren und Dekodieren`() {
        val lock = ChipLock("p1")

        assertEquals(lock, LockCodec.decodeChipLock(LockCodec.encodeChipLock(lock)))
    }

    @Test
    fun `null-Chipsperre bleibt null`() {
        assertEquals(null, LockCodec.decodeChipLock(LockCodec.encodeChipLock(null)))
    }

    @Test
    fun `kaputte Eingabe ergibt leere Liste statt Absturz`() {
        assertTrue(LockCodec.decodeProfiles("völliger Unsinn").isEmpty())
    }

    @Test
    fun `Zeitsperren ueberstehen Hin- und Rueckwandlung`() {
        val locks = listOf(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            TimeLock("p2", LockMode.UNTIL, 1_700_000_600_000),
        )
        assertEquals(locks, LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(locks)))
    }

    @Test
    fun `leere Zeitsperrenliste bleibt leer`() {
        assertEquals(
            emptyList<TimeLock>(),
            LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(emptyList())),
        )
    }

    @Test
    fun `Zeitsperre ohne Endzeitpunkt wird verworfen`() {
        val kaputt = "p1" + '' + "TIMER" + '' + "keineZahl"
        assertEquals(emptyList<TimeLock>(), LockCodec.decodeTimeLocks(kaputt))
    }

    @Test
    fun `v2-Datensatz mit OPEN bleibt eine Chipsperre`() {
        val alt = "p1" + '' + "OPEN" + '' + ""
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock(alt))
        assertNull(LockCodec.decodeLegacyTimeLock(alt))
    }

    @Test
    fun `v2-Datensatz mit TIMER wird zur Zeitsperre`() {
        val alt = "p1" + '' + "TIMER" + '' + "1700000000000"
        assertNull(LockCodec.decodeChipLock(alt))
        assertEquals(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            LockCodec.decodeLegacyTimeLock(alt),
        )
    }

    @Test
    fun `v3-Datensatz besteht nur aus der Profil-Kennung`() {
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock("p1"))
        assertNull(LockCodec.decodeLegacyTimeLock("p1"))
    }

    @Test
    fun `Terminfenster ueberstehen Kodieren und Dekodieren`() {
        val fenster = listOf(
            CalendarWindow("e1", "Konzept schreiben", 1_000L, 2_000L, "p1"),
            CalendarWindow("e2", "Sport", 3_000L, 4_000L, "p2"),
        )

        val zurueck = LockCodec.decodeWindows(LockCodec.encodeWindows(fenster))

        assertEquals(fenster, zurueck)
    }

    @Test
    fun `leere Fensterliste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeWindows(emptyList()))
        assertTrue(LockCodec.decodeWindows("").isEmpty())
    }

    @Test
    fun `Kalendereinstellungen ueberstehen Kodieren und Dekodieren`() {
        val einstellungen = CalendarSettings(
            enabled = true,
            calendarProfiles = mapOf("cal1" to "p1", "cal2" to "p2"),
            keywordMarker = "[Fokus]",
            keywordProfileId = "p2",
            cachedWindows = listOf(CalendarWindow("e1", "Termin", 1_000L, 2_000L, "p1")),
            windowsFetchedAt = 5_000L,
            pinnedEnds = mapOf("e1" to 2_000L),
            suppressedUntil = 9_000L,
        )

        val zurueck = LockCodec.decodeCalendar(LockCodec.encodeCalendar(einstellungen))

        assertEquals(einstellungen, zurueck)
    }

    @Test
    fun `Kalendereinstellungen ohne Angaben ergeben die Vorgaben`() {
        val zurueck = LockCodec.decodeCalendar("")

        assertEquals(CalendarSettings(), zurueck)
    }

    @Test
    fun `Termintitel mit Sonderzeichen ueberlebt den Rundlauf`() {
        val fenster = listOf(CalendarWindow("e1", "Team-Meeting: Q4 (wichtig!)", 1L, 2L, "p1"))

        assertEquals(fenster, LockCodec.decodeWindows(LockCodec.encodeWindows(fenster)))
    }
}
