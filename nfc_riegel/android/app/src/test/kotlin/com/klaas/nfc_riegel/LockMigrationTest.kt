package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockMigrationTest {

    @Test
    fun `v1-Zustand ergibt ein Profil namens Standard`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.TIMER,
            endsAt = null,
            durationMinutes = 90,
            blockedPackages = setOf("com.a"),
            tagUid = null,
            codeHash = "abc",
        )

        assertEquals(1, state.profiles.size)
        val profile = state.profiles.first()
        assertEquals("Standard", profile.name)
        assertEquals(setOf("com.a"), profile.blockedPackages)
        assertEquals(90, profile.durationMinutes)
        assertEquals("abc", state.codeHash)
    }

    @Test
    fun `bestehender Chip wird Generalschluessel`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.OPEN,
            endsAt = null,
            durationMinutes = 60,
            blockedPackages = emptySet(),
            tagUid = "04AA",
            codeHash = null,
        )

        assertEquals(1, state.tags.size)
        val tag = state.tags.first()
        assertEquals("04AA", tag.uid)
        assertEquals("Chip 1", tag.label)
        assertTrue(tag.isMaster)
        assertEquals(state.profiles.first().id, tag.profileId)
    }

    @Test
    fun `ohne Chip bleibt die Liste leer`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = null,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertTrue(state.tags.isEmpty())
    }

    @Test
    fun `laufende Sperre wird uebernommen`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.TIMER, endsAt = 1_700_000_000_000,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        val lock = state.chipLock!!
        assertEquals(state.profiles.first().id, lock.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(1_700_000_000_000, lock.endsAt)
    }

    @Test
    fun `ohne laufende Sperre bleibt chipLock null`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = 123,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertNull(state.chipLock)
    }
}
