# Riegel v2 — Profile, mehrere Chips, Sperre bis Zeitpunkt: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aus dem einen Profil und dem einen Chip der v1 werden beliebig viele Profile und Chips, dazu ein dritter Sperr-Modus mit absolutem Ende.

**Architecture:** Der Zustand wird umgebaut: `LockState` hält künftig eine Profilliste, eine Chipliste und höchstens eine aktive Chipsperre. Die gesamte Logik bleibt in `LockEngine` — reines Kotlin hinter `LockStore`, ohne Android. Serialisierung läuft über einen eigenen `LockCodec` statt über `org.json`, damit sie ohne Emulator testbar bleibt. Ein bestehender v1-Zustand wird beim ersten Lesen einmalig migriert.

**Tech Stack:** Kotlin (JVM 17), JUnit 4.13.2, Flutter 3.44 / Dart 3.12.

**Spec:** `docs/superpowers/specs/2026-08-04-riegel-profile-chips-design.md`

**Projekt:** `C:\Users\klaas\Desktop\Programmieren\nfc_riegel`
**Branch:** `feature/nfc-riegel`

---

## Prüf-Kommandos

Alle aus `C:\Users\klaas\Desktop\Programmieren\nfc_riegel`.

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
```

| Zweck | Kommando |
|---|---|
| Kotlin-Tests | `android/gradlew.bat -p android testDebugUnitTest` |
| Kotlin kompilieren | `android/gradlew.bat -p android compileDebugKotlin` |
| Dart-Analyse | `flutter analyze` |
| Dart-Tests | `flutter test` |

Auf `PATH` liegt Java 8, Gradle braucht 17 — `JAVA_HOME` in jeder Sitzung setzen.
Die JUnit-XMLs liegen unter `build/app/test-results/testDebugUnitTest/`.

**Ausgangslage:** 39 Kotlin-Tests, 6 Dart-Tests, alle grün.

---

## Dateistruktur

**Neu**

| Datei | Verantwortung |
|---|---|
| `.../nfc_riegel/Profile.kt` | Datenklassen `Profile`, `TagBinding`, `ChipLock` |
| `.../nfc_riegel/LockCodec.kt` | Listen ⇄ String für SharedPreferences, reines Kotlin |
| `.../nfc_riegel/LockMigration.kt` | v1-Zustand → v2-Zustand, reine Funktion |
| `lib/profile_screen.dart` | Profil anlegen und bearbeiten |
| `lib/tags_screen.dart` | Chips verwalten und anlernen |

**Geändert**

| Datei | Was |
|---|---|
| `LockState.kt` | Neue Felder, `LockMode.UNTIL` |
| `LockEngine.kt` | Scan mit Chipliste, Profil-CRUD, `UNTIL` |
| `SharedPrefsLockStore.kt` | Neues Format plus Migration |
| `LockController.kt` | Nebenwirkungen auf die aktive Chipsperre beziehen |
| `BlockActivity.kt` | Profilname anzeigen |
| `BlockerService.kt` | `isBlocked` mit Zeitstempel |
| `TagWriteActivity.kt` | Label, Profil und Generalschlüssel aus dem Intent |
| `RiegelChannel.kt` | Neue Methoden |
| `lib/lock_status.dart` | Profile, Chips, aktive Sperre |
| `lib/riegel_channel.dart` | Neue Methoden |
| `lib/home_screen.dart` | Profilliste, Statuskachel mit Profilnamen |
| `lib/setup_wizard.dart` | Chip-Anlernen mit Label und Profil |
| `GERAETETEST.md` | Neue Punkte |

---

### Task 1: Datenklassen

**Files:**
- Create: `android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`

- [ ] **Step 1: Profile.kt schreiben**

```kotlin
package com.klaas.nfc_riegel

/** Was gesperrt wird. Mindestens eines existiert immer. */
data class Profile(
    val id: String,
    val name: String,
    val blockedPackages: Set<String> = emptySet(),
    val defaultMode: LockMode = LockMode.TIMER,
    val durationMinutes: Int = 60,
    /** Absolutes Ende für [LockMode.UNTIL]. */
    val untilAt: Long? = null,
    /**
     * Nur für die Kalender-Spec: hält das Ende eines Terminfensters fest, damit
     * Löschen des Termins die Sperre nicht abkürzt. Hier mitgeführt, damit das
     * Modell später nicht wandern muss.
     */
    val pinCalendarEnd: Boolean = false,
)

/** Womit gesperrt wird. Jeder Chip hat ein Profil — auch ein Generalschlüssel. */
data class TagBinding(
    val uid: String,
    val label: String,
    val profileId: String,
    /** Beendet jede laufende Sperre, auch Kalendersperren. */
    val isMaster: Boolean = false,
)

/** Die eine aktive Chipsperre. Höchstens eine gleichzeitig. */
data class ChipLock(
    val profileId: String,
    val mode: LockMode,
    /** Bei TIMER und UNTIL gesetzt, bei OPEN null. */
    val endsAt: Long? = null,
)
```

- [ ] **Step 2: LockState.kt ersetzen**

```kotlin
package com.klaas.nfc_riegel

/**
 * OPEN = bis erneuter Scan, TIMER = für eine Dauer, UNTIL = bis zu einem
 * absoluten Zeitpunkt. TIMER und UNTIL enden beide auch durch erneuten Scan.
 */
enum class LockMode { OPEN, TIMER, UNTIL }

/**
 * Vollständiger Zustand des Riegels. Reine Daten, keine Android-Abhängigkeit —
 * damit die Logik in [LockEngine] ohne Emulator testbar bleibt.
 */
data class LockState(
    val profiles: List<Profile> = emptyList(),
    val tags: List<TagBinding> = emptyList(),
    val chipLock: ChipLock? = null,
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
) {
    fun profileById(id: String): Profile? = profiles.firstOrNull { it.id == id }

    fun tagByUid(uid: String): TagBinding? =
        tags.firstOrNull { it.uid.equals(uid, ignoreCase = true) }
}
```

- [ ] **Step 3: Kompilierung wird jetzt fehlschlagen — das ist erwartet**

`LockEngine`, `SharedPrefsLockStore` und die Tests greifen noch auf die alten Felder zu. Die Aufräumarbeit passiert in Task 2 bis 5. Kein Prüf-Kommando in diesem Task.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel
git commit -m "feat: Datenklassen fuer Profile, Chips und Chipsperre"
```

---

### Task 2: LockEngine — Sperren und Freigeben mit Profilen

