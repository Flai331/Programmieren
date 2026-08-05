package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L
    private val profil = Profile(id = "p1", name = "Arbeit")

    private fun engine(lock: ChipLock?): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(LockState(profiles = listOf(profil), chipLock = lock))
        return LockEngine(store) to store
    }

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now - 1))

        e.onTimerElapsed(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `laufender Timer bleibt bestehen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now + 60_000))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `abgelaufener UNTIL-Zeitpunkt gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now - 1))

        e.onTimerElapsed(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `kuenftiger UNTIL-Zeitpunkt bleibt bestehen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now + 10_000))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Modus OPEN wird vom Ablauf nicht beruehrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit abgelaufenem Ende gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now - 10_000))

        e.restoreAfterBoot(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit laufendem Ende bleibt gesperrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now + 10_000))

        e.restoreAfterBoot(now)

        assertEquals(now + 10_000, store.current.chipLock!!.endsAt)
    }

    @Test
    fun `Boot im Modus OPEN bleibt gesperrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        e.restoreAfterBoot(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `abgelaufene Zeitsperren werden abgeraeumt, laufende bleiben`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(profil),
                timeLocks = listOf(
                    TimeLock("p1", LockMode.TIMER, now - 1),
                    TimeLock("p2", LockMode.UNTIL, now + 60_000),
                ),
            )
        )
        val e = LockEngine(store)

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 60_000, store.current.timeLocks.single().endsAt)
    }
}
