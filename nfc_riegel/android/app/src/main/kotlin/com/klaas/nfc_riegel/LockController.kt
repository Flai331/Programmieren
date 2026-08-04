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

    private fun applyEffects(state: LockState) {
        val lock = state.chipLock
        if (lock != null) {
            val endsAt = lock.endsAt
            if (endsAt != null) LockScheduler.schedule(context, endsAt)
            else LockScheduler.cancel(context)
            LockNotification.show(context, state)
        } else {
            LockScheduler.cancel(context)
            LockNotification.hide(context)
        }
    }
}