Ersetzt das alte `onTagScanned` vollständig.

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt` (ersetzen)

- [ ] **Step 1: Alten Test ersetzen**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt` vollständig ersetzen durch:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LockEngineToggleTest {

    private val now = 1_000_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 30,
    )
    private val nacht = Profile(
        id = "p2",
        name = "Nacht",
        blockedPackages = setOf("com.zhiliaoapp.musically"),
        defaultMode = LockMode.OPEN,
    )

    private val chipArbeit = TagBinding("04AA", "Schreibtisch", "p1")
    private val chipNacht = TagBinding("04BB", "Bett", "p2")
    private val general = TagBinding("04CC", "Schlüsselbund", "p1", isMaster = true)

    private fun engine(
        chipLock: ChipLock? = null,
        tags: List<TagBinding> = listOf(chipArbeit, chipNacht, general),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(profiles = listOf(arbeit, nacht), tags = tags, chipLock = chipLock)
        )
        return LockEngine(store) to store
    }

    @Test
    fun `unbekannte UID aendert nichts`() {
        val (e, store) = engine()

        val result = e.onTagScanned("DEADBEEF", now)

        assertEquals(ScanOutcome.UNKNOWN_TAG, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `ohne angelernte Chips meldet die Engine NO_TAG_ENROLLED`() {
        val (e, _) = engine(tags = emptyList())

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.NO_TAG_ENROLLED, result.outcome)
    }

    @Test
    fun `Chip sperrt mit dem Modus seines Profils`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        val lock = store.current.chipLock
        assertNotNull(lock)
        assertEquals("p1", lock!!.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(now + 30 * 60_000L, lock.endsAt)
    }

    @Test
    fun `Profil im Modus OPEN sperrt ohne Ende`() {
        val (e, store) = engine()

        e.onTagScanned("04BB", now)

        assertEquals(LockMode.OPEN, store.current.chipLock!!.mode)
        assertNull(store.current.chipLock!!.endsAt)
    }

    @Test
    fun `derselbe Chip gibt wieder frei`() {
        val (e, store) = engine(chipLock = ChipLock("p1", LockMode.TIMER, now + 5000))

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `anderer Chip uebernimmt mit seinem Profil`() {
        val (e, store) = engine(chipLock = ChipLock("p1", LockMode.TIMER, now + 5000))

        val result = e.onTagScanned("04BB", now)

        assertEquals(ScanOutcome.SWITCHED, result.outcome)
        assertEquals("p2", store.current.chipLock!!.profileId)
        assertEquals(LockMode.OPEN, store.current.chipLock!!.mode)
    }

    @Test
    fun `Generalschluessel beendet eine laufende Sperre`() {
        val (e, store) = engine(chipLock = ChipLock("p2", LockMode.OPEN))

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.MASTER_CLEARED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `Generalschluessel sperrt mit eigenem Profil wenn nichts laeuft`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertEquals("p1", store.current.chipLock!!.profileId)
    }

    @Test
    fun `UID-Vergleich ignoriert Gross- und Kleinschreibung`() {
        val (e, _) = engine()

        assertEquals(ScanOutcome.LOCKED, e.onTagScanned("04aa", now).outcome)
    }

    @Test
    fun `Chip mit geloeschtem Profil sperrt nicht`() {
        val store = FakeLockStore(
            LockState(profiles = listOf(nacht), tags = listOf(chipArbeit))
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.NO_PROFILE, result.outcome)
        assertNull(store.current.chipLock)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineToggleTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: SWITCHED`.

- [ ] **Step 3: LockEngine-Kopf und Scan-Logik ersetzen**

In `LockEngine.kt` die Zeilen 1 bis 29 (Enums, `ScanResult`, Klassenkopf, `state`, `onTagScanned`) ersetzen durch:

```kotlin
package com.klaas.nfc_riegel

enum class ScanOutcome {
    LOCKED,
    UNLOCKED,
    /** Anderer Chip hat übernommen: alte Sperre beendet, neue gestartet. */
    SWITCHED,
    /** Generalschlüssel hat alle Sperren beendet. */
    MASTER_CLEARED,
    UNKNOWN_TAG,
    NO_TAG_ENROLLED,
    /** Chip zeigt auf ein Profil, das es nicht mehr gibt. */
    NO_PROFILE,
    /** UNTIL-Zeitpunkt liegt in der Vergangenheit. */
    UNTIL_IN_PAST,
}

data class ScanResult(val state: LockState, val outcome: ScanOutcome)

enum class CodeOutcome { UNLOCKED, WRONG, LOCKED_OUT, NOT_SET }

data class CodeResult(val state: LockState, val outcome: CodeOutcome)

/**
 * Alle Zustandsübergänge des Riegels. Kennt nur [LockStore] — keine Android-Klassen,
 * keine Nebenwirkungen. Alarm und Benachrichtigung setzt [LockController] anhand des
 * zurückgegebenen Zustands.
 */
class LockEngine(private val store: LockStore) {

    fun state(): LockState = store.load()

    /**
     * Chip gescannt. Ein normaler Chip schaltet nur sein eigenes Profil; ein
     * Generalschlüssel beendet jede laufende Sperre.
     */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        if (s.tags.isEmpty()) return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        val tag = s.tagByUid(uid) ?: return ScanResult(s, ScanOutcome.UNKNOWN_TAG)

        val active = activeChipLock(s, now)

        if (tag.isMaster && active != null) {
            return ScanResult(clearLocks(s), ScanOutcome.MASTER_CLEARED)
        }

        val profile = s.profileById(tag.profileId)
            ?: return ScanResult(s, ScanOutcome.NO_PROFILE)

        if (active != null && active.profileId == profile.id) {
            return ScanResult(clearLocks(s), ScanOutcome.UNLOCKED)
        }

        val endsAt = when (profile.defaultMode) {
            LockMode.OPEN -> null
            LockMode.TIMER -> now + profile.durationMinutes * 60_000L
            LockMode.UNTIL -> {
                val until = profile.untilAt
                if (until == null || until <= now) {
                    return ScanResult(s, ScanOutcome.UNTIL_IN_PAST)
                }
                until
            }
        }

        val next = s.copy(chipLock = ChipLock(profile.id, profile.defaultMode, endsAt))
        store.save(next)
        return ScanResult(
            next,
            if (active != null) ScanOutcome.SWITCHED else ScanOutcome.LOCKED,
        )
    }

    /** Die Chipsperre, sofern sie jetzt noch gilt. Abgelaufene zählen nicht. */
    private fun activeChipLock(s: LockState, now: Long): ChipLock? {
        val lock = s.chipLock ?: return null
        val endsAt = lock.endsAt ?: return lock
        return if (now >= endsAt) null else lock
    }

    private fun clearLocks(s: LockState): LockState {
        val next = s.copy(chipLock = null, failedAttempts = 0, codeLockedUntil = null)
        store.save(next)
        return next
    }
```

- [ ] **Step 4: Alte private Helfer entfernen**

Am Ende von `LockEngine.kt` die Methoden `lock` und `unlock` ersatzlos löschen — ihre Aufgabe übernehmen `onTagScanned` und `clearLocks`.

- [ ] **Step 5: Test laufen lassen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineToggleTest*"
```

Erwartet: die 11 Tests dieser Datei laufen. Andere Testdateien sind noch rot — die kommen in Task 3 und 4.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Scan-Logik mit mehreren Chips und Profilen"
```

---

### Task 3: LockEngine — Ablauf, Boot, Blockliste, Notfall-Code

Die verbliebenen Methoden auf das neue Modell umstellen.

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineTimerTest.kt` (ersetzen)
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineBlockTest.kt` (ersetzen)
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCodeTest.kt` (anpassen)

- [ ] **Step 1: LockEngineTimerTest.kt ersetzen**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L
    private val profil = Profile(id = "p1", name = "Arbeit")

    private fun engine(lock: ChipLock?): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(LockState(profiles = listOf(profil), chipLock = lock))
        return LockEngine(store) to store
    }

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now - 1))

        e.onTimerElapsed(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `laufender Timer bleibt bestehen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now + 60_000))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `abgelaufener UNTIL-Zeitpunkt gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now - 1))

        e.onTimerElapsed(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `kuenftiger UNTIL-Zeitpunkt bleibt bestehen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now + 10_000))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Modus OPEN wird vom Ablauf nicht beruehrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        e.onTimerElapsed(now)

        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit abgelaufenem Ende gibt frei`() {
        val (e, store) = engine(ChipLock("p1", LockMode.TIMER, now - 10_000))

        e.restoreAfterBoot(now)

        assertNull(store.current.chipLock)
    }

    @Test
    fun `Boot mit laufendem Ende bleibt gesperrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.UNTIL, now + 10_000))

        e.restoreAfterBoot(now)

        assertEquals(now + 10_000, store.current.chipLock!!.endsAt)
    }

    @Test
    fun `Boot im Modus OPEN bleibt gesperrt`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        e.restoreAfterBoot(now)

        assertNotNull(store.current.chipLock)
    }
}
```

- [ ] **Step 2: LockEngineBlockTest.kt ersetzen**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineBlockTest {

    private val now = 1_000_000L
    private val arbeit = Profile("p1", "Arbeit", setOf("com.instagram.android"))
    private val nacht = Profile("p2", "Nacht", setOf("com.zhiliaoapp.musically"))

    private fun engine(lock: ChipLock?): LockEngine =
        LockEngine(FakeLockStore(LockState(profiles = listOf(arbeit, nacht), chipLock = lock)))

    @Test
    fun `App des sperrenden Profils wird geblockt`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `App eines anderen Profils wird nicht geblockt`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertFalse(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `ohne Sperre wird nichts geblockt`() {
        val e = engine(null)

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `abgelaufene Sperre blockt nicht mehr`() {
        val e = engine(ChipLock("p1", LockMode.TIMER, now - 1))

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `blockedPackages liefert die Vereinigung der aktiven Sperren`() {
        val e = engine(ChipLock("p1", LockMode.OPEN))

        assertEquals(setOf("com.instagram.android"), e.blockedPackages(now))
    }
}
```

- [ ] **Step 3: LockEngineCodeTest.kt anpassen**

In `LockEngineCodeTest.kt` die Hilfsmethode `lockedEngine` ersetzen durch:

```kotlin
    private fun lockedEngine(
        failedAttempts: Int = 0,
        codeLockedUntil: Long? = null,
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(Profile("p1", "Arbeit")),
                chipLock = ChipLock("p1", LockMode.OPEN),
                codeHash = Hashing.sha256(code),
                failedAttempts = failedAttempts,
                codeLockedUntil = codeLockedUntil,
            )
        )
        return LockEngine(store) to store
    }
```

Im Test `ohne hinterlegten Code meldet die Engine NOT_SET` den Store ersetzen durch:

```kotlin
        val store = FakeLockStore(
            LockState(
                profiles = listOf(Profile("p1", "Arbeit")),
                chipLock = ChipLock("p1", LockMode.OPEN),
                codeHash = null,
            )
        )
```

Und in allen Tests dieser Datei die Prüfungen auf `state.locked` bzw. `store.current.locked` ersetzen: `assertFalse(...locked)` wird zu `assertNull(...chipLock)`, `assertTrue(...locked)` wird zu `assertNotNull(...chipLock)`. Import `assertNull` und `assertNotNull` ergänzen, `assertFalse`/`assertTrue` bleiben für die übrigen Stellen.

- [ ] **Step 4: Tests laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineTimerTest*" --tests "*LockEngineBlockTest*"
```

Erwartet: Kompilierfehler, `Too many arguments for isBlocked` oder `Unresolved reference: blockedPackages`.

- [ ] **Step 5: Methoden in LockEngine ersetzen**

In `LockEngine.kt` die Methoden `onTimerElapsed`, `restoreAfterBoot` und `isBlocked` ersetzen durch:

```kotlin
    /**
     * Vom Alarm gerufen. Gibt frei, wenn das Ende erreicht ist — sonst nichts.
     * Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val lock = s.chipLock ?: return s
        val endsAt = lock.endsAt ?: return s
        return if (now >= endsAt) clearLocks(s) else s
    }

    /**
     * Nach dem Neustart. OPEN bleibt gesperrt; bei TIMER und UNTIL entscheidet
     * das gespeicherte Ende.
     */
    fun restoreAfterBoot(now: Long): LockState = onTimerElapsed(now)

    /** Vom AccessibilityService bei jedem Fensterwechsel gefragt. */
    fun isBlocked(packageName: String, now: Long): Boolean =
        packageName in blockedPackages(now)

    /**
     * Vereinigung aller aktiven Sperren. Aktuell nur die Chipsperre — die
     * Kalendersperre kommt in einer eigenen Ausbaustufe dazu.
     */
    fun blockedPackages(now: Long): Set<String> {
        val s = store.load()
        val lock = activeChipLock(s, now) ?: return emptySet()
        return s.profileById(lock.profileId)?.blockedPackages ?: emptySet()
    }
```

Im `submitCode` den Aufruf `unlock(s)` ersetzen durch `clearLocks(s)`.

- [ ] **Step 6: Tests laufen lassen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngine*"
```

Erwartet: `LockEngineToggleTest` 11, `LockEngineTimerTest` 8, `LockEngineBlockTest` 5, `LockEngineCodeTest` 7 grün. `LockEngineSettingsTest` ist noch rot — Task 4.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Ablauf, Boot und Blockliste auf Profile umgestellt"
```

---

### Task 4: LockEngine — Profile und Chips verwalten

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineSettingsTest.kt` (ersetzen)

- [ ] **Step 1: LockEngineSettingsTest.kt ersetzen**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineSettingsTest {

    private val arbeit = Profile("p1", "Arbeit", setOf("com.a"))
    private val nacht = Profile("p2", "Nacht", setOf("com.b"))

    private fun engine(lock: ChipLock? = null): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = lock,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `Profil anlegen haengt es hinten an`() {
        val (e, store) = engine()

        val created = e.addProfile("Lernen")

        assertEquals(3, store.current.profiles.size)
        assertEquals("Lernen", store.current.profiles.last().name)
        assertNotNull(created)
    }

    @Test
    fun `Profil bearbeiten speichert`() {
        val (e, store) = engine()

        val ok = e.updateProfile(arbeit.copy(name = "Fokus", durationMinutes = 90))

        assertTrue(ok)
        assertEquals("Fokus", store.current.profileById("p1")!!.name)
        assertEquals(90, store.current.profileById("p1")!!.durationMinutes)
    }

    @Test
    fun `sperrendes Profil ist nicht bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        val ok = e.updateProfile(arbeit.copy(name = "Fokus"))

        assertFalse(ok)
        assertEquals("Arbeit", store.current.profileById("p1")!!.name)
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Sperre bearbeitbar`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        val ok = e.updateProfile(nacht.copy(name = "Schlaf"))

        assertTrue(ok)
        assertEquals("Schlaf", store.current.profileById("p2")!!.name)
    }

    @Test
    fun `Profil loeschen zieht zugeordnete Chips auf das erste verbleibende`() {
        val (e, store) = engine()

        val ok = e.deleteProfile("p1")

        assertTrue(ok)
        assertNull(store.current.profileById("p1"))
        assertEquals("p2", store.current.tags.first().profileId)
    }

    @Test
    fun `letztes Profil laesst sich nicht loeschen`() {
        val store = FakeLockStore(LockState(profiles = listOf(arbeit)))
        val e = LockEngine(store)

        assertFalse(e.deleteProfile("p1"))
        assertEquals(1, store.current.profiles.size)
    }

    @Test
    fun `sperrendes Profil laesst sich nicht loeschen`() {
        val (e, store) = engine(ChipLock("p1", LockMode.OPEN))

        assertFalse(e.deleteProfile("p1"))
        assertNotNull(store.current.profileById("p1"))
    }

    @Test
    fun `Chip anlernen haengt ihn an`() {
        val (e, store) = engine()

        val ok = e.enrollTag("04BB", "Bett", "p2", isMaster = false)

        assertTrue(ok)
        assertEquals(2, store.current.tags.size)
    }

    @Test
    fun `bekannte UID wird aktualisiert statt doppelt angelegt`() {
        val (e, store) = engine()

        e.enrollTag("04aa", "Neu", "p2", isMaster = true)

        assertEquals(1, store.current.tags.size)
        assertEquals("Neu", store.current.tags.first().label)
        assertEquals("p2", store.current.tags.first().profileId)
        assertTrue(store.current.tags.first().isMaster)
    }

    @Test
    fun `Chips sind waehrend einer Sperre gesperrt`() {
        val (e, store) = engine(ChipLock("p2", LockMode.OPEN))

        assertFalse(e.enrollTag("04BB", "Bett", "p1", isMaster = false))
        assertFalse(e.deleteTag("04AA"))
        assertEquals(1, store.current.tags.size)
    }

    @Test
    fun `Chip loeschen entfernt ihn`() {
        val (e, store) = engine()

        assertTrue(e.deleteTag("04AA"))
        assertTrue(store.current.tags.isEmpty())
    }

    @Test
    fun `Code erzeugen liefert acht Zeichen und speichert nur den Hash`() {
        val (e, store) = engine()

        val code = e.generateCode()

        assertNotNull(code)
        assertEquals(8, code!!.length)
        assertEquals(Hashing.sha256(code), store.current.codeHash)
    }

    @Test
    fun `Code laesst sich waehrend einer Sperre nicht neu erzeugen`() {
        val (e, _) = engine(ChipLock("p1", LockMode.OPEN))

        assertNull(e.generateCode())
    }

    @Test
    fun `erzeugter Code enthaelt nur erlaubte Zeichen`() {
        val (e, _) = engine()

        assertTrue(e.generateCode()!!.all { it in LockEngine.CODE_ALPHABET })
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineSettingsTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: addProfile`.

- [ ] **Step 3: Verwaltungsmethoden ersetzen**

In `LockEngine.kt` die Methoden `setBlockedPackages`, `setMode`, `enrollTag` und `generateCode` ersetzen durch:

```kotlin
    /** Legt ein Profil an und gibt es zurück. Immer erlaubt. */
    fun addProfile(name: String): Profile {
        val s = store.load()
        val profile = Profile(id = newId(), name = name)
        store.save(s.copy(profiles = s.profiles + profile))
        return profile
    }

    /**
     * Speichert ein geändertes Profil. Abgelehnt, solange genau dieses Profil
     * sperrt — andere Profile bleiben bearbeitbar.
     */
    fun updateProfile(profile: Profile): Boolean {
        val s = store.load()
        if (s.chipLock?.profileId == profile.id) return false
        if (s.profileById(profile.id) == null) return false
        store.save(s.copy(profiles = s.profiles.map { if (it.id == profile.id) profile else it }))
        return true
    }

    /**
     * Löscht ein Profil. Das letzte bleibt bestehen, ein sperrendes ebenfalls.
     * Zugeordnete Chips ziehen auf das erste verbleibende Profil.
     */
    fun deleteProfile(id: String): Boolean {
        val s = store.load()
        if (s.profiles.size <= 1) return false
        if (s.chipLock?.profileId == id) return false
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
     * Chip anlernen oder einen bekannten aktualisieren. Während einer Sperre
     * abgelehnt — sonst legte man sich mitten in der Sperre einen neuen Schlüssel an.
     */
    fun enrollTag(uid: String, label: String, profileId: String, isMaster: Boolean): Boolean {
        val s = store.load()
        if (s.chipLock != null) return false
        val binding = TagBinding(uid, label, profileId, isMaster)
        val existing = s.tagByUid(uid)
        val tags = if (existing == null) s.tags + binding
        else s.tags.map { if (it.uid.equals(uid, ignoreCase = true)) binding else it }
        store.save(s.copy(tags = tags))
        return true
    }

    fun deleteTag(uid: String): Boolean {
        val s = store.load()
        if (s.chipLock != null) return false
        store.save(s.copy(tags = s.tags.filterNot { it.uid.equals(uid, ignoreCase = true) }))
        return true
    }

    /**
     * Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig
     * zurück. Während einer Sperre nicht möglich — sonst wäre der Notausgang
     * jederzeit neu ausstellbar.
     */
    fun generateCode(): String? {
        val s = store.load()
        if (s.chipLock != null) return null
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(s.copy(codeHash = Hashing.sha256(code)))
        return code
    }

    private fun newId(): String =
        System.currentTimeMillis().toString(36) + (0..999).random().toString(36)
```

- [ ] **Step 4: Alle Kotlin-Tests laufen lassen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngine*" --tests "*Hashing*" --tests "*SettingsGuard*" --tests "*NfcSupport*"
```

Erwartet: `LockEngineSettingsTest` 14 Tests grün, die übrigen wie zuvor.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Profile und Chips verwalten in LockEngine"
```

---

### Task 5: Serialisierung und Migration

**Files:**
- Create: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Create: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockMigration.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockMigrationTest.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`

- [ ] **Step 1: Failing Tests schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LockCodecTest {

    @Test
    fun `Profile ueberstehen Kodieren und Dekodieren`() {
        val profiles = listOf(
            Profile("p1", "Arbeit", setOf("com.a", "com.b"), LockMode.TIMER, 45, null, false),
            Profile("p2", "Nacht", emptySet(), LockMode.UNTIL, 60, 1_700_000_000_000, true),
        )

        val decoded = LockCodec.decodeProfiles(LockCodec.encodeProfiles(profiles))

        assertEquals(profiles, decoded)
    }

    @Test
    fun `Chips ueberstehen Kodieren und Dekodieren`() {
        val tags = listOf(
            TagBinding("04AA", "Schreibtisch", "p1", false),
            TagBinding("04BB", "Schlüsselbund", "p2", true),
        )

        assertEquals(tags, LockCodec.decodeTags(LockCodec.encodeTags(tags)))
    }

    @Test
    fun `leere Liste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeProfiles(emptyList()))
        assertTrue(LockCodec.decodeProfiles("").isEmpty())
        assertTrue(LockCodec.decodeTags("").isEmpty())
    }

    @Test
    fun `Chipsperre ueberstehen Kodieren und Dekodieren`() {
        val lock = ChipLock("p1", LockMode.UNTIL, 1_700_000_000_000)

        assertEquals(lock, LockCodec.decodeChipLock(LockCodec.encodeChipLock(lock)))
    }

    @Test
    fun `null-Chipsperre bleibt null`() {
        assertEquals(null, LockCodec.decodeChipLock(LockCodec.encodeChipLock(null)))
    }

    @Test
    fun `kaputte Eingabe ergibt leere Liste statt Absturz`() {
        assertTrue(LockCodec.decodeProfiles("völliger Unsinn").isEmpty())
    }
}
```

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockMigrationTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockMigrationTest {

    @Test
    fun `v1-Zustand ergibt ein Profil namens Standard`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.TIMER,
            endsAt = null,
            durationMinutes = 90,
            blockedPackages = setOf("com.a"),
            tagUid = null,
            codeHash = "abc",
        )

        assertEquals(1, state.profiles.size)
        val profile = state.profiles.first()
        assertEquals("Standard", profile.name)
        assertEquals(setOf("com.a"), profile.blockedPackages)
        assertEquals(90, profile.durationMinutes)
        assertEquals("abc", state.codeHash)
    }

    @Test
    fun `bestehender Chip wird Generalschluessel`() {
        val state = LockMigration.fromV1(
            locked = false,
            mode = LockMode.OPEN,
            endsAt = null,
            durationMinutes = 60,
            blockedPackages = emptySet(),
            tagUid = "04AA",
            codeHash = null,
        )

        assertEquals(1, state.tags.size)
        val tag = state.tags.first()
        assertEquals("04AA", tag.uid)
        assertEquals("Chip 1", tag.label)
        assertTrue(tag.isMaster)
        assertEquals(state.profiles.first().id, tag.profileId)
    }

    @Test
    fun `ohne Chip bleibt die Liste leer`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = null,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertTrue(state.tags.isEmpty())
    }

    @Test
    fun `laufende Sperre wird uebernommen`() {
        val state = LockMigration.fromV1(
            locked = true, mode = LockMode.TIMER, endsAt = 1_700_000_000_000,
            durationMinutes = 60, blockedPackages = setOf("com.a"),
            tagUid = "04AA", codeHash = null,
        )

        val lock = state.chipLock!!
        assertEquals(state.profiles.first().id, lock.profileId)
        assertEquals(LockMode.TIMER, lock.mode)
        assertEquals(1_700_000_000_000, lock.endsAt)
    }

    @Test
    fun `ohne laufende Sperre bleibt chipLock null`() {
        val state = LockMigration.fromV1(
            locked = false, mode = LockMode.TIMER, endsAt = 123,
            durationMinutes = 60, blockedPackages = emptySet(),
            tagUid = null, codeHash = null,
        )

        assertNull(state.chipLock)
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockCodecTest*" --tests "*LockMigrationTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: LockCodec`.

