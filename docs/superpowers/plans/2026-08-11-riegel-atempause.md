# Atempause Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach jeder Stufe der Tagesnutzung legt sich ein nicht überspringbarer Countdown über die App; die Wartezeit verdoppelt sich je Stufe und ist bei einer Minute gedeckelt. Danach geht es immer weiter — die Pause sperrt nicht.

**Architecture:** Die Rechnung liegt in reinem Kotlin (`PausePlanner`) und ist per JUnit prüfbar; Android steckt außen herum — derselbe Schnitt wie `CalendarPlanner`/`CalendarSource` und `ScreenTimeCalculator`/`AndroidUsageSource`. Die Tagesnutzung kommt aus dem bestehenden `ScreenTimeCalculator`. Der Pausenschirm läuft ohne Flutter, wie der Sperrschirm.

**Tech Stack:** Kotlin (JVM 17), Flutter 3.44 / Dart 3.12, JUnit 4.13.2, `AccessibilityService`, `UsageStatsManager`, MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** `docs/superpowers/specs/2026-08-11-riegel-atempause-design.md`

---

## Vorbemerkungen für die Umsetzung

**Gradle braucht JDK 17.** `JAVA_HOME` zeigt auf dieser Maschine auf eine JVM 8. Vor jedem Gradle-Aufruf setzen:

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
```

**Nicht PowerShell für Gradle benutzen.** `2>&1` auf einer nativen exe verfälscht dort den Rückgabewert — ein erfolgreicher Build meldet 255. Die Bash-Werkzeuge nehmen.

**Testzahlen aus den JUnit-XMLs bilden**, nicht der Konsole glauben:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && grep -ho 'tests="[0-9]*" skipped="[0-9]*" failures="[0-9]*" errors="[0-9]*"' build/app/test-results/testDebugUnitTest/TEST-*.xml | awk -F'"' '{t+=$2; f+=$6; e+=$8} END {print "tests="t, "failures="f, "errors="e}'
```

**`lib/secrets.dart` niemals lesen, ändern oder committen.** Enthält den echten Notion-Token.

**Emulatortests mit frischer Installation**, Berechtigungen **nicht** vorab setzen. In dieser Codebasis kosteten vorab erteilte Berechtigungen schon drei übersehene Blocker.

**Der Emulator setzt `appops GET_USAGE_STATS` gelegentlich selbst zurück**, sobald der Bedienungshilfe-Dienst angeht. Vor jeder Prüfung nachsehen:

```bash
adb shell appops get com.klaas.nfc_riegel GET_USAGE_STATS
```

---

## Dateiübersicht

| Datei | Verantwortung |
|---|---|
| `android/.../PausePlanner.kt` (neu) | reine Rechnung: fällige Stufe, Wartezeit, nächster Prüfzeitpunkt, Zusammenführen mehrerer Profile |
| `android/.../PauseStore.kt` (neu) | zuletzt gezeigte Stufe je App, mit Datum |
| `android/.../BlockColors.kt` (neu) | Farbkonstanten, bisher privat in `BlockActivity.kt` |
| `android/.../PauseActivity.kt` (neu) | der Pausenschirm |
| `android/.../BlockActivity.kt` | Farben wandern raus |
| `android/.../BlockerService.kt` | Auslösung und Terminplanung |
| `android/.../Profile.kt` | drei Felder für die Einstellungen |
| `android/.../LockCodec.kt` | Profilsatz wächst von 7 auf 10 Felder, liest den alten weiter |
| `android/.../RiegelChannel.kt` | drei Felder in `updateProfile` und im Zustand |
| `lib/lock_status.dart` | `ProfileInfo` bekommt drei Felder |
| `lib/riegel_channel.dart` | drei Felder in `updateProfile` |
| `lib/profile_screen.dart` | Abschnitt „Atempause" |

**Erwartete Testzahlen**

| nach Task | Kotlin | Dart |
|---|---|---|
| Ausgangslage | 181 | 36 |
| 1 | 193 | 36 |
| 2 | 195 | 36 |
| 6 | 195 | 40 |

Weicht eine Zahl ab, **nicht** die Zahl anpassen, sondern nachsehen, welcher Test fehlt oder zu viel ist.

---

