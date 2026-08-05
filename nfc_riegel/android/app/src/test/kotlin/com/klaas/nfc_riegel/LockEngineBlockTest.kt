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
        val e = engine(ChipLock("p1"))

        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `App eines anderen Profils wird nicht geblockt`() {
        val e = engine(ChipLock("p1"))

        assertFalse(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `ohne Sperre wird nichts geblockt`() {
        val e = engine(null)

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `abgelaufene Zeitsperre blockt nicht mehr`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now - 1))

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `blockedPackages liefert die Vereinigung der aktiven Sperren`() {
        val e = engine(ChipLock("p1"))

        assertEquals(setOf("com.instagram.android"), e.blockedPackages(now))
    }

    private fun engineMitZeitsperren(vararg locks: TimeLock): LockEngine =
        LockEngine(
            FakeLockStore(
                LockState(profiles = listOf(arbeit, nacht), timeLocks = locks.toList())
            )
        )

    @Test
    fun `laufende Zeitsperre sperrt die Pakete ihres Profils`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertEquals(arbeit.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `abgelaufene Zeitsperre sperrt nicht mehr`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now - 1))
        assertEquals(emptySet<String>(), e.blockedPackages(now))
    }

    @Test
    fun `zwei Zeitsperren sperren die Vereinigung`() {
        val e = engineMitZeitsperren(
            TimeLock("p1", LockMode.TIMER, now + 60_000),
            TimeLock("p2", LockMode.UNTIL, now + 90_000),
        )
        assertEquals(arbeit.blockedPackages + nacht.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `Chipsperre und Zeitsperre sperren gemeinsam`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                chipLock = ChipLock("p1"),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 60_000)),
            )
        )
        val e = LockEngine(store)
        assertEquals(arbeit.blockedPackages + nacht.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `hasActiveLock erkennt eine laufende Zeitsperre`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertTrue(e.hasActiveLock(now))
    }

    @Test
    fun `hasActiveLock ist falsch wenn alles abgelaufen ist`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now - 1))
        assertFalse(e.hasActiveLock(now))
    }
}
