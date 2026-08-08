package com.klaas.nfc_riegel

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager

/** Fragt [Manifest.permission.READ_CALENDAR] an — erst beim Einschalten der Funktion. */
object CalendarPermission {

    const val REQUEST_CODE = 1002

    fun granted(activity: Activity): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    fun request(activity: Activity) {
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CODE)
    }
}
