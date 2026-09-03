package com.klaas.nfc_riegel

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Die Anruffilter-Rolle des Systems. Nur wer sie hält, wird von Android bei
 * jedem eingehenden Anruf gefragt — und nur dann lassen sich einzelne Nummern
 * stumm schalten.
 *
 * Erst ab Android 10 vergibt das System die Rolle an gewöhnliche Apps. Darunter
 * bleibt [QuietDnd] der einzige Weg.
 */
object CallScreening {

    const val REQUEST_CODE = 1004

    fun available(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rollen = context.getSystemService(RoleManager::class.java) ?: return false
        return rollen.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
    }

    fun held(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rollen = context.getSystemService(RoleManager::class.java) ?: return false
        return rollen.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    /**
     * Öffnet den Systemdialog. Die Rolle lässt sich nicht still übernehmen —
     * der Nutzer muss zustimmen, und er kann sie jederzeit wieder abgeben.
     */
    fun request(activity: Activity): Boolean {
        if (!available(activity)) return false
        val rollen = activity.getSystemService(RoleManager::class.java) ?: return false
        val absicht: Intent = rollen.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
        activity.startActivityForResult(absicht, REQUEST_CODE)
        return true
    }
}
