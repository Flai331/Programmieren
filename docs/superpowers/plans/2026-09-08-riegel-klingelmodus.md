# Klingelmodus in der Ruhe — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Ruhe eines Profils kann den Klingelmodus des Telefons setzen — unverändert, laut, vibrieren oder lautlos — statt nur Anrufe stumm zu schalten.

**Architecture:** Derselbe Schnitt wie im übrigen Riegel. Die Entscheidung, welcher Modus gerade gilt, ist eine reine Funktion in `QuietPlanner` und per JUnit prüfbar. Das Anfassen von Android steckt in einer neuen, dünnen Klasse `QuietRinger`, gebaut wie `QuietDnd`: sie merkt sich den vorherigen Modus und stellt ihn am Ende wieder her. `LockController.applyEffects` ruft beides an derselben Stelle.

**Tech Stack:** Kotlin (Android, JUnit ohne Emulator), Flutter/Dart (flutter_test), MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** `docs/superpowers/specs/2026-09-08-riegel-klingelmodus-design.md`

---

## Vorbereitung für jede Sitzung

`JAVA_HOME` ist systemweit falsch. Vor jedem Gradle-Aufruf in PowerShell:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

Kotlin-Tests laufen aus `nfc_riegel/android`:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

Flutter-Tests laufen aus `nfc_riegel`:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

## Dateiübersicht

| Datei | Verantwortung |
|---|---|
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/Quiet.kt` | ändern — `RingerMode` und das neue Feld `QuietSettings.ringer` |
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt` | ändern — Feld 19, Abwärtskompatibilität |
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietPlanner.kt` | ändern — `ringerMode()`, die reine Auswahl |
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietRinger.kt` | **neu** — setzt und stellt den Klingelmodus wieder her |
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt` | ändern — Aufruf in `applyEffects` |
| `android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt` | ändern — Feld in beide Richtungen, Diagnose-Zeile |
| `lib/lock_status.dart` | ändern — `RingerMode`, `ProfileInfo.quietRinger` |
| `lib/riegel_channel.dart` | ändern — Feld beim Speichern mitschicken |
| `lib/profile_screen.dart` | ändern — Auswahlfeld, Hinweis, DND-Knopf entzerren |
| `android/app/src/test/kotlin/com/klaas/nfc_riegel/QuietPlannerTest.kt` | ändern — Tests der Rangfolge |
| `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt` | ändern — Rundlauf und Altsätze |
| `test/profile_screen_test.dart` | ändern — Auswahlfeld sichtbar, Wert wird gespeichert |
| `test/lock_status_test.dart` | ändern — Abbildung des Kanalfelds |
| `GERAETETEST.md` | ändern — neuer Abschnitt |
| `pubspec.yaml` | ändern — Build 19 |

---

### Task 1: Modell und Speicherformat

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/Quiet.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt:15-16`, `:20-39`, `:71-86`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

- [ ] **Step 1: Enum und Feld anlegen**

In `Quiet.kt` **über** `QuietSettings` einfügen:

```kotlin
/**
 * Der Klingelmodus, den die Ruhe setzt. [UNVERAENDERT] heißt: das Telefon wird
 * nicht angefasst — die Vorgabe, damit bestehende Profile bleiben, wie sie sind.
 *
 * Die Reihenfolge ist die Rangfolge: weiter unten heißt leiser und gewinnt in
 * [QuietPlanner.ringerMode]. Nicht umsortieren.
 */
enum class RingerMode { UNVERAENDERT, LAUT, VIBRIEREN, LAUTLOS }
```

In `QuietSettings` als **letztes** Feld anhängen (hinter `schedules`):

```kotlin
    /** Klingelmodus, solange diese Ruhe greift. */
    val ringer: RingerMode = RingerMode.UNVERAENDERT,
```

- [ ] **Step 2: Failing test für den Rundlauf schreiben**

In `LockCodecTest.kt` hinter dem Test `Atempause-Einstellungen ueberstehen Kodieren und Dekodieren` einfügen:

