package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineCodeTest {

    private val now = 1_000_000L
    private val code = "K7M2P9QX"

    private fun lockedEngine(
        failedAttempts: Int = 0,
        codeLockedUntil: Long? = null,
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                locked = true,
                mode = LockMode.OPEN,
                codeHash = Hashing.sha256(code),
                failedAttempts = failedAttempts,
                codeLockedUntil = codeLockedUntil,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `richtiger Code gibt frei`() {
        val (engine, store) = lockedEngine()

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
        assertFalse(store.current.locked)
    }

    @Test
    fun `falscher Code zaehlt hoch und bleibt gesperrt`() {
        val (engine, _) = lockedEngine()

        val result = engine.submitCode("FALSCH12", now)

        assertEquals(CodeOutcome.WRONG, result.outcome)
        assertTrue(result.state.locked)
        assertEquals(1, result.state.failedAttempts)
    }

    @Test
    fun `dritter Fehlversuch sperrt die Eingabe 60 Sekunden`() {
        val (engine, _) = lockedEngine(failedAttempts = 2)

        val result = engine.submitCode("FALSCH12", now)

        assertEquals(CodeOutcome.LOCKED_OUT, result.outcome)
        assertEquals(now + 60_000L, result.state.codeLockedUntil)
        assertEquals(0, result.state.failedAttempts)
    }

    @Test
    fun `waehrend der Eingabesperre wird selbst der richtige Code abgewiesen`() {
        val (engine, _) = lockedEngine(codeLockedUntil = now + 30_000)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.LOCKED_OUT, result.outcome)
        assertTrue(result.state.locked)
    }

    @Test
    fun `nach Ablauf der Eingabesperre gilt der Code wieder`() {
        val (engine, _) = lockedEngine(codeLockedUntil = now - 1)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
    }

    @Test
    fun `ohne hinterlegten Code meldet die Engine NOT_SET`() {
        val store = FakeLockStore(LockState(locked = true, codeHash = null))
        val engine = LockEngine(store)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.NOT_SET, result.outcome)
        assertTrue(result.state.locked)
    }

    @Test
    fun `Code wird gross geschrieben und getrimmt geprueft`() {
        val (engine, _) = lockedEngine()

        val result = engine.submitCode("  k7m2p9qx ", now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
    }
}
