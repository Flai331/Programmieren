# Screenzeit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Riegel zeigt die Tagesnutzung ab lokaler Mitternacht — auf dem Sperrschirm für die abgefangene App, in einem eigenen Reiter für alle benutzten Apps.

**Architecture:** Die Rechnung liegt in reinem Kotlin (`ScreenTimeCalculator`) und ist per JUnit prüfbar; Android steckt in einer dünnen Quelle (`AndroidUsageSource`) dahinter — derselbe Schnitt wie `CalendarPlanner`/`CalendarSource`. Flutter holt die fertigen Zahlen über den bestehenden MethodChannel. Der Sperrschirm läuft ohne Flutter und ruft die Kotlin-Seite direkt.

**Tech Stack:** Kotlin (JVM 17), Flutter 3.44 / Dart 3.12, JUnit 4.13.2, `UsageStatsManager`, `AppOpsManager`, MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** `docs/superpowers/specs/2026-08-08-riegel-screenzeit-design.md`

---

## Vorbemerkungen für die Umsetzung

**Gradle braucht JDK 17.** `JAVA_HOME` zeigt auf dieser Maschine auf eine JVM 8. Vor jedem Gradle-Aufruf setzen:

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
```

**Nicht PowerShell für Gradle benutzen.** `2>&1` auf einer nativen exe verfälscht dort den Rückgabewert — ein erfolgreicher Build meldet 255. Die Bash-Werkzeuge nehmen.

**Testzahlen zählen.** Nach jedem Task die Summe aus den JUnit-XMLs bilden, nicht der Konsole glauben:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && grep -ho 'tests="[0-9]*" skipped="[0-9]*" failures="[0-9]*" errors="[0-9]*"' build/app/test-results/testDebugUnitTest/TEST-*.xml | awk -F'"' '{t+=$2; f+=$6; e+=$8} END {print "tests="t, "failures="f, "errors="e}'
```

**`lib/secrets.dart` niemals lesen, ändern oder committen.** Enthält den echten Notion-Token. Im Repo gehört nur `secrets.template.dart`.

**Emulatortests immer mit frischer Installation.** `adb uninstall` zuerst, Berechtigungen **nicht** vorab per `pm grant` setzen — sonst bleiben genau die Fehler unsichtbar, die echte Nutzer treffen.

---

## Dateiübersicht

| Datei | Verantwortung |
|---|---|
| `android/.../UsageEvent.kt` (neu) | Ereignis-Datenmodell, plattformfrei |
| `android/.../ScreenTimeCalculator.kt` (neu) | reine Rechnung: Ereignisse → Millisekunden je Paket; lokale Mitternacht |
| `android/.../UsageStatsSource.kt` (neu) | `UsageStatsManager` und `AppOpsManager` hinter einer Schnittstelle |
| `android/.../RiegelChannel.kt` | drei Kanalmethoden, Namen aus `launchableApps()` |
| `android/.../BlockerService.kt` | reicht das abgefangene Paket an den Sperrschirm |
| `android/.../BlockActivity.kt` | eine Zeile mit der Tagesnutzung |
| `android/app/src/main/AndroidManifest.xml` | `PACKAGE_USAGE_STATS` |
| `lib/screen_time.dart` (neu) | `AppUsage`, `formatUsage`, Schwelle |
| `lib/screen_time_tab.dart` (neu) | der Reiter |
| `lib/riegel_channel.dart` | drei Aufrufe |
| `lib/home_screen.dart` | zwei Reiter statt einem Rumpf |

**Erwartete Testzahlen**

| nach Task | Kotlin | Dart |
|---|---|---|
| Ausgangslage | 168 | 27 |
| 1 | 181 | 27 |
| 5 | 181 | 30 |
| 6 | 181 | 34 |
| 7 | 181 | 35 |

Weicht eine Zahl ab, **nicht** die Zahl anpassen, sondern nachsehen, welcher Test fehlt oder zu viel ist.

---

### Task 1: Ereignismodell und Rechnung

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/UsageEvent.kt`
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/ScreenTimeCalculator.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/ScreenTimeCalculatorTest.kt` (neu)

Hier steckt die ganze Knifflichkeit. Die drei Ränder aus der Spec — um Mitternacht schon offen, jetzt noch offen, Bildschirm aus ohne Pausenereignis — sind der eigentliche Inhalt.

- [ ] **Schritt 1: Das Datenmodell anlegen**

`UsageEvent.kt`:

```kotlin
package com.klaas.nfc_riegel

/**
 * Ein Wechsel im Vordergrund, reduziert auf das Nötige. Bewusst ohne
 * Android-Typen, damit [ScreenTimeCalculator] per JUnit prüfbar bleibt.
 */
data class UsageEvent(
    val packageName: String,
    val type: UsageEventType,
    val timestamp: Long,
)

enum class UsageEventType {
    /** App kommt nach vorn. */
    FOREGROUND,

    /** App geht nach hinten. */
    BACKGROUND,

    /**
     * Bildschirm aus oder Sperrbildschirm an. Beendet alles, was gerade offen
     * ist — auf manchen Geräten kommt sonst kein Pausenereignis, und eine über
     * Nacht offen gelassene App sammelte acht Stunden an.
     */
    SCREEN_OFF,
}
```