```kotlin
    @Test
    fun `Klingelmodus uebersteht Kodieren und Dekodieren`() {
        val profile = listOf(
            Profile(
                id = "p1",
                name = "Nacht",
                quiet = QuietSettings(enabled = true, ringer = RingerMode.VIBRIEREN),
            ),
        )

        assertEquals(profile, LockCodec.decodeProfiles(LockCodec.encodeProfiles(profile)))
    }

    @Test
    fun `ein Profilsatz ohne Klingelmodus liest sich als unveraendert`() {
        // Ein Satz aus Build 18: achtzehn Felder, das neunzehnte fehlt.
        val alt = LockCodec.encodeProfiles(
            listOf(Profile(id = "p1", name = "Nacht", quiet = QuietSettings(enabled = true))),
        ).substringBeforeLast('\u0002')

        val zurueck = LockCodec.decodeProfiles(alt).single()

        assertEquals(RingerMode.UNVERAENDERT, zurueck.quiet.ringer)
    }

    @Test
    fun `ein unbekannter Klingelmodus liest sich als unveraendert`() {
        val roh = LockCodec.encodeProfiles(
            listOf(
                Profile(
                    id = "p1",
                    name = "Nacht",
                    quiet = QuietSettings(enabled = true, ringer = RingerMode.LAUTLOS),
                ),
            ),
        ).substringBeforeLast('\u0002') + '\u0002' + "FLUESTERN"

        val zurueck = LockCodec.decodeProfiles(roh).single()

        assertEquals(RingerMode.UNVERAENDERT, zurueck.quiet.ringer)
    }
```

- [ ] **Step 3: Tests laufen lassen, Fehlschlag prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest --tests '*LockCodecTest*'
```

Erwartet: FAIL. Der Rundlauf-Test schlägt fehl, weil `encodeProfiles` das Feld noch nicht schreibt und `decodeProfiles` es nicht liest.

- [ ] **Step 4: Codec erweitern**

In `LockCodec.kt` Zeile 15-16 ersetzen:

```kotlin
    /** Feldzahlen, die je Ausbaustufe entstanden sind: 7, 10/11, 17, 18, 19. */
    private val GUELTIGE_PROFILFELDER = setOf(7, 10, 11, 17, 18, 19)
```

In `encodeProfiles` hinter `if (p.timedRelease) "1" else "0",` als letzten Listeneintrag anhängen:

```kotlin
                p.quiet.ringer.name,
```

In `decodeProfiles` innerhalb des `quiet = if (f.size >= 17) { QuietSettings(...) }`-Blocks hinter `schedules = decodeSchedules(f[16]),` anhängen:

```kotlin
                        // Feld 19 kam mit dem Klingelmodus dazu.
                        ringer = if (f.size >= 19) {
                            runCatching { RingerMode.valueOf(f[18]) }
                                .getOrDefault(RingerMode.UNVERAENDERT)
                        } else {
                            RingerMode.UNVERAENDERT
                        },
```

- [ ] **Step 5: Tests laufen lassen, Erfolg prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL, alle Tests grün — auch die alten in `LockCodecTest` und `LockMigrationTest`.

- [ ] **Step 6: Probe aufs Exempel (Mutation)**

`GUELTIGE_PROFILFELDER` versuchsweise wieder auf `setOf(7, 10, 11, 17, 18)` setzen, Tests laufen lassen. Erwartet: `Klingelmodus uebersteht Kodieren und Dekodieren` fällt um (19 Felder gelten als ungültig, das Profil verschwindet). Danach zurückändern.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Quiet.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt && git commit -m "feat: Klingelmodus am Profil, mit abwaertskompatiblem Speicherformat"
```

---

