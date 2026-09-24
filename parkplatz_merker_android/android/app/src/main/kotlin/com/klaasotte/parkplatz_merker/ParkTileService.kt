package com.klaasotte.parkplatz_merker

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService

class ParkTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile
        if (tile != null) {
            tile.label = "Hier geparkt"
            tile.state = android.service.quicksettings.Tile.STATE_INACTIVE
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, ParkHereActivity::class.java)
        intent.putExtra("source", "tile")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        val pendingIntent = PendingIntent.getActivity(
            this,
            4,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
