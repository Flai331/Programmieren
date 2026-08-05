package com.klaas.nfc_riegel

import android.content.Context

/**
 * Legt den Zustand in SharedPreferences ab. Einzige Android-Abhängigkeit der
 * Datenschicht. Fehlt der Schlüssel [KEY_PROFILES], liegt noch ein v1-Zustand
 * vor — er wird einmalig migriert und sofort im neuen Format zurückgeschrieben.
 */
class SharedPrefsLockStore(context: Context) : LockStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    override fun load(): LockState {
        if (!prefs.contains(KEY_PROFILES)) {
            val migrated = migrateFromV1()
            save(migrated)
            return migrated
        }
        val rohChipLock = prefs.getString(KEY_CHIP_LOCK, "") ?: ""
        val zeitsperren = LockCodec.decodeTimeLocks(prefs.getString(KEY_TIME_LOCKS, "") ?: "")
        // Aus v2 kann im chipLock-Feld noch eine TIMER- oder UNTIL-Sperre stecken.
        // Abgelaufene wird verworfen; sie hat ohnehin keine Wirkung mehr.
        val ausV2 = LockCodec.decodeLegacyTimeLock(rohChipLock)
            ?.takeIf { System.currentTimeMillis() < it.endsAt }
            ?.takeIf { alt -> zeitsperren.none { it.profileId == alt.profileId } }

        return LockState(
            profiles = LockCodec.decodeProfiles(prefs.getString(KEY_PROFILES, "") ?: ""),
            tags = LockCodec.decodeTags(prefs.getString(KEY_TAGS, "") ?: ""),
            chipLock = LockCodec.decodeChipLock(rohChipLock),
            timeLocks = if (ausV2 == null) zeitsperren else zeitsperren + ausV2,
            codeHash = prefs.getString(KEY_CODE_HASH, null),
            failedAttempts = prefs.getInt(KEY_ATTEMPTS, 0),
            codeLockedUntil = prefs.getLong(KEY_CODE_LOCKED_UNTIL, -1L).takeIf { it > 0 },
        )
    }

    override fun save(state: LockState) {
        prefs.edit()
            .putString(KEY_PROFILES, LockCodec.encodeProfiles(state.profiles))
            .putString(KEY_TAGS, LockCodec.encodeTags(state.tags))
            .putString(KEY_CHIP_LOCK, LockCodec.encodeChipLock(state.chipLock))
            .putString(KEY_TIME_LOCKS, LockCodec.encodeTimeLocks(state.timeLocks))
            .putString(KEY_CODE_HASH, state.codeHash)
            .putInt(KEY_ATTEMPTS, state.failedAttempts)
            .putLong(KEY_CODE_LOCKED_UNTIL, state.codeLockedUntil ?: -1L)
            .apply()
    }

    private fun migrateFromV1(): LockState = LockMigration.fromV1(
        locked = prefs.getBoolean("locked", false),
        mode = runCatching { LockMode.valueOf(prefs.getString("mode", "TIMER") ?: "TIMER") }
            .getOrDefault(LockMode.TIMER),
        endsAt = prefs.getLong("endsAt", -1L).takeIf { it > 0 },
        durationMinutes = prefs.getInt("durationMinutes", 60),
        blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet(),
        tagUid = prefs.getString("tagUid", null),
        codeHash = prefs.getString("codeHash", null),
    )

    private companion object {
        const val KEY_PROFILES = "profiles"
        const val KEY_TAGS = "tags"
        const val KEY_CHIP_LOCK = "chipLock"
        const val KEY_TIME_LOCKS = "timeLocks"
        const val KEY_CODE_HASH = "codeHash"
        const val KEY_ATTEMPTS = "failedAttempts"
        const val KEY_CODE_LOCKED_UNTIL = "codeLockedUntil"
    }
}
