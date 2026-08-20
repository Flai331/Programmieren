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
     * Die einzelnen Vordergrund-Abschnitte **eines** Pakets, in zeitlicher
     * Reihenfolge. Dieselben drei Ränder wie in [totals]; nur eben nicht zu
     * einer Summe verdichtet, weil die Atempause die Lücken dazwischen braucht.
     */
    fun intervals(
        events: List<UsageEvent>,
        packageName: String,
        from: Long,
        to: Long,
    ): List<Pair<Long, Long>> {
        val abschnitte = mutableListOf<Pair<Long, Long>>()
        var offen: Long? = null
        var gesehen = false

        fun schliesse(zeitpunkt: Long) {
            val start = offen ?: if (gesehen) return else from
            offen = null
            gesehen = true
            if (zeitpunkt > start) abschnitte += start to zeitpunkt
        }

        for (ereignis in events.sortedBy { it.timestamp }) {
            val t = ereignis.timestamp.coerceIn(from, to)
            when (ereignis.type) {
                UsageEventType.FOREGROUND -> if (ereignis.packageName == packageName) {
                    gesehen = true
                    if (offen == null) offen = t
                }
                UsageEventType.BACKGROUND -> if (ereignis.packageName == packageName) {
                    schliesse(t)
                }
                UsageEventType.SCREEN_OFF -> if (offen != null) schliesse(t)
            }
        }
        // Nur schliessen, was auch offen ist. Ohne diese Bedingung bekaeme ein
        // Paket ganz ohne Ereignisse den Rueckfall auf [from] und damit das
        // gesamte Fenster angerechnet.
        if (offen != null) schliesse(to)
        return abschnitte
    }

    /**
     * Zeit der laufenden Sitzung: rückwärts summiert, bis eine Lücke von
     * mindestens [resetMillis] kommt.
     *
     * Anders als die Tagessumme misst das, wie lange man **am Stück** in einer
     * App hängt. Wer wirklich weglegt, fängt wieder bei null an — wer nur kurz
     * herausspringt, nicht. Genau darin liegt der Unterschied zwischen einer
     * Pause, die etwas bewirkt, und einer, die man umgeht.
     */
    fun sessionMillis(
        events: List<UsageEvent>,
        packageName: String,
        from: Long,
        to: Long,
        resetMillis: Long,
    ): Long {
        val abschnitte = intervals(events, packageName, from, to)
        if (abschnitte.isEmpty()) return 0L

        // Liegt die letzte Nutzung lange genug zurück, läuft keine Sitzung mehr.
        if (to - abschnitte.last().second >= resetMillis) return 0L

        var summe = 0L
        var vorherigerStart: Long? = null
        for ((start, ende) in abschnitte.asReversed()) {
            val vorher = vorherigerStart
            if (vorher != null && vorher - ende >= resetMillis) break
            summe += ende - start
            vorherigerStart = start
        }
        return summe
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