### Task 1: Die Rechnung

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/PausePlanner.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/PausePlannerTest.kt` (neu)

Der ganze Inhalt des Vorhabens steckt hier. Alles Weitere ist Verkabelung.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PausePlannerTest {

    private val minute = 60_000L
    private val standard = PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 5)

    private fun entscheide(genutzteMinuten: Long, zuletzt: Int = 0) =
        PausePlanner.decide(standard, genutzteMinuten * minute, zuletzt)

    @Test
    fun `unterhalb der ersten Stufe keine Pause`() {
        val e = entscheide(14)

        assertNull(e.waitSeconds)
        assertEquals(0, e.step)
        assertEquals(minute, e.nextCheckAfterMillis)
    }

    @Test
    fun `genau auf der Stufe kommt die Pause`() {
        val e = entscheide(15)

        assertEquals(5, e.waitSeconds)
        assertEquals(1, e.step)
    }

    @Test
    fun `Wartezeit verdoppelt sich je Stufe`() {
        assertEquals(5, entscheide(15).waitSeconds)
        assertEquals(10, entscheide(30).waitSeconds)
        assertEquals(20, entscheide(45).waitSeconds)
        assertEquals(40, entscheide(60).waitSeconds)
    }

    @Test
    fun `Wartezeit ist bei einer Minute gedeckelt`() {
        assertEquals(60, entscheide(75).waitSeconds)
        assertEquals(60, entscheide(600).waitSeconds)
    }

    @Test
    fun `mehrere Stufen auf einmal ergeben eine Pause mit der hoechsten Wartezeit`() {
        // Berechtigung spät erteilt: aus dem Nichts stehen zwei Stunden da.
        val e = entscheide(120, zuletzt = 0)

        assertEquals(60, e.waitSeconds)
        assertEquals(8, e.step)
    }

    @Test
    fun `bereits gezeigte Stufe loest nicht erneut aus`() {
        val e = entscheide(20, zuletzt = 1)

        assertNull(e.waitSeconds)
        assertEquals(10 * minute, e.nextCheckAfterMillis)
    }

    @Test
    fun `ausgeschaltet loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(enabled = false), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `Stufenabstand null loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(stepMinutes = 0), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `negativer Stufenabstand loest nichts aus`() {
        val e = PausePlanner.decide(standard.copy(stepMinutes = -5), 90 * minute, 0)

        assertNull(e.waitSeconds)
        assertNull(e.nextCheckAfterMillis)
    }

    @Test
    fun `naechster Blick zaehlt bis zur naechsten Stufengrenze`() {
        assertEquals(15 * minute, entscheide(15, zuletzt = 1).nextCheckAfterMillis)
        assertEquals(5 * minute, entscheide(25, zuletzt = 1).nextCheckAfterMillis)
    }

    @Test
    fun `mehrere Profile ergeben den kleinsten Abstand und die laengste Wartezeit`() {
        val zusammen = PausePlanner.merge(
            listOf(
                PauseSettings(enabled = true, stepMinutes = 30, baseSeconds = 5),
                PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 8),
            )
        )

        assertEquals(PauseSettings(true, 15, 8), zusammen)
    }

    @Test
    fun `ausgeschaltete Profile zaehlen beim Zusammenfuehren nicht mit`() {
        assertNull(
            PausePlanner.merge(
                listOf(PauseSettings(enabled = false, stepMinutes = 5, baseSeconds = 30))
            )
        )
        assertEquals(
            PauseSettings(true, 15, 5),
            PausePlanner.merge(
                listOf(
                    PauseSettings(enabled = false, stepMinutes = 5, baseSeconds = 30),
                    PauseSettings(enabled = true, stepMinutes = 15, baseSeconds = 5),
                )
            ),
        )
    }
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler „Unresolved reference: PausePlanner".

- [ ] **Schritt 3: `PausePlanner.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

/** Was der Nutzer je Profil an der Atempause einstellt. */
data class PauseSettings(
    val enabled: Boolean = false,
    /** Abstand der Stufen in Minuten Tagesnutzung. */
    val stepMinutes: Int = 15,
    /** Wartezeit der ersten Stufe in Sekunden; danach verdoppelt sie sich. */
    val baseSeconds: Int = 5,
)

data class PauseDecision(
    /** Wartezeit in Sekunden — oder null, wenn keine Pause fällig ist. */
    val waitSeconds: Int?,
    /** Erreichte Stufe. Wird gespeichert, damit sie nicht erneut auslöst. */
    val step: Int,
    /**
     * Vordergrundmillisekunden bis zur nächsten Stufe — oder null, wenn es
     * nichts zu erwarten gibt. Darauf legt der Dienst seinen nächsten Blick.
     */
    val nextCheckAfterMillis: Long?,
)

/**
 * Rechnet aus der heutigen Nutzung einer App, ob eine Atempause fällig ist, wie
 * lang sie dauert und wann der nächste Blick nötig wird.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object PausePlanner {

    /**
     * Länger als eine Minute wäre Schikane statt Denkpause — und Schikane
     * erzeugt Umgehungen statt Einsicht.
     */
    const val MAX_WAIT_SECONDS = 60

    fun decide(
        settings: PauseSettings,
        usedMillis: Long,
        lastShownStep: Int,
    ): PauseDecision {
        // Eine kaputte Einstellung darf nicht in eine Dauerpause führen.
        if (!settings.enabled || settings.stepMinutes <= 0) {
            return PauseDecision(null, lastShownStep, null)
        }

        val stufenMillis = settings.stepMinutes * 60_000L
        val stufe = (usedMillis / stufenMillis).toInt()
        val bisZurNaechsten = (stufe + 1) * stufenMillis - usedMillis

        // Mehrere Stufen auf einmal ergeben eine Pause mit der Wartezeit der
        // höchsten erreichten — vier Pausen hintereinander wären eine Strafe.
        if (stufe > lastShownStep) {
            return PauseDecision(wartezeit(stufe, settings.baseSeconds), stufe, bisZurNaechsten)
        }
        return PauseDecision(null, lastShownStep, bisZurNaechsten)
    }

    private fun wartezeit(stufe: Int, baseSeconds: Int): Int {
        var wert = baseSeconds.toLong()
        repeat(stufe - 1) {
            wert *= 2
            if (wert >= MAX_WAIT_SECONDS) return MAX_WAIT_SECONDS
        }
        return wert.coerceIn(0L, MAX_WAIT_SECONDS.toLong()).toInt()
    }

    /**
     * Steht eine App in mehreren Profilen, gilt der kleinste Stufenabstand und
     * die längste Grundwartezeit. Strenger stellen ist immer erlaubt, lockerer
     * nie — dieselbe Linie wie bei den Zeitsperren.
     *
     * Null heißt: keines der Profile will eine Pause.
     */
    fun merge(alle: List<PauseSettings>): PauseSettings? {
        val an = alle.filter { it.enabled && it.stepMinutes > 0 }
        if (an.isEmpty()) return null
        return PauseSettings(
            enabled = true,
            stepMinutes = an.minOf { it.stepMinutes },
            baseSeconds = an.maxOf { it.baseSeconds },
        )
    }
}
```

- [ ] **Schritt 4: Tests laufen lassen**

Erwartet: 193 Tests, 0 Fehlschläge.

- [ ] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Rechnung fuer die Atempause"
```

