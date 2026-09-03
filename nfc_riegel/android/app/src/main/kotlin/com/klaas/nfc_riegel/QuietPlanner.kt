package com.klaas.nfc_riegel

import java.util.Calendar
import java.util.TimeZone

/**
 * Rechnet aus Zustand und Uhrzeit, für welche Profile gerade Ruhe gilt und ob
 * ein bestimmter Anruf stumm bleibt.
 *
 * Reine Funktionen ohne Android und ohne Speicher — wie [CalendarPlanner],
 * damit sich alles per JUnit prüfen lässt. Die Zeitzone ist ein Parameter und
 * kein Aufruf von `getDefault()` mitten in der Rechnung: sonst ließen sich
 * Fenster über Mitternacht nicht reproduzierbar prüfen.
 */
object QuietPlanner {

    /** So weit voraus wird nach dem nächsten Wochenplan-Fenster gesucht. */
    private const val HORIZONT_TAGE = 8

    /** Ein konkretes Fenster auf der Zeitachse. Ende ist ausschließlich. */
    data class Fenster(val startsAt: Long, val endsAt: Long) {
        fun enthaelt(zeitpunkt: Long) = startsAt <= zeitpunkt && zeitpunkt < endsAt
    }

    /** Profile, für die jetzt Ruhe gilt. */
    fun quietProfiles(
        state: LockState,
        now: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): List<Profile> = state.profiles.filter { it.quiet.enabled && giltRuhe(state, it, now, zone) }

    fun isQuiet(
        state: LockState,
        now: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): Boolean = quietProfiles(state, now, zone).isNotEmpty()

    /**
     * Bleibt dieser Anruf stumm?
     *
     * Gilt Ruhe für mehrere Profile gleichzeitig, genügt **ein** Profil, das
     * stumm schaltet. Ruhe heißt Ruhe — eine Ausnahmeliste im einen Profil kann
     * die Vorgabe des anderen nicht aufheben.
     *
     * Eine unterdrückte Nummer ([number] leer oder null) klingelt nur bei
     * [QuietScope.AUSGEWAEHLTE]: dort ist ausdrücklich benannt, wer stumm sein
     * soll, und eine unbekannte Nummer steht nicht auf dieser Liste.
     */
    fun silences(profiles: List<Profile>, number: String?): Boolean =
        profiles.any { schaltetStumm(it.quiet, number) }

    private fun schaltetStumm(q: QuietSettings, number: String?): Boolean = when (q.scope) {
        QuietScope.ALLE -> true
        QuietScope.AUSGEWAEHLTE -> PhoneNumbers.contains(q.numbers, number)
        QuietScope.ALLE_AUSSER -> !PhoneNumbers.contains(q.numbers, number)
    }

    /**
     * Wann sich die Ruhelage das nächste Mal ändert. Darauf wird derselbe
     * Wecker gesetzt, der auch Sperren beendet — die Ruhe muss von allein
     * anfangen und aufhören, ohne dass jemand die App öffnet.
     */
    fun nextBoundary(
        state: LockState,
        now: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): Long? {
        val grenzen = mutableListOf<Long>()

        for (profil in state.profiles) {
            if (!profil.quiet.enabled) continue

            for (fenster in terminFenster(state.calendar, profil, now)) {
                if (now < fenster.startsAt) grenzen += fenster.startsAt
                if (now < fenster.endsAt) grenzen += fenster.endsAt
            }

            for (fenster in planFenster(profil.quiet.schedules, now, zone)) {
                if (now < fenster.startsAt) grenzen += fenster.startsAt
                if (now < fenster.endsAt) grenzen += fenster.endsAt
            }

            if (profil.quiet.whileLocked) {
                state.timeLocks
                    .filter { it.profileId == profil.id && now < it.endsAt }
                    .forEach { grenzen += it.endsAt }
            }
        }

        // Solange der Kalender unterdrückt ist, liefert [terminFenster] nichts.
        // Der Zeitpunkt selbst ist deshalb eine Grenze: danach ist neu zu rechnen.
        state.calendar.suppressedUntil?.takeIf { now < it }?.let { grenzen += it }

        return grenzen.minOrNull()
    }

    private fun giltRuhe(state: LockState, profil: Profile, now: Long, zone: TimeZone): Boolean {
        if (profil.quiet.whileLocked && istGesperrt(state, profil, now)) return true
        if (terminFenster(state.calendar, profil, now).any { it.enthaelt(now) }) return true
        return planFenster(profil.quiet.schedules, now, zone).any { it.enthaelt(now) }
    }

    private fun istGesperrt(state: LockState, profil: Profile, now: Long): Boolean =
        state.chipLock?.profileId == profil.id ||
            state.timeLocks.any { it.profileId == profil.id && now < it.endsAt } ||
            profil.id in CalendarPlanner.lockedProfileIds(state.calendar, now)

    /**
     * Die Terminfenster dieses Profils, jeweils um den Nachlauf verlängert. Ein
     * festgenageltes Ende schlägt das Ende aus dem Kalender — dieselbe Regel wie
     * bei der Sperre.
     */
    private fun terminFenster(c: CalendarSettings, profil: Profile, now: Long): List<Fenster> {
        if (!c.enabled) return emptyList()
        if (c.suppressedUntil != null && now < c.suppressedUntil) return emptyList()

        val nachlauf = profil.quiet.afterEventMinutes.coerceAtLeast(0) * 60_000L
        return c.cachedWindows
            .filter { it.profileId == profil.id }
            .map { Fenster(it.startsAt, (c.pinnedEnds[it.eventId] ?: it.endsAt) + nachlauf) }
    }

    /**
     * Die Wochenplan-Fenster von gestern bis [HORIZONT_TAGE] Tage voraus.
     * Gestern muss mit hinein: ein Fenster über Mitternacht hat gestern
     * angefangen und gilt jetzt noch.
     */
    private fun planFenster(
        schedules: List<QuietSchedule>,
        now: Long,
        zone: TimeZone,
    ): List<Fenster> {
        if (schedules.isEmpty()) return emptyList()

        val tag = Calendar.getInstance(zone).apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_MONTH, -1)
        }

        val fenster = mutableListOf<Fenster>()
        repeat(HORIZONT_TAGE + 2) {
            val wochentag = tag.get(Calendar.DAY_OF_WEEK)
            for (plan in schedules) {
                if (wochentag in plan.days) fenster += fensterAn(tag, plan)
            }
            tag.add(Calendar.DAY_OF_MONTH, 1)
        }
        return fenster
    }

    /**
     * Anfang und Ende werden über den Kalender gesetzt statt über Millisekunden
     * addiert: an den Umstellungstagen ist ein Tag 23 oder 25 Stunden lang, und
     * „bis 6 Uhr" soll auch dann 6 Uhr heißen.
     */
    private fun fensterAn(tag: Calendar, plan: QuietSchedule): Fenster {
        val beginn = plan.startMinute.coerceIn(0, MINUTEN_PRO_TAG - 1)
        val schluss = plan.endMinute.coerceIn(0, MINUTEN_PRO_TAG - 1)

        val start = (tag.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, beginn / 60)
            set(Calendar.MINUTE, beginn % 60)
        }
        val ende = (start.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, schluss / 60)
            set(Calendar.MINUTE, schluss % 60)
            if (schluss <= beginn) add(Calendar.DAY_OF_MONTH, 1)
        }
        return Fenster(start.timeInMillis, ende.timeInMillis)
    }

    private const val MINUTEN_PRO_TAG = 24 * 60
}
