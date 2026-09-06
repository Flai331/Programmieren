package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Freigabe auf Zeit: der Chip öffnet nur befristet. */
class LockEngineReleaseTest {

    private val now = 1_000_000L
    private val minute = 60_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.OPEN,
        timedRelease = true,
    )

    private fun engine(
        chipLock: ChipLock? = ChipLock("p1"),
        release: Release? = null,
        timeLocks: List<TimeLock> = emptyList(),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = chipLock,
                release = release,
                timeLocks = timeLocks,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `waehrend der Freigabe ist nichts gesperrt`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `nach dem Ende der Freigabe sperrt dieselbe Chipsperre wieder`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertTrue(e.isBlocked("com.instagram.android", now + 11 * minute))
    }

    @Test
    fun `startRelease setzt das Ende aus der gewaehlten Dauer`() {
        val (e, store) = engine()

        val result = e.startRelease("p1", 15, now)

        assertEquals(ReleaseOutcome.RELEASED, result.outcome)
        assertEquals(Release("p1", now + 15 * minute), store.current.release)
    }

    @Test
    fun `ohne Chipsperre dieses Profils passiert nichts`() {
        val (e, store) = engine(chipLock = null)

        val result = e.startRelease("p1", 15, now)

        assertEquals(ReleaseOutcome.NO_LOCK, result.outcome)
        assertNull(store.current.release)
    }

    @Test
    fun `zu kurze und zu lange Dauer werden geklemmt`() {
        val (e, store) = engine()

        e.startRelease("p1", 0, now)
        assertEquals(now + 1 * minute, store.current.release?.endsAt)

        e.startRelease("p1", 999, now)
        assertEquals(now + 240 * minute, store.current.release?.endsAt)
    }

    @Test
    fun `eine Zeitsperre desselben Profils sperrt trotz Freigabe weiter`() {
        val (e, _) = engine(
            release = Release("p1", now + 10 * minute),
            timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 30 * minute)),
        )

        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `die Freigabe eines Profils oeffnet kein anderes`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(
                    arbeit,
                    Profile(
                        id = "p2",
                        name = "Nacht",
                        blockedPackages = setOf("com.zhiliaoapp.musically"),
                        defaultMode = LockMode.TIMER,
                    ),
                ),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 30 * minute)),
            )
        )
        val e = LockEngine(store)

        assertFalse(e.isBlocked("com.instagram.android", now))
        assertTrue(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `eine laufende Freigabe zaehlt als aktive Sperre nicht`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertFalse(e.hasActiveLock(now))
        assertNotNull(e.state().chipLock)
    }
}
