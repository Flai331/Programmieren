# Freigabe auf Zeit — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Scan öffnet eine Chipsperre nur noch für eine gewählte Spanne; nach Ablauf sperrt dasselbe Profil ohne weiteren Scan wieder zu.

**Architecture:** Die Chipsperre bleibt im Zustand stehen, daneben tritt ein neues Feld `release` mit Endzeitpunkt. Solange es läuft, zählt die Chipsperre in `LockEngine.lockedProfileIds` nicht — die eine Stelle, an der alle Sperrwirkungen zusammenlaufen. Läuft die Freigabe ab, verschwindet nur das Feld, und die alte Sperre wirkt wieder. Der bestehende Wecker (`LockScheduler`, `TimerReceiver`) bekommt den Endzeitpunkt als weitere Grenze; gefragt wird in einer neuen `ReleaseActivity` aus Kotlin-Views, weil der Scanweg ohne Flutter-Engine läuft.

**Tech Stack:** Kotlin (reine Logik in `LockEngine`, JUnit ohne Emulator), Flutter/Dart für die App-Oberfläche, MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** [`docs/superpowers/specs/2026-09-03-riegel-freigabe-auf-zeit-design.md`](../specs/2026-09-03-riegel-freigabe-auf-zeit-design.md)

**Vor jedem Gradle-Aufruf** (PowerShell, `JAVA_HOME` steht systemweit falsch):

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

---

## Dateien

| Datei | Rolle |
|---|---|
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt` | `Release`-Datenklasse, `Profile.timedRelease` |
| `.../LockState.kt` | `LockState.release`, neue `ScanOutcome`-Werte, `ReleaseOutcome`/`ReleaseResult` |
| `.../LockEngine.kt` | Wirkung, Start, Ablauf, Scan-Wege |
| `.../LockCodec.kt` | Freigabe und neues Profilfeld speichern/lesen |
| `.../SharedPrefsLockStore.kt` | Schlüssel `release` |
| `.../LockController.kt` | Wecker, Durchreichung, Wirkung nachziehen |
| `.../LockNotification.kt` | Text „Frei bis HH:MM" |
| `.../ReleaseActivity.kt` | **neu** — der Dialog beim Aufsperren |
| `.../NfcToggleActivity.kt` | startet den Dialog bei `ASK_RELEASE` |
| `.../RiegelChannel.kt` | Profilfeld und Freigabe über den Kanal |
| `android/app/src/main/AndroidManifest.xml` | Eintrag der `ReleaseActivity` |
| `lib/lock_status.dart` | `ProfileInfo.timedRelease`, `LockStatus.release*` |
| `lib/riegel_channel.dart` | Feld im `updateProfile`-Aufruf |
| `lib/profile_screen.dart` | Schalter „Freigabe auf Zeit" |
| `lib/home_screen.dart` | Statuskachel „Frei bis" |
| `android/app/src/test/.../LockEngineReleaseTest.kt` | **neu** — alle Engine-Fälle |
| `android/app/src/test/.../LockCodecTest.kt` | Speicherformat |
| `test/profile_screen_test.dart`, `test/home_screen_test.dart` | Oberfläche |
| `GERAETETEST.md`, `lib/build_info.dart`, `pubspec.yaml` | Abnahme und Build 17 |

---

### Task 1: Modell und Speicherformat

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

- [ ] **Step 1: Die scheiternden Tests schreiben**

Ans Ende von `LockCodecTest.kt` (innerhalb der Klasse) anfügen:

```kotlin
    @Test
    fun `Freigabe wird geschrieben und gelesen`() {
        val roh = LockCodec.encodeRelease(Release("p1", 1_700_000_000_000L))

        assertEquals(Release("p1", 1_700_000_000_000L), LockCodec.decodeRelease(roh))
    }

    @Test
    fun `leerer Eintrag ist keine Freigabe`() {
        assertNull(LockCodec.decodeRelease(""))
        assertNull(LockCodec.encodeRelease(null).let { LockCodec.decodeRelease(it) })
    }

    @Test
    fun `kaputter Eintrag ist keine Freigabe`() {
        assertNull(LockCodec.decodeRelease("p1"))
    }

    @Test
    fun `Freigabe auf Zeit ueberlebt Schreiben und Lesen`() {
        val p = Profile(id = "p1", name = "Arbeit", timedRelease = true)

        val gelesen = LockCodec.decodeProfiles(LockCodec.encodeProfiles(listOf(p)))

        assertEquals(true, gelesen.single().timedRelease)
    }

    @Test
    fun `Profil ohne das neue Feld liest sich als Freigabe aus`() {
        // Siebzehn Felder — der Stand vor der Freigabe. '\u0002' ist FIELD aus LockCodec. Der Aufbau muss exakt
        // dem von encodeProfiles entsprechen, deshalb hier aus einem Profil
        // erzeugt und das letzte Feld abgeschnitten.
        val mitFeld = LockCodec.encodeProfiles(
            listOf(Profile(id = "p1", name = "Arbeit", timedRelease = true))
        )
        val ohneFeld = mitFeld.substringBeforeLast('\u0002')

        val gelesen = LockCodec.decodeProfiles(ohneFeld)

        assertEquals(1, gelesen.size)
        assertEquals(false, gelesen.single().timedRelease)
    }
```

Falls `assertNull` in der Datei noch nicht importiert ist, oben ergänzen:

```kotlin
import org.junit.Assert.assertNull
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockCodecTest"
```

Erwartet: Übersetzungsfehler — `Release`, `encodeRelease`, `decodeRelease` und `timedRelease` gibt es nicht.

- [ ] **Step 3: Modell ergänzen**

In `Profile.kt` in die `Profile`-Datenklasse nach `pinCalendarEnd` einfügen:

```kotlin
    /**
     * Freigabe auf Zeit: der Chip öffnet die Chipsperre nur für eine gewählte
     * Spanne, danach sperrt dasselbe Profil von selbst wieder. Wirkt allein bei
     * [LockMode.OPEN] — an Zeitsperren kommt der Chip ohnehin nicht.
     */
    val timedRelease: Boolean = false,