- [ ] **Schritt 2: Die fehlschlagenden Tests schreiben**

`ScreenTimeCalculatorTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class ScreenTimeCalculatorTest {

    private val beginn = 1_000_000L
    private val ende = beginn + 60 * 60_000L
    private val minute = 60_000L

    private fun vorn(paket: String, t: Long) = UsageEvent(paket, UsageEventType.FOREGROUND, t)
    private fun hinten(paket: String, t: Long) = UsageEvent(paket, UsageEventType.BACKGROUND, t)
    private fun aus(t: Long) = UsageEvent("", UsageEventType.SCREEN_OFF, t)

    private fun summen(vararg events: UsageEvent) =
        ScreenTimeCalculator.totals(events.toList(), beginn, ende)

    @Test
    fun `einfacher Wechsel ergibt die Differenz`() {
        val s = summen(vorn("com.a", beginn + minute), hinten("com.a", beginn + 6 * minute))

        assertEquals(mapOf("com.a" to 5 * minute), s)
    }

    @Test
    fun `noch offene App zaehlt bis zum Fensterende`() {
        val s = summen(vorn("com.a", ende - 10 * minute))

        assertEquals(mapOf("com.a" to 10 * minute), s)
    }

    @Test
    fun `um Mitternacht offene App zaehlt ab dem Fensterbeginn`() {
        // Kein FOREGROUND im Fenster — die App lief schon vorher.
        val s = summen(hinten("com.a", beginn + 3 * minute))

        assertEquals(mapOf("com.a" to 3 * minute), s)
    }

    @Test
    fun `zweites BACKGROUND zaehlt nicht erneut`() {
        // ACTIVITY_PAUSED und ACTIVITY_STOPPED kommen oft beide.
        val s = summen(
            vorn("com.a", beginn + minute),
            hinten("com.a", beginn + 4 * minute),
            hinten("com.a", beginn + 4 * minute),
        )

        assertEquals(mapOf("com.a" to 3 * minute), s)
    }

    @Test
    fun `Bildschirm aus schliesst alles Offene`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            aus(beginn + 3 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `nach Bildschirm aus zaehlt erst ein neues FOREGROUND wieder`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            aus(beginn + 3 * minute),
            hinten("com.a", beginn + 30 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `zweites FOREGROUND ohne BACKGROUND zaehlt nicht doppelt`() {
        val s = summen(
            vorn("com.a", beginn + minute),
            vorn("com.a", beginn + 2 * minute),
            hinten("com.a", beginn + 5 * minute),
        )

        assertEquals(mapOf("com.a" to 4 * minute), s)
    }

    @Test
    fun `Ereignis vor dem Fensterbeginn wird auf den Beginn geklemmt`() {
        val s = summen(vorn("com.a", beginn - 10 * minute), hinten("com.a", beginn + 2 * minute))

        assertEquals(mapOf("com.a" to 2 * minute), s)
    }

    @Test
    fun `zwei Apps abwechselnd ergeben getrennte Summen`() {
        val s = summen(
            vorn("com.a", beginn),
            hinten("com.a", beginn + 2 * minute),
            vorn("com.b", beginn + 2 * minute),
            hinten("com.b", beginn + 5 * minute),
        )

        assertEquals(mapOf("com.a" to 2 * minute, "com.b" to 3 * minute), s)
    }

    @Test
    fun `unsortierte Ereignisse werden nach Zeit verarbeitet`() {
        val s = summen(
            hinten("com.a", beginn + 5 * minute),
            vorn("com.a", beginn + minute),
        )

        assertEquals(mapOf("com.a" to 4 * minute), s)
    }

    @Test
    fun `leere Ereignisliste ergibt eine leere Karte`() {
        assertTrue(ScreenTimeCalculator.totals(emptyList(), beginn, ende).isEmpty())
    }

    @Test
    fun `Mitternacht ist der Beginn des laufenden Tages`() {
        val zone = TimeZone.getTimeZone("Europe/Berlin")
        val kalender = Calendar.getInstance(zone).apply {
            set(2026, Calendar.AUGUST, 8, 14, 37, 12)
            set(Calendar.MILLISECOND, 400)
        }

        val mitternacht = ScreenTimeCalculator.startOfDay(kalender.timeInMillis, zone)

        val geprueft = Calendar.getInstance(zone).apply { timeInMillis = mitternacht }
        assertEquals(8, geprueft.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, geprueft.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, geprueft.get(Calendar.MINUTE))
        assertEquals(0, geprueft.get(Calendar.SECOND))
        assertEquals(0, geprueft.get(Calendar.MILLISECOND))
    }

    @Test
    fun `kurz nach Mitternacht bleibt es derselbe Tag`() {
        val zone = TimeZone.getTimeZone("Europe/Berlin")
        val kalender = Calendar.getInstance(zone).apply {
            set(2026, Calendar.AUGUST, 8, 0, 0, 30)
            set(Calendar.MILLISECOND, 0)
        }

        val mitternacht = ScreenTimeCalculator.startOfDay(kalender.timeInMillis, zone)

        assertEquals(30_000L, kalender.timeInMillis - mitternacht)
    }
}
```

