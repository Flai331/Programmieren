package com.klaasotte.parkplatz_merker

import android.content.Context

object CarSession {
    fun start(ctx: Context) {
        val now = System.currentTimeMillis()
        // Schutz vor hängendem Zustand: nach 12 h gilt eine alte Sitzung als beendet.
        if (Config.sessionActive && now - Config.sessionSince < 12 * 60 * 60_000L) return
        Config.sessionActive = true
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
