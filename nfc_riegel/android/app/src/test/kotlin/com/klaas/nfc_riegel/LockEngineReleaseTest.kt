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
    fun `die Chipsperre eines anderen Profils gibt nichts frei`() {
        val (e, store) = engine(chipLock = ChipLock("p2"))

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
    fun `eine Freigabe fuer ein anderes Profil oeffnet die Chipsperre nicht`() {
        // Der Fall entsteht, wenn die Chipsperre gewechselt hat, waehrend eine
        // Freigabe des vorherigen Profils noch lief. Ohne den Vergleich der
        // Kennungen wuerde sie die neue Sperre mit aufmachen.
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                chipLock = ChipLock("p1"),
                release = Release("p2", now + 10 * minute),
            )
        )
        val e = LockEngine(store)

        assertTrue(e.isBlocked("com.instagram.android", now))
        assertTrue(e.hasActiveLock(now))
    }

    @Test
    fun `Dauer an den Grenzen bleibt unveraendert`() {
        val (e, store) = engine()

        e.startRelease("p1", 1, now)
        assertEquals(now + 1 * minute, store.current.release?.endsAt)

        e.startRelease("p1", 240, now)
        assertEquals(now + 240 * minute, store.current.release?.endsAt)
    }

    @Test
    fun `eine laufende Freigabe zaehlt als aktive Sperre nicht`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertFalse(e.hasActiveLock(now))
        assertNotNull(e.state().chipLock)
    }

    @Test
    fun `abgelaufene Freigabe faellt beim Weckerlauf weg`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.onTimerElapsed(now + 11 * minute)

        assertNull(store.current.release)
        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `laufende Freigabe bleibt beim Weckerlauf stehen`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.onTimerElapsed(now + 5 * minute)

        assertEquals(Release("p1", now + 10 * minute), store.current.release)
    }

    @Test
    fun `ein Neustart traegt die laufende Freigabe weiter`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.restoreAfterBoot(now + 5 * minute)

        assertEquals(Release("p1", now + 10 * minute), store.current.release)
        assertFalse(e.isBlocked("com.instagram.android", now + 5 * minute))
    }

    @Test
    fun `ein Neustart nach dem Ende sperrt wieder`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.restoreAfterBoot(now + 20 * minute)

        assertNull(store.current.release)
        assertTrue(e.isBlocked("com.instagram.android", now + 20 * minute))
    }

    @Test
    fun `der Notfall-Code raeumt Chipsperre und Freigabe zusammen weg`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
                codeHash = Hashing.sha256("FZ9HK39D"),
            )
        )
        val e = LockEngine(store)

        val result = e.submitCode("fz9hk39d", now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `der Generalschluessel raeumt die Freigabe mit weg`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                tags = listOf(TagBinding("04CC", "Schlüsselbund", "p1", isMaster = true)),
                chipLock = ChipLock("p1"),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 30 * minute)),
                release = Release("p1", now + 10 * minute),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.MASTER_CLEARED, result.outcome)
        assertNull(store.current.release)
    }

    @Test
    fun `Scan bei eingeschaltetem Schalter fragt statt zu oeffnen`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.ASK_RELEASE, result.outcome)
        assertNotNull(store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `Scan bei ausgeschaltetem Schalter oeffnet wie bisher`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit.copy(timedRelease = false)),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = ChipLock("p1"),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `Scan waehrend der Freigabe sperrt sofort wieder`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        val result = e.onTagScanned("04AA", now + 2 * minute)

        assertEquals(ScanOutcome.RELOCKED, result.outcome)
        assertNull(store.current.release)
        assertNotNull(store.current.chipLock)
        assertTrue(e.isBlocked("com.instagram.android", now + 2 * minute))
    }

    @Test
    fun `Aufsperren raeumt eine abgelaufene Freigabe mit weg`() {
        // Zwischen Ablauf und Weckerlauf steht die alte Freigabe noch im
        // Speicher. Wer dann aufsperrt, darf sie nicht zurueckhalten -- sonst
        // liegt eine Freigabe ohne Sperre herum.
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit.copy(timedRelease = false)),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = ChipLock("p1"),
                release = Release("p1", now - 1),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `Sperren ueber die Schaltflaeche beendet eine laufende Freigabe`() {
        // Waehrend der Freigabe zeigt die App das Profil als offen an und bietet
        // "Sperren" an. Der Knopf muss dann auch sperren -- vorher meldete die
        // Engine "laeuft schon" und liess den Riegel offen.
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        val outcome = e.startLock("p1", now).outcome

        assertEquals(StartOutcome.STARTED, outcome)
        assertNull(store.current.release)
        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `Sperren eines anderen Profils laesst keine alte Freigabe stehen`() {
        val nacht = Profile(id = "p2", name = "Nacht", defaultMode = LockMode.OPEN)
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
            )
        )
        val e = LockEngine(store)

        e.startLock("p2", now)

        assertEquals(ChipLock("p2"), store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `ein Chipwechsel laesst keine alte Freigabe stehen`() {
        // Freigabe fuer Arbeit laeuft, der Chip der Nacht uebernimmt. Bliebe die
        // Freigabe stehen, waere Arbeit beim Zurueckwechseln sofort wieder offen.
        val nacht = Profile(
            id = "p2",
            name = "Nacht",
            blockedPackages = setOf("com.zhiliaoapp.musically"),
            defaultMode = LockMode.OPEN,
        )
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(
                    TagBinding("04AA", "Schreibtisch", "p1"),
                    TagBinding("04BB", "Bett", "p2"),
                ),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04BB", now)

        assertEquals(ScanOutcome.SWITCHED, result.outcome)
        assertEquals(ChipLock("p2"), store.current.chipLock)
        assertNull(store.current.release)
        assertTrue(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `Scan ohne laufende Sperre sperrt wie bisher zu`() {
        val (e, store) = engine(chipLock = null)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertEquals(ChipLock("p1"), store.current.chipLock)
        assertNull(store.current.release)
    }
}
