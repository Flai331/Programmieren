# NFC-Riegel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine Android-App, die per NFC-Chip eine voreingestellte Liste von Apps sperrt und wieder freigibt.

**Architecture:** Flutter liefert die Oberfläche, Kotlin die Sperrmechanik. Der Sperrzustand liegt nativ in SharedPreferences, weil der AccessibilityService ohne Flutter-Engine läuft. Die gesamte Zustandslogik steckt in `LockEngine` — reines Kotlin hinter dem Interface `LockStore`, damit sie mit JUnit ohne Emulator prüfbar ist. Android-Nebenwirkungen (Alarm, Benachrichtigung) liegen ausschließlich in `LockController`.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Kotlin (JVM-Target 17), AGP 8.11.1, JUnit 4.13.2, Pakete `installed_apps`, `permission_handler`.

**Spec:** `docs/superpowers/specs/2026-08-03-nfc-riegel-design.md`

**Projektpfad:** `C:\Users\klaas\Desktop\Programmieren\nfc_riegel`
**Kotlin-Paket:** `com.klaas.nfc_riegel`
**Branch:** `feature/nfc-riegel`

---

## Vorbemerkung zu den Prüf-Kommandos

Alle Kommandos laufen aus `C:\Users\klaas\Desktop\Programmieren\nfc_riegel`.

| Zweck | Kommando |
|---|---|
| Dart-Analyse | `flutter analyze` |
| Dart-Tests | `flutter test` |
| Kotlin-Unit-Tests | `android\gradlew.bat testDebugUnitTest` |

**Bekannte Stolperstelle:** Auf `PATH` liegt Java 8, Gradle braucht 17. Vor Gradle-Aufrufen in der Sitzung einmal setzen:

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
```

PowerShell-Variante:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

---

## Dateistruktur

**Kotlin** — `android/app/src/main/kotlin/com/klaas/nfc_riegel/`

| Datei | Verantwortung |
|---|---|
| `LockState.kt` | Datenklasse + `LockMode`. Reines Kotlin, kein Android. |
| `LockStore.kt` | Interface `LockStore` (load/save). Reines Kotlin. |
| `Hashing.kt` | SHA-256-Helfer. Reines Kotlin. |
| `LockEngine.kt` | Alle Zustandsübergänge. Reines Kotlin, kennt nur `LockStore`. |
| `SharedPrefsLockStore.kt` | `LockStore`-Umsetzung auf SharedPreferences. |
| `LockScheduler.kt` | AlarmManager für den Timer. |
| `LockNotification.kt` | Dauerbenachrichtigung an/aus. |
| `LockController.kt` | Bindeglied: ruft `LockEngine`, wendet Alarm + Benachrichtigung an. |
| `BlockerService.kt` | AccessibilityService: Fenster-Event → blocken. |
| `BlockActivity.kt` | Vollbild-Sperrschirm mit Notfall-Code-Eingabe. |
| `NfcToggleActivity.kt` | NDEF-Intent → UID prüfen → togglen. |
| `TagWriteActivity.kt` | Chip beim Einrichten beschreiben. |
| `TimerReceiver.kt` | Alarm-Empfänger → Sperre beenden. |
| `BootReceiver.kt` | Nach Neustart Zustand wiederherstellen. |
| `UninstallAdmin.kt` | DeviceAdminReceiver. |
| `RiegelChannel.kt` | MethodChannel-Brücke. |
| `MainActivity.kt` | FlutterActivity, registriert `RiegelChannel`. |

**Kotlin-Tests** — `android/app/src/test/kotlin/com/klaas/nfc_riegel/`

| Datei | Prüft |
|---|---|
| `FakeLockStore.kt` | Test-Doppel für `LockStore` |
| `LockEngineToggleTest.kt` | Scan sperrt / entsperrt, fremde UID |
| `LockEngineTimerTest.kt` | Timer-Ablauf, Boot-Wiederherstellung |
| `LockEngineCodeTest.kt` | Notfall-Code, Fehlversuche |
| `LockEngineBlockTest.kt` | `isBlocked` |

**Dart** — `lib/`

| Datei | Verantwortung |
|---|---|
| `main.dart` | App-Einstieg, entscheidet Setup oder Hauptscreen |
| `riegel_channel.dart` | MethodChannel-Client |
| `lock_status.dart` | Dart-Spiegel des Zustands |
| `home_screen.dart` | Status, Modus, Blockliste, Warnbanner |
| `app_picker_screen.dart` | App-Auswahl |
| `setup_wizard.dart` | Vier-Schritt-Einrichtung |

---

### Task 1: Projekt anlegen

**Files:**
- Create: `C:\Users\klaas\Desktop\Programmieren\nfc_riegel\` (Flutter-Projekt)
- Modify: `nfc_riegel/android/app/build.gradle.kts`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Step 1: Flutter-Projekt erzeugen**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
flutter create --org com.klaas --project-name nfc_riegel --platforms=android nfc_riegel
```

- [ ] **Step 2: Abhängigkeiten eintragen**

In `nfc_riegel/pubspec.yaml` den Block `dependencies:` ersetzen durch:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  installed_apps: ^1.5.2
  permission_handler: ^11.3.1
```

Dann:

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter pub get
```

- [ ] **Step 3: JUnit für Kotlin-Unit-Tests eintragen**

In `nfc_riegel/android/app/build.gradle.kts` den `dependencies`-Block ersetzen durch:

```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
}
```

- [ ] **Step 4: Prüfen, dass das leere Projekt sauber ist**

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter analyze
```

Erwartet: `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel
git commit -m "chore: Flutter-Projekt nfc_riegel angelegt"
```

---

### Task 2: LockState, LockStore, Hashing

Reine Datenschicht ohne Android. Noch keine Logik.

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockStore.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Hashing.kt`
- Create: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/FakeLockStore.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/HashingTest.kt`

- [ ] **Step 1: Failing Test für den Hash schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/HashingTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class HashingTest {

    @Test
    fun `gleicher Text ergibt gleichen Hash`() {
        assertEquals(Hashing.sha256("ABCD1234"), Hashing.sha256("ABCD1234"))
    }

    @Test
    fun `anderer Text ergibt anderen Hash`() {
        assertNotEquals(Hashing.sha256("ABCD1234"), Hashing.sha256("ABCD1235"))
    }

    @Test
    fun `Hash ist 64 Hexzeichen lang`() {
        assertEquals(64, Hashing.sha256("test").length)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
android/gradlew.bat -p android testDebugUnitTest --tests "*HashingTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: Hashing`.

- [ ] **Step 3: Hashing schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/Hashing.kt`:

```kotlin
package com.klaas.nfc_riegel

import java.security.MessageDigest

