package com.klaas.nfc_riegel

/** Ablage des Zustands. Eine Umsetzung für Android, eine für Tests. */
interface LockStore {
    fun load(): LockState
    fun save(state: LockState)
}
