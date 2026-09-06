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
        val state = result.state
        val now = System.currentTimeMillis()

        // Ein Scan kann eine Chipsperre oder eine Zeitsperre erzeugt haben.
        val profileId = state.chipLock?.profileId
            ?: state.timeLocks.filter { now < it.endsAt }.maxByOrNull { it.endsAt }?.profileId
        val profileName = profileId?.let { state.profileById(it)?.name } ?: "Riegel"

        if (result.outcome == ScanOutcome.ASK_RELEASE) {
            // Der Zustand ist unveraendert — gefragt wird erst, gesperrt bleibt es
            // so lange. Das Profil steckt am Chip, nicht in der Sperre.
            val chip = state.tagByUid(uid)
            val gefragtesProfil = chip?.profileId?.let { state.profileById(it) }
            startActivity(
                Intent(this, ReleaseActivity::class.java)
                    .putExtra(ReleaseActivity.EXTRA_PROFILE_ID, gefragtesProfil?.id ?: "")
                    .putExtra(ReleaseActivity.EXTRA_PROFILE_NAME, gefragtesProfil?.name ?: "Riegel")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            finish()
            return
        }

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — $profileName"
            ScanOutcome.RELOCKED -> "Riegel wieder zu — $profileName"
            ScanOutcome.SWITCHED -> "Gewechselt auf $profileName"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            // Wird nie erreicht: ASK_RELEASE steigt oben schon aus. Der Text
            // waere aber auch dann nicht falsch, sollte der fruehe Ausstieg
            // einmal fehlen.
            ScanOutcome.ASK_RELEASE -> "Riegel offen"
            ScanOutcome.MASTER_CLEARED -> "Alle Sperren beendet"
            ScanOutcome.EXTENDED -> "Sperre verlängert — $profileName"
            ScanOutcome.TIME_LOCK_RUNNING -> "Zeitsperre läuft — nur ein Generalschlüssel öffnet"
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
