package com.klaas.nfc_riegel

import android.content.Context
import java.util.Calendar
import java.util.TimeZone

/**
 * Merkt sich je App die zuletzt gezeigte Stufe, zusammen mit dem Tag, für den
 * sie galt. Wechselt das Datum, fängt die Staffelung von vorn an.
 *
 * Bewusst neben [LockState], nicht darin: eine Atempause ist keine Sperre. Der
 * Sperrzustand ist die eine Sache in dieser App, die niemals durcheinander-
 * kommen darf.
 */
class PauseStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences("riegel_pausen", Context.MODE_PRIVATE)

    fun lastStep(packageName: String, now: Long): Int {
        val roh = prefs.getString(packageName, null) ?: return 0
        val teile = roh.split('|')
        if (teile.size != 2) return 0
        if (teile[0] != tagesschluessel(now)) return 0
        return teile[1].toIntOrNull() ?: 0
    }

    fun remember(packageName: String, step: Int, now: Long) {
        prefs.edit().putString(packageName, "${tagesschluessel(now)}|$step").apply()
    }

    /**
     * Jahr und Tag im Jahr. Reicht als Kennung und macht den Mitternachts-
     * wechsel ohne Datumsrechnung erkennbar.
     */
    private fun tagesschluessel(now: Long): String {
        val kalender = Calendar.getInstance(TimeZone.getDefault())
        kalender.timeInMillis = now
        return "${kalender.get(Calendar.YEAR)}-${kalender.get(Calendar.DAY_OF_YEAR)}"
    }
}