```

In `Profile.kt` ans Dateiende anfügen:

```kotlin
/**
 * Eine laufende Freigabe. Hebt die Chipsperre nicht auf, sondern legt sie bis
 * [endsAt] schlafen — fällt sie weg, sperrt dieselbe Chipsperre weiter. Genau
 * deshalb steht sie neben [ChipLock] statt an ihrer Stelle.
 */
data class Release(val profileId: String, val endsAt: Long)
```

In `LockState.kt` in die `LockState`-Datenklasse nach `timeLocks` einfügen:

```kotlin
    /** Höchstens eine — es gibt höchstens eine Chipsperre. */
    val release: Release? = null,
```

- [ ] **Step 4: Speicherformat ergänzen**

In `LockCodec.kt` die Feldzahlen erweitern:

```kotlin
    /** Feldzahlen, die je Ausbaustufe entstanden sind: 7, 10/11, 17, 18. */
    private val GUELTIGE_PROFILFELDER = setOf(7, 10, 11, 17, 18)
```

In `encodeProfiles` als letzten Eintrag der `listOf(...)` — hinter `encodeSchedules(p.quiet.schedules)` — anfügen:

```kotlin
                if (p.timedRelease) "1" else "0",
```

In `decodeProfiles` im `Profile(...)`-Aufruf hinter dem `quiet = …`-Block anfügen:

```kotlin
                timedRelease = f.size >= 18 && f[17] == "1",
```

Hinter `decodeChipLock` in `LockCodec` einfügen:

```kotlin
    /** Freigabe: Profil und Ende. Leer heißt: keine. */
    fun encodeRelease(release: Release?): String =
        release?.let { "${it.profileId}$FIELD${it.endsAt}" } ?: ""

    fun decodeRelease(raw: String): Release? {
        if (raw.isEmpty()) return null
        val f = raw.split(FIELD)
        if (f.size != 2) return null
        val endsAt = f[1].toLongOrNull() ?: return null
        return Release(f[0], endsAt)
    }
```

In `SharedPrefsLockStore.kt` in `load()` im `LockState(...)`-Aufruf nach `timeLocks = …` anfügen:

```kotlin
            release = LockCodec.decodeRelease(prefs.getString(KEY_RELEASE, "") ?: ""),
```

in `save()` in die Kette einfügen:

```kotlin
            .putString(KEY_RELEASE, LockCodec.encodeRelease(state.release))
```

und in das `private companion object`:

```kotlin
        const val KEY_RELEASE = "release"
```

- [ ] **Step 5: Tests laufen lassen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockCodecTest"
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt
git commit -m "feat: Freigabe auf Zeit im Modell und im Speicher"
```

---

### Task 2: Freigabe wirkt und lässt sich starten

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt` (neu)

- [ ] **Step 1: Die scheiternden Tests schreiben**

Neue Datei `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Freigabe auf Zeit: der Chip öffnet nur befristet. */
class LockEngineReleaseTest {

