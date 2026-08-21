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
