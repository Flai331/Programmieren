package com.klaas.nfc_riegel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineBlockTest {

    @Test
    fun `gesperrte App wird bei aktiver Sperre geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = true, blockedPackages = setOf("com.instagram.android")))
        )

        assertTrue(engine.isBlocked("com.instagram.android"))
    }

    @Test
    fun `nicht gelistete App wird nicht geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = true, blockedPackages = setOf("com.instagram.android")))
        )

        assertFalse(engine.isBlocked("com.android.dialer"))
    }

    @Test
    fun `ohne aktive Sperre wird nichts geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = false, blockedPackages = setOf("com.instagram.android")))
        )

        assertFalse(engine.isBlocked("com.instagram.android"))
    }
}
