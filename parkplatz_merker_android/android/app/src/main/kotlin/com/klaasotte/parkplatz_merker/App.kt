package com.klaasotte.parkplatz_merker

import android.app.Application

/**
 * Läuft in jedem Prozessstart zuerst – auch wenn nur ein Receiver oder der
 * Service geweckt wird. Deshalb wird hier [Config] initialisiert.
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Config.init(this)
        Notifications.ensureChannels(this)
    }
}