### Task 2: Die Auswahl — welcher Modus gilt jetzt

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietPlanner.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/QuietPlannerTest.kt`

- [ ] **Step 1: Failing tests schreiben**

Ans Ende von `QuietPlannerTest.kt` (vor der schließenden Klammer der Klasse) einfügen:

```kotlin
    // -------------------------------------------------------------- Klingelmodus

    /** Ruhe, die immer gilt: gebunden an die Sperre, und die Sperre läuft. */
    private fun immerRuhe(ringer: RingerMode) =
        QuietSettings(enabled = true, whileLocked = true, ringer = ringer)

    private fun gesperrt(vararg profile: Profile) =
        LockState(profiles = profile.toList(), chipLock = ChipLock(profile.first().id))

    @Test
    fun `ein Profil in Ruhe gibt seinen Klingelmodus vor`() {
        val state = gesperrt(profil(immerRuhe(RingerMode.VIBRIEREN)))

        assertEquals(RingerMode.VIBRIEREN, QuietPlanner.ringerMode(state, am(24, 12), zone))
    }

    @Test
    fun `bei zwei Profilen in Ruhe gewinnt der leisere`() {
        // Beide sperren nicht selbst; die Chipsperre auf p1 macht nur p1 gesperrt.
        // Damit auch p2 Ruhe hat, hängt es an einem Wochenplan, der gerade gilt.
        val laut = profil(immerRuhe(RingerMode.LAUT), id = "p1")
        val still = Profile(
            id = "p2",
            name = "Nacht",
            quiet = QuietSettings(
                enabled = true,
                whileLocked = false,
                ringer = RingerMode.LAUTLOS,
                schedules = listOf(
                    QuietSchedule(
                        days = setOf(Calendar.MONDAY),
                        startMinute = 8 * 60,
                        endMinute = 20 * 60,
                    ),
                ),
            ),
        )
        val state = LockState(profiles = listOf(laut, still), chipLock = ChipLock("p1"))

        assertEquals(RingerMode.LAUTLOS, QuietPlanner.ringerMode(state, am(24, 12), zone))
    }

    @Test
    fun `ein ausdruecklicher Modus schlaegt unveraendert`() {
        val egal = profil(immerRuhe(RingerMode.UNVERAENDERT), id = "p1")
        val laut = Profile(
            id = "p2",
            name = "Bereitschaft",
            quiet = QuietSettings(
                enabled = true,
                whileLocked = false,
                ringer = RingerMode.LAUT,
                schedules = listOf(
                    QuietSchedule(
                        days = setOf(Calendar.MONDAY),
                        startMinute = 8 * 60,
                        endMinute = 20 * 60,
                    ),
                ),
            ),
        )
        val state = LockState(profiles = listOf(egal, laut), chipLock = ChipLock("p1"))

        assertEquals(RingerMode.LAUT, QuietPlanner.ringerMode(state, am(24, 12), zone))
    }

    @Test
    fun `ohne laufende Ruhe bleibt der Klingelmodus unveraendert`() {
        // Das Profil will lautlos, aber nichts löst die Ruhe gerade aus.
        val state = zustand(profil(immerRuhe(RingerMode.LAUTLOS)))

        assertEquals(RingerMode.UNVERAENDERT, QuietPlanner.ringerMode(state, am(24, 12), zone))
    }

    @Test
    fun `ein Profil mit ausgeschalteter Ruhe zaehlt nicht mit`() {
        val aus = profil(
            QuietSettings(enabled = false, whileLocked = true, ringer = RingerMode.LAUTLOS),
        )
        val state = gesperrt(aus)

        assertEquals(RingerMode.UNVERAENDERT, QuietPlanner.ringerMode(state, am(24, 12), zone))
    }
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest --tests '*QuietPlannerTest*'
```

Erwartet: Übersetzungsfehler „unresolved reference: ringerMode".

- [ ] **Step 3: `ringerMode` schreiben**

In `QuietPlanner.kt` hinter `isQuiet(...)` einfügen:

```kotlin
    /**
     * Welcher Klingelmodus jetzt gilt.
     *
     * Der leiseste gewinnt — dieselbe Doktrin wie bei [silences]: ein Profil kann
     * die Ruhe eines anderen nicht aufheben. [RingerMode.UNVERAENDERT] steht in
     * der Aufzählung ganz vorn und damit im Rang ganz unten, damit „egal" jeder
     * ausdrücklichen Wahl weicht.
     */
    fun ringerMode(
        state: LockState,
        now: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): RingerMode = quietProfiles(state, now, zone)
        .maxOfOrNull { it.quiet.ringer }
        ?: RingerMode.UNVERAENDERT
```

`maxOfOrNull` vergleicht Enums nach ihrer Ordinalzahl. Deshalb steht in `Quiet.kt` der Hinweis, die Reihenfolge nicht umzusortieren.

- [ ] **Step 4: Tests laufen lassen, Erfolg prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL.

- [ ] **Step 5: Probe aufs Exempel (Mutation)**

`maxOfOrNull` versuchsweise auf `minOfOrNull` ändern, Tests laufen lassen. Erwartet: `bei zwei Profilen in Ruhe gewinnt der leisere` und `ein ausdruecklicher Modus schlaegt unveraendert` fallen um. Danach zurückändern.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietPlanner.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/QuietPlannerTest.kt && git commit -m "feat: QuietPlanner waehlt den geltenden Klingelmodus"
```