/** SHA-256 als Hexstring. Wird für den Notfall-Code gebraucht. */
object Hashing {
    fun sha256(input: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
```

- [ ] **Step 4: LockState und LockStore schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`:

```kotlin
package com.klaas.nfc_riegel

/** Modus A = OPEN (bis erneuter Scan), Modus B = TIMER (bis Ablauf oder Scan). */
enum class LockMode { OPEN, TIMER }

/**
 * Vollständiger Zustand des Riegels. Reine Daten, keine Android-Abhängigkeit —
 * damit die Logik in [LockEngine] ohne Emulator testbar bleibt.
 */
data class LockState(
    val locked: Boolean = false,
    val mode: LockMode = LockMode.TIMER,
    /** Ende der Sperre in Millis (Wall Clock). Nur gesetzt, wenn locked && mode == TIMER. */
    val endsAt: Long? = null,
    val durationMinutes: Int = 60,
    val blockedPackages: Set<String> = emptySet(),
    val tagUid: String? = null,
    val codeHash: String? = null,
    val failedAttempts: Int = 0,
    /** Bis wann die Code-Eingabe gesperrt ist (Millis) oder null. */
    val codeLockedUntil: Long? = null,
)
```

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockStore.kt`:

```kotlin
package com.klaas.nfc_riegel

/** Ablage des Zustands. Eine Umsetzung für Android, eine für Tests. */
interface LockStore {
    fun load(): LockState
    fun save(state: LockState)
}
```

- [ ] **Step 5: FakeLockStore für Tests schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/FakeLockStore.kt`:

```kotlin
package com.klaas.nfc_riegel

/** Hält den Zustand im Speicher. Ersetzt SharedPreferences im Test. */
class FakeLockStore(initial: LockState = LockState()) : LockStore {
    var current: LockState = initial
        private set

    override fun load(): LockState = current

    override fun save(state: LockState) {
        current = state
    }
}
```

- [ ] **Step 6: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*HashingTest*"
```

Erwartet: `BUILD SUCCESSFUL`, 3 Tests grün.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: LockState, LockStore und Hashing"
```

---

### Task 3: LockEngine — Scan sperrt und entsperrt

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt`

- [ ] **Step 1: Failing Test schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineToggleTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineToggleTest {

    private val now = 1_000_000L
    private val uid = "04A2B3C4D5"

    private fun engineWith(state: LockState): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(state)
        return LockEngine(store) to store
    }

    @Test
    fun `Scan im Modus TIMER sperrt und setzt endsAt`() {
        val (engine, store) = engineWith(
            LockState(tagUid = uid, mode = LockMode.TIMER, durationMinutes = 30)
        )

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertTrue(result.state.locked)
        assertEquals(now + 30 * 60_000L, result.state.endsAt)
        assertTrue(store.current.locked)
    }

    @Test
    fun `Scan im Modus OPEN sperrt ohne endsAt`() {
        val (engine, _) = engineWith(LockState(tagUid = uid, mode = LockMode.OPEN))

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertTrue(result.state.locked)
        assertNull(result.state.endsAt)
    }

    @Test
    fun `Scan waehrend Sperre gibt frei`() {
        val (engine, store) = engineWith(
            LockState(tagUid = uid, locked = true, mode = LockMode.TIMER, endsAt = now + 5000)
        )

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
        assertNull(result.state.endsAt)
        assertFalse(store.current.locked)
    }

    @Test
    fun `fremde UID aendert nichts`() {
        val (engine, store) = engineWith(LockState(tagUid = uid))

        val result = engine.onTagScanned("DEADBEEF", now)

        assertEquals(ScanOutcome.UNKNOWN_TAG, result.outcome)
        assertFalse(result.state.locked)
        assertFalse(store.current.locked)
    }

    @Test
    fun `ohne angelernten Chip passiert nichts`() {
        val (engine, _) = engineWith(LockState(tagUid = null))

        val result = engine.onTagScanned(uid, now)

        assertEquals(ScanOutcome.NO_TAG_ENROLLED, result.outcome)
        assertFalse(result.state.locked)
    }

    @Test
    fun `UID-Vergleich ignoriert Gross- und Kleinschreibung`() {
        val (engine, _) = engineWith(LockState(tagUid = uid))

        val result = engine.onTagScanned(uid.lowercase(), now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineToggleTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: LockEngine`.

- [ ] **Step 3: LockEngine mit der Toggle-Logik schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`:

```kotlin
package com.klaas.nfc_riegel

enum class ScanOutcome { LOCKED, UNLOCKED, UNKNOWN_TAG, NO_TAG_ENROLLED }

data class ScanResult(val state: LockState, val outcome: ScanOutcome)

/**
 * Alle Zustandsübergänge des Riegels. Kennt nur [LockStore] — keine Android-Klassen,
 * keine Nebenwirkungen. Alarm und Benachrichtigung setzt [LockController] anhand des
 * zurückgegebenen Zustands.
 */
class LockEngine(private val store: LockStore) {

    fun state(): LockState = store.load()

    /** Chip gescannt: sperrt oder gibt frei. Fremde UID lässt den Zustand unberührt. */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        val enrolled = s.tagUid ?: return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        if (!uid.equals(enrolled, ignoreCase = true)) {
            return ScanResult(s, ScanOutcome.UNKNOWN_TAG)
        }
        return if (s.locked) ScanResult(unlock(s), ScanOutcome.UNLOCKED)
        else ScanResult(lock(s, now), ScanOutcome.LOCKED)
    }

    private fun lock(s: LockState, now: Long): LockState {
        val endsAt = if (s.mode == LockMode.TIMER) now + s.durationMinutes * 60_000L else null
        val next = s.copy(locked = true, endsAt = endsAt)
        store.save(next)
        return next
    }

    private fun unlock(s: LockState): LockState {
        val next = s.copy(
            locked = false,
            endsAt = null,
            failedAttempts = 0,
            codeLockedUntil = null,
        )
        store.save(next)
        return next
    }
}
```

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineToggleTest*"
```

Erwartet: `BUILD SUCCESSFUL`, 6 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: LockEngine sperrt und entsperrt per Chip-Scan"
```

---

### Task 4: LockEngine — Timer-Ablauf und Boot-Wiederherstellung

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineTimerTest.kt`

- [ ] **Step 1: Failing Test schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineTimerTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineTimerTest {

    private val now = 1_000_000L

    @Test
    fun `abgelaufener Timer gibt frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now - 1)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertFalse(state.locked)
        assertNull(state.endsAt)
        assertFalse(store.current.locked)
    }

    @Test
    fun `noch laufender Timer gibt nicht frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now + 60_000)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertTrue(state.locked)
        assertEquals(now + 60_000, state.endsAt)
    }

    @Test
    fun `Boot mit abgelaufenem Timer gibt frei`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now - 10_000)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertFalse(state.locked)
    }

    @Test
    fun `Boot mit laufendem Timer bleibt gesperrt`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.TIMER, endsAt = now + 10_000)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertTrue(state.locked)
        assertEquals(now + 10_000, state.endsAt)
    }

    @Test
    fun `Boot im Modus OPEN bleibt gesperrt`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.OPEN, endsAt = null)
        )
        val engine = LockEngine(store)

        val state = engine.restoreAfterBoot(now)

        assertTrue(state.locked)
    }

    @Test
    fun `Timer-Ablauf im Modus OPEN aendert nichts`() {
        val store = FakeLockStore(
            LockState(locked = true, mode = LockMode.OPEN, endsAt = null)
        )
        val engine = LockEngine(store)

        val state = engine.onTimerElapsed(now)

        assertTrue(state.locked)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineTimerTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: onTimerElapsed`.

- [ ] **Step 3: Methoden ergänzen**

In `LockEngine.kt` vor die private Methode `lock` einfügen:

```kotlin
    /**
     * Vom Alarm gerufen. Gibt frei, wenn die Endzeit erreicht ist — sonst nichts.
     * Die Uhrzeit entscheidet, nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val endsAt = s.endsAt ?: return s
        if (!s.locked || s.mode != LockMode.TIMER) return s
        return if (now >= endsAt) unlock(s) else s
    }

    /**
     * Nach dem Neustart. Modus OPEN bleibt gesperrt; im Modus TIMER entscheidet
     * die Endzeit, ob die Sperre noch gilt.
     */
    fun restoreAfterBoot(now: Long): LockState {
        val s = store.load()
        if (!s.locked) return s
        if (s.mode != LockMode.TIMER) return s
        val endsAt = s.endsAt ?: return s
        return if (now >= endsAt) unlock(s) else s
    }
```

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineTimerTest*"
```

Erwartet: `BUILD SUCCESSFUL`, 6 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Timer-Ablauf und Boot-Wiederherstellung in LockEngine"
```

---

### Task 5: LockEngine — Notfall-Code und Blockliste

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCodeTest.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineBlockTest.kt`

- [ ] **Step 1: Failing Tests schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCodeTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineCodeTest {

    private val now = 1_000_000L
    private val code = "K7M2P9QX"

    private fun lockedEngine(
        failedAttempts: Int = 0,
        codeLockedUntil: Long? = null,
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                locked = true,
                mode = LockMode.OPEN,
                codeHash = Hashing.sha256(code),
                failedAttempts = failedAttempts,
                codeLockedUntil = codeLockedUntil,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `richtiger Code gibt frei`() {
        val (engine, store) = lockedEngine()

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
        assertFalse(store.current.locked)
    }

    @Test
    fun `falscher Code zaehlt hoch und bleibt gesperrt`() {
        val (engine, _) = lockedEngine()

        val result = engine.submitCode("FALSCH12", now)

        assertEquals(CodeOutcome.WRONG, result.outcome)
        assertTrue(result.state.locked)
        assertEquals(1, result.state.failedAttempts)
    }

    @Test
    fun `dritter Fehlversuch sperrt die Eingabe 60 Sekunden`() {
        val (engine, _) = lockedEngine(failedAttempts = 2)

        val result = engine.submitCode("FALSCH12", now)

        assertEquals(CodeOutcome.LOCKED_OUT, result.outcome)
        assertEquals(now + 60_000L, result.state.codeLockedUntil)
        assertEquals(0, result.state.failedAttempts)
    }

    @Test
    fun `waehrend der Eingabesperre wird selbst der richtige Code abgewiesen`() {
        val (engine, _) = lockedEngine(codeLockedUntil = now + 30_000)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.LOCKED_OUT, result.outcome)
        assertTrue(result.state.locked)
    }

    @Test
    fun `nach Ablauf der Eingabesperre gilt der Code wieder`() {
        val (engine, _) = lockedEngine(codeLockedUntil = now - 1)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertFalse(result.state.locked)
    }

    @Test
    fun `ohne hinterlegten Code meldet die Engine NOT_SET`() {
        val store = FakeLockStore(LockState(locked = true, codeHash = null))
        val engine = LockEngine(store)

        val result = engine.submitCode(code, now)

        assertEquals(CodeOutcome.NOT_SET, result.outcome)
        assertTrue(result.state.locked)
    }

    @Test
    fun `Code wird gross geschrieben und getrimmt geprueft`() {
        val (engine, _) = lockedEngine()

        val result = engine.submitCode("  k7m2p9qx ", now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
    }
}
```

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineBlockTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineBlockTest {

    @Test
    fun `gesperrte App wird bei aktiver Sperre geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = true, blockedPackages = setOf("com.instagram.android")))
        )

        assertTrue(engine.isBlocked("com.instagram.android"))
    }

    @Test
    fun `nicht gelistete App wird nicht geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = true, blockedPackages = setOf("com.instagram.android")))
        )

        assertFalse(engine.isBlocked("com.android.dialer"))
    }

    @Test
    fun `ohne aktive Sperre wird nichts geblockt`() {
        val engine = LockEngine(
            FakeLockStore(LockState(locked = false, blockedPackages = setOf("com.instagram.android")))
        )

        assertFalse(engine.isBlocked("com.instagram.android"))
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineCodeTest*" --tests "*LockEngineBlockTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: submitCode`.

