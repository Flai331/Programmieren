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
 * Bedienungshilfe mit zwei Aufgaben (nur auf Auftrag, sonst tut sie nichts):
 *  1. Apps beenden: App-Info öffnen, "Beenden erzwingen" + Bestätigen drücken (Ablauf vom Parkplatz-Merker).
 *  2. Schalter umlegen (Sparprofil): Einstellungsseite öffnen und den obersten Schalter in die
 *     gewünschte Stellung bringen – für Energiesparmodus, Bluetooth, NFC, Standort, die keine App direkt ändern darf.
 * Nebenbei läuft hier der Monitor (Akku-Wächter + Automatik) ohne Dauer-Benachrichtigung.
 */
class ForceStopService : AccessibilityService() {

    companion object {
        @Volatile var instance: ForceStopService? = null
        private val pending: ArrayDeque<String> = ArrayDeque()
        private val toggles: ArrayDeque<Pair<String, Boolean>> = ArrayDeque()
        private val results: MutableList<Map<String, String>> = mutableListOf()
        private var total = 0
        private var returnToApp = true

        fun isEnabled(ctx: Context): Boolean {
            val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            val me = ComponentName(ctx, ForceStopService::class.java)
            // Je nach Handy als "pkg/.Klasse" oder "pkg/pkg.Klasse" gespeichert.
            return enabled?.split(":")?.any { ComponentName.unflattenFromString(it) == me } ?: false
        }

        fun busy(): Boolean = pending.isNotEmpty() || toggles.isNotEmpty()

        private fun startBatch(returnToApp: Boolean) {
            if (!busy()) {
                results.clear()
                total = 0
                this.returnToApp = returnToApp
            }
        }

        /**
         * Apps erzwungen beenden. false = Bedienungshilfe ist nicht eingeschaltet.
         * returnToApp = am Ende den Akku-Schoner zeigen (sonst bleibt der Startbildschirm).
         */
        fun request(ctx: Context, pkgs: List<String>, returnToApp: Boolean = true): Boolean {
            val service = instance ?: return false
            val protected = Apps.protectedPackages(ctx)
            startBatch(returnToApp)
            for (pkg in pkgs) {
                if (protected.contains(pkg) || pending.contains(pkg)) continue
                pending.addLast(pkg)
                total++
            }
            service.tryRun()
            return true
        }

        /** Schalter umlegen: (SaverProfile-id, soll danach an sein). */
        fun requestToggles(ctx: Context, items: List<Pair<String, Boolean>>, returnToApp: Boolean = true): Boolean {
            val service = instance ?: return false
            startBatch(returnToApp)
            for (item in items) {
                if (toggles.any { it.first == item.first }) continue
                toggles.addLast(item)
                total++
            }
            service.tryRun()
            return true
        }

        fun cancel() {
            pending.clear()
            toggles.clear()
            instance?.abort()
        }

        fun state(): Map<String, Any> = mapOf(
            "pending" to (pending.toList() + toggles.map { "toggle:" + it.first }),
            "total" to total,
            "results" to results.toList(),
        )
    }

    private val FORCE_TEXTS = listOf("beenden erzwingen", "stopp erzwingen", "erzwungenes beenden",
        "erzwungener stopp", "force stop", "stoppen erzwingen")
    private val FORCE_IDS = listOf("com.android.settings:id/force_stop_button",
        "com.android.settings:id/button3", "com.miui.securitycenter:id/am_force_stop")
    private val OK_IDS = listOf("android:id/button1")

