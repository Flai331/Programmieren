package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now - 1)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertFalse(state.locked)
        assertNull(state.endsAt)
        assertFalse(store.current.locked)
    }

    @Test
    fun `noch laufender Timer gibt nicht frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now + 60_000)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertTrue(state.locked)
        assertEquals(now + 60_000, state.endsAt)
    }

    @Test
    fun `Boot mit abgelaufenem Timer gibt frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now - 10_000)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertFalse(state.locked)
    }

    @Test
    fun `Boot mit laufendem Timer bleibt gesperrt`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now + 10_000)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertTrue(state.locked)
        assertEquals(now + 10_000, state.endsAt)
    }

    @Test
    fun `Boot im Modus OPEN bleibt gesperrt`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.OPEN, endsAt = null)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertTrue(state.locked)
    }

    @Test
    fun `Timer-Ablauf im Modus OPEN aendert nichts`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.OPEN, endsAt = null)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertTrue(state.locked)
    }
}
