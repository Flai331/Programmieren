package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test

class LockEngineStartTest {

    private val now = 1_000_000L

    private val timerProfil = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 30,
    )
    private val untilProfil = Profile(
        id = "p2",
        name = "Nacht",
        blockedPackages = setOf("com.zhiliaoapp.musically"),
        defaultMode = LockMode.UNTIL,
        untilAt = now + 3_600_000,
    )
    private val openProfil = Profile(
        id = "p3",
        name = "Fokus",
        blockedPackages = setOf("com.reddit.frontpage"),
        defaultMode = LockMode.OPEN,
    )

    private fun engine(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(timerProfil, untilProfil, openProfil),
                timeLocks = locks.toList(),
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `TIMER startet und endet nach der Dauer`() {
        val (e, store) = engine()
        val result = e.startLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `UNTIL startet und uebernimmt den Zeitpunkt des Profils`() {
        val (e, store) = engine()
        val result = e.startLock("p2", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 3_600_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `OPEN-Profil laesst sich ohne Chip sperren`() {
        val (e, store) = engine()

        assertEquals(StartOutcome.STARTED, e.startLock("p3", now).outcome)

        assertEquals(ChipLock("p3"), store.current.chipLock)
        // Keine Zeitsperre: eine Chipsperre hat kein Ende.
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `laufende Chipsperre desselben Profils meldet ALREADY_RUNNING`() {
        val (e, store) = engine()
        e.startLock("p3", now)

        assertEquals(StartOutcome.ALREADY_RUNNING, e.startLock("p3", now).outcome)
        assertEquals(ChipLock("p3"), store.current.chipLock)
    }

    @Test
    fun `ohne Chip gestartete Sperre oeffnet der Scan wieder`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(openProfil),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p3")),
            )
        )
        val e = LockEngine(store)
        e.startLock("p3", now)

        val ergebnis = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, ergebnis.outcome)
        assertEquals(null, store.current.chipLock)
    }

    @Test
    fun `unbekanntes Profil ergibt NO_PROFILE`() {
        val (e, _) = engine()
        assertEquals(StartOutcome.NO_PROFILE, e.startLock("gibtsnicht", now).outcome)
    }

    @Test
    fun `UNTIL in der Vergangenheit startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = now - 1)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startLock("p2", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `UNTIL ohne Zeitpunkt startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = null)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startLock("p2", now).outcome)
    }

    @Test
    fun `zweiter Start verlaengert den TIMER ab jetzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startLock("p1", now)
        assertEquals(StartOutcome.EXTENDED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Start verkuerzt eine laufende Sperre niemals`() {
        val spaeter = now + 120 * 60_000
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, spaeter))
        val result = e.startLock("p1", now)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(spaeter, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `ohne Verlaengerungserlaubnis passiert bei laufender Sperre nichts`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startLock("p1", now, allowExtend = false)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(now + 10 * 60_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `abgelaufene Sperre desselben Profils wird ersetzt statt ergaenzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now - 1))
        val result = e.startLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `zwei Profile duerfen gleichzeitig sperren`() {
        val (e, store) = engine()
        e.startLock("p1", now)
        e.startLock("p2", now)
        assertEquals(2, store.current.timeLocks.size)
    }
}
