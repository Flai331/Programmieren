package com.klaasotte.parkplatz_merker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Config.init(context)
        Transitions.register(context)
        BeaconBackground.start(context)

        Reminder.onBoot(context)
    }
}