- [ ] **Step 3: LockCodec schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`:

```kotlin
package com.klaas.nfc_riegel

/**
 * Listen ⇄ String für SharedPreferences. Bewusst kein `org.json`: das steckt im
 * Android-SDK und wäre in reinen JUnit-Tests nicht verfügbar. Getrennt wird mit
 * Steuerzeichen, die in Paketnamen und Labels nicht vorkommen.
 */
object LockCodec {

    private const val RECORD = '\u0001'
    private const val FIELD = '\u0002'
    private const val ITEM = '\u0003'

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
            ).joinToString(FIELD.toString())
        }

    fun decodeProfiles(raw: String): List<Profile> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 7) return@mapNotNull null
            Profile(
                id = f[0],
                name = f[1],
                blockedPackages = if (f[2].isEmpty()) emptySet() else f[2].split(ITEM).toSet(),
                defaultMode = runCatching { LockMode.valueOf(f[3]) }.getOrDefault(LockMode.TIMER),
                durationMinutes = f[4].toIntOrNull() ?: 60,
                untilAt = f[5].toLongOrNull(),
                pinCalendarEnd = f[6] == "1",
            )
        }
    }

    fun encodeTags(tags: List<TagBinding>): String =
        tags.joinToString(RECORD.toString()) { t ->
            listOf(t.uid, t.label, t.profileId, if (t.isMaster) "1" else "0")
                .joinToString(FIELD.toString())
        }

    fun decodeTags(raw: String): List<TagBinding> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 4) return@mapNotNull null
            TagBinding(uid = f[0], label = f[1], profileId = f[2], isMaster = f[3] == "1")
        }
    }

    fun encodeChipLock(lock: ChipLock?): String =
        if (lock == null) ""
        else listOf(lock.profileId, lock.mode.name, lock.endsAt?.toString() ?: "")
            .joinToString(FIELD.toString())

    fun decodeChipLock(raw: String): ChipLock? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size != 3) return null
        return ChipLock(
            profileId = f[0],
            mode = runCatching { LockMode.valueOf(f[1]) }.getOrNull() ?: return null,
            endsAt = f[2].toLongOrNull(),
        )
    }
}
```

- [ ] **Step 4: LockMigration schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockMigration.kt`:

