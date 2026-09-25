package com.klaasotte.parkplatz_merker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

class BackgroundRunReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Handler(Looper.getMainLooper()).post {
            BackgroundRunner.run(context) { pending.finish() }
        }
    }
}
