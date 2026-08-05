package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineSettingsTest {

    private val now = 1_000_000L
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

    private fun engineMitZeitsperre(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                timeLocks = locks.toList(),
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

        val ok = e.updateProfile(arbeit.copy(name = "Fokus", durationMinutes = 90), now)

        assertTrue(ok)
        assertEquals("Fokus", store.current.profileById("p1")!!.name)
        assertEquals(90, store.current.profileById("p1")!!.durationMinutes)
    }

    @Test
    fun `sperrendes Profil ist nicht bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1"))

        val ok = e.updateProfile(arbeit.copy(name = "Fokus"), now)

        assertFalse(ok)
        assertEquals("Arbeit", store.current.profileById("p1")!!.name)
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Sperre bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1"))

        val ok = e.updateProfile(nacht.copy(name = "Schlaf"), now)

        assertTrue(ok)
        assertEquals("Schlaf", store.current.profileById("p2")!!.name)
    }

    @Test
    fun `Profil loeschen zieht zugeordnete Chips auf das erste verbleibende`() {
        val (e, store) = engine()

        val ok = e.deleteProfile("p1", now)

        assertTrue(ok)
        assertNull(store.current.profileById("p1"))
        assertEquals("p2", store.current.tags.first().profileId)
    }

    @Test
    fun `letztes Profil laesst sich nicht loeschen`() {
        val store = FakeLockStore(LockState(profiles = listOf(arbeit)))
        val e = LockEngine(store)

        assertFalse(e.deleteProfile("p1", now))
        assertEquals(1, store.current.profiles.size)
    }

    @Test
    fun `sperrendes Profil laesst sich nicht loeschen`() {
        val (e, store) = engine(ChipLock("p1"))

        assertFalse(e.deleteProfile("p1", now))
        assertNotNull(store.current.profileById("p1"))
    }

    @Test
    fun `Chip anlernen haengt ihn an`() {
        val (e, store) = engine()

        val ok = e.enrollTag("04BB", "Bett", "p2", isMaster = false, now = now)

        assertTrue(ok)
        assertEquals(2, store.current.tags.size)
    }

    @Test
    fun `bekannte UID wird aktualisiert statt doppelt angelegt`() {
        val (e, store) = engine()

        e.enrollTag("04aa", "Neu", "p2", isMaster = true, now = now)

        assertEquals(1, store.current.tags.size)
        assertEquals("Neu", store.current.tags.first().label)
        assertEquals("p2", store.current.tags.first().profileId)
        assertTrue(store.current.tags.first().isMaster)
    }

    @Test
    fun `Chips sind waehrend einer Sperre gesperrt`() {
        val (e, store) = engine(ChipLock("p2"))

        assertFalse(e.enrollTag("04BB", "Bett", "p1", isMaster = false, now = now))
        assertFalse(e.deleteTag("04AA", now))
        assertEquals(1, store.current.tags.size)
    }

    @Test
    fun `Chip loeschen entfernt ihn`() {
        val (e, store) = engine()

        assertTrue(e.deleteTag("04AA", now))
        assertTrue(store.current.tags.isEmpty())
    }

    @Test
    fun `Code erzeugen liefert acht Zeichen und speichert nur den Hash`() {
        val (e, store) = engine()

        val code = e.generateCode(now)

        assertNotNull(code)
        assertEquals(8, code!!.length)
        assertEquals(Hashing.sha256(code), store.current.codeHash)
    }

    @Test
    fun `Code laesst sich waehrend einer Sperre nicht neu erzeugen`() {
        val (e, _) = engine(ChipLock("p1"))

        assertNull(e.generateCode(now))
    }

    @Test
    fun `erzeugter Code enthaelt nur erlaubte Zeichen`() {
        val (e, _) = engine()

        assertTrue(e.generateCode(now)!!.all { it in LockEngine.CODE_ALPHABET })
    }

    @Test
    fun `Profil mit laufender Zeitsperre ist nicht aenderbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        assertFalse(e.updateProfile(arbeit.copy(name = "Neu"), now))
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Zeitsperre aenderbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        assertTrue(e.updateProfile(nacht.copy(name = "Neu"), now))
    }

    @Test
    fun `Profil mit laufender Zeitsperre ist nicht loeschbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        assertFalse(e.deleteProfile("p1", now))
    }

    @Test
    fun `waehrend einer Zeitsperre laesst sich kein Chip anlernen`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        assertFalse(e.enrollTag("04BB", "Neu", "p1", isMaster = false, now = now))
    }

    @Test
    fun `waehrend einer Zeitsperre gibt es keinen neuen Notfall-Code`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        assertNull(e.generateCode(now))
    }

    /**
     * Der eigentliche Grund für den `now`-Parameter: vorher fragten die Wächter
     * nur, ob eine Sperre gespeichert ist. Eine abgelaufene, noch nicht
     * aufgeräumte blockierte damit weiter, bis der Alarm feuerte.
     */
    @Test
    fun `abgelaufene Zeitsperre blockiert die Einstellungen nicht mehr`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 1))

        assertTrue(e.enrollTag("04BB", "Neu", "p1", isMaster = false, now = now))
        assertTrue(e.updateProfile(arbeit.copy(name = "Neu"), now))
    }
}
