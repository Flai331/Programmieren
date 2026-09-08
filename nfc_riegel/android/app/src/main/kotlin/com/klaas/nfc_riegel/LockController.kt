package com.klaas.nfc_riegel

import android.content.Context

/**
 * Bindeglied zwischen der reinen [LockEngine] und Android. Nur hier werden Alarm und
 * Benachrichtigung angefasst — die Engine bleibt frei von Nebenwirkungen.
 */
class LockController(private val context: Context) {

    val engine = LockEngine(SharedPrefsLockStore(context))

    fun scan(uid: String, now: Long = System.currentTimeMillis()): ScanResult {
        val result = engine.onTagScanned(uid, now)
        applyEffects(result.state, now)
        return result
    }

    fun expire(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.onTimerElapsed(now), now)
        // Derselbe Wecker dient beiden Zwecken: Zeitsperre beenden und Termine
        // nachlesen. Welcher der beiden ihn gestellt hat, ist hier nicht mehr zu
        // unterscheiden — also immer beides.
        refreshCalendar(now)
    }

    /**
     * Liest die Termine der nächsten 48 Stunden neu ein und legt sie ab. Wird vom
     * Wecker, vom [CalendarWatcher] und beim App-Start gerufen.
     */
    fun refreshCalendar(now: Long = System.currentTimeMillis()) {
        val zustand = engine.state()
        if (!zustand.calendar.enabled) return
        val quelle = ContentCalendarSource(context)
        val fenster = quelle.windows(zustand.calendar, now, now + CALENDAR_LOOKAHEAD_MILLIS)
        applyEffects(engine.updateWindows(fenster, now), now)
    }

    fun restoreAfterBoot(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.restoreAfterBoot(now), now)
    }

    /**
     * Profil speichern und die Wirkung sofort nachziehen. Eine geänderte Ruhe
     * verschiebt den Wecker und schaltet den Rückfall an oder aus — ohne diesen
     * Weg fiele das erst beim nächsten Ereignis auf.
     */
    fun updateProfile(profile: Profile, now: Long = System.currentTimeMillis()): Boolean {
        val gespeichert = engine.updateProfile(profile, now)
        if (gespeichert) applyEffects(engine.state(), now)
        return gespeichert
    }

    /** Löschen aus demselben Grund über den Controller: die Ruhe muss mit weg. */
    fun deleteProfile(id: String, now: Long = System.currentTimeMillis()): Boolean {
        val geloescht = engine.deleteProfile(id, now)
        if (geloescht) applyEffects(engine.state(), now)
        return geloescht
    }

    fun submitCode(code: String, now: Long = System.currentTimeMillis()): CodeResult {
        val result = engine.submitCode(code, now)
        applyEffects(result.state, now)
        return result
    }

    fun startLock(
        profileId: String,
        now: Long = System.currentTimeMillis(),
    ): StartOutcome {
        val result = engine.startLock(profileId, now)
        applyEffects(result.state, now)
        return result.outcome
    }

    /**
     * Freigabe auf Zeit, gerufen aus der Oberfläche. Zieht Wecker und
     * Benachrichtigung sofort nach — der Wecker ist es, der die Sperre später
     * ohne Zutun wieder greifen lässt.
     */
    fun startRelease(
        profileId: String,
        minutes: Int,
        now: Long = System.currentTimeMillis(),
    ): ReleaseOutcome {
        val result = engine.startRelease(profileId, minutes, now)
        applyEffects(result.state, now)
        return result.outcome
    }

    private fun applyEffects(state: LockState, now: Long = System.currentTimeMillis()) {
        LockScheduler.schedule(context, naechsterWecker(state, now))

        val kalenderSperrt = CalendarPlanner.lockedProfileIds(state.calendar, now).isNotEmpty()
        if (state.chipLock != null || state.timeLocks.isNotEmpty() || kalenderSperrt) {
            LockNotification.show(context, state, now)
        } else {
            LockNotification.hide(context)
        }

        // Ruhe: Erste Wahl ist der Anruffilter — er trifft genau die gewählten
        // Nummern und lässt alles andere in Ruhe. Hat Riegel die Rolle, ist hier
        // nichts zu tun; hat er sie nicht, bleibt „Bitte nicht stören" als
        // grober Rückfall. Wechselt die Rolle, räumt derselbe Aufruf ihn ab.
        QuietDnd(context).apply(
            QuietPlanner.isQuiet(state, now) && !CallScreening.held(context),
        )

        // Der Klingelmodus ist die zweite Hälfte der Ruhe: der Anruffilter trifft
        // einzelne Nummern, der Modus das ganze Telefon. Beides an derselben
        // Stelle, damit es nicht auseinanderlaufen kann.
        QuietRinger(context).apply(QuietPlanner.ringerMode(state, now))
    }

    /**
     * Der frühere von: Ende der nächsten Zeitsperre, nächste Fenstergrenze, und
     * eine Auffrischung in zwölf Stunden.
     *
     * Die Auffrischung ist nötig, weil der Wecker sonst an den Fenstergrenzen
     * hinge: ohne passenden Termin gibt es keine Grenze, also keinen Wecker, und
     * der Zwischenspeicher altert weg. Der [CalendarWatcher] fängt das nicht auf —
     * er lebt nur, solange der Prozess lebt.
     */
    private fun naechsterWecker(state: LockState, now: Long): Long {
        val kandidaten = mutableListOf<Long>()
        state.timeLocks.minOfOrNull { it.endsAt }?.let { kandidaten += it }
        state.release?.endsAt?.takeIf { now < it }?.let { kandidaten += it }
        if (state.calendar.enabled) {
            CalendarPlanner.nextBoundary(state.calendar, now)?.let { kandidaten += it }
            kandidaten += now + AUFFRISCHUNG_MILLIS
        }
        // Auch die Ruhe muss von allein anfangen und aufhören, ohne dass jemand
        // die App öffnet — dafür derselbe Wecker.
        QuietPlanner.nextBoundary(state, now)?.let { kandidaten += it }
        return kandidaten.minOrNull() ?: (now + AUFFRISCHUNG_MILLIS)
    }

    private companion object {
        const val AUFFRISCHUNG_MILLIS = 12L * 60 * 60 * 1000
    }
}
