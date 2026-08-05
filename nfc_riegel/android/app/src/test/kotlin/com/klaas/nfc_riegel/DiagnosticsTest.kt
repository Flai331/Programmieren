package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DiagnosticsTest {

    private val now = 1_000_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.a", "com.b"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 45,
    )
    private val nacht = Profile(id = "p2", name = "Nacht", defaultMode = LockMode.OPEN)

    @Test
    fun `ohne Sperre steht offen im Bericht`() {
        val state = LockState(profiles = listOf(arbeit, nacht))

        val lines = Diagnostics.summarize(state, now)

        assertEquals("offen", lines["Sperre"])
    }

    @Test
    fun `Chipsperre nennt das Profil`() {
        val state = LockState(
            profiles = listOf(arbeit),
            chipLock = ChipLock("p1"),
        )

        val lines = Diagnostics.summarize(state, now)

        assertTrue(lines["Sperre"]!!.contains("Arbeit"))
    }

    @Test
    fun `Profile werden mit App-Anzahl und Modus aufgelistet`() {
        val state = LockState(profiles = listOf(arbeit, nacht))

        val profile = Diagnostics.summarize(state, now)["Profile"]!!

        assertTrue(profile.contains("Arbeit"))
        assertTrue(profile.contains("2 Apps"))
        assertTrue(profile.contains("TIMER"))
        assertTrue(profile.contains("Nacht"))
    }

    @Test
    fun `Chips werden mit Profil und Generalschluessel-Merkmal aufgelistet`() {
        val state = LockState(
            profiles = listOf(arbeit),
            tags = listOf(
                TagBinding("04AA", "Schreibtisch", "p1"),
                TagBinding("04BB", "Bund", "p1", isMaster = true),
            ),
        )

        val chips = Diagnostics.summarize(state, now)["Chips"]!!

        assertTrue(chips.contains("Schreibtisch"))
        assertTrue(chips.contains("Bund"))
        assertTrue(chips.contains("General"))
    }

    @Test
    fun `keine Chips wird ausdruecklich gemeldet`() {
        val state = LockState(profiles = listOf(arbeit))

        assertEquals("keine", Diagnostics.summarize(state, now)["Chips"])
    }

    @Test
    fun `Notfall-Code-Status steht drin`() {
        val ohne = LockState(profiles = listOf(arbeit))
        val mit = LockState(profiles = listOf(arbeit), codeHash = "abc")

        assertEquals("nein", Diagnostics.summarize(ohne, now)["Notfall-Code"])
        assertEquals("ja", Diagnostics.summarize(mit, now)["Notfall-Code"])
    }

    @Test
    fun `Bericht enthaelt keine UIDs und keine Hashes`() {
        val state = LockState(
            profiles = listOf(arbeit),
            tags = listOf(TagBinding("04AABBCC", "Schreibtisch", "p1")),
            codeHash = "geheimerhash",
        )

        val text = Diagnostics.summarize(state, now).values.joinToString(" ")

        assertTrue(!text.contains("04AABBCC"))
        assertTrue(!text.contains("geheimerhash"))
    }

    @Test
    fun `laufende Zeitsperre steht im Bericht`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(Profile(id = "p1", name = "Arbeit")),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 60_000)),
            ),
            now,
        )
        assertTrue(bericht["Sperre"]!!.contains("Arbeit"))
        assertTrue(bericht["Sperre"]!!.contains("TIMER"))
    }

    @Test
    fun `abgelaufene Zeitsperre gilt als offen`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(Profile(id = "p1", name = "Arbeit")),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now - 1)),
            ),
            now,
        )
        assertEquals("offen", bericht["Sperre"])
    }

    @Test
    fun `Chip- und Zeitsperre stehen beide im Bericht`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(
                    Profile(id = "p1", name = "Arbeit"),
                    Profile(id = "p2", name = "Nacht"),
                ),
                chipLock = ChipLock("p1"),
                timeLocks = listOf(TimeLock("p2", LockMode.UNTIL, now + 60_000)),
            ),
            now,
        )
        assertTrue(bericht["Sperre"]!!.contains("Arbeit"))
        assertTrue(bericht["Sperre"]!!.contains("Nacht"))
    }
}
