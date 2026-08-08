package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineCalendarTest {

    private val jetzt = 1_000_000L
    private val minute = 60_000L

    // OPEN, damit ein Scan die Chipsperre umschaltet statt eine Zeitsperre zu
    // starten — hier geht es um das Verhältnis von Chip- und Kalendersperre.
    private val arbeit = Profile("p1", "Arbeit", setOf("com.a"), LockMode.OPEN)
    private val nacht = Profile("p2", "Nacht", setOf("com.b"), LockMode.OPEN)

    private fun engine(
        kalender: CalendarSettings = CalendarSettings(),
        chipLock: ChipLock? = null,
        tags: List<TagBinding> = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = tags,
                chipLock = chipLock,
                calendar = kalender,
            )
        )
        return LockEngine(store) to store
    }

    private fun laufendesFenster(profil: String = "p1") = CalendarSettings(
        enabled = true,
        cachedWindows = listOf(
            CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, profil),
        ),
    )

    @Test
    fun `laufendes Fenster sperrt die Apps seines Profils`() {
        val (e, _) = engine(laufendesFenster())

        assertEquals(setOf("com.a"), e.blockedPackages(jetzt))
    }

    @Test
    fun `Kalendersperre und Chipsperre werden vereinigt`() {
        val (e, _) = engine(laufendesFenster("p1"), chipLock = ChipLock("p2"))

        assertEquals(setOf("com.a", "com.b"), e.blockedPackages(jetzt))
    }

    @Test
    fun `vergangenes Fenster sperrt nichts`() {
        val alt = CalendarSettings(
            enabled = true,
            cachedWindows = listOf(
                CalendarWindow("e1", "Konzept", jetzt - 10 * minute, jetzt - minute, "p1"),
            ),
        )
        val (e, _) = engine(alt)

        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Profil mit laufendem Fenster ist nicht bearbeitbar`() {
        val (e, _) = engine(laufendesFenster())

        assertFalse(e.updateProfile(arbeit.copy(name = "Neu"), jetzt))
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Kalendersperre bearbeitbar`() {
        val (e, _) = engine(laufendesFenster("p1"))

        assertTrue(e.updateProfile(nacht.copy(name = "Neu"), jetzt))
    }

    @Test
    fun `waehrend einer Kalendersperre laesst sich kein Chip anlernen`() {
        val (e, _) = engine(laufendesFenster())

        assertFalse(e.enrollTag("04BB", "Neu", "p1", isMaster = false, now = jetzt))
    }

    @Test
    fun `normaler Chip beendet die Kalendersperre nicht`() {
        val (e, store) = engine(laufendesFenster("p1"), chipLock = ChipLock("p1"))

        val ergebnis = e.onTagScanned("04AA", jetzt)

        assertEquals(ScanOutcome.UNLOCKED, ergebnis.outcome)
        assertNull(store.current.chipLock)
        // Kalendersperre steht weiter
        assertEquals(setOf("com.a"), e.blockedPackages(jetzt))
    }

    @Test
    fun `Generalschluessel beendet die Kalendersperre und unterdrueckt sie`() {
        val (e, store) = engine(
            laufendesFenster("p1"),
            tags = listOf(TagBinding("04MM", "General", "p1", isMaster = true)),
        )

        val ergebnis = e.onTagScanned("04MM", jetzt)

        assertEquals(ScanOutcome.MASTER_CLEARED, ergebnis.outcome)
        assertEquals(jetzt + minute, store.current.calendar.suppressedUntil)
        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Notfall-Code beendet die Kalendersperre ebenfalls`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                codeHash = Hashing.sha256("ABCD2345"),
                calendar = laufendesFenster("p1"),
            )
        )
        val e = LockEngine(store)

        val ergebnis = e.submitCode("ABCD2345", jetzt)

        assertEquals(CodeOutcome.UNLOCKED, ergebnis.outcome)
        assertNotNull(store.current.calendar.suppressedUntil)
        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Unterdrueckung endet mit dem laufenden Fenster`() {
        val zweiFenster = CalendarSettings(
            enabled = true,
            cachedWindows = listOf(
                CalendarWindow("e1", "Jetzt", jetzt - minute, jetzt + minute, "p1"),
                CalendarWindow("e2", "Spaeter", jetzt + 5 * minute, jetzt + 9 * minute, "p1"),
            ),
            suppressedUntil = jetzt + minute,
        )
        val (e, _) = engine(zweiFenster)

        assertTrue(e.blockedPackages(jetzt).isEmpty())
        assertEquals(setOf("com.a"), e.blockedPackages(jetzt + 6 * minute))
    }

    @Test
    fun `Fenster schreiben legt sie ab und nagelt faellige Enden fest`() {
        val nagler = Profile("p1", "Arbeit", setOf("com.a"), pinCalendarEnd = true)
        val store = FakeLockStore(
            LockState(profiles = listOf(nagler), calendar = CalendarSettings(enabled = true))
        )
        val e = LockEngine(store)
        val fenster = listOf(CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1"))

        e.updateWindows(fenster, jetzt)

        assertEquals(fenster, store.current.calendar.cachedWindows)
        assertEquals(jetzt, store.current.calendar.windowsFetchedAt)
        assertEquals(mapOf("e1" to jetzt + minute), store.current.calendar.pinnedEnds)
    }

    @Test
    fun `festgenageltes Fenster sperrt weiter, wenn der Termin verschwindet`() {
        val nagler = Profile("p1", "Arbeit", setOf("com.a"), LockMode.OPEN, pinCalendarEnd = true)
        val store = FakeLockStore(
            LockState(profiles = listOf(nagler), calendar = CalendarSettings(enabled = true))
        )
        val e = LockEngine(store)
        val fenster = CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1")

        e.updateWindows(listOf(fenster), jetzt)
        // Termin im Kalender gelöscht: der nächste Abgleich bringt nichts mehr mit.
        e.updateWindows(emptyList(), jetzt)

        assertEquals(mapOf("e1" to jetzt + minute), store.current.calendar.pinnedEnds)
        assertEquals(setOf("com.a"), e.blockedPackages(jetzt))
    }

    @Test
    fun `abgelaufener Nagel haelt das Fenster nicht mehr fest`() {
        val nagler = Profile("p1", "Arbeit", setOf("com.a"), LockMode.OPEN, pinCalendarEnd = true)
        val store = FakeLockStore(
            LockState(profiles = listOf(nagler), calendar = CalendarSettings(enabled = true))
        )
        val e = LockEngine(store)
        val fenster = CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1")

        e.updateWindows(listOf(fenster), jetzt)
        e.updateWindows(emptyList(), jetzt + 2 * minute)

        assertTrue(store.current.calendar.pinnedEnds.isEmpty())
        assertTrue(store.current.calendar.cachedWindows.isEmpty())
    }

    @Test
    fun `Einstellungen schreiben laesst den Zwischenspeicher stehen`() {
        val (e, store) = engine(laufendesFenster())

        e.updateCalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Fokus]",
            keywordProfileId = "p2",
            keywordCalendarIds = setOf("cal2"),
        )

        assertEquals("[Fokus]", store.current.calendar.keywordMarker)
        assertEquals(
            mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            store.current.calendar.calendarRules,
        )
        assertEquals(setOf("cal2"), store.current.calendar.keywordCalendarIds)
        assertEquals(1, store.current.calendar.cachedWindows.size)
    }
}