- [ ] **Schritt 3: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler „Unresolved reference: ScreenTimeCalculator".

- [ ] **Schritt 4: Den Rechner schreiben**

`ScreenTimeCalculator.kt`:

```kotlin
package com.klaas.nfc_riegel

import java.util.Calendar
import java.util.TimeZone

/**
 * Rechnet aus rohen Nutzungsereignissen die Vordergrundzeit je Paket.
 *
 * Bewusst aus Ereignissen statt aus den fertigen Tageseimern von
 * `queryUsageStats`: deren Grenzen richten sich nach einer geräteeigenen
 * Tagesgrenze, nicht nach der lokalen Mitternacht des Nutzers.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object ScreenTimeCalculator {

    /** Lokale Mitternacht des Tages, in dem [now] liegt. */
    fun startOfDay(now: Long, zone: TimeZone = TimeZone.getDefault()): Long {
        val kalender = Calendar.getInstance(zone)
        kalender.timeInMillis = now
        kalender.set(Calendar.HOUR_OF_DAY, 0)
        kalender.set(Calendar.MINUTE, 0)
        kalender.set(Calendar.SECOND, 0)
        kalender.set(Calendar.MILLISECOND, 0)
        return kalender.timeInMillis
    }

    /**
     * Vordergrundzeit je Paket im Fenster [from]..[to].
     *
     * Drei Fälle, die eine naive Paarbildung falsch rechnet:
     *
     * 1. Ein Paket ohne Startereignis, aber mit Ende, lief schon zu Beginn des
     *    Fensters — seine Zeit zählt ab [from].
     * 2. Ein Paket ohne Endeereignis läuft noch — es zählt bis [to].
     * 3. `SCREEN_OFF` beendet alles Offene, weil auf manchen Geräten beim
     *    Ausschalten kein Pausenereignis kommt.
     *
     * `gesehen` verhindert, dass Fall 1 mehrfach greift: kommt für ein Paket ein
     * zweites Ende (Android schickt oft `ACTIVITY_PAUSED` **und**
     * `ACTIVITY_STOPPED`), würde sonst erneut ab [from] gerechnet.
     */
    fun totals(events: List<UsageEvent>, from: Long, to: Long): Map<String, Long> {
        val summen = mutableMapOf<String, Long>()
        val offen = mutableMapOf<String, Long>()
        val gesehen = mutableSetOf<String>()

        fun schliesse(paket: String, zeitpunkt: Long) {
            val start = offen.remove(paket)
                ?: if (paket in gesehen) return else from
            gesehen += paket
            val dauer = zeitpunkt - start
            if (dauer > 0) summen[paket] = (summen[paket] ?: 0L) + dauer
        }

        for (ereignis in events.sortedBy { it.timestamp }) {
            val t = ereignis.timestamp.coerceIn(from, to)
            when (ereignis.type) {
                UsageEventType.FOREGROUND -> {
                    gesehen += ereignis.packageName
                    offen.putIfAbsent(ereignis.packageName, t)
                }
                UsageEventType.BACKGROUND -> schliesse(ereignis.packageName, t)
                UsageEventType.SCREEN_OFF -> offen.keys.toList().forEach { schliesse(it, t) }
            }
        }

        offen.keys.toList().forEach { schliesse(it, to) }
        return summen
    }
}
```

- [ ] **Schritt 5: Tests laufen lassen**

Erwartet: 181 Tests, 0 Fehlschläge.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Nutzungsereignisse zu Tageszeiten rechnen"
```

---

### Task 2: Quelle für Nutzungsdaten

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/UsageStatsSource.kt`
- Modify: `nfc_riegel/android/app/src/main/AndroidManifest.xml`

Ohne eigene Tests: `UsageStatsManager` läuft in reinem JUnit nicht. Die Rechnung davor und danach ist in Task 1 abgedeckt, diese Schicht ist eine Übersetzung.

- [ ] **Schritt 1: `UsageStatsSource.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

/**
 * Liest die Nutzungsereignisse des Geräts. Hinter einer Schnittstelle, damit
 * [ScreenTimeCalculator] ohne Android prüfbar bleibt.
 */
interface UsageSource {
    fun granted(): Boolean
    fun events(from: Long, to: Long): List<UsageEvent>
}

class AndroidUsageSource(private val context: Context) : UsageSource {

    /**
     * `PACKAGE_USAGE_STATS` läuft nicht über das normale Berechtigungssystem —
     * `checkSelfPermission` meldet hier immer „verweigert", auch wenn der Nutzer
     * den Zugriff erteilt hat. Gefragt wird stattdessen der AppOps-Dienst.
     */
    override fun granted(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val modus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return modus == AppOpsManager.MODE_ALLOWED
    }

    override fun events(from: Long, to: Long): List<UsageEvent> {
        if (!granted()) return emptyList()
        val manager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val roh = manager.queryEvents(from, to)
        val ergebnis = mutableListOf<UsageEvent>()
        val puffer = UsageEvents.Event()
        while (roh.hasNextEvent()) {
            roh.getNextEvent(puffer)
            val paket = puffer.packageName ?: continue
            val art = when (puffer.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> UsageEventType.FOREGROUND
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> UsageEventType.BACKGROUND
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN -> UsageEventType.SCREEN_OFF
                // Alles andere — Benachrichtigungen, Konfigurationswechsel — sagt
                // nichts über Vordergrundzeit aus.
                else -> continue
            }
            ergebnis += UsageEvent(paket, art, puffer.timeStamp)
        }
        return ergebnis
    }
}
```

