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
        applyEffects(result.state)
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
        applyEffects(engine.restoreAfterBoot(now))
    }

    fun submitCode(code: String, now: Long = System.currentTimeMillis()): CodeResult {
        val result = engine.submitCode(code, now)
        applyEffects(result.state)
        return result
    }

    fun startTimeLock(
        profileId: String,
        now: Long = System.currentTimeMillis(),
    ): StartOutcome {
        val result = engine.startTimeLock(profileId, now)
        applyEffects(result.state)
        return result.outcome
    }

    private fun applyEffects(state: LockState, now: Long = System.currentTimeMillis()) {
        LockScheduler.schedule(context, naechsterWecker(state, now))

        val kalenderSperrt = CalendarPlanner.lockedProfileIds(state.calendar, now).isNotEmpty()
        if (state.chipLock != null || state.timeLocks.isNotEmpty() || kalenderSperrt) {
            LockNotification.show(context, state)
        } else {
            LockNotification.hide(context)
        }
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
        if (state.calendar.enabled) {
            CalendarPlanner.nextBoundary(state.calendar, now)?.let { kandidaten += it }
            kandidaten += now + AUFFRISCHUNG_MILLIS
        }
        return kandidaten.minOrNull() ?: (now + AUFFRISCHUNG_MILLIS)
    }

    private companion object {
        const val AUFFRISCHUNG_MILLIS = 12L * 60 * 60 * 1000
    }
}