---

### Task 3: Den Modus wirklich setzen

**Files:**
- Create: `android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietRinger.kt`
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt:105-107`

Kein Unit-Test: die Klasse besteht nur aus Aufrufen an `AudioManager` und `NotificationManager`, genau wie `QuietDnd`, das ebenfalls keinen hat. Die prüfbare Rechnung steckt vollständig in Task 2. Nachgewiesen wird diese Aufgabe am Gerät in Task 7.

- [ ] **Step 1: `QuietRinger.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager

/**
 * Setzt den Klingelmodus des Telefons, solange eine Ruhe ihn vorgibt.
 *
 * Der vorherige Modus wird beim ersten Setzen gemerkt und am Ende
 * wiederhergestellt — wie [QuietDnd] es mit „Bitte nicht stören" hält. Das
 * Vorhandensein des Schlüssels heißt: Riegel hat den Modus gesetzt.
 *
 * Android verlangt den „Bitte nicht stören"-Zugriff nur, wenn ein Wechsel den
 * Zustand *lautlos* betritt oder verlässt (`AudioService.wouldToggleZenMode`).
 * Vibrieren geht deshalb ohne Sonderrecht; lautlos nicht. Fehlt das Recht und
 * ist lautlos gewünscht, wird vibriert — halbe Ruhe ist besser als keine, und
 * der Profilschirm sagt es an.
 */
class QuietRinger(context: Context) {

    private val app = context.applicationContext

    private val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val notifications =
        app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val prefs = app.getSharedPreferences("nfc_riegel", Context.MODE_PRIVATE)

    /** Der Modus, den das Telefon gerade hat. */
    fun current(): RingerMode = when (audio.ringerMode) {
        AudioManager.RINGER_MODE_SILENT -> RingerMode.LAUTLOS
        AudioManager.RINGER_MODE_VIBRATE -> RingerMode.VIBRIEREN
        else -> RingerMode.LAUT
    }

    /** Setzt den Modus oder stellt bei [RingerMode.UNVERAENDERT] den alten her. */
    fun apply(mode: RingerMode) {
        if (mode == RingerMode.UNVERAENDERT) {
            zuruecksetzen()
            return
        }

        val gewuenscht = machbar(mode)
        if (!prefs.contains(KEY_VORHER)) {
            prefs.edit().putInt(KEY_VORHER, audio.ringerMode).apply()
        }
        setze(gewuenscht)
    }

    /**
     * Lautlos ohne Recht wird zu Vibrieren. Alles andere bleibt, wie gewünscht —
     * scheitert es trotzdem, fängt [setze] es ab.
     */
    private fun machbar(mode: RingerMode): RingerMode =
        if (mode == RingerMode.LAUTLOS && !notifications.isNotificationPolicyAccessGranted) {
            RingerMode.VIBRIEREN
        } else {
            mode
        }

    private fun zuruecksetzen() {
        if (!prefs.contains(KEY_VORHER)) return
        val vorher = prefs.getInt(KEY_VORHER, AudioManager.RINGER_MODE_NORMAL)
        prefs.edit().remove(KEY_VORHER).apply()
        runCatching { audio.ringerMode = vorher }
    }

    /**
     * `setRingerMode` wirft `SecurityException`, wenn der Wechsel lautlos
     * berührt und der Zugriff fehlt. Ein Fehlschlag darf die übrige Wirkung
     * einer Sperre nicht abbrechen.
     */
    private fun setze(mode: RingerMode) {
        val wert = when (mode) {
            RingerMode.LAUT -> AudioManager.RINGER_MODE_NORMAL
            RingerMode.VIBRIEREN -> AudioManager.RINGER_MODE_VIBRATE
            RingerMode.LAUTLOS -> AudioManager.RINGER_MODE_SILENT
            RingerMode.UNVERAENDERT -> return
        }
        if (audio.ringerMode == wert) return
        runCatching { audio.ringerMode = wert }
    }

