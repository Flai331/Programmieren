package com.klaas.nfc_riegel

/** Hält den Zustand im Speicher. Ersetzt SharedPreferences im Test. */
class FakeLockStore(initial: LockState = LockState()) : LockStore {
    var current: LockState = initial
        private set

    override fun load(): LockState = current

    override fun save(state: LockState) {
        current = state
    }
}
