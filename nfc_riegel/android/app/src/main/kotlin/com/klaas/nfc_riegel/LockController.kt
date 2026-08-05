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
        applyEffects(engine.onTimerElapsed(now))
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

    private fun applyEffects(state: LockState) {
        val naechstesEnde = state.timeLocks.minOfOrNull { it.endsAt }
        if (naechstesEnde != null) {
            LockScheduler.schedule(context, naechstesEnde)
        } else {
            LockScheduler.cancel(context)
        }

        if (state.chipLock != null || state.timeLocks.isNotEmpty()) {
            LockNotification.show(context, state)
        } else {
            LockNotification.hide(context)
        }
    }
}
