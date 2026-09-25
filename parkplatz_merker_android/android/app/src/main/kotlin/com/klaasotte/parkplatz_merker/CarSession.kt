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

    /** Routine-Test aus der App: Sitzung neu beginnen, auch wenn schon eine läuft. */
    fun testStart(ctx: Context) {
        EventLog.info(ctx, "Routine-Test: Einsteigen")
        Config.sessionActive = false
        start(ctx)
    }

    /** Routine-Test aus der App: Aussteigen wie im Auto. */
    fun testEnd(ctx: Context) {
        EventLog.info(ctx, "Routine-Test: Aussteigen")
        if (!Config.sessionActive) {
            Config.sessionActive = true
            Config.sessionSince = System.currentTimeMillis()
        }
        end(ctx)
    }

    fun end(ctx: Context) {
        if (!Config.sessionActive) return
        Config.sessionActive = false
        EventLog.info(ctx, "Im Auto: Sitzung endet")
        if (Config.closeOnGone) AppLauncher.closeAll(ctx)
        VolumeProfile.restore(ctx)
    }
}