```kotlin
package com.klaas.nfc_riegel

/**
 * Einmalige Überführung eines v1-Zustands. Der bestehende Chip wird
 * Generalschlüssel — sonst käme man nach dem Update an eine spätere
 * Kalendersperre nicht mehr heran.
 */
object LockMigration {

    const val LEGACY_PROFILE_ID = "legacy"

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

        return LockState(
            profiles = listOf(profile),
            tags = tags,
            chipLock = if (locked) ChipLock(LEGACY_PROFILE_ID, mode, endsAt) else null,
            codeHash = codeHash,
        )
    }
}
```

- [ ] **Step 5: SharedPrefsLockStore ersetzen**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt` vollständig ersetzen durch:

```kotlin
package com.klaas.nfc_riegel

import android.content.Context

/**
 * Legt den Zustand in SharedPreferences ab. Einzige Android-Abhängigkeit der
 * Datenschicht. Fehlt der Schlüssel [KEY_PROFILES], liegt noch ein v1-Zustand
 * vor — er wird einmalig migriert und sofort im neuen Format zurückgeschrieben.
 */
class SharedPrefsLockStore(context: Context) : LockStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    override fun load(): LockState {
        if (!prefs.contains(KEY_PROFILES)) {
            val migrated = migrateFromV1()
            save(migrated)
            return migrated
        }
        return LockState(
            profiles = LockCodec.decodeProfiles(prefs.getString(KEY_PROFILES, "") ?: ""),
            tags = LockCodec.decodeTags(prefs.getString(KEY_TAGS, "") ?: ""),
            chipLock = LockCodec.decodeChipLock(prefs.getString(KEY_CHIP_LOCK, "") ?: ""),
            codeHash = prefs.getString(KEY_CODE_HASH, null),
            failedAttempts = prefs.getInt(KEY_ATTEMPTS, 0),
            codeLockedUntil = prefs.getLong(KEY_CODE_LOCKED_UNTIL, -1L).takeIf { it > 0 },
        )
    }

    override fun save(state: LockState) {
        prefs.edit()
            .putString(KEY_PROFILES, LockCodec.encodeProfiles(state.profiles))
            .putString(KEY_TAGS, LockCodec.encodeTags(state.tags))
            .putString(KEY_CHIP_LOCK, LockCodec.encodeChipLock(state.chipLock))
            .putString(KEY_CODE_HASH, state.codeHash)
            .putInt(KEY_ATTEMPTS, state.failedAttempts)
            .putLong(KEY_CODE_LOCKED_UNTIL, state.codeLockedUntil ?: -1L)
            .apply()
    }

    private fun migrateFromV1(): LockState = LockMigration.fromV1(
        locked = prefs.getBoolean("locked", false),
        mode = runCatching { LockMode.valueOf(prefs.getString("mode", "TIMER") ?: "TIMER") }
            .getOrDefault(LockMode.TIMER),
        endsAt = prefs.getLong("endsAt", -1L).takeIf { it > 0 },
        durationMinutes = prefs.getInt("durationMinutes", 60),
        blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet(),
        tagUid = prefs.getString("tagUid", null),
        codeHash = prefs.getString("codeHash", null),
    )

    private companion object {
        const val KEY_PROFILES = "profiles"
        const val KEY_TAGS = "tags"
        const val KEY_CHIP_LOCK = "chipLock"
        const val KEY_CODE_HASH = "codeHash"
        const val KEY_ATTEMPTS = "failedAttempts"
        const val KEY_CODE_LOCKED_UNTIL = "codeLockedUntil"
    }
}
```

- [ ] **Step 6: Tests laufen lassen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockCodecTest*" --tests "*LockMigrationTest*"
```