- [ ] **Step 3: Methoden ergänzen**

In `LockEngine.kt` oben neben `ScanOutcome` einfügen:

```kotlin
enum class CodeOutcome { UNLOCKED, WRONG, LOCKED_OUT, NOT_SET }

data class CodeResult(val state: LockState, val outcome: CodeOutcome)
```

Und in der Klasse `LockEngine` vor `lock` einfügen:

```kotlin
    /** Notfall-Code aus dem Sperrschirm. Drei Fehlversuche sperren die Eingabe 60 s. */
    fun submitCode(input: String, now: Long): CodeResult {
        val s = store.load()
        val hash = s.codeHash ?: return CodeResult(s, CodeOutcome.NOT_SET)

        val lockedUntil = s.codeLockedUntil
        if (lockedUntil != null && now < lockedUntil) {
            return CodeResult(s, CodeOutcome.LOCKED_OUT)
        }

        val normalized = input.trim().uppercase()
        if (Hashing.sha256(normalized) == hash) {
            return CodeResult(unlock(s), CodeOutcome.UNLOCKED)
        }

        val attempts = s.failedAttempts + 1
        return if (attempts >= MAX_ATTEMPTS) {
            val next = s.copy(failedAttempts = 0, codeLockedUntil = now + LOCKOUT_MILLIS)
            store.save(next)
            CodeResult(next, CodeOutcome.LOCKED_OUT)
        } else {
            val next = s.copy(failedAttempts = attempts, codeLockedUntil = null)
            store.save(next)
            CodeResult(next, CodeOutcome.WRONG)
        }
    }

    /** Vom AccessibilityService bei jedem Fensterwechsel gefragt. */
    fun isBlocked(packageName: String): Boolean {
        val s = store.load()
        return s.locked && packageName in s.blockedPackages
    }
```

Und am Ende der Klasse:

```kotlin
    companion object {
        const val MAX_ATTEMPTS = 3
        const val LOCKOUT_MILLIS = 60_000L
    }
```

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`, alle 25 Tests grün (3 Hashing + 6 Toggle + 6 Timer + 7 Code + 3 Block).

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Notfall-Code und Blocklisten-Pruefung in LockEngine"
```

---

### Task 6: Einstellungen ändern (Blockliste, Modus, Chip, Code)

Schreibende Methoden, die der Setup-Wizard und der Hauptscreen brauchen.

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineSettingsTest.kt`

- [ ] **Step 1: Failing Test schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineSettingsTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineSettingsTest {

    @Test
    fun `Blockliste wird gespeichert`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.setBlockedPackages(setOf("com.a", "com.b"))

        assertEquals(setOf("com.a", "com.b"), store.current.blockedPackages)
    }

    @Test
    fun `Modus und Dauer werden gespeichert`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.setMode(LockMode.OPEN, 90)

        assertEquals(LockMode.OPEN, store.current.mode)
        assertEquals(90, store.current.durationMinutes)
    }

    @Test
    fun `Einstellungen sind waehrend einer Sperre gesperrt`() {
        val store = FakeLockStore(LockState(locked = true))
        val engine = LockEngine(store)

        val ok = engine.setBlockedPackages(setOf("com.a"))

        assertEquals(false, ok)
        assertTrue(store.current.blockedPackages.isEmpty())
    }

    @Test
    fun `Chip anlernen speichert die UID`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        engine.enrollTag("04A2B3")

        assertEquals("04A2B3", store.current.tagUid)
    }

    @Test
    fun `Code erzeugen liefert acht Zeichen und speichert nur den Hash`() {
        val store = FakeLockStore()
        val engine = LockEngine(store)

        val code = engine.generateCode()

        assertEquals(8, code.length)
        assertEquals(Hashing.sha256(code), store.current.codeHash)
        assertNotNull(store.current.codeHash)
    }

    @Test
    fun `erzeugter Code enthaelt nur erlaubte Zeichen`() {
        val engine = LockEngine(FakeLockStore())

        val code = engine.generateCode()

        assertTrue(code.all { it in LockEngine.CODE_ALPHABET })
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*LockEngineSettingsTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: setBlockedPackages`.

- [ ] **Step 3: Methoden ergänzen**

In `LockEngine.kt` vor `lock` einfügen:

```kotlin
    /** Blockliste setzen. Während einer Sperre abgelehnt — sonst wäre sie wertlos. */
    fun setBlockedPackages(packages: Set<String>): Boolean {
        val s = store.load()
        if (s.locked) return false
        store.save(s.copy(blockedPackages = packages))
        return true
    }

    /** Modus und Dauer setzen. Während einer Sperre abgelehnt. */
    fun setMode(mode: LockMode, durationMinutes: Int): Boolean {
        val s = store.load()
        if (s.locked) return false
        store.save(s.copy(mode = mode, durationMinutes = durationMinutes))
        return true
    }

    fun enrollTag(uid: String) {
        store.save(store.load().copy(tagUid = uid))
    }

    /** Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig zurück. */
    fun generateCode(): String {
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(store.load().copy(codeHash = Hashing.sha256(code)))
        return code
    }
```

Und die `companion object`-Konstanten ergänzen:

