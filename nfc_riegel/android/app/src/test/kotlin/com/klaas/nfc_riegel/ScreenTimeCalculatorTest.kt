package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class ScreenTimeCalculatorTest {

    private val beginn = 1_000_000L
    private val ende = beginn + 60 * 60_000L
    private val minute = 60_000L

    private fun vorn(paket: String, t: Long) = UsageEvent(paket, UsageEventType.FOREGROUND, t)
    private fun hinten(paket: String, t: Long) = UsageEvent(paket, UsageEventType.BACKGROUND, t)
    private fun aus(t: Long) = UsageEvent("", UsageEventType.SCREEN_OFF, t)

    private fun summen(vararg events: UsageEvent) =
        ScreenTimeCalculator.totals(events.toList(), beginn, ende)

    @Test
    fun `einfacher Wechsel ergibt die Differenz`() {
        val s = summen(vorn("com.a", beginn + minute), hinten("com.a", beginn + 6 * minute))

        assertEquals(mapOf("com.a" to 5 * minute), s)
    }

    @Test
    fun `noch offene App zaehlt bis zum Fensterende`() {
        val s = summen(vorn("com.a", ende - 10 * minute))

        assertEquals(mapOf("com.a" to 10 * minute), s)
    }

    @Test
    fun `um Mitternacht offene App zaehlt ab dem Fensterbeginn`() {
        // Kein FOREGROUND im Fenster — die App lief schon vorher.
        val s = summen(hinten("com.a", beginn + 3 * minute))

        assertEquals(mapOf("com.a" to 3 * minute), s)
    }

    @Test
    fun `zweites BACKGROUND zaehlt nicht erneut`() {
        // ACTIVITY_PAUSED und ACTIVITY_STOPPED kommen oft beide.
        val s = summen(
            vorn("com.a", beginn + minute),
            hinten("com.a", beginn + 4 * minute),
            hinten("com.a", beginn + 4 * minute),
        )

        assertEquals(mapOf("com.a" to 3 * minute), s)
    }

    @Test
    fun `Bildschirm aus schliesst alles Offene`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            aus(beginn + 3 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `nach Bildschirm aus zaehlt erst ein neues FOREGROUND wieder`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            aus(beginn + 3 * minute),
            hinten("com.a", beginn + 30 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `zweites FOREGROUND ohne BACKGROUND zaehlt nicht doppelt`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            vorn("com.a", beginn + 2 * minute),
            hinten("com.a", beginn + 5 * minute),
        )

        assertEquals(mapOf("com.a" to 4 * minute), s)
    }

    @Test
    fun `Ereignis vor dem Fensterbeginn wird auf den Beginn geklemmt`() {
        val s = summen(vorn("com.a", beginn - 10 * minute), hinten("com.a", beginn + 2 * minute))

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `zwei Apps abwechselnd ergeben getrennte Summen`() {
        val s = summen(
            vorn("com.a", beginn),
            hinten("com.a", beginn + 2 * minute),
            vorn("com.b", beginn + 2 * minute),
            hinten("com.b", beginn + 5 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute, "com.b" to 3 * minute), s)
    }

    @Test
    fun `unsortierte Ereignisse werden nach Zeit verarbeitet`() {
        val s = summen(
            hinten("com.a", beginn + 5 * minute),
            vorn("com.a", beginn + minute),
        )

        assertEquals(mapOf("com.a" to 4 * minute), s)
    }

    @Test
    fun `leere Ereignisliste ergibt eine leere Karte`() {
        assertTrue(ScreenTimeCalculator.totals(emptyList(), beginn, ende).isEmpty())
    }

    private val reset = 15 * minute

    private fun sitzung(vararg events: UsageEvent, bis: Long = ende) =
        ScreenTimeCalculator.sessionMillis(events.toList(), "com.a", beginn, bis, reset)

    @Test
    fun `durchgehende Nutzung ergibt die Sitzungsdauer`() {
        val s = sitzung(
            vorn("com.a", ende - 10 * minute),
            hinten("com.a", ende - minute),
            bis = ende,
        )

        assertEquals(9 * minute, s)
    }

    @Test
    fun `kurze Unterbrechung zaehlt weiter`() {
        // Zwei Minuten raus, dann wieder rein: eine Sitzung, keine zwei.
        val s = sitzung(
            vorn("com.a", ende - 20 * minute),
            hinten("com.a", ende - 15 * minute),
            vorn("com.a", ende - 13 * minute),
            hinten("com.a", ende - minute),
            bis = ende,
        )

        assertEquals(5 * minute + 12 * minute, s)
    }

    @Test
    fun `lange Unterbrechung schneidet die aeltere Nutzung ab`() {
        val s = sitzung(
            vorn("com.a", beginn),
            hinten("com.a", beginn + 20 * minute),
            vorn("com.a", ende - 5 * minute),
            hinten("com.a", ende - minute),
            bis = ende,
        )

        assertEquals(4 * minute, s)
    }

    @Test
    fun `lange nicht mehr benutzt ergibt null`() {
        val s = sitzung(
            vorn("com.a", beginn),
            hinten("com.a", beginn + 5 * minute),
            bis = ende,
        )

        assertEquals(0L, s)
    }

    @Test
    fun `ohne Nutzung ergibt null`() {
        assertEquals(0L, sitzung(vorn("com.b", ende - minute)))
    }

    @Test
    fun `noch offene App zaehlt bis jetzt mit`() {
        val s = sitzung(vorn("com.a", ende - 3 * minute), bis = ende)

        assertEquals(3 * minute, s)
    }

    @Test
    fun `Mitternacht ist der Beginn des laufenden Tages`() {
        val zone = TimeZone.getTimeZone("Europe/Berlin")
        val kalender = Calendar.getInstance(zone).apply {
            set(2026, Calendar.AUGUST, 8, 14, 37, 12)
            set(Calendar.MILLISECOND, 400)
        }

        val mitternacht = ScreenTimeCalculator.startOfDay(kalender.timeInMillis, zone)

        val geprueft = Calendar.getInstance(zone).apply { timeInMillis = mitternacht }
        assertEquals(8, geprueft.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, geprueft.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, geprueft.get(Calendar.MINUTE))
        assertEquals(0, geprueft.get(Calendar.SECOND))
        assertEquals(0, geprueft.get(Calendar.MILLISECOND))
    }

    @Test
    fun `kurz nach Mitternacht bleibt es derselbe Tag`() {
        val zone = TimeZone.getTimeZone("Europe/Berlin")
        val kalender = Calendar.getInstance(zone).apply {
            set(2026, Calendar.AUGUST, 8, 0, 0, 30)
            set(Calendar.MILLISECOND, 0)
        }

        val mitternacht = ScreenTimeCalculator.startOfDay(kalender.timeInMillis, zone)

        assertEquals(30_000L, kalender.timeInMillis - mitternacht)
    }
}
