package com.klaas.nfc_riegel

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockCodecTest {

    /** FIELD aus LockCodec. */
    private val FELD = ""

    /**
     * Ein Profilsatz mit genau [felder] Feldern — der Stand einer früheren
     * Ausbaustufe. Aus `encodeProfiles` erzeugt statt von Hand geschrieben,
     * damit der Aufbau nicht auseinanderläuft, und über die Feldzahl
     * abgeschnitten statt über „das letzte Feld weg": sonst bricht jedes neu
     * angehängte Feld die älteren Fälle.
     */
    private fun satzMit(profil: Profile, felder: Int): String {
        val teile = LockCodec.encodeProfiles(listOf(profil)).split(FELD)
        require(felder <= teile.size) {
            "Der Kodierer schreibt nur ${teile.size} Felder, verlangt sind $felder"
        }
        return teile.take(felder).joinToString(FELD)
    }

    @Test
    fun `Profile ueberstehen Kodieren und Dekodieren`() {
        val profiles = listOf(
            Profile("p1", "Arbeit", setOf("com.a", "com.b"), LockMode.TIMER, 45, null, false),
            Profile("p2", "Nacht", emptySet(), LockMode.UNTIL, 60, 1_700_000_000_000, true),
        )

        val decoded = LockCodec.decodeProfiles(LockCodec.encodeProfiles(profiles))

        assertEquals(profiles, decoded)
    }

    @Test
    fun `Chips ueberstehen Kodieren und Dekodieren`() {
        val tags = listOf(
            TagBinding("04AA", "Schreibtisch", "p1"),
            TagBinding("04BB", "Schlüsselbund", "p2"),
        )

        assertEquals(tags, LockCodec.decodeTags(LockCodec.encodeTags(tags)))
    }

    @Test
    fun `alter Chipsatz mit Generalschluessel-Merkmal bleibt lesbar`() {
        // Vier Felder, wie vor dem Wegfall des Generalschluessels abgelegt. Das
        // Merkmal faellt weg, der Chip bleibt.
        val alt = listOf("04BB", "Schlüsselbund", "p2", "1").joinToString("")

        assertEquals(listOf(TagBinding("04BB", "Schlüsselbund", "p2")), LockCodec.decodeTags(alt))
    }

    @Test
    fun `leere Liste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeProfiles(emptyList()))
        assertTrue(LockCodec.decodeProfiles("").isEmpty())
        assertTrue(LockCodec.decodeTags("").isEmpty())
    }

    @Test
    fun `Chipsperre uebersteht Kodieren und Dekodieren`() {
        val lock = ChipLock("p1")

        assertEquals(lock, LockCodec.decodeChipLock(LockCodec.encodeChipLock(lock)))
    }

    @Test
    fun `null-Chipsperre bleibt null`() {
        assertEquals(null, LockCodec.decodeChipLock(LockCodec.encodeChipLock(null)))
    }

    @Test
    fun `kaputte Eingabe ergibt leere Liste statt Absturz`() {
        assertTrue(LockCodec.decodeProfiles("völliger Unsinn").isEmpty())
    }

    @Test
    fun `Zeitsperren ueberstehen Hin- und Rueckwandlung`() {
        val locks = listOf(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            TimeLock("p2", LockMode.UNTIL, 1_700_000_600_000),
        )
        assertEquals(locks, LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(locks)))
    }

    @Test
    fun `leere Zeitsperrenliste bleibt leer`() {
        assertEquals(
            emptyList<TimeLock>(),
            LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(emptyList())),
        )
    }

    @Test
    fun `Zeitsperre ohne Endzeitpunkt wird verworfen`() {
        val kaputt = "p1" + '' + "TIMER" + '' + "keineZahl"
        assertEquals(emptyList<TimeLock>(), LockCodec.decodeTimeLocks(kaputt))
    }

    @Test
    fun `v2-Datensatz mit OPEN bleibt eine Chipsperre`() {
        val alt = "p1" + '' + "OPEN" + '' + ""
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock(alt))
        assertNull(LockCodec.decodeLegacyTimeLock(alt))
    }

    @Test
    fun `v2-Datensatz mit TIMER wird zur Zeitsperre`() {
        val alt = "p1" + '' + "TIMER" + '' + "1700000000000"
        assertNull(LockCodec.decodeChipLock(alt))
        assertEquals(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            LockCodec.decodeLegacyTimeLock(alt),
        )
    }

    @Test
    fun `v3-Datensatz besteht nur aus der Profil-Kennung`() {
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock("p1"))
        assertNull(LockCodec.decodeLegacyTimeLock("p1"))
    }

    @Test
    fun `Terminfenster ueberstehen Kodieren und Dekodieren`() {
        val fenster = listOf(
            CalendarWindow("e1", "Konzept schreiben", 1_000L, 2_000L, "p1"),
            CalendarWindow("e2", "Sport", 3_000L, 4_000L, "p2"),
        )

        val zurueck = LockCodec.decodeWindows(LockCodec.encodeWindows(fenster))

        assertEquals(fenster, zurueck)
    }

    @Test
    fun `leere Fensterliste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeWindows(emptyList()))
        assertTrue(LockCodec.decodeWindows("").isEmpty())
    }

    @Test
    fun `Kalendereinstellungen ueberstehen Kodieren und Dekodieren`() {
        val einstellungen = CalendarSettings(
            enabled = true,
            calendarRules = mapOf(
                "cal1" to CalendarRule("p1", CalendarMatch.ALL),
                "cal2" to CalendarRule("p2", CalendarMatch.KEYWORD),
            ),
            keywordMarker = "[Fokus]",
            keywordProfileId = "p2",
            keywordCalendarIds = setOf("cal3", "cal4"),
            cachedWindows = listOf(CalendarWindow("e1", "Termin", 1_000L, 2_000L, "p1")),
            windowsFetchedAt = 5_000L,
            pinnedEnds = mapOf("e1" to 2_000L),
            suppressedUntil = 9_000L,
        )

        val zurueck = LockCodec.decodeCalendar(LockCodec.encodeCalendar(einstellungen))

        assertEquals(einstellungen, zurueck)
    }

    @Test
    fun `leere Stichwort-Kalenderliste bleibt leer`() {
        val einstellungen = CalendarSettings(enabled = true, keywordCalendarIds = emptySet())

        val zurueck = LockCodec.decodeCalendar(LockCodec.encodeCalendar(einstellungen))

        assertTrue(zurueck.keywordCalendarIds.isEmpty())
    }

    @Test
    fun `unbekannte Trefferart faellt auf ALL zurueck`() {
        val roh = LockCodec.encodeCalendar(
            CalendarSettings(calendarRules = mapOf("cal1" to CalendarRule("p1")))
        ).replace("ALL", "QUATSCH")

        val zurueck = LockCodec.decodeCalendar(roh)

        assertEquals(CalendarMatch.ALL, zurueck.calendarRules.getValue("cal1").match)
    }

    @Test
    fun `Kalendereinstellungen ohne Angaben ergeben die Vorgaben`() {
        val zurueck = LockCodec.decodeCalendar("")

        assertEquals(CalendarSettings(), zurueck)
    }

    @Test
    fun `Termintitel mit Sonderzeichen ueberlebt den Rundlauf`() {
        val fenster = listOf(CalendarWindow("e1", "Team-Meeting: Q4 (wichtig!)", 1L, 2L, "p1"))

        assertEquals(fenster, LockCodec.decodeWindows(LockCodec.encodeWindows(fenster)))
    }

    @Test
    fun `Atempause-Einstellungen ueberstehen Kodieren und Dekodieren`() {
        val profile = listOf(
            Profile(
                id = "p1",
                name = "Arbeit",
                blockedPackages = setOf("com.a"),
                defaultMode = LockMode.TIMER,
                durationMinutes = 45,
                pause = PauseSettings(enabled = true, stepMinutes = 20, baseSeconds = 8),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `Klingelmodus uebersteht Kodieren und Dekodieren`() {
        val profile = listOf(
            Profile(
                id = "p1",
                name = "Nacht",
                quiet = QuietSettings(enabled = true, ringer = RingerMode.VIBRIEREN),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `ein Profilsatz ohne Klingelmodus liest sich als unveraendert`() {
        // Achtzehn Felder — der Stand aus Build 18. Geprüft wird das ganze
        // Profil, nicht nur der Modus: sonst stünde nirgends, dass ein solcher
        // Satz auch sonst noch heil ankommt.
        val quiet = QuietSettings(enabled = true, whileLocked = false, afterEventMinutes = 20)
        val vorher = Profile(
            id = "p1",
            name = "Nacht",
            blockedPackages = setOf("com.a"),
            durationMinutes = 45,
            timedRelease = true,
            quiet = quiet,
        )

        val zurueck = LockCodec.decodeProfiles(satzMit(vorher, felder = 18)).single()

        assertEquals(vorher.copy(quiet = quiet.copy(ringer = RingerMode.UNVERAENDERT)), zurueck)
    }

    @Test
    fun `ein unbekannter Klingelmodus liest sich als unveraendert`() {
        val roh = satzMit(
            Profile(
                id = "p1",
                name = "Nacht",
                quiet = QuietSettings(enabled = true, ringer = RingerMode.LAUTLOS),
            ),
            felder = 18,
        ) + FELD + "FLUESTERN"

        val zurueck = LockCodec.decodeProfiles(roh).single()

        assertEquals(RingerMode.UNVERAENDERT, zurueck.quiet.ringer)
    }

    @Test
    fun `alter Profilsatz ohne Atempause bleibt lesbar`() {
        // Sieben Felder, wie vor der Atempause abgelegt.
        val alt = listOf("p1", "Arbeit", "com.a", "TIMER", "45", "", "0")
            .joinToString("")

        val zurueck = LockCodec.decodeProfiles(alt)

        assertEquals(1, zurueck.size)
        assertEquals("Arbeit", zurueck[0].name)
        assertEquals(PauseSettings(), zurueck[0].pause)
    }

    @Test
    fun `Ruhe uebersteht Kodieren und Dekodieren`() {
        val profile = listOf(
            Profile(
                id = "p1",
                name = "Arbeit",
                quiet = QuietSettings(
                    enabled = true,
                    scope = QuietScope.ALLE_AUSSER,
                    numbers = setOf("015123456789", "03012345678"),
                    afterEventMinutes = 15,
                    whileLocked = false,
                    schedules = listOf(
                        QuietSchedule(setOf(Calendar.MONDAY, Calendar.FRIDAY), 22 * 60, 6 * 60),
                        QuietSchedule(setOf(Calendar.SUNDAY), 0, 12 * 60),
                    ),
                ),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `Atempause bleibt neben der Ruhe erhalten`() {
        val profile = listOf(
            Profile(
                id = "p1",
                name = "Arbeit",
                pause = PauseSettings(
                    enabled = true,
                    stepMinutes = 7,
                    baseSeconds = 9,
                    resetMinutes = 11,
                ),
                quiet = QuietSettings(enabled = true),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `Profilsatz mit Atempause aber ohne Ruhe bleibt lesbar`() {
        // Elf Felder, wie vor der Ruhe abgelegt.
        val alt = listOf("p1", "Arbeit", "com.a", "TIMER", "45", "", "0", "1", "20", "8", "12")
            .joinToString("")

        val zurueck = LockCodec.decodeProfiles(alt)

        assertEquals(1, zurueck.size)
        assertEquals(20, zurueck[0].pause.stepMinutes)
        assertEquals(12, zurueck[0].pause.resetMinutes)
        assertEquals(QuietSettings(), zurueck[0].quiet)
    }

    @Test
    fun `Freigabe wird geschrieben und gelesen`() {
        val roh = LockCodec.encodeRelease(Release("p1", 1_700_000_000_000L))

        assertEquals(Release("p1", 1_700_000_000_000L), LockCodec.decodeRelease(roh))
    }

    @Test
    fun `leerer Eintrag ist keine Freigabe`() {
        assertNull(LockCodec.decodeRelease(""))
        assertNull(LockCodec.decodeRelease(LockCodec.encodeRelease(null)))
    }

    @Test
    fun `kaputter Eintrag ist keine Freigabe`() {
        // Beide Fehlerwege: zu wenige Felder und ein Ende, das keine Zahl ist.
        assertNull(LockCodec.decodeRelease("p1"))
        assertNull(LockCodec.decodeRelease("p1\u0002irgendwann"))
    }

    @Test
    fun `Freigabe auf Zeit ueberlebt Schreiben und Lesen`() {
        val p = Profile(id = "p1", name = "Arbeit", timedRelease = true)

        val gelesen = LockCodec.decodeProfiles(LockCodec.encodeProfiles(listOf(p)))

        assertEquals(true, gelesen.single().timedRelease)
    }

    @Test
    fun `Profil ohne das neue Feld hat keine Freigabe auf Zeit`() {
        // Siebzehn Felder — der Stand vor der Freigabe auf Zeit.
        val ohneFeld = satzMit(
            Profile(id = "p1", name = "Arbeit", timedRelease = true),
            felder = 17,
        )

        val gelesen = LockCodec.decodeProfiles(ohneFeld)

        assertEquals(1, gelesen.size)
        assertEquals(false, gelesen.single().timedRelease)
    }

    @Test
    fun `Kalenderauswahl am Profil uebersteht Kodieren und Dekodieren`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL, "7" to CalendarMatch.KEYWORD),
            keywordEverywhere = true,
        )

        val zurueck = LockCodec.decodeProfiles(LockCodec.encodeProfiles(listOf(profil))).single()

        assertEquals(profil, zurueck)
    }

    @Test
    fun `Profil mit neunzehn Feldern bekommt keine Kalenderauswahl`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL),
            keywordEverywhere = true,
        )

        val zurueck = LockCodec.decodeProfiles(satzMit(profil, felder = 19)).single()

        assertEquals(profil.copy(calendars = emptyMap(), keywordEverywhere = false), zurueck)
    }

    @Test
    fun `Profil mit zwanzig Feldern ist kein gueltiger Satz`() {
        val profil = Profile("p1", "Arbeit", calendars = mapOf("3" to CalendarMatch.ALL))

        assertTrue(LockCodec.decodeProfiles(satzMit(profil, felder = 20)).isEmpty())
    }

    @Test
    fun `unbekannte Trefferart am Profil wird verworfen`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL, "7" to CalendarMatch.KEYWORD),
        )
        val roh = LockCodec.encodeProfiles(listOf(profil)).replace("KEYWORD", "QUATSCH")

        assertEquals(
            mapOf("3" to CalendarMatch.ALL),
            LockCodec.decodeProfiles(roh).single().calendars,
        )
    }
}
