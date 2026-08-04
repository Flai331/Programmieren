package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineBlockTest {

    private val now = 1_000_000L
    private val arbeit = Profile("p1", "Arbeit", setOf("com.instagram.android"))
    private val nacht = Profile("p2", "Nacht", setOf("com.zhiliaoapp.musically"))

    private fun engine(lock: ChipLock?): LockEngine =
        LockEngine(FakeLockStore(LockState(profiles = listOf(arbeit, nacht), chipLock = lock)))

    @Test
    fun `App des sperrenden Profils wird geblockt`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `App eines anderen Profils wird nicht geblockt`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertFalse(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `ohne Sperre wird nichts geblockt`() {
        val e = engine(null)

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `abgelaufene Sperre blockt nicht mehr`() {
        val e = engine(ChipLock("p1", LockMode.TIMER, now - 1))

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `blockedPackages liefert die Vereinigung der aktiven Sperren`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertEquals(setOf("com.instagram.android"), e.blockedPackages(now))
    }
}
