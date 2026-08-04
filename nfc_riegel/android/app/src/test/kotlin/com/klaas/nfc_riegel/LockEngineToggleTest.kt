package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LockEngineToggleTest {

    private val now = 1_000_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 30,
    )
    private val nacht = Profile(
        id = "p2",
        name = "Nacht",
        blockedPackages = setOf("com.zhiliaoapp.musically"),
        defaultMode = LockMode.OPEN,
    )

    private val chipArbeit = TagBinding("04AA", "Schreibtisch", "p1")
    private val chipNacht = TagBinding("04BB", "Bett", "p2")
    private val general = TagBinding("04CC", "Schlüsselbund", "p1", isMaster = true)

    private fun engine(
        chipLock: ChipLock? = null,
        tags: List<TagBinding> = listOf(chipArbeit, chipNacht, general),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(arbeit, nacht), tags = tags, chipLock = chipLock)
        )
        return LockEngine(store) to store
    }

    @Test
    fun `UNTIL-Zeitpunkt in der Vergangenheit sperrt nicht`() {
        val abend = Profile(
            id = "p3",
            name = "Abend",
            defaultMode = LockMode.UNTIL,
            untilAt = now - 1,
        )
        val store = FakeLockStore(
            LockState(
                profiles = listOf(abend),
                tags = listOf(TagBinding("04DD", "Sofa", "p3")),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04DD", now)

        assertEquals(ScanOutcome.UNTIL_IN_PAST, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `unbekannte UID aendert nichts`() {
        val (e, store) = engine()

        val result = e.onTagScanned("DEADBEEF", now)

        assertEquals(ScanOutcome.UNKNOWN_TAG, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `ohne angelernte Chips meldet die Engine NO_TAG_ENROLLED`() {
        val (e, _) = engine(tags = emptyList())

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.NO_TAG_ENROLLED, result.outcome)
    }

    @Test
    fun `Chip sperrt mit dem Modus seines Profils`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        val lock = store.current.chipLock
        assertNotNull(lock)
        assertEquals("p1", lock!!.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(now + 30 * 60_000L, lock.endsAt)
    }

    @Test
    fun `Profil im Modus OPEN sperrt ohne Ende`() {
        val (e, store) = engine()

        e.onTagScanned("04BB", now)

        assertEquals(LockMode.OPEN, store.current.chipLock!!.mode)
        assertNull(store.current.chipLock!!.endsAt)
    }

    @Test
    fun `derselbe Chip gibt wieder frei`() {
        val (e, store) = engine(chipLock = ChipLock("p1", LockMode.TIMER, now + 5000))

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `anderer Chip uebernimmt mit seinem Profil`() {
        val (e, store) = engine(chipLock = ChipLock("p1", LockMode.TIMER, now + 5000))

        val result = e.onTagScanned("04BB", now)

        assertEquals(ScanOutcome.SWITCHED, result.outcome)
        assertEquals("p2", store.current.chipLock!!.profileId)
        assertEquals(LockMode.OPEN, store.current.chipLock!!.mode)
    }

    @Test
    fun `Generalschluessel beendet eine laufende Sperre`() {
        val (e, store) = engine(chipLock = ChipLock("p2", LockMode.OPEN))

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.MASTER_CLEARED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `Generalschluessel sperrt mit eigenem Profil wenn nichts laeuft`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertEquals("p1", store.current.chipLock!!.profileId)
    }

    @Test
    fun `UID-Vergleich ignoriert Gross- und Kleinschreibung`() {
        val (e, _) = engine()

        assertEquals(ScanOutcome.LOCKED, e.onTagScanned("04aa", now).outcome)
    }

    @Test
    fun `Chip mit geloeschtem Profil sperrt nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(nacht), tags = listOf(chipArbeit))
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.NO_PROFILE, result.outcome)
        assertNull(store.current.chipLock)
    }
}
