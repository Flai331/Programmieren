package com.klaasotte.parkplatz_merker

import android.content.Context

object Config {
    private const val PREFS_NAME = "parkplatz_config"
    private lateinit var applicationContext: Context

    fun init(ctx: Context) {
        applicationContext = ctx.applicationContext
    }

    private fun prefs(): android.content.SharedPreferences =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // Getter/Setter für Konfiguration
    var activityEnabled: Boolean
        get() = prefs().getBoolean("activityEnabled", true)
        set(value) = prefs().edit().putBoolean("activityEnabled", value).apply()

    var chargerEnabled: Boolean
        get() = prefs().getBoolean("chargerEnabled", true)
        set(value) = prefs().edit().putBoolean("chargerEnabled", value).apply()

    var deviceMode: String
        get() = prefs().getString("deviceMode", "none") ?: "none"
        set(value) = prefs().edit().putString("deviceMode", value).apply()

    var deviceAddress: String?
        get() = prefs().getString("deviceAddress", null)
        set(value) = prefs().edit().putString("deviceAddress", value).apply()

    var deviceName: String?
        get() = prefs().getString("deviceName", null)
        set(value) = prefs().edit().putString("deviceName", value).apply()

    var transitionsRegistered: Boolean
        get() = prefs().getBoolean("transitionsRegistered", false)
        set(value) = prefs().edit().putBoolean("transitionsRegistered", value).apply()

    var transitionsError: String?
        get() = prefs().getString("transitionsError", null)
        set(value) = prefs().edit().putString("transitionsError", value).apply()

    var transitionsAt: Long
        get() = prefs().getLong("transitionsAt", 0L)
        set(value) = prefs().edit().putLong("transitionsAt", value).apply()

    var reminderAt: Long
        get() = prefs().getLong("reminderAt", 0L)
        set(value) = prefs().edit().putLong("reminderAt", value).apply()

    var reminderText: String
        get() = prefs().getString("reminderText", "") ?: ""
        set(value) = prefs().edit().putString("reminderText", value).apply()

    var lastBeaconBgLog: Long
        get() = prefs().getLong("lastBeaconBgLog", 0L)
        set(value) = prefs().edit().putLong("lastBeaconBgLog", value).apply()

    var launchPackage: String
        get() = prefs().getString("launchPackage", "") ?: ""
        set(value) = prefs().edit().putString("launchPackage", value).apply()

    var launchLabel: String
        get() = prefs().getString("launchLabel", "") ?: ""
        set(value) = prefs().edit().putString("launchLabel", value).apply()

    var closeOnGone: Boolean
        get() = prefs().getBoolean("closeOnGone", true)
        set(value) = prefs().edit().putBoolean("closeOnGone", value).apply()

    var devicePresent: Boolean
        get() = prefs().getBoolean("devicePresent", false)
        set(value) = prefs().edit().putBoolean("devicePresent", value).apply()

    var devicePresentAt: Long
        get() = prefs().getLong("devicePresentAt", 0L)
        set(value) = prefs().edit().putLong("devicePresentAt", value).apply()

    var closeActionTitle: String
        get() = prefs().getString("closeActionTitle", "") ?: ""
        set(value) = prefs().edit().putString("closeActionTitle", value).apply()

    var closeActionIndex: Int
        get() = prefs().getInt("closeActionIndex", -1)
        set(value) = prefs().edit().putInt("closeActionIndex", value).apply()

    var forceStopFallback: Boolean
        get() = prefs().getBoolean("forceStopFallback", false)
        set(value) = prefs().edit().putBoolean("forceStopFallback", value).apply()

    fun getConfig(): Map<String, Any?> {
        return mapOf(
            "activityEnabled" to activityEnabled,
            "chargerEnabled" to chargerEnabled,
            "deviceMode" to deviceMode,
            "deviceAddress" to deviceAddress,
            "deviceName" to deviceName,
            "launchPackage" to launchPackage,
            "launchLabel" to launchLabel,
            "closeOnGone" to closeOnGone,
            "closeActionTitle" to closeActionTitle,
            "closeActionIndex" to closeActionIndex,
            "forceStopFallback" to forceStopFallback
        )
    }

    fun setConfig(config: Map<String, Any?>) {
        config["activityEnabled"]?.let { (it as? Boolean)?.let { v -> activityEnabled = v } }
        config["chargerEnabled"]?.let { (it as? Boolean)?.let { v -> chargerEnabled = v } }
        config["deviceMode"]?.let { (it as? String)?.let { v -> deviceMode = v } }
        config["deviceAddress"]?.let { (it as? String)?.let { v -> deviceAddress = v } }
        config["deviceName"]?.let { (it as? String)?.let { v -> deviceName = v } }
        config["launchPackage"]?.let { (it as? String)?.let { v -> launchPackage = v } }
        config["launchLabel"]?.let { (it as? String)?.let { v -> launchLabel = v } }
        config["closeOnGone"]?.let { (it as? Boolean)?.let { v -> closeOnGone = v } }
        config["closeActionTitle"]?.let { (it as? String)?.let { v -> closeActionTitle = v } }
        config["closeActionIndex"]?.let { (it as? Number)?.toInt()?.let { v -> closeActionIndex = v } }
        config["forceStopFallback"]?.let { (it as? Boolean)?.let { v -> forceStopFallback = v } }
    }
}
