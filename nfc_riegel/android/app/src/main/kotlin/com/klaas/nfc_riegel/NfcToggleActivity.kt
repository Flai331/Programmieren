package com.klaas.nfc_riegel

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

/**
 * Wird vom Chip gestartet. Prüft die UID, togglet, meldet kurz das Ergebnis
 * und verschwindet wieder — ohne Oberfläche.
 */
class NfcToggleActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val tag = intent?.let { NfcSupport.tagFrom(it) }
        if (tag == null) {
            toastAndFinish("Chip nicht lesbar")
            return
        }

        val uid = NfcSupport.toHex(tag.id)
        val result = LockController(this).scan(uid)

        val profileName = result.state.chipLock
            ?.let { lock -> result.state.profileById(lock.profileId)?.name }

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — $profileName"
            ScanOutcome.SWITCHED -> "Gewechselt auf $profileName"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            ScanOutcome.MASTER_CLEARED -> "Alle Sperren beendet"
            ScanOutcome.UNKNOWN_TAG -> "Fremder Chip"
            ScanOutcome.NO_TAG_ENROLLED -> "Erst in der App einen Chip anlernen"
            ScanOutcome.NO_PROFILE -> "Profil dieses Chips existiert nicht mehr"
            ScanOutcome.UNTIL_IN_PAST -> "Zeitpunkt liegt in der Vergangenheit"
        }
        toastAndFinish(message)
    }

    private fun toastAndFinish(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        finish()
    }
}
