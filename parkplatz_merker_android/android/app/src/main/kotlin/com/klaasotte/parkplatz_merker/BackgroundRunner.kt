package com.klaasotte.parkplatz_merker

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector
import java.util.concurrent.atomic.AtomicBoolean

object BackgroundRunner {
    @Volatile
    private var engine: FlutterEngine? = null

    /**
     * Plant eine Ausführung des Hintergrund-Laufs.
     * [requestCode] dient zur Unterscheidung mehrerer geplanter Aufrufe.
     */
    fun schedule(ctx: Context, delayMs: Long, requestCode: Int) {
        try {
            val pi = android.app.PendingIntent.getBroadcast(
                ctx, requestCode,
                android.content.Intent(ctx, BackgroundRunReceiver::class.java),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val at = System.currentTimeMillis() + delayMs
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (am != null) {
                if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                }
            }
        } catch (e: Exception) {
            EventLog.info(ctx, "BackgroundRunner.schedule fehlgeschlagen: ${e.message}")
        }
    }

    /**
     * Startet die Hintergrund-Engine. [done] wird genau einmal aufgerufen (Ende oder Zeitlimit 25 s).
     * Muss auf dem Main-Thread aufgerufen werden.
     */
    fun run(ctx: Context, done: () -> Unit) {
        try {
            if (MainActivity.visible || engine != null) {
                done()
                return
            }

            val app = ctx.applicationContext
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationComplete(app, null)

            val e = FlutterEngine(app) // registriert Plugins automatisch
            engine = e

            val finished = AtomicBoolean(false)
            val handler = Handler(Looper.getMainLooper())
            var timeout: Runnable? = null

            val finish: () -> Unit = {
                if (!finished.getAndSet(true)) {
                    if (timeout != null) handler.removeCallbacks(timeout!!)
                    try {
                        e.destroy()
                    } catch (ex: Exception) {
                        // ignorieren
                    }
                    engine = null
                    done()
                }
            }

            timeout = Runnable {
                EventLog.info(app, "Hintergrund-Lauf: Zeitlimit")
                finish()
            }

            MethodChannel(e.dartExecutor.binaryMessenger, "parkplatz_merker/native")
                .setMethodCallHandler(BackgroundHandler(app) { finish() })

            e.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "backgroundMain"
                )
            )

            handler.postDelayed(timeout!!, 25_000L)
        } catch (e: Exception) {
            EventLog.info(ctx, "BackgroundRunner.run Fehler: ${e.message}")
            done()
        }
    }
}
