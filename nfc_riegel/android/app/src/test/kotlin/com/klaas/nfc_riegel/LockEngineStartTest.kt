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
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `UNTIL startet und uebernimmt den Zeitpunkt des Profils`() {
        val (e, store) = engine()
        val result = e.startTimeLock("p2", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 3_600_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `OPEN-Profil laesst sich nicht als Zeitsperre starten`() {
        val (e, store) = engine()
        assertEquals(StartOutcome.WRONG_MODE, e.startTimeLock("p3", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `unbekanntes Profil ergibt NO_PROFILE`() {
        val (e, _) = engine()
        assertEquals(StartOutcome.NO_PROFILE, e.startTimeLock("gibtsnicht", now).outcome)
    }

    @Test
    fun `UNTIL in der Vergangenheit startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = now - 1)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startTimeLock("p2", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `UNTIL ohne Zeitpunkt startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = null)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startTimeLock("p2", now).outcome)
    }

    @Test
    fun `zweiter Start verlaengert den TIMER ab jetzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.EXTENDED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Start verkuerzt eine laufende Sperre niemals`() {
        val spaeter = now + 120 * 60_000
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, spaeter))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(spaeter, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `ohne Verlaengerungserlaubnis passiert bei laufender Sperre nichts`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startTimeLock("p1", now, allowExtend = false)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(now + 10 * 60_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `abgelaufene Sperre desselben Profils wird ersetzt statt ergaenzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now - 1))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `zwei Profile duerfen gleichzeitig sperren`() {
        val (e, store) = engine()
        e.startTimeLock("p1", now)
        e.startTimeLock("p2", now)
        assertEquals(2, store.current.timeLocks.size)
    }
}
