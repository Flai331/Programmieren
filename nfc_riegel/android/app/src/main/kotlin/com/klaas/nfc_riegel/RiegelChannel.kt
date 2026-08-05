package com.klaas.nfc_riegel

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
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

                "addProfile" -> {
                    val name = call.argument<String>("name") ?: "Neues Profil"
                    result.success(controller.engine.addProfile(name).id)
                }

                "updateProfile" -> {
                    val profile = Profile(
                        id = call.argument<String>("id") ?: "",
                        name = call.argument<String>("name") ?: "",
                        blockedPackages = call.argument<List<String>>("blockedPackages")
                            ?.toSet() ?: emptySet(),
                        defaultMode = runCatching {
                            LockMode.valueOf(call.argument<String>("defaultMode") ?: "TIMER")
                        }.getOrDefault(LockMode.TIMER),
                        durationMinutes = call.argument<Int>("durationMinutes") ?: 60,
                        untilAt = call.argument<Long>("untilAt"),
                        pinCalendarEnd = call.argument<Boolean>("pinCalendarEnd") ?: false,
                    )
                    result.success(controller.engine.updateProfile(profile))
                }

                "deleteProfile" ->
                    result.success(controller.engine.deleteProfile(call.argument<String>("id") ?: ""))

                "deleteTag" ->
                    result.success(controller.engine.deleteTag(call.argument<String>("uid") ?: ""))

                "generateCode" -> result.success(controller.engine.generateCode())

                "startTagEnrollment" -> {
                    val intent = Intent(activity, TagWriteActivity::class.java)
                        .putExtra(TagWriteActivity.EXTRA_LABEL, call.argument<String>("label"))
                        .putExtra(TagWriteActivity.EXTRA_PROFILE_ID, call.argument<String>("profileId"))
                        .putExtra(TagWriteActivity.EXTRA_IS_MASTER, call.argument<Boolean>("isMaster") ?: false)
                    activity.startActivity(intent)
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

                "getDiagnostics" -> {
                    val map = Diagnostics.summarize(
                        controller.engine.state(),
                        System.currentTimeMillis(),
                    ).toMutableMap()
                    map["Bedienungshilfe"] = if (isAccessibilityEnabled()) "an" else "AUS"
                    map["Geräteadministrator"] =
                        if (devicePolicyManager().isAdminActive(adminComponent())) "an" else "aus"
                    map["Benachrichtigungen"] = notificationPermissionState()
                    map["Android"] = "SDK ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})"
                    result.success(map)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun stateMap(): Map<String, Any?> {
        val s = controller.engine.state()
        val lock = s.chipLock
        return mapOf(
            "profiles" to s.profiles.map { p ->
                mapOf(
                    "id" to p.id,
                    "name" to p.name,
                    "blockedPackages" to p.blockedPackages.toList(),
                    "defaultMode" to p.defaultMode.name,
                    "durationMinutes" to p.durationMinutes,
                    "untilAt" to p.untilAt,
                    "pinCalendarEnd" to p.pinCalendarEnd,
                )
            },
            "tags" to s.tags.map { t ->
                mapOf(
                    "uid" to t.uid,
                    "label" to t.label,
                    "profileId" to t.profileId,
                    "isMaster" to t.isMaster,
                )
            },
            "activeLock" to lock?.let {
                mapOf(
                    "profileId" to it.profileId,
                    "mode" to it.mode.name,
                    "endsAt" to it.endsAt,
                )
            },
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

    /**
     * Seit Android 13 ist POST_NOTIFICATIONS eine Laufzeit-Berechtigung. Fehlt sie,
     * verschwindet die Sperr-Benachrichtigung lautlos — im Bericht muss das stehen.
     */
    private fun notificationPermissionState(): String =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            "nicht nötig"
        } else if (
            activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            "erlaubt"
        } else {
            "VERWEIGERT"
        }

    companion object {
        const val CHANNEL = "com.klaas.nfc_riegel/riegel"
    }
}
