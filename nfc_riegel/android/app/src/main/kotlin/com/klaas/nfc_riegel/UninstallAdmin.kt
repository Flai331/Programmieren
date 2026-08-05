package com.klaas.nfc_riegel

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class UninstallAdmin : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        val engine = LockEngine(SharedPrefsLockStore(context))
        return if (engine.hasActiveLock(System.currentTimeMillis())) {
            "Der Riegel sperrt gerade. Deaktivieren hebt den Deinstallationsschutz auf."
        } else {
            "Deinstallationsschutz wird aufgehoben."
        }
    }
}
