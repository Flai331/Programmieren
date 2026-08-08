package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CalendarPlannerTest {

    private val jetzt = 1_000_000L
    private val minute = 60_000L

    private fun fenster(
        id: String = "e1",
        von: Long = jetzt - minute,
        bis: Long = jetzt + minute,
        profil: String = "p1",
    ) = CalendarWindow(id, "Termin $id", von, bis, profil)

    private fun einstellungen(
        vararg fenster: CalendarWindow,
        an: Boolean = true,
        unterdruecktBis: Long? = null,
        festgenagelt: Map<String, Long> = emptyMap(),
    ) = CalendarSettings(
        enabled = an,
        cachedWindows = fenster.toList(),
        suppressedUntil = unterdruecktBis,
        pinnedEnds = festgenagelt,
    )

    @Test
    fun `laufendes Fenster sperrt`() {
        val aktiv = CalendarPlanner.activeWindows(einstellungen(fenster()), jetzt)

        assertEquals(listOf("e1"), aktiv.map { it.eventId })
    }

    @Test
    fun `vergangenes Fenster sperrt nicht`() {
        val alt = fenster(von = jetzt - 10 * minute, bis = jetzt - minute)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(alt), jetzt).isEmpty())
    }

    @Test
    fun `kuenftiges Fenster sperrt nicht`() {
        val spaeter = fenster(von = jetzt + minute, bis = jetzt + 10 * minute)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(spaeter), jetzt).isEmpty())
    }

    @Test
    fun `Fenster genau am Ende sperrt nicht mehr`() {
        val endetJetzt = fenster(von = jetzt - minute, bis = jetzt)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(endetJetzt), jetzt).isEmpty())
    }

    @Test
    fun `ausgeschaltete Kalenderfunktion sperrt nie`() {
        val aus = einstellungen(fenster(), an = false)

        assertTrue(CalendarPlanner.activeWindows(aus, jetzt).isEmpty())
    }

    @Test
    fun `zwei ueberlappende Fenster gelten beide`() {
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val aktiv = CalendarPlanner.activeWindows(einstellungen(a, b), jetzt)

        assertEquals(setOf("e1", "e2"), aktiv.map { it.eventId }.toSet())
    }

    @Test
    fun `Unterdrueckung schaltet das laufende Fenster ab`() {
        val e = einstellungen(fenster(), unterdruecktBis = jetzt + minute)

        assertTrue(CalendarPlanner.activeWindows(e, jetzt).isEmpty())
    }

    @Test
    fun `Unterdrueckung laesst das naechste Fenster unberuehrt`() {
        val laufend = fenster(id = "e1", von = jetzt - minute, bis = jetzt + minute)
        val spaeter = fenster(id = "e2", von = jetzt + 2 * minute, bis = jetzt + 3 * minute)
        val e = einstellungen(laufend, spaeter, unterdruecktBis = jetzt + minute)

        val aktiv = CalendarPlanner.activeWindows(e, jetzt + 2 * minute + 1)

        assertEquals(listOf("e2"), aktiv.map { it.eventId })
    }

    @Test
    fun `festgenageltes Ende gilt auch wenn der Termin verschwunden ist`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt + minute))

        val aktiv = CalendarPlanner.activeWindows(e, jetzt)

        assertEquals(listOf("e1"), aktiv.map { it.eventId })
    }

    @Test
    fun `festgenageltes Ende schlaegt ein vorgezogenes Ende im Kalender`() {
        val verkuerzt = fenster(bis = jetzt - minute)
        val e = einstellungen(verkuerzt, festgenagelt = mapOf("e1" to jetzt + minute))

        assertEquals(listOf("e1"), CalendarPlanner.activeWindows(e, jetzt).map { it.eventId })
    }

    @Test
    fun `abgelaufenes festgenageltes Ende sperrt nicht mehr`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt - 1))

        assertTrue(CalendarPlanner.activeWindows(e, jetzt).isEmpty())
    }

    @Test
    fun `gesperrte Profile stammen aus den laufenden Fenstern`() {
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val profile = CalendarPlanner.lockedProfileIds(einstellungen(a, b), jetzt)

        assertEquals(setOf("p1", "p2"), profile)
    }

    @Test
    fun `ohne laufendes Fenster gibt es kein gesperrtes Profil`() {
        assertTrue(CalendarPlanner.lockedProfileIds(einstellungen(), jetzt).isEmpty())
    }

    @Test
    fun `festzunagelnde Enden entstehen nur fuer Profile mit pinCalendarEnd`() {
        val mitNagel = Profile("p1", "Arbeit", pinCalendarEnd = true)
        val ohneNagel = Profile("p2", "Nacht", pinCalendarEnd = false)
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val neu = CalendarPlanner.pinsToAdd(
            einstellungen(a, b),
            listOf(mitNagel, ohneNagel),
            jetzt,
        )

        assertEquals(mapOf("e1" to jetzt + minute), neu)
    }

    @Test
    fun `bereits festgenagelte Fenster werden nicht neu genagelt`() {
        val mitNagel = Profile("p1", "Arbeit", pinCalendarEnd = true)
        val a = fenster(id = "e1", profil = "p1")
        val e = einstellungen(a, festgenagelt = mapOf("e1" to jetzt + 5 * minute))

        assertTrue(CalendarPlanner.pinsToAdd(e, listOf(mitNagel), jetzt).isEmpty())
    }

    @Test
    fun `vergangene Naegel werden aufgeraeumt`() {
        val e = einstellungen(
            festgenagelt = mapOf("alt" to jetzt - 1, "neu" to jetzt + minute),
        )

        assertEquals(mapOf("neu" to jetzt + minute), CalendarPlanner.prunePins(e, jetzt))
    }

    @Test
    fun `naechste Grenze ist der Beginn des naechsten Fensters`() {
        val spaeter = fenster(von = jetzt + 5 * minute, bis = jetzt + 10 * minute)

        val grenze = CalendarPlanner.nextBoundary(einstellungen(spaeter), jetzt)

        assertEquals(jetzt + 5 * minute, grenze)
    }

    @Test
    fun `naechste Grenze ist das Ende des laufenden Fensters`() {
        val grenze = CalendarPlanner.nextBoundary(einstellungen(fenster()), jetzt)

        assertEquals(jetzt + minute, grenze)
    }

    @Test
    fun `naechste Grenze nimmt die frueheste von mehreren`() {
        val a = fenster(id = "e1", von = jetzt - minute, bis = jetzt + 3 * minute)
        val b = fenster(id = "e2", von = jetzt + minute, bis = jetzt + 9 * minute)

        assertEquals(jetzt + minute, CalendarPlanner.nextBoundary(einstellungen(a, b), jetzt))
    }

    @Test
    fun `ohne Fenster gibt es keine Grenze`() {
        assertNull(CalendarPlanner.nextBoundary(einstellungen(), jetzt))
    }

    @Test
    fun `bei ausgeschalteter Kalenderfunktion gibt es keine Grenze`() {
        assertNull(CalendarPlanner.nextBoundary(einstellungen(fenster(), an = false), jetzt))
    }

    @Test
    fun `festgenageltes Ende zaehlt als Grenze`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt + 2 * minute))

        assertEquals(jetzt + 2 * minute, CalendarPlanner.nextBoundary(e, jetzt))
    }

    @Test
    fun `Kalender auf ALL sperrt mit jedem Termin`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.ALL)),
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalender auf KEYWORD sperrt nur bei Treffer`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Riegel]",
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "[Riegel] Konzept"))
        assertNull(CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalenderregel schlaegt die Stichwortregel`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.ALL)),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "[Riegel] Sport"))
    }

    @Test
    fun `Kalender auf KEYWORD ohne Treffer faellt auf die Stichwortregel zurueck`() {
        // cal1 sucht nach dem Marker, die eigenständige Regel nach demselben in
        // allen Kalendern — hier greift sie nicht, weil der Titel nichts trifft.
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
        )

        assertNull(CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Stichwortregel greift ohne Kalenderauswahl ueberall`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1")),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
            keywordCalendarIds = emptySet(),
        )

        assertEquals("p9", CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
    }

    @Test
    fun `Stichwortregel sucht nur in den ausgewaehlten Kalendern`() {
        val c = CalendarSettings(
            enabled = true,
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
            keywordCalendarIds = setOf("cal2"),
        )

        assertEquals("p9", CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
        assertNull(CalendarPlanner.profileForEvent(c, "cal3", "[Riegel] Sport"))
    }

    @Test
    fun `Termin ohne Regel und ohne Stichwort sperrt nicht`() {
        val c = CalendarSettings(enabled = true, keywordProfileId = "p9")

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "Zahnarzt"))
    }

    @Test
    fun `Stichwort ohne hinterlegtes Profil sperrt nicht`() {
        val c = CalendarSettings(enabled = true, keywordProfileId = null)

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
    }

    @Test
    fun `leerer Marker trifft nie`() {
        val c = CalendarSettings(
            enabled = true,
            keywordMarker = "",
            keywordProfileId = "p9",
        )

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "Irgendein Termin"))
    }
}
