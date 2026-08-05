# Zeitsperren ohne Chip — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zeitsperren (`TIMER`, `UNTIL`) starten ohne Chip und lassen sich vor Ablauf nur durch einen Generalschlüssel oder den Notfall-Code öffnen.

**Architecture:** Zwei unabhängige Spuren im `LockState`: die bestehende `chipLock` (nur noch `OPEN`, endet durch Scan) und eine neue Liste `timeLocks` (höchstens eine je Profil, endet durch Ablauf). Gesperrt ist die Vereinigung der Blocklisten aller aktiven Sperren. Die reine `LockEngine` bleibt frei von Android-Abhängigkeiten und damit in JUnit testbar.

**Tech Stack:** Kotlin (JVM 17, JUnit 4.13.2), Flutter 3.44 / Dart 3.12, MethodChannel `com.klaas.nfc_riegel/riegel`, SharedPreferences über `LockCodec`.

**Spec:** `docs/superpowers/specs/2026-08-05-riegel-zeitsperren-design.md`

---

## Vorbemerkungen für die Umsetzung

**Verifikationsbefehl** — immer auf `:app` einschränken. Ohne den Doppelpunkt läuft
Gradle über alle Module, darunter `image_picker`, und braucht ein Vielfaches der
Zeit:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Ausgangslage: 75 Tests, 0 Fehlschläge.

**`testDebugUnitTest` kompiliert alle Hauptquellen mit.** Eine Signaturänderung an
`ChipLock` bricht daher jeden Aufrufer, auch solche, die mit Tests nichts zu tun
haben. Deshalb ist die Reihenfolge hier bewusst gewählt: erst werden alle
Verbraucher von `chipLock.mode` und `chipLock.endsAt` befreit (Tasks 6–8), erst
danach fallen die Felder weg (Task 9).

**Diese Dateien lesen `chipLock`** — vollständige Liste, ermittelt per Suche, damit
Task 9 nichts übersieht:

Hauptquellen: `Profile.kt`, `LockState.kt`, `LockEngine.kt`, `LockCodec.kt`,
`LockMigration.kt`, `SharedPrefsLockStore.kt`, `LockController.kt`,
`LockNotification.kt`, `RiegelChannel.kt`, `Diagnostics.kt`, `BlockActivity.kt`,
`NfcToggleActivity.kt`, `UninstallAdmin.kt`

Tests: `LockCodecTest.kt`, `LockEngineBlockTest.kt`, `LockEngineCodeTest.kt`,
`LockEngineSettingsTest.kt`, `LockEngineTimerTest.kt`, `LockEngineToggleTest.kt`,
`LockMigrationTest.kt`, `DiagnosticsTest.kt`

**Pfadwurzel** für alle Kotlin-Pfade:
`nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/`
Tests: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/`

---

### Task 1: TimeLock-Modell, Codec, Speicher

Rein additiv. Nach dieser Task laufen alle 75 bestehenden Tests unverändert weiter.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

An `LockCodecTest.kt` anhängen (innerhalb der bestehenden Testklasse):

```kotlin
    @Test
    fun `Zeitsperren ueberstehen Hin- und Rueckwandlung`() {
        val locks = listOf(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            TimeLock("p2", LockMode.UNTIL, 1_700_000_600_000),
        )
        assertEquals(locks, LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(locks)))
    }

    @Test
    fun `leere Zeitsperrenliste bleibt leer`() {
        assertEquals(
            emptyList<TimeLock>(),
            LockCodec.decodeTimeLocks(LockCodec.encodeTimeLocks(emptyList())),
        )
    }

    @Test
    fun `Zeitsperre ohne Endzeitpunkt wird verworfen`() {
        val kaputt = "p1" + '\u001F' + "TIMER" + '\u001F' + "keineZahl"
        assertEquals(emptyList<TimeLock>(), LockCodec.decodeTimeLocks(kaputt))
    }
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, `Unresolved reference: TimeLock`.

- [ ] **Schritt 3: `TimeLock` in `Profile.kt` ergänzen**

Ans Ende von `Profile.kt` anhängen:

```kotlin
/**
 * Eine Zeitsperre. Startet ohne Chip — über die Schaltfläche, durch einen Scan
 * oder später durch einen Termin — und endet vorzeitig nur durch einen
 * Generalschlüssel oder den Notfall-Code. Höchstens eine je Profil.
 */
data class TimeLock(
    val profileId: String,
    /** TIMER oder UNTIL, nie OPEN. */
    val mode: LockMode,
    val endsAt: Long,
)
```

- [ ] **Schritt 4: Feld in `LockState.kt` ergänzen**

`LockState` bekommt eine Zeile nach `chipLock`:

```kotlin
data class LockState(
    val profiles: List<Profile> = emptyList(),
    val tags: List<TagBinding> = emptyList(),
    val chipLock: ChipLock? = null,
    val timeLocks: List<TimeLock> = emptyList(),
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
) {
```

Der Rest der Klasse bleibt unverändert. Alle bestehenden Aufrufer benennen ihre
Argumente, das Einschieben bricht daher nichts.

- [ ] **Schritt 5: Codec-Funktionen ergänzen**

In `LockCodec.kt` hinter `decodeChipLock` einfügen:

```kotlin
    fun encodeTimeLocks(locks: List<TimeLock>): String =
        locks.joinToString(RECORD.toString()) { l ->
            listOf(l.profileId, l.mode.name, l.endsAt.toString())
                .joinToString(FIELD.toString())
        }

    fun decodeTimeLocks(raw: String): List<TimeLock> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 3) return@mapNotNull null
            TimeLock(
                profileId = f[0],
                mode = runCatching { LockMode.valueOf(f[1]) }.getOrNull()
                    ?: return@mapNotNull null,
                endsAt = f[2].toLongOrNull() ?: return@mapNotNull null,
            )
        }
    }
```

- [ ] **Schritt 6: Speicher anbinden**

In `SharedPrefsLockStore.kt` in `load()` nach der `chipLock`-Zeile ergänzen:

```kotlin
            timeLocks = LockCodec.decodeTimeLocks(prefs.getString(KEY_TIME_LOCKS, "") ?: ""),
```

In `save()` nach der `KEY_CHIP_LOCK`-Zeile ergänzen:

```kotlin
            .putString(KEY_TIME_LOCKS, LockCodec.encodeTimeLocks(state.timeLocks))
```

Im `companion object` ergänzen:

```kotlin
        const val KEY_TIME_LOCKS = "timeLocks"
```

- [ ] **Schritt 7: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge. Die drei neuen Codec-Tests kommen zu den 75 hinzu.

- [ ] **Schritt 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: TimeLock im Zustandsmodell und im Codec"
```

---

### Task 2: Engine — aktive Sperren, Vereinigung, Ablauf

Rein additiv. `onTagScanned` bleibt unverändert.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineBlockTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineTimerTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

An `LockEngineBlockTest.kt` anhängen. Die Klasse hat bereits die Profile `arbeit`
(id `p1`) und `nacht` (id `p2`) sowie eine Hilfsfunktion `engine(lock: ChipLock?)`.
Für Zeitsperren wird eine zweite Hilfsfunktion gebraucht:

```kotlin
    private fun engineMitZeitsperren(vararg locks: TimeLock): LockEngine =
        LockEngine(
            FakeLockStore(
                LockState(profiles = listOf(arbeit, nacht), timeLocks = locks.toList())
            )
        )

    @Test
    fun `laufende Zeitsperre sperrt die Pakete ihres Profils`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertEquals(arbeit.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `abgelaufene Zeitsperre sperrt nicht mehr`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now - 1))
        assertEquals(emptySet<String>(), e.blockedPackages(now))
    }

    @Test
    fun `zwei Zeitsperren sperren die Vereinigung`() {
        val e = engineMitZeitsperren(
            TimeLock("p1", LockMode.TIMER, now + 60_000),
            TimeLock("p2", LockMode.UNTIL, now + 90_000),
        )
        assertEquals(arbeit.blockedPackages + nacht.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `Chipsperre und Zeitsperre sperren gemeinsam`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                chipLock = ChipLock("p1", LockMode.OPEN),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 60_000)),
            )
        )
        val e = LockEngine(store)
        assertEquals(arbeit.blockedPackages + nacht.blockedPackages, e.blockedPackages(now))
    }

    @Test
    fun `hasActiveLock erkennt eine laufende Zeitsperre`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertTrue(e.hasActiveLock(now))
    }

    @Test
    fun `hasActiveLock ist falsch wenn alles abgelaufen ist`() {
        val e = engineMitZeitsperren(TimeLock("p1", LockMode.TIMER, now - 1))
        assertFalse(e.hasActiveLock(now))
    }
```

Falls `assertTrue`/`assertFalse` in der Datei noch nicht importiert sind, ergänzen:

```kotlin
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
```

An `LockEngineTimerTest.kt` anhängen:

```kotlin
    @Test
    fun `abgelaufene Zeitsperren werden abgeraeumt, laufende bleiben`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(profil),
                timeLocks = listOf(
                    TimeLock("p1", LockMode.TIMER, now - 1),
                    TimeLock("p2", LockMode.UNTIL, now + 60_000),
                ),
            )
        )
        val e = LockEngine(store)

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 60_000, store.current.timeLocks.single().endsAt)
    }
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, `Unresolved reference: hasActiveLock`.

- [ ] **Schritt 3: Hilfsfunktionen in `LockEngine` ergänzen**

Direkt hinter `activeChipLock` einfügen:

```kotlin
    /** Zeitsperren, die jetzt noch gelten. Abgelaufene zählen nicht. */
    private fun activeTimeLocks(s: LockState, now: Long): List<TimeLock> =
        s.timeLocks.filter { now < it.endsAt }

    /** Profile, die gerade sperren — über die Chipsperre oder eine Zeitsperre. */
    private fun lockedProfileIds(s: LockState, now: Long): Set<String> = buildSet {
        activeChipLock(s, now)?.let { add(it.profileId) }
        activeTimeLocks(s, now).forEach { add(it.profileId) }
    }

    /** Sperrt gerade irgendetwas? Grundlage aller Einstellungswächter. */
    fun hasActiveLock(now: Long): Boolean = lockedProfileIds(store.load(), now).isNotEmpty()
```

- [ ] **Schritt 4: `blockedPackages` auf die Vereinigung umstellen**

`blockedPackages` vollständig ersetzen:

```kotlin
    /**
     * Vereinigung aller aktiven Sperren: Chipsperre und Zeitsperren. Ein Paket ist
     * gesperrt, sobald irgendeine davon es enthält.
     */
    fun blockedPackages(now: Long): Set<String> {
        val s = store.load()
        return lockedProfileIds(s, now)
            .flatMapTo(mutableSetOf()) { s.profileById(it)?.blockedPackages ?: emptySet() }
    }
```

