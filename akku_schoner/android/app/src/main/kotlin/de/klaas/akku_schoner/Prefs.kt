package de.klaas.akku_schoner

import android.content.Context
import android.content.SharedPreferences

/** Einstellungen, die auch der Wächter-Dienst ohne Flutter lesen muss. */
object Prefs {
    private fun p(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences("akku", Context.MODE_PRIVATE)

    fun watcherEnabled(ctx: Context) = p(ctx).getBoolean("watcherEnabled", false)
    fun upperLimit(ctx: Context) = p(ctx).getInt("upperLimit", 80)
    fun lowerLimit(ctx: Context) = p(ctx).getInt("lowerLimit", 20)
    fun maxTemp(ctx: Context) = p(ctx).getInt("maxTemp", 40)

    fun getWatcher(ctx: Context): Map<String, Any> = mapOf(
        "enabled" to watcherEnabled(ctx),
        "upper" to upperLimit(ctx),
        "lower" to lowerLimit(ctx),
        "maxTemp" to maxTemp(ctx),
    )

    fun setWatcher(ctx: Context, map: Map<*, *>) {
        val e = p(ctx).edit()
        (map["enabled"] as? Boolean)?.let { e.putBoolean("watcherEnabled", it) }
        (map["upper"] as? Number)?.let { e.putInt("upperLimit", it.toInt().coerceIn(50, 100)) }
        (map["lower"] as? Number)?.let { e.putInt("lowerLimit", it.toInt().coerceIn(5, 50)) }
        (map["maxTemp"] as? Number)?.let { e.putInt("maxTemp", it.toInt().coerceIn(30, 55)) }
        e.apply()
    }

    /** Paketnamen, die nie beendet werden sollen. null = noch nie gespeichert. */
    fun important(ctx: Context): List<String>? =
        p(ctx).getString("important", null)?.split("\n")?.filter { it.isNotBlank() }

    fun setImportant(ctx: Context, list: List<String>) {
        p(ctx).edit().putString("important", list.joinToString("\n")).apply()
    }
}