```kotlin
    companion object {
        const val MAX_ATTEMPTS = 3
        const val LOCKOUT_MILLIS = 60_000L
        /** Ohne 0/O und 1/I — der Code wird abgeschrieben. */
        const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }
```

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`, 31 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Einstellungen schreiben in LockEngine"
```

---

### Task 7: SharedPrefsLockStore

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`

Diese Datei ist die einzige Stelle mit Android-Ablage. Getestet wird sie von Hand (Task 17), weil SharedPreferences ohne Emulator nicht läuft — die Logik darüber ist bereits abgedeckt.

- [ ] **Step 1: Store schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.content.Context

/** Legt den Zustand in SharedPreferences ab. Einzige Android-Abhängigkeit der Datenschicht. */
class SharedPrefsLockStore(context: Context) : LockStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    override fun load(): LockState = LockState(
        locked = prefs.getBoolean(KEY_LOCKED, false),
        mode = if (prefs.getString(KEY_MODE, "TIMER") == "OPEN") LockMode.OPEN else LockMode.TIMER,
        endsAt = prefs.getLong(KEY_ENDS_AT, -1L).takeIf { it > 0 },
        durationMinutes = prefs.getInt(KEY_DURATION, 60),
        blockedPackages = prefs.getStringSet(KEY_PACKAGES, emptySet()) ?: emptySet(),
        tagUid = prefs.getString(KEY_TAG_UID, null),
        codeHash = prefs.getString(KEY_CODE_HASH, null),
        failedAttempts = prefs.getInt(KEY_ATTEMPTS, 0),
        codeLockedUntil = prefs.getLong(KEY_CODE_LOCKED_UNTIL, -1L).takeIf { it > 0 },
    )

    override fun save(state: LockState) {
        prefs.edit()
            .putBoolean(KEY_LOCKED, state.locked)
            .putString(KEY_MODE, state.mode.name)
            .putLong(KEY_ENDS_AT, state.endsAt ?: -1L)
            .putInt(KEY_DURATION, state.durationMinutes)
            .putStringSet(KEY_PACKAGES, state.blockedPackages)
            .putString(KEY_TAG_UID, state.tagUid)
            .putString(KEY_CODE_HASH, state.codeHash)
            .putInt(KEY_ATTEMPTS, state.failedAttempts)
            .putLong(KEY_CODE_LOCKED_UNTIL, state.codeLockedUntil ?: -1L)
            .apply()
    }

    private companion object {
        const val KEY_LOCKED = "locked"
        const val KEY_MODE = "mode"
        const val KEY_ENDS_AT = "endsAt"
        const val KEY_DURATION = "durationMinutes"
        const val KEY_PACKAGES = "blockedPackages"
        const val KEY_TAG_UID = "tagUid"
        const val KEY_CODE_HASH = "codeHash"
        const val KEY_ATTEMPTS = "failedAttempts"
        const val KEY_CODE_LOCKED_UNTIL = "codeLockedUntil"
    }
}
```

- [ ] **Step 2: Kompilierung prüfen**

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: SharedPrefsLockStore"
```

---

### Task 8: LockScheduler, LockNotification, LockController

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockScheduler.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/TimerReceiver.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BootReceiver.kt`

- [ ] **Step 1: LockScheduler schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockScheduler.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Setzt und löscht den Wecker, der eine Timer-Sperre beendet. */
object LockScheduler {

    private const val REQUEST_CODE = 4711

    fun schedule(context: Context, endsAt: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            manager.set(AlarmManager.RTC_WAKEUP, endsAt, pending)
            return
        }
        manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAt, pending)
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, TimerReceiver::class.java).setPackage(context.packageName)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
```

- [ ] **Step 2: LockNotification schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Dauerhafte Benachrichtigung während einer Sperre. Bewusst eine gewöhnliche
 * ongoing-Notification: den AccessibilityService hält das System selbst am Leben,
 * ein Foreground Service wäre überflüssig.
 */
object LockNotification {

    private const val CHANNEL_ID = "riegel_lock"
    private const val NOTIFICATION_ID = 1

    fun show(context: Context, state: LockState) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val text = when {
            state.mode == LockMode.TIMER && state.endsAt != null ->
                "Frei ab ${SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(state.endsAt))} " +
                    "oder nach erneutem Scan"
            else -> "Chip scannen, um freizugeben"
        }

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle("Riegel aktiv — ${state.blockedPackages.size} Apps gesperrt")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    fun hide(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(manager: NotificationManager) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Riegel-Status",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Zeigt an, ob der Riegel gerade sperrt"
        manager.createNotificationChannel(channel)
    }
}
```

- [ ] **Step 3: LockController schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.content.Context

/**
 * Bindeglied zwischen der reinen [LockEngine] und Android. Nur hier werden Alarm und
 * Benachrichtigung angefasst — die Engine bleibt frei von Nebenwirkungen.
 */
class LockController(private val context: Context) {

    val engine = LockEngine(SharedPrefsLockStore(context))

    fun scan(uid: String, now: Long = System.currentTimeMillis()): ScanResult {
        val result = engine.onTagScanned(uid, now)
        applyEffects(result.state)
        return result
    }

    fun expire(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.onTimerElapsed(now))
    }

    fun restoreAfterBoot(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.restoreAfterBoot(now))
    }

    fun submitCode(code: String, now: Long = System.currentTimeMillis()): CodeResult {
        val result = engine.submitCode(code, now)
        applyEffects(result.state)
        return result
    }

    private fun applyEffects(state: LockState) {
        if (state.locked) {
            val endsAt = state.endsAt
            if (state.mode == LockMode.TIMER && endsAt != null) {
                LockScheduler.schedule(context, endsAt)
            } else {
                LockScheduler.cancel(context)
            }
            LockNotification.show(context, state)
        } else {
            LockScheduler.cancel(context)
            LockNotification.hide(context)
        }
    }
}
```

- [ ] **Step 4: TimerReceiver und BootReceiver schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/TimerReceiver.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LockController(context).expire()
    }
}
```

`android/app/src/main/kotlin/com/klaas/nfc_riegel/BootReceiver.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LockController(context).restoreAfterBoot()
    }
}
```

- [ ] **Step 5: Kompilierung prüfen**

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Alarm, Benachrichtigung und LockController"
```

---

### Task 9: AndroidManifest und Ressourcen

**Files:**
- Modify: `nfc_riegel/android/app/src/main/AndroidManifest.xml`
- Create: `nfc_riegel/android/app/src/main/res/xml/accessibility_service_config.xml`
- Create: `nfc_riegel/android/app/src/main/res/xml/device_admin.xml`
- Create: `nfc_riegel/android/app/src/main/res/values/strings.xml`

- [ ] **Step 1: Ressourcen anlegen**

`android/app/src/main/res/xml/accessibility_service_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagDefault"
    android:canPerformGestures="false"
    android:canRetrieveWindowContent="true"
    android:description="@string/accessibility_description"
    android:notificationTimeout="100"/>
```

Kein `android:packageNames` — der Dienst muss jede App sehen können.

`android/app/src/main/res/xml/device_admin.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <force-lock />
    </uses-policies>
</device-admin>
```

`android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="accessibility_description">Erkennt, wenn eine gesperrte App geöffnet wird, und blendet den Sperrschirm ein.</string>
    <string name="admin_label">Riegel-Deinstallationsschutz</string>