- [ ] **Schritt 5: `onTimerElapsed` um Zeitsperren erweitern**

`onTimerElapsed` vollständig ersetzen:

```kotlin
    /**
     * Vom Alarm gerufen. Räumt jede abgelaufene Sperre ab — auch mehrere zugleich.
     * Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val verbleibend = s.timeLocks.filter { now < it.endsAt }
        val chipEnde = s.chipLock?.endsAt
        val chipAbgelaufen = chipEnde != null && now >= chipEnde

        if (verbleibend.size == s.timeLocks.size && !chipAbgelaufen) return s

        val next = if (chipAbgelaufen) {
            s.copy(
                chipLock = null,
                timeLocks = verbleibend,
                failedAttempts = 0,
                codeLockedUntil = null,
            )
        } else {
            s.copy(timeLocks = verbleibend)
        }
        store.save(next)
        return next
    }
```

Der `chipAbgelaufen`-Zweig verschwindet in Task 9, sobald `ChipLock` kein `endsAt`
mehr hat. Bis dahin bleibt das bisherige Verhalten der Chipsperre unangetastet,
damit die bestehenden Timer-Tests grün bleiben.

- [ ] **Schritt 6: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Vereinigung aus Chip- und Zeitsperren"
```

---

### Task 3: Engine — `startTimeLock`

Rein additiv. Noch ruft niemand die Funktion auf.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Create: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineStartTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

Neue Datei `LockEngineStartTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test

class LockEngineStartTest {

    private val now = 1_000_000L

