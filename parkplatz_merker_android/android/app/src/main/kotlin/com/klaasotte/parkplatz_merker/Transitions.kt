package com.klaasotte.parkplatz_merker

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity

@SuppressLint("MissingPermission")
object Transitions {
    fun register(ctx: Context, callback: ((Boolean, String?) -> Unit)? = null) {
        if (!Config.activityEnabled) {
            unregister(ctx)
            Config.transitionsError = "Aktivitätserkennung ausgeschaltet"
            callback?.invoke(false, "Aktivitätserkennung ausgeschaltet")
            return
        }

        // Unter Android 10 gibt es die Laufzeit-Berechtigung nicht (Manifest reicht).
        val granted = Build.VERSION.SDK_INT < 29 ||
            ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.ACTIVITY_RECOGNITION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        if (!granted) {
            val error = "Berechtigung Aktivitätserkennung fehlt"
            Config.transitionsError = error
            Config.transitionsRegistered = false
            EventLog.info(ctx, error)
            callback?.invoke(false, error)
            return
        }

        try {
            val request = ActivityTransitionRequest(
                listOf(
                    ActivityTransition.Builder()
                        .setActivityType(DetectedActivity.IN_VEHICLE)
                        .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                        .build(),
                    ActivityTransition.Builder()
                        .setActivityType(DetectedActivity.IN_VEHICLE)
                        .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                        .build(),
                    ActivityTransition.Builder()
                        .setActivityType(DetectedActivity.WALKING)
                        .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                        .build(),
                    ActivityTransition.Builder()
                        .setActivityType(DetectedActivity.RUNNING)
                        .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                        .build(),
                    ActivityTransition.Builder()
                        .setActivityType(DetectedActivity.STILL)
                        .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                        .build(),
                )
            )

            val pi = pendingIntent(ctx)
            ActivityRecognition.getClient(ctx)
                .requestActivityTransitionUpdates(request, pi)
                .addOnSuccessListener {
                    Config.transitionsRegistered = true
                    Config.transitionsError = null
                    Config.transitionsAt = System.currentTimeMillis()
                    EventLog.info(ctx, "Aktivitätstransitionen registriert")
                    callback?.invoke(true, null)
                }
                .addOnFailureListener { e ->
                    Config.transitionsRegistered = false
                    Config.transitionsError = e.message ?: "Fehler"
                    EventLog.info(ctx, "Aktivitätstransitionen Fehler: ${e.message}")
                    callback?.invoke(false, e.message)
                }
        } catch (e: Exception) {
            val error = if (e is SecurityException) "Berechtigung Aktivitätserkennung fehlt" else "Registrierung fehlgeschlagen: ${e.message}"
            Config.transitionsError = error
            Config.transitionsRegistered = false
            EventLog.info(ctx, error)
            callback?.invoke(false, error)
        }
    }

    fun unregister(ctx: Context) {
        try {
            val pi = pendingIntent(ctx)
            ActivityRecognition.getClient(ctx)
                .removeActivityTransitionUpdates(pi)
                .addOnSuccessListener {
                    Config.transitionsRegistered = false
                }
                .addOnFailureListener {
                    Config.transitionsRegistered = false
                }
        } catch (e: Exception) {
            Config.transitionsRegistered = false
        }
    }

    fun pendingIntent(ctx: Context): PendingIntent {
        val flags = if (Build.VERSION.SDK_INT >= 31) {
            (PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(
            ctx,
            1,
            Intent(ctx, TransitionReceiver::class.java),
            flags
        )
    }

    fun activityName(activity: Int): String = when (activity) {
        DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
        DetectedActivity.WALKING -> "WALKING"
        DetectedActivity.RUNNING -> "RUNNING"
        DetectedActivity.STILL -> "STILL"
        DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
        DetectedActivity.UNKNOWN -> "UNKNOWN"
        else -> "UNKNOWN($activity)"
    }

    fun transitionName(transition: Int): String = when (transition) {
        ActivityTransition.ACTIVITY_TRANSITION_ENTER -> "ENTER"
        ActivityTransition.ACTIVITY_TRANSITION_EXIT -> "EXIT"
        else -> "UNKNOWN($transition)"
    }
}