    private companion object {
        const val KEY_VORHER = "ringerVorher"
    }
}
```

- [ ] **Step 2: In `applyEffects` einhängen**

In `LockController.kt` hinter dem `QuietDnd(context).apply(...)`-Aufruf anfügen:

```kotlin
        // Der Klingelmodus ist die zweite Hälfte der Ruhe: der Anruffilter trifft
        // einzelne Nummern, der Modus das ganze Telefon. Beides an derselben
        // Stelle, damit es nicht auseinanderlaufen kann.
        QuietRinger(context).apply(QuietPlanner.ringerMode(state, now))
```

- [ ] **Step 3: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:compileDebugKotlin
```

Erwartet: BUILD SUCCESSFUL.

- [ ] **Step 4: Alle Kotlin-Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/QuietRinger.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt && git commit -m "feat: Ruhe setzt den Klingelmodus und stellt ihn danach wieder her"
```

---

### Task 4: Über den Kanal

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt:48-64`, `:302-307`
- Modify: `lib/lock_status.dart:16-28`, `:109-192`
- Modify: `lib/riegel_channel.dart:72-79`
- Test: `test/lock_status_test.dart`

- [ ] **Step 1: Failing test in Dart schreiben**

Ans Ende von `test/lock_status_test.dart` (innerhalb von `main()`) einfügen:

```dart
  test('der Klingelmodus kommt aus der Kanal-Antwort', () {
    final profil = ProfileInfo.fromMap({
      'id': 'p1',
      'name': 'Nacht',
      'quietRinger': 'VIBRIEREN',
    });

    expect(profil.quietRinger, RingerMode.vibrieren);
  });

  test('ohne Angabe bleibt der Klingelmodus unveraendert', () {
    final profil = ProfileInfo.fromMap({'id': 'p1', 'name': 'Nacht'});

    expect(profil.quietRinger, RingerMode.unveraendert);
  });

  test('ein unbekannter Klingelmodus faellt auf unveraendert zurueck', () {
    final profil = ProfileInfo.fromMap({
      'id': 'p1',
      'name': 'Nacht',
      'quietRinger': 'FLUESTERN',
    });

    expect(profil.quietRinger, RingerMode.unveraendert);
  });
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/lock_status_test.dart
```

Erwartet: FAIL, „Undefined name 'RingerMode'".

- [ ] **Step 3: Dart-Modell erweitern**

In `lib/lock_status.dart` hinter `scopeToNative` (Zeile 28) einfügen:

```dart
/// Klingelmodus, den die Ruhe setzt. Reihenfolge wie in `RingerMode.kt`.
enum RingerMode { unveraendert, laut, vibrieren, lautlos }

RingerMode _ringerFrom(String? raw) => switch (raw) {
  'LAUT' => RingerMode.laut,
  'VIBRIEREN' => RingerMode.vibrieren,
  'LAUTLOS' => RingerMode.lautlos,
  _ => RingerMode.unveraendert,
};

String ringerToNative(RingerMode mode) => switch (mode) {
  RingerMode.unveraendert => 'UNVERAENDERT',
  RingerMode.laut => 'LAUT',
  RingerMode.vibrieren => 'VIBRIEREN',
  RingerMode.lautlos => 'LAUTLOS',
};

/// Beschriftung für die Auswahl im Profilschirm.
String ringerLabel(RingerMode mode) => switch (mode) {
  RingerMode.unveraendert => 'Unverändert',
  RingerMode.laut => 'Laut',
  RingerMode.vibrieren => 'Vibrieren',
  RingerMode.lautlos => 'Lautlos',
};
```

In `ProfileInfo`: im Konstruktor hinter `required this.quietSchedules,` einfügen:

```dart
    this.quietRinger = RingerMode.unveraendert,
```

Bei den Feldern hinter `final List<QuietScheduleInfo> quietSchedules;` einfügen:

```dart
  /// Klingelmodus des Telefons, solange die Ruhe dieses Profils greift.
  final RingerMode quietRinger;
```

In `ProfileInfo.fromMap` hinter der `quietSchedules:`-Zeile einfügen:

```dart
      quietRinger: _ringerFrom(map['quietRinger'] as String?),
```

