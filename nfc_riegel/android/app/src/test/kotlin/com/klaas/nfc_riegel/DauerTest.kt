package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class DauerTest {

    private fun zeitpunkt(stunde: Int, minute: Int): Long {
        val c = Calendar.getInstance(TimeZone.getTimeZone("Europe/Berlin"), Locale.GERMANY)
        c.set(2026, Calendar.SEPTEMBER, 24, stunde, minute, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    @Test
    fun `Endzeit ist jetzt plus Minuten`() {
        assertEquals("16:24", endeUhrzeit(zeitpunkt(15, 54), 30))
    }

    @Test
    fun `Endzeit geht ueber die volle Stunde`() {
        assertEquals("09:05", endeUhrzeit(zeitpunkt(8, 55), 10))
    }

    @Test
    fun `Endzeit geht ueber Mitternacht`() {
        assertEquals("00:10", endeUhrzeit(zeitpunkt(23, 55), 15))
    }
}
