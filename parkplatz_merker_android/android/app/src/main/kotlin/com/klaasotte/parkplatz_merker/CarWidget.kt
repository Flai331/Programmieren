package com.klaasotte.parkplatz_merker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.Locale

object CarWidget {
    private const val PREFS_NAME = "car_widget"
    private const val KEY_SPOT = "spot"
    private const val KEY_MAP = "map_key"

    /** Speichert Parkplatz-Daten oder entfernt sie; ruft dann updateAll auf. */
    fun save(ctx: Context, args: Any?) {
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (args is Map<*, *>) {
            // Konvertiere Map in JSON
            val json = JSONObject()
            for ((k, v) in args) {
                val key = k.toString()
                when (v) {
                    is Number -> {
                        if (key == "time" || key == "t") {
                            json.put(key, v.toLong())
                        } else {
                            json.put(key, v.toDouble())
                        }
                    }
                    is String -> json.put(key, v)
                    is Boolean -> json.put(key, v)
                    null -> json.put(key, JSONObject.NULL)
                }
            }
            prefs.edit().putString(KEY_SPOT, json.toString()).apply()
        } else {
            prefs.edit().remove(KEY_SPOT).apply()
        }
        updateAll(ctx)
    }

    /** Aktualisiert alle Widget-Instanzen. */
    fun updateAll(ctx: Context) {
        val am = AppWidgetManager.getInstance(ctx)
        val ids = am.getAppWidgetIds(
            ComponentName(ctx, CarWidgetProvider::class.java)
        )
        for (id in ids) {
            val views = build(ctx)
            am.updateAppWidget(id, views)
        }

        // Lade Map asynchron nach
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val spotJson = prefs.getString(KEY_SPOT, null) ?: return
        try {
            val obj = JSONObject(spotJson)
            val lat = (obj.opt("lat") as? Number)?.toDouble()
            val lng = (obj.opt("lng") as? Number)?.toDouble()
            if (lat == null || lng == null) return

            val mapKey = String.format(Locale.US, "%.5f,%.5f", lat, lng)
            val savedKey = prefs.getString(KEY_MAP, null)
            val mapFile = File(ctx.filesDir, "widget_map.png")

            // Prüfe, ob die gecachte Map noch passt
            if (savedKey == mapKey && mapFile.exists()) {
                return // Map ist aktuell
            }

            // Sonst: zeichne neue Map im Hintergrund
            Thread {
                val bitmap = MapSnapshot.render(lat, lng)
                if (bitmap != null) {
                    try {
                        mapFile.outputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, out) }
                        prefs.edit().putString(KEY_MAP, mapKey).apply()
                        // Aktualisiere UI mit neuer Map
                        val am2 = AppWidgetManager.getInstance(ctx)
                        val ids2 = am2.getAppWidgetIds(
                            ComponentName(ctx, CarWidgetProvider::class.java)
                        )
                        for (id in ids2) {
                            val views = build(ctx)
                            am2.updateAppWidget(id, views)
                        }
                    } catch (e: Exception) {
                        EventLog.info(ctx, "CarWidget Map speichern fehlgeschlagen: ${e.message}")
                    }
                }
            }.start()
        } catch (e: Exception) {
            EventLog.info(ctx, "CarWidget updateAll Fehler: ${e.message}")
        }
    }

    /** Baut RemoteViews für das Widget. */
    fun build(ctx: Context): RemoteViews {
        val views = RemoteViews(ctx.packageName, R.layout.car_widget)
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val spotJson = prefs.getString(KEY_SPOT, null)

        if (spotJson == null) {
            // Kein Parkplatz
            views.setTextViewText(R.id.widget_title, "Noch kein Parkplatz gemerkt")
            views.setViewVisibility(R.id.widget_since, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_address, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_note, android.view.View.GONE)
            views.setViewVisibility(R.id.btn_nav, android.view.View.GONE)

            // Klick: App öffnen
            val click = PendingIntent.getActivity(
                ctx, 10, Intent(ctx, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_body, click)
            views.setOnClickPendingIntent(R.id.widget_map_box, click)
        } else {
            // Parkplatz vorhanden
            try {
                val obj = JSONObject(spotJson)
                val time = (obj.opt("time") as? Number)?.toLong() ?: 0L
                val lat = (obj.opt("lat") as? Number)?.toDouble()
                val lng = (obj.opt("lng") as? Number)?.toDouble()
                val address = text(obj, "address")
                val note = text(obj, "note")

                views.setTextViewText(R.id.widget_title, "Dein Auto steht")
                views.setTextViewText(R.id.widget_since, sinceText(time))

                if (lat != null && lng != null) {
                    views.setTextViewText(
                        R.id.widget_address,
                        address ?: String.format(Locale.US, "%.5f, %.5f", lat, lng)
                    )
                } else {
                    views.setTextViewText(R.id.widget_address, "")
                }

                if (note != null) {
                    views.setTextViewText(R.id.widget_note, note)
                    views.setViewVisibility(R.id.widget_note, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_note, android.view.View.GONE)
                }

                // Karte nur zeigen, wenn sie zu DIESER Position gehört – sonst Platzhalter.
                views.setImageViewResource(R.id.widget_map, R.drawable.ic_car)
                val mapFile = File(ctx.filesDir, "widget_map.png")
                val currentKey = if (lat != null && lng != null) String.format(Locale.US, "%.5f,%.5f", lat, lng) else null
                if (currentKey != null && prefs.getString(KEY_MAP, null) == currentKey && mapFile.exists()) {
                    try {
                        val bitmap = BitmapFactory.decodeFile(mapFile.path)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_map, bitmap)
                        }
                    } catch (e: Exception) {
                        // ignorieren
                    }
                }

                // Klicks
                val click = PendingIntent.getActivity(
                    ctx, 10, Intent(ctx, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_body, click)
                views.setOnClickPendingIntent(R.id.widget_map_box, click)

                // Navigation
                if (lat != null && lng != null) {
                    val ll = String.format(Locale.US, "%.7f,%.7f", lat, lng)
                    val navIntent = try {
                        Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=$ll&mode=w"))
                            .setPackage("com.google.android.apps.maps")
                    } catch (e: Exception) {
                        null
                    }

                    val navPending = if (navIntent != null && canLaunch(ctx, navIntent)) {
                        PendingIntent.getActivity(
                            ctx, 11, navIntent,
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        )
                    } else {
                        val geoIntent = Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("geo:$ll?q=${Uri.encode("$ll(Mein Auto)")}")
                        )
                        PendingIntent.getActivity(
                            ctx, 11, geoIntent,
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        )
                    }
                    views.setOnClickPendingIntent(R.id.btn_nav, navPending)
                    views.setViewVisibility(R.id.btn_nav, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.btn_nav, android.view.View.GONE)
                }

            } catch (e: Exception) {
                EventLog.info(ctx, "CarWidget build Fehler: ${e.message}")
                views.setTextViewText(R.id.widget_title, "Fehler")
            }
        }

        // „Hier geparkt“ – auch ohne gespeicherten Parkplatz
        val parkIntent = Intent(ctx, ParkHereActivity::class.java)
            .putExtra("source", "widget")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val parkPending = PendingIntent.getActivity(
            ctx, 12, parkIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.btn_park, parkPending)
        return views
    }

    /** Text aus JSON; fehlend, JSON-null oder leer → null. */
    private fun text(obj: JSONObject, key: String): String? {
        if (!obj.has(key) || obj.isNull(key)) return null
        return obj.optString(key).takeIf { it.isNotBlank() }
    }

    /** Formatiert die Zeit wie Dart: "seit 14:32", "seit gestern, 14:32", etc. */
    fun sinceText(time: Long): String {
        val parked = Calendar.getInstance().apply { timeInMillis = time }
        val today = Calendar.getInstance()
        val yesterday = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }
        fun sameDay(a: Calendar, b: Calendar) =
            a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
        val clock = String.format(Locale.GERMANY, "%02d:%02d", parked.get(Calendar.HOUR_OF_DAY), parked.get(Calendar.MINUTE))
        return when {
            sameDay(parked, today) -> "seit $clock"
            sameDay(parked, yesterday) -> "seit gestern, $clock"
            else -> {
                // Calendar.DAY_OF_WEEK: Sonntag = 1 … Samstag = 7
                val days = listOf("So.", "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.")
                val day = days[parked.get(Calendar.DAY_OF_WEEK) - 1]
                val date = String.format(Locale.GERMANY, "%02d.%02d.", parked.get(Calendar.DAY_OF_MONTH), parked.get(Calendar.MONTH) + 1)
                "seit $day, $date, $clock"
            }
        }
    }

    private fun canLaunch(ctx: Context, intent: Intent): Boolean {
        return ctx.packageManager.resolveActivity(intent, 0) != null
    }
}

class CarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        CarWidget.updateAll(context)
    }
}