`quietRinger` bekommt bewusst eine Vorgabe statt `required`: sonst müsste jede der acht bestehenden Testkonstruktionen von `ProfileInfo` angefasst werden, ohne dass sie etwas mit dem Klingelmodus zu tun hätten.

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/lock_status_test.dart
```

Erwartet: alle Tests grün.

- [ ] **Step 5: Feld beim Speichern mitschicken**

In `lib/riegel_channel.dart` hinter der `'quietSchedules': ...`-Zeile (vor der schließenden Klammer des Argument-Maps) einfügen:

```dart
          'quietRinger': ringerToNative(profile.quietRinger),
```

- [ ] **Step 6: Kotlin-Seite des Kanals**

In `RiegelChannel.kt` im `QuietSettings(...)`-Aufruf hinter `schedules = wochenplaene(call.argument("quietSchedules")),` einfügen:

```kotlin
                            ringer = runCatching {
                                RingerMode.valueOf(
                                    call.argument<String>("quietRinger") ?: "UNVERAENDERT",
                                )
                            }.getOrDefault(RingerMode.UNVERAENDERT),
```

In der Antwort von `getState` hinter `"quietSchedules" to p.quiet.schedules.map { ... }` — also als weiteren Eintrag desselben Maps — einfügen:

```kotlin
                    "quietRinger" to p.quiet.ringer.name,
```

- [ ] **Step 7: Beides übersetzen und alle Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: beide grün.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib/lock_status.dart nfc_riegel/lib/riegel_channel.dart nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt nfc_riegel/test/lock_status_test.dart && git commit -m "feat: Klingelmodus geht ueber den Kanal"
```

---

### Task 5: Auswahl im Profilschirm

**Files:**
- Modify: `lib/profile_screen.dart:39-50`, `:230-236`, `:462-509`
- Test: `test/profile_screen_test.dart`

- [ ] **Step 1: Failing tests schreiben**

Ans Ende von `test/profile_screen_test.dart` (innerhalb von `main()`) einfügen:

```dart
  testWidgets('der Klingelmodus erscheint erst mit eingeschalteter Ruhe', (
    tester,
  ) async {
    stub(usageGranted: true);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Klingelmodus während der Ruhe'), findsNothing);

    final ruheSchalter = find.widgetWithText(
      SwitchListTile,
      'Anrufe stumm schalten',
    );
    await tester.ensureVisible(ruheSchalter);
    await tester.pumpAndSettle();
    await tester.tap(ruheSchalter);
    await tester.pumpAndSettle();

    expect(find.text('Klingelmodus während der Ruhe'), findsOneWidget);
  });

  testWidgets('der gewaehlte Klingelmodus wird gespeichert', (tester) async {
    stub(usageGranted: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          profile: const ProfileInfo(
            id: 'p1',
            name: 'Arbeit',
            blockedPackages: [],
            mode: LockMode.timer,
            durationMinutes: 60,
            untilAt: null,
            pinCalendarEnd: false,
            timedRelease: false,
            pauseEnabled: false,
            pauseStepMinutes: 15,
            pauseBaseSeconds: 5,
            pauseResetMinutes: 15,
            quietEnabled: true,
            quietScope: QuietScope.alle,
            quietNumbers: [],
            quietAfterEventMinutes: 0,
            quietWhileLocked: true,
            quietSchedules: [],
          ),
          channel: RiegelChannel(channel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final auswahl = find.byType(DropdownButton<RingerMode>);
    await tester.ensureVisible(auswahl);
    await tester.pumpAndSettle();
    await tester.tap(auswahl);
    await tester.pumpAndSettle();
    // Der geöffnete Klapp-Vorhang zeigt jeden Eintrag ein zweites Mal; der
    // letzte Treffer gehört zum Vorhang, nicht zum geschlossenen Knopf.
    await tester.tap(find.text('Vibrieren').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['quietRinger'], 'VIBRIEREN');
  });
```

`screen()` und `profil` sind die schon vorhandenen Helfer der Datei; der Sichern-Knopf sitzt als `TextButton` mit der Aufschrift „Sichern" in der AppBar (`lib/profile_screen.dart:267`).

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/profile_screen_test.dart
```

Erwartet: FAIL — „Klingelmodus während der Ruhe" wird nicht gefunden.

- [ ] **Step 3: Zustandsfeld anlegen**

In `lib/profile_screen.dart` hinter `late List<QuietScheduleInfo> _quietSchedules = ...;` einfügen:

```dart
  late RingerMode _quietRinger = widget.profile.quietRinger;