---

### Task 2: Einstellungen am Profil

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

Der Profilsatz wächst von sieben auf zehn Felder. **Alte Sätze müssen weiter lesbar bleiben** — auf dem Handy liegen Profile im alten Format, und ein stiller Verlust würde die Sperre aufheben.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `LockCodecTest.kt`, vor die schließende Klammer:

```kotlin
    @Test
    fun `Atempause-Einstellungen ueberstehen Kodieren und Dekodieren`() {
        val profile = listOf(
            Profile(
                "p1", "Arbeit", setOf("com.a"), LockMode.TIMER, 45, null, false,
                PauseSettings(enabled = true, stepMinutes = 20, baseSeconds = 8),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `alter Profilsatz ohne Atempause bleibt lesbar`() {
        // Sieben Felder, wie vor der Atempause abgelegt.
        val alt = listOf("p1", "Arbeit", "com.a", "TIMER", "45", "", "0")
            .joinToString("\u0002")

        val zurueck = LockCodec.decodeProfiles(alt)

        assertEquals(1, zurueck.size)
        assertEquals("Arbeit", zurueck[0].name)
        assertEquals(PauseSettings(), zurueck[0].pause)
    }
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „No value passed for parameter 'pause'" bzw. „Unresolved reference: pause".

- [ ] **Schritt 3: `Profile` erweitern**

In `Profile.kt`, hinter `pinCalendarEnd`:

```kotlin
    /**
     * Atempause gegen Doomscrolling. Keine Sperre — sie hält kurz auf und lässt
     * dann weiter. Steht am Profil, gilt aber je App: man doomscrollt in einer
     * App, nicht in einem Profil.
     */
    val pause: PauseSettings = PauseSettings(),
```

- [ ] **Schritt 4: Den Codec erweitern**

In `LockCodec.kt` `encodeProfiles` die Liste um drei Einträge ergänzen — **ans Ende**, damit alte Sätze am Feldzähler erkennbar bleiben:

```kotlin
    fun encodeProfiles(profiles: List<Profile>): String =
        profiles.joinToString(RECORD.toString()) { p ->
            listOf(
                p.id,
                p.name,
                p.blockedPackages.joinToString(ITEM.toString()),
                p.defaultMode.name,
                p.durationMinutes.toString(),
                p.untilAt?.toString() ?: "",
                if (p.pinCalendarEnd) "1" else "0",
                if (p.pause.enabled) "1" else "0",
                p.pause.stepMinutes.toString(),
                p.pause.baseSeconds.toString(),
            ).joinToString(FIELD.toString())
        }
```

und `decodeProfiles` ersetzen:

```kotlin
    /**
     * Liest zehn Felder (mit Atempause) und sieben (davor). Ein alter Satz
     * bekommt die Vorgaben — stillschweigend zu verwerfen hieße, gesperrte Apps
     * zu vergessen.
     */
    fun decodeProfiles(raw: String): List<Profile> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 7 && f.size != 10) return@mapNotNull null
            Profile(
                id = f[0],
                name = f[1],
                blockedPackages = if (f[2].isEmpty()) emptySet() else f[2].split(ITEM).toSet(),
                defaultMode = runCatching { LockMode.valueOf(f[3]) }.getOrDefault(LockMode.TIMER),
                durationMinutes = f[4].toIntOrNull() ?: 60,
                untilAt = f[5].toLongOrNull(),
                pinCalendarEnd = f[6] == "1",
                pause = if (f.size == 10) {
                    PauseSettings(
                        enabled = f[7] == "1",
                        stepMinutes = f[8].toIntOrNull() ?: 15,
                        baseSeconds = f[9].toIntOrNull() ?: 5,
                    )
                } else {
                    PauseSettings()
                },
            )
        }
    }
```

- [ ] **Schritt 5: Tests laufen lassen**

Erwartet: 195 Tests, 0 Fehlschläge.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Atempause-Einstellungen am Profil"
```

