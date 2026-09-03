package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneNumbersTest {

    @Test
    fun `Normalisieren behaelt nur Ziffern`() {
        assertEquals("4901511234", PhoneNumbers.normalize("+49 (0)151 12-34"))
        assertEquals("", PhoneNumbers.normalize(null))
        assertEquals("", PhoneNumbers.normalize("unbekannt"))
    }

    @Test
    fun `dieselbe Nummer in verschiedenen Schreibweisen passt zusammen`() {
        assertTrue(PhoneNumbers.matches("+49 151 23456789", "0151 23456789"))
        assertTrue(PhoneNumbers.matches("0049151 23456789", "+4915123456789"))
        assertTrue(PhoneNumbers.matches("0151/234 567 89", "015123456789"))
    }

    @Test
    fun `verschiedene Nummern passen nicht`() {
        assertFalse(PhoneNumbers.matches("+49 151 23456789", "+49 151 23456780"))
        assertFalse(PhoneNumbers.matches("030 1234567", "040 7654321"))
    }

    @Test
    fun `kurze Nummern muessen ganz uebereinstimmen`() {
        assertTrue(PhoneNumbers.matches("110", "110"))
        assertFalse(PhoneNumbers.matches("110", "0151110"))
    }

    @Test
    fun `leere Nummer passt auf nichts`() {
        assertFalse(PhoneNumbers.matches("", ""))
        assertFalse(PhoneNumbers.contains(setOf("015123456789"), null))
        assertFalse(PhoneNumbers.contains(setOf("015123456789"), ""))
    }

    @Test
    fun `contains findet die Nummer in der Auswahl`() {
        val auswahl = setOf("015123456789", "03012345678")

        assertTrue(PhoneNumbers.contains(auswahl, "+49 151 23456789"))
        assertFalse(PhoneNumbers.contains(auswahl, "+49 171 99988877"))
    }
}
