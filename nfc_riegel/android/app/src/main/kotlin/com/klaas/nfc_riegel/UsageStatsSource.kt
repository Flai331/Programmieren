package com.klaas.nfc_riegel

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

/**
 * Liest die Nutzungsereignisse des Geräts. Hinter einer Schnittstelle, damit
 * [ScreenTimeCalculator] ohne Android prüfbar bleibt.
 */
interface UsageSource {
    fun granted(): Boolean
    fun events(from: Long, to: Long): List<UsageEvent>
}

class AndroidUsageSource(private val context: Context) : UsageSource {

    /**
     * `PACKAGE_USAGE_STATS` läuft nicht über das normale Berechtigungssystem —
     * `checkSelfPermission` meldet hier immer „verweigert", auch wenn der Nutzer
     * den Zugriff erteilt hat. Gefragt wird stattdessen der AppOps-Dienst.
     */
    override fun granted(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val modus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return modus == AppOpsManager.MODE_ALLOWED
    }

    override fun events(from: Long, to: Long): List<UsageEvent> {
        if (!granted()) return emptyList()
        val manager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val roh = manager.queryEvents(from, to)
        val ergebnis = mutableListOf<UsageEvent>()
        val puffer = UsageEvents.Event()
        while (roh.hasNextEvent()) {
            roh.getNextEvent(puffer)
            val paket = puffer.packageName ?: continue
            val art = when (puffer.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> UsageEventType.FOREGROUND
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> UsageEventType.BACKGROUND
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN -> UsageEventType.SCREEN_OFF
                // Alles andere — Benachrichtigungen, Konfigurationswechsel — sagt
                // nichts über Vordergrundzeit aus.
                else -> continue
            }
            ergebnis += UsageEvent(paket, art, puffer.timeStamp)
        }
        return ergebnis
    }
}
