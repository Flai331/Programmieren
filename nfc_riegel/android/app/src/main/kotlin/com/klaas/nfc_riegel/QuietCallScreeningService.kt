package com.klaas.nfc_riegel

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import androidx.annotation.RequiresApi

/**
 * Entscheidet je eingehendem Anruf, ob er klingeln darf. Android fragt hier nur
 * nach, wenn Riegel die Anruffilter-Rolle hält — siehe [CallScreening].
 *
 * Stumm heißt: kein Klingeln, kein Vibrieren. Der Anruf selbst läuft weiter und
 * steht hinterher im Anrufprotokoll. Bewusst kein Abweisen — Riegel soll dich
 * in Ruhe lassen, nicht für dich auflegen.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class QuietCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val antwort = CallScreeningService.CallResponse.Builder()

        if (callDetails.callDirection == Call.Details.DIRECTION_INCOMING && stummSchalten(callDetails)) {
            antwort.setSilenceCall(true)
        }

        respondToCall(callDetails, antwort.build())
    }

    private fun stummSchalten(callDetails: Call.Details): Boolean {
        val zustand = LockEngine(SharedPrefsLockStore(this)).state()
        val jetzt = System.currentTimeMillis()
        val profile = QuietPlanner.quietProfiles(zustand, jetzt)
        if (profile.isEmpty()) return false

        // `handle` ist bei unterdrückter Nummer null. Das ist kein Fehler,
        // sondern eine Angabe: der Planer entscheidet je nach Auswahlart.
        val nummer = callDetails.handle?.schemeSpecificPart
        return QuietPlanner.silences(profile, nummer)
    }
}
