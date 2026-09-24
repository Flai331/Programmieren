package com.klaasotte.parkplatz_merker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity
import org.json.JSONObject

class TransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null || !ActivityTransitionResult.hasResult(intent)) return
        val result = ActivityTransitionResult.extractResult(intent) ?: return

        val events = result.transitionEvents.sortedBy { it.elapsedRealTimeNanos }

        for (e in events) {
            val t = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - e.elapsedRealTimeNanos) / 1_000_000

            val obj = JSONObject()
            obj.put("type", "activity")
            obj.put("t", t)
            obj.put("activity", Transitions.activityName(e.activityType))
            obj.put("transition", Transitions.transitionName(e.transitionType))
            obj.put("rx", System.currentTimeMillis())

            EventLog.append(context, obj)
        }

        // Verarbeite das letzte relevante Ereignis
        val lastEvent = events.lastOrNull() ?: return

        when {
            lastEvent.activityType == DetectedActivity.IN_VEHICLE &&
            lastEvent.transitionType == ActivityTransitionRequest.ACTIVITY_TRANSITION_ENTER -> {
                TripService.start(context, TripService.ACTION_ENTER)
            }
            lastEvent.activityType == DetectedActivity.IN_VEHICLE &&
            lastEvent.transitionType == ActivityTransitionRequest.ACTIVITY_TRANSITION_EXIT -> {
                TripService.start(context, TripService.ACTION_EXIT)
            }
            (lastEvent.activityType == DetectedActivity.WALKING || lastEvent.activityType == DetectedActivity.RUNNING) &&
            lastEvent.transitionType == ActivityTransitionRequest.ACTIVITY_TRANSITION_ENTER &&
            TripService.running -> {
                TripService.start(context, TripService.ACTION_WALKING)
            }
        }
    }
}