```

- [ ] **Step 4: Beim Speichern mitgeben**

In `_save()` hinter `quietSchedules: _quietSchedules,` einfügen:

```dart
        quietRinger: _quietRinger,
```

- [ ] **Step 5: Auswahlfeld einbauen**

In `build`, unmittelbar hinter `if (_quiet) ...[` und **vor** dem `SizedBox(height: RiegelSpacing.s3)` mit dem `SegmentedButton<QuietScope>`, einfügen:

```dart
            const SizedBox(height: RiegelSpacing.s3),
            const Text('Klingelmodus während der Ruhe'),
            DropdownButton<RingerMode>(
              value: _quietRinger,
              isExpanded: true,
              items: [
                for (final m in RingerMode.values)
                  DropdownMenuItem(value: m, child: Text(ringerLabel(m))),
              ],
              onChanged: (m) =>
                  setState(() => _quietRinger = m ?? RingerMode.unveraendert),
            ),
            const Text(
              'Gilt fürs ganze Telefon, also auch für Benachrichtigungen.',
              style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
            ),
            if (_quietRinger == RingerMode.lautlos && _dndErlaubt == false)
              const Text(
                'Ohne „Bitte nicht stören" bleibt es beim Vibrieren.',
                style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
              ),
```

- [ ] **Step 6: Den DND-Knopf entzerren**

Er hängt heute im Anruffilter-Block und erscheint deshalb nicht, wenn nur der Klingelmodus ihn braucht. Aus dem Block `if (_screeningGehalten == false) ...[` diese drei Zeilen **entfernen**:

```dart
              if (_dndErlaubt == false)
                OutlinedButton(
                  onPressed: widget.channel.openDndSettings,
                  child: const Text('„Bitte nicht stören" erlauben'),
                ),
```

Und **hinter** dem gesamten `if (_screeningGehalten == false) ...[...]`-Block einfügen:

```dart
            // Der Zugriff wird an zwei Stellen gebraucht: als Rückfall für den
            // Anruffilter und für „Lautlos". Deshalb steht der Knopf hier
            // einmal für beide statt zweimal.
            if (_dndErlaubt == false &&
                (_screeningGehalten == false ||
                    _quietRinger == RingerMode.lautlos)) ...[
              const SizedBox(height: RiegelSpacing.s2),
              OutlinedButton(
                onPressed: widget.channel.openDndSettings,
                child: const Text('„Bitte nicht stören" erlauben'),
              ),
            ],
```

- [ ] **Step 7: Tests laufen lassen, Erfolg prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: alle Tests grün.

- [ ] **Step 8: Probe aufs Exempel (Mutation)**

In `_save()` `quietRinger: _quietRinger` versuchsweise durch `quietRinger: RingerMode.unveraendert` ersetzen, Tests laufen lassen. Erwartet: genau `der gewaehlte Klingelmodus wird gespeichert` fällt um. Danach zurückändern.

- [ ] **Step 9: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib/profile_screen.dart nfc_riegel/test/profile_screen_test.dart && git commit -m "feat: Klingelmodus im Profilschirm waehlbar"
```

---

### Task 6: Diagnose

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt:165-188`

Die Zeile gehört in `RiegelChannel` und nicht in `Diagnostics`: der Ist-Wert kommt vom `AudioManager` und braucht einen `Context`, `Diagnostics.summarize` ist bewusst rein. Dieselbe Trennung gilt schon für „Bitte nicht stören" und „Anruffilter".

- [ ] **Step 1: Zeile ergänzen**

Im `"getDiagnostics"`-Zweig hinter `map["Ruhe"] = ...` einfügen:

```kotlin
                    // Weicht ist von soll ab, fehlt ein Recht. Genau der Fall
                    // aus dem Fehlerbericht vom 2026-09-06 wäre so sichtbar.
                    map["Klingelmodus"] = "ist=${QuietRinger(activity).current()}, " +
                        "soll=${
                            QuietPlanner.ringerMode(
                                controller.engine.state(),
                                System.currentTimeMillis(),
                            )
                        }"
```

- [ ] **Step 2: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:compileDebugKotlin
```

Erwartet: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt && git commit -m "feat: Fehlerbericht nennt Ist- und Soll-Klingelmodus"
```

---

### Task 7: Build 19, Emulator, Gerätetest

**Files:**
- Modify: `pubspec.yaml:19`
- Modify: `GERAETETEST.md`

- [ ] **Step 1: Build-Nummer erhöhen**

In `pubspec.yaml` Zeile 19 von `version: 1.0.0+18` auf `version: 1.0.0+19` ändern.

- [ ] **Step 2: Gerätetest-Punkte ergänzen**

Ans Ende von `GERAETETEST.md` anhängen:

```markdown
## Klingelmodus in der Ruhe

- [ ] Profil mit Ruhe an, Klingelmodus „Vibrieren", „Auch während einer Sperre" an.
      Sperren — das Telefon vibriert nur noch. Ohne „Bitte nicht stören"-Recht.
- [ ] Entsperren — der Klingelmodus von vorher steht wieder da.
- [ ] Klingelmodus „Lautlos" ohne „Bitte nicht stören"-Recht: der Hinweis
      „Ohne „Bitte nicht stören" bleibt es beim Vibrieren." steht im Schirm,
      und beim Sperren vibriert es tatsächlich statt still zu sein.
- [ ] „Bitte nicht stören" erlauben, wieder sperren — jetzt ist es still.
- [ ] Klingelmodus „Unverändert": Sperren ändert am Telefon nichts.
- [ ] Zwei Profile gleichzeitig in Ruhe, eines „Laut", eines „Lautlos" —
      es bleibt still.
- [ ] Fehlerbericht schicken: die Zeile „Klingelmodus: ist=…, soll=…" steht drin
      und stimmt.
- [ ] Nach einem Neustart des Telefons mit laufender Sperre: der Modus stimmt
      weiter.
```

- [ ] **Step 3: Emulator starten, falls keiner läuft**

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
```

Läuft keiner:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_8_API_35
```

Dann warten, bis `adb shell getprop sys.boot_completed` eine `1` liefert.

- [ ] **Step 4: Bauen**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; cd "C:\Users\klaas\Desktop\Programmieren\nfc_riegel"; flutter build apk --release
```

Erwartet: „✓ Built build\app\outputs\flutter-apk\app-release.apk".

- [ ] **Step 5: Im Emulator installieren und starten**

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r "C:\Users\klaas\Desktop\Programmieren\nfc_riegel\build\app\outputs\flutter-apk\app-release.apk"
```

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell monkey -p com.klaas.nfc_riegel -c android.intent.category.LAUNCHER 1
```

Danach prüfen, dass die App läuft und nicht abgestürzt ist:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell "pidof com.klaas.nfc_riegel"
```

Erwartet: eine Prozessnummer. Kommt nichts, im Logcat nach `FATAL EXCEPTION` sehen.

- [ ] **Step 6: Klingelmodus im Emulator prüfen**

Im Profilschirm Ruhe an, Klingelmodus „Vibrieren", „Auch während einer Sperre" an, speichern, sperren. Dann:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell dumpsys audio | Select-String -Pattern "ringer mode"
```

`Select-String` läuft in PowerShell, nicht in der Android-Shell — die Pipe gehört deshalb hinter den `adb`-Aufruf, nicht in seine Anführungszeichen.

Erwartet: `RINGER_MODE_VIBRATE`. Nach dem Entsperren wieder der vorherige Wert.

- [ ] **Step 7: APK ablegen**

```powershell
Copy-Item "C:\Users\klaas\Desktop\Programmieren\nfc_riegel\build\app\outputs\flutter-apk\app-release.apk" "C:\Users\klaas\Desktop\Programmieren\APKs\Android\Riegel.apk" -Force
```

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/pubspec.yaml nfc_riegel/GERAETETEST.md && git commit -m "chore: Build 19 mit dem Klingelmodus"
```

---

## Zum Schluss

Alle Tests noch einmal, beide Seiten:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel/android" && ./gradlew :app:testDebugUnitTest
```

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: keine Fehler, alle Tests grün.
