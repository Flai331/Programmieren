package com.klaas.nfc_riegel

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Einzige Schnittstelle zwischen Flutter und der nativen Sperrmechanik. */
class RiegelChannel(private val activity: Activity) {

    private val controller = LockController(activity)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> result.success(stateMap())

                "setBlockedPackages" -> {
                    val packages = call.argument<List<String>>("packages")?.toSet() ?: emptySet()
                    result.success(controller.engine.setBlockedPackages(packages))
                }

                "setMode" -> {
                    val mode = if (call.argument<String>("mode") == "OPEN") LockMode.OPEN else LockMode.TIMER
                    val minutes = call.argument<Int>("durationMinutes") ?: 60
                    result.success(controller.engine.setMode(mode, minutes))
                }

                "generateCode" -> result.success(controller.engine.generateCode())

                "startTagEnrollment" -> {
                    activity.startActivity(Intent(activity, TagWriteActivity::class.java))
                    result.success(true)
                }

                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

                "openAccessibilitySettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "isAdminActive" -> result.success(devicePolicyManager().isAdminActive(adminComponent()))

                "requestAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
                        .putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Verhindert, dass der Riegel während einer Sperre deinstalliert wird.",
                        )
                    activity.startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun stateMap(): Map<String, Any?> {
        val s = controller.engine.state()
        return mapOf(
            "locked" to s.locked,
            "mode" to s.mode.name,
            "endsAt" to s.endsAt,
            "durationMinutes" to s.durationMinutes,
            "blockedPackages" to s.blockedPackages.toList(),
            "hasTag" to (s.tagUid != null),
            "hasCode" to (s.codeHash != null),
        )
    }

    private fun devicePolicyManager() =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun adminComponent() = ComponentName(activity, UninstallAdmin::class.java)

    private fun isAccessibilityEnabled(): Boolean {
        val service = ComponentName(activity, BlockerService::class.java)
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: ""
        return enabled.split(':').any {
            it.equals(service.flattenToString(), ignoreCase = true) ||
                it.equals(service.flattenToShortString(), ignoreCase = true)
        }
    }

    companion object {
        const val CHANNEL = "com.klaas.nfc_riegel/riegel"
    }
}