</resources>
```

- [ ] **Step 2: Manifest schreiben**

`android/app/src/main/AndroidManifest.xml` vollständig ersetzen durch:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.NFC"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission"/>

    <uses-feature android:name="android.hardware.nfc" android:required="true"/>

    <application
        android:label="Riegel"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Wird vom Chip gestartet: NDEF mit eigenem MIME-Typ -->
        <activity
            android:name=".NfcToggleActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:excludeFromRecents="true"
            android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="application/vnd.com.klaas.nfc_riegel"/>
            </intent-filter>
        </activity>

        <!-- Chip beschreiben beim Einrichten -->
        <activity
            android:name=".TagWriteActivity"
            android:exported="false"
            android:launchMode="singleTop"
            android:excludeFromRecents="true"/>

        <!-- Sperrschirm -->
        <activity
            android:name=".BlockActivity"
            android:exported="false"
            android:launchMode="singleTask"
            android:taskAffinity=""
            android:excludeFromRecents="true"
            android:theme="@android:style/Theme.DeviceDefault.NoActionBar"/>

        <service
            android:name=".BlockerService"
            android:exported="true"
            android:label="Riegel"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService"/>
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config"/>
        </service>

        <receiver
            android:name=".UninstallAdmin"
            android:exported="true"
            android:label="@string/admin_label"
            android:permission="android.permission.BIND_DEVICE_ADMIN">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/device_admin"/>
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/>
            </intent-filter>
        </receiver>

        <receiver android:name=".TimerReceiver" android:exported="false"/>

        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2"/>
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent>
    </queries>
</manifest>
```

- [ ] **Step 3: UninstallAdmin schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/UninstallAdmin.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class UninstallAdmin : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        val state = LockEngine(SharedPrefsLockStore(context)).state()
        return if (state.locked) {
            "Der Riegel sperrt gerade. Deaktivieren hebt den Deinstallationsschutz auf."
        } else {
            "Deinstallationsschutz wird aufgehoben."
        }
    }
}
```

- [ ] **Step 4: Kompilierung prüfen**

Die Activities aus dem Manifest gibt es noch nicht — deshalb hier nur Kotlin kompilieren:

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Manifest, Accessibility-Konfiguration und Device Admin"
```

---

### Task 10: BlockerService

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockerService.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/SettingsGuardTest.kt`

Die Erkennung der geschützten Einstellungsseiten ist reine Zeichenkettenarbeit und wird getestet. Der Dienst selbst wird von Hand geprüft.

- [ ] **Step 1: Failing Test für den Einstellungs-Wächter schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/SettingsGuardTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsGuardTest {

    @Test
    fun `Accessibility-Seite ist geschuetzt`() {
        assertTrue(SettingsGuard.isGuarded("com.android.settings.AccessibilitySettings"))
    }

    @Test
    fun `Unterseite eines Accessibility-Dienstes ist geschuetzt`() {
        assertTrue(
            SettingsGuard.isGuarded("com.android.settings.accessibility.AccessibilityDetailsSettings")
        )
    }

    @Test
    fun `Device-Admin-Seite ist geschuetzt`() {
        assertTrue(SettingsGuard.isGuarded("com.android.settings.DeviceAdminSettings"))
    }

    @Test
    fun `WLAN-Einstellungen sind nicht geschuetzt`() {
        assertFalse(SettingsGuard.isGuarded("com.android.settings.wifi.WifiSettings"))
    }

    @Test
    fun `null bedeutet nicht geschuetzt`() {
        assertFalse(SettingsGuard.isGuarded(null))
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*SettingsGuardTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: SettingsGuard`.

- [ ] **Step 3: SettingsGuard und BlockerService schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockerService.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Erkennt die Einstellungsseiten, über die man den Riegel abschalten könnte.
 * Bewusst nur diese — die restlichen Einstellungen bleiben während einer Sperre nutzbar.
 */
object SettingsGuard {
    private val markers = listOf("accessibility", "deviceadmin", "device_admin")

    fun isGuarded(className: String?): Boolean {
        val name = className?.lowercase() ?: return false
        return markers.any { name.contains(it) }
    }
}

/**
 * Lauscht auf Fensterwechsel. Fragt bei jedem Ereignis den aktuellen Zustand ab,
 * statt sich benachrichtigen zu lassen — so kann nichts auseinanderlaufen.
 */
class BlockerService : AccessibilityService() {

    private val engine by lazy { LockEngine(SharedPrefsLockStore(this)) }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg == packageName) return

        val state = engine.state()
        if (!state.locked) return

        if (pkg in state.blockedPackages) {
            showBlockScreen()
            return
        }

        if (pkg == SETTINGS_PACKAGE && SettingsGuard.isGuarded(event.className?.toString())) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
    }

    override fun onInterrupt() {}

    private fun showBlockScreen() {
        val intent = Intent(this, BlockActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
    }

    private companion object {
        const val SETTINGS_PACKAGE = "com.android.settings"
    }
}
```

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*SettingsGuardTest*"
```

Erwartet: `BUILD SUCCESSFUL`, 5 Tests grün.

Zum Spec-Punkt „gesperrte App war beim Sperren offen": ein eigener
`GLOBAL_ACTION_HOME`-Aufruf beim Sperren ist nicht nötig. Der Scan öffnet
`NfcToggleActivity` im Vordergrund; beim Schließen kehrt das System zur vorherigen
App zurück und löst genau das Fenster-Ereignis aus, auf das dieser Dienst reagiert.
Der Sperrschirm erscheint dadurch von selbst.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: BlockerService mit Einstellungs-Waechter"
```

---

### Task 11: BlockActivity

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`

Vollständig in Kotlin-Code aufgebaut, ohne Layout-XML — der Schirm hat vier Elemente und muss auch dann funktionieren, wenn die Flutter-Engine nicht läuft.

- [ ] **Step 1: BlockActivity schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Vollbild-Sperrschirm. Zeigt Restzeit und nimmt den Notfall-Code entgegen. */
class BlockActivity : Activity() {