Erwartet: 6 plus 5 Tests grün.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Serialisierung und Migration des v1-Zustands"
```

---

### Task 6: Android-Anbindung nachziehen

Alles, was noch die alten Felder benutzt.

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockerService.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt`

- [ ] **Step 1: LockController anpassen**

In `LockController.kt` die Methode `applyEffects` ersetzen durch:

```kotlin
    private fun applyEffects(state: LockState) {
        val lock = state.chipLock
        if (lock != null) {
            val endsAt = lock.endsAt
            if (endsAt != null) LockScheduler.schedule(context, endsAt)
            else LockScheduler.cancel(context)
            LockNotification.show(context, state)
        } else {
            LockScheduler.cancel(context)
            LockNotification.hide(context)
        }
    }
```

- [ ] **Step 2: LockNotification anpassen**

In `LockNotification.kt` die Methode `show` ersetzen durch:

```kotlin
    fun show(context: Context, state: LockState) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val lock = state.chipLock ?: return
        val profile = state.profileById(lock.profileId)
        val endsAt = lock.endsAt

        val text = if (endsAt != null) {
            "Frei ab ${SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(endsAt))} " +
                "oder nach erneutem Scan"
        } else {
            "Chip scannen, um freizugeben"
        }

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(
                "Riegel aktiv — ${profile?.name ?: "Unbekannt"}, " +
                    "${profile?.blockedPackages?.size ?: 0} Apps gesperrt"
            )
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }
```

- [ ] **Step 3: BlockerService anpassen**

In `BlockerService.kt` die Methode `onAccessibilityEvent` ersetzen durch:

```kotlin
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg == packageName) return

        val now = System.currentTimeMillis()
        val blocked = engine.blockedPackages(now)
        if (blocked.isEmpty()) return

        if (pkg in blocked) {
            showBlockScreen()
            return
        }

        if (pkg == SETTINGS_PACKAGE && SettingsGuard.isGuarded(event.className?.toString())) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
    }
```

- [ ] **Step 4: BlockActivity anpassen**

In `BlockActivity.kt` die Methode `refresh` ersetzen durch:

```kotlin
    private fun refresh() {
        val state = controller.engine.state()
        val lock = state.chipLock
        if (lock == null) {
            finish()
            return
        }
        val profileName = state.profileById(lock.profileId)?.name ?: "Riegel"
        val endsAt = lock.endsAt
        if (endsAt != null) {
            val remaining = ((endsAt - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            countdown.visibility = View.VISIBLE
            countdown.text = "%02d:%02d".format(remaining / 60, remaining % 60)
            hint.text = "oder Chip scannen"
        } else {
            countdown.visibility = View.GONE
            hint.text = "Chip scannen, um freizugeben"
        }
        modeCaption.text = "Profil: $profileName"
    }
```

- [ ] **Step 5: NfcToggleActivity anpassen**

In `NfcToggleActivity.kt` den `when`-Block der Meldungen ersetzen durch:

```kotlin
        val profileName = result.state.chipLock
            ?.let { lock -> result.state.profileById(lock.profileId)?.name }

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — $profileName"
            ScanOutcome.SWITCHED -> "Gewechselt auf $profileName"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            ScanOutcome.MASTER_CLEARED -> "Alle Sperren beendet"
            ScanOutcome.UNKNOWN_TAG -> "Fremder Chip"
            ScanOutcome.NO_TAG_ENROLLED -> "Erst in der App einen Chip anlernen"
            ScanOutcome.NO_PROFILE -> "Profil dieses Chips existiert nicht mehr"
            ScanOutcome.UNTIL_IN_PAST -> "Zeitpunkt liegt in der Vergangenheit"
        }
```

- [ ] **Step 6: Kompilieren und alle Kotlin-Tests laufen lassen**

```bash
android/gradlew.bat -p android compileDebugKotlin
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`. Testzahl: 3 Hashing + 11 Toggle + 8 Timer + 5 Block + 7 Code + 14 Settings + 5 SettingsGuard + 3 NfcSupport + 6 Codec + 5 Migration = **67 Tests**.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Android-Anbindung auf Profile und Chipsperre umgestellt"
```

---

### Task 7: Chip-Anlernen mit Label, Profil und Generalschlüssel

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/TagWriteActivity.kt`

- [ ] **Step 1: Extras entgegennehmen**

In `TagWriteActivity.kt` oberhalb von `onCreate` einfügen:

```kotlin
    private val label: String get() = intent.getStringExtra(EXTRA_LABEL) ?: "Chip"
    private val profileId: String get() = intent.getStringExtra(EXTRA_PROFILE_ID).orEmpty()
    private val isMaster: Boolean get() = intent.getBooleanExtra(EXTRA_IS_MASTER, false)
```

Und am Ende der Klasse, vor der schließenden Klammer:

```kotlin
    companion object {
        const val EXTRA_LABEL = "label"
        const val EXTRA_PROFILE_ID = "profileId"
        const val EXTRA_IS_MASTER = "isMaster"
    }
```

- [ ] **Step 2: Speichern auf die neue Signatur umstellen**

In `writeTag` den Erfolgszweig ersetzen durch:

```kotlin
            onSuccess = {
                val stored = LockEngine(SharedPrefsLockStore(this))
                    .enrollTag(NfcSupport.toHex(tag.id), label, profileId, isMaster)
                if (stored) {
                    Toast.makeText(this, "Chip angelernt", Toast.LENGTH_SHORT).show()
                    setResult(RESULT_OK)
                    finish()
                } else {
                    status.setTextColor(TagWriteColors.DANGER)
                    status.text = "Während einer Sperre nicht möglich"
                }
            },
```

- [ ] **Step 3: Kompilieren**

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Chip-Anlernen mit Label, Profil und Generalschluessel"
```

---

### Task 8: MethodChannel erweitern

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`

- [ ] **Step 1: Methoden ersetzen**

