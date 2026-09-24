package com.klaas.nfc_riegel

/**
 * Dauer in Worten, wie `formatUsage` in `lib/screen_time.dart` — hier ohne
 * Flutter, weil Sperrschirm und Atempause eigene Android-Ansichten sind.
 *
 * Sekunden kommen nirgends vor: sie ändern sich beim Hinsehen und tragen zur
 * Aussage nichts bei.
 */
fun formatiereDauer(millis: Long): String {
    val minuten = millis / 60_000L
    return if (minuten < 60) "$minuten min" else "${minuten / 60} h ${minuten % 60} min"
}

/**
 * Uhrzeit, zu der eine Freigabe von [minuten] ab [jetztMillis] endet — die
 * Frage beim Aufsperren ist nicht „wie lange", sondern „bis wann".
 */
fun endeUhrzeit(jetztMillis: Long, minuten: Int): String =
    NotificationText.uhrzeit(jetztMillis + minuten * 60_000L)
