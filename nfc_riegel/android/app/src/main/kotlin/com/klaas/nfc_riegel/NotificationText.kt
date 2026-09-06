package com.klaas.nfc_riegel

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Überschrift und Zeile der laufenden Benachrichtigung. */
data class NotificationContent(val title: String, val text: String)

/**
 * Was in der Benachrichtigung steht. Reine Rechnung ohne Android, damit sie per
 * JUnit prüfbar bleibt — [LockNotification] hängt nur noch außen dran.
 *
 * Die Trennung entstand, weil der Text in gemischten Lagen falsch war: lief eine
 * Freigabe und daneben eine Zeitsperre eines anderen Profils, standen beide
 * Profile unter „Freigabe läuft", obwohl nur eines offen war.
 */
object NotificationText {

    /** `null` heißt: nichts anzeigen. */
    fun content(state: LockState, now: Long): NotificationContent? {
        val freigabe = state.release?.takeIf { now < it.endsAt }

        // Dieselbe Ausnahme wie in LockEngine.lockedProfileIds: das freigegebene
        // Profil sperrt gerade nicht und gehört nicht in die Aufzählung.
        val gesperrteProfile = buildSet {
            state.chipLock?.profileId
                ?.takeIf { it != freigabe?.profileId }
                ?.let { add(it) }
            state.timeLocks.forEach { add(it.profileId) }
        }
        if (freigabe == null && gesperrteProfile.isEmpty()) return null

        val namen = gesperrteProfile.mapNotNull { state.profileById(it)?.name }
        val fruehestesEnde = state.timeLocks.minOfOrNull { it.endsAt }

        if (freigabe != null) {
            val freigegeben = state.profileById(freigabe.profileId)?.name ?: "Unbekannt"
            val rest = when {
                namen.isEmpty() -> " — danach wieder zu"
                namen.size == 1 -> ", ${namen.single()} bleibt gesperrt"
                else -> ", ${namen.joinToString(", ")} bleiben gesperrt"
            }
            return NotificationContent(
                title = "Freigabe läuft — $freigegeben",
                text = "Frei bis ${uhrzeit(freigabe.endsAt)}$rest",
            )
        }

        val anzahlApps = gesperrteProfile
            .flatMap { state.profileById(it)?.blockedPackages ?: emptySet() }
            .distinct()
            .size

        val text = when {
            fruehestesEnde != null && state.chipLock != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)}, der Rest nach erneutem Scan"
            fruehestesEnde != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)} — vorher nur mit Generalschlüssel"
            else -> "Chip scannen, um freizugeben"
        }

        val apps = if (anzahlApps == 1) "1 App gesperrt" else "$anzahlApps Apps gesperrt"
        return NotificationContent(
            title = "Riegel aktiv — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}, $apps",
            text = text,
        )
    }

    fun uhrzeit(millis: Long): String =
        SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(millis))
}