- [ ] **Schritt 2: Berechtigung ins Manifest**

In `AndroidManifest.xml` hinter die `READ_CALENDAR`-Zeile:

```xml
    <!--
        Tagesnutzung für den Screenzeit-Reiter. Sonderberechtigung: wird nicht
        zur Laufzeit abgefragt, sondern über einen eigenen Systemschirm erteilt.
    -->
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions"/>
```

- [ ] **Schritt 3: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL, weiterhin 181 Tests.

- [ ] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Nutzungsereignisse des Geraets lesen"
```

---

### Task 3: Kanal für Screenzeit

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`

- [ ] **Schritt 1: Drei Methoden ergänzen**

Im `when` über `call.method`, vor `"launchableApps"`:

```kotlin
                "usageAccessGranted" ->
                    result.success(AndroidUsageSource(activity).granted())

                "openUsageAccessSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }

                "screenTimeToday" -> result.success(screenTimeToday())

```

- [ ] **Schritt 2: Die Zusammenstellung ergänzen**

Direkt über `private fun launchableApps()`:

```kotlin
    /**
     * Tagesnutzung ab lokaler Mitternacht, absteigend sortiert.
     *
     * Die Namen kommen aus [launchableApps] — das filtert zugleich zweierlei
     * heraus: Hintergrunddienste ohne Startsymbol, die keine „benutzte App"
     * sind, und Riegel selbst. Wer die Screenzeit ansieht, erzeugt dabei
     * Screenzeit; diese Zahl anzuzeigen wäre Rauschen.
     */
    private fun screenTimeToday(): List<Map<String, Any>> {
        val quelle = AndroidUsageSource(activity)
        if (!quelle.granted()) return emptyList()

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val summen = ScreenTimeCalculator.totals(quelle.events(beginn, jetzt), beginn, jetzt)
        val namen = launchableApps().associate {
            it.getValue("packageName") to it.getValue("name")
        }

        return summen.mapNotNull { (paket, millis) ->
            val name = namen[paket] ?: return@mapNotNull null
            mapOf<String, Any>("packageName" to paket, "name" to name, "millis" to millis)
        }.sortedByDescending { it["millis"] as Long }
    }

```

- [ ] **Schritt 3: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 181 Tests.

- [ ] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Screenzeit ueber den Kanal"
```

---

### Task 4: Nutzungsdaten im Fehlerbericht

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`

Die Zeile entsteht im Kanal, nicht in `Diagnostics` — genau wie „Bedienungshilfe" und „Benachrichtigungen", weil `Diagnostics.summarize` bewusst keinen `Context` kennt.

**Wichtig:** nur der Zustand der Berechtigung, **keine** Zeiten. Der Bericht landet in einer Notion-Datenbank; wie lange jemand welche App benutzt hat, gehört dort nicht hin — dieselbe Linie wie bei Chip-Kennungen, Code-Hash und Termintiteln.

- [ ] **Schritt 1: Zeile ergänzen**

Im Zweig `"getDiagnostics"`, hinter `map["Benachrichtigungen"] = notificationPermissionState()`:

```kotlin
                    map["Nutzungsdaten"] =
                        if (AndroidUsageSource(activity).granted()) "erlaubt" else "VERWEIGERT"
```

- [ ] **Schritt 2: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 181 Tests.

- [ ] **Schritt 3: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Zustand der Nutzungsdaten im Fehlerbericht"
```

---

### Task 5: Dart-Modell und Kanalaufrufe

**Files:**
- Create: `nfc_riegel/lib/screen_time.dart`
- Modify: `nfc_riegel/lib/riegel_channel.dart`
- Test: `nfc_riegel/test/screen_time_test.dart` (neu)

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`test/screen_time_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/screen_time.dart';