    private val now = 1_000_000L
    private val minute = 60_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.OPEN,
        timedRelease = true,
    )

    private fun engine(
        chipLock: ChipLock? = ChipLock("p1"),
        release: Release? = null,
        timeLocks: List<TimeLock> = emptyList(),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = chipLock,
                release = release,
                timeLocks = timeLocks,
            )
        )
        return LockEngine(store) to store
    }

    @Test
    fun `waehrend der Freigabe ist nichts gesperrt`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertFalse(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `nach dem Ende der Freigabe sperrt dieselbe Chipsperre wieder`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertTrue(e.isBlocked("com.instagram.android", now + 11 * minute))
    }

    @Test
    fun `startRelease setzt das Ende aus der gewaehlten Dauer`() {
        val (e, store) = engine()

        val result = e.startRelease("p1", 15, now)

        assertEquals(ReleaseOutcome.RELEASED, result.outcome)
        assertEquals(Release("p1", now + 15 * minute), store.current.release)
    }

    @Test
    fun `ohne Chipsperre dieses Profils passiert nichts`() {
        val (e, store) = engine(chipLock = null)

        val result = e.startRelease("p1", 15, now)

        assertEquals(ReleaseOutcome.NO_LOCK, result.outcome)
        assertNull(store.current.release)
    }

    @Test
    fun `zu kurze und zu lange Dauer werden geklemmt`() {
        val (e, store) = engine()

        e.startRelease("p1", 0, now)
        assertEquals(now + 1 * minute, store.current.release?.endsAt)

        e.startRelease("p1", 999, now)
        assertEquals(now + 240 * minute, store.current.release?.endsAt)
    }

    @Test
    fun `eine Zeitsperre desselben Profils sperrt trotz Freigabe weiter`() {
        val (e, _) = engine(
            release = Release("p1", now + 10 * minute),
            timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 30 * minute)),
        )

        assertTrue(e.isBlocked("com.instagram.android", now))
    }

    @Test
    fun `die Freigabe eines Profils oeffnet kein anderes`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(
                    arbeit,
                    Profile(
                        id = "p2",
                        name = "Nacht",
                        blockedPackages = setOf("com.zhiliaoapp.musically"),
                        defaultMode = LockMode.TIMER,
                    ),
                ),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 30 * minute)),
            )
        )
        val e = LockEngine(store)

        assertFalse(e.isBlocked("com.instagram.android", now))
        assertTrue(e.isBlocked("com.zhiliaoapp.musically", now))
    }

    @Test
    fun `eine laufende Freigabe zaehlt als aktive Sperre nicht`() {
        val (e, _) = engine(release = Release("p1", now + 10 * minute))

        assertFalse(e.hasActiveLock(now))
        assertNotNull(e.state().chipLock)
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockEngineReleaseTest"
```

Erwartet: Übersetzungsfehler — `ReleaseOutcome` und `startRelease` gibt es nicht.

- [ ] **Step 3: Ergebnistypen anlegen**

In `LockState.kt` hinter `data class StartResult(...)` einfügen:

```kotlin
enum class ReleaseOutcome {
    RELEASED,

    /** Keine Chipsperre dieses Profils läuft — es gibt nichts freizugeben. */
    NO_LOCK,
}

data class ReleaseResult(val state: LockState, val outcome: ReleaseOutcome)
```

- [ ] **Step 4: Engine ergänzen**

In `LockEngine.kt` neben `activeChipLock` einfügen:

```kotlin
    /** Die laufende Freigabe, oder null. Eine abgelaufene zählt nicht. */
    private fun activeRelease(s: LockState, now: Long): Release? =
        s.release?.takeIf { now < it.endsAt }
```

`lockedProfileIds` ersetzen durch:

```kotlin
    /**
     * Profile, die gerade sperren — über die Chipsperre, eine Zeitsperre oder ein
     * laufendes Terminfenster. Grundlage der Blockliste und aller Wächter.
     *
     * Hier und nur hier wirkt die Freigabe: die Chipsperre bleibt stehen, zählt
     * aber nicht, solange eine Freigabe für ihr Profil läuft.
     */
    private fun lockedProfileIds(s: LockState, now: Long): Set<String> = buildSet {
        val freigabe = activeRelease(s, now)
        activeChipLock(s, now)
            ?.takeIf { it.profileId != freigabe?.profileId }
            ?.let { add(it.profileId) }
        activeTimeLocks(s, now).forEach { add(it.profileId) }
        addAll(CalendarPlanner.lockedProfileIds(s.calendar, now))
    }
```

Hinter `startChipLock` einfügen:

```kotlin
    /**
     * Freigabe auf Zeit. Legt die laufende Chipsperre bis [minutes] Minuten in
     * der Zukunft schlafen. Gelöscht wird sie nicht — deshalb sperrt sie danach
     * ohne weiteres Zutun wieder.
     */
    fun startRelease(profileId: String, minutes: Int, now: Long): ReleaseResult {
        val s = store.load()
        if (s.chipLock?.profileId != profileId) {
            return ReleaseResult(s, ReleaseOutcome.NO_LOCK)
        }
        val geklemmt = minutes.coerceIn(MIN_RELEASE_MINUTES, MAX_RELEASE_MINUTES)
        val next = s.copy(release = Release(profileId, now + geklemmt * 60_000L))
        store.save(next)
        return ReleaseResult(next, ReleaseOutcome.RELEASED)
    }
```

Im `private companion object` von `LockEngine` — dort, wo `MAX_ATTEMPTS` und `LOCKOUT_MILLIS` stehen — ergänzen:

```kotlin
        /** Kürzer als eine Minute ist keine Freigabe, länger als vier Stunden keine kurze. */
        const val MIN_RELEASE_MINUTES = 1
        const val MAX_RELEASE_MINUTES = 240
```

- [ ] **Step 5: Tests laufen lassen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockEngineReleaseTest"
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt
git commit -m "feat: Freigabe legt die Chipsperre auf Zeit schlafen"
```

---

### Task 3: Ablauf, Neustart und Aufräumen

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt`

- [ ] **Step 1: Die scheiternden Tests schreiben**

In `LockEngineReleaseTest.kt` innerhalb der Klasse anfügen:

```kotlin
    @Test
    fun `abgelaufene Freigabe faellt beim Weckerlauf weg`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.onTimerElapsed(now + 11 * minute)

        assertNull(store.current.release)
        assertNotNull(store.current.chipLock)
    }

    @Test
    fun `laufende Freigabe bleibt beim Weckerlauf stehen`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.onTimerElapsed(now + 5 * minute)

        assertEquals(Release("p1", now + 10 * minute), store.current.release)
    }

    @Test
    fun `ein Neustart traegt die laufende Freigabe weiter`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.restoreAfterBoot(now + 5 * minute)

        assertEquals(Release("p1", now + 10 * minute), store.current.release)
        assertFalse(e.isBlocked("com.instagram.android", now + 5 * minute))
    }

    @Test
    fun `ein Neustart nach dem Ende sperrt wieder`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        e.restoreAfterBoot(now + 20 * minute)

        assertNull(store.current.release)
        assertTrue(e.isBlocked("com.instagram.android", now + 20 * minute))
    }

    @Test
    fun `der Notfall-Code raeumt Chipsperre und Freigabe zusammen weg`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                chipLock = ChipLock("p1"),
                release = Release("p1", now + 10 * minute),
                codeHash = Hashing.sha256("FZ9HK39D"),
            )
        )
        val e = LockEngine(store)

        val result = e.submitCode("fz9hk39d", now)

        assertEquals(CodeOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `der Generalschluessel raeumt die Freigabe mit weg`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                tags = listOf(TagBinding("04CC", "Schlüsselbund", "p1", isMaster = true)),
                chipLock = ChipLock("p1"),
                timeLocks = listOf(TimeLock("p1", LockMode.TIMER, now + 30 * minute)),
                release = Release("p1", now + 10 * minute),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04CC", now)

        assertEquals(ScanOutcome.MASTER_CLEARED, result.outcome)
        assertNull(store.current.release)
    }
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockEngineReleaseTest"
```

Erwartet: FAIL in `abgelaufene Freigabe faellt beim Weckerlauf weg` (die Freigabe bleibt stehen) und in beiden Aufräum-Tests.

- [ ] **Step 3: Ablauf und Aufräumen einbauen**

In `LockEngine.kt` `onTimerElapsed` ersetzen durch:

```kotlin
    /**
     * Vom Alarm gerufen. Räumt jede abgelaufene Zeitsperre ab — auch mehrere
     * zugleich — und dazu eine abgelaufene Freigabe. Die Uhrzeit entscheidet,
     * nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val verbleibend = s.timeLocks.filter { now < it.endsAt }
        val freigabe = activeRelease(s, now)
        if (verbleibend.size == s.timeLocks.size && freigabe == s.release) return s
        val next = s.copy(timeLocks = verbleibend, release = freigabe)
        store.save(next)
        return next
    }
```

In `clearAll` in den `s.copy(...)`-Aufruf nach `timeLocks = emptyList(),` einfügen:

```kotlin
            release = null,
```

`clearChipLock` ersetzen durch:

```kotlin
    /**
     * Beendet nur die Chipsperre. Eine Freigabe fällt mit weg — sie war die
     * Aussetzung genau dieser Sperre. Zeitsperren bleiben stehen; ein normaler
     * Chip kommt an sie nicht heran.
     */
    private fun clearChipLock(s: LockState): LockState {
        val next = s.copy(chipLock = null, release = null)
        store.save(next)
        return next
    }
