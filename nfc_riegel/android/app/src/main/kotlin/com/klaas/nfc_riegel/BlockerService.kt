package com.klaas.nfc_riegel

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Erkennt die Einstellungsseiten, über die man den Riegel abschalten könnte.
 * Bewusst nur diese — die restlichen Einstellungen bleiben während einer Sperre nutzbar.
 */
object SettingsGuard {
    private val markers = listOf("accessibility", "deviceadmin", "device_admin")

    fun isGuarded(className: String?): Boolean {
        val name = className?.lowercase() ?: return false
        return markers.any { name.contains(it) }
    }
}

/**
 * Lauscht auf Fensterwechsel. Fragt bei jedem Ereignis den aktuellen Zustand ab,
 * statt sich benachrichtigen zu lassen — so kann nichts auseinanderlaufen.
 */
class BlockerService : AccessibilityService() {

    private val engine by lazy { LockEngine(SharedPrefsLockStore(this)) }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg == packageName) return

        val now = System.currentTimeMillis()
        val blocked = engine.blockedPackages(now)
        if (blocked.isEmpty()) return

        if (pkg in blocked) {
            showBlockScreen(pkg)
            return
        }

        if (pkg == SETTINGS_PACKAGE && SettingsGuard.isGuarded(event.className?.toString())) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
    }

    override fun onInterrupt() {}

    private fun showBlockScreen(paket: String) {
        val intent = Intent(this, BlockActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(BlockActivity.EXTRA_PACKAGE, paket)
        startActivity(intent)
    }

    private companion object {
        const val SETTINGS_PACKAGE = "com.android.settings"
    }
}