In `RiegelChannel.kt` die Zweige `setBlockedPackages`, `setMode`, `generateCode` und `startTagEnrollment` ersetzen durch:

```kotlin
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
```

- [ ] **Step 2: stateMap ersetzen**

```kotlin
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
```

- [ ] **Step 3: Vollständigen Debug-Build prüfen**

```bash
flutter build apk --debug
```

Erwartet: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`. Die Dart-Seite ruft noch alte Methoden — das bricht erst zur Laufzeit, nicht beim Bauen. Task 9 zieht nach.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: MethodChannel um Profile und Chips erweitert"
```

---

### Task 9: Dart — Modell und Channel

**Files:**
- Modify: `lib/lock_status.dart`
- Modify: `lib/riegel_channel.dart`
- Test: `test/lock_status_test.dart` (ersetzen)

- [ ] **Step 1: Test ersetzen**

`test/lock_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? activeLock,
    List<Map<String, dynamic>>? tags,
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
    ],
    'tags': tags ??
        [
          {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1', 'isMaster': true},
        ],
    'activeLock': activeLock,
    'hasCode': hasCode,
  };

  test('liest Profile und Chips', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.profiles.single.name, 'Arbeit');
    expect(status.profiles.single.durationMinutes, 45);
    expect(status.profiles.single.mode, LockMode.timer);
    expect(status.tags.single.label, 'Schreibtisch');
    expect(status.tags.single.isMaster, isTrue);
  });

  test('ohne aktive Sperre ist locked false', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.locked, isFalse);
    expect(status.activeProfile, isNull);
  });

  test('aktive Sperre liefert Profil und Ende', () {
    final status = LockStatus.fromMap(
      stateMap(
        activeLock: {'profileId': 'p1', 'mode': 'UNTIL', 'endsAt': 1700000000000},
      ),
    );

    expect(status.locked, isTrue);
    expect(status.activeProfile!.name, 'Arbeit');
    expect(status.endsAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('Profil gilt als gesperrt, wenn es gerade sperrt', () {
    final status = LockStatus.fromMap(
      stateMap(activeLock: {'profileId': 'p1', 'mode': 'OPEN', 'endsAt': null}),
    );

    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isFalse);
  });

  test('Einrichtung braucht Chip, Code und mindestens eine App', () {
    expect(LockStatus.fromMap(stateMap()).setupComplete, isTrue);
    expect(LockStatus.fromMap(stateMap(tags: [])).setupComplete, isFalse);
    expect(LockStatus.fromMap(stateMap(hasCode: false)).setupComplete, isFalse);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
flutter test test/lock_status_test.dart
```

Erwartet: Fehler, `The getter 'profiles' isn't defined`.

- [ ] **Step 3: lock_status.dart ersetzen**

```dart
enum LockMode { open, timer, until }

LockMode _modeFrom(String? raw) => switch (raw) {
  'OPEN' => LockMode.open,
  'UNTIL' => LockMode.until,
  _ => LockMode.timer,
};

String modeToNative(LockMode mode) => switch (mode) {
  LockMode.open => 'OPEN',
  LockMode.timer => 'TIMER',
  LockMode.until => 'UNTIL',
};

class ProfileInfo {
  const ProfileInfo({
    required this.id,
    required this.name,
    required this.blockedPackages,
    required this.mode,
    required this.durationMinutes,
    required this.untilAt,
    required this.pinCalendarEnd,
  });

  final String id;
  final String name;
  final List<String> blockedPackages;
  final LockMode mode;
  final int durationMinutes;
  final DateTime? untilAt;
  final bool pinCalendarEnd;

  factory ProfileInfo.fromMap(Map<dynamic, dynamic> map) {
    final until = map['untilAt'] as int?;
    return ProfileInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      blockedPackages:
          (map['blockedPackages'] as List<dynamic>? ?? []).cast<String>(),
      mode: _modeFrom(map['defaultMode'] as String?),
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      untilAt: until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
      pinCalendarEnd: map['pinCalendarEnd'] as bool? ?? false,
    );
  }
}

class TagInfo {
  const TagInfo({
    required this.uid,
    required this.label,
    required this.profileId,
    required this.isMaster,
  });

  final String uid;
  final String label;
  final String profileId;
  final bool isMaster;

  factory TagInfo.fromMap(Map<dynamic, dynamic> map) => TagInfo(
    uid: map['uid'] as String? ?? '',
    label: map['label'] as String? ?? '',
    profileId: map['profileId'] as String? ?? '',
    isMaster: map['isMaster'] as bool? ?? false,
  );
}

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.profiles,
    required this.tags,
    required this.activeProfileId,
    required this.activeMode,
    required this.endsAt,
    required this.hasCode,
  });

  final List<ProfileInfo> profiles;
  final List<TagInfo> tags;
  final String? activeProfileId;
  final LockMode? activeMode;
  final DateTime? endsAt;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final lock = map['activeLock'] as Map<dynamic, dynamic>?;
    final endsAtMillis = lock?['endsAt'] as int?;
    return LockStatus(
      profiles: (map['profiles'] as List<dynamic>? ?? [])
          .map((e) => ProfileInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => TagInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      activeProfileId: lock?['profileId'] as String?,
      activeMode: lock == null ? null : _modeFrom(lock['mode'] as String?),
      endsAt: endsAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAtMillis),
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  bool get locked => activeProfileId != null;

  ProfileInfo? get activeProfile => activeProfileId == null
      ? null
      : profiles.where((p) => p.id == activeProfileId).firstOrNull;

  /// Ein Profil ist nur dann gesperrt, wenn genau es gerade sperrt.
  bool isProfileLocked(String profileId) => activeProfileId == profileId;

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete =>
      tags.isNotEmpty &&
      hasCode &&
      profiles.any((p) => p.blockedPackages.isNotEmpty);
}
```

Ergänze oben in der Datei den Import für `firstOrNull`:

```dart
import 'package:collection/collection.dart';
```

Falls `collection` nicht als Abhängigkeit vorhanden ist, stattdessen ohne Import arbeiten und `activeProfile` so schreiben:

```dart
  ProfileInfo? get activeProfile {
    for (final p in profiles) {
      if (p.id == activeProfileId) return p;
    }
    return null;
  }
```

Die zweite Variante ist vorzuziehen — keine neue Abhängigkeit.

- [ ] **Step 4: riegel_channel.dart ersetzen**

```dart
import 'package:flutter/services.dart';

import 'lock_status.dart';

/// Einzige Stelle, an der Dart mit der nativen Seite spricht.
class RiegelChannel {
  const RiegelChannel([this.channel = const MethodChannel(_name)]);

  static const _name = 'com.klaas.nfc_riegel/riegel';

  final MethodChannel channel;

  Future<LockStatus> getState() async {
    final map = await channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    return LockStatus.fromMap(map ?? const {});
  }

  Future<String> addProfile(String name) async =>
      await channel.invokeMethod<String>('addProfile', {'name': name}) ?? '';

  Future<bool> updateProfile(ProfileInfo profile) async =>
      await channel.invokeMethod<bool>('updateProfile', {
        'id': profile.id,
        'name': profile.name,
        'blockedPackages': profile.blockedPackages,
        'defaultMode': modeToNative(profile.mode),
        'durationMinutes': profile.durationMinutes,
        'untilAt': profile.untilAt?.millisecondsSinceEpoch,
        'pinCalendarEnd': profile.pinCalendarEnd,
      }) ??
      false;

  Future<bool> deleteProfile(String id) async =>
      await channel.invokeMethod<bool>('deleteProfile', {'id': id}) ?? false;

  Future<bool> deleteTag(String uid) async =>
      await channel.invokeMethod<bool>('deleteTag', {'uid': uid}) ?? false;

  Future<String?> generateCode() async =>
      channel.invokeMethod<String>('generateCode');

  Future<void> startTagEnrollment({
    required String label,
    required String profileId,
    required bool isMaster,
  }) => channel.invokeMethod<void>('startTagEnrollment', {
    'label': label,
    'profileId': profileId,
    'isMaster': isMaster,
  });

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() => channel.invokeMethod<void>('requestAdmin');
}
```

- [ ] **Step 5: Test laufen lassen**

```bash
flutter test test/lock_status_test.dart
```

