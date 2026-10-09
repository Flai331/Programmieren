package de.klaas.akku_schoner

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Bedienungshilfe, die für jede gewählte App die App-Info öffnet und
 * "Beenden erzwingen" + Bestätigen drückt. Ablauf übernommen vom Parkplatz-Merker.
 * Ohne Auftrag (step == 0) tut der Dienst nichts.
 */
class ForceStopService : AccessibilityService() {

    companion object {
        @Volatile var instance: ForceStopService? = null
        private val pending: ArrayDeque<String> = ArrayDeque()
        private val results: MutableList<Map<String, String>> = mutableListOf()
        private var total = 0

        fun isEnabled(ctx: Context): Boolean {
            val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            val me = ComponentName(ctx, ForceStopService::class.java).flattenToString()
            return enabled?.split(":")?.any { it.equals(me, ignoreCase = true) } ?: false
        }

        /** Neuer Auftrag. false = Bedienungshilfe ist nicht eingeschaltet. */
        fun request(ctx: Context, pkgs: List<String>): Boolean {
            val service = instance ?: return false
            val protected = Apps.protectedPackages(ctx)
            if (pending.isEmpty()) {
                results.clear()
                total = 0
            }
            for (pkg in pkgs) {
                if (protected.contains(pkg) || pending.contains(pkg)) continue
                pending.addLast(pkg)
                total++
            }
            service.tryRun()
            return true
        }

        fun cancel() {
            pending.clear()
            instance?.abort()
        }

        fun state(): Map<String, Any> = mapOf(
            "pending" to pending.toList(),
            "total" to total,
            "results" to results.toList(),
        )
    }

    private val FORCE_TEXTS = listOf("beenden erzwingen", "stopp erzwingen", "erzwungenes beenden",
        "erzwungener stopp", "force stop", "stoppen erzwingen")
    private val FORCE_IDS = listOf("com.android.settings:id/force_stop_button",
        "com.android.settings:id/button3", "com.miui.securitycenter:id/am_force_stop")
    private val OK_IDS = listOf("android:id/button1")

    private var step = 0          // 0 frei, 1 warte auf Knopf, 2 warte auf Bestätigung, 3 prüft
    private var stepSince = 0L
    private var current = ""
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish("Zeitlimit – Knopf nicht gefunden") }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun tryRun() {
        if (step != 0) return
        val pkg = pending.firstOrNull() ?: return
        current = pkg

        if (Apps.isStopped(this, pkg)) {
            // Schon gestoppt – App-Info gar nicht erst öffnen.
            record(pkg, "war schon beendet")
            pending.removeFirstOrNull()
            handler.post { next() }
            return
        }

        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            finish("App-Info ließ sich nicht öffnen")
            return
        }
        setStep(1)
    }

    private fun setStep(s: Int) {
        step = s
        stepSince = System.currentTimeMillis()
        handler.removeCallbacks(timeout)
        if (s == 1 || s == 2) handler.postDelayed(timeout, 8000L)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (step != 1 && step != 2) return
        // Kurz warten, bis wirklich die richtige App-Info / der Dialog angezeigt wird.
        if (System.currentTimeMillis() - stepSince < 500L) return
        val root = rootInActiveWindow ?: return
        when (step) {
            1 -> findForceButton(root)
            2 -> clickOk(root)
        }
    }

    private fun findForceButton(root: AccessibilityNodeInfo) {
        val candidates = mutableListOf<AccessibilityNodeInfo>()
        for (id in FORCE_IDS) {
            // Gleiche IDs können auf manchen Handys "Deinstallieren" sein – Text prüfen.
            candidates += root.findAccessibilityNodeInfosByViewId(id).filter { isForceNode(it) }
        }
        for (text in FORCE_TEXTS) {
            candidates += root.findAccessibilityNodeInfosByText(text)
                .filter { it.text?.toString()?.lowercase()?.contains(text) == true }
        }
        for (node in candidates) {
            if (!node.isEnabled) {
                finish("war schon beendet")
                return
            }
            if (click(node)) {
                setStep(2)
                return
            }
        }
    }

    private fun isForceNode(node: AccessibilityNodeInfo): Boolean {
        val texts = mutableListOf<String>()
        node.text?.let { texts.add(it.toString().lowercase()) }
        node.contentDescription?.let { texts.add(it.toString().lowercase()) }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.text?.let { texts.add(it.toString().lowercase()) }
        }
        return texts.any { t -> FORCE_TEXTS.any { f -> t.contains(f) } }
    }

    private fun clickOk(root: AccessibilityNodeInfo) {
        // Nur den positiven Knopf eines echten Dialogs (AlertDialog: android:id/button1).
        for (id in OK_IDS) {
            for (node in root.findAccessibilityNodeInfosByViewId(id)) {
                if (!node.isEnabled) continue
                if (click(node)) {
                    verify()
                    return
                }
            }
        }
    }

    /** Ehrlich prüfen, ob Android die App jetzt als gestoppt führt. */
    private fun verify() {
        setStep(3)
        val pkg = current
        handler.postDelayed({
            finish(if (Apps.isStopped(this, pkg)) "beendet" else "bestätigt, läuft aber noch")
        }, 1200L)
    }

    private fun click(node: AccessibilityNodeInfo): Boolean {
        var n: AccessibilityNodeInfo? = node
        var depth = 0
        while (n != null && depth < 5) {
            if (n.isClickable) {
                n.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            n = n.parent
            depth++
        }
        return false
    }

    private fun record(pkg: String, result: String) {
        results.add(mapOf("pkg" to pkg, "result" to result))
    }

    private fun finish(reason: String) {
        if (step == 0) return
        record(current, reason)
        pending.removeFirstOrNull()
        setStep(0)
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
            handler.postDelayed({ next() }, 1000L)
        }, 400L)
    }

    private fun next() {
        if (pending.isNotEmpty()) {
            tryRun()
        } else {
            backToApp()
        }
    }

    private fun abort() {
        if (step == 0) return
        record(current, "abgebrochen")
        setStep(0)
        backToApp()
    }

    private fun backToApp() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            try {
                startActivity(it)
            } catch (_: Exception) {
            }
        }
    }

    override fun onInterrupt() {}
}
