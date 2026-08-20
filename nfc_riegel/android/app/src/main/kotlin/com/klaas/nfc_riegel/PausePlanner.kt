package com.klaas.nfc_riegel

/** Was der Nutzer je Profil an der Atempause einstellt. */
data class PauseSettings(
    val enabled: Boolean = false,
    /** Abstand der Stufen in Minuten Tagesnutzung. */
    val stepMinutes: Int = 15,
    /** Wartezeit der ersten Stufe in Sekunden; danach verdoppelt sie sich. */
    val baseSeconds: Int = 5,
    /**
     * So lange muss die App unbenutzt bleiben, damit die Staffelung von vorn
     * beginnt. Gemessen wird die Zeit **am Stück**, nicht die Tagessumme: wer
     * wirklich weglegt, faengt wieder bei null an.
     */
    val resetMinutes: Int = 15,
)

data class PauseDecision(
    /** Wartezeit in Sekunden — oder null, wenn keine Pause fällig ist. */
    val waitSeconds: Int?,
    /** Erreichte Stufe. Wird gespeichert, damit sie nicht erneut auslöst. */
    val step: Int,
    /**
     * Vordergrundmillisekunden bis zur nächsten Stufe — oder null, wenn es
     * nichts zu erwarten gibt. Darauf legt der Dienst seinen nächsten Blick.
     */
    val nextCheckAfterMillis: Long?,
)

/**
 * Rechnet aus der heutigen Nutzung einer App, ob eine Atempause fällig ist, wie
 * lang sie dauert und wann der nächste Blick nötig wird.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object PausePlanner {

    /**
     * Länger als eine Minute wäre Schikane statt Denkpause — und Schikane
     * erzeugt Umgehungen statt Einsicht.
     */
    const val MAX_WAIT_SECONDS = 60

    fun decide(
        settings: PauseSettings,
        usedMillis: Long,
        lastShownStep: Int,
    ): PauseDecision {
        // Eine kaputte Einstellung darf nicht in eine Dauerpause führen.
        if (!settings.enabled || settings.stepMinutes <= 0) {
            return PauseDecision(null, lastShownStep, null)
        }

        val stufenMillis = settings.stepMinutes * 60_000L
        val stufe = (usedMillis / stufenMillis).toInt()
        val bisZurNaechsten = (stufe + 1) * stufenMillis - usedMillis

        // Mehrere Stufen auf einmal ergeben eine Pause mit der Wartezeit der
        // höchsten erreichten — vier Pausen hintereinander wären eine Strafe.
        if (stufe > lastShownStep) {
            return PauseDecision(wartezeit(stufe, settings.baseSeconds), stufe, bisZurNaechsten)
        }
        // Auch ohne faellige Pause die tatsaechlich erreichte Stufe melden: faellt
        // sie unter die gespeicherte, hat eine neue Sitzung begonnen, und der
        // Aufrufer muss den Zaehler zuruecksetzen.
        return PauseDecision(null, stufe, bisZurNaechsten)
    }

    private fun wartezeit(stufe: Int, baseSeconds: Int): Int {
        var wert = baseSeconds.toLong()
        repeat(stufe - 1) {
            wert *= 2
            if (wert >= MAX_WAIT_SECONDS) return MAX_WAIT_SECONDS
        }
        return wert.coerceIn(0L, MAX_WAIT_SECONDS.toLong()).toInt()
    }

    /**
     * Steht eine App in mehreren Profilen, gilt der kleinste Stufenabstand und
     * die längste Grundwartezeit. Strenger stellen ist immer erlaubt, lockerer
     * nie — dieselbe Linie wie bei den Zeitsperren.
     *
     * Null heißt: keines der Profile will eine Pause.
     */
    fun merge(alle: List<PauseSettings>): PauseSettings? {
        val an = alle.filter { it.enabled && it.stepMinutes > 0 }
        if (an.isEmpty()) return null
        return PauseSettings(
            enabled = true,
            stepMinutes = an.minOf { it.stepMinutes },
            baseSeconds = an.maxOf { it.baseSeconds },
            // Laengeres Zuruecksetzen ist das strengere: die Staffelung haelt
            // laenger durch.
            resetMinutes = an.maxOf { it.resetMinutes },
        )
    }
}
