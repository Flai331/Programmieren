package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
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
    fun `Chipsperre ueberstehen Kodieren und Dekodieren`() {
        val lock = ChipLock("p1", LockMode.UNTIL, 1_700_000_000_000)

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
}
