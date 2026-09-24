package com.klaasotte.parkplatz_merker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity
import org.json.JSONObject

/** Empfängt Aktivitätsübergänge (auch bei geschlossener App). */
class TransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null || !ActivityTransitionResult.hasResult(intent)) return
        val result = ActivityTransitionResult.extractResult(intent) ?: return

        val events = result.transitionEvents.sortedBy { it.elapsedRealTimeNanos }
        val now = System.currentTimeMillis()
        val nowElapsedNanos = SystemClock.elapsedRealtimeNanos()

        for (e in events) {
            // Ereigniszeit aus der Laufzeit seit dem Booten in Wanduhrzeit umrechnen.
            val t = now - (nowElapsedNanos - e.elapsedRealTimeNanos) / 1_000_000L
            val obj = JSONObject()
            obj.put("type", "activity")
            obj.put("t", t)
            obj.put("activity", Transitions.activityName(e.activityType))
            obj.put("transition", Transitions.transitionName(e.transitionType))
            obj.put("rx", now)
            EventLog.append(context, obj)
        }

        // Jedes relevante Ereignis in zeitlicher Reihenfolge an den Service geben
        // (nicht nur das letzte – sonst ginge z. B. IN_VEHICLE EXIT vor STILL ENTER verloren).
        for (e in events) {
            val enter = e.transitionType == ActivityTransitionRequest.ACTIVITY_TRANSITION_ENTER
            when (e.activityType) {
                DetectedActivity.IN_VEHICLE ->
                    TripService.start(context, if (enter) TripService.ACTION_ENTER else TripService.ACTION_EXIT)
                DetectedActivity.WALKING, DetectedActivity.RUNNING ->
                    if (enter && TripService.running) TripService.start(context, TripService.ACTION_WALKING)
            }
        }
    }
}
