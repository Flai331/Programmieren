package com.klaas.nfc_riegel

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
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
    private val handler = Handler(Looper.getMainLooper())
    private var geplant: Runnable? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg == packageName) return

        val now = System.currentTimeMillis()
        val blocked = engine.blockedPackages(now)

        // Jeder Wechsel verwirft den vorgemerkten Blick: er galt der App, die
        // gerade verlassen wurde.
        geplant?.let { handler.removeCallbacks(it) }
        geplant = null

        if (pkg in blocked) {
            showBlockScreen(pkg)
            return
        }

        // Nur während einer Sperre: sonst wäre der Riegel eine App, die einen
        // grundlos aus den Systemeinstellungen wirft.
        if (blocked.isNotEmpty() &&
            pkg == SETTINGS_PACKAGE &&
            SettingsGuard.isGuarded(event.className?.toString())
        ) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            return
        }

        pruefePause(pkg)
    }

    override fun onInterrupt() {}

    private fun showBlockScreen(paket: String) {
        val intent = Intent(this, BlockActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(BlockActivity.EXTRA_PACKAGE, paket)
        startActivity(intent)
    }

    /**
     * Sucht die Einstellungen aller Profile, die diese App enthalten, führt sie
     * zusammen und schaut nach, ob eine Stufe fällig ist.
     */
    private fun pruefePause(pkg: String) {
        val profile = engine.state().profiles.filter { pkg in it.blockedPackages }
        val settings = PausePlanner.merge(profile.map { it.pause }) ?: return
        zeigeOderPlane(pkg, settings)
    }

    /**
     * Zeigt die Pause, wenn eine Stufe erreicht ist — sonst merkt sie sich den
     * Zeitpunkt vor, an dem die nächste fällig wird. Kein Sekundentakt: die
     * fehlenden Vordergrundmillisekunden stehen fest, also genügt ein einziger
     * verzögerter Aufruf.
     */
    private fun zeigeOderPlane(pkg: String, settings: PauseSettings) {
        val quelle = AndroidUsageSource(this)
        if (!quelle.granted()) return

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val genutzt = ScreenTimeCalculator
            .totals(quelle.events(beginn, jetzt), beginn, jetzt)[pkg] ?: 0L

        val entscheidung = PausePlanner.decide(
            settings,
            genutzt,
            PauseStore(this).lastStep(pkg, jetzt),
        )

        val wartezeit = entscheidung.waitSeconds
        if (wartezeit != null) {
            // Die Stufe wird hier bewusst **nicht** vermerkt. Sie gilt erst als
            // gezeigt, wenn der Countdown wirklich abgelaufen ist — sonst
            // genuegt Wegwischen, um sie loszuwerden. Genau das ist am
            // 2026-08-20 auf dem Geraet passiert.
            startActivity(
                Intent(this, PauseActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    .putExtra(PauseActivity.EXTRA_PACKAGE, pkg)
                    .putExtra(PauseActivity.EXTRA_STEP, entscheidung.step)
                    .putExtra(PauseActivity.EXTRA_SECONDS, wartezeit)
                    .putExtra(PauseActivity.EXTRA_APP_NAME, appName(pkg))
                    .putExtra(PauseActivity.EXTRA_USED_MINUTES, (genutzt / 60_000L).toInt())
            )
            return
        }

        val rest = entscheidung.nextCheckAfterMillis ?: return
        val runnable = Runnable { zeigeOderPlane(pkg, settings) }
        geplant = runnable
        // Nie schneller als alle fünf Sekunden nachsehen — auf der Stufengrenze
        // wäre der Rest sonst null und der Dienst liefe im Kreis.
        handler.postDelayed(runnable, rest.coerceAtLeast(5_000L))
    }

    private fun appName(pkg: String): String = runCatching {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(pkg)

    private companion object {
        const val SETTINGS_PACKAGE = "com.android.settings"
    }
}
