package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineToggleTest {

    private val now = 1_000_000L
    private val uid = "04A2B3C4D5"

    private fun engineWith(state: LockState): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(state)
        return LockEngine(store) to store
    }

    @Test
    fun `Scan im Modus TIMER sperrt und setzt endsAt`() {
        val (engine, store) = engineWith(
            LockState(tagUid = uid, mode = LockMode.TIMER, durationMinutes = 30)
        )

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertTrue(result.state.locked)
        assertEquals(now + 30 * 60_000L, result.state.endsAt)
        assertTrue(store.current.locked)
    }

    @Test
    fun `Scan im Modus OPEN sperrt ohne endsAt`() {
        val (engine, _) = engineWith(LockState(tagUid = uid, mode = LockMode.OPEN))

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertTrue(result.state.locked)
        assertNull(result.state.endsAt)
    }

    @Test
    fun `Scan waehrend Sperre gibt frei`() {
        val (engine, store) = engineWith(
            LockState(tagUid = uid, locked = true, mode = LockMode.TIMER, endsAt = now + 5000)
        )

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
        assertNull(result.state.endsAt)
        assertFalse(store.current.locked)
    }

    @Test
    fun `fremde UID aendert nichts`() {
        val (engine, store) = engineWith(LockState(tagUid = uid))

        val result = engine.onTagScanned("DEADBEEF", now)

        assertEquals(ScanOutcome.UNKNOWN_TAG, result.outcome)
        assertFalse(result.state.locked)
        assertFalse(store.current.locked)
    }

    @Test
    fun `ohne angelernten Chip passiert nichts`() {
        val (engine, _) = engineWith(LockState(tagUid = null))

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.NO_TAG_ENROLLED, result.outcome)
        assertFalse(result.state.locked)
    }

    @Test
    fun `UID-Vergleich ignoriert Gross- und Kleinschreibung`() {
        val (engine, _) = engineWith(LockState(tagUid = uid))

        val result = engine.onTagScanned(uid.lowercase(), now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
    }
}
