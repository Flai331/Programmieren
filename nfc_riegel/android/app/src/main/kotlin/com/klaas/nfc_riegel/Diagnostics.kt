package com.klaas.nfc_riegel

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Fasst den Sperrzustand für einen Fehlerbericht zusammen.
 *
 * Bewusst ohne Tag-UIDs und ohne den Hash des Notfall-Codes: ein Bericht wandert
 * in eine Notion-Datenbank, und beides wäre dort ein Schlüssel zur Wohnung.
 * Paketnamen bleiben drin — ohne sie ist ein Blockier-Fehler nicht zu deuten.
 */
object Diagnostics {

    fun summarize(state: LockState, now: Long): Map<String, String> {
        val lock = state.chipLock?.takeIf { l ->
            val endsAt = l.endsAt
            endsAt == null || now < endsAt
        }

        val lockLine = if (lock == null) {
            "offen"
        } else {
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            val ende = lock.endsAt?.let {
                " bis " + SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(it))
            } ?: ""
            "gesperrt · $name · ${lock.mode.name}$ende"
        }

        val profiles = if (state.profiles.isEmpty()) "keine"
        else state.profiles.joinToString(" | ") { p ->
            val ende = p.untilAt?.let {
                " bis " + SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(it))
            } ?: ""
            "${p.name}: ${p.blockedPackages.size} Apps, ${p.defaultMode.name}, " +
                "${p.durationMinutes} min$ende"
        }

        val chips = if (state.tags.isEmpty()) "keine"
        else state.tags.joinToString(" | ") { t ->
            val profil = state.profileById(t.profileId)?.name ?: "?"
            "${t.label} → $profil${if (t.isMaster) " (General)" else ""}"
        }

        val packages = state.profiles
            .flatMap { it.blockedPackages }
            .distinct()
            .sorted()
            .joinToString(", ")
            .ifEmpty { "keine" }

        return linkedMapOf(
            "Sperre" to lockLine,
            "Profile" to profiles,
            "Chips" to chips,
            "Gesperrte Pakete" to packages,
            "Notfall-Code" to if (state.codeHash != null) "ja" else "nein",
        )
    }
}