```

- [ ] **Step 4: Tests laufen lassen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockEngineReleaseTest"
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt
git commit -m "feat: Freigabe laeuft ab und wird mit aufgeraeumt"
```

---

### Task 4: Die Scan-Wege

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt`

- [ ] **Step 1: Die scheiternden Tests schreiben**

In `LockEngineReleaseTest.kt` innerhalb der Klasse anfügen:

```kotlin
    @Test
    fun `Scan bei eingeschaltetem Schalter fragt statt zu oeffnen`() {
        val (e, store) = engine()

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.ASK_RELEASE, result.outcome)
        assertNotNull(store.current.chipLock)
        assertNull(store.current.release)
    }

    @Test
    fun `Scan bei ausgeschaltetem Schalter oeffnet wie bisher`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit.copy(timedRelease = false)),
                tags = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
                chipLock = ChipLock("p1"),
            )
        )
        val e = LockEngine(store)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.UNLOCKED, result.outcome)
        assertNull(store.current.chipLock)
    }

    @Test
    fun `Scan waehrend der Freigabe sperrt sofort wieder`() {
        val (e, store) = engine(release = Release("p1", now + 10 * minute))

        val result = e.onTagScanned("04AA", now + 2 * minute)

        assertEquals(ScanOutcome.RELOCKED, result.outcome)
        assertNull(store.current.release)
        assertNotNull(store.current.chipLock)
        assertTrue(e.isBlocked("com.instagram.android", now + 2 * minute))
    }

    @Test
    fun `Scan ohne laufende Sperre sperrt wie bisher zu`() {
        val (e, store) = engine(chipLock = null)

        val result = e.onTagScanned("04AA", now)

        assertEquals(ScanOutcome.LOCKED, result.outcome)
        assertEquals(ChipLock("p1"), store.current.chipLock)
        assertNull(store.current.release)
    }
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockEngineReleaseTest"
```

Erwartet: Übersetzungsfehler — `ASK_RELEASE` und `RELOCKED` gibt es in `ScanOutcome` nicht.

- [ ] **Step 3: Ergebniswerte und Scan-Zweig einbauen**

In `LockState.kt` in `enum class ScanOutcome` nach `UNLOCKED,` einfügen:

```kotlin
    /** Freigabe lief, der Scan hat sie beendet — es ist wieder zu. */
    RELOCKED,

    /** Chipsperre ließe sich öffnen, das Profil will aber vorher nach der Dauer gefragt werden. */
    ASK_RELEASE,
```

In `LockEngine.onTagScanned` den Block ab `val active = activeChipLock(s, now)` bis zum Ende der Funktion ersetzen durch:

```kotlin
        val active = activeChipLock(s, now)
        if (active != null && active.profileId == profile.id) {
            // Reihenfolge zählt: erst die laufende Freigabe beenden, dann erst
            // fragen. Andersherum käme mitten in der Freigabe wieder der Dialog,
            // statt dass der Riegel zugeht.
            if (activeRelease(s, now)?.profileId == profile.id) {
                val next = s.copy(release = null)
                store.save(next)
                return ScanResult(next, ScanOutcome.RELOCKED)
            }
            if (profile.timedRelease) return ScanResult(s, ScanOutcome.ASK_RELEASE)
            return ScanResult(clearChipLock(s), ScanOutcome.UNLOCKED)
        }

        val next = s.copy(chipLock = ChipLock(profile.id))
        store.save(next)
        return ScanResult(
            next,
            if (active != null) ScanOutcome.SWITCHED else ScanOutcome.LOCKED,
        )
    }
```

- [ ] **Step 4: Alle Kotlin-Tests laufen lassen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL` — auch `LockEngineToggleTest` und `LockEngineBlockTest` laufen weiter, weil `timedRelease` standardmäßig aus ist.

- [ ] **Step 5: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineReleaseTest.kt
git commit -m "feat: Scan fragt nach der Freigabe und sperrt sie vorzeitig zu"
```

---

### Task 5: Wecker, Durchreichung und Benachrichtigung

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt`

Kein eigener Test: beide Klassen fassen Android an (`AlarmManager`, `NotificationManager`) und sind deshalb bewusst dünn — die Rechnung dahinter steckt in der Engine und ist in Task 2–4 abgedeckt.

- [ ] **Step 1: Controller ergänzen**

In `LockController.kt` hinter `startLock` einfügen:

```kotlin
    /**
     * Freigabe auf Zeit, gerufen aus der [ReleaseActivity]. Zieht Wecker und
     * Benachrichtigung sofort nach — der Wecker ist es, der die Sperre später
     * ohne Zutun wieder greifen lässt.
     */
    fun startRelease(
        profileId: String,
        minutes: Int,
        now: Long = System.currentTimeMillis(),
    ): ReleaseOutcome {
        val result = engine.startRelease(profileId, minutes, now)
        applyEffects(result.state, now)
        return result.outcome
    }
```

In `naechsterWecker` nach der Zeile mit `state.timeLocks.minOfOrNull { it.endsAt }` einfügen:

```kotlin
        state.release?.endsAt?.takeIf { now < it }?.let { kandidaten += it }
```

In `applyEffects` den Aufruf `LockNotification.show(context, state)` ersetzen durch:

```kotlin
            LockNotification.show(context, state, now)
```

- [ ] **Step 2: Benachrichtigung ergänzen**

In `LockNotification.kt` den Kopf von `show` ersetzen durch:

```kotlin
    fun show(context: Context, state: LockState, now: Long = System.currentTimeMillis()) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val freigabe = state.release?.takeIf { now < it.endsAt }
```

Den `text`-Block ersetzen durch:

```kotlin
        val fruehestesEnde = state.timeLocks.minOfOrNull { it.endsAt }
        val text = when {
            freigabe != null -> "Frei bis ${uhrzeit(freigabe.endsAt)} — danach wieder zu"
            fruehestesEnde != null && state.chipLock != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)}, der Rest nach erneutem Scan"
            fruehestesEnde != null ->
                "Frei ab ${uhrzeit(fruehestesEnde)} — vorher nur mit Generalschlüssel"
            else -> "Chip scannen, um freizugeben"
        }
```

Und den Titel — im `Notification.Builder`-Aufruf `setContentTitle(...)` — ersetzen durch:

```kotlin
            .setContentTitle(
                if (freigabe != null) {
                    "Freigabe läuft — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}"
                } else {
                    "Riegel aktiv — ${namen.joinToString(", ").ifEmpty { "Unbekannt" }}, " +
                        "$anzahlApps Apps gesperrt"
                }
            )
```

- [ ] **Step 3: Übersetzen und alle Tests laufen lassen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel\android; .\gradlew.bat :app:testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt
git commit -m "feat: Wecker und Benachrichtigung kennen die Freigabe"
```

---

### Task 6: Der Dialog beim Aufsperren

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/ReleaseActivity.kt`
- Modify: `nfc_riegel/android/app/src/main/AndroidManifest.xml`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt`

Kein Unit-Test: reine Oberfläche ohne Rechnung. Geprüft wird sie im Gerätetest (Task 10).

- [ ] **Step 1: Die Activity anlegen**

Neue Datei `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/ReleaseActivity.kt`:

```kotlin
package com.klaas.nfc_riegel

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Fragt beim Aufsperren, wie lange offen bleiben soll. Vier Stufen und ein Feld
 * für eigene Zahlen; Abbrechen lässt die Sperre stehen.
 *
 * Kotlin-Views wie [PauseActivity] und [BlockActivity]: der Scanweg startet ohne
 * Flutter-Engine, und daran soll ein Dialog nichts ändern.
 */
class ReleaseActivity : Activity() {

    private lateinit var eingabe: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
    }

    private fun oeffne(minuten: Int) {
        val profileId = intent?.getStringExtra(EXTRA_PROFILE_ID) ?: ""
        val meldung = when (LockController(this).startRelease(profileId, minuten)) {
            ReleaseOutcome.RELEASED -> "Frei für $minuten Minuten"
            ReleaseOutcome.NO_LOCK -> "Keine Sperre dieses Profils"
        }
        Toast.makeText(this, meldung, Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BlockColors.BACKGROUND)
            setPadding(dp(32), dp(40), dp(32), dp(32))
        }

        val titel = TextView(this).apply {
            text = "Wie lange offen?"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(BlockColors.FG_1)
            gravity = Gravity.CENTER
        }

        val profil = TextView(this).apply {
            text = intent?.getStringExtra(EXTRA_PROFILE_NAME) ?: "Riegel"
            textSize = 15f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(28))
        }

        val stufen = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
        for ((index, minuten) in STUFEN.withIndex()) {
            stufen.addView(
                Button(this).apply {
                    text = "$minuten"
                    textSize = 16f
                    isAllCaps = false
                    setTextColor(BlockColors.FG_1)
                    background = roundedRect(BlockColors.SURFACE, dp(10), BlockColors.BORDER)
                    layoutParams = LinearLayout.LayoutParams(
                        0,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        1f,
                    ).apply { if (index > 0) leftMargin = dp(8) }
                    setOnClickListener { oeffne(minuten) }
                }
            )
        }

        val einheit = TextView(this).apply {
            text = "Minuten"
            textSize = 13f
            setTextColor(BlockColors.FG_4)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(20))
        }

        eingabe = EditText(this).apply {
            hint = "eigene Minuten"
            inputType = InputType.TYPE_CLASS_NUMBER
            textSize = 16f
            setTextColor(BlockColors.FG_1)
            setHintTextColor(BlockColors.FG_4)
            background = roundedRect(BlockColors.SURFACE, dp(10), BlockColors.BORDER)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        val oeffnen = Button(this).apply {
            text = "Öffnen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.BACKGROUND)
            background = roundedRect(BlockColors.ACCENT, dp(10))
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            setOnClickListener {
                val minuten = eingabe.text.toString().toIntOrNull()
                if (minuten == null) {
                    Toast.makeText(this@ReleaseActivity, "Zahl eingeben", Toast.LENGTH_SHORT).show()
                } else {
                    oeffne(minuten)
                }
            }
        }

        val abbrechen = Button(this).apply {
            text = "Abbrechen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.FG_2)
            background = roundedRect(Color.TRANSPARENT, dp(10), BlockColors.BORDER)
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            // Abbruch heißt Abbruch: es bleibt zu, der Zustand wird nicht angefasst.
            setOnClickListener { finish() }
        }

        root.addView(titel)
        root.addView(profil)
        root.addView(stufen)
        root.addView(einheit)
        root.addView(eingabe)
        root.addView(oeffnen)
        root.addView(abbrechen)
        return root
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
        const val EXTRA_PROFILE_ID = "profilId"
        const val EXTRA_PROFILE_NAME = "profilName"

        /** Kurze Stufen — eine Freigabe ist eine Unterbrechung, kein halber Tag. */
        val STUFEN = listOf(5, 10, 15, 30)
    }
}
```

- [ ] **Step 2: Ins Manifest eintragen**

In `nfc_riegel/android/app/src/main/AndroidManifest.xml` hinter dem `<activity android:name=".PauseActivity" …/>`-Block einfügen:

```xml
        <!--
            Wie Sperr- und Pausenschirm eine eigene Aufgabe: der Dialog kommt aus
            einem Chip-Scan heraus, nicht aus der App, und darf sie nicht in den
            Vordergrund ziehen.
        -->
        <activity
            android:name=".ReleaseActivity"
            android:exported="false"
            android:launchMode="singleTask"
            android:taskAffinity=""
            android:excludeFromRecents="true"
            android:theme="@android:style/Theme.DeviceDefault.NoActionBar"/>