    private lateinit var controller: LockController
    private lateinit var title: TextView
    private lateinit var subtitle: TextView
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        controller = LockController(this)
        setContentView(buildLayout())
    }

    override fun onResume() {
        super.onResume()
        handler.post(ticker)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
    }

    /** Zurück-Taste darf den Sperrschirm nicht wegräumen. */
    override fun onBackPressed() {
        moveTaskToBack(true)
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#101317"))
            setPadding(48, 48, 48, 48)
        }

        title = TextView(this).apply {
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = "Gesperrt"
        }

        subtitle = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.parseColor("#B0B8C1"))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 48)
        }

        val codeField = EditText(this).apply {
            hint = "Notfall-Code"
            inputType = InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#6B7480"))
            gravity = Gravity.CENTER
        }

        val submit = Button(this).apply {
            text = "Code einlösen"
            setOnClickListener { submitCode(codeField.text.toString()) }
        }

        root.addView(title)
        root.addView(subtitle)
        root.addView(codeField)
        root.addView(submit)
        return root
    }

    private fun submitCode(code: String) {
        when (controller.submitCode(code).outcome) {
            CodeOutcome.UNLOCKED -> {
                Toast.makeText(this, "Riegel offen", Toast.LENGTH_SHORT).show()
                finish()
            }
            CodeOutcome.WRONG ->
                Toast.makeText(this, "Code falsch", Toast.LENGTH_SHORT).show()
            CodeOutcome.LOCKED_OUT ->
                Toast.makeText(this, "Zu viele Versuche — 60 Sekunden warten", Toast.LENGTH_LONG).show()
            CodeOutcome.NOT_SET ->
                Toast.makeText(this, "Kein Notfall-Code hinterlegt", Toast.LENGTH_LONG).show()
        }
    }

    private fun refresh() {
        val state = controller.engine.state()
        if (!state.locked) {
            finish()
            return
        }
        val endsAt = state.endsAt
        subtitle.text = if (state.mode == LockMode.TIMER && endsAt != null) {
            val remaining = ((endsAt - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            "Noch %02d:%02d — oder Chip scannen".format(remaining / 60, remaining % 60)
        } else {
            "Chip scannen, um freizugeben"
        }
    }
}
```

- [ ] **Step 2: Kompilierung prüfen**

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Sperrschirm mit Restzeit und Notfall-Code"
```

---

### Task 12: NfcToggleActivity und TagWriteActivity

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcSupport.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/TagWriteActivity.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/NfcSupportTest.kt`

- [ ] **Step 1: Failing Test für die UID-Umwandlung schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/NfcSupportTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test

class NfcSupportTest {

    @Test
    fun `Bytes werden als Grossbuchstaben-Hex ausgegeben`() {
        val bytes = byteArrayOf(0x04, 0xA2.toByte(), 0x0B)
        assertEquals("04A20B", NfcSupport.toHex(bytes))
    }

    @Test
    fun `fuehrende Null bleibt erhalten`() {
        assertEquals("0F", NfcSupport.toHex(byteArrayOf(0x0F)))
    }

    @Test
    fun `leeres Array ergibt leeren String`() {
        assertEquals("", NfcSupport.toHex(byteArrayOf()))
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*NfcSupportTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: NfcSupport`.

- [ ] **Step 3: NfcSupport schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcSupport.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build

object NfcSupport {

    const val MIME_TYPE = "application/vnd.com.klaas.nfc_riegel"

    fun toHex(bytes: ByteArray): String = bytes.joinToString("") { "%02X".format(it) }

    /** Tag aus dem Intent holen — ab API 33 mit Typ, davor über die veraltete Variante. */
    @Suppress("DEPRECATION")
    fun tagFrom(intent: Intent): Tag? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }

    /**
     * Nachricht für den Chip: eigener MIME-Record (löst den Intent aus) plus
     * Android Application Record (startet die App, auch wenn sie geschlossen ist).
     */
    fun buildMessage(packageName: String): NdefMessage = NdefMessage(
        arrayOf(
            NdefRecord.createMime(MIME_TYPE, "riegel".toByteArray()),
            NdefRecord.createApplicationRecord(packageName),
        )
    )
}
```

- [ ] **Step 4: NfcToggleActivity schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

/**
 * Wird vom Chip gestartet. Prüft die UID, togglet, meldet kurz das Ergebnis
 * und verschwindet wieder — ohne Oberfläche.
 */
class NfcToggleActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val tag = intent?.let { NfcSupport.tagFrom(it) }
        if (tag == null) {
            toastAndFinish("Chip nicht lesbar")
            return
        }

        val uid = NfcSupport.toHex(tag.id)
        val result = LockController(this).scan(uid)

        val message = when (result.outcome) {
            ScanOutcome.LOCKED -> "Riegel zu — ${result.state.blockedPackages.size} Apps gesperrt"
            ScanOutcome.UNLOCKED -> "Riegel offen"
            ScanOutcome.UNKNOWN_TAG -> "Fremder Chip"
            ScanOutcome.NO_TAG_ENROLLED -> "Erst in der App einen Chip anlernen"
        }
        toastAndFinish(message)
    }

    private fun toastAndFinish(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        finish()
    }
}
```

- [ ] **Step 5: TagWriteActivity schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/TagWriteActivity.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Einrichtung: beschreibt den Chip mit MIME-Record und Application Record und
 * merkt sich dessen UID. Nutzt Foreground Dispatch, damit hier jeder Tag ankommt —
 * auch ein noch leerer.
 */
class TagWriteActivity : Activity() {

    private var adapter: NfcAdapter? = null
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        adapter = NfcAdapter.getDefaultAdapter(this)
        setContentView(buildLayout())
        if (adapter == null) {
            Toast.makeText(this, "Kein NFC auf diesem Gerät", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onResume() {
        super.onResume()
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_MUTABLE
        )
        adapter?.enableForegroundDispatch(this, pending, null, null)
    }

    override fun onPause() {
        super.onPause()
        adapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        writeTag(intent)
    }

    private fun buildLayout(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(Color.parseColor("#101317"))
        setPadding(48, 48, 48, 48)
        status = TextView(context).apply {
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = "Chip jetzt an die Rückseite des Handys halten"
        }
        addView(status)
    }

    private fun writeTag(intent: Intent) {
        val tag = NfcSupport.tagFrom(intent)
        if (tag == null) {
            status.text = "Chip nicht lesbar — nochmal versuchen"
            return
        }

        val message = NfcSupport.buildMessage(packageName)
        val written = runCatching {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                if (!ndef.isWritable) throw IllegalStateException("Chip ist schreibgeschützt")
                ndef.writeNdefMessage(message)
                ndef.close()
            } else {
                val formatable = NdefFormatable.get(tag)
                    ?: throw IllegalStateException("Chip nicht beschreibbar")
                formatable.connect()
                formatable.format(message)
                formatable.close()
            }
        }

        written.fold(
            onSuccess = {
                LockEngine(SharedPrefsLockStore(this)).enrollTag(NfcSupport.toHex(tag.id))
                Toast.makeText(this, "Chip angelernt", Toast.LENGTH_SHORT).show()
                setResult(RESULT_OK)
                finish()
            },
            onFailure = { error ->
                status.text = "Fehlgeschlagen: ${error.message ?: "unbekannt"}"
            },
        )
    }
}
```

- [ ] **Step 6: Tests und Kompilierung prüfen**

```bash
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`, 39 Tests grün.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: NFC-Toggle und Chip-Anlernen"
```

---

### Task 13: MethodChannel-Brücke

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/MainActivity.kt`

- [ ] **Step 1: RiegelChannel schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`:

```kotlin
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
```

- [ ] **Step 2: MainActivity anpassen**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/MainActivity.kt` vollständig ersetzen durch:

```kotlin
package com.klaas.nfc_riegel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zustand nach App-Start begradigen: abgelaufener Timer wird sofort aufgelöst.
        LockController(this).expire()
        RiegelChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
```

- [ ] **Step 3: Vollständigen Debug-Build prüfen**

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter build apk --debug
```