void main() {
  test('unter einer Stunde nur Minuten', () {
    expect(formatUsage(const Duration(minutes: 47)), '47 min');
    expect(formatUsage(const Duration(minutes: 59, seconds: 59)), '59 min');
  });

  test('ab einer Stunde mit Stundenfeld', () {
    expect(formatUsage(const Duration(hours: 1, minutes: 23)), '1 h 23 min');
    expect(formatUsage(const Duration(hours: 2)), '2 h 0 min');
  });

  test('Nutzung wird aus der Karte gelesen', () {
    final nutzung = AppUsage.fromMap({
      'name': 'Chrome',
      'packageName': 'com.android.chrome',
      'millis': 90000,
    });

    expect(nutzung.name, 'Chrome');
    expect(nutzung.packageName, 'com.android.chrome');
    expect(nutzung.duration, const Duration(seconds: 90));
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/screen_time_test.dart
```

Erwartet: „Target of URI doesn't exist: 'package:nfc_riegel/screen_time.dart'".

- [ ] **Schritt 3: `screen_time.dart` anlegen**

```dart
/// Tagesnutzung einer App, wie sie die native Seite liefert.
class AppUsage {
  const AppUsage({
    required this.name,
    required this.packageName,
    required this.duration,
  });

  final String name;
  final String packageName;
  final Duration duration;

  factory AppUsage.fromMap(Map<dynamic, dynamic> map) => AppUsage(
    name: map['name'] as String? ?? '',
    packageName: map['packageName'] as String? ?? '',
    duration: Duration(milliseconds: (map['millis'] as num?)?.toInt() ?? 0),
  );
}

/// Ab einer Stunde mit Stundenfeld. Sekunden nirgends — sie ändern sich beim
/// Hinsehen und tragen nichts zur Aussage bei.
String formatUsage(Duration d) {
  final minuten = d.inMinutes;
  if (minuten < 60) return '$minuten min';
  return '${minuten ~/ 60} h ${minuten % 60} min';
}

/// Apps darunter fallen aus der Liste — sonst besteht sie aus
/// Zufallsberührungen. In die Tagessumme zählen sie trotzdem hinein.
const kUsageThreshold = Duration(minutes: 1);
```

- [ ] **Schritt 4: Kanalaufrufe ergänzen**

In `lib/riegel_channel.dart` den Import ergänzen:

```dart
import 'screen_time.dart';
```

und vor `/// Sperrbare Apps: alles mit Startsymbol, ohne Riegel selbst.`:

```dart
  Future<bool> usageAccessGranted() async =>
      await channel.invokeMethod<bool>('usageAccessGranted') ?? false;

  Future<void> openUsageAccessSettings() =>
      channel.invokeMethod<void>('openUsageAccessSettings');

  /// Tagesnutzung ab Mitternacht, absteigend sortiert.
  Future<List<AppUsage>> screenTimeToday() async {
    final raw = await channel.invokeMethod<List<dynamic>>('screenTimeToday');
    return (raw ?? [])
        .map((e) => AppUsage.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

```

- [ ] **Schritt 5: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: 30 Tests, alle grün.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Dart kennt die Tagesnutzung"
```

---

### Task 6: Screenzeit-Reiter

**Files:**
- Create: `nfc_riegel/lib/screen_time_tab.dart`
- Test: `nfc_riegel/test/screen_time_tab_test.dart` (neu)

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

Die Attrappe folgt dem Muster aus `calendar_screen_test.dart`: ein Mock-`MethodChannel`, der in `RiegelChannel(channel)` gesteckt wird. **Eine Klasse `FakeRiegelChannel` gibt es nicht.**

`test/screen_time_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/riegel_channel.dart';
import 'package:nfc_riegel/screen_time_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  void stub({
    required bool granted,
    List<Map<String, dynamic>> apps = const [],
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'usageAccessGranted':
              return granted;
            case 'screenTimeToday':
              return apps;
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

  Widget tab() => MaterialApp(
    home: Scaffold(body: ScreenTimeTab(channel: RiegelChannel(channel))),
  );

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub(granted: false);
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nutzungsdaten'), findsOneWidget);
    expect(find.text('Zugriff erlauben'), findsOneWidget);
  });

  testWidgets('mit Daten erscheinen Tagessumme und Liste', (tester) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 3600000},
        {'name': 'Gmail', 'packageName': 'com.google.android.gm', 'millis': 1200000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
    // 60 min + 20 min
    expect(find.text('1 h 20 min'), findsOneWidget);
  });

  testWidgets('Apps unter einer Minute fehlen, die Fusszeile nennt ihre Zahl', (
    tester,
  ) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 600000},
        {'name': 'Uhr', 'packageName': 'com.google.android.deskclock', 'millis': 20000},
        {'name': 'Karten', 'packageName': 'com.google.android.apps.maps', 'millis': 5000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Uhr'), findsNothing);
    expect(find.text('2 weitere unter 1 Minute'), findsOneWidget);
  });

  testWidgets('ohne kurze Apps fehlt die Fusszeile', (tester) async {
    stub(
      granted: true,
      apps: [
        {'name': 'Chrome', 'packageName': 'com.android.chrome', 'millis': 600000},
      ],
    );
    await tester.pumpWidget(tab());
    await tester.pumpAndSettle();

    expect(find.textContaining('unter 1 Minute'), findsNothing);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Target of URI doesn't exist: 'package:nfc_riegel/screen_time_tab.dart'".

- [ ] **Schritt 3: `screen_time_tab.dart` anlegen**

```dart
import 'package:flutter/material.dart';

import 'riegel_channel.dart';
import 'screen_time.dart';
import 'theme.dart';

/// Tagesnutzung ab Mitternacht. Zweiter Reiter des Hauptschirms.
class ScreenTimeTab extends StatefulWidget {
  const ScreenTimeTab({super.key, this.channel = const RiegelChannel()});

  final RiegelChannel channel;

  @override
  State<ScreenTimeTab> createState() => _ScreenTimeTabState();
}

class _ScreenTimeTabState extends State<ScreenTimeTab>
    with WidgetsBindingObserver {
  bool _granted = false;
  List<AppUsage>? _apps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Die Berechtigung wird auf einem Systemschirm erteilt. Beim Zurückkommen
  /// neu lesen — sonst stünde der Hinweis noch da, obwohl der Zugriff längst
  /// erlaubt ist, und man müsste die App schließen und wieder öffnen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await widget.channel.usageAccessGranted();
    final apps = granted ? await widget.channel.screenTimeToday() : <AppUsage>[];
    if (mounted) {
      setState(() {
        _granted = granted;
        _apps = apps;
      });
    }
  }

  Future<void> _requestAccess() => widget.channel.openUsageAccessSettings();

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    if (apps == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_granted) {
      return _AccessHint(onRequest: _requestAccess);
    }

    final lang = apps.where((a) => a.duration >= kUsageThreshold).toList();
    final kurz = apps.length - lang.length;
    final summe = apps.fold<Duration>(
      Duration.zero,
      (acc, a) => acc + a.duration,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        // Ohne dieses Physics-Objekt zieht sich eine kurze Liste nicht herunter
        // — und kurz ist sie an einem ruhigen Tag genau dann, wenn man
        // nachsehen will, ob schon etwas zusammengekommen ist.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          Text('HEUTE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          Text(
            formatUsage(summe),
            style: const TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 34,
              color: RiegelColors.fg1,
            ),
          ),
          const SizedBox(height: RiegelSpacing.s6),
          if (lang.isEmpty)
            const Text('Heute noch keine App länger als eine Minute benutzt.'),
          for (final app in lang)
            Padding(
              padding: const EdgeInsets.only(bottom: RiegelSpacing.s3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      app.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: RiegelColors.fg1,
                      ),
                    ),
                  ),
                  Text(
                    formatUsage(app.duration),
                    style: const TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 13,
                      color: RiegelColors.fg2,
                    ),
                  ),
                ],
              ),
            ),
          if (kurz > 0) ...[
            const SizedBox(height: RiegelSpacing.s2),
            Text(
              '$kurz weitere unter 1 Minute',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Solange die Sonderberechtigung fehlt, gibt es nichts anzuzeigen — also auch
/// keine leere Liste, sondern nur den Weg dorthin.
class _AccessHint extends StatelessWidget {
  const _AccessHint({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(RiegelSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Riegel darf die Nutzungsdaten noch nicht lesen. Ohne sie gibt es '
            'keine Screenzeit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: RiegelColors.fg2),
          ),
          const SizedBox(height: RiegelSpacing.s4),
          FilledButton(
            onPressed: onRequest,
            child: const Text('Zugriff erlauben'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Schritt 4: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: 34 Tests, alle grün.

- [ ] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Screenzeit-Reiter"
```

---

### Task 7: Zwei Reiter im Hauptschirm

**Files:**
- Modify: `nfc_riegel/lib/home_screen.dart`
- Test: `nfc_riegel/test/home_screen_test.dart`

Der erste Reiter heißt **Sperre**, nicht „Riegel": die Kopfzeile trägt bereits den Namen der App.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

Ans Ende der bestehenden `main()` in `test/home_screen_test.dart`:

```dart
  testWidgets('zweiter Reiter zeigt die Screenzeit', (tester) async {
    stub(accessibility: true);
    await zeige(tester);

    expect(find.text('Sperre'), findsOneWidget);
    expect(find.text('Screenzeit'), findsOneWidget);

    await tester.tap(find.text('Screenzeit'));
    await tester.pumpAndSettle();

    // Ohne Berechtigung — der Mock kennt 'usageAccessGranted' nicht und liefert
    // null, was zu false wird.
    expect(find.text('Zugriff erlauben'), findsOneWidget);
  });
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Expected: exactly one matching candidate, Actual: zero widgets" für `find.text('Sperre')`.

- [ ] **Schritt 3: Import ergänzen**

In `lib/home_screen.dart` hinter `import 'riegel_channel.dart';`:

```dart
import 'screen_time_tab.dart';
```

- [ ] **Schritt 4: Den Rumpf in zwei Reiter teilen**

Ersetze in `build` das `return Scaffold(...)` — vom `return Scaffold(` bis zur schließenden Klammer der `body:`-Zuweisung — so, dass der bisherige `RefreshIndicator` zum ersten Reiter wird:

```dart
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riegel'),
          actions: [
            IconButton(
              tooltip: 'Fehler melden',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: _reportProblem,
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Sperre'), Tab(text: 'Screenzeit')],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(RiegelSpacing.s4),
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
                      TextButton(
                        onPressed: _addProfile,
                        child: const Text('Neu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: RiegelSpacing.s2),
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
                  const SizedBox(height: RiegelSpacing.s4),
                  _NavRow(
                    title: 'Chips',
                    subtitle: '${status.tags.length} angelernt',
                    enabled: !status.locked,
                    onTap: () => _openTags(status),
                  ),
                  const SizedBox(height: RiegelSpacing.s3),
                  _NavRow(
                    title: 'Kalender',
                    subtitle: status.calendar.enabled
                        ? '${status.calendar.calendarRules.length} Kalender zugeordnet'
                        : 'aus',
                    enabled: !status.locked,
                    onTap: () => _openCalendar(status),
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
              ),
            ),
            ScreenTimeTab(channel: widget.channel),
          ],
        ),
      ),
    );
```

- [ ] **Schritt 5: Prüfen und Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: „No issues found!", 35 Tests grün.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Hauptschirm bekommt zwei Reiter"
```

---

### Task 8: Tagesnutzung auf dem Sperrschirm

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockerService.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`

Der Sperrschirm läuft ohne Flutter-Engine und ruft die Kotlin-Seite direkt. Die Formatierung ist deshalb ein zweites Mal nötig — `formatUsage` aus Dart ist hier nicht erreichbar.

- [ ] **Schritt 1: Das Paket mitgeben**

In `BlockerService.kt` den Aufruf und die Methode ersetzen:

```kotlin
        if (pkg in blocked) {
            showBlockScreen(pkg)
            return
        }
```

und

```kotlin
    private fun showBlockScreen(paket: String) {
        val intent = Intent(this, BlockActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(BlockActivity.EXTRA_PACKAGE, paket)
        startActivity(intent)
    }
```

- [ ] **Schritt 2: Das Feld im Sperrschirm anlegen**

In `BlockActivity.kt` zu den Feldern hinzufügen, hinter `private lateinit var modeCaption: TextView`:

```kotlin
    private lateinit var screenTime: TextView
    private var blockiertesPaket: String? = null
```

In `onCreate` hinter `controller = LockController(this)`:

```kotlin
        blockiertesPaket = intent?.getStringExtra(EXTRA_PACKAGE)
```

Dahinter, als neue Methode der Klasse — der Sperrschirm wird mit `CLEAR_TOP` erneut gestartet, wenn eine andere gesperrte App aufgerufen wird:

```kotlin
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        blockiertesPaket = intent?.getStringExtra(EXTRA_PACKAGE)
        aktualisiereScreenzeit()
    }
```

- [ ] **Schritt 3: Die Ansicht in das Layout hängen**

In `buildLayout()` hinter dem `modeCaption`-Block:

```kotlin
        screenTime = TextView(this).apply {
            textSize = 12f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, 0)
            visibility = View.GONE
        }
```

und in der Reihenfolge am Ende, hinter `root.addView(modeCaption)`:

```kotlin
        root.addView(screenTime)
```

- [ ] **Schritt 4: Die Zeile füllen**

Als neue Methoden der Klasse, hinter `refresh()`:

```kotlin
    /**
     * Bewusst nicht im Sekundentakt: der Ticker fragt jede Sekunde den
     * Sperrzustand ab, aber die Nutzungsereignisse des ganzen Tages dafür
     * durchzugehen wäre Verschwendung. Die Zahl ändert sich ohnehin nicht,
     * solange dieser Schirm oben liegt — die App dahinter läuft ja nicht.
     */
    private fun aktualisiereScreenzeit() {
        val paket = blockiertesPaket
        if (paket == null) {
            screenTime.visibility = View.GONE
            return
        }

        val quelle = AndroidUsageSource(this)
        // Ohne Berechtigung bleibt die Zeile weg. Der Sperrschirm ist der
        // falsche Ort, um etwas einzufordern — dort ist man ohnehin gebremst.
        if (!quelle.granted()) {
            screenTime.visibility = View.GONE
            return
        }

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val millis = ScreenTimeCalculator
            .totals(quelle.events(beginn, jetzt), beginn, jetzt)[paket] ?: 0L

        screenTime.visibility = View.VISIBLE
        screenTime.text = when {
            millis == 0L -> "Heute noch nicht benutzt"
            millis < 60_000L -> "Heute: unter 1 min"
            else -> "Heute: ${formatiereDauer(millis)}"
        }
    }

    /** Wie `formatUsage` in `lib/screen_time.dart` — hier ohne Flutter. */
    private fun formatiereDauer(millis: Long): String {
        val minuten = millis / 60_000L
        return if (minuten < 60) "$minuten min" else "${minuten / 60} h ${minuten % 60} min"
    }
```

- [ ] **Schritt 5: Beim Anzeigen aufrufen**

In `onResume()`, hinter `handler.post(ticker)`:

```kotlin
        aktualisiereScreenzeit()
```

- [ ] **Schritt 6: Die Konstante ergänzen**

`BlockActivity` hat bisher kein `companion object`. Direkt vor die schließende Klammer der Klasse — also hinter das Ende von `refresh()`:

```kotlin
    companion object {
        const val EXTRA_PACKAGE = "paket"
    }
```

- [ ] **Schritt 7: Übersetzen und Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL, 181 Tests, 0 Fehlschläge.

- [ ] **Schritt 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Tagesnutzung auf dem Sperrschirm"
```

---

### Task 9: Emulatortest, Bauen, Ablegen

**Files:**
- Modify: `nfc_riegel/GERAETETEST.md`
- Modify: `nfc_riegel/lib/build_info.dart`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Schritt 1: Prüfliste ergänzen**

Ans Ende von `GERAETETEST.md`:

```markdown
## Screenzeit

- [ ] Reiter „Screenzeit" ist da, Reiter „Sperre" zeigt weiterhin alles wie vorher
- [ ] Ohne Berechtigung: Hinweis und Knopf, keine Liste
- [ ] „Zugriff erlauben" führt in den Systemschirm für Nutzungsdaten
- [ ] Nach dem Erteilen und Herunterziehen erscheinen Tagessumme und Liste
- [ ] Liste ist absteigend sortiert, Riegel selbst fehlt
- [ ] Apps unter einer Minute fehlen, Fußzeile nennt ihre Zahl
- [ ] Zahlen grob gegen „Digital Wellbeing" gegenprüfen — kleine Abweichungen
      sind normal, große weisen auf einen Fehler in den Rändern hin
- [ ] Gesperrte App öffnen: Sperrschirm zeigt „Heute: …" für genau diese App
- [ ] Zweite gesperrte App öffnen: die Zeile wechselt mit
- [ ] Berechtigung entziehen: Zeile auf dem Sperrschirm verschwindet, Reiter
      zeigt wieder den Hinweis
- [ ] Nach Mitternacht: Summen fangen wieder bei null an
- [ ] Fehlerbericht enthält „Nutzungsdaten: erlaubt", aber keine Zeiten
```

- [ ] **Schritt 2: Build-Nummer erhöhen**

`lib/build_info.dart`:

```dart
const int kBuildNumber = 7;
```

`pubspec.yaml`:

```yaml
version: 1.0.0+7
```

- [ ] **Schritt 3: Alles prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: sauber, 35 Dart-Tests, 181 Kotlin-Tests, 0 Fehlschläge.

- [ ] **Schritt 4: Am Emulator prüfen**

Frische Installation, **ohne** Berechtigungen vorab zu setzen:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && flutter build apk --debug && "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" uninstall com.klaas.nfc_riegel; "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-debug.apk
```

Dann starten und nachsehen, dass die App nicht abstürzt und der Reiter den Hinweis zeigt:

```bash
export MSYS_NO_PATHCONV=1; A="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"; $A logcat -c; $A shell monkey -p com.klaas.nfc_riegel -c android.intent.category.LAUNCHER 1; sleep 7; $A shell dumpsys window | grep -o "mCurrentFocus=.*" | head -1; $A logcat -d | grep -c "FATAL EXCEPTION"
```

Erwartet: `mCurrentFocus` zeigt auf `MainActivity`, Abstürze: 0.

Berechtigung erteilen und die Liste gegenprüfen:

```bash
export MSYS_NO_PATHCONV=1; A="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"; $A shell appops set com.klaas.nfc_riegel GET_USAGE_STATS allow; $A shell monkey -p com.klaas.nfc_riegel -c android.intent.category.LAUNCHER 1
```

- [ ] **Schritt 5: Release bauen und ablegen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && flutter build apk --release && cp build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" && md5sum build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

Beide MD5-Summen müssen übereinstimmen. Danach die Versionsnummer in der abgelegten Datei prüfen:

```bash
"$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt2.exe" dump badging "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" | head -1
```

Erwartet: `versionCode='7'`.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel && git commit -m "chore: Screenzeit in der Prueflisten und Build 7"
```

---

## Selbstprüfung gegen die Spec

| Spec-Abschnitt | Task |
|---|---|
| Ereignisse statt Tageseimer | 1 |
| `UsageEvent`, `ScreenTimeCalculator`, `UsageStatsSource` | 1, 2 |
| Die drei Ränder | 1 |
| Berechtigung erst im Reiter, `AppOpsManager` | 2, 6 |
| Zwei Reiter, erster heißt „Sperre" | 7 |
| Reiter: Tagessumme, Liste, Schwelle, Fußzeile | 6 |
| Riegel selbst fehlt in Liste und Summe | 3 (über `launchableApps`) |
| Dauerformat ohne Sekunden | 5 (Dart), 8 (Kotlin) |
| Sperrschirm: eine Zeile, nur die abgefangene App | 8 |
| Sperrschirm ohne Berechtigung: Zeile weg | 8 |
| Paket per Extra an den Sperrschirm | 8 |
| Fehlerbericht: Zustand ja, Zeiten nein | 4 |

**Bewusst nicht enthalten** (wie in der Spec): Verlauf über mehrere Tage, Diagramme, Wochenansicht, Zeitbudgets, Warnungen, Export, eigener Speicher.
