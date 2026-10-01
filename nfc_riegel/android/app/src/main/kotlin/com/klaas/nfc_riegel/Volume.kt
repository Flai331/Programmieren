package com.klaas.nfc_riegel

/**
 * Die Lautstärken, die ein Profil während seiner Sperre einzeln setzen kann.
 * Die Namen sind gespeichert — nicht umbenennen.
 */
enum class VolumeStream { MEDIEN, KLINGELTON, BENACHRICHTIGUNG, WECKER }

/**
 * Rechnet aus, welche Lautstärken gerade gelten. Reine Funktionen ohne Android,
 * wie [QuietPlanner], damit sich alles per JUnit prüfen lässt.
 */
object VolumePlanner {

    /**
     * Lautstärke je Strom in Prozent, solange eines der [lockedIds]-Profile
     * sperrt. Fehlt ein Strom, bleibt er unverändert.
     *
     * Sperren mehrere Profile mit Vorgaben für denselben Strom, gewinnt die
     * leiseste — dieselbe Doktrin wie beim Klingelmodus: ein Profil kann die
     * Ruhe eines anderen nicht aufheben.
     */
    fun targets(profiles: List<Profile>, lockedIds: Set<String>): Map<VolumeStream, Int> =
        profiles
            .filter { it.id in lockedIds }
            .flatMap { it.volumes.entries }
            .groupBy({ it.key }, { it.value.coerceIn(0, 100) })
            .mapValues { (_, werte) -> werte.min() }

    /**
     * Prozent → Stufe des Stroms. Gerundet statt abgeschnitten, damit 50 % bei
     * sieben Stufen nicht zu drei werden, und auf [min] bis [max] begrenzt:
     * der Wecker etwa hat ab Android 9 eine Untergrenze über null.
     */
    fun stufe(prozent: Int, max: Int, min: Int = 0): Int =
        ((prozent.coerceIn(0, 100) * max + 50) / 100).coerceIn(min, max)
}
