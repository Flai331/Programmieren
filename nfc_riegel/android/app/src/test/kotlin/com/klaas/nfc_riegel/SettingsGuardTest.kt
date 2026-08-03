package com.klaas.nfc_riegel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsGuardTest {

    @Test
    fun `Accessibility-Seite ist geschuetzt`() {
        assertTrue(SettingsGuard.isGuarded("com.android.settings.AccessibilitySettings"))
    }

    @Test
    fun `Unterseite eines Accessibility-Dienstes ist geschuetzt`() {
        assertTrue(
            SettingsGuard.isGuarded("com.android.settings.accessibility.AccessibilityDetailsSettings")
        )
    }

    @Test
    fun `Device-Admin-Seite ist geschuetzt`() {
        assertTrue(SettingsGuard.isGuarded("com.android.settings.DeviceAdminSettings"))
    }

    @Test
    fun `WLAN-Einstellungen sind nicht geschuetzt`() {
        assertFalse(SettingsGuard.isGuarded("com.android.settings.wifi.WifiSettings"))
    }

    @Test
    fun `null bedeutet nicht geschuetzt`() {
        assertFalse(SettingsGuard.isGuarded(null))
    }
}
