package com.klaas.nfc_riegel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Ein Update stoppt die App wie ein Neustart des Geräts: der gestellte Wecker
 * fällt weg und die Benachrichtigung verschwindet. Die Sperre selbst überlebt —
 * sie steht im Speicher —, aber ohne Wecker endet eine Zeitsperre nicht mehr von
 * selbst, und ohne Benachrichtigung sieht man nicht mehr, dass gesperrt ist.
 *
 * Deshalb derselbe Wiederanlauf wie nach dem Hochfahren.
 */
class PackageReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LockController(context).restoreAfterBoot()
    }
}
