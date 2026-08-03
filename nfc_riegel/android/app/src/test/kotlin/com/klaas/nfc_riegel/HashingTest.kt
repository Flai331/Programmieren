package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class HashingTest {

    @Test
    fun `gleicher Text ergibt gleichen Hash`() {
        assertEquals(Hashing.sha256("ABCD1234"), Hashing.sha256("ABCD1234"))
    }

    @Test
    fun `anderer Text ergibt anderen Hash`() {
        assertNotEquals(Hashing.sha256("ABCD1234"), Hashing.sha256("ABCD1235"))
    }

    @Test
    fun `Hash ist 64 Hexzeichen lang`() {
        assertEquals(64, Hashing.sha256("test").length)
    }
}