    private val timerProfil = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 30,
    )
    private val untilProfil = Profile(
        id = "p2",
        name = "Nacht",
        blockedPackages = setOf("com.zhiliaoapp.musically"),
        defaultMode = LockMode.UNTIL,
        untilAt = now + 3_600_000,
    )
    private val openProfil = Profile(
        id = "p3",
        name = "Fokus",
        blockedPackages = setOf("com.reddit.frontpage"),
        defaultMode = LockMode.OPEN,
    )

    private fun engine(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(timerProfil, untilProfil, openProfil),
                timeLocks = locks.toList(),
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `TIMER startet und endet nach der Dauer`() {
        val (e, store) = engine()
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `UNTIL startet und uebernimmt den Zeitpunkt des Profils`() {
        val (e, store) = engine()
        val result = e.startTimeLock("p2", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(now + 3_600_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `OPEN-Profil laesst sich nicht als Zeitsperre starten`() {
        val (e, store) = engine()
        assertEquals(StartOutcome.WRONG_MODE, e.startTimeLock("p3", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `unbekanntes Profil ergibt NO_PROFILE`() {
        val (e, _) = engine()
        assertEquals(StartOutcome.NO_PROFILE, e.startTimeLock("gibtsnicht", now).outcome)
    }

    @Test
    fun `UNTIL in der Vergangenheit startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = now - 1)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startTimeLock("p2", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `UNTIL ohne Zeitpunkt startet nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(untilProfil.copy(untilAt = null)))
        )
        val e = LockEngine(store)
        assertEquals(StartOutcome.UNTIL_IN_PAST, e.startTimeLock("p2", now).outcome)
    }

    @Test
    fun `zweiter Start verlaengert den TIMER ab jetzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.EXTENDED, result.outcome)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Start verkuerzt eine laufende Sperre niemals`() {
        val spaeter = now + 120 * 60_000
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, spaeter))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(spaeter, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `ohne Verlaengerungserlaubnis passiert bei laufender Sperre nichts`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now + 10 * 60_000))
        val result = e.startTimeLock("p1", now, allowExtend = false)
        assertEquals(StartOutcome.ALREADY_RUNNING, result.outcome)
        assertEquals(now + 10 * 60_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `abgelaufene Sperre desselben Profils wird ersetzt statt ergaenzt`() {
        val (e, store) = engine(TimeLock("p1", LockMode.TIMER, now - 1))
        val result = e.startTimeLock("p1", now)
        assertEquals(StartOutcome.STARTED, result.outcome)
        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 30 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `zwei Profile duerfen gleichzeitig sperren`() {
        val (e, store) = engine()
        e.startTimeLock("p1", now)
        e.startTimeLock("p2", now)
        assertEquals(2, store.current.timeLocks.size)
    }
}
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, `Unresolved reference: StartOutcome`.

- [ ] **Schritt 3: Ergebnistypen ergänzen**

In `LockEngine.kt` hinter `CodeResult` einfügen:

```kotlin
enum class StartOutcome {
    STARTED,
    /** Lief bereits, das neue Ende liegt später. */
    EXTENDED,
    /** Lief bereits, das neue Ende liegt nicht später — Zustand unverändert. */
    ALREADY_RUNNING,
    /** OPEN gibt es nur als Chipsperre. */
    WRONG_MODE,
    UNTIL_IN_PAST,
    NO_PROFILE,
}

data class StartResult(val state: LockState, val outcome: StartOutcome)
```

- [ ] **Schritt 4: `startTimeLock` schreiben**

In `LockEngine` hinter `onTagScanned` einfügen:

```kotlin
    /**
     * Startet eine Zeitsperre — aus der Oberfläche oder durch einen Scan. Strenger
     * stellen ist immer erlaubt, verkürzen nie: ein späteres Ende überschreibt,
     * ein früheres lässt die laufende Sperre in Ruhe.
     *
     * [allowExtend] steht nur der Schaltfläche zu. Beim Scan ist es `false`, damit
     * ein versehentlich vorbeigeführter Chip eine Sperre nicht verdoppelt.
     */
    fun startTimeLock(profileId: String, now: Long, allowExtend: Boolean = true): StartResult {
        val s = store.load()
        val profile = s.profileById(profileId)
            ?: return StartResult(s, StartOutcome.NO_PROFILE)

        val endsAt = when (profile.defaultMode) {
            LockMode.OPEN -> return StartResult(s, StartOutcome.WRONG_MODE)
            LockMode.TIMER -> now + profile.durationMinutes * 60_000L
            LockMode.UNTIL -> {
                val until = profile.untilAt
                if (until == null || until <= now) {
                    return StartResult(s, StartOutcome.UNTIL_IN_PAST)
                }
                until
            }
        }

        val laufend = s.timeLocks.firstOrNull { it.profileId == profileId && now < it.endsAt }
        if (laufend != null && (!allowExtend || endsAt <= laufend.endsAt)) {
            return StartResult(s, StartOutcome.ALREADY_RUNNING)
        }

        val andere = s.timeLocks.filter { it.profileId != profileId }
        val next = s.copy(
            timeLocks = andere + TimeLock(profileId, profile.defaultMode, endsAt),
        )
        store.save(next)
        return StartResult(next, if (laufend != null) StartOutcome.EXTENDED else StartOutcome.STARTED)
    }
```

- [ ] **Schritt 5: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Zeitsperre starten und verlaengern"
```

---

### Task 4: Engine — Scan-Verhalten der zwei Spuren

Erste Verhaltensänderung. Bestehende Tests, die das alte Verhalten festschreiben,
werden hier mit umgestellt.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

An `LockEngineToggleTest.kt` anhängen. Die Klasse hat `arbeit` (id `p1`, `OPEN`),
`nacht` (id `p2`) und eine Hilfsfunktion `engine(tags, chipLock)`.

```kotlin
    @Test
    fun `normaler Chip beendet eine Zeitsperre nicht`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("AA", "Chip", "p1")),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 60_000)),
            )
        )
        val e = LockEngine(store)

        e.onTagScanned("AA", now)

        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `Chip mit OPEN-Profil sperrt zusaetzlich zur laufenden Zeitsperre`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("AA", "Chip", "p1")),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 60_000)),
            )
        )
        val e = LockEngine(store)

        assertEquals(ScanOutcome.LOCKED, e.onTagScanned("AA", now).outcome)
        assertEquals("p1", store.current.chipLock!!.profileId)
        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `Chip mit TIMER-Profil startet eine Zeitsperre statt einer Chipsperre`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht.copy(defaultMode = LockMode.TIMER, durationMinutes = 45)),
                tags = listOf(TagBinding("BB", "Chip", "p2")),
            )
        )
        val e = LockEngine(store)

        assertEquals(ScanOutcome.LOCKED, e.onTagScanned("BB", now).outcome)
        assertNull(store.current.chipLock)
        assertEquals(now + 45 * 60_000L, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `erneuter Scan beendet die eigene Zeitsperre nicht und verlaengert sie nicht`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht.copy(defaultMode = LockMode.TIMER, durationMinutes = 45)),
                tags = listOf(TagBinding("BB", "Chip", "p2")),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 10_000)),
            )
        )
        val e = LockEngine(store)

        assertEquals(ScanOutcome.TIME_LOCK_RUNNING, e.onTagScanned("BB", now).outcome)
        assertEquals(now + 10_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Generalschluessel beendet Chip- und Zeitsperre gemeinsam`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("CC", "General", "p1", isMaster = true)),
                chipLock = ChipLock("p1", LockMode.OPEN),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 60_000)),
            )
        )
        val e = LockEngine(store)

        assertEquals(ScanOutcome.MASTER_CLEARED, e.onTagScanned("CC", now).outcome)
        assertNull(store.current.chipLock)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }

    @Test
    fun `Generalschluessel beendet auch eine reine Zeitsperre`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("CC", "General", "p1", isMaster = true)),
                timeLocks = listOf(TimeLock("p2", LockMode.UNTIL, now + 60_000)),
            )
        )
        val e = LockEngine(store)

        assertEquals(ScanOutcome.MASTER_CLEARED, e.onTagScanned("CC", now).outcome)
        assertEquals(emptyList<TimeLock>(), store.current.timeLocks)
    }
```

Falls `assertNull` noch nicht importiert ist, ergänzen:

```kotlin
import org.junit.Assert.assertNull
```

- [ ] **Schritt 2: Bestehende Tests ans neue Verhalten anpassen**

Zwei Tests in `LockEngineToggleTest.kt` schreiben das alte Verhalten fest, dass
eine `TIMER`-Chipsperre durch Scan endet oder übernommen wird. Sie stehen um
Zeile 107 und 117 und beginnen mit
`val (e, store) = engine(chipLock = ChipLock("p1", LockMode.TIMER, now + 5000))`.

Beide `ChipLock`-Argumente auf `LockMode.OPEN` ohne Endzeit umstellen:

```kotlin
        val (e, store) = engine(chipLock = ChipLock("p1", LockMode.OPEN))
```

Damit prüfen sie weiterhin genau das, wofür sie gedacht waren — Freigeben und
Übernehmen zwischen Chipsperren. Die `TIMER`-Fälle decken jetzt die neuen Tests aus
Schritt 1 ab.

- [ ] **Schritt 3: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, `Unresolved reference: TIME_LOCK_RUNNING`.

- [ ] **Schritt 4: `ScanOutcome` erweitern**

In `LockEngine.kt` die beiden neuen Werte ergänzen:

```kotlin
enum class ScanOutcome {
    LOCKED,
    UNLOCKED,
    /** Anderer Chip hat übernommen: alte Sperre beendet, neue gestartet. */
    SWITCHED,
    /** Generalschlüssel hat alle Sperren beendet. */
    MASTER_CLEARED,
    /** Zeitsperre lief bereits, ihr Ende wurde nach hinten geschoben. */
    EXTENDED,
    /** Zeitsperre läuft — nur ein Generalschlüssel öffnet sie vorzeitig. */
    TIME_LOCK_RUNNING,
    UNKNOWN_TAG,
    NO_TAG_ENROLLED,
    /** Chip zeigt auf ein Profil, das es nicht mehr gibt. */
    NO_PROFILE,
    /** UNTIL-Zeitpunkt liegt in der Vergangenheit. */
    UNTIL_IN_PAST,
}
```

- [ ] **Schritt 5: `clearLocks` in zwei Funktionen trennen**

`clearLocks` vollständig ersetzen:

```kotlin
    /**
     * Beendet alles: Chipsperre und sämtliche Zeitsperren. Nur der Generalschlüssel
     * und der Notfall-Code kommen hier hin.
     */
    private fun clearAll(s: LockState): LockState {
        val next = s.copy(
            chipLock = null,
            timeLocks = emptyList(),
            failedAttempts = 0,
            codeLockedUntil = null,
        )
        store.save(next)
        return next
    }

    /**
     * Beendet nur die Chipsperre. Zeitsperren bleiben stehen — ein normaler Chip
     * kommt an sie nicht heran.
     */
    private fun clearChipLock(s: LockState): LockState {
        val next = s.copy(chipLock = null)
        store.save(next)
        return next
    }
```

Anschließend den einzigen weiteren Aufrufer anpassen: in `submitCode` wird aus
`return CodeResult(clearLocks(s), CodeOutcome.UNLOCKED)`

```kotlin
            return CodeResult(clearAll(s), CodeOutcome.UNLOCKED)
```

- [ ] **Schritt 6: `onTagScanned` ersetzen**

```kotlin
    /**
     * Chip gescannt. Der Modus des Profils entscheidet, welche Spur entsteht:
     * `OPEN` ergibt eine Chipsperre, `TIMER` und `UNTIL` eine Zeitsperre. Ein
     * normaler Chip beendet nur seine eigene Chipsperre; an Zeitsperren kommt
     * allein der Generalschlüssel.
     */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        if (s.tags.isEmpty()) return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        val tag = s.tagByUid(uid) ?: return ScanResult(s, ScanOutcome.UNKNOWN_TAG)

        if (tag.isMaster && lockedProfileIds(s, now).isNotEmpty()) {
            return ScanResult(clearAll(s), ScanOutcome.MASTER_CLEARED)
        }

        val profile = s.profileById(tag.profileId)
            ?: return ScanResult(s, ScanOutcome.NO_PROFILE)

        if (profile.defaultMode != LockMode.OPEN) {
            val result = startTimeLock(profile.id, now, allowExtend = false)
            return ScanResult(result.state, result.outcome.asScanOutcome())
        }

        val active = activeChipLock(s, now)
        if (active != null && active.profileId == profile.id) {
            return ScanResult(clearChipLock(s), ScanOutcome.UNLOCKED)
        }

        val next = s.copy(chipLock = ChipLock(profile.id, LockMode.OPEN))
        store.save(next)
        return ScanResult(
            next,
            if (active != null) ScanOutcome.SWITCHED else ScanOutcome.LOCKED,
        )
    }

    private fun StartOutcome.asScanOutcome(): ScanOutcome = when (this) {
        StartOutcome.STARTED -> ScanOutcome.LOCKED
        StartOutcome.EXTENDED -> ScanOutcome.EXTENDED
        StartOutcome.ALREADY_RUNNING -> ScanOutcome.TIME_LOCK_RUNNING
        StartOutcome.UNTIL_IN_PAST -> ScanOutcome.UNTIL_IN_PAST
        StartOutcome.WRONG_MODE, StartOutcome.NO_PROFILE -> ScanOutcome.NO_PROFILE
    }
```

- [ ] **Schritt 7: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Chip beendet keine Zeitsperre mehr"
```

---

### Task 5: Engine — Einstellungswächter mit Uhrzeit

Die Wächter fragten bisher `chipLock != null` ohne Uhrzeit. Eine abgelaufene, noch
nicht abgeräumte Sperre blockierte damit das Anlernen von Chips, bis der Alarm
feuerte. Alle Wächter bekommen `now` und rechnen den Ablauf mit.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineSettingsTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

An `LockEngineSettingsTest.kt` anhängen. Die Klasse hat eine Hilfsfunktion
`engine(lock: ChipLock? = null)` mit den Profilen `p1` und `p2` und liefert
`Pair<LockEngine, FakeLockStore>`. Für Zeitsperren wird eine zweite gebraucht:

```kotlin
    private fun engineMitZeitsperre(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("AA", "Chip", "p1")),
                timeLocks = locks.toList(),
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `Profil mit laufender Zeitsperre ist nicht aenderbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertFalse(e.updateProfile(arbeit.copy(name = "Neu"), now))
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Zeitsperre aenderbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertTrue(e.updateProfile(nacht.copy(name = "Neu"), now))
    }

    @Test
    fun `Profil mit laufender Zeitsperre ist nicht loeschbar`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertFalse(e.deleteProfile("p1", now))
    }

    @Test
    fun `waehrend einer Zeitsperre laesst sich kein Chip anlernen`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertFalse(e.enrollTag("BB", "Neu", "p1", false, now))
    }

    @Test
    fun `waehrend einer Zeitsperre gibt es keinen neuen Notfall-Code`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))
        assertNull(e.generateCode(now))
    }

    @Test
    fun `abgelaufene Zeitsperre blockiert die Einstellungen nicht mehr`() {
        val (e, _) = engineMitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 1))
        assertTrue(e.enrollTag("BB", "Neu", "p1", false, now))
        assertTrue(e.updateProfile(arbeit.copy(name = "Neu"), now))
    }
```

Zusätzlich in derselben Datei **alle bestehenden Aufrufe** der fünf Wächter um das
`now`-Argument ergänzen:

- `e.updateProfile(x)` → `e.updateProfile(x, now)`
- `e.deleteProfile(id)` → `e.deleteProfile(id, now)`
- `e.enrollTag(a, b, c, d)` → `e.enrollTag(a, b, c, d, now)`
- `e.deleteTag(uid)` → `e.deleteTag(uid, now)`
- `e.generateCode()` → `e.generateCode(now)`

`addProfile` bleibt ohne `now` — Anlegen ist immer erlaubt.

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, zu viele Argumente für `updateProfile`.

- [ ] **Schritt 3: Wächter umstellen**

In `LockEngine.kt` die fünf Funktionen ersetzen:

```kotlin
    /**
     * Speichert ein geändertes Profil. Abgelehnt, solange genau dieses Profil
     * sperrt — gleich ob über die Chipsperre oder eine Zeitsperre. Andere Profile
     * bleiben bearbeitbar.
     */
    fun updateProfile(profile: Profile, now: Long): Boolean {
        val s = store.load()
        if (profile.id in lockedProfileIds(s, now)) return false
        if (s.profileById(profile.id) == null) return false
        store.save(s.copy(profiles = s.profiles.map { if (it.id == profile.id) profile else it }))
        return true
    }

    /**
     * Löscht ein Profil. Das letzte bleibt bestehen, ein sperrendes ebenfalls.
     * Zugeordnete Chips ziehen auf das erste verbleibende Profil.
     */
    fun deleteProfile(id: String, now: Long): Boolean {
        val s = store.load()
        if (s.profiles.size <= 1) return false
        if (id in lockedProfileIds(s, now)) return false
        val remaining = s.profiles.filterNot { it.id == id }
        val fallback = remaining.first().id
        store.save(
            s.copy(
                profiles = remaining,
                tags = s.tags.map { if (it.profileId == id) it.copy(profileId = fallback) else it },
            )
        )
        return true
    }

    /**
     * Chip anlernen oder einen bekannten aktualisieren. Während jeder Sperre
     * abgelehnt — sonst läge man sich mitten in der Sperre einen neuen Schlüssel an.
     */
    fun enrollTag(
        uid: String,
        label: String,
        profileId: String,
        isMaster: Boolean,
        now: Long,
    ): Boolean {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return false
        val binding = TagBinding(uid, label, profileId, isMaster)
        val existing = s.tagByUid(uid)
        val tags = if (existing == null) s.tags + binding
        else s.tags.map { if (it.uid.equals(uid, ignoreCase = true)) binding else it }
        store.save(s.copy(tags = tags))
        return true
    }

    fun deleteTag(uid: String, now: Long): Boolean {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return false
        store.save(s.copy(tags = s.tags.filterNot { it.uid.equals(uid, ignoreCase = true) }))
        return true
    }

    /**
     * Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig
     * zurück. Während jeder Sperre abgelehnt — sonst wäre der Notausgang jederzeit
     * neu ausstellbar.
     */
    fun generateCode(now: Long): String? {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return null
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(s.copy(codeHash = Hashing.sha256(code)))
        return code
    }
```

- [ ] **Schritt 4: `RiegelChannel` nachziehen**

In `RiegelChannel.kt` ganz oben in `register` vor dem `when` eine Hilfszeile
einführen und die fünf Aufrufe ergänzen. Die betroffenen Zweige werden zu:

```kotlin
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
                    result.success(
                        controller.engine.updateProfile(profile, System.currentTimeMillis())
                    )
                }

                "deleteProfile" -> result.success(
                    controller.engine.deleteProfile(
                        call.argument<String>("id") ?: "",
                        System.currentTimeMillis(),
                    )
                )

                "deleteTag" -> result.success(
                    controller.engine.deleteTag(
                        call.argument<String>("uid") ?: "",
                        System.currentTimeMillis(),
                    )
                )

                "generateCode" ->
                    result.success(controller.engine.generateCode(System.currentTimeMillis()))
```

- [ ] **Schritt 5: `TagWriteActivity` nachziehen**

`TagWriteActivity.kt:134-135` ruft `enrollTag` auf. Die beiden Zeilen

```kotlin
                val stored = LockEngine(SharedPrefsLockStore(this))
                    .enrollTag(NfcSupport.toHex(tag.id), label, profileId, isMaster)
```

ersetzen durch:

```kotlin
                val stored = LockEngine(SharedPrefsLockStore(this))
                    .enrollTag(
                        NfcSupport.toHex(tag.id),
                        label,
                        profileId,
                        isMaster,
                        System.currentTimeMillis(),
                    )
```

- [ ] **Schritt 6: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "fix: Einstellungswaechter rechnen den Ablauf mit"
```

---

### Task 6: LockController — Alarm und Benachrichtigung für mehrere Sperren

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt`

Ohne eigene Tests: beide Klassen fassen Android-Dienste an und laufen in reinem
JUnit nicht. Die Logik, die sich testen lässt, sitzt in der Engine.

- [ ] **Schritt 1: `LockController.applyEffects` ersetzen**

```kotlin
    private fun applyEffects(state: LockState) {
        val naechstesEnde = state.timeLocks.minOfOrNull { it.endsAt }
        if (naechstesEnde != null) {
            LockScheduler.schedule(context, naechstesEnde)
        } else {
            LockScheduler.cancel(context)
        }

        if (state.chipLock != null || state.timeLocks.isNotEmpty()) {
            LockNotification.show(context, state)
        } else {
            LockNotification.hide(context)
        }
    }
```

Der Alarm hängt jetzt allein an den Zeitsperren. Eine Chipsperre hat kein Ende und
braucht keinen.

- [ ] **Schritt 2: `LockNotification.show` ersetzen**

```kotlin
    fun show(context: Context, state: LockState) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val gesperrteProfile = buildSet {
            state.chipLock?.let { add(it.profileId) }
            state.timeLocks.forEach { add(it.profileId) }
        }
        if (gesperrteProfile.isEmpty()) return

        val namen = gesperrteProfile.mapNotNull { state.profileById(it)?.name }
        val anzahlApps = gesperrteProfile
            .flatMap { state.profileById(it)?.blockedPackages ?: emptySet() }
            .distinct()
            .size

        val fruehestesEnde = state.timeLocks.minOfOrNull { it.endsAt }
        val text = when {
            fruehestesEnde != null && state.chipLock != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)}, der Rest nach erneutem Scan"
            fruehestesEnde != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)} — vorher nur mit Generalschlüssel"
            else -> "Chip scannen, um freizugeben"
        }

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(
                "Riegel aktiv — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}, " +
                    "$anzahlApps Apps gesperrt"
            )
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun uhrzeit(millis: Long): String =
        SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(millis))
```

- [ ] **Schritt 3: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Alarm und Benachrichtigung fuer mehrere Sperren"
```

---

### Task 7: Android-Ränder von `chipLock.mode` und `chipLock.endsAt` befreien

Vorbereitung für Task 9. Fünf Dateien lesen die beiden Felder noch.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Diagnostics.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/UninstallAdmin.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

In `DiagnosticsTest.kt` anhängen:

```kotlin
    @Test
    fun `laufende Zeitsperre steht im Bericht`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(Profile(id = "p1", name = "Arbeit")),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 60_000)),
            ),
            now,
        )
        assertTrue(bericht["Sperre"]!!.contains("Arbeit"))
        assertTrue(bericht["Sperre"]!!.contains("TIMER"))
    }

    @Test
    fun `abgelaufene Zeitsperre gilt als offen`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(Profile(id = "p1", name = "Arbeit")),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now - 1)),
            ),
            now,
        )
        assertEquals("offen", bericht["Sperre"])
    }

    @Test
    fun `Chip- und Zeitsperre stehen beide im Bericht`() {
        val bericht = Diagnostics.summarize(
            LockState(
                profiles = listOf(
                    Profile(id = "p1", name = "Arbeit"),
                    Profile(id = "p2", name = "Nacht"),
                ),
                chipLock = ChipLock("p1", LockMode.OPEN),
                timeLocks = listOf(TimeLock("p2", LockMode.UNTIL, now + 60_000)),
            ),
            now,
        )
        assertTrue(bericht["Sperre"]!!.contains("Arbeit"))
        assertTrue(bericht["Sperre"]!!.contains("Nacht"))
    }
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: die drei neuen Tests schlagen fehl, weil `summarize` die Zeitsperren
nicht kennt.

