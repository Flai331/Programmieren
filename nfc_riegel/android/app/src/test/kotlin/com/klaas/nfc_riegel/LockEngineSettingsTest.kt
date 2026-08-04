package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineSettingsTest {

    private val arbeit = Profile("p1", "Arbeit", setOf("com.a"))
    private val nacht = Profile("p2", "Nacht", setOf("com.b"))

    private fun engine(lock: ChipLock? = null): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = lock,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `Profil anlegen haengt es hinten an`() {
        val (e, store) = engine()

        val created = e.addProfile("Lernen")

        assertEquals(3, store.current.profiles.size)
        assertEquals("Lernen", store.current.profiles.last().name)
        assertNotNull(created)
    }

    @Test
    fun `Profil bearbeiten speichert`() {
        val (e, store) = engine()

        val ok = e.updateProfile(arbeit.copy(name = "Fokus", durationMinutes = 90))

        assertTrue(ok)
        assertEquals("Fokus", store.current.profileById("p1")!!.name)
        assertEquals(90, store.current.profileById("p1")!!.durationMinutes)
    }

    @Test
    fun `sperrendes Profil ist nicht bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        val ok = e.updateProfile(arbeit.copy(name = "Fokus"))

        assertFalse(ok)
        assertEquals("Arbeit", store.current.profileById("p1")!!.name)
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Sperre bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        val ok = e.updateProfile(nacht.copy(name = "Schlaf"))

        assertTrue(ok)
        assertEquals("Schlaf", store.current.profileById("p2")!!.name)
    }

    @Test
    fun `Profil loeschen zieht zugeordnete Chips auf das erste verbleibende`() {
        val (e, store) = engine()

        val ok = e.deleteProfile("p1")

        assertTrue(ok)
        assertNull(store.current.profileById("p1"))
        assertEquals("p2", store.current.tags.first().profileId)
    }

    @Test
    fun `letztes Profil laesst sich nicht loeschen`() {
        val store = FakeLockStore(LockState(profiles = listOf(arbeit)))
        val e = LockEngine(store)

        assertFalse(e.deleteProfile("p1"))
        assertEquals(1, store.current.profiles.size)
    }

    @Test
    fun `sperrendes Profil laesst sich nicht loeschen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        assertFalse(e.deleteProfile("p1"))
        assertNotNull(store.current.profileById("p1"))
    }

    @Test
    fun `Chip anlernen haengt ihn an`() {
        val (e, store) = engine()

        val ok = e.enrollTag("04BB", "Bett", "p2", isMaster = false)

        assertTrue(ok)
        assertEquals(2, store.current.tags.size)
    }

    @Test
    fun `bekannte UID wird aktualisiert statt doppelt angelegt`() {
        val (e, store) = engine()

        e.enrollTag("04aa", "Neu", "p2", isMaster = true)

        assertEquals(1, store.current.tags.size)
        assertEquals("Neu", store.current.tags.first().label)
        assertEquals("p2", store.current.tags.first().profileId)
        assertTrue(store.current.tags.first().isMaster)
    }

    @Test
    fun `Chips sind waehrend einer Sperre gesperrt`() {
        val (e, store) = engine(ChipLock("p2", LockMode.OPEN))

        assertFalse(e.enrollTag("04BB", "Bett", "p1", isMaster = false))
        assertFalse(e.deleteTag("04AA"))
        assertEquals(1, store.current.tags.size)
    }

    @Test
    fun `Chip loeschen entfernt ihn`() {
        val (e, store) = engine()

        assertTrue(e.deleteTag("04AA"))
        assertTrue(store.current.tags.isEmpty())
    }

    @Test
    fun `Code erzeugen liefert acht Zeichen und speichert nur den Hash`() {
        val (e, store) = engine()

        val code = e.generateCode()

        assertNotNull(code)
        assertEquals(8, code!!.length)
        assertEquals(Hashing.sha256(code), store.current.codeHash)
    }

    @Test
    fun `Code laesst sich waehrend einer Sperre nicht neu erzeugen`() {
        val (e, _) = engine(ChipLock("p1", LockMode.OPEN))

        assertNull(e.generateCode())
    }

    @Test
    fun `erzeugter Code enthaelt nur erlaubte Zeichen`() {
        val (e, _) = engine()

        assertTrue(e.generateCode()!!.all { it in LockEngine.CODE_ALPHABET })
    }
}