Erwartet: 5 Tests grün. `flutter analyze` ist noch rot, weil die Screens die alten Namen benutzen — Task 10.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib nfc_riegel/test
git commit -m "feat: Dart-Modell und Channel fuer Profile und Chips"
```

---

### Task 10: Dart — Hauptscreen mit Profilliste

**Files:**
- Modify: `lib/home_screen.dart`
- Test: `test/home_screen_test.dart` (ersetzen)

- [ ] **Step 1: Test ersetzen**

`test/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/home_screen.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  void stub({required bool locked, required bool accessibility}) {
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
                'defaultMode': 'TIMER',
                'durationMinutes': 60,
                'untilAt': null,
                'pinCalendarEnd': false,
              },
            ],
            'tags': [
              {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1', 'isMaster': true},
            ],
            'activeLock': locked
                ? {
                    'profileId': 'p1',
                    'mode': 'TIMER',
                    'endsAt': DateTime.now().millisecondsSinceEpoch + 60000,
                  }
                : null,
            'hasCode': true,
          };
        case 'isAccessibilityEnabled':
          return accessibility;
        case 'isAdminActive':
          return true;
      }
      return null;
    });
  }

  testWidgets('zeigt Frei-Status', (tester) async {
    stub(locked: false, accessibility: true);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riegel offen'), findsOneWidget);
  });

  testWidgets('zeigt Gesperrt-Status mit Profilnamen', (tester) async {
    stub(locked: true, accessibility: true);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riegel zu'), findsOneWidget);
    expect(find.textContaining('Arbeit'), findsWidgets);
  });

  testWidgets('warnt, wenn der Dienst aus ist', (tester) async {
    stub(locked: false, accessibility: false);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sperre nicht wirksam'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
flutter test test/home_screen_test.dart
```

Erwartet: Fehler in `home_screen.dart`, `The getter 'mode' isn't defined for LockStatus`.

- [ ] **Step 3: home_screen.dart anpassen**

Die Widgets `_StatusTile`, `_ModeSection` und `_AppsRow` werden ersetzt. `_ModeSection` und `_AppsRow` entfallen ersatzlos — Modus und App-Liste gehören ab jetzt ins Profil. An ihre Stelle tritt die Profilliste.

Ersetze in `home_screen.dart` den `ListView`-Inhalt des `build` durch:

```dart
          children: [
            if (!_accessibility) ...[
              _AccessibilityWarning(
                onEnable: widget.channel.openAccessibilitySettings,
              ),
              const SizedBox(height: RiegelSpacing.s4),
            ],
            _StatusTile(status: status),
            const SizedBox(height: RiegelSpacing.s6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROFILE',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                TextButton(onPressed: _addProfile, child: const Text('Neu')),
              ],
            ),
            const SizedBox(height: RiegelSpacing.s2),
            for (final profile in status.profiles) ...[
              _ProfileRow(
                profile: profile,
                locked: status.isProfileLocked(profile.id),
                onTap: () => _editProfile(profile),
              ),
              const SizedBox(height: RiegelSpacing.s2),
            ],
            const SizedBox(height: RiegelSpacing.s4),
            _NavRow(
              title: 'Chips',
              subtitle: '${status.tags.length} angelernt',
              enabled: !status.locked,
              onTap: () => _openTags(status),
            ),
            if (status.tags.isEmpty) ...[
              const SizedBox(height: RiegelSpacing.s3),
              Text(
                'Kein Chip angelernt — nur der Notfall-Code öffnet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: RiegelColors.danger,
                ),
              ),
            ],
          ],
```

Ergänze in `_HomeScreenState` die drei Aktionen:

```dart
  Future<void> _addProfile() async {
    await widget.channel.addProfile('Neues Profil');
    await _refresh();
  }

  Future<void> _editProfile(ProfileInfo profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(profile: profile, channel: widget.channel),
      ),
    );
    await _refresh();
  }

  Future<void> _openTags(LockStatus status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagsScreen(status: status, channel: widget.channel),
      ),
    );
    await _refresh();
  }
```

Ergänze die Importe:

```dart
import 'profile_screen.dart';
import 'tags_screen.dart';
```

Passe `_StatusTile._subtitle` an, sodass bei aktiver Sperre der Profilname erscheint:

```dart
  String _subtitle(LockStatus status) {
    final profile = status.activeProfile;
    if (profile == null) return 'Chip scannen, um zu sperren';
    final endsAt = status.endsAt;
    if (endsAt != null) {
      final h = endsAt.hour.toString().padLeft(2, '0');
      final m = endsAt.minute.toString().padLeft(2, '0');
      return '${profile.name} — frei ab $h:$m oder nach Scan';
    }
    return '${profile.name} — frei nach erneutem Scan';
  }
```

Und ergänze zwei neue Widgets am Dateiende:

```dart
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.locked,
    required this.onTap,
  });

  final ProfileInfo profile;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (profile.mode) {
      LockMode.open => 'bis Scan',
      LockMode.timer => '${profile.durationMinutes} min',
      LockMode.until => 'bis Zeitpunkt',
    };
    return _NavRow(
      title: profile.name,
      subtitle: '${profile.blockedPackages.length} Apps · $modeLabel',
      enabled: !locked,
      onTap: onTap,
      trailingText: locked ? 'sperrt' : null,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailingText,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiegelColors.bgElev1,
      borderRadius: BorderRadius.circular(RiegelRadii.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(RiegelRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(RiegelSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RiegelRadii.lg),
            border: Border.all(color: RiegelColors.borderDefault),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? RiegelColors.fg1 : RiegelColors.fg4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: RiegelColors.fg3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RiegelColors.locked,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: enabled ? RiegelColors.fg3 : RiegelColors.fg4,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Entferne die nicht mehr benutzten Widgets `_ModeSection` und `_AppsRow` sowie den Import von `app_picker_screen.dart`, sofern er hier nicht mehr gebraucht wird.

- [ ] **Step 4: Prüfen — schlägt noch fehl**

`profile_screen.dart` und `tags_screen.dart` fehlen noch. `flutter analyze` meldet die fehlenden Dateien. Weiter mit Task 11.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib nfc_riegel/test
git commit -m "feat: Hauptscreen mit Profilliste"
```

---

### Task 11: Dart — Profil-Bildschirm

**Files:**
- Create: `lib/profile_screen.dart`

- [ ] **Step 1: profile_screen.dart schreiben**

```dart
import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Ein Profil bearbeiten: Name, Apps, Modus, Dauer bzw. Zeitpunkt.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.channel,
  });

  final ProfileInfo profile;
  final RiegelChannel channel;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.name);
  late List<String> _packages = List.of(widget.profile.blockedPackages);
  late LockMode _mode = widget.profile.mode;
  late int _duration = widget.profile.durationMinutes;
  late DateTime? _untilAt = widget.profile.untilAt;
  late bool _pin = widget.profile.pinCalendarEnd;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickApps() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => AppPickerScreen(selected: _packages)),
    );
    if (picked != null) setState(() => _packages = picked);
  }

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _untilAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_untilAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _untilAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final ok = await widget.channel.updateProfile(
      ProfileInfo(
        id: widget.profile.id,
        name: _name.text.trim().isEmpty ? 'Profil' : _name.text.trim(),
        blockedPackages: _packages,
        mode: _mode,
        durationMinutes: _duration,
        untilAt: _untilAt,
        pinCalendarEnd: _pin,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dieses Profil sperrt gerade')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await widget.channel.deleteProfile(widget.profile.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nicht möglich — letztes Profil oder gerade gesperrt'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Sichern')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: RiegelSpacing.s6),
          Text('APPS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          OutlinedButton(
            onPressed: _pickApps,
            child: Text('${_packages.length} Apps ausgewählt'),
          ),
          const SizedBox(height: RiegelSpacing.s6),
          Text('MODUS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<LockMode>(
              segments: const [
                ButtonSegment(value: LockMode.open, label: Text('Bis Scan')),
                ButtonSegment(value: LockMode.timer, label: Text('Auf Zeit')),
                ButtonSegment(value: LockMode.until, label: Text('Bis Termin')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          if (_mode == LockMode.timer) ...[
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 480,
              divisions: 31,
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            Text(
              '$_duration Minuten',
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 12,
                color: RiegelColors.fg2,
              ),
            ),
          ],
          if (_mode == LockMode.until) ...[
            const SizedBox(height: RiegelSpacing.s3),
            OutlinedButton(
              onPressed: _pickUntil,
              child: Text(
                _untilAt == null
                    ? 'Zeitpunkt wählen'
                    : '${_untilAt!.day}.${_untilAt!.month}. '
                          '${_untilAt!.hour.toString().padLeft(2, '0')}:'
                          '${_untilAt!.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ],
          const SizedBox(height: RiegelSpacing.s6),
          SwitchListTile(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            title: const Text('Kalender-Ende festnageln'),
            subtitle: const Text(
              'Sperre läuft bis zum ursprünglichen Terminende, auch wenn der '
              'Termin verschoben oder gelöscht wird',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: RiegelSpacing.s8),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: RiegelColors.danger,
            ),
            child: const Text('Profil löschen'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib/profile_screen.dart
git commit -m "feat: Profil-Bildschirm"
```

---

### Task 12: Dart — Chip-Verwaltung

**Files:**
- Create: `lib/tags_screen.dart`
- Modify: `lib/setup_wizard.dart`

- [ ] **Step 1: tags_screen.dart schreiben**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Angelernte Chips anzeigen, neue anlernen, alte löschen.
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key, required this.status, required this.channel});

  final LockStatus status;
  final RiegelChannel channel;

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  late LockStatus _status = widget.status;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    if (mounted) setState(() => _status = status);
  }

  /// Nach dem Anlernen wartet der Bildschirm darauf, dass die native Seite den
  /// neuen Chip meldet.
  void _startPolling(int previousCount) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await widget.channel.getState();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.tags.length != previousCount) timer.cancel();
    });
  }

  Future<void> _enroll() async {
    final result = await showDialog<_EnrollRequest>(
      context: context,
      builder: (_) => _EnrollDialog(profiles: _status.profiles),
    );
    if (result == null) return;
    await widget.channel.startTagEnrollment(
      label: result.label,
      profileId: result.profileId,
      isMaster: result.isMaster,
    );
    _startPolling(_status.tags.length);
  }

  Future<void> _delete(TagInfo tag) async {
    final ok = await widget.channel.deleteTag(tag.uid);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Während einer Sperre nicht möglich')),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chips'),
        actions: [
          TextButton(onPressed: _enroll, child: const Text('Anlernen')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          for (final tag in _status.tags)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                tag.isMaster ? Icons.vpn_key : Icons.nfc,
                color: tag.isMaster ? RiegelColors.locked : RiegelColors.accent,
              ),
              title: Text(tag.label),
              subtitle: Text(
                _profileName(tag.profileId) +
                    (tag.isMaster ? ' · Generalschlüssel' : ''),
                style: const TextStyle(fontSize: 12, color: RiegelColors.fg3),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(tag),
              ),
            ),
          if (_status.tags.isEmpty)
            const Text(
              'Noch kein Chip angelernt.',
              style: TextStyle(color: RiegelColors.fg3),
            ),
        ],
      ),
    );
  }

  String _profileName(String id) {
    for (final p in _status.profiles) {
      if (p.id == id) return p.name;
    }
    return 'Unbekannt';
  }
}

