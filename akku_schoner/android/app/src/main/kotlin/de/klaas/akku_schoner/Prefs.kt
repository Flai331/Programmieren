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

    // ---------- Sparprofil ----------

    fun profileIds(ctx: Context): List<String> =
        p(ctx).getString("profileIds", null)?.split(",")?.filter { it in SaverProfile.ALL }
            ?: SaverProfile.DEFAULT

    fun profileAuto(ctx: Context) = p(ctx).getBoolean("profileAuto", false)
    fun profileAutoLevel(ctx: Context) = p(ctx).getInt("profileAutoLevel", 30)
    fun profileAutoDone(ctx: Context) = p(ctx).getBoolean("profileAutoDone", false)
    fun setProfileAutoDone(ctx: Context, v: Boolean) = p(ctx).edit().putBoolean("profileAutoDone", v).apply()

    fun getProfile(ctx: Context): Map<String, Any> = mapOf(
        "ids" to profileIds(ctx),
        "auto" to profileAuto(ctx),
        "autoLevel" to profileAutoLevel(ctx),
        "hasBackup" to profileBackup(ctx).isNotEmpty(),
    )

    fun setProfile(ctx: Context, map: Map<*, *>) {
        val e = p(ctx).edit()
        (map["ids"] as? List<*>)?.let { l ->
            e.putString("profileIds", l.filterIsInstance<String>().filter { it in SaverProfile.ALL }.joinToString(","))
        }
        (map["auto"] as? Boolean)?.let { e.putBoolean("profileAuto", it) }
        (map["autoLevel"] as? Number)?.let { e.putInt("profileAutoLevel", it.toInt().coerceIn(10, 60)) }
        e.apply()
    }

    /** Werte vor dem Sparprofil: id -> Zahl (Schalter 1/0). */
    fun profileBackup(ctx: Context): Map<String, Int> =
        (p(ctx).getString("profileBackup", "") ?: "").split(",")
            .mapNotNull { e ->
                val i = e.indexOf('=')
                if (i <= 0) null else e.substring(i + 1).toIntOrNull()?.let { e.substring(0, i) to it }
            }
            .toMap()

    fun setProfileBackup(ctx: Context, m: Map<String, Int>) {
        p(ctx).edit().putString("profileBackup", m.entries.joinToString(",") { "${it.key}=${it.value}" }).apply()
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
