package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L
    private val profil = Profile(id = "p1", name = "Arbeit")

    private fun mitZeitsperre(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(profil), timeLocks = locks.toList())
        )
        return LockEngine(store) to store
    }

    private fun mitChipsperre(): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(profil), chipLock = ChipLock("p1"))
        )
        return LockEngine(store) to store
    }

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 1))

        e.onTimerElapsed(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `laufender Timer bleibt bestehen`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `abgelaufener UNTIL-Zeitpunkt gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now - 1))

        e.onTimerElapsed(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `kuenftiger UNTIL-Zeitpunkt bleibt bestehen`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now + 10_000))

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `Chipsperre wird vom Ablauf nicht beruehrt`() {
        val (e, store) = mitChipsperre()

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit abgelaufenem Ende gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 10_000))

        e.restoreAfterBoot(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `Boot mit laufendem Ende bleibt gesperrt`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now + 10_000))

        e.restoreAfterBoot(now)

        assertEquals(now + 10_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Boot mit Chipsperre bleibt gesperrt`() {
        val (e, store) = mitChipsperre()

        e.restoreAfterBoot(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `abgelaufene Zeitsperren werden abgeraeumt, laufende bleiben`() {
        val (e, store) = mitZeitsperre(
            TimeLock("p1", LockMode.TIMER, now - 1),
            TimeLock("p2", LockMode.UNTIL, now + 60_000),
        )

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 60_000, store.current.timeLocks.single().endsAt)
    }
}