class _EnrollRequest {
  const _EnrollRequest(this.label, this.profileId, this.isMaster);

  final String label;
  final String profileId;
  final bool isMaster;
}

class _EnrollDialog extends StatefulWidget {
  const _EnrollDialog({required this.profiles});

  final List<ProfileInfo> profiles;

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  final _label = TextEditingController();
  late String _profileId = widget.profiles.first.id;
  bool _isMaster = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chip anlernen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Bezeichnung'),
          ),
          const SizedBox(height: RiegelSpacing.s4),
          DropdownButtonFormField<String>(
            initialValue: _profileId,
            decoration: const InputDecoration(labelText: 'Profil'),
            items: [
              for (final p in widget.profiles)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _profileId = v ?? _profileId),
          ),
          SwitchListTile(
            value: _isMaster,
            onChanged: (v) => setState(() => _isMaster = v),
            title: const Text('Generalschlüssel'),
            subtitle: const Text('Beendet jede laufende Sperre'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _EnrollRequest(
              _label.text.trim().isEmpty ? 'Chip' : _label.text.trim(),
              _profileId,
              _isMaster,
            ),
          ),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
```

Hinweis: meldet `flutter analyze`, dass `initialValue` bei `DropdownButtonFormField` nicht existiert, ist die Flutter-Version älter — dann `value:` statt `initialValue:` schreiben.

- [ ] **Step 2: setup_wizard.dart anpassen**

Im Schritt „Chip anlernen" den Aufruf ersetzen durch:

```dart
                OutlinedButton(
                  onPressed: () async {
                    final profileId = status.profiles.isEmpty
                        ? ''
                        : status.profiles.first.id;
                    await widget.channel.startTagEnrollment(
                      label: 'Chip 1',
                      profileId: profileId,
                      isMaster: true,
                    );
                    _startTagPolling();
                  },
                  child: Text(
                    status.tags.isEmpty ? 'Chip anlernen' : 'Weiteren Chip anlernen',
                  ),
                ),
```

Ersetze im Wizard alle Zugriffe auf `status.hasTag` durch `status.tags.isNotEmpty` und auf `status.blockedPackages` durch `status.profiles.first.blockedPackages`. Im Polling die Abbruchbedingung auf `status.tags.isNotEmpty` umstellen. Die App-Auswahl in Schritt 2 speichert über `updateProfile` auf dem ersten Profil:

```dart
  Future<void> _pickApps() async {
    final first = _status?.profiles.firstOrNull;
    if (first == null) return;
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(selected: first.blockedPackages),
      ),
    );
    if (picked != null) {
      await widget.channel.updateProfile(
        ProfileInfo(
          id: first.id,
          name: first.name,
          blockedPackages: picked,
          mode: first.mode,
          durationMinutes: first.durationMinutes,
          untilAt: first.untilAt,
          pinCalendarEnd: first.pinCalendarEnd,
        ),
      );
      await _refresh();
    }
  }
```

Da `firstOrNull` ohne das Paket `collection` nicht existiert, stattdessen:

```dart
    final profiles = _status?.profiles ?? const <ProfileInfo>[];
    if (profiles.isEmpty) return;
    final first = profiles.first;
```

Der Notfall-Code-Schritt prüft künftig auf `null`:

```dart
  Future<void> _generateCode() async {
    final code = await widget.channel.generateCode();
    await _refresh();
    if (mounted && code != null) setState(() => _code = code);
  }
```

- [ ] **Step 3: Analyse und alle Tests**

```bash
flutter analyze
flutter test
```

Erwartet: `No issues found!` und 8 Dart-Tests grün (5 lock_status + 3 home_screen).

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib nfc_riegel/test
git commit -m "feat: Chip-Verwaltung und Wizard auf Profile umgestellt"
```

---

### Task 13: Gerätetest, Build, Ablage

**Files:**
- Modify: `GERAETETEST.md`

- [ ] **Step 1: Checkliste ergänzen**

An `GERAETETEST.md` anhängen:

```markdown
## v2 — Profile, mehrere Chips, Sperre bis Zeitpunkt

### Migration
- [ ] Update über eine bestehende v1-Installation: Profil „Standard" ist da, der alte Chip erscheint als Generalschlüssel
- [ ] Eine beim Update laufende Sperre besteht weiter

### Profile
- [ ] Zweites Profil anlegen, benennen, eigene Apps wählen
- [ ] Profil löschen — zugeordnete Chips zeigen danach auf das erste verbleibende
- [ ] Letztes Profil lässt sich nicht löschen
- [ ] Während „Arbeit" sperrt: „Arbeit" nicht bearbeitbar, „Nacht" schon

### Mehrere Chips
- [ ] Zweiten Chip anlernen, Label und Profil vergeben
- [ ] Chip A sperrt Profil A, erneuter Scan von A gibt frei
- [ ] Chip B während laufender A-Sperre: wechselt auf Profil B
- [ ] Generalschlüssel beendet die laufende Sperre
- [ ] Generalschlüssel bei freiem Riegel: sperrt sein eigenes Profil
- [ ] Chip löschen, danach Scan: „Fremder Chip"

### Sperre bis Zeitpunkt
- [ ] Profil auf „Bis Termin" stellen, Zeitpunkt in 5 Minuten wählen, sperren
- [ ] Sperrschirm zählt herunter, Sperre endet zum Zeitpunkt
- [ ] Erneuter Scan beendet vorzeitig
- [ ] Zeitpunkt in der Vergangenheit: Meldung, keine Sperre
- [ ] Neustart während einer UNTIL-Sperre: Sperre besteht weiter
```

- [ ] **Step 2: Alles prüfen**

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
flutter analyze
flutter test
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `No issues found!`, 8 Dart-Tests, 67 Kotlin-Tests.

- [ ] **Step 3: Release bauen und ablegen**

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk \
   "/c/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/GERAETETEST.md
git commit -m "docs: Geraetetest um v2-Punkte ergaenzt"
```

---

## Abschluss

- `flutter analyze` sauber
- `flutter test` — 8 Tests grün
- `android/gradlew.bat -p android testDebugUnitTest` — 67 Tests grün
- `Riegel.apk` neu in `APKs\Android`
- Gerätetest offen, Checkliste steht bereit

Die Kalendereinbindung ist nicht Teil dieses Plans. `Profile.pinCalendarEnd` wird
hier bereits mitgeführt und gespeichert, damit die Kalender-Ausbaustufe das
Datenmodell nicht erneut anfassen muss.