Erwartet: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: MethodChannel-Bruecke RiegelChannel"
```

---

### Task 14: Dart — Channel-Client und Zustandsmodell

**Files:**
- Create: `nfc_riegel/lib/lock_status.dart`
- Create: `nfc_riegel/lib/riegel_channel.dart`
- Test: `nfc_riegel/test/lock_status_test.dart`

- [ ] **Step 1: Failing Test schreiben**

`test/lock_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  test('liest die Map aus dem Channel', () {
    final status = LockStatus.fromMap(const {
      'locked': true,
      'mode': 'TIMER',
      'endsAt': 1700000000000,
      'durationMinutes': 45,
      'blockedPackages': ['com.a', 'com.b'],
      'hasTag': true,
      'hasCode': false,
    });

    expect(status.locked, isTrue);
    expect(status.mode, LockMode.timer);
    expect(status.durationMinutes, 45);
    expect(status.blockedPackages, ['com.a', 'com.b']);
    expect(status.hasTag, isTrue);
    expect(status.hasCode, isFalse);
    expect(status.endsAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('endsAt null bleibt null', () {
    final status = LockStatus.fromMap(const {
      'locked': false,
      'mode': 'OPEN',
      'endsAt': null,
      'durationMinutes': 60,
      'blockedPackages': <String>[],
      'hasTag': false,
      'hasCode': false,
    });

    expect(status.endsAt, isNull);
    expect(status.mode, LockMode.open);
  });

  test('Einrichtung ist erst mit Chip und Code abgeschlossen', () {
    LockStatus build({required bool tag, required bool code, required List<String> pkgs}) =>
        LockStatus.fromMap({
          'locked': false,
          'mode': 'TIMER',
          'endsAt': null,
          'durationMinutes': 60,
          'blockedPackages': pkgs,
          'hasTag': tag,
          'hasCode': code,
        });

    expect(build(tag: true, code: true, pkgs: ['com.a']).setupComplete, isTrue);
    expect(build(tag: false, code: true, pkgs: ['com.a']).setupComplete, isFalse);
    expect(build(tag: true, code: false, pkgs: ['com.a']).setupComplete, isFalse);
    expect(build(tag: true, code: true, pkgs: []).setupComplete, isFalse);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter test test/lock_status_test.dart
```

Erwartet: Fehler `Target of URI doesn't exist: 'package:nfc_riegel/lock_status.dart'`.

- [ ] **Step 3: lock_status.dart schreiben**

`lib/lock_status.dart`:

```dart
enum LockMode { open, timer }

/// Dart-Spiegel des nativen Zustands. Nur Lesen — geändert wird nativ.
class LockStatus {
  const LockStatus({
    required this.locked,
    required this.mode,
    required this.endsAt,
    required this.durationMinutes,
    required this.blockedPackages,
    required this.hasTag,
    required this.hasCode,
  });

  final bool locked;
  final LockMode mode;
  final DateTime? endsAt;
  final int durationMinutes;
  final List<String> blockedPackages;
  final bool hasTag;
  final bool hasCode;

  factory LockStatus.fromMap(Map<dynamic, dynamic> map) {
    final endsAtMillis = map['endsAt'] as int?;
    return LockStatus(
      locked: map['locked'] as bool? ?? false,
      mode: map['mode'] == 'OPEN' ? LockMode.open : LockMode.timer,
      endsAt: endsAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAtMillis),
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      blockedPackages:
          (map['blockedPackages'] as List<dynamic>? ?? []).cast<String>(),
      hasTag: map['hasTag'] as bool? ?? false,
      hasCode: map['hasCode'] as bool? ?? false,
    );
  }

  /// Ohne Chip, Code und mindestens eine App ist die Einrichtung unvollständig.
  bool get setupComplete => hasTag && hasCode && blockedPackages.isNotEmpty;
}
```

- [ ] **Step 4: riegel_channel.dart schreiben**

`lib/riegel_channel.dart`:

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

  Future<bool> setBlockedPackages(List<String> packages) async =>
      await channel.invokeMethod<bool>(
        'setBlockedPackages',
        {'packages': packages},
      ) ??
      false;

  Future<bool> setMode(LockMode mode, int durationMinutes) async =>
      await channel.invokeMethod<bool>('setMode', {
        'mode': mode == LockMode.open ? 'OPEN' : 'TIMER',
        'durationMinutes': durationMinutes,
      }) ??
      false;

  Future<String> generateCode() async =>
      await channel.invokeMethod<String>('generateCode') ?? '';

  Future<void> startTagEnrollment() =>
      channel.invokeMethod<void>('startTagEnrollment');

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() => channel.invokeMethod<void>('requestAdmin');
}
```

- [ ] **Step 5: Tests laufen lassen, Erfolg bestätigen**

```bash
flutter test test/lock_status_test.dart
flutter analyze
```

Erwartet: 3 Tests grün, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib nfc_riegel/test
git commit -m "feat: Dart-Zustandsmodell und Channel-Client"
```

---

### Task 15: Dart — Hauptscreen

**Files:**
- Create: `nfc_riegel/lib/home_screen.dart`
- Create: `nfc_riegel/lib/app_picker_screen.dart`
- Modify: `nfc_riegel/lib/main.dart`
- Test: `nfc_riegel/test/home_screen_test.dart`

- [ ] **Step 1: Failing Widget-Test schreiben**

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
            'locked': locked,
            'mode': 'TIMER',
            'endsAt': locked ? DateTime.now().millisecondsSinceEpoch + 60000 : null,
            'durationMinutes': 60,
            'blockedPackages': ['com.instagram.android'],
            'hasTag': true,
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

  testWidgets('zeigt Gesperrt-Status', (tester) async {
    stub(locked: true, accessibility: true);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riegel zu'), findsOneWidget);
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

Erwartet: Fehler `Target of URI doesn't exist: 'package:nfc_riegel/home_screen.dart'`.

- [ ] **Step 3: app_picker_screen.dart schreiben**

`lib/app_picker_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

/// Auswahl der zu sperrenden Apps. Gibt die gewählten Paketnamen zurück.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.selected});

  final List<String> selected;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<AppInfo>? _apps;
  late Set<String> _selected = widget.selected.toSet();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await InstalledApps.getInstalledApps(true, true);
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps sperren'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text('Fertig'),
          ),
        ],
      ),
      body: apps == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return CheckboxListTile(
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  value: _selected.contains(app.packageName),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(app.packageName);
                    } else {
                      _selected.remove(app.packageName);
                    }
                  }),
                );
              },
            ),
    );
  }
}
```

Hinweis zur Paketversion: meldet `flutter analyze` an `app.name` einen
Nullability-Fehler, ist `AppInfo.name` in der installierten `installed_apps`-Version
nullbar. Dann in `app_picker_screen.dart` beide Verwendungen auf
`(app.name ?? app.packageName)` umstellen — sonst nichts ändern.

- [ ] **Step 4: home_screen.dart schreiben**

`lib/home_screen.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';

/// Status, Modus-Einstellung und Blockliste.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.channel = const RiegelChannel()});

  final RiegelChannel channel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LockStatus? _status;
  bool _accessibility = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    final accessibility = await widget.channel.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _status = status;
        _accessibility = accessibility;
      });
    }
  }

  Future<void> _pickApps(LockStatus status) async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(selected: status.blockedPackages),
      ),
    );
    if (picked != null) {
      await widget.channel.setBlockedPackages(picked);
      await _refresh();
    }
  }

  Future<void> _setMode(LockMode mode, int minutes) async {
    await widget.channel.setMode(mode, minutes);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riegel')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_accessibility)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('Sperre nicht wirksam'),
                  subtitle: const Text('Bedienungshilfe ist ausgeschaltet'),
                  trailing: TextButton(
                    onPressed: widget.channel.openAccessibilitySettings,
                    child: const Text('Anschalten'),
                  ),
                ),
              ),
            Card(
              child: ListTile(
                leading: Icon(status.locked ? Icons.lock : Icons.lock_open, size: 40),
                title: Text(
                  status.locked ? 'Riegel zu' : 'Riegel offen',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(_subtitle(status)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Modus', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<LockMode>(
              segments: const [
                ButtonSegment(
                  value: LockMode.open,
                  label: Text('Bis Scan'),
                  icon: Icon(Icons.all_inclusive),
                ),
                ButtonSegment(
                  value: LockMode.timer,
                  label: Text('Auf Zeit'),
                  icon: Icon(Icons.timer_outlined),
                ),
              ],
              selected: {status.mode},
              onSelectionChanged: status.locked
                  ? null
                  : (selection) =>
                      _setMode(selection.first, status.durationMinutes),
            ),
            if (status.mode == LockMode.timer)
              Slider(
                value: status.durationMinutes.toDouble(),
                min: 15,
                max: 480,
                divisions: 31,
                label: '${status.durationMinutes} min',
                onChanged: status.locked
                    ? null
                    : (value) => _setMode(LockMode.timer, value.round()),
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Gesperrte Apps'),
              subtitle: Text('${status.blockedPackages.length} ausgewählt'),
              trailing: const Icon(Icons.chevron_right),
              onTap: status.locked ? null : () => _pickApps(status),
            ),
            if (status.locked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Einstellungen sind während einer Sperre gesperrt.'),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(LockStatus status) {
    if (!status.locked) return 'Chip scannen, um zu sperren';
    final endsAt = status.endsAt;
    if (status.mode == LockMode.timer && endsAt != null) {
      final h = endsAt.hour.toString().padLeft(2, '0');
      final m = endsAt.minute.toString().padLeft(2, '0');
      return 'Frei ab $h:$m oder nach erneutem Scan';
    }
    return 'Frei nach erneutem Scan';
  }
}
```

- [ ] **Step 5: main.dart schreiben**

`lib/main.dart` vollständig ersetzen durch:

```dart
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'setup_wizard.dart';

void main() => runApp(const RiegelApp());

class RiegelApp extends StatelessWidget {
  const RiegelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riegel',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _Entry(),
    );
  }
}

/// Entscheidet beim Start zwischen Einrichtung und Hauptscreen.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  final _channel = const RiegelChannel();
  LockStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _channel.getState();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return status.setupComplete
        ? const HomeScreen()
        : SetupWizard(onFinished: _load);
  }
}
```

- [ ] **Step 6: Tests laufen lassen**

Der Wizard fehlt noch — dieser Schritt schlägt erwartungsgemäß fehl, bis Task 16 fertig ist. Trotzdem ausführen, um den Stand zu sehen:

```bash
flutter analyze
```

Erwartet: Fehler `Target of URI doesn't exist: 'setup_wizard.dart'`. Weiter mit Task 16.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib nfc_riegel/test
git commit -m "feat: Hauptscreen und App-Auswahl"
```

---

### Task 16: Dart — Setup-Wizard

**Files:**
- Create: `nfc_riegel/lib/setup_wizard.dart`

- [ ] **Step 1: setup_wizard.dart schreiben**

`lib/setup_wizard.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';

/// Vier Schritte: Berechtigungen, Apps, Chip, Notfall-Code.
class SetupWizard extends StatefulWidget {
  const SetupWizard({
    super.key,
    required this.onFinished,
    this.channel = const RiegelChannel(),
  });

  final VoidCallback onFinished;
  final RiegelChannel channel;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _step = 0;
  LockStatus? _status;
  String? _code;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    if (mounted) setState(() => _status = status);
  }

  /// Nach dem Anlernen wartet der Wizard darauf, dass die native Seite die UID meldet.
  void _startTagPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await widget.channel.getState();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.hasTag) timer.cancel();
    });
  }

  Future<void> _pickApps() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(selected: _status?.blockedPackages ?? []),
      ),
    );
    if (picked != null) {
      await widget.channel.setBlockedPackages(picked);
      await _refresh();
    }
  }

  Future<void> _generateCode() async {
    final code = await widget.channel.generateCode();
    await _refresh();
    if (mounted) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riegel einrichten')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () => setState(() => _step = (_step + 1).clamp(0, 3)),
        onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 3)),
        controlsBuilder: (context, details) => Row(
          children: [
            if (_step < 3)
              FilledButton(onPressed: details.onStepContinue, child: const Text('Weiter')),
            if (_step == 3)
              FilledButton(
                onPressed: status.setupComplete ? widget.onFinished : null,
                child: const Text('Fertig'),
              ),
            if (_step > 0)
              TextButton(onPressed: details.onStepCancel, child: const Text('Zurück')),
          ],
        ),
        steps: [
          Step(
            title: const Text('Berechtigungen'),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Der Riegel braucht die Bedienungshilfe, um gesperrte Apps zu erkennen, '
                  'und den Geräteadministrator gegen Deinstallation.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: widget.channel.openAccessibilitySettings,
                  child: const Text('Bedienungshilfe öffnen'),
                ),
                OutlinedButton(
                  onPressed: widget.channel.requestAdmin,
                  child: const Text('Geräteadministrator aktivieren'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Apps wählen'),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${status.blockedPackages.length} Apps ausgewählt'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _pickApps, child: const Text('Apps auswählen')),
              ],
            ),
          ),
          Step(
            title: const Text('Chip anlernen'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.hasTag ? 'Chip ist angelernt.' : 'Noch kein Chip angelernt.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await widget.channel.startTagEnrollment();
                    _startTagPolling();
                  },
                  child: Text(status.hasTag ? 'Anderen Chip anlernen' : 'Chip anlernen'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Notfall-Code'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Der Code hebt eine Sperre auf, wenn der Chip nicht zur Hand ist. '
                  'Er wird nur dieses eine Mal angezeigt — aufschreiben.',
                ),
                const SizedBox(height: 12),
                if (_code != null)
                  SelectableText(
                    _code!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                OutlinedButton(
                  onPressed: _generateCode,
                  child: Text(status.hasCode ? 'Neuen Code erzeugen' : 'Code erzeugen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyse und alle Tests laufen lassen**

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter analyze
flutter test
```

Erwartet: `No issues found!` und 6 Dart-Tests grün (3 lock_status + 3 home_screen).

- [ ] **Step 3: Kotlin-Tests und Release-Build prüfen**

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
android/gradlew.bat -p android testDebugUnitTest
flutter build apk --release
```

Erwartet: `BUILD SUCCESSFUL` mit 39 Kotlin-Tests und `✓ Built build\app\outputs\flutter-apk\app-release.apk`.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib
git commit -m "feat: Setup-Wizard"
```

---

### Task 17: Gerätetest und Ablage

Alles, was echtes NFC oder echte Fenster-Events braucht. Ohne Gerät nicht prüfbar — deshalb Checkliste statt Test.

**Files:**
- Create: `nfc_riegel/GERAETETEST.md`
- Copy: `nfc_riegel/build/app/outputs/flutter-apk/app-release.apk` → `C:\Users\klaas\Desktop\Programmieren\APKs\Android\Riegel.apk`

- [ ] **Step 1: Checkliste anlegen**

`nfc_riegel/GERAETETEST.md`:

```markdown
# Gerätetest Riegel

Vor jeder Ablage einer neuen APK durchgehen. Braucht: Android-Handy mit NFC,
einen beschreibbaren NFC-Tag (NTAG213/215/216).

## Einrichtung

- [ ] App startet mit dem Wizard
- [ ] Bedienungshilfe lässt sich aus Schritt 1 heraus anschalten
- [ ] Geräteadministrator lässt sich aus Schritt 1 heraus aktivieren
- [ ] App-Auswahl listet die installierten Apps
- [ ] Chip anlernen: Tag wird beschrieben, Schritt meldet „Chip ist angelernt"
- [ ] Notfall-Code wird angezeigt — aufschreiben
- [ ] Nach „Fertig" erscheint der Hauptscreen

## Sperren und Freigeben

- [ ] Modus „Bis erneuter Scan" wählen, Chip scannen → Meldung „Riegel zu"
- [ ] Gesperrte App öffnen → Sperrschirm erscheint
- [ ] Nicht gesperrte App öffnen → normal nutzbar
- [ ] Chip erneut scannen → „Riegel offen", App wieder nutzbar

## Timer

- [ ] Modus „Auf Zeit" mit 15 Minuten wählen, Chip scannen
- [ ] Sperrschirm zeigt die Restzeit herunterzählend
- [ ] Chip vor Ablauf erneut scannen → sofort frei
- [ ] Neu sperren, Timer ablaufen lassen → Sperre endet von selbst

## Umgehungsschutz

- [ ] Während einer Sperre die Bedienungshilfen-Einstellungen öffnen → Rauswurf
- [ ] Während einer Sperre WLAN-Einstellungen öffnen → bleibt nutzbar
- [ ] Während einer Sperre App deinstallieren wollen → wird verhindert

## Sonderfälle

- [ ] Fremden NFC-Tag scannen → „Fremder Chip", Zustand unverändert
- [ ] Neustart während einer Sperre → Sperre besteht weiter
- [ ] Neustart, nachdem der Timer währenddessen ablief → frei beim Hochfahren
- [ ] Notfall-Code eingeben → Sperre endet
- [ ] Code 3× falsch → Meldung „Zu viele Versuche", 60 s warten
```

- [ ] **Step 2: Checkliste auf dem Gerät abarbeiten**

APK installieren:

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter install --release
```

Dann `GERAETETEST.md` Punkt für Punkt durchgehen. Fehlgeschlagene Punkte notieren und beheben, bevor es weitergeht.

- [ ] **Step 3: APK ablegen**

Laut `Programmieren\CLAUDE.md` gehört jede fertige APK in die feste Ablage:

```bash
cp "/c/Users/klaas/Desktop/Programmieren/nfc_riegel/build/app/outputs/flutter-apk/app-release.apk" \
   "/c/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/GERAETETEST.md
git commit -m "docs: Geraetetest-Checkliste"
```

---

## Abschluss

Nach Task 17:

- `flutter analyze` sauber
- `flutter test` — 6 Tests grün
- `android/gradlew.bat -p android testDebugUnitTest` — 39 Tests grün
- Checkliste in `GERAETETEST.md` vollständig abgehakt
- `Riegel.apk` liegt in `APKs\Android`

Was die Spec bewusst offen lässt und hier deshalb nicht vorkommt: mehrere Profile,
mehrere Chips, iOS, Nutzungsstatistiken.