---

### Task 3: Der Speicher für gezeigte Stufen

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/PauseStore.kt`

Ohne eigene Tests: `SharedPreferences` läuft in reinem JUnit nicht, und die Klasse enthält keine Rechnung — die steckt in `PausePlanner`.

- [ ] **Schritt 1: `PauseStore.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.content.Context
import java.util.Calendar
import java.util.TimeZone

/**
 * Merkt sich je App die zuletzt gezeigte Stufe, zusammen mit dem Tag, für den
 * sie galt. Wechselt das Datum, fängt die Staffelung von vorn an.
 *
 * Bewusst neben [LockState], nicht darin: eine Atempause ist keine Sperre. Der
 * Sperrzustand ist die eine Sache in dieser App, die niemals durcheinander-
 * kommen darf.
 */
class PauseStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences("riegel_pausen", Context.MODE_PRIVATE)

    fun lastStep(packageName: String, now: Long): Int {
        val roh = prefs.getString(packageName, null) ?: return 0
        val teile = roh.split('|')
        if (teile.size != 2) return 0
        if (teile[0] != tagesschluessel(now)) return 0
        return teile[1].toIntOrNull() ?: 0
    }

    fun remember(packageName: String, step: Int, now: Long) {
        prefs.edit().putString(packageName, "${tagesschluessel(now)}|$step").apply()
    }

    /**
     * Jahr und Tag im Jahr. Reicht als Kennung und macht den Mitternachts-
     * wechsel ohne Datumsrechnung erkennbar.
     */
    private fun tagesschluessel(now: Long): String {
        val kalender = Calendar.getInstance(TimeZone.getDefault())
        kalender.timeInMillis = now
        return "${kalender.get(Calendar.YEAR)}-${kalender.get(Calendar.DAY_OF_YEAR)}"
    }
}
```

- [ ] **Schritt 2: Übersetzen**

Erwartet: BUILD SUCCESSFUL, weiterhin 195 Tests.

- [ ] **Schritt 3: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Speicher fuer gezeigte Pausenstufen"
```

---

### Task 4: Farben herauslösen und der Pausenschirm

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockColors.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/PauseActivity.kt`

- [ ] **Schritt 1: `BlockColors.kt` anlegen**

Der Block steht bisher `private` in `BlockActivity.kt`. Wortgleich in die neue Datei, ohne `private`:

```kotlin
package com.klaas.nfc_riegel

import android.graphics.Color

/**
 * Farben aus `design_system/tokens.css`. Sperr- und Pausenschirm laufen ohne
 * Flutter-Engine, deshalb stehen sie hier als Konstanten statt im Theme —
 * ändert sich ein Token, müssen `tokens.css`, `lib/theme.dart` und diese Datei
 * gemeinsam nachgezogen werden.
 */
