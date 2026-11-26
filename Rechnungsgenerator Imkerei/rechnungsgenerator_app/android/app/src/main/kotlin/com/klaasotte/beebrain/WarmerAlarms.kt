package com.klaasotte.beebrain

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Die Wärmeschrank-Uhr meldet sich, wenn die Zeit um ist.
 *
 * Absichtlich eigenes Kotlin statt flutter_local_notifications: das Paket
 * verlangt *core library desugaring*, und dieses Projekt steht auf AGP 9.1.0,
 * wo file_picker ganz verloren ging. Diese Datei trägt dieses Risiko nicht —
 * sie braucht nichts, was nicht schon da ist (androidx.core liegt wegen des
 * FileProviders bereits bei).
 *
 * Geweckt wird ungenau: `setAndAllowWhileIdle` kommt auch im Doze durch,
 * braucht aber keines der eingeschränkten Alarm-Rechte
 * (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM), die Google rechtfertigen lässt.
 * Bei einer Uhr über 48 Stunden sind ein paar Minuten Verzug ohne Belang.
 *
 * Was ein Neustart des Handys löscht, sind die Weckzeiten — nicht die Uhren.
 * Die Wahrheit steht in der Datenbank, und die App meldet die offenen Uhren
 * beim Start neu an (siehe WarmerAlarms in Dart).
 */
object WarmerAlarms {
    /** Der Kanal zu Dart. */
    const val KANAL = "beebrain/warmer"

    /** Der Benachrichtigungskanal, den Android ab Oreo verlangt. */
    private const val MELDEKANAL = "waermeschrank"

    const val EXTRA_TITEL = "titel"
    const val EXTRA_TEXT = "text"
    const val EXTRA_EIMER = "eimer"

    /**
     * Eine Weckzeit setzen. Eine zweite für denselben Eimer ersetzt die erste,
     * weil der PendingIntent an derselben Kennung hängt.
     */
    fun schedule(
        context: Context,
        bucketId: String,
        dueAtMillis: Long,
        titel: String,
        text: String
    ): Boolean {
        val wecker = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        val absicht = pendingIntent(context, bucketId, titel, text) ?: return false

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                wecker.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAtMillis, absicht)
            } else {
                wecker.set(AlarmManager.RTC_WAKEUP, dueAtMillis, absicht)
            }
            true
        } catch (fehler: Exception) {
            false
        }
    }

    /** Die Weckzeit eines Eimers wieder abnehmen. */
    fun cancel(context: Context, bucketId: String) {
        val wecker = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        // FLAG_NO_CREATE: nur holen, was es schon gibt. Die Extras spielen
        // beim Zuordnen keine Rolle, Kennung und Absicht genügen.
        val vorhanden = PendingIntent.getBroadcast(
            context,
            kennung(bucketId),
            Intent(context, WarmerAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or flaggen()
        ) ?: return
        wecker?.cancel(vorhanden)
        vorhanden.cancel()
    }

    /** Darf die App überhaupt melden? */
    fun canNotify(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /**
     * Die Meldung selbst – gerufen aus dem Receiver, wenn die Zeit um ist.
     */
    fun notify(context: Context, bucketId: String, titel: String, text: String) {
        ensureChannel(context)

        val oeffnen = PendingIntent.getActivity(
            context,
            kennung(bucketId),
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or flaggen()
        )

        val meldung = NotificationCompat.Builder(context, MELDEKANAL)
            // Ein Systemsymbol: garantiert vorhanden, weiße Silhouette, und
            // die App muss dafür kein eigenes Bild mitbringen.
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(titel)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(oeffnen)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(kennung(bucketId), meldung)
        } catch (fehler: SecurityException) {
            // Ab Android 13 ohne erteilte Erlaubnis. Die Uhr läuft trotzdem,
            // sie meldet sich nur nicht.
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return
        if (manager.getNotificationChannel(MELDEKANAL) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                MELDEKANAL,
                "Wärmeschrank",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Meldet, wenn ein Eimer im Wärmeschrank fertig ist."
            }
        )
    }

    private fun pendingIntent(
        context: Context,
        bucketId: String,
        titel: String,
        text: String
    ): PendingIntent? = try {
        PendingIntent.getBroadcast(
            context,
            kennung(bucketId),
            Intent(context, WarmerAlarmReceiver::class.java).apply {
                putExtra(EXTRA_EIMER, bucketId)
                putExtra(EXTRA_TITEL, titel)
                putExtra(EXTRA_TEXT, text)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or flaggen()
        )
    } catch (fehler: Exception) {
        null
    }

    /**
     * Ab Android 12 muss ein PendingIntent sagen, ob er sich noch ändern
     * lässt. Unsere ändern sich nicht.
     */
    private fun flaggen(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0

    /**
     * Eine stabile Zahl je Eimer. Gerechnet wird sie immer hier, damit
     * Setzen und Abnehmen auf dieselbe kommen — Dart und Kotlin streuen ihre
     * Zeichenketten-Hashes unterschiedlich.
     */
    private fun kennung(bucketId: String): Int = bucketId.hashCode()
}

/**
 * Nimmt die Weckzeit an und macht daraus eine Meldung.
 *
 * Steht im Manifest, exportiert ist er nicht: wecken darf nur Android selbst.
 */
class WarmerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val eimer = intent.getStringExtra(WarmerAlarms.EXTRA_EIMER) ?: return
        val titel = intent.getStringExtra(WarmerAlarms.EXTRA_TITEL)
            ?: "Wärmeschrank"
        val text = intent.getStringExtra(WarmerAlarms.EXTRA_TEXT)
            ?: "Ein Eimer ist fertig."
        WarmerAlarms.notify(context, eimer, titel, text)
    }
}