```

- [ ] **Step 3: Den Scan den Dialog starten lassen**

In `NfcToggleActivity.kt` in `handle` nach der Zeile `val profileName = profileId?.let { … } ?: "Riegel"` einfügen:

```kotlin
        if (result.outcome == ScanOutcome.ASK_RELEASE) {
            // Der Zustand ist unverändert — gefragt wird erst, gesperrt bleibt es
            // so lange. Das Profil steckt am Chip, nicht in der Sperre.
            val chip = state.tagByUid(uid)
            val gefragtesProfil = chip?.profileId?.let { state.profileById(it) }
            startActivity(
                Intent(this, ReleaseActivity::class.java)
                    .putExtra(ReleaseActivity.EXTRA_PROFILE_ID, gefragtesProfil?.id ?: "")
                    .putExtra(ReleaseActivity.EXTRA_PROFILE_NAME, gefragtesProfil?.name ?: "Riegel")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            finish()
            return
        }
```

Und in das `when (result.outcome)` zwei Zeilen ergänzen:

```kotlin
            ScanOutcome.RELOCKED -> "Riegel wieder zu — $profileName"
            ScanOutcome.ASK_RELEASE -> "Riegel offen"
```

(Der `ASK_RELEASE`-Zweig wird nie erreicht — der frühe Ausstieg oben fängt ihn ab —, aber `when` über ein `enum` muss vollständig sein.)

- [ ] **Step 4: Übersetzen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat build apk --release
```

Erwartet: `√ Built build\app\outputs\flutter-apk\app-release.apk`.

- [ ] **Step 5: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/ReleaseActivity.kt nfc_riegel/android/app/src/main/AndroidManifest.xml nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt
git commit -m "feat: Dialog fragt beim Aufsperren nach der Freigabe"
```

---

### Task 7: Kanal und Dart-Modell

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`
- Modify: `nfc_riegel/lib/lock_status.dart`
- Modify: `nfc_riegel/lib/riegel_channel.dart`
- Modify: `nfc_riegel/test/lock_status_test.dart`

- [ ] **Step 1: Den scheiternden Test schreiben**

Die Datei gibt es schon. Ihren Helfer `stateMap` um zwei Angaben erweitern —
Kopf ersetzen durch:

```dart
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>>? timeLocks,
    List<Map<String, dynamic>>? tags,
    bool hasMasterTag = true,
    bool hasCode = true,
    Map<String, dynamic>? release,
    bool timedRelease = false,
  }) => {
```

im ersten Profil (`'id': 'p1'`) nach `'pinCalendarEnd': false,` einfügen:

```dart
        'timedRelease': timedRelease,
```

und hinter der Zeile `'chipLock': chipLock,` einfügen:

```dart
    'release': release,
```

Dann innerhalb von `main()` die Tests anfügen:

```dart
  test('Freigabe auf Zeit kommt am Profil an', () {
    final status = LockStatus.fromMap(stateMap(timedRelease: true));

    expect(status.profiles.first.timedRelease, isTrue);
  });

  test('ohne Freigabe sperrt die Chipsperre', () {
    final status = LockStatus.fromMap(stateMap(chipLock: {'profileId': 'p1'}));

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.releaseEndsAt, isNull);
  });

  test('mit laufender Freigabe gilt das Profil als offen', () {
    final ende = DateTime.now().add(const Duration(minutes: 10));

    final status = LockStatus.fromMap(
      stateMap(
        chipLock: {'profileId': 'p1'},
        release: {'profileId': 'p1', 'endsAt': ende.millisecondsSinceEpoch},
      ),
    );

    expect(status.isProfileLocked('p1'), isFalse);
    expect(status.locked, isFalse);
    expect(status.releaseProfileId, 'p1');
    expect(status.releaseEndsAt, isNotNull);
  });
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test test/lock_status_test.dart
```

Erwartet: Übersetzungsfehler — `timedRelease`, `releaseProfileId` und `releaseEndsAt` gibt es nicht.

- [ ] **Step 3: Kanal ergänzen**

In `RiegelChannel.kt` im `"updateProfile"`-Zweig nach `pinCalendarEnd = …` einfügen:

```kotlin
                        timedRelease = call.argument<Boolean>("timedRelease") ?: false,
```

In `stateMap()` in der Profilkarte nach `"pinCalendarEnd" to p.pinCalendarEnd,` einfügen:

```kotlin
                    "timedRelease" to p.timedRelease,
```

und in derselben Karte hinter der Zeile `"chipLock" to s.chipLock?.let { … },` einfügen:

```kotlin
            // Abgelaufene Freigaben gehen gar nicht erst raus — die Oberfläche
            // soll die Uhrzeitrechnung nicht ein zweites Mal machen.
            "release" to s.release?.takeIf { now < it.endsAt }?.let {
                mapOf("profileId" to it.profileId, "endsAt" to it.endsAt)
            },
```

- [ ] **Step 4: Dart-Modell ergänzen**

In `lib/lock_status.dart` in `ProfileInfo`: in den Konstruktor nach `required this.pinCalendarEnd,` einfügen:

```dart
    required this.timedRelease,
```

nach `final bool pinCalendarEnd;` einfügen:

```dart
  /// Der Chip öffnet dieses Profil nur für eine gewählte Spanne.
  final bool timedRelease;
```

und in `ProfileInfo.fromMap` nach `pinCalendarEnd: …` einfügen:

```dart
      timedRelease: map['timedRelease'] as bool? ?? false,
```

In `LockStatus`: in den Konstruktor nach `required this.chipLockProfileId,` einfügen:

```dart
    required this.releaseProfileId,
    required this.releaseEndsAt,
```

nach `final String? chipLockProfileId;` einfügen:

```dart
  /// Profil der laufenden Freigabe, oder null. Die native Seite schickt
  /// abgelaufene gar nicht erst mit.
  final String? releaseProfileId;
  final DateTime? releaseEndsAt;
```

in `LockStatus.fromMap` vor dem `return` einfügen:

```dart
    final release = map['release'] as Map<dynamic, dynamic>?;
```

und im `return` nach `chipLockProfileId: …` einfügen:

```dart
      releaseProfileId: release?['profileId'] as String?,
      releaseEndsAt: release?['endsAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(release!['endsAt'] as int),
```

`lockedProfileIds` ersetzen durch:

```dart
  /// Alle Profile, die gerade sperren — über alle drei Quellen. Die Chipsperre
  /// zählt nicht, solange ihr Profil freigegeben ist; dieselbe Regel wie in
  /// `LockEngine.lockedProfileIds`.
  Set<String> get lockedProfileIds => {
    if (chipLockProfileId != null && chipLockProfileId != releaseProfileId)
      chipLockProfileId!,
    ...timeLocks.map((l) => l.profileId),
    ...calendar.activeWindows.map((w) => w.profileId),
  };
```

`locked` ersetzen durch:

```dart
  bool get locked => lockedProfileIds.isNotEmpty;
```

- [ ] **Step 5: Kanalaufruf ergänzen**

In `lib/riegel_channel.dart` in `updateProfile` in die Karte nach `'pinCalendarEnd': profile.pinCalendarEnd,` einfügen:

```dart
          'timedRelease': profile.timedRelease,
```

- [ ] **Step 6: Tests laufen lassen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test
```

Erwartet: Fehlschlag in `test/profile_screen_test.dart` und anderen Dateien, die `ProfileInfo(...)` bauen — das Pflichtfeld `timedRelease` fehlt dort. In **jedem** `ProfileInfo(...)`-Aufruf in `test/` `timedRelease: false,` nach `pinCalendarEnd: false,` ergänzen, dann erneut laufen lassen. Erwartet: `All tests passed!`.

- [ ] **Step 7: Committen**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt nfc_riegel/lib/lock_status.dart nfc_riegel/lib/riegel_channel.dart nfc_riegel/test
git commit -m "feat: Freigabe und ihr Schalter gehen ueber den Kanal"
```

---

### Task 8: Der Schalter am Profil

**Files:**
- Modify: `nfc_riegel/lib/profile_screen.dart`
- Test: `nfc_riegel/test/profile_screen_test.dart`

- [ ] **Step 1: Die scheiternden Tests schreiben**

In `test/profile_screen_test.dart` innerhalb von `main()` anfügen:

```dart
  testWidgets('bei Modus Offen erscheint der Schalter der Freigabe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          profile: profil.copyWithModeOpen(),
          channel: RiegelChannel(channel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Freigabe auf Zeit'), findsOneWidget);
  });

  testWidgets('bei Modus Auf Zeit fehlt der Schalter der Freigabe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Freigabe auf Zeit'), findsNothing);
  });

  testWidgets('eingeschaltete Freigabe landet im Kanalaufruf', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          profile: profil.copyWithModeOpen(),
          channel: RiegelChannel(channel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final schalter = find.widgetWithText(SwitchListTile, 'Freigabe auf Zeit');
    await tester.ensureVisible(schalter);
    await tester.pumpAndSettle();
    await tester.tap(schalter);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['timedRelease'], isTrue);
  });
```

Und am Dateiende, außerhalb von `main()`, den kleinen Helfer anlegen:

```dart
extension on ProfileInfo {
  /// Dasselbe Profil im Modus „Offen" — nur dort gibt es die Freigabe.
  ProfileInfo copyWithModeOpen() => ProfileInfo(
    id: id,
    name: name,
    blockedPackages: blockedPackages,
    mode: LockMode.open,
    durationMinutes: durationMinutes,
    untilAt: untilAt,
    pinCalendarEnd: pinCalendarEnd,
    timedRelease: timedRelease,
    pauseEnabled: pauseEnabled,
    pauseStepMinutes: pauseStepMinutes,
    pauseBaseSeconds: pauseBaseSeconds,
    pauseResetMinutes: pauseResetMinutes,
    quietEnabled: quietEnabled,
    quietScope: quietScope,
    quietNumbers: quietNumbers,
    quietAfterEventMinutes: quietAfterEventMinutes,
    quietWhileLocked: quietWhileLocked,
    quietSchedules: quietSchedules,
  );
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test test/profile_screen_test.dart
```

Erwartet: FAIL — „Freigabe auf Zeit" wird nicht gefunden.

- [ ] **Step 3: Schalter einbauen**

In `lib/profile_screen.dart` neben `late bool _pin = widget.profile.pinCalendarEnd;` einfügen:

```dart
  late bool _timedRelease = widget.profile.timedRelease;
```

Im `build` unmittelbar vor der Zeile `const SizedBox(height: RiegelSpacing.s6),`, die dem `SwitchListTile` mit `'Kalender-Ende festnageln'` vorausgeht, einfügen:

```dart
          // Nur bei „Offen": Zeitsperren lassen sich ohnehin nicht per Chip
          // aufmachen, ein Schalter dafür wäre eine leere Zusage.
          if (_mode == LockMode.open)
            SwitchListTile(
              value: _timedRelease,
              onChanged: (v) => setState(() => _timedRelease = v),
              title: const Text('Freigabe auf Zeit'),
              subtitle: const Text(
                'Der Chip öffnet nur für eine gewählte Zeit. Danach sperrt es '
                'von selbst wieder.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
```

In `_save` in den `ProfileInfo(...)`-Aufruf nach `pinCalendarEnd: _pin,` einfügen:

```dart
        timedRelease: _timedRelease,
```

In `lib/riegel_channel.dart` die Protokollzeile in `updateProfile` erweitern — nach `'Atempause ${profile.pauseEnabled ? "an" : "aus"}, '`:

```dart
      'Freigabe ${profile.timedRelease ? "an" : "aus"}, '
```

- [ ] **Step 4: Tests laufen lassen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test
```

Erwartet: `All tests passed!`.

- [ ] **Step 5: Committen**

```bash
git add nfc_riegel/lib/profile_screen.dart nfc_riegel/lib/riegel_channel.dart nfc_riegel/test/profile_screen_test.dart
git commit -m "feat: Schalter Freigabe auf Zeit am Profil"
```

---

### Task 9: Die Statuskachel

**Files:**
- Modify: `nfc_riegel/lib/home_screen.dart`
- Test: `nfc_riegel/test/home_screen_test.dart`

- [ ] **Step 1: Den scheiternden Test schreiben**

In `nfc_riegel/test/home_screen_test.dart` den vorhandenen `stub`-Helfer um die
Freigabe erweitern — in die Parameterliste aufnehmen:

```dart
    Map<String, dynamic>? release,
```

und in der `getState`-Antwort hinter `'chipLock': chipLock,` einfügen:

```dart
                'release': release,
```

Dann den Test anfügen:

```dart
  testWidgets('laufende Freigabe steht in der Statuskachel', (tester) async {
    final ende = DateTime.now().add(const Duration(minutes: 12));
    stub(
      accessibility: true,
      defaultMode: 'OPEN',
      chipLock: {'profileId': 'p1'},
      release: {'profileId': 'p1', 'endsAt': ende.millisecondsSinceEpoch},
    );
    await zeige(tester);

    expect(find.textContaining('frei bis'), findsOneWidget);
    expect(find.text('Riegel offen'), findsOneWidget);
    expect(find.text('Riegel zu'), findsNothing);
  });
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test test/home_screen_test.dart
```

Erwartet: FAIL — „Frei bis" steht nicht in der Kachel.

- [ ] **Step 3: Kachel ergänzen**

In `lib/home_screen.dart` in `_subtitle` ganz am Anfang der Funktion einfügen:

```dart
    // Die Freigabe geht allem vor: sie ist der Grund, aus dem gerade nichts
    // sperrt, und nennt zugleich den Zeitpunkt, ab dem es wieder sperrt.
    final freigabe = status.releaseEndsAt;
    if (freigabe != null) {
      final profil = status.profiles
          .where((p) => p.id == status.releaseProfileId)
          .map((p) => p.name)
          .join(', ');
      return '$profil — frei bis ${_hhmm(freigabe)}';
    }
```

- [ ] **Step 4: Tests laufen lassen**

```powershell
cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test
```

Erwartet: `All tests passed!`.

- [ ] **Step 5: Committen**

```bash
git add nfc_riegel/lib/home_screen.dart nfc_riegel/test/home_screen_test.dart
git commit -m "feat: Statuskachel zeigt die laufende Freigabe"
```

---

### Task 10: Abnahme, Build 17, Ablage

**Files:**
- Modify: `nfc_riegel/GERAETETEST.md`
- Modify: `nfc_riegel/lib/build_info.dart`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Step 1: Prüfliste ergänzen**

In `nfc_riegel/GERAETETEST.md` einen Abschnitt anfügen:

```markdown
## Freigabe auf Zeit

- [ ] Profil im Modus „Offen", Schalter „Freigabe auf Zeit" an, Chip scannen →
      es sperrt.
- [ ] Erneut scannen → der Dialog „Wie lange offen?" kommt, die Sperre steht
      weiter.
- [ ] Abbrechen → es bleibt zu, gesperrte App wird weiter geblockt.
- [ ] Erneut scannen, 5 Minuten wählen → gesperrte App geht auf, die
      Benachrichtigung sagt „Frei bis HH:MM", die Statuskachel „frei bis".
- [ ] Bildschirm aus, fünf Minuten warten, gesperrte App öffnen → sie ist
      wieder gesperrt (Wecker greift auch im Doze).
- [ ] Neue Freigabe starten, währenddessen scannen → sofort wieder zu.
- [ ] Neue Freigabe starten, Gerät neu starten → die Freigabe läuft weiter und
      endet zur ursprünglichen Zeit.
- [ ] Freigabe läuft, Generalschlüssel scannen → alles offen, nach Ablauf der
      alten Freigabezeit bleibt es offen.
- [ ] Schalter aus, Chip scannen → öffnet dauerhaft wie bisher, kein Dialog.
```

- [ ] **Step 2: Build-Nummer erhöhen**

In `nfc_riegel/lib/build_info.dart`:

```dart
const int kBuildNumber = 17;
```

In `nfc_riegel/pubspec.yaml`:

```yaml
version: 1.0.0+17
```

- [ ] **Step 3: Alles bauen und prüfen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd C:\Users\klaas\Desktop\Programmieren\nfc_riegel; C:\flutter\bin\flutter.bat test; cd android; .\gradlew.bat :app:testDebugUnitTest; cd ..; C:\flutter\bin\flutter.bat build apk --release
```

Erwartet: `All tests passed!`, `BUILD SUCCESSFUL`, `√ Built build\app\outputs\flutter-apk\app-release.apk`.

- [ ] **Step 4: Im Emulator prüfen, was ohne Chip prüfbar ist**

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"; & $adb devices; & $adb uninstall com.klaas.nfc_riegel; & $adb install -r C:\Users\klaas\Desktop\Programmieren\nfc_riegel\build\app\outputs\flutter-apk\app-release.apk; & $adb shell am start -n com.klaas.nfc_riegel/.MainActivity
```

Läuft kein Emulator, vorher starten:

```powershell
Start-Process -FilePath "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -ArgumentList "-avd","Pixel_8_API_35" -WindowStyle Minimized
```

Erwartet: `Success`, App startet ohne Absturz. Danach prüfen, dass die neue Activity registriert ist:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell dumpsys package com.klaas.nfc_riegel | Select-String "ReleaseActivity","versionCode"
```

Erwartet: `com.klaas.nfc_riegel/.ReleaseActivity` und `versionCode=17`. Der Scanweg selbst bleibt dem Gerätetest vorbehalten — der Emulator hat kein NFC.

- [ ] **Step 5: APK ablegen und committen**

```bash
cp nfc_riegel/build/app/outputs/flutter-apk/app-release.apk "APKs/Android/Riegel.apk"
git add nfc_riegel/GERAETETEST.md nfc_riegel/lib/build_info.dart nfc_riegel/pubspec.yaml
git commit -m "chore: Build 17 mit der Freigabe auf Zeit"
```

---

## Offen für den Gerätetest

Der Dialog selbst lässt sich nur am Gerät auslösen — der Emulator hat kein NFC,
und der Einrichtungsassistent verlangt einen angelernten Chip. Alles darunter
(Wirkung, Ablauf, Aufräumen, Speicherformat) ist in den JUnit-Tests aus Task 2–4
abgedeckt und läuft ohne Emulator.