- [ ] **Schritt 3: `Diagnostics.summarize` ersetzen**

Nur die Berechnung von `lockLine`; `profiles`, `chips`, `packages` und der
`linkedMapOf`-Block bleiben unverändert.

```kotlin
    fun summarize(state: LockState, now: Long): Map<String, String> {
        val zeilen = mutableListOf<String>()

        state.chipLock?.let { lock ->
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            zeilen += "Chip · $name"
        }

        state.timeLocks.filter { now < it.endsAt }.forEach { lock ->
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            val ende = SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(lock.endsAt))
            zeilen += "Zeit · $name · ${lock.mode.name} bis $ende"
        }

        val lockLine = if (zeilen.isEmpty()) "offen" else "gesperrt · " + zeilen.joinToString(" + ")
```

Der Rest der Funktion bleibt, wie er ist.

- [ ] **Schritt 4: `RiegelChannel.stateMap` ersetzen**

```kotlin
    private fun stateMap(): Map<String, Any?> {
        val s = controller.engine.state()
        val now = System.currentTimeMillis()
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
            "chipLock" to s.chipLock?.let { mapOf("profileId" to it.profileId) },
            "timeLocks" to s.timeLocks.filter { now < it.endsAt }.map { l ->
                mapOf(
                    "profileId" to l.profileId,
                    "mode" to l.mode.name,
                    "endsAt" to l.endsAt,
                )
            },
            "hasMasterTag" to s.tags.any { it.isMaster },
            "hasCode" to (s.codeHash != null),
        )
    }
```

Der bisherige Schlüssel `activeLock` entfällt. Die Dart-Seite wird in Task 10
darauf umgestellt; bis dahin liest sie einen fehlenden Schlüssel als `null`, was
„offen" bedeutet. Die App ist zwischen Task 7 und Task 10 also übersetzbar, zeigt
aber keine Sperre an.

- [ ] **Schritt 5: `startTimeLock` als Kanalmethode ergänzen**

In `RiegelChannel.register` im `when` vor `else` einfügen:

```kotlin
                "startTimeLock" -> {
                    val outcome = controller.startTimeLock(
                        call.argument<String>("profileId") ?: "",
                    )
                    result.success(outcome.name)
                }
```

Und in `LockController` die passende Methode ergänzen:

```kotlin
    fun startTimeLock(
        profileId: String,
        now: Long = System.currentTimeMillis(),
    ): StartOutcome {
        val result = engine.startTimeLock(profileId, now)
        applyEffects(result.state)
        return result.outcome
    }
```

- [ ] **Schritt 6: `BlockActivity.refresh` ersetzen**

`BlockActivity.kt:190-209`. Die Funktion vollständig ersetzen:

```kotlin
    private fun refresh() {
        val state = controller.engine.state()
        val now = System.currentTimeMillis()
        val laufende = state.timeLocks.filter { now < it.endsAt }
        val gesperrteProfile = buildSet {
            state.chipLock?.let { add(it.profileId) }
            laufende.forEach { add(it.profileId) }
        }
        if (gesperrteProfile.isEmpty()) {
            finish()
            return
        }

        val profileName = gesperrteProfile
            .mapNotNull { state.profileById(it)?.name }
            .joinToString(", ")
            .ifEmpty { "Riegel" }

        // Die am spätesten endende Zeitsperre zählt: eine frühere sagt nichts,
        // solange eine spätere noch greift.
        val spaetestesEnde = laufende.maxOfOrNull { it.endsAt }
        if (spaetestesEnde != null) {
            val remaining = ((spaetestesEnde - now) / 1000).coerceAtLeast(0)
            countdown.visibility = View.VISIBLE
            // Eine UNTIL-Sperre läuft über Nacht. „720:00" wäre keine Auskunft,
            // deshalb ab einer Stunde mit Stundenfeld.
            countdown.text = if (remaining >= 3600) {
                "%d:%02d:%02d".format(remaining / 3600, (remaining % 3600) / 60, remaining % 60)
            } else {
                "%02d:%02d".format(remaining / 60, remaining % 60)
            }
            hint.text = if (state.chipLock != null) {
                "Chip scannen oder warten"
            } else {
                "Vorher öffnet nur ein Generalschlüssel"
            }
        } else {
            countdown.visibility = View.GONE
            hint.text = "Chip scannen, um freizugeben"
        }
        modeCaption.text = "Profil: $profileName"
    }
```

- [ ] **Schritt 7: `NfcToggleActivity.handle` ersetzen**

`NfcToggleActivity.kt:24-48`. Die Funktion vollständig ersetzen:

```kotlin
    private fun handle(intent: Intent?) {
        val tag = intent?.let { NfcSupport.tagFrom(it) }
        if (tag == null) {
            toastAndFinish("Chip nicht lesbar")
            return
        }

        val uid = NfcSupport.toHex(tag.id)
        val result = LockController(this).scan(uid)
        val state = result.state
        val now = System.currentTimeMillis()

        // Ein Scan kann eine Chipsperre oder eine Zeitsperre erzeugt haben.
        val profileId = state.chipLock?.profileId
            ?: state.timeLocks.filter { now < it.endsAt }.maxByOrNull { it.endsAt }?.profileId
        val profileName = profileId?.let { state.profileById(it)?.name } ?: "Riegel"

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — $profileName"
            ScanOutcome.SWITCHED -> "Gewechselt auf $profileName"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            ScanOutcome.MASTER_CLEARED -> "Alle Sperren beendet"
            ScanOutcome.EXTENDED -> "Sperre verlängert — $profileName"
            ScanOutcome.TIME_LOCK_RUNNING ->
                "Zeitsperre läuft — nur ein Generalschlüssel öffnet"
            ScanOutcome.UNKNOWN_TAG -> "Fremder Chip"
            ScanOutcome.NO_TAG_ENROLLED -> "Erst in der App einen Chip anlernen"
            ScanOutcome.NO_PROFILE -> "Profil dieses Chips existiert nicht mehr"
            ScanOutcome.UNTIL_IN_PAST -> "Zeitpunkt liegt in der Vergangenheit"
        }
        toastAndFinish(message)
    }
```

- [ ] **Schritt 8: `UninstallAdmin` nachziehen**

`UninstallAdmin.kt` vollständig ersetzen. Hier wird `hasActiveLock` aus Task 2
zum ersten Mal produktiv genutzt:

```kotlin
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
```

