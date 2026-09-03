package com.klaas.nfc_riegel

/**
 * Rufnummern vergleichbar machen, ohne eine Bibliothek dafür einzubinden.
 *
 * Dieselbe Nummer erreicht das Gerät in vielen Schreibweisen: `+49 151 1234567`,
 * `0049 151 1234567`, `0151 1234567`, mit Klammern, Bindestrichen oder
 * Leerzeichen. Statt die Landesvorwahl zu raten — dafür bräuchte es die Region
 * des Anrufers — werden nur die Ziffern verglichen, und davon die letzten
 * [VERGLEICHSSTELLEN]. Der Teilnehmeranschluss steht immer hinten; alles davor
 * unterscheidet sich je nach Schreibweise.
 */
object PhoneNumbers {

    /**
     * So viele Stellen von hinten werden verglichen. Acht ist der Kompromiss:
     * kurz genug, dass `+49151…` und `0151…` zusammenfallen, lang genug, dass
     * zwei verschiedene Anschlüsse nicht zufällig übereinstimmen.
     */
    private const val VERGLEICHSSTELLEN = 8

    /** Zu wenige Ziffern für einen sinnvollen Vergleich — etwa Kurzwahlen. */
    private const val MINDESTSTELLEN = 5

    /** Nur die Ziffern. Aus `+49 (0)151 12-34` wird `4901511234`. */
    fun normalize(raw: String?): String =
        raw?.filter { it.isDigit() } ?: ""

    /**
     * Zwei Nummern gelten als dieselbe, wenn ihre letzten [VERGLEICHSSTELLEN]
     * Ziffern übereinstimmen. Sind beide kürzer, müssen sie ganz gleich sein.
     *
     * Unter [MINDESTSTELLEN] wird nichts verglichen: eine dreistellige Kurzwahl
     * würde sonst auf jede Nummer passen, die zufällig so endet.
     */
    fun matches(a: String, b: String): Boolean {
        val x = normalize(a)
        val y = normalize(b)
        if (x.length < MINDESTSTELLEN || y.length < MINDESTSTELLEN) return x == y && x.isNotEmpty()

        val stellen = minOf(VERGLEICHSSTELLEN, x.length, y.length)
        return x.takeLast(stellen) == y.takeLast(stellen)
    }

    /** Steht die Nummer in der Auswahl? */
    fun contains(numbers: Set<String>, number: String?): Boolean {
        val gesucht = normalize(number)
        if (gesucht.isEmpty()) return false
        return numbers.any { matches(it, gesucht) }
    }
}
