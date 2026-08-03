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

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — ${result.state.blockedPackages.size} Apps gesperrt"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            ScanOutcome.UNKNOWN_TAG -> "Fremder Chip"
            ScanOutcome.NO_TAG_ENROLLED -> "Erst in der App einen Chip anlernen"
        }
        toastAndFinish(message)
    }

    private fun toastAndFinish(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        finish()
    }
}
