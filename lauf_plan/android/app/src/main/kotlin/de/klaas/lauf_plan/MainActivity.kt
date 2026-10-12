package de.klaas.lauf_plan

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone

// Kalender-Anbindung fuer lib/device_calendar.dart:
// - insertIntent: Kalender-App mit vorausgefuelltem Termin oeffnen (ohne Berechtigung)
// - calendars / writeEvents / deleteEvents: direkt in einen Kalender schreiben
//   (braucht READ_/WRITE_CALENDAR, die Berechtigungen ergaenzt der Workflow im Manifest)
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lauf_plan/calendar")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "insertIntent" -> result.success(insertIntent(call.arguments as Map<*, *>))
                        "hasPermission" -> result.success(hasPermission())
                        "requestPermission" -> requestPermission(result)
                        "calendars" -> result.success(calendars())
                        "writeEvents" -> result.success(
                            writeEvents(
                                (call.argument<Number>("calendarId") ?: 0).toLong(),
                                call.argument<List<Map<*, *>>>("events") ?: emptyList()
                            )
                        )
                        "deleteEvents" -> result.success(
                            deleteEvents(call.argument<List<Number>>("ids") ?: emptyList())
                        )
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("calendar", e.message, null)
                }
            }
    }

    // Beginn/Ende in Millisekunden. Ganztaegig: im Kalender-Speicher UTC-Mitternacht
    // (Vorgabe von CalendarContract), im Intent lokale Mitternacht.
    private fun times(e: Map<*, *>, utcAllDay: Boolean): Pair<Long, Long> {
        val allDay = e["allDay"] == true
        val tz = if (allDay && utcAllDay) TimeZone.getTimeZone("UTC") else TimeZone.getDefault()
        val c = Calendar.getInstance(tz)
        c.clear()
        c.set(
            (e["year"] as Number).toInt(),
            (e["month"] as Number).toInt() - 1,
            (e["day"] as Number).toInt(),
            0, 0, 0
        )
        if (!allDay) c.add(Calendar.MINUTE, (e["start"] as Number).toInt())
        val begin = c.timeInMillis
        if (allDay) {
            c.add(Calendar.DAY_OF_MONTH, 1)
        } else {
            c.add(Calendar.MINUTE, (e["minutes"] as Number).toInt())
        }
        return Pair(begin, c.timeInMillis)
    }

    private fun insertIntent(e: Map<*, *>): Boolean {
        val (begin, end) = times(e, false)
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, begin)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
            .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, e["allDay"] == true)
            .putExtra(CalendarContract.Events.TITLE, e["title"] as? String ?: "")
            .putExtra(CalendarContract.Events.DESCRIPTION, e["description"] as? String ?: "")
        return try {
            startActivity(intent)
            true
        } catch (ex: ActivityNotFoundException) {
            false
        }
    }

    private fun hasPermission(): Boolean =
        checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            REQUEST_CALENDAR
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CALENDAR) {
            pendingPermission?.success(hasPermission())
            pendingPermission = null
        }
    }

    private fun calendars(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.IS_PRIMARY
        )
        val selection = "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= " +
            "${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR} AND " +
            "${CalendarContract.Calendars.VISIBLE} = 1"
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projection, selection, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "name" to (c.getString(1) ?: ""),
                        "account" to (c.getString(2) ?: ""),
                        "primary" to (c.getInt(3) == 1)
                    )
                )
            }
        }
        return out
    }

    // Legt Termine an oder aktualisiert sie (wenn "id" gesetzt und noch vorhanden).
    // Rueckgabe: die Termin-IDs in derselben Reihenfolge.
    private fun writeEvents(calendarId: Long, events: List<Map<*, *>>): List<Long> {
        val ids = mutableListOf<Long>()
        for (e in events) {
            val allDay = e["allDay"] == true
            val (begin, end) = times(e, true)
            val alarm = (e["alarm"] as? Number)?.toInt() ?: 0
            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, e["title"] as? String ?: "")
                put(CalendarContract.Events.DESCRIPTION, e["description"] as? String ?: "")
                put(CalendarContract.Events.DTSTART, begin)
                put(CalendarContract.Events.DTEND, end)
                put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
                put(
                    CalendarContract.Events.EVENT_TIMEZONE,
                    if (allDay) "UTC" else TimeZone.getDefault().id
                )
                put(CalendarContract.Events.HAS_ALARM, if (!allDay && alarm > 0) 1 else 0)
            }
            val oldId = (e["id"] as? Number)?.toLong()
            if (oldId != null) {
                val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, oldId)
                if (contentResolver.update(uri, values, null, null) > 0) {
                    ids.add(oldId)
                    continue
                }
            }
            val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
                ?: throw IllegalStateException("Termin konnte nicht angelegt werden")
            val newId = ContentUris.parseId(uri)
            if (!allDay && alarm > 0) {
                val r = ContentValues().apply {
                    put(CalendarContract.Reminders.EVENT_ID, newId)
                    put(CalendarContract.Reminders.MINUTES, alarm)
                    put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
                }
                contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, r)
            }
            ids.add(newId)
        }
        return ids
    }

    private fun deleteEvents(ids: List<Number>): Int {
        var n = 0
        for (id in ids) {
            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id.toLong())
            n += contentResolver.delete(uri, null, null)
        }
        return n
    }

    companion object {
        private const val REQUEST_CALENDAR = 4711
    }
}
