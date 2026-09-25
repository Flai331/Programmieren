package com.klaasotte.parkplatz_merker

import android.content.Context

object CarSession {
    fun start(ctx: Context) {
        if (Config.sessionActive) return
        Config.sessionActive = true
        val now = System.currentTimeMillis()
        Config.sessionSince = now
        EventLog.info(ctx, "Im Auto: Sitzung beginnt")
        VolumeProfile.apply(ctx)
        AppLauncher.launchAll(ctx)
    }

    fun end(ctx: Context) {
        if (!Config.sessionActive) return
        Config.sessionActive = false
        EventLog.info(ctx, "Im Auto: Sitzung endet")
        if (Config.closeOnGone) AppLauncher.closeAll(ctx)
        VolumeProfile.restore(ctx)
    }
}