object BlockColors {
    val BACKGROUND = Color.parseColor("#05070C")   // bg-block, tiefer als alles andere
    val SURFACE = Color.parseColor("#141A24")      // bg-elev-1
    val BORDER = Color.parseColor("#29FFFFFF")     // border-strong
    val LOCKED = Color.parseColor("#F5A65B")       // locked
    val LOCKED_BRIGHT = Color.parseColor("#FFC089")
    val LOCKED_TINT = Color.parseColor("#24F5A65B")
    val ACCENT = Color.parseColor("#62D9E8")       // accent, für die Pause
    val FG_1 = Color.parseColor("#EEF2F7")
    val FG_2 = Color.parseColor("#B6C0CE")
    val FG_3 = Color.parseColor("#7C8899")
    val FG_4 = Color.parseColor("#515C6B")
}
```

- [ ] **Schritt 2: Den alten Block aus `BlockActivity.kt` entfernen**

Die Zeilen von `private object BlockColors {` bis zur zugehörigen schließenden Klammer ersatzlos löschen, samt dem Kommentarblock darüber. Der Import `android.graphics.Color` bleibt — er wird für `Color.TRANSPARENT` weiter gebraucht.

- [ ] **Schritt 3: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 195 Tests. Schlägt es mit „Unresolved reference: BlockColors" fehl, wurde zu viel gelöscht.

- [ ] **Schritt 4: `PauseActivity.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Die Atempause. Ein Countdown, der sich nicht überspringen lässt, danach zwei
 * Wege. Bewusst kein Sperrschirm: hier wird nichts verwehrt, nur aufgehalten.
 */
class PauseActivity : Activity() {

    private lateinit var countdown: TextView
    private lateinit var weiter: Button
    private lateinit var schliessen: Button
    private var verbleibend = 5
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            verbleibend -= 1
            if (verbleibend > 0) {
                countdown.text = verbleibend.toString()
                handler.postDelayed(this, 1000)
            } else {
                countdown.text = "0"
                zeigeKnoepfe()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        verbleibend = intent?.getIntExtra(EXTRA_SECONDS, 5) ?: 5
        setContentView(buildLayout())
    }

    override fun onResume() {
        super.onResume()
        if (verbleibend > 0) handler.postDelayed(ticker, 1000)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
    }

    /** Während des Countdowns führt die Zurück-Taste nicht heraus. */
    override fun onBackPressed() {
        if (verbleibend > 0) return
        super.onBackPressed()
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BlockColors.BACKGROUND)
            setPadding(dp(32), dp(40), dp(32), dp(32))
        }

        val app = TextView(this).apply {
            text = intent?.getStringExtra(EXTRA_APP_NAME) ?: "Diese App"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(BlockColors.FG_1)
            gravity = Gravity.CENTER
        }

        val heute = TextView(this).apply {
            val minuten = intent?.getIntExtra(EXTRA_USED_MINUTES, 0) ?: 0
            text = "Heute $minuten Minuten"
            textSize = 15f
            setTextColor(BlockColors.FG_2)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(28))
        }

        countdown = TextView(this).apply {
            text = verbleibend.toString()
            textSize = 56f
            typeface = Typeface.MONOSPACE
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(BlockColors.ACCENT)
            gravity = Gravity.CENTER
        }

        val frage = TextView(this).apply {
            text = "Willst du weitermachen?"
            textSize = 15f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, dp(32))
        }

        weiter = Button(this).apply {
            text = "Weiter"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.FG_2)
            background = roundedRect(Color.TRANSPARENT, dp(10), BlockColors.BORDER)
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            visibility = View.INVISIBLE
            setOnClickListener { finish() }
        }

        schliessen = Button(this).apply {
            text = "Schließen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.BACKGROUND)
            background = roundedRect(BlockColors.ACCENT, dp(10))
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            visibility = View.INVISIBLE
            setOnClickListener {
                startActivity(
                    Intent(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_HOME)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                finish()
            }
        }

        root.addView(app)
        root.addView(heute)
        root.addView(countdown)
        root.addView(frage)
        root.addView(weiter)
        root.addView(schliessen)
        return root
    }

    private fun zeigeKnoepfe() {
        weiter.visibility = View.VISIBLE
        schliessen.visibility = View.VISIBLE
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun roundedRect(fill: Int, radius: Int, stroke: Int? = null) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius.toFloat()
            setColor(fill)
            if (stroke != null) setStroke(dp(1).coerceAtLeast(1), stroke)
        }

    companion object {
        const val EXTRA_SECONDS = "sekunden"
        const val EXTRA_APP_NAME = "appName"
        const val EXTRA_USED_MINUTES = "genutzteMinuten"
    }
}
```

- [ ] **Schritt 5: Ins Manifest eintragen**

In `AndroidManifest.xml` hinter den `BlockActivity`-Eintrag (Zeile 73–79). `BlockActivity` steht dort auf `singleTask` mit leerer `taskAffinity` und `excludeFromRecents` — beides gehört zum Sperrschirm, der sich nicht wegwischen lassen darf. Die Pause braucht das nicht: sie ist ein Zwischenschirm in derselben Aufgabe, und wer sie über die Übersicht verlässt, hat die App verlassen — genau das war der Zweck.

```xml
        <activity
            android:name=".PauseActivity"
            android:exported="false"
            android:launchMode="singleTop"
            android:theme="@android:style/Theme.DeviceDefault.NoActionBar"/>
```

- [ ] **Schritt 6: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 195 Tests.

- [ ] **Schritt 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Pausenschirm, Farben in eigene Datei"
```

---

### Task 5: Auslösung im Dienst

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockerService.kt`

Der Kern: `BlockerService` horcht nur auf App-Wechsel. Statt zu pollen, rechnet er aus, wann die nächste Stufe fällig wird, und legt sich genau dafür einen Aufruf zurecht.

- [ ] **Schritt 1: Importe ergänzen**

```kotlin
import android.content.Intent
import android.os.Handler
import android.os.Looper
```

(`android.content.Intent` steht schon da.)

- [ ] **Schritt 2: Felder und Auslösung ergänzen**

In der Klasse `BlockerService`, hinter `private val engine by lazy { ... }`:

```kotlin
    private val handler = Handler(Looper.getMainLooper())
    private var geplant: Runnable? = null
```

**Der Rest der Methode muss umgebaut werden**, und dabei liegt eine Falle. Bisher steht ganz oben `if (blocked.isEmpty()) return`. Diese Zeile muss weg, sonst gibt es ohne laufende Sperre nie eine Pause — sie schützt aber zugleich den `SettingsGuard`. Fällt sie ersatzlos, würde der Riegel **auch ohne jede Sperre** jeden aus den Bedienungshilfen-Einstellungen werfen. Der Schutz muss also ausdrücklich an `blocked` gebunden werden.

Ersetze den Rumpf ab `val now`:

```kotlin
        val now = System.currentTimeMillis()
        val blocked = engine.blockedPackages(now)

        // Jeder Wechsel verwirft den vorgemerkten Blick: er galt der App, die
        // gerade verlassen wurde.
        geplant?.let { handler.removeCallbacks(it) }
        geplant = null

        if (pkg in blocked) {
            showBlockScreen(pkg)
            return
        }

        // Nur während einer Sperre: sonst wäre der Riegel eine App, die einen
        // grundlos aus den Systemeinstellungen wirft.
        if (blocked.isNotEmpty() &&
            pkg == SETTINGS_PACKAGE &&
            SettingsGuard.isGuarded(event.className?.toString())
        ) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            return
        }

        pruefePause(pkg)
