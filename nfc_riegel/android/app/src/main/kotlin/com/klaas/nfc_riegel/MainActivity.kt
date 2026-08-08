package com.klaas.nfc_riegel

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private val calendarWatcher by lazy { CalendarWatcher(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zustand nach App-Start begradigen: abgelaufener Timer wird sofort aufgelöst.
        val controller = LockController(this)
        controller.expire()
        controller.refreshCalendar()
        calendarWatcher.start()
        RiegelChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        requestNotificationPermission()
    }

    /**
     * Beim ersten Start fehlt `READ_CALENDAR`, der Beobachter kommt dann nicht
     * zustande. Nach dem Erteilen kehrt der Nutzer hierher zurück — der zweite
     * Versuch holt ihn nach.
     */
    override fun onResume() {
        super.onResume()
        calendarWatcher.start()
    }

    override fun onDestroy() {
        calendarWatcher.stop()
        super.onDestroy()
    }

    /**
     * Seit Android 13 muss POST_NOTIFICATIONS zur Laufzeit erteilt werden. Ohne sie
     * bleibt die Benachrichtigung während einer Sperre stumm, ohne dass irgendwo
     * ein Fehler auftaucht. Ablehnen ist erlaubt — die Sperre wirkt trotzdem, man
     * sieht sie nur nicht mehr im Schirm.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 1001
    }
}
