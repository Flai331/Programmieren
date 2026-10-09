package de.klaas.akku_schoner

import android.content.Context
import android.content.SharedPreferences

/** Einstellungen, die auch der Hintergrund-Dienst ohne Flutter lesen muss. */
object Prefs {
    private fun p(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences("akku", Context.MODE_PRIVATE)

    fun watcherEnabled(ctx: Context) = p(ctx).getBoolean("watcherEnabled", false)
    fun upperLimit(ctx: Context) = p(ctx).getInt("upperLimit", 80)
    fun lowerLimit(ctx: Context) = p(ctx).getInt("lowerLimit", 20)
    fun maxTemp(ctx: Context) = p(ctx).getInt("maxTemp", 40)

    /** Beim Bildschirm-Aus Apps der Stufen "sanft" und "komplett" sanft beenden. */
    fun autoSoft(ctx: Context) = p(ctx).getBoolean("autoSoft", false)
    /** Beim Entsperren nach längerer Pause Apps der Stufe "komplett" erzwungen beenden. */
    fun autoFull(ctx: Context) = p(ctx).getBoolean("autoFull", false)
    fun unlockAfterMin(ctx: Context) = p(ctx).getInt("unlockAfterMin", 30)

    /** Der Dienst läuft, sobald Wächter oder Automatik an ist. */
    fun serviceNeeded(ctx: Context) = watcherEnabled(ctx) || autoSoft(ctx) || autoFull(ctx)

    fun getWatcher(ctx: Context): Map<String, Any> = mapOf(
        "enabled" to watcherEnabled(ctx),
        "upper" to upperLimit(ctx),
        "lower" to lowerLimit(ctx),
        "maxTemp" to maxTemp(ctx),
        "autoSoft" to autoSoft(ctx),
        "autoFull" to autoFull(ctx),
        "unlockAfterMin" to unlockAfterMin(ctx),
    )

    fun setWatcher(ctx: Context, map: Map<*, *>) {
        val e = p(ctx).edit()
        (map["enabled"] as? Boolean)?.let { e.putBoolean("watcherEnabled", it) }
        (map["upper"] as? Number)?.let { e.putInt("upperLimit", it.toInt().coerceIn(50, 100)) }
        (map["lower"] as? Number)?.let { e.putInt("lowerLimit", it.toInt().coerceIn(5, 50)) }
        (map["maxTemp"] as? Number)?.let { e.putInt("maxTemp", it.toInt().coerceIn(30, 55)) }
        (map["autoSoft"] as? Boolean)?.let { e.putBoolean("autoSoft", it) }
        (map["autoFull"] as? Boolean)?.let { e.putBoolean("autoFull", it) }
        (map["unlockAfterMin"] as? Number)?.let { e.putInt("unlockAfterMin", it.toInt().coerceIn(5, 240)) }
        e.apply()
    }

    /** Von Hand gesetzte Stufen: Paketname -> keep/soft/full. */
    fun overrides(ctx: Context): Map<String, String> =
        (p(ctx).getString("overrides", "") ?: "").split("\n")
            .mapNotNull { line ->
                val i = line.indexOf('=')
                if (i <= 0) null else line.substring(0, i) to line.substring(i + 1)
            }
            .filter { it.second in Policy.LEVELS }
            .toMap()

    /** level == null -> wieder automatisch. */
    fun setOverride(ctx: Context, pkg: String, level: String?) {
        val m = overrides(ctx).toMutableMap()
        if (level == null || level !in Policy.LEVELS) m.remove(pkg) else m[pkg] = level
        p(ctx).edit().putString("overrides", m.entries.joinToString("\n") { "${it.key}=${it.value}" }).apply()
    }
}
