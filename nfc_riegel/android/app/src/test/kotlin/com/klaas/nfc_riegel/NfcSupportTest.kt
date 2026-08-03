package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test

class NfcSupportTest {

    @Test
    fun `Bytes werden als Grossbuchstaben-Hex ausgegeben`() {
        val bytes = byteArrayOf(0x04, 0xA2.toByte(), 0x0B)
        assertEquals("04A20B", NfcSupport.toHex(bytes))
    }

    @Test
    fun `fuehrende Null bleibt erhalten`() {
        assertEquals("0F", NfcSupport.toHex(byteArrayOf(0x0F)))
    }

    @Test
    fun `leeres Array ergibt leeren String`() {
        assertEquals("", NfcSupport.toHex(byteArrayOf()))
    }
}
