package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PausePlannerTest {

    private val minute = 60_000L
    private val standard = PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 5)

    private fun entscheide(genutzteMinuten: Long, zuletzt: Int = 0) =
        PausePlanner.decide(standard, genutzteMinuten * minute, zuletzt)

    @Test
    fun `unterhalb der ersten Stufe keine Pause`() {
        val e = entscheide(14)

        assertNull(e.waitSeconds)
        assertEquals(0, e.step)
        assertEquals(minute, e.nextCheckAfterMillis)
    }

    @Test
    fun `genau auf der Stufe kommt die Pause`() {
        val e = entscheide(15)

        assertEquals(5, e.waitSeconds)
        assertEquals(1, e.step)
    }

    @Test
    fun `Wartezeit verdoppelt sich je Stufe`() {
        assertEquals(5, entscheide(15).waitSeconds)
        assertEquals(10, entscheide(30).waitSeconds)
        assertEquals(20, entscheide(45).waitSeconds)
        assertEquals(40, entscheide(60).waitSeconds)
    }

    @Test
    fun `Wartezeit ist bei einer Minute gedeckelt`() {
        assertEquals(60, entscheide(75).waitSeconds)
        assertEquals(60, entscheide(600).waitSeconds)
    }

    @Test
    fun `mehrere Stufen auf einmal ergeben eine Pause mit der hoechsten Wartezeit`() {
        // Berechtigung spät erteilt: aus dem Nichts stehen zwei Stunden da.
        val e = entscheide(120, zuletzt = 0)

        assertEquals(60, e.waitSeconds)
        assertEquals(8, e.step)
    }

    @Test
    fun `bereits gezeigte Stufe loest nicht erneut aus`() {
        val e = entscheide(20, zuletzt = 1)

        assertNull(e.waitSeconds)
        assertEquals(10 * minute, e.nextCheckAfterMillis)
    }

    @Test
    fun `ausgeschaltet loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(enabled = false), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `Stufenabstand null loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(stepMinutes = 0), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `negativer Stufenabstand loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(stepMinutes = -5), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `naechster Blick zaehlt bis zur naechsten Stufengrenze`() {
        assertEquals(15 * minute, entscheide(15, zuletzt = 1).nextCheckAfterMillis)
        assertEquals(5 * minute, entscheide(25, zuletzt = 1).nextCheckAfterMillis)
    }

    @Test
    fun `mehrere Profile ergeben den kleinsten Abstand und die laengste Wartezeit`() {
        val zusammen = PausePlanner.merge(
            listOf(
                PauseSettings(enabled = true, stepMinutes = 30, baseSeconds = 5),
                PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 8),
            )
        )

        assertEquals(PauseSettings(true, 15, 8), zusammen)
    }

    @Test
    fun `ausgeschaltete Profile zaehlen beim Zusammenfuehren nicht mit`() {
        assertNull(
            PausePlanner.merge(
                listOf(PauseSettings(enabled = false, stepMinutes = 5, baseSeconds = 30))
            )
        )
        assertEquals(
            PauseSettings(true, 15, 5),
            PausePlanner.merge(
                listOf(
                    PauseSettings(enabled = false, stepMinutes = 5, baseSeconds = 30),
                    PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 5),
                )
            ),
        )
    }
}
