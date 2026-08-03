package com.klaas.nfc_riegel

import android.content.Context

/** Legt den Zustand in SharedPreferences ab. Einzige Android-Abhängigkeit der Datenschicht. */
class SharedPrefsLockStore(context: Context) : LockStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    override fun load(): LockState = LockState(
        locked = prefs.getBoolean(KEY_LOCKED, false),
        mode = if (prefs.getString(KEY_MODE, "TIMER") == "OPEN") LockMode.OPEN else LockMode.TIMER,
        endsAt = prefs.getLong(KEY_ENDS_AT, -1L).takeIf { it > 0 },
        durationMinutes = prefs.getInt(KEY_DURATION, 60),
        blockedPackages = prefs.getStringSet(KEY_PACKAGES, emptySet()) ?: emptySet(),
        tagUid = prefs.getString(KEY_TAG_UID, null),
        codeHash = prefs.getString(KEY_CODE_HASH, null),
        failedAttempts = prefs.getInt(KEY_ATTEMPTS, 0),
        codeLockedUntil = prefs.getLong(KEY_CODE_LOCKED_UNTIL, -1L).takeIf { it > 0 },
    )

    override fun save(state: LockState) {
        prefs.edit()
            .putBoolean(KEY_LOCKED, state.locked)
            .putString(KEY_MODE, state.mode.name)
            .putLong(KEY_ENDS_AT, state.endsAt ?: -1L)
            .putInt(KEY_DURATION, state.durationMinutes)
            .putStringSet(KEY_PACKAGES, state.blockedPackages)
            .putString(KEY_TAG_UID, state.tagUid)
            .putString(KEY_CODE_HASH, state.codeHash)
            .putInt(KEY_ATTEMPTS, state.failedAttempts)
            .putLong(KEY_CODE_LOCKED_UNTIL, state.codeLockedUntil ?: -1L)
            .apply()
    }

    private companion object {
        const val KEY_LOCKED = "locked"
        const val KEY_MODE = "mode"
        const val KEY_ENDS_AT = "endsAt"
        const val KEY_DURATION = "durationMinutes"
        const val KEY_PACKAGES = "blockedPackages"
        const val KEY_TAG_UID = "tagUid"
        const val KEY_CODE_HASH = "codeHash"
        const val KEY_ATTEMPTS = "failedAttempts"
        const val KEY_CODE_LOCKED_UNTIL = "codeLockedUntil"
    }
}