```

Läuft eine Sperre für diese App, kommt der Sperrschirm und keine Pause — zwei Schirme übereinander wären albern.

- [ ] **Schritt 3: Die beiden Methoden ergänzen**

Vor `private companion object`:

```kotlin
    /**
     * Sucht die Einstellungen aller Profile, die diese App enthalten, führt sie
     * zusammen und schaut nach, ob eine Stufe fällig ist.
     */
    private fun pruefePause(pkg: String) {
        val profile = engine.state().profiles.filter { pkg in it.blockedPackages }
        val settings = PausePlanner.merge(profile.map { it.pause }) ?: return
        zeigeOderPlane(pkg, settings)
    }

    /**
     * Zeigt die Pause, wenn eine Stufe erreicht ist — sonst merkt sie sich den
     * Zeitpunkt vor, an dem die nächste fällig wird. Kein Sekundentakt: die
     * fehlenden Vordergrundmillisekunden stehen fest, also genügt ein einziger
     * verzögerter Aufruf.
     */
    private fun zeigeOderPlane(pkg: String, settings: PauseSettings) {
        val quelle = AndroidUsageSource(this)
        if (!quelle.granted()) return

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val genutzt = ScreenTimeCalculator
            .totals(quelle.events(beginn, jetzt), beginn, jetzt)[pkg] ?: 0L

        val store = PauseStore(this)
        val entscheidung = PausePlanner.decide(settings, genutzt, store.lastStep(pkg, jetzt))

        val wartezeit = entscheidung.waitSeconds
        if (wartezeit != null) {
            store.remember(pkg, entscheidung.step, jetzt)
            startActivity(
                Intent(this, PauseActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    .putExtra(PauseActivity.EXTRA_SECONDS, wartezeit)
                    .putExtra(PauseActivity.EXTRA_APP_NAME, appName(pkg))
                    .putExtra(PauseActivity.EXTRA_USED_MINUTES, (genutzt / 60_000L).toInt())
            )
            return
        }

        val rest = entscheidung.nextCheckAfterMillis ?: return
        val runnable = Runnable { zeigeOderPlane(pkg, settings) }
        geplant = runnable
        // Nie schneller als alle fünf Sekunden nachsehen — auf der Stufengrenze
        // wäre der Rest sonst null und der Dienst liefe im Kreis.
        handler.postDelayed(runnable, rest.coerceAtLeast(5_000L))
    }

    private fun appName(pkg: String): String = runCatching {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(pkg)
```

- [ ] **Schritt 4: Übersetzen und Tests laufen lassen**

Erwartet: BUILD SUCCESSFUL, 195 Tests, 0 Fehlschläge.

- [ ] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Atempause ausloesen und vormerken"
```

---

### Task 6: Kanal, Dart-Modell und Einstellungen

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`
- Modify: `nfc_riegel/lib/lock_status.dart`
- Modify: `nfc_riegel/lib/riegel_channel.dart`
- Modify: `nfc_riegel/lib/profile_screen.dart`
- Test: `nfc_riegel/test/lock_status_test.dart`
- Test: `nfc_riegel/test/profile_screen_test.dart` (neu)

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `test/lock_status_test.dart`, in `main()`:

```dart
  test('Atempause-Einstellungen werden gelesen', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'blockedPackages': <dynamic>[],
          'defaultMode': 'TIMER',
          'durationMinutes': 60,
          'pinCalendarEnd': false,
          'pauseEnabled': true,
          'pauseStepMinutes': 20,
          'pauseBaseSeconds': 8,
        },
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.profiles.first.pauseEnabled, isTrue);
    expect(status.profiles.first.pauseStepMinutes, 20);
    expect(status.profiles.first.pauseBaseSeconds, 8);
  });

  test('fehlende Atempause-Angaben ergeben die Vorgaben', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'blockedPackages': <dynamic>[],
          'defaultMode': 'TIMER',
          'durationMinutes': 60,
          'pinCalendarEnd': false,
        },
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.profiles.first.pauseEnabled, isFalse);
    expect(status.profiles.first.pauseStepMinutes, 15);
    expect(status.profiles.first.pauseBaseSeconds, 5);
  });
