package com.klaas.nfc_riegel

/** Wen die Ruhe stumm schaltet. */
enum class QuietScope {
    /** Jeder Anruf wird stumm geschaltet. */
    ALLE,

    /** Nur die ausgewählten Nummern werden stumm, alle anderen klingeln. */
    AUSGEWAEHLTE,

    /** Alle werden stumm — außer den ausgewählten. */
    ALLE_AUSSER,
}

/**
 * Ein wiederkehrendes Zeitfenster, etwa „Mo–Fr 22:00–06:00".
 *
 * [endMinute] kleiner oder gleich [startMinute] heißt: das Fenster läuft über
 * Mitternacht. Gleiche Werte ergeben volle 24 Stunden — das ist die einzige
 * sinnvolle Lesart, wenn Anfang und Ende zusammenfallen.
 */
data class QuietSchedule(
    /** Wochentage nach `java.util.Calendar`: SUNDAY = 1 … SATURDAY = 7. */
    val days: Set<Int> = emptySet(),
    /** Minuten seit Mitternacht. */
    val startMinute: Int = 22 * 60,
    /** Minuten seit Mitternacht. */
    val endMinute: Int = 6 * 60,
)

/**
 * Der Klingelmodus, den die Ruhe setzt. [UNVERAENDERT] heißt: das Telefon wird
 * nicht angefasst — die Vorgabe, damit bestehende Profile bleiben, wie sie sind.
 *
 * Die Reihenfolge ist die Rangfolge: weiter unten heißt leiser und gewinnt in
 * [QuietPlanner.ringerMode]. Nicht umsortieren.
 */
enum class RingerMode { UNVERAENDERT, LAUT, VIBRIEREN, LAUTLOS }

/**
 * Ruhe am Profil — Anrufe stumm schalten, ohne die App zu sperren. Steht neben
 * [PauseSettings] am selben Ort, weil beides dieselbe Frage beantwortet: was
 * passiert, während dieses Profil gilt.
 *
 * Ausgelöst wird sie von drei Dingen, die sich überlagern dürfen: einem
 * laufenden Termin dieses Profils samt [afterEventMinutes] Nachlauf, einem
 * Fenster aus [schedules], und — falls [whileLocked] — jeder laufenden Sperre
 * des Profils.
 */
data class QuietSettings(
    val enabled: Boolean = false,
    val scope: QuietScope = QuietScope.ALLE,
    /** Ausgewählte Rufnummern, normalisiert über [PhoneNumbers.normalize]. */
    val numbers: Set<String> = emptySet(),
    /** Nachlauf nach dem Ende eines Termins dieses Profils, in Minuten. */
    val afterEventMinutes: Int = 0,
    /** Ruhe auch, solange eine Sperre dieses Profils läuft. */
    val whileLocked: Boolean = true,
    val schedules: List<QuietSchedule> = emptyList(),
    /** Klingelmodus, solange diese Ruhe greift. */
    val ringer: RingerMode = RingerMode.UNVERAENDERT,
)