- [ ] **Schritt 9: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 10: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Android-Raender kennen beide Sperrspuren"
```

---

### Task 8: Migration von v1 und v2

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockMigration.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockMigrationTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

An `LockCodecTest.kt` anhängen:

```kotlin
    @Test
    fun `v2-Datensatz mit OPEN bleibt eine Chipsperre`() {
        val alt = "p1" + '\u001F' + "OPEN" + '\u001F' + ""
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock(alt))
        assertNull(LockCodec.decodeLegacyTimeLock(alt))
    }

    @Test
    fun `v2-Datensatz mit TIMER wird zur Zeitsperre`() {
        val alt = "p1" + '\u001F' + "TIMER" + '\u001F' + "1700000000000"
        assertNull(LockCodec.decodeChipLock(alt))
        assertEquals(
            TimeLock("p1", LockMode.TIMER, 1_700_000_000_000),
            LockCodec.decodeLegacyTimeLock(alt),
        )
    }

    @Test
    fun `v3-Datensatz besteht nur aus der Profil-Kennung`() {
        assertEquals(ChipLock("p1"), LockCodec.decodeChipLock("p1"))
        assertNull(LockCodec.decodeLegacyTimeLock("p1"))
    }
```

Falls `assertNull` fehlt, ergänzen: `import org.junit.Assert.assertNull`.

In `LockMigrationTest.kt` den Test `laufende Sperre wird uebernommen`
(Zeilen 61–73) vollständig durch diese beiden ersetzen:

```kotlin
    @Test
    fun `laufende TIMER-Sperre wird zur Zeitsperre`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.TIMER, endsAt = 1_700_000_000_000,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        assertNull(state.chipLock)
        val lock = state.timeLocks.single()
        assertEquals(state.profiles.first().id, lock.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(1_700_000_000_000, lock.endsAt)
    }

    @Test
    fun `laufende OPEN-Sperre bleibt eine Chipsperre`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.OPEN, endsAt = null,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        assertEquals(state.profiles.first().id, state.chipLock!!.profileId)
        assertTrue(state.timeLocks.isEmpty())
    }
```

Der Test `ohne laufende Sperre bleibt chipLock null` (Zeilen 75–84) bleibt
unverändert gültig.

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler, `Unresolved reference: decodeLegacyTimeLock`.

- [ ] **Schritt 3: Codec auf v3 umstellen**

In `LockCodec.kt` `encodeChipLock` und `decodeChipLock` ersetzen und
`decodeLegacyTimeLock` ergänzen:

```kotlin
    /** v3: nur noch die Profil-Kennung. Eine Chipsperre hat weder Modus noch Ende. */
    fun encodeChipLock(lock: ChipLock?): String = lock?.profileId ?: ""

    /**
     * Liest v3 (ein Feld) und v2 (drei Felder: Kennung, Modus, Ende). Aus einem
     * v2-Datensatz bleibt nur `OPEN` eine Chipsperre; `TIMER` und `UNTIL` holt
     * [decodeLegacyTimeLock] ab.
     */
    fun decodeChipLock(raw: String): ChipLock? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size == 1) return ChipLock(f[0])
        if (f.size != 3) return null
        return if (f[1] == LockMode.OPEN.name) ChipLock(f[0]) else null
    }

    /** Die Zeitsperre, die in einem v2-Datensatz steckt — oder null. */
    fun decodeLegacyTimeLock(raw: String): TimeLock? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size != 3) return null
        val mode = runCatching { LockMode.valueOf(f[1]) }.getOrNull() ?: return null
        if (mode == LockMode.OPEN) return null
        val endsAt = f[2].toLongOrNull() ?: return null
        return TimeLock(f[0], mode, endsAt)
    }
```

`ChipLock("p1")` setzt voraus, dass `mode` und `endsAt` Vorgabewerte haben. Dafür
in `Profile.kt` die Felder vorläufig mit Vorgaben versehen — in Task 9 fallen sie
ganz weg:

```kotlin
data class ChipLock(
    val profileId: String,
    val mode: LockMode = LockMode.OPEN,
    val endsAt: Long? = null,
)
```

- [ ] **Schritt 4: `LockMigration.fromV1` ersetzen**

```kotlin
    fun fromV1(
        locked: Boolean,
        mode: LockMode,
        endsAt: Long?,
        durationMinutes: Int,
        blockedPackages: Set<String>,
        tagUid: String?,
        codeHash: String?,
    ): LockState {
        val profile = Profile(
            id = LEGACY_PROFILE_ID,
            name = "Standard",
            blockedPackages = blockedPackages,
            defaultMode = mode,
            durationMinutes = durationMinutes,
        )
        val tags = if (tagUid.isNullOrEmpty()) emptyList()
        else listOf(TagBinding(tagUid, "Chip 1", LEGACY_PROFILE_ID, isMaster = true))

        val chipLock = if (locked && mode == LockMode.OPEN) ChipLock(LEGACY_PROFILE_ID) else null
        val timeLocks = if (locked && mode != LockMode.OPEN && endsAt != null) {
            listOf(TimeLock(LEGACY_PROFILE_ID, mode, endsAt))
        } else {
            emptyList()
        }

        return LockState(
            profiles = listOf(profile),
            tags = tags,
            chipLock = chipLock,
            timeLocks = timeLocks,
            codeHash = codeHash,
        )
    }
```

- [ ] **Schritt 5: Speicher um die v2-Überführung ergänzen**

In `SharedPrefsLockStore.load()` den `return LockState(...)`-Block ersetzen:

```kotlin
        val rohChipLock = prefs.getString(KEY_CHIP_LOCK, "") ?: ""
        val zeitsperren = LockCodec.decodeTimeLocks(prefs.getString(KEY_TIME_LOCKS, "") ?: "")
        // Aus v2 kann im chipLock-Feld noch eine TIMER- oder UNTIL-Sperre stecken.
        // Abgelaufene wird verworfen; sie hat ohnehin keine Wirkung mehr.
        val ausV2 = LockCodec.decodeLegacyTimeLock(rohChipLock)
            ?.takeIf { System.currentTimeMillis() < it.endsAt }
            ?.takeIf { alt -> zeitsperren.none { it.profileId == alt.profileId } }

        return LockState(
            profiles = LockCodec.decodeProfiles(prefs.getString(KEY_PROFILES, "") ?: ""),
            tags = LockCodec.decodeTags(prefs.getString(KEY_TAGS, "") ?: ""),
            chipLock = LockCodec.decodeChipLock(rohChipLock),
            timeLocks = if (ausV2 == null) zeitsperren else zeitsperren + ausV2,
            codeHash = prefs.getString(KEY_CODE_HASH, null),
            failedAttempts = prefs.getInt(KEY_ATTEMPTS, 0),
            codeLockedUntil = prefs.getLong(KEY_CODE_LOCKED_UNTIL, -1L).takeIf { it > 0 },
        )
```

Beim nächsten `save()` schreibt der Codec das v3-Format, der alte Datensatz
verschwindet von selbst.

- [ ] **Schritt 6: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Migration bestehender Zeitsperren auf die neue Spur"
```

---

### Task 9: `ChipLock` verschlanken

Rein mechanisch. Nach den Tasks 1–8 liest keine Hauptquelle mehr `chipLock.mode`
oder `chipLock.endsAt`. **Erst am Ende der Task übersetzen** — dazwischen ist der
Baum nicht übersetzbar.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineBlockTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCodeTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineSettingsTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineTimerTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt`

- [ ] **Schritt 1: Alle verbliebenen Fundstellen auflisten**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && grep -rn "ChipLock(" android/app/src && grep -rn "chipLock!!\.\(mode\|endsAt\)\|chipLock?\.\(mode\|endsAt\)" android/app/src
```

Die Ausgabe ist die Arbeitsliste für diese Task. Jede Zeile muss abgearbeitet sein,
bevor Schritt 5 läuft.

- [ ] **Schritt 2: `ChipLock` verschlanken**

In `Profile.kt`:

```kotlin
/**
 * Die eine aktive Chipsperre. Höchstens eine gleichzeitig, immer unbefristet:
 * sie endet allein durch einen erneuten Scan, einen Generalschlüssel oder den
 * Notfall-Code. Alles Zeitgebundene steckt in [TimeLock].
 */
data class ChipLock(val profileId: String)
```

- [ ] **Schritt 3: `LockEngine` aufräumen**

`activeChipLock` verliert die Ablaufprüfung:

```kotlin
    /** Die Chipsperre. Sie läuft nicht ab — nur ein Scan oder der Code beendet sie. */
    private fun activeChipLock(s: LockState, now: Long): ChipLock? = s.chipLock
```

`now` bleibt als Parameter stehen, damit die Aufrufer unverändert bleiben und die
Signatur zur Kalenderstufe passt. Kotlin warnt bei ungenutzten Parametern nicht.

`onTimerElapsed` verliert den Chip-Zweig:

```kotlin
    /**
     * Vom Alarm gerufen. Räumt jede abgelaufene Zeitsperre ab — auch mehrere
     * zugleich. Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val verbleibend = s.timeLocks.filter { now < it.endsAt }
        if (verbleibend.size == s.timeLocks.size) return s
        val next = s.copy(timeLocks = verbleibend)
        store.save(next)
        return next
    }
```

In `onTagScanned` wird aus `ChipLock(profile.id, LockMode.OPEN)`:

```kotlin
        val next = s.copy(chipLock = ChipLock(profile.id))
```

- [ ] **Schritt 4: Alle Testdateien nachziehen**

Jede Fundstelle aus Schritt 1 abarbeiten. Die Muster:

- `ChipLock("p1", LockMode.OPEN)` → `ChipLock("p1")`
- `ChipLock("p2", LockMode.OPEN)` → `ChipLock("p2")`
- `ChipLock("p1", LockMode.TIMER, now + 60_000)` → als `TimeLock` in `timeLocks`
  überführen, nicht als Chipsperre. Der umgebende Test prüft dann eine Zeitsperre;
  seinen Namen entsprechend anpassen.
- `store.current.chipLock!!.mode` und `.endsAt` → entfernen oder auf die passende
  Zeitsperre umstellen.

`LockEngineBlockTest.kt:40` baut eine `ChipLock` mit Endzeit, um den Ablauf zu
prüfen — das ist jetzt eine Zeitsperre. Den Test auf `engineMitZeitsperren` aus
Task 2 umstellen.

