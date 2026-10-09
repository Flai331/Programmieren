package de.klaas.akku_schoner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Startet den Akku-Wächter nach Neustart / App-Update wieder, falls er an ist. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WatcherService.sync(context)
    }
}