```

Neue Datei `test/profile_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';
import 'package:nfc_riegel/profile_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  Map<dynamic, dynamic>? gespeichert;

  void stub({required bool usageGranted}) {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'usageAccessGranted':
              return usageGranted;
            case 'updateProfile':
              gespeichert = call.arguments as Map<dynamic, dynamic>;
              return true;
            case 'openUsageAccessSettings':
              return true;
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const profil = ProfileInfo(
    id: 'p1',
    name: 'Arbeit',
    blockedPackages: [],
    mode: LockMode.timer,
    durationMinutes: 60,
    untilAt: null,
    pinCalendarEnd: false,
    pauseEnabled: false,
    pauseStepMinutes: 15,
    pauseBaseSeconds: 5,
  );

  Widget screen() => MaterialApp(
    home: ProfileScreen(profile: profil, channel: RiegelChannel(channel)),
  );

  testWidgets('mit Berechtigung erscheint der Schalter', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Atempause'), findsOneWidget);
  });

  testWidgets('ohne Berechtigung erscheint der Hinweis statt der Regler', (
    tester,
  ) async {
    stub(usageGranted: false);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nutzungsdaten'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('eingeschaltete Atempause landet im Kanalaufruf', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['pauseEnabled'], isTrue);
    expect(gespeichert!['pauseStepMinutes'], 15);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: „No named parameter with the name 'pauseEnabled'".

- [ ] **Schritt 3: Den Kanal erweitern**

In `RiegelChannel.kt` im Zweig `"updateProfile"` die Profilerzeugung ergänzen — hinter `pinCalendarEnd`:

```kotlin
                        pause = PauseSettings(
                            enabled = call.argument<Boolean>("pauseEnabled") ?: false,
                            stepMinutes = call.argument<Int>("pauseStepMinutes") ?: 15,
                            baseSeconds = call.argument<Int>("pauseBaseSeconds") ?: 5,
                        ),
```

und in `stateMap()` bei den Profilen, hinter `"pinCalendarEnd" to p.pinCalendarEnd`:

```kotlin
                    "pauseEnabled" to p.pause.enabled,
                    "pauseStepMinutes" to p.pause.stepMinutes,
                    "pauseBaseSeconds" to p.pause.baseSeconds,
```

- [ ] **Schritt 4: `ProfileInfo` erweitern**

In `lib/lock_status.dart` die Klasse ergänzen — Konstruktor, Felder und `fromMap`:

```dart
    required this.pauseEnabled,
    required this.pauseStepMinutes,
    required this.pauseBaseSeconds,
```

```dart
  /// Atempause gegen Doomscrolling. Keine Sperre — sie hält kurz auf.
  final bool pauseEnabled;
  final int pauseStepMinutes;
  final int pauseBaseSeconds;
```

```dart
      pauseEnabled: map['pauseEnabled'] as bool? ?? false,
      pauseStepMinutes: map['pauseStepMinutes'] as int? ?? 15,
      pauseBaseSeconds: map['pauseBaseSeconds'] as int? ?? 5,
```

- [ ] **Schritt 5: `updateProfile` im Dart-Kanal erweitern**

In `lib/riegel_channel.dart`, in der Karte von `updateProfile`:

```dart
        'pauseEnabled': profile.pauseEnabled,
        'pauseStepMinutes': profile.pauseStepMinutes,
        'pauseBaseSeconds': profile.pauseBaseSeconds,
```

- [ ] **Schritt 6: Den Abschnitt im Profilschirm ergänzen**

In `lib/profile_screen.dart` den Zustand ergänzen, hinter `late bool _pin = ...`:

```dart
  late bool _pause = widget.profile.pauseEnabled;
  late int _pauseStep = widget.profile.pauseStepMinutes;
  late int _pauseBase = widget.profile.pauseBaseSeconds;
  bool? _usageGranted;
```

`initState` ergänzen (die Klasse hat bisher keins — direkt über `dispose` einfügen):

```dart
  @override
  void initState() {
    super.initState();
    _ladeBerechtigung();
  }

  Future<void> _ladeBerechtigung() async {
    final granted = await widget.channel.usageAccessGranted();
    if (mounted) setState(() => _usageGranted = granted);
  }
```

In `_save` die drei Felder mitgeben, hinter `pinCalendarEnd: _pin,`:

```dart
        pauseEnabled: _pause,
        pauseStepMinutes: _pauseStep,
        pauseBaseSeconds: _pauseBase,
```

Und im `build`, zwischen dem `SwitchListTile` für den Kalender-Nagel und dem `SizedBox(height: RiegelSpacing.s8)`:

```dart
          const SizedBox(height: RiegelSpacing.s6),
          Text('ATEMPAUSE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          if (_usageGranted == false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ohne Zugriff auf die Nutzungsdaten kann Riegel nicht wissen, '
                  'wie lange du in einer App warst.',
                  style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
                ),
                const SizedBox(height: RiegelSpacing.s3),
                OutlinedButton(
                  onPressed: widget.channel.openUsageAccessSettings,
                  child: const Text('Zugriff erlauben'),
                ),
              ],
            )
          else ...[
            SwitchListTile(
              value: _pause,
              onChanged: (v) => setState(() => _pause = v),
              title: const Text('Atempause'),
              subtitle: const Text(
                'Hält dich nach jeder Stufe kurz auf. Sperrt nicht — nach dem '
                'Countdown geht es weiter.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_pause) ...[
              Text(
                'Alle $_pauseStep Minuten Tagesnutzung',
                style: const TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 12,
                  color: RiegelColors.fg2,
                ),
              ),
              Slider(
                value: _pauseStep.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (v) => setState(() => _pauseStep = v.round()),
              ),
              Text(
                'Erste Pause $_pauseBase Sekunden, danach doppelt so lang',
                style: const TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 12,
                  color: RiegelColors.fg2,
                ),
              ),
              Slider(
                value: _pauseBase.toDouble(),
                min: 3,
                max: 30,
                divisions: 9,
                onChanged: (v) => setState(() => _pauseBase = v.round()),
              ),
            ],
          ],
```

- [ ] **Schritt 7: Alle Aufrufer von `ProfileInfo` nachziehen**

`ProfileInfo` hat drei neue Pflichtfelder. `flutter analyze` nennt jede Stelle. Betroffen sind mindestens `lib/profile_screen.dart` (`_save`) und `lib/setup_wizard.dart`. Im Wizard die Werte des bestehenden Profils durchreichen:

```dart
          pauseEnabled: first.pauseEnabled,
          pauseStepMinutes: first.pauseStepMinutes,
          pauseBaseSeconds: first.pauseBaseSeconds,
```

- [ ] **Schritt 8: Prüfen und Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: „No issues found!", 40 Tests grün.

- [ ] **Schritt 9: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test nfc_riegel/android/app/src && git commit -m "feat: Atempause einstellen"
```

---

### Task 7: Emulatortest, Bauen, Ablegen

**Files:**
- Modify: `nfc_riegel/GERAETETEST.md`
- Modify: `nfc_riegel/lib/build_info.dart`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Schritt 1: Prüfliste ergänzen**

Ans Ende von `GERAETETEST.md`:

```markdown
## Atempause

- [ ] Ohne Nutzungsdaten-Berechtigung: Hinweis statt Regler im Profil
- [ ] Atempause einschalten, Stufenabstand auf 5 Minuten stellen
- [ ] Gesperrte App öffnen und liegen lassen — Pause kommt **mitten im
      Scrollen**, nicht erst beim App-Wechsel
- [ ] Countdown lässt sich nicht überspringen, Zurück-Taste wirkt nicht
- [ ] „Weiter" führt zurück in die App
- [ ] „Schließen" führt auf den Startbildschirm
- [ ] Zweite Stufe wartet doppelt so lang
- [ ] Nach genug Stufen bleibt die Wartezeit bei 60 Sekunden
- [ ] App aus einem Profil ohne Atempause: keine Pause
- [ ] Während einer laufenden Sperre: Sperrschirm, keine Pause
- [ ] Über Mitternacht hinweg beginnt die Staffelung von vorn
- [ ] App wechseln und zurückkommen: keine doppelte Pause für dieselbe Stufe
- [ ] Update über eine bestehende Installation: alte Profile sind noch da,
      Atempause steht auf aus
```

- [ ] **Schritt 2: Build-Nummer auf 8**

`lib/build_info.dart`:

```dart
const int kBuildNumber = 8;
```

`pubspec.yaml`:

```yaml
version: 1.0.0+8
```

- [ ] **Schritt 3: Alles prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: sauber, 40 Dart-Tests, 195 Kotlin-Tests, 0 Fehlschläge.

- [ ] **Schritt 4: Am Emulator prüfen**

Frische Installation, Berechtigungen **nicht** vorab setzen:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && flutter build apk --debug && "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" uninstall com.klaas.nfc_riegel; "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-debug.apk
```

Der entscheidende Punkt ist, dass die Pause **während** der Nutzung kommt. Dafür Stufenabstand auf 5 Minuten stellen, eine gesperrte App öffnen und fünf Minuten laufen lassen, ohne sie anzufassen. Kommt nichts, ist die Terminplanung in `BlockerService` das Problem — dann in `logcat` nach `PauseActivity` sehen.

- [ ] **Schritt 5: Release bauen und ablegen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && flutter build apk --release && cp build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" && md5sum build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

Beide MD5-Summen müssen übereinstimmen. Danach die Versionsnummer prüfen:

```bash
"$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt2.exe" dump badging "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" | head -1
```

Erwartet: `versionCode='8'`.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel && git commit -m "chore: Atempause in der Prueflisten und Build 8"
```

---

## Selbstprüfung gegen die Spec

| Spec-Abschnitt | Task |
|---|---|
| Staffelung, Verdopplung, Deckel bei 60 s | 1 |
| mehrere Stufen ergeben eine Pause | 1 |
| kleinster Abstand, längste Wartezeit bei mehreren Profilen | 1 |
| Stufenabstand null oder negativ löst nichts aus | 1 |
| Einstellungen je Profil, alte Profile bleiben lesbar | 2 |
| Datumswechsel setzt zurück | 3 |
| Pausenschirm, Countdown nicht überspringbar, Weiter/Schließen | 4 |
| `BlockColors` in eigener Datei | 4 |
| Pause **mitten in der Sitzung**, ohne Polling | 5 |
| Sperre hat Vorrang, keine Pause | 5 |
| Umgehungsschutz bleibt an eine laufende Sperre gebunden | 5 |
| nur Apps aus Profilen mit eingeschalteter Pause | 5 |
| Riegel selbst löst nie aus | 5 (`BlockerService` überspringt das eigene Paket bereits) |
| Hinweis statt Regler ohne Berechtigung | 6 |

**Bewusst nicht enthalten** (wie in der Spec): keine Sperre, keine Statistik über Pausen, keine Belohnung fürs Aufhören, kein Verlauf.
