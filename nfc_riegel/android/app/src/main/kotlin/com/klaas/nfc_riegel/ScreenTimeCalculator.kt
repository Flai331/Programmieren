package com.klaas.nfc_riegel

import java.util.Calendar
import java.util.TimeZone

/**
 * Rechnet aus rohen Nutzungsereignissen die Vordergrundzeit je Paket.
 *
 * Bewusst aus Ereignissen statt aus den fertigen Tageseimern von
 * `queryUsageStats`: deren Grenzen richten sich nach einer geräteeigenen
 * Tagesgrenze, nicht nach der lokalen Mitternacht des Nutzers.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object ScreenTimeCalculator {

    /** Lokale Mitternacht des Tages, in dem [now] liegt. */
    fun startOfDay(now: Long, zone: TimeZone = TimeZone.getDefault()): Long {
        val kalender = Calendar.getInstance(zone)
        kalender.timeInMillis = now
        kalender.set(Calendar.HOUR_OF_DAY, 0)
        kalender.set(Calendar.MINUTE, 0)
        kalender.set(Calendar.SECOND, 0)
        kalender.set(Calendar.MILLISECOND, 0)
        return kalender.timeInMillis
    }

    /**
     * Vordergrundzeit je Paket im Fenster [from]..[to].
     *
     * Drei Fälle, die eine naive Paarbildung falsch rechnet:
     *
     * 1. Ein Paket ohne Startereignis, aber mit Ende, lief schon zu Beginn des
     *    Fensters — seine Zeit zählt ab [from].
     * 2. Ein Paket ohne Endeereignis läuft noch — es zählt bis [to].
     * 3. `SCREEN_OFF` beendet alles Offene, weil auf manchen Geräten beim
     *    Ausschalten kein Pausenereignis kommt.
     *
     * `gesehen` verhindert, dass Fall 1 mehrfach greift: kommt für ein Paket ein
     * zweites Ende (Android schickt oft `ACTIVITY_PAUSED` **und**
     * `ACTIVITY_STOPPED`), würde sonst erneut ab [from] gerechnet.
     */
    fun totals(events: List<UsageEvent>, from: Long, to: Long): Map<String, Long> {
        val summen = mutableMapOf<String, Long>()
        val offen = mutableMapOf<String, Long>()
        val gesehen = mutableSetOf<String>()

        fun schliesse(paket: String, zeitpunkt: Long) {
            val start = offen.remove(paket)
                ?: if (paket in gesehen) return else from
            gesehen += paket
            val dauer = zeitpunkt - start
            if (dauer > 0) summen[paket] = (summen[paket] ?: 0L) + dauer
        }

        for (ereignis in events.sortedBy { it.timestamp }) {
            val t = ereignis.timestamp.coerceIn(from, to)
            when (ereignis.type) {
                UsageEventType.FOREGROUND -> {
                    gesehen += ereignis.packageName
                    offen.putIfAbsent(ereignis.packageName, t)
                }
                UsageEventType.BACKGROUND -> schliesse(ereignis.packageName, t)
                UsageEventType.SCREEN_OFF -> offen.keys.toList().forEach { schliesse(it, t) }
            }
        }

        offen.keys.toList().forEach { schliesse(it, to) }
        return summen
    }
}
