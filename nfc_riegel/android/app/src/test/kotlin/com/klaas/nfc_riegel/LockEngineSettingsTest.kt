package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineSettingsTest {

    @Test
    fun `Blockliste wird gespeichert`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.setBlockedPackages(setOf("com.a", "com.b"))

        assertEquals(setOf("com.a", "com.b"), store.current.blockedPackages)
    }

    @Test
    fun `Modus und Dauer werden gespeichert`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.setMode(LockMode.OPEN, 90)

        assertEquals(LockMode.OPEN, store.current.mode)
        assertEquals(90, store.current.durationMinutes)
    }

    @Test
    fun `Einstellungen sind waehrend einer Sperre gesperrt`() {
        val store = FakeLockStore(LockState(locked = true))
        val engine = LockEngine(store)

        val ok = engine.setBlockedPackages(setOf("com.a"))

        assertEquals(false, ok)
        assertTrue(store.current.blockedPackages.isEmpty())
    }

    @Test
    fun `Chip anlernen speichert die UID`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.enrollTag("04A2B3")

        assertEquals("04A2B3", store.current.tagUid)
    }

    @Test
    fun `Code erzeugen liefert acht Zeichen und speichert nur den Hash`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        val code = engine.generateCode()

        assertEquals(8, code.length)
        assertEquals(Hashing.sha256(code), store.current.codeHash)
        assertNotNull(store.current.codeHash)
    }

    @Test
    fun `erzeugter Code enthaelt nur erlaubte Zeichen`() {
        val engine = LockEngine(FakeLockStore())

        val code = engine.generateCode()

        assertTrue(code.all { it in LockEngine.CODE_ALPHABET })
    }
}