    // 0 frei | App beenden: 1 Knopf suchen, 2 Bestätigung, 3 prüfen | Schalter: 10 suchen, 11 prüfen
    private var step = 0
    private var stepSince = 0L
    private var current = ""          // Paket oder "toggle:<id>" (für das Ergebnis)
    private var currentToggle: Pair<String, Boolean>? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish("Zeitlimit – Knopf nicht gefunden") }

    /** Nicht nur auf Ereignisse warten: ist die Seite schon fertig, kommt evtl. keins mehr. */
    private val poll = object : Runnable {
        override fun run() {
            if (step != 1 && step != 2 && step != 10) return
            rootInActiveWindow?.let { process(it) }
            if (step == 1 || step == 2 || step == 10) handler.postDelayed(this, 400L)
        }
    }

    private var monitor: Monitor? = null

    override fun onServiceConnected() {
        instance = this
        // Akku-Wächter + Automatik laufen hier mit – ohne Dauer-Benachrichtigung.
        monitor = Monitor(this).also { it.start() }
    }

    override fun onUnbind(intent: Intent?): Boolean {
        monitor?.stop()
        monitor = null
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        monitor?.stop()
        monitor = null
        instance = null
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun tryRun() {
        if (step != 0) return
        val pkg = pending.firstOrNull()
        if (pkg != null) {
            startStop(pkg)
            return
        }
        val t = toggles.firstOrNull() ?: return
        startToggle(t)
    }

    private fun open(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS))
        true
    } catch (_: Exception) {
        false
    }

    private fun startStop(pkg: String) {
        current = pkg
        currentToggle = null
        if (Apps.isStopped(this, pkg)) {
            // Schon gestoppt – App-Info gar nicht erst öffnen.
            record(pkg, "war schon beendet")
            pending.removeFirstOrNull()
            handler.post { next() }
            return
        }
        setStep(1)
        if (!open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null)))) {
            finish("App-Info ließ sich nicht öffnen")
        }
    }

    private fun startToggle(t: Pair<String, Boolean>) {
        current = "toggle:" + t.first
        currentToggle = t
        if (SaverProfile.toggleIsOn(this, t.first) == t.second) {
            record(current, "war schon so")
            toggles.removeFirstOrNull()
            handler.post { next() }
            return
        }
        setStep(10)
        if (!open(SaverProfile.toggleIntent(t.first))) {
            finish("Einstellung ließ sich nicht öffnen")
        }
    }

    private fun setStep(s: Int) {
        step = s
        stepSince = System.currentTimeMillis()
        handler.removeCallbacks(timeout)
        handler.removeCallbacks(poll)
        if (s == 1 || s == 2 || s == 10) {
            handler.postDelayed(timeout, 8000L)
            handler.postDelayed(poll, 600L)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (step != 1 && step != 2 && step != 10) return
        rootInActiveWindow?.let { process(it) }
    }

    private fun process(root: AccessibilityNodeInfo) {
        // Kurz warten, bis wirklich die richtige Seite / der Dialog angezeigt wird.
        if (System.currentTimeMillis() - stepSince < 500L) return
        when (step) {
            1 -> findForceButton(root)
            2 -> clickOk(root)
            10 -> findSwitch(root)
        }
    }

    // ---------- Apps beenden ----------

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
            val button = clickable(node) ?: continue
            // Ausgegraut (Knopf selbst oder Text darin) = App läuft nicht mehr.
            if (!node.isEnabled || !button.isEnabled) {
                finish("war schon beendet")
                return
            }
            button.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            setStep(2)
            return
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
                    verifyStop()
                    return
                }
            }
        }
    }

    /** Ehrlich prüfen, ob Android die App jetzt als gestoppt führt. */
    private fun verifyStop() {
        setStep(3)
        val pkg = current
        handler.postDelayed({
            finish(if (Apps.isStopped(this, pkg)) "beendet" else "bestätigt, läuft aber noch")
        }, 1200L)
    }

    // ---------- Schalter umlegen ----------

    /** Oberster Ein/Aus-Schalter der Seite (Breitensuche = von oben nach unten). */
    private fun findSwitch(root: AccessibilityNodeInfo) {
        val t = currentToggle ?: return
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.addLast(root)
        var seen = 0
        while (queue.isNotEmpty() && seen < 400) {
            val n = queue.removeFirst()
            seen++
            val cls = n.className?.toString() ?: ""
            if (n.isCheckable && cls.contains("Switch", ignoreCase = true)) {
                if (n.isChecked == t.second) {
                    verifyToggle()
                } else if (click(n)) {
                    verifyToggle()
                }
                return
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { queue.addLast(it) }
        }
    }

    private fun verifyToggle() {
        setStep(11)
        val t = currentToggle ?: return
        handler.postDelayed({
            finish(if (SaverProfile.toggleIsOn(this, t.first) == t.second) "erledigt"
                   else "Schalter gedrückt, aber nicht umgestellt")
        }, 1200L)
    }

    // ---------- gemeinsam ----------

    /** Der Knoten selbst oder der nächste klickbare Elternknoten (max. 5 Ebenen). */
    private fun clickable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var n: AccessibilityNodeInfo? = node
        var depth = 0
        while (n != null && depth < 5) {
            if (n.isClickable) return n
            n = n.parent
            depth++
        }
        return null
    }

    private fun click(node: AccessibilityNodeInfo): Boolean {
        val button = clickable(node) ?: return false
        if (!button.isEnabled) return false
        button.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        return true
    }

    private fun record(key: String, result: String) {
        results.add(mapOf("pkg" to key, "result" to result))
    }

    private fun finish(reason: String) {
        if (step == 0) return
        record(current, reason)
        if (currentToggle != null) toggles.removeFirstOrNull() else pending.removeFirstOrNull()
        currentToggle = null
        setStep(0)
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
            handler.postDelayed({ next() }, 1000L)
        }, 400L)
    }

    private fun next() {
        if (busy()) {
            tryRun()
        } else if (returnToApp) {
            backToApp()
        }
    }

    private fun abort() {
        if (step == 0) return
        record(current, "abgebrochen")
        currentToggle = null
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
