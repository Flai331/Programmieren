package com.klaasotte.parkplatz_merker

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat

class ForceStopService : AccessibilityService() {

    companion object {
        @Volatile var instance: ForceStopService? = null
        private var pendingPkg: String? = null
        private var pendingSince = 0L

        fun isEnabled(ctx: Context): Boolean {
            val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            val myComponent = ComponentName(ctx, ForceStopService::class.java).flattenToString()
            return enabled?.split(":")?.any { it.equals(myComponent, ignoreCase = true) } ?: false
        }

        fun request(ctx: Context, pkg: String) {
            pendingPkg = pkg
            pendingSince = System.currentTimeMillis()
            instance?.tryRun()
            if (instance == null) {
                EventLog.info(ctx, "Bedienungshilfe nicht aktiv")
            }
        }
    }

    private val FORCE_TEXTS = listOf("beenden erzwingen", "stopp erzwingen", "erzwungenes beenden",
        "erzwungener stopp", "force stop", "stoppen erzwingen")
    private val FORCE_IDS = listOf("com.android.settings:id/force_stop_button",
        "com.android.settings:id/button3", "com.miui.securitycenter:id/am_force_stop")
    private val OK_IDS = listOf("android:id/button1")
    private val OK_TEXTS = listOf("ok", "beenden erzwingen", "stopp erzwingen", "force stop")
    private var step = 0
    private var stepSince = 0L
    private val handler = Handler(Looper.getMainLooper())
    private var unlockReceiver: BroadcastReceiver? = null
    private var unlockRunnable: Runnable? = null

    override fun onServiceConnected() {
        instance = this
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                tryRun()
            }
        }
        unlockReceiver = receiver
        if (Build.VERSION.SDK_INT >= 34) {
            ContextCompat.registerReceiver(
                this, receiver,
                IntentFilter(Intent.ACTION_USER_PRESENT),
                ContextCompat.RECEIVER_EXPORTED
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, IntentFilter(Intent.ACTION_USER_PRESENT))
        }
    }

    override fun onUnbind(intent: Intent?): Boolean {
        unlockReceiver?.let { unregisterReceiver(it) }
        unlockReceiver = null
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        unlockReceiver?.let { unregisterReceiver(it) }
        unlockReceiver = null
        instance = null
        super.onDestroy()
    }

    private fun tryRun() {
        val pkg = pendingPkg ?: return
        val now = System.currentTimeMillis()
        if (now - pendingSince > (30 * 60 * 1000L)) {
            pendingPkg = null
            return
        }

        if (step != 0) return

        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        if (!pm.isInteractive) return

        val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager ?: return
        if (km.isKeyguardLocked) return

        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            finish("Fehler beim App-Oeffnen")
            return
        }

        step = 1
        stepSince = now
        handler.removeCallbacks(unlockRunnable ?: {})
        unlockRunnable = Runnable { finish("Zeitlimit") }
        handler.postDelayed(unlockRunnable!!, 8000L)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (step == 0) return
        val root = rootInActiveWindow ?: return

        when (step) {
            1 -> handleFindButton(root)
            2 -> handleClickOK(root)
        }
    }

    private fun handleFindButton(root: AccessibilityNodeInfo) {
        for (id in FORCE_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                if (!node.isEnabled) {
                    finish("lief nicht mehr")
                    return
                }
                if (click(node)) {
                    step = 2
                    stepSince = System.currentTimeMillis()
                    handler.removeCallbacks(unlockRunnable ?: {})
                    unlockRunnable = Runnable { finish("Zeitlimit") }
                    handler.postDelayed(unlockRunnable!!, 8000L)
                    return
                }
            }
        }

        for (text in FORCE_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                if ((node.text?.toString()?.lowercase()?.contains(text)) == true) {
                    if (!node.isEnabled) {
                        finish("lief nicht mehr")
                        return
                    }
                    if (click(node)) {
                        step = 2
                        stepSince = System.currentTimeMillis()
                        handler.removeCallbacks(unlockRunnable ?: {})
                        unlockRunnable = Runnable { finish("Zeitlimit") }
                        handler.postDelayed(unlockRunnable!!, 8000L)
                        return
                    }
                }
            }
        }
    }

    private fun handleClickOK(root: AccessibilityNodeInfo) {
        for (id in OK_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                if (click(node)) {
                    finish("beendet")
                    return
                }
            }
        }

        for (text in OK_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                if ((node.text?.toString()?.lowercase()?.equals(text)) == true) {
                    if (click(node)) {
                        finish("beendet")
                        return
                    }
                }
            }
        }
    }

    private fun click(node: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = node
        var depth = 0
        while (current != null && depth < 5) {
            if (current.isClickable) {
                current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            current = current.parent
            depth++
        }
        return false
    }

    private fun finish(reason: String) {
        val pkg = pendingPkg ?: ""
        EventLog.info(this, "Beenden erzwingen ($pkg): $reason")
        pendingPkg = null
        step = 0
        handler.removeCallbacks(unlockRunnable ?: {})
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 500L)
    }

    override fun onInterrupt() {
    }
}