`LockEngineTimerTest.kt` besteht fast vollständig aus solchen Fällen. Die Datei
komplett durch diese Fassung ersetzen:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L
    private val profil = Profile(id = "p1", name = "Arbeit")

    private fun mitZeitsperre(vararg locks: TimeLock): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(profil), timeLocks = locks.toList())
        )
        return LockEngine(store) to store
    }

    private fun mitChipsperre(): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(profil), chipLock = ChipLock("p1"))
        )
        return LockEngine(store) to store
    }

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 1))

        e.onTimerElapsed(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `laufender Timer bleibt bestehen`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now + 60_000))

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `abgelaufener UNTIL-Zeitpunkt gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now - 1))

        e.onTimerElapsed(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `kuenftiger UNTIL-Zeitpunkt bleibt bestehen`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now + 10_000))

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
    }

    @Test
    fun `Chipsperre wird vom Ablauf nicht beruehrt`() {
        val (e, store) = mitChipsperre()

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit abgelaufenem Ende gibt frei`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.TIMER, now - 10_000))

        e.restoreAfterBoot(now)

        assertTrue(store.current.timeLocks.isEmpty())
    }

    @Test
    fun `Boot mit laufendem Ende bleibt gesperrt`() {
        val (e, store) = mitZeitsperre(TimeLock("p1", LockMode.UNTIL, now + 10_000))

        e.restoreAfterBoot(now)

        assertEquals(now + 10_000, store.current.timeLocks.single().endsAt)
    }

    @Test
    fun `Boot mit Chipsperre bleibt gesperrt`() {
        val (e, store) = mitChipsperre()

        e.restoreAfterBoot(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `abgelaufene Zeitsperren werden abgeraeumt, laufende bleiben`() {
        val (e, store) = mitZeitsperre(
            TimeLock("p1", LockMode.TIMER, now - 1),
            TimeLock("p2", LockMode.UNTIL, now + 60_000),
        )

        e.onTimerElapsed(now)

        assertEquals(1, store.current.timeLocks.size)
        assertEquals(now + 60_000, store.current.timeLocks.single().endsAt)
    }
}
```

- [ ] **Schritt 5: Übersetzen und testen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 6: Gegenprobe, dass nichts übrig ist**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && grep -rn "chipLock.*mode\|chipLock.*endsAt" android/app/src
```

Erwartet: keine Ausgabe.

- [ ] **Schritt 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "refactor: Chipsperre ohne Modus und Endzeit"
```

---

### Task 10: Dart — `LockStatus` mit mehreren Sperren

**Files:**
- Modify: `nfc_riegel/lib/lock_status.dart`
- Modify: `nfc_riegel/lib/riegel_channel.dart`
- Test: `nfc_riegel/test/lock_status_test.dart`

- [ ] **Schritt 1: Fehlschlagende Tests schreiben**

Die bestehende Datei baut ihren Zustand über `activeLock` und prüft
`status.activeProfile` — beides fällt weg. `test/lock_status_test.dart`
vollständig ersetzen:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>>? timeLocks,
    List<Map<String, dynamic>>? tags,
    bool hasMasterTag = true,
    bool hasCode = true,
  }) => {
    'profiles': [
      {
        'id': 'p1',
        'name': 'Arbeit',
        'blockedPackages': ['com.a'],
        'defaultMode': 'TIMER',
        'durationMinutes': 45,
        'untilAt': null,
        'pinCalendarEnd': false,
      },
      {
        'id': 'p2',
        'name': 'Nacht',
        'blockedPackages': ['com.b'],
        'defaultMode': 'UNTIL',
        'durationMinutes': 60,
        'untilAt': null,
        'pinCalendarEnd': false,
      },
    ],
    'tags': tags ??
        [
          {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1', 'isMaster': true},
        ],
    'chipLock': chipLock,
    'timeLocks': timeLocks ?? <Map<String, dynamic>>[],
    'hasMasterTag': hasMasterTag,
    'hasCode': hasCode,
  };

  test('liest Profile und Chips', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.profiles.first.name, 'Arbeit');
    expect(status.profiles.first.durationMinutes, 45);
    expect(status.profiles.first.mode, LockMode.timer);
    expect(status.tags.single.label, 'Schreibtisch');
    expect(status.tags.single.isMaster, isTrue);
  });

  test('ohne Sperre ist nichts gesperrt', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.locked, isFalse);
    expect(status.earliestEnd, isNull);
    expect(status.lockedProfileIds, isEmpty);
  });

  test('Chipsperre sperrt ihr Profil ohne Endzeit', () {
    final status = LockStatus.fromMap(stateMap(chipLock: {'profileId': 'p1'}));

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isFalse);
    expect(status.earliestEnd, isNull);
  });

  test('liest Chipsperre und Zeitsperre getrennt', () {
    final status = LockStatus.fromMap(stateMap(
      chipLock: {'profileId': 'p1'},
      timeLocks: [
        {'profileId': 'p2', 'mode': 'TIMER', 'endsAt': 1700000000000},
      ],
    ));

    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isTrue);
    expect(status.timeLocks.length, 1);
    expect(status.timeLockFor('p2')!.mode, LockMode.timer);
    expect(status.timeLockFor('p1'), isNull);
  });

  test('frueheste Endzeit stammt aus der frueher endenden Zeitsperre', () {
    final status = LockStatus.fromMap(stateMap(
      timeLocks: [
        {'profileId': 'p1', 'mode': 'TIMER', 'endsAt': 2000},
        {'profileId': 'p2', 'mode': 'UNTIL', 'endsAt': 1000},
      ],
    ));

    expect(status.earliestEnd, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('hasMasterTag wird durchgereicht', () {
    expect(LockStatus.fromMap(stateMap()).hasMasterTag, isTrue);
    expect(LockStatus.fromMap(stateMap(hasMasterTag: false)).hasMasterTag, isFalse);
  });

  test('Einrichtung braucht Chip, Code und mindestens eine App', () {
    expect(LockStatus.fromMap(stateMap()).setupComplete, isTrue);
    expect(LockStatus.fromMap(stateMap(tags: [])).setupComplete, isFalse);
    expect(LockStatus.fromMap(stateMap(hasCode: false)).setupComplete, isFalse);
  });
}
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: Übersetzungsfehler, `timeLocks` ist kein Feld von `LockStatus`.

- [ ] **Schritt 3: `TimeLockInfo` und `LockStatus` ersetzen**

In `lock_status.dart` vor `LockStatus` einfügen:

```dart
/// Eine laufende Zeitsperre. Endet vorzeitig nur durch Generalschlüssel oder Code.
class TimeLockInfo {
  const TimeLockInfo({
    required this.profileId,
    required this.mode,
    required this.endsAt,
  });

  final String profileId;
  final LockMode mode;
  final DateTime endsAt;

  factory TimeLockInfo.fromMap(Map<dynamic, dynamic> map) => TimeLockInfo(
    profileId: map['profileId'] as String? ?? '',
    mode: _modeFrom(map['mode'] as String?),
    endsAt: DateTime.fromMillisecondsSinceEpoch(map['endsAt'] as int? ?? 0),
  );
}
```

`LockStatus` vollständig ersetzen:

```dart
/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.profiles,
    required this.tags,
    required this.chipLockProfileId,
    required this.timeLocks,
    required this.hasMasterTag,
    required this.hasCode,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;

  /// Profil der Chipsperre, oder null. Sie hat kein Ende.
  final String? chipLockProfileId;

  /// Laufende Zeitsperren. Die native Seite filtert abgelaufene bereits heraus.
  final List<TimeLockInfo> timeLocks;

  /// Ob überhaupt ein Generalschlüssel angelernt ist — sonst öffnet nur der Code.
  final bool hasMasterTag;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final chipLock = map['chipLock'] as Map<dynamic, dynamic>?;
    return LockStatus(
      profiles: (map['profiles'] as List<dynamic>? ?? [])
          .map((e) => ProfileInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => TagInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      chipLockProfileId: chipLock?['profileId'] as String?,
      timeLocks: (map['timeLocks'] as List<dynamic>? ?? [])
          .map((e) => TimeLockInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      hasMasterTag: map['hasMasterTag'] as bool? ?? false,
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  bool get locked => chipLockProfileId != null || timeLocks.isNotEmpty;

  /// Alle Profile, die gerade sperren — über beide Spuren.
  Set<String> get lockedProfileIds => {
    if (chipLockProfileId != null) chipLockProfileId!,
    ...timeLocks.map((l) => l.profileId),
  };

  bool isProfileLocked(String profileId) => lockedProfileIds.contains(profileId);

  TimeLockInfo? timeLockFor(String profileId) {
    for (final lock in timeLocks) {
      if (lock.profileId == profileId) return lock;
    }
    return null;
  }

  /// Wann die erste Sperre fällt. Null, wenn nur die Chipsperre läuft.
  DateTime? get earliestEnd {
    if (timeLocks.isEmpty) return null;
    var earliest = timeLocks.first.endsAt;
    for (final lock in timeLocks) {
      if (lock.endsAt.isBefore(earliest)) earliest = lock.endsAt;
    }
    return earliest;
  }

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete =>
      tags.isNotEmpty &&
      hasCode &&
      profiles.any((p) => p.blockedPackages.isNotEmpty);
}
```

- [ ] **Schritt 4: Kanalmethode ergänzen**

In `riegel_channel.dart` hinter `addProfile` einfügen:

```dart
  /// Startet eine Zeitsperre ohne Chip. Liefert den nativen Ausgang als Text,
  /// z.B. `STARTED`, `EXTENDED`, `ALREADY_RUNNING`, `UNTIL_IN_PAST`.
  Future<String> startTimeLock(String profileId) async =>
      await channel.invokeMethod<String>('startTimeLock', {
        'profileId': profileId,
      }) ??
      'NO_PROFILE';
```

- [ ] **Schritt 5: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: `home_screen_test.dart` schlägt fehl, weil es `activeProfileId` und
`endsAt` nutzt. Das wird in Task 11 mit umgestellt — hier nur `lock_status_test.dart`
prüfen:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/lock_status_test.dart
```

Erwartet: alle grün.

- [ ] **Schritt 6: Commit**

Ohne `flutter analyze`, das erst nach Task 11 wieder sauber ist.

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Dart-Zustand kennt Chip- und Zeitsperren"
```

---

### Task 11: Dart — Sperren und Verlängern mit Bestätigung

**Files:**
- Modify: `nfc_riegel/lib/home_screen.dart`
- Test: `nfc_riegel/test/home_screen_test.dart`

- [ ] **Schritt 1: Bestehenden Widget-Test anpassen und erweitern**

Die Datei stubt den MethodChannel und liefert im `getState` noch `activeLock`.
`test/home_screen_test.dart` vollständig ersetzen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/home_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  /// Zuletzt an `startTimeLock` übergebenes Profil — so lässt sich prüfen, ob
  /// der Knopf wirklich bis zur nativen Seite durchschlägt.
  String? gestartetesProfil;

  void stub({
    required bool accessibility,
    String defaultMode = 'TIMER',
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>> timeLocks = const [],
    bool hasMasterTag = true,
    bool hasCode = true,
  }) {
    gestartetesProfil = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getState':
          return {
            'profiles': [
              {
                'id': 'p1',
                'name': 'Arbeit',
                'blockedPackages': ['com.instagram.android'],
                'defaultMode': defaultMode,
                'durationMinutes': 60,
                'untilAt': null,
                'pinCalendarEnd': false,
              },
            ],
            'tags': [
              {
                'uid': '04AA',
                'label': 'Schreibtisch',
                'profileId': 'p1',
                'isMaster': hasMasterTag,
              },
            ],
            'chipLock': chipLock,
            'timeLocks': timeLocks,
            'hasMasterTag': hasMasterTag,
            'hasCode': hasCode,
          };
        case 'isAccessibilityEnabled':
          return accessibility;
        case 'isAdminActive':
          return true;
        case 'startTimeLock':
          gestartetesProfil = call.arguments['profileId'] as String?;
          return 'STARTED';
      }
      return null;
    });
  }

  List<Map<String, dynamic>> laufendeSperre() => [
    {
      'profileId': 'p1',
      'mode': 'TIMER',
      'endsAt': DateTime.now().millisecondsSinceEpoch + 60000,
    },
  ];

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Frei-Status', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    expect(find.text('Riegel offen'), findsOneWidget);
  });

  testWidgets('zeigt Gesperrt-Status mit Profilnamen', (tester) async {
    stub(accessibility: true, timeLocks: laufendeSperre());
    await zeige(tester);

    expect(find.text('Riegel zu'), findsOneWidget);
    expect(find.textContaining('Arbeit'), findsWidgets);
  });

  testWidgets('warnt, wenn der Dienst aus ist', (tester) async {
    stub(accessibility: false);
    await zeige(tester);

    expect(find.text('Sperre nicht wirksam'), findsOneWidget);
  });

  testWidgets('TIMER-Profil zeigt Sperren-Knopf', (tester) async {
    stub(accessibility: true, defaultMode: 'TIMER');
    await zeige(tester);

    expect(find.text('Sperren'), findsOneWidget);
  });

  testWidgets('OPEN-Profil zeigt keinen Sperren-Knopf', (tester) async {
    stub(accessibility: true, defaultMode: 'OPEN');
    await zeige(tester);

    expect(find.text('Sperren'), findsNothing);
  });

  testWidgets('laufende Zeitsperre bietet Verlaengern an', (tester) async {
    stub(accessibility: true, timeLocks: laufendeSperre());
    await zeige(tester);

    expect(find.text('Verlängern'), findsOneWidget);
  });

  testWidgets('Bestaetigung warnt ohne Generalschluessel', (tester) async {
    stub(accessibility: true, hasMasterTag: false);
    await zeige(tester);

    await tester.tap(find.text('Sperren'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kein Generalschlüssel'), findsOneWidget);
  });

  testWidgets('Bestaetigen startet die Zeitsperre', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    await tester.tap(find.text('Sperren'));
    await tester.pumpAndSettle();
    // „Sperren" steht jetzt zweimal auf dem Schirm: in der Profilzeile und im
    // Dialog. Der zuletzt gefundene liegt im Dialog.
    await tester.tap(find.text('Sperren').last);
    await tester.pumpAndSettle();

    expect(gestartetesProfil, 'p1');
  });
}
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/home_screen_test.dart
```

Erwartet: „Sperren" wird nicht gefunden.

- [ ] **Schritt 3: Startfunktion im `_HomeScreenState` ergänzen**

```dart
  /// Startet oder verlängert eine Zeitsperre. Vorher ein Dialog, der beim Namen
  /// nennt, worauf man sich einlässt — die Sperre lässt sich nicht zurücknehmen.
  Future<void> _startTimeLock(ProfileInfo profile, LockStatus status) async {
    final laufend = status.timeLockFor(profile.id);
    final ende = profile.mode == LockMode.until
        ? profile.untilAt
        : DateTime.now().add(Duration(minutes: profile.durationMinutes));

    if (ende == null || ende.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Zeitpunkt liegt in der Vergangenheit.')),
      );
      return;
    }

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(laufend == null ? 'Sperren?' : 'Verlängern?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sperrt ${profile.name} bis ${_uhrzeit(ende)}.\n'
              'Vorher öffnet nur ein Generalschlüssel oder der Notfall-Code.',
            ),
            if (!status.hasMasterTag) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Kein Generalschlüssel angelernt — dann öffnet nur der Notfall-Code.',
                style: TextStyle(color: RiegelColors.danger),
              ),
            ],
            if (!status.hasCode) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Kein Notfall-Code gesetzt.',
                style: TextStyle(color: RiegelColors.danger),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(laufend == null ? 'Sperren' : 'Verlängern'),
          ),
        ],
      ),
    );

    if (bestaetigt != true) return;

    final outcome = await widget.channel.startTimeLock(profile.id);
    if (!mounted) return;
    if (outcome == 'UNTIL_IN_PAST') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Zeitpunkt liegt in der Vergangenheit.')),
      );
    } else if (outcome == 'ALREADY_RUNNING') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Läuft bereits und endet nicht früher.')),
      );
    }
    await _refresh();
  }

  String _uhrzeit(DateTime moment) {
    final h = moment.hour.toString().padLeft(2, '0');
    final m = moment.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
```

- [ ] **Schritt 4: `_ProfileRow` um die Schaltfläche erweitern**

`_ProfileRow` ersetzen:

```dart
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.locked,
    required this.timeLock,
    required this.onTap,
    required this.onLock,
  });

  final ProfileInfo profile;
  final bool locked;
  final TimeLockInfo? timeLock;
  final VoidCallback onTap;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (profile.mode) {
      LockMode.open => 'bis Scan',
      LockMode.timer => '${profile.durationMinutes} min',
      LockMode.until => 'bis Zeitpunkt',
    };
    final zeitsperre = timeLock;
    final subtitle = zeitsperre == null
        ? '${profile.blockedPackages.length} Apps · $modeLabel'
        : '${profile.blockedPackages.length} Apps · frei ab '
              '${zeitsperre.endsAt.hour.toString().padLeft(2, '0')}:'
              '${zeitsperre.endsAt.minute.toString().padLeft(2, '0')}';

    return _NavRow(
      title: profile.name,
      subtitle: subtitle,
      enabled: !locked,
      onTap: onTap,
      trailingText: locked && profile.mode == LockMode.open ? 'sperrt' : null,
      // OPEN-Profile lassen sich nur mit dem Chip sperren — dort wäre eine
      // Schaltfläche nur ein Knopf, der nichts kann.
      action: profile.mode == LockMode.open
          ? null
          : _RowAction(
              label: zeitsperre == null ? 'Sperren' : 'Verlängern',
              onPressed: onLock,
            ),
    );
  }
}

class _RowAction {
  const _RowAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}
```

In `_NavRow` das Feld ergänzen und im `Row` vor dem `trailingText`-Zweig einsetzen:

```dart
  final _RowAction? action;
```

und im Aufbau, direkt vor `if (trailingText != null)`:

```dart
              if (action != null)
                TextButton(
                  onPressed: action!.onPressed,
                  child: Text(action!.label),
                ),
```

`_NavRow` bekommt `this.action` im Konstruktor als benannten Parameter mit
Vorgabe `null`. Der Aufruf für „Chips" bleibt dadurch unverändert.

- [ ] **Schritt 5: Aufruf im `build` anpassen**

Im `ListView` die Profilschleife ersetzen:

```dart
            for (final profile in status.profiles) ...[
              _ProfileRow(
                profile: profile,
                locked: status.isProfileLocked(profile.id),
                timeLock: status.timeLockFor(profile.id),
                onTap: () => _editProfile(profile),
                onLock: () => _startTimeLock(profile, status),
              ),
              const SizedBox(height: RiegelSpacing.s2),
            ],
```

- [ ] **Schritt 6: `_StatusTile._subtitle` anpassen**

```dart
  String _subtitle(LockStatus status) {
    if (!status.locked) return 'Chip scannen oder Profil sperren';

    final ende = status.earliestEnd;
    final anzahl = status.lockedProfileIds.length;
    if (ende == null) {
      final profil = status.profiles
          .where((p) => status.isProfileLocked(p.id))
          .map((p) => p.name)
          .join(', ');
      return '$profil — frei nach erneutem Scan';
    }

    final h = ende.hour.toString().padLeft(2, '0');
    final m = ende.minute.toString().padLeft(2, '0');
    if (anzahl > 1) return '$anzahl Sperren — frei ab $h:$m';

    final profil = status.profiles
        .where((p) => status.isProfileLocked(p.id))
        .map((p) => p.name)
        .join(', ');
    return '$profil — frei ab $h:$m';
  }
```

Der frühere Zugriff `status.activeProfile` entfällt; falls die Datei ihn noch
anderswo nutzt, entsprechend auf `lockedProfileIds` umstellen.

- [ ] **Schritt 7: Prüfen und testen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: „No issues found." und alle Tests grün.

- [ ] **Schritt 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Zeitsperre ueber die Oberflaeche starten"
```

---

### Task 12: `POST_NOTIFICATIONS` zur Laufzeit anfragen

Die Berechtigung steht seit v1 im Manifest, wird aber nie angefragt. Seit Android 13
ist sie eine Laufzeit-Berechtigung — ohne Anfrage verschwindet die Sperr-Benachrichtigung
lautlos. Auf dem Testgerät (SDK 33) fällt es nur deshalb nicht auf, weil sie dort von
Hand erteilt wurde.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/MainActivity.kt`

Ohne eigene Tests: `FlutterActivity` und `requestPermissions` laufen in reinem JUnit
nicht. Die Prüfung erfolgt von Hand über die Liste in Task 13.

- [ ] **Schritt 1: `MainActivity` ersetzen**

```kotlin
package com.klaas.nfc_riegel

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zustand nach App-Start begradigen: abgelaufener Timer wird sofort aufgelöst.
        LockController(this).expire()
        RiegelChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        requestNotificationPermission()
    }

    /**
     * Seit Android 13 muss POST_NOTIFICATIONS zur Laufzeit erteilt werden. Ohne sie
     * bleibt die Benachrichtigung während einer Sperre stumm, ohne dass irgendwo
     * ein Fehler auftaucht. Ablehnen ist erlaubt — die Sperre wirkt trotzdem, man
     * sieht sie nur nicht mehr im Schirm.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 1001
    }
}
```

Kein `onRequestPermissionsResult`: die Antwort ändert nichts am Ablauf, und der
Fehlerbericht liest den tatsächlichen Stand ohnehin über `getDiagnostics`.

- [ ] **Schritt 2: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: alle grün, 0 Fehlschläge.

- [ ] **Schritt 3: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "fix: Benachrichtigungsberechtigung zur Laufzeit anfragen"
```

---

### Task 13: Gerätetest, Bauen, Ablegen

**Files:**
- Modify: `nfc_riegel/GERAETETEST.md`
- Modify: `nfc_riegel/lib/build_info.dart`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Schritt 1: Prüfliste ergänzen**

An `GERAETETEST.md` anhängen:

```markdown
## Zeitsperren ohne Chip

- [ ] Profil auf `TIMER` mit 5 Minuten stellen, „Sperren" drücken, Dialog bestätigen
- [ ] Gesperrte App öffnen — Sperrschirm erscheint
- [ ] Normalen Chip dieses Profils scannen — Sperre bleibt bestehen, Meldung
      „Zeitsperre läuft"
- [ ] Chip eines anderen `OPEN`-Profils scannen — beide Sperren gelten gleichzeitig
- [ ] Generalschlüssel scannen — beide Sperren enden
- [ ] Erneut sperren, „Verlängern" drücken — Ende rückt nach hinten, nie nach vorn
- [ ] Profil auf `UNTIL` mit einem Zeitpunkt in der Vergangenheit stellen,
      „Sperren" drücken — Meldung statt Sperre
- [ ] Während laufender Zeitsperre: Profil öffnen — nicht bearbeitbar
- [ ] Während laufender Zeitsperre: Chips öffnen — nicht erreichbar
- [ ] Handy neu starten, während eine Zeitsperre läuft — Sperre gilt weiter,
      Benachrichtigung wieder da
- [ ] Timer ablaufen lassen — Sperre endet von selbst, Benachrichtigung verschwindet
- [ ] Ohne angelernten Generalschlüssel sperren — Dialog warnt in Rot
- [ ] Update über eine laufende v2-`UNTIL`-Sperre — sie läuft nach dem Update weiter

## Benachrichtigungsberechtigung

- [ ] App entfernen und neu installieren, beim ersten Start erscheint die Abfrage
      nach Benachrichtigungen
- [ ] Abfrage ablehnen, dann sperren — Sperre wirkt, nur die Benachrichtigung fehlt
- [ ] Fehlerbericht senden — im Zustandsblock steht „Benachrichtigungen: VERWEIGERT"
```

- [ ] **Schritt 2: Build-Nummer erhöhen**

In `lib/build_info.dart` `kBuildNumber` auf `3` setzen.
In `pubspec.yaml` `version: 1.0.0+2` auf `1.0.0+3` setzen.

- [ ] **Schritt 3: Vollständig prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test && android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: „No issues found.", alle Dart-Tests grün, alle Kotlin-Tests grün.

- [ ] **Schritt 4: Release bauen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter build apk --release
```

- [ ] **Schritt 5: Ablegen**

Laut `CLAUDE.md` gehört jede fertige APK nach `APKs\Android`.

```bash
cp "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/build/app/outputs/flutter-apk/app-release.apk" "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" && md5sum "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/build/app/outputs/flutter-apk/app-release.apk" "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

Erwartet: zwei gleiche Prüfsummen.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel && git commit -m "docs: Geraetetest um Zeitsperren ergaenzt, Build 3"
```

---

## Selbstprüfung gegen die Spec

| Spec-Abschnitt | Task |
|---|---|
| Zwei Spuren, Vereinigung | 1, 2 |
| `TimeLock`-Datenmodell, höchstens eine je Profil | 1, 3 |
| `startTimeLock` mit allen sechs Ausgängen | 3 |
| Verlängern ja, verkürzen nein | 3 |
| Kein Verlängern per Chip (`allowExtend = false`) | 3, 4 |
| Scan-Verhalten der zwei Spuren | 4 |
| Normaler Chip beendet keine Zeitsperre | 4 |
| Generalschlüssel und Code beenden alles | 4 |
| Ablauf mehrerer Zeitsperren, Alarm auf `min(endsAt)` | 2, 6 |
| Einstellungswächter mit Uhrzeit | 5 |
| Oberfläche: „Sperren"/„Verlängern", Bestätigung, Warnungen | 11 |
| Statuskachel mit Anzahl und frühester Endzeit | 11 |
| Sperrschirm nennt Profil und Ende | 7 |
| Migration v1 und v2 | 8 |
| `ChipLock` ohne Modus und Ende | 9 |
| Gerätetest-Prüfliste | 13 |

**Nicht aus der Spec, aber im selben Durchgang erledigt:** Task 12 fragt
`POST_NOTIFICATIONS` zur Laufzeit an. Die Berechtigung stand seit v1 im Manifest,
wurde aber nie angefragt — seit Android 13 bleibt die Benachrichtigung dadurch
stumm, ohne dass ein Fehler auftaucht.

**Offen und bewusst nicht in diesem Plan:** die Kalendersperre. Sie hat eine eigene
Spec und setzt diese Umsetzung voraus.

---

## Korrektionen aus der Umsetzung

- **Task 1, Schritt 1 / Task 8, Schritt 1 — falsches Trennzeichen in den Testliteralen.**
  Der Plan verwendet `'\u001F'`. `LockCodec` nutzt tatsächlich `RECORD = '\u0001'`,
  `FIELD = '\u0002'`, `ITEM = '\u0003'`. Mit `'\u001F'` prüfte der Codec-Test nur
  zufällig richtig, die v2-Migrationstests in Task 8 wären fehlgeschlagen.
  Umgesetzt mit `'\u0002'`.
- **Umgebung:** Gradle braucht `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`;
  die System-Standard-JVM ist Java 8 und Gradle bricht sonst sofort ab.
- **Task 4, Schritt 1+2 — Profile in `LockEngineToggleTest` vertauscht.** Der Plan
  sagt „`arbeit` (id `p1`, `OPEN`), `nacht` (id `p2`)". Tatsächlich ist `arbeit`
  (p1) `TIMER` mit 30 Minuten und `nacht` (p2) `OPEN`. Alle neuen Tests wurden
  entsprechend umgehängt: Chipsperren-Fälle laufen über `chipNacht`/`04BB`/`p2`,
  Zeitsperren-Fälle über `chipArbeit`/`04AA`/`p1`.
- **Task 4, Schritt 2 — drei statt zwei bestehende Tests betroffen.** Der Plan nennt
  nur die beiden Tests um Zeile 107 und 117. Zusätzlich brachen
  `Chip sperrt mit dem Modus seines Profils` (Chipsperre wird zur Zeitsperre, jetzt
  umbenannt in `Chip mit TIMER-Profil startet eine Zeitsperre statt einer Chipsperre`)
  und `Generalschluessel sperrt mit eigenem Profil wenn nichts laeuft` (der
  Generalschlüssel zeigt auf das TIMER-Profil `p1`). Außerdem ging der Plan-Fix für
  `derselbe Chip gibt wieder frei` nicht auf: Freigeben per Scan gibt es nur noch bei
  `OPEN`-Profilen, der Test scannt daher jetzt `04BB` (Profil `p2`).
- **Task 7, Schritt 7 — `NfcToggleActivity` war schon fertig.** Die Zielfassung stand
  bereits im Baum: Task 4 hatte sie mitziehen müssen, weil das `when` über
  `ScanOutcome` erschöpfend sein muss und dort zwei Werte hinzukamen. Schritt 7 ist
  ein Leerlauf.
- **Task 7, Schritt 1+3 — zwei bestehende `DiagnosticsTest`-Tests brechen.** Der Plan
  nennt nur die drei neuen Tests. Tatsächlich schreiben zwei vorhandene das alte
  Verhalten fest und scheitern an der neuen `summarize`-Fassung:
  `laufende Sperre nennt Profil und Ende` baute `ChipLock("p1", LockMode.TIMER, …)`
  und erwartete „TIMER" im Text — eine Chipsperre hat im Bericht keinen Modus mehr;
  umbenannt in `Chipsperre nennt das Profil`, prüft jetzt nur den Profilnamen.
  `abgelaufene Sperre gilt als offen` prüfte den Ablauf einer Chipsperre — die läuft
  nicht mehr ab; gelöscht, Nachfolger ist der neue Test
  `abgelaufene Zeitsperre gilt als offen`. `DiagnosticsTest` hat danach 10 Tests,
  nicht die vom Plan implizierten 11.
- **Task 7 in zwei Commits umgesetzt**, weil sie sechs Dateien und zwei verschiedene
  Arten von Arbeit umfasst: `feat: Diagnosebericht kennt beide Sperrspuren` (Bericht
  samt Tests) und `feat: Android-Raender kennen beide Sperrspuren` (Kanal, Controller,
  Sperrschirm, Deinstallationsschutz).
- **Task 8, Schritt 1 — ein bestehender `LockCodecTest`-Test bricht.** Der Plan nennt
  ihn nicht: `Chipsperre ueberstehen Kodieren und Dekodieren` baute
  `ChipLock("p1", LockMode.UNTIL, 1_700_000_000_000)` und erwartete Modus und Ende
  nach dem Rundlauf zurück. Das v3-Format schreibt nur noch die Profil-Kennung und
  kann das nicht mehr liefern. Auf `ChipLock("p1")` umgestellt und in
  `Chipsperre uebersteht Kodieren und Dekodieren` umbenannt.
- **Task 9, Schritt 4 — die inhaltlich betroffenen Tests im Einzelnen.** Der Plan
  nennt nur Muster. Konkret waren neben den rein mechanischen Streichungen des
  `LockMode.OPEN`-Arguments drei Stellen inhaltlich zu ändern:
  `LockEngineBlockTest.abgelaufene Sperre blockt nicht mehr` →
  `abgelaufene Zeitsperre blockt nicht mehr` über `engineMitZeitsperren`;
  `LockEngineToggleTest.Profil im Modus OPEN sperrt ohne Ende` →
  `Profil im Modus OPEN erzeugt eine Chipsperre`, prüft statt `mode`/`endsAt` jetzt
  die `profileId`; und in `anderer Chip uebernimmt mit seinem Profil` entfiel die
  Zusicherung auf `chipLock!!.mode`.
- **Task 10/11 — der Plan-Code löst einen Analyzer-Hinweis aus.** `lockedProfileIds`
  in der Fassung `{ if (chipLockProfileId != null) chipLockProfileId!, … }` meldet
  `use_null_aware_elements`. `flutter analyze` hätte damit nach Task 11 nicht
  „No issues found!" gemeldet, was Schritt 7 aber verlangt. In Task 11 auf die
  null-aware-Element-Schreibweise `?chipLockProfileId` umgestellt.
- **Tatsächliche Testzahlen dieses Durchgangs:** vor Task 6 107 Kotlin-Tests, nach
  Task 9 113 (Task 7 netto +2, Task 8 netto +4); Tasks 6, 9 und 12 ändern die Zahl
  nicht. Dart: vor Task 10 8 Tests, nach Task 11 15.
