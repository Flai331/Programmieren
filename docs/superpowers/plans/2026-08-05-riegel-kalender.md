# Kalendereinbindung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Termine im Android-Systemkalender sperren die Apps eines zugeordneten Profils für ihre Dauer — ohne Chip, ohne Zutun.

**Architecture:** Die Kalendersperre ist eine dritte Sperrquelle neben `chipLock` und `timeLocks`, aber **kein gespeicherter Zustand**: sie wird aus zwischengespeicherten Terminfenstern und der Uhrzeit gerechnet. Die Rechenlogik liegt in einem reinen `CalendarPlanner` ohne Android-Bezug, damit sie per JUnit prüfbar ist. `CalendarContract` wird hinter der Schnittstelle `CalendarSource` gekapselt und im Test durch eine feste Fensterliste ersetzt.

**Tech Stack:** Kotlin (JUnit 4.13.2), Flutter 3.44 / Dart 3.12, `CalendarContract`, `AlarmManager`, `ContentObserver`, MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** `docs/superpowers/specs/2026-08-04-riegel-kalender-design.md`
**Setzt voraus:** `2026-08-05-riegel-zeitsperren-design.md` (umgesetzt, 113 Kotlin-Tests grün)

---

## Vorbemerkungen für die Umsetzung

**Gradle.** `JAVA_HOME` zeigt auf dieser Maschine auf JVM 8, Gradle braucht 17. Vor jedem Aufruf setzen:

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
```

Verifikation immer auf `:app` eingeschränkt — ohne den Doppelpunkt laufen alle Module mit, darunter `image_picker` mit eigenen Tests:

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Die Gradle-Ausgabe nennt **keine Testzahl**. Sie steht in `nfc_riegel/build/app/test-results/testDebugUnitTest/TEST-*.xml`, Attribute `tests`, `failures`, `errors` am `testsuite`-Element.

**Ausgangslage:** 113 Kotlin-Tests, 15 Dart-Tests, `flutter analyze` sauber.

**Reihenfolge.** Tasks 1–5 sind rein additiv und einzeln grün. Task 6 bringt die erste Android-Abhängigkeit. Ab Task 11 ändert sich der Kanal, weshalb `flutter analyze` erst nach Task 13 wieder sauber ist. Nicht umstellen.

**`nfc_riegel/lib/secrets.dart` niemals lesen, ändern oder committen** — steht in `.gitignore`, enthält den echten Notion-Token.

---

## Dateiübersicht

| Datei | Zuständigkeit | Task |
|---|---|---|
| `CalendarWindow.kt` | Terminfenster und Kalendereinstellungen als reine Daten | 1 |
| `LockState.kt` | um `calendar` erweitert | 1 |
| `LockCodec.kt` | Fenster und Einstellungen ⇄ String | 2 |
| `CalendarPlanner.kt` | aktive Fenster, Festnageln, Unterdrückung, nächste Grenze | 3, 4 |
| `LockEngine.kt` | Kalendersperren in Blockliste, Wächter, Unterdrückung beim Abräumen | 5 |
| `CalendarSource.kt` | Schnittstelle + `CalendarContract`-Umsetzung | 6 |
| `CalendarPermission.kt` | `READ_CALENDAR` zur Laufzeit | 7 |
| `CalendarWatcher.kt` | `ContentObserver` | 8 |
| `LockController.kt` | Einlesen, Wecker auf `min(Grenze, +12 h)` | 9 |
| `Diagnostics.kt` | Kalenderlage im Fehlerbericht | 10 |
| `RiegelChannel.kt` | Kalendereinstellungen lesen und schreiben | 11 |
| `lock_status.dart` | `CalendarInfo`, `CalendarWindowInfo`, Einstellungen | 12 |
| `calendar_screen.dart` | Schalter, Kalenderliste, Stichwort, Vorschau | 13 |
| `home_screen.dart`, `BlockActivity.kt` | Termin statt Profilname anzeigen | 14 |
| `GERAETETEST.md`, Build | Prüfliste, APK, Build 4 | 15 |

---

### Task 1: Datenmodell für Fenster und Einstellungen

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarWindow.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockState.kt`

Rein additiv: `LockState` bekommt ein Feld mit Vorgabewert, kein bestehender Aufrufer ändert sich.

- [x] **Schritt 1: `CalendarWindow.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

/**
 * Ein Termin, der sperren soll, reduziert auf das Nötige. Zwischenspeicher —
 * die Wahrheit steht im Kalender des Geräts.
 */
data class CalendarWindow(
    val eventId: String,
    val title: String,
    val startsAt: Long,
    val endsAt: Long,
    val profileId: String,
)

/** Welche Termine eines Kalenders sperren. */
enum class CalendarMatch {
    /** Jeder Termin des Kalenders. */
    ALL,

    /** Nur Termine, deren Titel den Stichwortmarker enthält. */
    KEYWORD,
}

/**
 * Regel für einen Kalender des Geräts. Kalender ohne Regel sperren nicht — es
 * gibt bewusst kein „aus" als eigenen Wert, das Fehlen der Regel ist das Aus.
 */
data class CalendarRule(
    val profileId: String,
    val match: CalendarMatch = CalendarMatch.ALL,
)

/**
 * Alles, was der Nutzer an der Kalenderfunktion einstellt, plus der
 * Zwischenspeicher. Eigene Klasse statt neun Felder in [LockState] — sie
 * gehören zusammen und werden gemeinsam geschrieben.
 */
data class CalendarSettings(
    val enabled: Boolean = false,
    /** Kalender-ID des Geräts → Regel. Nicht enthaltene Kalender sperren nicht. */
    val calendarRules: Map<String, CalendarRule> = emptyMap(),
    val keywordMarker: String = "[Riegel]",
    /** Profil für Treffer der eigenständigen Stichwortregel. */
    val keywordProfileId: String? = null,
    /**
     * In welchen Kalendern die eigenständige Stichwortregel sucht.
     * **Leer heißt: in allen.** Das ist die Vorgabe und der häufige Fall — wer
     * einen Marker vergibt, will ihn meist überall wirken lassen.
     */
    val keywordCalendarIds: Set<String> = emptySet(),
    val cachedWindows: List<CalendarWindow> = emptyList(),
    val windowsFetchedAt: Long = 0L,
    /** eventId → festgenageltes Ende, siehe [Profile.pinCalendarEnd]. */
    val pinnedEnds: Map<String, Long> = emptyMap(),
    /**
     * Vom Generalschlüssel oder Notfall-Code gesetzt: bis hierhin sperrt der
     * Kalender nicht. Ohne dieses Feld griffe die Sperre sofort wieder, weil sie
     * ja aus dem Kalender gerechnet wird.
     */
    val suppressedUntil: Long? = null,
)
```

**Zwei Regelarten nebeneinander.** Ein Kalender kann auf „alle Termine" oder „nur
Stichwort" stehen und bringt sein eigenes Profil mit. Unabhängig davon sucht die
Stichwortregel in den Kalendern aus `keywordCalendarIds` (leer = alle) und
benutzt `keywordProfileId`. Welche gewinnt, legt Task 4 fest.

> **Hinweis für die Umsetzung:** `CalendarWindow.kt` und das Feld in `LockState`
> existieren aus einem früheren Anlauf bereits, dort aber noch mit
> `calendarProfiles: Map<String, String>` statt `calendarRules`. Schreibe die
> Datei auf den oben gezeigten Zielinhalt — nicht danebenlegen, nicht ergänzen.

- [x] **Schritt 2: `LockState` erweitern**

Ersetze in `LockState.kt` den Kopfkommentar über `LockMode` und ergänze das Feld. Der alte Kommentar behauptet noch, `TIMER` und `UNTIL` endeten durch erneuten Scan — seit der Zeitsperren-Umstellung falsch.

```kotlin
/**
 * OPEN = Chipsperre bis erneuter Scan. TIMER = Zeitsperre für eine Dauer,
 * UNTIL = Zeitsperre bis zu einem absoluten Zeitpunkt. Zeitsperren enden
 * vorzeitig nur durch Generalschlüssel oder Notfall-Code.
 */
enum class LockMode { OPEN, TIMER, UNTIL }
```

und in der `data class LockState` hinter `timeLocks`:

```kotlin
    val calendar: CalendarSettings = CalendarSettings(),
```

- [x] **Schritt 3: Übersetzen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: BUILD SUCCESSFUL, weiterhin 113 Tests, 0 Fehlschläge.

- [x] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Datenmodell fuer Terminfenster und Kalendereinstellungen"
```

---

### Task 2: Codec für Fenster und Einstellungen

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt`

`LockCodec` benutzt Steuerzeichen als Trenner: `RECORD` = `\u0001`, `FIELD` = `\u0002`, `ITEM` = `\u0003`. Für die verschachtelten Karten (`calendarProfiles`, `pinnedEnds`) wird ein vierter Trenner `PAIR` = `\u0004` gebraucht — ITEM trennt die Paare, PAIR trennt Schlüssel und Wert.

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `LockCodecTest.kt`, vor die schließende Klammer:

```kotlin
    @Test
    fun `Terminfenster ueberstehen Kodieren und Dekodieren`() {
        val fenster = listOf(
            CalendarWindow("e1", "Konzept schreiben", 1_000L, 2_000L, "p1"),
            CalendarWindow("e2", "Sport", 3_000L, 4_000L, "p2"),
        )

        val zurueck = LockCodec.decodeWindows(LockCodec.encodeWindows(fenster))

        assertEquals(fenster, zurueck)
    }

    @Test
    fun `leere Fensterliste ergibt leeren String und zurueck`() {
        assertEquals("", LockCodec.encodeWindows(emptyList()))
        assertTrue(LockCodec.decodeWindows("").isEmpty())
    }

    @Test
    fun `Kalendereinstellungen ueberstehen Kodieren und Dekodieren`() {
        val einstellungen = CalendarSettings(
            enabled = true,
            calendarRules = mapOf(
                "cal1" to CalendarRule("p1", CalendarMatch.ALL),
                "cal2" to CalendarRule("p2", CalendarMatch.KEYWORD),
            ),
            keywordMarker = "[Fokus]",
            keywordProfileId = "p2",
            keywordCalendarIds = setOf("cal3", "cal4"),
            cachedWindows = listOf(CalendarWindow("e1", "Termin", 1_000L, 2_000L, "p1")),
            windowsFetchedAt = 5_000L,
            pinnedEnds = mapOf("e1" to 2_000L),
            suppressedUntil = 9_000L,
        )

        val zurueck = LockCodec.decodeCalendar(LockCodec.encodeCalendar(einstellungen))

        assertEquals(einstellungen, zurueck)
    }

    @Test
    fun `leere Stichwort-Kalenderliste bleibt leer`() {
        val einstellungen = CalendarSettings(enabled = true, keywordCalendarIds = emptySet())

        val zurueck = LockCodec.decodeCalendar(LockCodec.encodeCalendar(einstellungen))

        assertTrue(zurueck.keywordCalendarIds.isEmpty())
    }

    @Test
    fun `unbekannte Trefferart faellt auf ALL zurueck`() {
        val roh = LockCodec.encodeCalendar(
            CalendarSettings(calendarRules = mapOf("cal1" to CalendarRule("p1")))
        ).replace("ALL", "QUATSCH")

        val zurueck = LockCodec.decodeCalendar(roh)

        assertEquals(CalendarMatch.ALL, zurueck.calendarRules.getValue("cal1").match)
    }

    @Test
    fun `Kalendereinstellungen ohne Angaben ergeben die Vorgaben`() {
        val zurueck = LockCodec.decodeCalendar("")

        assertEquals(CalendarSettings(), zurueck)
    }

    @Test
    fun `Termintitel mit Sonderzeichen ueberlebt den Rundlauf`() {
        val fenster = listOf(CalendarWindow("e1", "Team-Meeting: Q4 (wichtig!)", 1L, 2L, "p1"))

        assertEquals(fenster, LockCodec.decodeWindows(LockCodec.encodeWindows(fenster)))
    }
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: Übersetzungsfehler „Unresolved reference: encodeWindows".

- [x] **Schritt 3: Codec ergänzen**

In `LockCodec.kt` neben die bestehenden Trenner:

```kotlin
    private const val PAIR = '\u0004'
```

und ans Ende des `object`:

```kotlin
    fun encodeWindows(windows: List<CalendarWindow>): String =
        windows.joinToString(RECORD.toString()) { w ->
            listOf(
                w.eventId,
                w.title,
                w.startsAt.toString(),
                w.endsAt.toString(),
                w.profileId,
            ).joinToString(FIELD.toString())
        }

    fun decodeWindows(raw: String): List<CalendarWindow> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(RECORD).mapNotNull { record ->
            val f = record.split(FIELD)
            if (f.size != 5) return@mapNotNull null
            CalendarWindow(
                eventId = f[0],
                title = f[1],
                startsAt = f[2].toLongOrNull() ?: return@mapNotNull null,
                endsAt = f[3].toLongOrNull() ?: return@mapNotNull null,
                profileId = f[4],
            )
        }
    }

    private fun encodeMap(map: Map<String, String>): String =
        map.entries.joinToString(ITEM.toString()) { "${it.key}$PAIR${it.value}" }

    private fun decodeMap(raw: String): Map<String, String> {
        if (raw.isEmpty()) return emptyMap()
        return raw.split(ITEM).mapNotNull { paar ->
            val teile = paar.split(PAIR)
            if (teile.size != 2) null else teile[0] to teile[1]
        }.toMap()
    }

    /**
     * Eine Kalenderregel als `id PAIR profilId PAIR trefferart`, Regeln durch
     * ITEM getrennt.
     */
    private fun encodeRules(rules: Map<String, CalendarRule>): String =
        rules.entries.joinToString(ITEM.toString()) { (id, regel) ->
            "$id$PAIR${regel.profileId}$PAIR${regel.match.name}"
        }

    private fun decodeRules(raw: String): Map<String, CalendarRule> {
        if (raw.isEmpty()) return emptyMap()
        return raw.split(ITEM).mapNotNull { eintrag ->
            val teile = eintrag.split(PAIR)
            if (teile.size != 3) return@mapNotNull null
            teile[0] to CalendarRule(
                profileId = teile[1],
                match = runCatching { CalendarMatch.valueOf(teile[2]) }
                    .getOrDefault(CalendarMatch.ALL),
            )
        }.toMap()
    }

    /**
     * Die Fensterliste steckt als eigenes Feld mit RECORD- und FIELD-Trennern in
     * einem FIELD-getrennten Datensatz. Das geht nur, weil die äußere Aufteilung
     * mit `limit` arbeitet und das Fensterfeld zuletzt steht.
     */
    fun encodeCalendar(c: CalendarSettings): String = listOf(
        if (c.enabled) "1" else "0",
        encodeRules(c.calendarRules),
        c.keywordMarker,
        c.keywordProfileId ?: "",
        c.keywordCalendarIds.joinToString(ITEM.toString()),
        c.windowsFetchedAt.toString(),
        encodeMap(c.pinnedEnds.mapValues { it.value.toString() }),
        c.suppressedUntil?.toString() ?: "",
        encodeWindows(c.cachedWindows),
    ).joinToString(FIELD.toString())

    fun decodeCalendar(raw: String): CalendarSettings {
        if (raw.isEmpty()) return CalendarSettings()
        val f = raw.split(FIELD, limit = 9)
        if (f.size != 9) return CalendarSettings()
        return CalendarSettings(
            enabled = f[0] == "1",
            calendarRules = decodeRules(f[1]),
            keywordMarker = f[2],
            keywordProfileId = f[3].takeIf { it.isNotEmpty() },
            keywordCalendarIds = if (f[4].isEmpty()) emptySet()
            else f[4].split(ITEM).toSet(),
            windowsFetchedAt = f[5].toLongOrNull() ?: 0L,
            pinnedEnds = decodeMap(f[6]).mapNotNull { (k, v) ->
                v.toLongOrNull()?.let { k to it }
            }.toMap(),
            suppressedUntil = f[7].toLongOrNull(),
            cachedWindows = decodeWindows(f[8]),
        )
    }
```

- [x] **Schritt 4: Zustand ablegen und laden**

In `SharedPrefsLockStore.kt` in `load()` hinter `codeLockedUntil`:

```kotlin
            calendar = LockCodec.decodeCalendar(prefs.getString(KEY_CALENDAR, "") ?: ""),
```

in `save()` vor `.apply()`:

```kotlin
            .putString(KEY_CALENDAR, LockCodec.encodeCalendar(state.calendar))
```

und in das `companion object`:

```kotlin
        const val KEY_CALENDAR = "calendar"
```

- [x] **Schritt 5: Tests laufen lassen**

Erwartet: 120 Tests, 0 Fehlschläge.

- [x] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalenderfenster und -einstellungen im Codec"
```

---

### Task 3: `CalendarPlanner` — aktive Fenster

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarPlanner.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/CalendarPlannerTest.kt`

Reine Funktionen ohne Android und ohne Speicher. Bekommen die Einstellungen und die Uhrzeit, geben zurück, welche Fenster jetzt sperren.

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CalendarPlannerTest {

    private val jetzt = 1_000_000L
    private val minute = 60_000L

    private fun fenster(
        id: String = "e1",
        von: Long = jetzt - minute,
        bis: Long = jetzt + minute,
        profil: String = "p1",
    ) = CalendarWindow(id, "Termin $id", von, bis, profil)

    private fun einstellungen(
        vararg fenster: CalendarWindow,
        an: Boolean = true,
        unterdruecktBis: Long? = null,
        festgenagelt: Map<String, Long> = emptyMap(),
    ) = CalendarSettings(
        enabled = an,
        cachedWindows = fenster.toList(),
        suppressedUntil = unterdruecktBis,
        pinnedEnds = festgenagelt,
    )

    @Test
    fun `laufendes Fenster sperrt`() {
        val aktiv = CalendarPlanner.activeWindows(einstellungen(fenster()), jetzt)

        assertEquals(listOf("e1"), aktiv.map { it.eventId })
    }

    @Test
    fun `vergangenes Fenster sperrt nicht`() {
        val alt = fenster(von = jetzt - 10 * minute, bis = jetzt - minute)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(alt), jetzt).isEmpty())
    }

    @Test
    fun `kuenftiges Fenster sperrt nicht`() {
        val spaeter = fenster(von = jetzt + minute, bis = jetzt + 10 * minute)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(spaeter), jetzt).isEmpty())
    }

    @Test
    fun `Fenster genau am Ende sperrt nicht mehr`() {
        val endetJetzt = fenster(von = jetzt - minute, bis = jetzt)

        assertTrue(CalendarPlanner.activeWindows(einstellungen(endetJetzt), jetzt).isEmpty())
    }

    @Test
    fun `ausgeschaltete Kalenderfunktion sperrt nie`() {
        val aus = einstellungen(fenster(), an = false)

        assertTrue(CalendarPlanner.activeWindows(aus, jetzt).isEmpty())
    }

    @Test
    fun `zwei ueberlappende Fenster gelten beide`() {
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val aktiv = CalendarPlanner.activeWindows(einstellungen(a, b), jetzt)

        assertEquals(setOf("e1", "e2"), aktiv.map { it.eventId }.toSet())
    }

    @Test
    fun `Unterdrueckung schaltet das laufende Fenster ab`() {
        val e = einstellungen(fenster(), unterdruecktBis = jetzt + minute)

        assertTrue(CalendarPlanner.activeWindows(e, jetzt).isEmpty())
    }

    @Test
    fun `Unterdrueckung laesst das naechste Fenster unberuehrt`() {
        val laufend = fenster(id = "e1", von = jetzt - minute, bis = jetzt + minute)
        val spaeter = fenster(id = "e2", von = jetzt + 2 * minute, bis = jetzt + 3 * minute)
        val e = einstellungen(laufend, spaeter, unterdruecktBis = jetzt + minute)

        val aktiv = CalendarPlanner.activeWindows(e, jetzt + 2 * minute + 1)

        assertEquals(listOf("e2"), aktiv.map { it.eventId })
    }

    @Test
    fun `festgenageltes Ende gilt auch wenn der Termin verschwunden ist`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt + minute))

        val aktiv = CalendarPlanner.activeWindows(e, jetzt)

        assertEquals(listOf("e1"), aktiv.map { it.eventId })
    }

    @Test
    fun `festgenageltes Ende schlaegt ein vorgezogenes Ende im Kalender`() {
        val verkuerzt = fenster(bis = jetzt - minute)
        val e = einstellungen(verkuerzt, festgenagelt = mapOf("e1" to jetzt + minute))

        assertEquals(listOf("e1"), CalendarPlanner.activeWindows(e, jetzt).map { it.eventId })
    }

    @Test
    fun `abgelaufenes festgenageltes Ende sperrt nicht mehr`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt - 1))

        assertTrue(CalendarPlanner.activeWindows(e, jetzt).isEmpty())
    }

    @Test
    fun `gesperrte Profile stammen aus den laufenden Fenstern`() {
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val profile = CalendarPlanner.lockedProfileIds(einstellungen(a, b), jetzt)

        assertEquals(setOf("p1", "p2"), profile)
    }

    @Test
    fun `ohne laufendes Fenster gibt es kein gesperrtes Profil`() {
        assertTrue(CalendarPlanner.lockedProfileIds(einstellungen(), jetzt).isEmpty())
    }

    @Test
    fun `festzunagelnde Enden entstehen nur fuer Profile mit pinCalendarEnd`() {
        val mitNagel = Profile("p1", "Arbeit", pinCalendarEnd = true)
        val ohneNagel = Profile("p2", "Nacht", pinCalendarEnd = false)
        val a = fenster(id = "e1", profil = "p1")
        val b = fenster(id = "e2", profil = "p2")

        val neu = CalendarPlanner.pinsToAdd(
            einstellungen(a, b),
            listOf(mitNagel, ohneNagel),
            jetzt,
        )

        assertEquals(mapOf("e1" to jetzt + minute), neu)
    }

    @Test
    fun `bereits festgenagelte Fenster werden nicht neu genagelt`() {
        val mitNagel = Profile("p1", "Arbeit", pinCalendarEnd = true)
        val a = fenster(id = "e1", profil = "p1")
        val e = einstellungen(a, festgenagelt = mapOf("e1" to jetzt + 5 * minute))

        assertTrue(CalendarPlanner.pinsToAdd(e, listOf(mitNagel), jetzt).isEmpty())
    }

    @Test
    fun `vergangene Naegel werden aufgeraeumt`() {
        val e = einstellungen(
            festgenagelt = mapOf("alt" to jetzt - 1, "neu" to jetzt + minute),
        )

        assertEquals(mapOf("neu" to jetzt + minute), CalendarPlanner.prunePins(e, jetzt))
    }
}
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Unresolved reference: CalendarPlanner".

- [x] **Schritt 3: `CalendarPlanner.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

/**
 * Rechnet die Kalendersperre aus den zwischengespeicherten Fenstern und der
 * Uhrzeit. Bewusst kein gespeicherter Zustand: verschiebst oder löschst du einen
 * laufenden Termin, verschwindet die Sperre mit — der Kalender bleibt die
 * Wahrheit über sich selbst. Ausnahme sind festgenagelte Enden.
 *
 * Reine Funktionen ohne Android und ohne Speicher, damit sie per JUnit prüfbar
 * bleiben.
 */
object CalendarPlanner {

    /**
     * Fenster, die jetzt sperren. Ein festgenageltes Ende schlägt das Ende aus
     * dem Kalender und überlebt sogar das Löschen des Termins.
     */
    fun activeWindows(c: CalendarSettings, now: Long): List<CalendarWindow> {
        if (!c.enabled) return emptyList()
        if (c.suppressedUntil != null && now < c.suppressedUntil) return emptyList()

        val ausKalender = c.cachedWindows.filter { fenster ->
            val ende = c.pinnedEnds[fenster.eventId] ?: fenster.endsAt
            fenster.startsAt <= now && now < ende
        }

        // Genagelte Fenster, deren Termin aus dem Kalender verschwunden ist. Genau
        // dafür gibt es das Festnageln: Löschen darf die Sperre nicht abkürzen.
        val bekannt = c.cachedWindows.map { it.eventId }.toSet()
        val verwaist = c.pinnedEnds
            .filter { (id, ende) -> id !in bekannt && now < ende }
            .map { (id, ende) -> CalendarWindow(id, "Termin", 0L, ende, profileIdFor(c, id)) }

        return ausKalender + verwaist
    }

    /**
     * Ein verwaistes Fenster kennt sein Profil nicht mehr — der Termin ist weg.
     * Die Zuordnung stand im zwischengespeicherten Fenster, das mit ihm
     * verschwunden ist; als Rückfall dient das Stichwortprofil.
     */
    private fun profileIdFor(c: CalendarSettings, eventId: String): String =
        c.cachedWindows.firstOrNull { it.eventId == eventId }?.profileId
            ?: c.keywordProfileId
            ?: ""

    fun lockedProfileIds(c: CalendarSettings, now: Long): Set<String> =
        activeWindows(c, now).map { it.profileId }.filter { it.isNotEmpty() }.toSet()

    /**
     * Enden, die jetzt festzunageln sind: laufende Fenster, deren Profil
     * [Profile.pinCalendarEnd] gesetzt hat und die noch keinen Nagel haben.
     */
    fun pinsToAdd(
        c: CalendarSettings,
        profiles: List<Profile>,
        now: Long,
    ): Map<String, Long> {
        val nagelnde = profiles.filter { it.pinCalendarEnd }.map { it.id }.toSet()
        return activeWindows(c, now)
            .filter { it.profileId in nagelnde && it.eventId !in c.pinnedEnds }
            .associate { it.eventId to it.endsAt }
    }

    /** Nägel, deren Zeitpunkt vergangen ist, fallen weg. */
    fun prunePins(c: CalendarSettings, now: Long): Map<String, Long> =
        c.pinnedEnds.filter { now < it.value }
}
```

- [x] **Schritt 4: Tests laufen lassen**

Erwartet: 136 Tests, 0 Fehlschläge.

- [x] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalenderfenster zu Sperren rechnen"
```

---

### Task 4: `CalendarPlanner` — nächste Grenze und Auswahl der Fenster

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarPlanner.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/CalendarPlannerTest.kt`

Zwei Ergänzungen: wann der Wecker klingeln muss, und welches Profil ein Rohtermin bekommt (Kalenderzuordnung schlägt Stichwort).

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `CalendarPlannerTest.kt`, vor die schließende Klammer:

```kotlin
    @Test
    fun `naechste Grenze ist der Beginn des naechsten Fensters`() {
        val spaeter = fenster(von = jetzt + 5 * minute, bis = jetzt + 10 * minute)

        val grenze = CalendarPlanner.nextBoundary(einstellungen(spaeter), jetzt)

        assertEquals(jetzt + 5 * minute, grenze)
    }

    @Test
    fun `naechste Grenze ist das Ende des laufenden Fensters`() {
        val grenze = CalendarPlanner.nextBoundary(einstellungen(fenster()), jetzt)

        assertEquals(jetzt + minute, grenze)
    }

    @Test
    fun `naechste Grenze nimmt die frueheste von mehreren`() {
        val a = fenster(id = "e1", von = jetzt - minute, bis = jetzt + 3 * minute)
        val b = fenster(id = "e2", von = jetzt + minute, bis = jetzt + 9 * minute)

        assertEquals(jetzt + minute, CalendarPlanner.nextBoundary(einstellungen(a, b), jetzt))
    }

    @Test
    fun `ohne Fenster gibt es keine Grenze`() {
        assertNull(CalendarPlanner.nextBoundary(einstellungen(), jetzt))
    }

    @Test
    fun `bei ausgeschalteter Kalenderfunktion gibt es keine Grenze`() {
        assertNull(CalendarPlanner.nextBoundary(einstellungen(fenster(), an = false), jetzt))
    }

    @Test
    fun `festgenageltes Ende zaehlt als Grenze`() {
        val e = einstellungen(festgenagelt = mapOf("e1" to jetzt + 2 * minute))

        assertEquals(jetzt + 2 * minute, CalendarPlanner.nextBoundary(e, jetzt))
    }

    @Test
    fun `Kalender auf ALL sperrt mit jedem Termin`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.ALL)),
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalender auf KEYWORD sperrt nur bei Treffer`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Riegel]",
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "[Riegel] Konzept"))
        assertNull(CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalenderregel schlaegt die Stichwortregel`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.ALL)),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
        )

        assertEquals("p1", CalendarPlanner.profileForEvent(c, "cal1", "[Riegel] Sport"))
    }

    @Test
    fun `Kalender auf KEYWORD ohne Treffer faellt auf die Stichwortregel zurueck`() {
        // cal1 sucht nach [Arbeit], die eigenständige Regel nach demselben Marker
        // in allen Kalendern — hier greift sie nicht, weil der Titel nichts trifft.
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
        )

        assertNull(CalendarPlanner.profileForEvent(c, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Stichwortregel greift ohne Kalenderauswahl ueberall`() {
        val c = CalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1")),
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
            keywordCalendarIds = emptySet(),
        )

        assertEquals("p9", CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
    }

    @Test
    fun `Stichwortregel sucht nur in den ausgewaehlten Kalendern`() {
        val c = CalendarSettings(
            enabled = true,
            keywordMarker = "[Riegel]",
            keywordProfileId = "p9",
            keywordCalendarIds = setOf("cal2"),
        )

        assertEquals("p9", CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
        assertNull(CalendarPlanner.profileForEvent(c, "cal3", "[Riegel] Sport"))
    }

    @Test
    fun `Termin ohne Regel und ohne Stichwort sperrt nicht`() {
        val c = CalendarSettings(enabled = true, keywordProfileId = "p9")

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "Zahnarzt"))
    }

    @Test
    fun `Stichwort ohne hinterlegtes Profil sperrt nicht`() {
        val c = CalendarSettings(enabled = true, keywordProfileId = null)

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "[Riegel] Sport"))
    }

    @Test
    fun `leerer Marker trifft nie`() {
        val c = CalendarSettings(
            enabled = true,
            keywordMarker = "",
            keywordProfileId = "p9",
        )

        assertNull(CalendarPlanner.profileForEvent(c, "cal2", "Irgendein Termin"))
    }
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Unresolved reference: nextBoundary".

- [x] **Schritt 3: `CalendarPlanner` ergänzen**

Ans Ende des `object`:

```kotlin
    /**
     * Wann sich die Sperrlage das nächste Mal ändert: der frühere von Beginn des
     * nächsten und Ende des laufenden Fensters. Darauf wird der Wecker gesetzt.
     */
    fun nextBoundary(c: CalendarSettings, now: Long): Long? {
        if (!c.enabled) return null
        val grenzen = mutableListOf<Long>()
        for (fenster in c.cachedWindows) {
            if (now < fenster.startsAt) grenzen += fenster.startsAt
            val ende = c.pinnedEnds[fenster.eventId] ?: fenster.endsAt
            if (now < ende) grenzen += ende
        }
        for ((_, ende) in c.pinnedEnds) {
            if (now < ende) grenzen += ende
        }
        return grenzen.minOrNull()
    }

    /**
     * Welches Profil ein Termin bekommt. Zwei Regelarten in fester Rangfolge:
     *
     * 1. Die Regel des Kalenders, in dem der Termin steht — die spezifischere
     *    Angabe. Steht sie auf [CalendarMatch.ALL], gilt sie für jeden Termin;
     *    auf [CalendarMatch.KEYWORD] nur bei Treffer im Titel.
     * 2. Die eigenständige Stichwortregel, sofern der Kalender in
     *    [CalendarSettings.keywordCalendarIds] steht oder diese Menge leer ist.
     *
     * Trifft weder noch, sperrt der Termin nicht.
     */
    fun profileForEvent(c: CalendarSettings, calendarId: String, title: String): String? {
        val trifftMarker = c.keywordMarker.isNotEmpty() && title.contains(c.keywordMarker)

        val regel = c.calendarRules[calendarId]
        if (regel != null) {
            when (regel.match) {
                CalendarMatch.ALL -> return regel.profileId
                // Kein Treffer heißt nicht „fertig": die eigenständige Regel darf
                // es noch versuchen. Nur wenn die Kalenderregel greift, hat sie
                // Vorrang.
                CalendarMatch.KEYWORD -> if (trifftMarker) return regel.profileId
            }
        }

        if (!trifftMarker) return null
        val imSuchbereich = c.keywordCalendarIds.isEmpty() || calendarId in c.keywordCalendarIds
        return if (imSuchbereich) c.keywordProfileId else null
    }
```

- [x] **Schritt 4: Tests laufen lassen**

Erwartet: 151 Tests, 0 Fehlschläge.

- [x] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: naechste Fenstergrenze und Profilzuordnung"
```

---

### Task 5: Engine kennt die Kalendersperre

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCalendarTest.kt` (neu)

Drei Änderungen: `lockedProfileIds` bezieht Kalenderfenster ein, `clearAll` setzt die Unterdrückung, und es kommt ein Schreibweg für Einstellungen und Fenster dazu.

**Wichtig:** `clearChipLock` bleibt unberührt. Ein normaler Chip kommt an die Kalendersperre nicht heran — das ist der Kern des Zwei-Spuren-Modells.

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LockEngineCalendarTest {

    private val jetzt = 1_000_000L
    private val minute = 60_000L

    private val arbeit = Profile("p1", "Arbeit", setOf("com.a"))
    private val nacht = Profile("p2", "Nacht", setOf("com.b"))

    private fun engine(
        kalender: CalendarSettings = CalendarSettings(),
        chipLock: ChipLock? = null,
        tags: List<TagBinding> = listOf(TagBinding("04AA", "Schreibtisch", "p1")),
    ): Pair<LockEngine, FakeLockStore> {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit, nacht),
                tags = tags,
                chipLock = chipLock,
                calendar = kalender,
            )
        )
        return LockEngine(store) to store
    }

    private fun laufendesFenster(profil: String = "p1") = CalendarSettings(
        enabled = true,
        cachedWindows = listOf(
            CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, profil),
        ),
    )

    @Test
    fun `laufendes Fenster sperrt die Apps seines Profils`() {
        val (e, _) = engine(laufendesFenster())

        assertEquals(setOf("com.a"), e.blockedPackages(jetzt))
    }

    @Test
    fun `Kalendersperre und Chipsperre werden vereinigt`() {
        val (e, _) = engine(laufendesFenster("p1"), chipLock = ChipLock("p2"))

        assertEquals(setOf("com.a", "com.b"), e.blockedPackages(jetzt))
    }

    @Test
    fun `vergangenes Fenster sperrt nichts`() {
        val alt = CalendarSettings(
            enabled = true,
            cachedWindows = listOf(
                CalendarWindow("e1", "Konzept", jetzt - 10 * minute, jetzt - minute, "p1"),
            ),
        )
        val (e, _) = engine(alt)

        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Profil mit laufendem Fenster ist nicht bearbeitbar`() {
        val (e, _) = engine(laufendesFenster())

        assertFalse(e.updateProfile(arbeit.copy(name = "Neu"), jetzt))
    }

    @Test
    fun `anderes Profil bleibt waehrend einer Kalendersperre bearbeitbar`() {
        val (e, _) = engine(laufendesFenster("p1"))

        assertTrue(e.updateProfile(nacht.copy(name = "Neu"), jetzt))
    }

    @Test
    fun `waehrend einer Kalendersperre laesst sich kein Chip anlernen`() {
        val (e, _) = engine(laufendesFenster())

        assertFalse(e.enrollTag("04BB", "Neu", "p1", isMaster = false, now = jetzt))
    }

    @Test
    fun `normaler Chip beendet die Kalendersperre nicht`() {
        val (e, store) = engine(laufendesFenster("p1"), chipLock = ChipLock("p1"))

        val ergebnis = e.onTagScanned("04AA", jetzt)

        assertEquals(ScanOutcome.UNLOCKED, ergebnis.outcome)
        assertNull(store.current.chipLock)
        // Kalendersperre steht weiter
        assertEquals(setOf("com.a"), e.blockedPackages(jetzt))
    }

    @Test
    fun `Generalschluessel beendet die Kalendersperre und unterdrueckt sie`() {
        val (e, store) = engine(
            laufendesFenster("p1"),
            tags = listOf(TagBinding("04MM", "General", "p1", isMaster = true)),
        )

        val ergebnis = e.onTagScanned("04MM", jetzt)

        assertEquals(ScanOutcome.MASTER_CLEARED, ergebnis.outcome)
        assertEquals(jetzt + minute, store.current.calendar.suppressedUntil)
        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Notfall-Code beendet die Kalendersperre ebenfalls`() {
        val store = FakeLockStore(
            LockState(
                profiles = listOf(arbeit),
                codeHash = Hashing.sha256("ABCD2345"),
                calendar = laufendesFenster("p1"),
            )
        )
        val e = LockEngine(store)

        val ergebnis = e.submitCode("ABCD2345", jetzt)

        assertEquals(CodeOutcome.UNLOCKED, ergebnis.outcome)
        assertNotNull(store.current.calendar.suppressedUntil)
        assertTrue(e.blockedPackages(jetzt).isEmpty())
    }

    @Test
    fun `Unterdrueckung endet mit dem laufenden Fenster`() {
        val zweiFenster = CalendarSettings(
            enabled = true,
            cachedWindows = listOf(
                CalendarWindow("e1", "Jetzt", jetzt - minute, jetzt + minute, "p1"),
                CalendarWindow("e2", "Spaeter", jetzt + 5 * minute, jetzt + 9 * minute, "p1"),
            ),
            suppressedUntil = jetzt + minute,
        )
        val (e, _) = engine(zweiFenster)

        assertTrue(e.blockedPackages(jetzt).isEmpty())
        assertEquals(setOf("com.a"), e.blockedPackages(jetzt + 6 * minute))
    }

    @Test
    fun `Fenster schreiben legt sie ab und nagelt faellige Enden fest`() {
        val nagler = Profile("p1", "Arbeit", setOf("com.a"), pinCalendarEnd = true)
        val store = FakeLockStore(
            LockState(profiles = listOf(nagler), calendar = CalendarSettings(enabled = true))
        )
        val e = LockEngine(store)
        val fenster = listOf(CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1"))

        e.updateWindows(fenster, jetzt)

        assertEquals(fenster, store.current.calendar.cachedWindows)
        assertEquals(jetzt, store.current.calendar.windowsFetchedAt)
        assertEquals(mapOf("e1" to jetzt + minute), store.current.calendar.pinnedEnds)
    }

    @Test
    fun `Einstellungen schreiben laesst den Zwischenspeicher stehen`() {
        val (e, store) = engine(laufendesFenster())

        e.updateCalendarSettings(
            enabled = true,
            calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            keywordMarker = "[Fokus]",
            keywordProfileId = "p2",
            keywordCalendarIds = setOf("cal2"),
        )

        assertEquals("[Fokus]", store.current.calendar.keywordMarker)
        assertEquals(
            mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
            store.current.calendar.calendarRules,
        )
        assertEquals(setOf("cal2"), store.current.calendar.keywordCalendarIds)
        assertEquals(1, store.current.calendar.cachedWindows.size)
    }
}
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Unresolved reference: updateWindows".

- [x] **Schritt 3: `lockedProfileIds` um den Kalender erweitern**

In `LockEngine.kt` ersetzen:

```kotlin
    /** Profile, die gerade sperren — über die Chipsperre oder eine Zeitsperre. */
    private fun lockedProfileIds(s: LockState, now: Long): Set<String> = buildSet {
        activeChipLock(s, now)?.let { add(it.profileId) }
        activeTimeLocks(s, now).forEach { add(it.profileId) }
    }
```

durch:

```kotlin
    /**
     * Profile, die gerade sperren — über die Chipsperre, eine Zeitsperre oder ein
     * laufendes Terminfenster. Grundlage der Blockliste und aller Wächter.
     */
    private fun lockedProfileIds(s: LockState, now: Long): Set<String> = buildSet {
        activeChipLock(s, now)?.let { add(it.profileId) }
        activeTimeLocks(s, now).forEach { add(it.profileId) }
        addAll(CalendarPlanner.lockedProfileIds(s.calendar, now))
    }
```

- [x] **Schritt 4: `clearAll` unterdrückt den Kalender**

Ersetzen:

```kotlin
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
```

durch:

```kotlin
    private fun clearAll(s: LockState, now: Long): LockState {
        // Ohne Unterdrückung griffe die Kalendersperre sofort wieder — sie wird ja
        // aus dem Kalender gerechnet, und der Termin läuft noch. Unterdrückt wird
        // bis zum Ende des spätesten laufenden Fensters; das nächste ist unberührt.
        val laufendeFenster = CalendarPlanner.activeWindows(s.calendar, now)
        val bisWann = laufendeFenster.maxOfOrNull { fenster ->
            s.calendar.pinnedEnds[fenster.eventId] ?: fenster.endsAt
        }

        val next = s.copy(
            chipLock = null,
            timeLocks = emptyList(),
            failedAttempts = 0,
            codeLockedUntil = null,
            calendar = if (bisWann == null) s.calendar
            else s.calendar.copy(suppressedUntil = bisWann),
        )
        store.save(next)
        return next
    }
```

- [x] **Schritt 5: Die beiden Aufrufer von `clearAll` nachziehen**

In `onTagScanned`:

```kotlin
        if (tag.isMaster && lockedProfileIds(s, now).isNotEmpty()) {
            return ScanResult(clearAll(s, now), ScanOutcome.MASTER_CLEARED)
        }
```

In `submitCode`, in dem Zweig mit erfolgreichem Hash-Vergleich:

```kotlin
        if (Hashing.sha256(normalized) == hash) {
            return CodeResult(clearAll(s, now), CodeOutcome.UNLOCKED)
        }
```

- [x] **Schritt 6: Schreibwege ergänzen**

Ans Ende der Klasse `LockEngine`, vor das `companion object`:

```kotlin
    /**
     * Legt frisch eingelesene Terminfenster ab. Nagelt dabei die Enden der
     * Fenster fest, deren Profil [Profile.pinCalendarEnd] gesetzt hat, und räumt
     * vergangene Nägel weg.
     */
    fun updateWindows(windows: List<CalendarWindow>, now: Long): LockState {
        val s = store.load()
        val mitFenstern = s.calendar.copy(
            cachedWindows = windows,
            windowsFetchedAt = now,
            pinnedEnds = CalendarPlanner.prunePins(s.calendar, now),
        )
        val neueNaegel = CalendarPlanner.pinsToAdd(mitFenstern, s.profiles, now)
        val next = s.copy(
            calendar = mitFenstern.copy(pinnedEnds = mitFenstern.pinnedEnds + neueNaegel),
        )
        store.save(next)
        return next
    }

    /**
     * Speichert die Kalendereinstellungen. Der Zwischenspeicher bleibt stehen —
     * er wird gleich darauf ohnehin neu eingelesen.
     */
    fun updateCalendarSettings(
        enabled: Boolean,
        calendarRules: Map<String, CalendarRule>,
        keywordMarker: String,
        keywordProfileId: String?,
        keywordCalendarIds: Set<String>,
    ): LockState {
        val s = store.load()
        val next = s.copy(
            calendar = s.calendar.copy(
                enabled = enabled,
                calendarRules = calendarRules,
                keywordMarker = keywordMarker,
                keywordProfileId = keywordProfileId,
                keywordCalendarIds = keywordCalendarIds,
            ),
        )
        store.save(next)
        return next
    }

    /** Laufende Terminfenster, für Anzeige und Diagnose. */
    fun activeCalendarWindows(now: Long): List<CalendarWindow> =
        CalendarPlanner.activeWindows(store.load().calendar, now)
```

- [x] **Schritt 7: Tests laufen lassen**

Erwartet: 163 Tests, 0 Fehlschläge.

- [x] **Schritt 8: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Engine kennt die Kalendersperre"
```

---

### Task 6: Kalender lesen über `CalendarContract`

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarSource.kt`
- Modify: `nfc_riegel/android/app/src/main/AndroidManifest.xml`

Ohne eigene Tests: `ContentResolver` läuft in reinem JUnit nicht. Die Logik davor und danach ist in Task 3–5 abgedeckt; diese Schicht ist eine dünne Abfrage.

- [x] **Schritt 1: `CalendarSource.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract

/** Ein Kalender des Geräts, für die Auswahlliste. */
data class DeviceCalendar(val id: String, val name: String, val account: String)

/**
 * Liest Kalender und Termine des Geräts. Hinter einer Schnittstelle, damit die
 * Rechenlogik in [CalendarPlanner] ohne Android prüfbar bleibt.
 */
interface CalendarSource {
    fun calendars(): List<DeviceCalendar>
    fun windows(settings: CalendarSettings, from: Long, to: Long): List<CalendarWindow>
}

/** Lesezeitraum: so weit schaut Riegel in die Zukunft. */
const val CALENDAR_LOOKAHEAD_MILLIS = 48L * 60 * 60 * 1000

class ContentCalendarSource(private val context: Context) : CalendarSource {

    private fun darfLesen(): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    override fun calendars(): List<DeviceCalendar> {
        if (!darfLesen()) return emptyList()
        val spalten = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
        )
        val ergebnis = mutableListOf<DeviceCalendar>()
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, spalten, null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                ergebnis += DeviceCalendar(
                    id = c.getLong(0).toString(),
                    name = c.getString(1) ?: "Kalender",
                    account = c.getString(2) ?: "",
                )
            }
        }
        return ergebnis
    }

    /**
     * Fragt die `Instances`-Tabelle ab, nicht `Events`: sie liefert Wiederholungen
     * bereits als einzelne Termine mit konkreten Zeiten.
     */
    override fun windows(settings: CalendarSettings, from: Long, to: Long): List<CalendarWindow> {
        if (!darfLesen()) return emptyList()

        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().let {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
            it.build()
        }
        val spalten = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.ALL_DAY,
        )

        val ergebnis = mutableListOf<CalendarWindow>()
        context.contentResolver.query(uri, spalten, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                // Ganztägige Termine würden 24 Stunden sperren — praktisch immer
                // ein Versehen. Wer das will, legt einen Termin mit Uhrzeit an.
                if (c.getInt(5) != 0) continue

                val beginn = c.getLong(2)
                val ende = c.getLong(3)
                if (ende <= beginn) continue

                val titel = c.getString(1) ?: ""
                val kalenderId = c.getLong(4).toString()
                val profil = CalendarPlanner.profileForEvent(settings, kalenderId, titel)
                    ?: continue

                ergebnis += CalendarWindow(
                    eventId = "${c.getLong(0)}_$beginn",
                    title = titel,
                    startsAt = beginn,
                    endsAt = ende,
                    profileId = profil,
                )
            }
        }
        return ergebnis
    }
}
```

Die `eventId` bekommt den Beginn angehängt: eine wiederkehrende Serie hat für alle Termine dieselbe `EVENT_ID`, und das Festnageln muss den einzelnen Termin treffen, nicht die ganze Serie.

- [x] **Schritt 2: Berechtigung ins Manifest**

In `AndroidManifest.xml` hinter die `INTERNET`-Zeile:

```xml
    <!-- Termine lesen, um sie sperren zu lassen. Zur Laufzeit angefragt. -->
    <uses-permission android:name="android.permission.READ_CALENDAR"/>
```

- [x] **Schritt 3: Übersetzen**

Erwartet: BUILD SUCCESSFUL, weiterhin 163 Tests.

- [x] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalender und Termine des Geraets lesen"
```

---

### Task 7: `READ_CALENDAR` zur Laufzeit anfragen

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarPermission.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/MainActivity.kt`

Die Berechtigung wird **nicht** beim Start angefragt, sondern erst, wenn der Nutzer die Kalenderfunktion einschaltet. Eine Sperr-App, die beim ersten Start nach dem Kalender fragt, wirkt übergriffig.

- [x] **Schritt 1: `CalendarPermission.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager

/** Fragt [Manifest.permission.READ_CALENDAR] an — erst beim Einschalten der Funktion. */
object CalendarPermission {

    const val REQUEST_CODE = 1002

    fun granted(activity: Activity): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    fun request(activity: Activity) {
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CODE)
    }
}
```

- [x] **Schritt 2: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 163 Tests.

- [x] **Schritt 3: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalenderberechtigung zur Laufzeit"
```

---

### Task 8: Auf Kalenderänderungen horchen

**Files:**
- Create: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarWatcher.kt`

- [x] **Schritt 1: `CalendarWatcher.kt` anlegen**

```kotlin
package com.klaas.nfc_riegel

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract

/**
 * Meldet Änderungen am Kalender und lässt neu einlesen. Lebt nur, solange der
 * Prozess lebt — deshalb hängt die Richtigkeit nicht an ihm, sondern am Wecker
 * in [LockController], der spätestens alle zwölf Stunden nachsieht.
 */
class CalendarWatcher(private val context: Context) {

    private var observer: ContentObserver? = null

    fun start() {
        if (observer != null) return
        val beobachter = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                LockController(context).refreshCalendar()
            }
        }
        context.contentResolver.registerContentObserver(
            CalendarContract.CONTENT_URI, true, beobachter,
        )
        observer = beobachter
    }

    fun stop() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }
}
```

- [x] **Schritt 2: Übersetzen — schlägt fehl**

Erwartet: „Unresolved reference: refreshCalendar". Das ist beabsichtigt; Task 9 liefert die Methode. **Kein Commit in diesem Zustand** — Task 8 und 9 werden zusammen committet.

---

### Task 9: Controller liest ein und stellt den Wecker

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt`
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/MainActivity.kt`

Hier sitzt die Korrektur an der Spec: der Wecker geht auf `min(Zeitsperren-Ende, nächste Fenstergrenze, jetzt + 12 h)`.

- [x] **Schritt 1: `LockController` ergänzen**

Ersetze `applyEffects` und ergänze `refreshCalendar`:

```kotlin
    /**
     * Liest die Termine der nächsten 48 Stunden neu ein und legt sie ab. Wird vom
     * Wecker, vom [CalendarWatcher] und beim App-Start gerufen.
     */
    fun refreshCalendar(now: Long = System.currentTimeMillis()) {
        val zustand = engine.state()
        if (!zustand.calendar.enabled) return
        val quelle = ContentCalendarSource(context)
        val fenster = quelle.windows(zustand.calendar, now, now + CALENDAR_LOOKAHEAD_MILLIS)
        applyEffects(engine.updateWindows(fenster, now))
    }

    private fun applyEffects(state: LockState, now: Long = System.currentTimeMillis()) {
        LockScheduler.schedule(context, naechsterWecker(state, now))

        val kalenderSperrt = CalendarPlanner.lockedProfileIds(state.calendar, now).isNotEmpty()
        if (state.chipLock != null || state.timeLocks.isNotEmpty() || kalenderSperrt) {
            LockNotification.show(context, state)
        } else {
            LockNotification.hide(context)
        }
    }

    /**
     * Der frühere von: Ende der nächsten Zeitsperre, nächste Fenstergrenze, und
     * eine Auffrischung in zwölf Stunden.
     *
     * Die Auffrischung ist nötig, weil der Wecker sonst an den Fenstergrenzen
     * hinge: ohne passenden Termin gibt es keine Grenze, also keinen Wecker, und
     * der Zwischenspeicher altert weg. Der [CalendarWatcher] fängt das nicht auf —
     * er lebt nur, solange der Prozess lebt.
     */
    private fun naechsterWecker(state: LockState, now: Long): Long {
        val kandidaten = mutableListOf<Long>()
        state.timeLocks.minOfOrNull { it.endsAt }?.let { kandidaten += it }
        if (state.calendar.enabled) {
            CalendarPlanner.nextBoundary(state.calendar, now)?.let { kandidaten += it }
            kandidaten += now + AUFFRISCHUNG_MILLIS
        }
        return kandidaten.minOrNull() ?: (now + AUFFRISCHUNG_MILLIS)
    }

    private companion object {
        const val AUFFRISCHUNG_MILLIS = 12L * 60 * 60 * 1000
    }
```

Beachte: `LockScheduler.cancel` entfällt hier. Ohne Kalenderfunktion und ohne Zeitsperre wird der Wecker auf `now + 12 h` gesetzt; das ist ein Aufwachen alle zwölf Stunden, das nichts tut. Ist das unerwünscht, ersetze die letzte Zeile durch eine Rückgabe von `null` und rufe wieder `cancel`. **Für diesen Plan gilt die einfache Fassung** — ein Wecker, der nichts findet, kostet weniger als ein Kalender, der nicht sperrt.

- [x] **Schritt 2: `expire` frischt mit auf**

Ersetze:

```kotlin
    fun expire(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.onTimerElapsed(now))
    }
```

durch:

```kotlin
    fun expire(now: Long = System.currentTimeMillis()) {
        applyEffects(engine.onTimerElapsed(now), now)
        // Derselbe Wecker dient beiden Zwecken: Zeitsperre beenden und Termine
        // nachlesen. Welcher der beiden ihn gestellt hat, ist hier nicht mehr zu
        // unterscheiden — also immer beides.
        refreshCalendar(now)
    }
```

- [x] **Schritt 3: `MainActivity` startet Beobachter und Auffrischung**

Ersetze `configureFlutterEngine` in `MainActivity.kt`:

```kotlin
    private val calendarWatcher by lazy { CalendarWatcher(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zustand nach App-Start begradigen: abgelaufener Timer wird sofort aufgelöst.
        val controller = LockController(this)
        controller.expire()
        controller.refreshCalendar()
        calendarWatcher.start()
        RiegelChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        requestNotificationPermission()
    }

    override fun onDestroy() {
        calendarWatcher.stop()
        super.onDestroy()
    }
```

- [x] **Schritt 4: Tests laufen lassen**

Erwartet: BUILD SUCCESSFUL, 163 Tests, 0 Fehlschläge.

- [x] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Termine einlesen und Wecker auf die naechste Grenze"
```

---

### Task 10: Kalenderlage im Fehlerbericht

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Diagnostics.kt`
- Test: `nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt`

**Wichtig:** Der Bericht landet in einer Notion-Datenbank. Termintitel können persönlich sein und gehören dort nicht hin — genauso wenig wie Tag-UIDs und der Code-Hash. Gemeldet werden nur Anzahl und Zeiten.

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `DiagnosticsTest.kt`, vor die schließende Klammer:

```kotlin
    @Test
    fun `Kalenderlage nennt Anzahl und naechste Grenze`() {
        val jetzt = 1_000_000L
        val zustand = LockState(
            profiles = listOf(Profile("p1", "Arbeit")),
            calendar = CalendarSettings(
                enabled = true,
                calendarRules = mapOf("cal1" to CalendarRule("p1", CalendarMatch.KEYWORD)),
                cachedWindows = listOf(
                    CalendarWindow("e1", "Konzept", jetzt - 1, jetzt + 60_000, "p1"),
                ),
            ),
        )

        val bericht = Diagnostics.summarize(zustand, jetzt)

        assertTrue(bericht.getValue("Kalender").contains("an"))
        assertTrue(bericht.getValue("Kalender").contains("1 Kalender"))
        assertTrue(bericht.getValue("Kalender").contains("1 nur Stichwort"))
        assertTrue(bericht.getValue("Kalender").contains("1 Termin"))
    }

    @Test
    fun `ausgeschalteter Kalender wird als aus gemeldet`() {
        val bericht = Diagnostics.summarize(LockState(), 1_000L)

        assertEquals("aus", bericht.getValue("Kalender"))
    }

    @Test
    fun `Bericht enthaelt keine Termintitel`() {
        val jetzt = 1_000_000L
        val zustand = LockState(
            profiles = listOf(Profile("p1", "Arbeit")),
            calendar = CalendarSettings(
                enabled = true,
                cachedWindows = listOf(
                    CalendarWindow("e1", "Therapie Dr. Meier", jetzt - 1, jetzt + 60_000, "p1"),
                ),
            ),
        )

        val bericht = Diagnostics.summarize(zustand, jetzt)

        assertFalse(bericht.values.any { it.contains("Therapie") })
        assertFalse(bericht.values.any { it.contains("Meier") })
    }
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: `NoSuchElementException: Key Kalender is missing in the map`.

- [x] **Schritt 3: `Diagnostics` ergänzen**

In der Map, die `summarize` aufbaut, hinter dem bestehenden Eintrag für die Chips:

```kotlin
        "Kalender" to kalenderZeile(state, now),
```

und als private Funktion im `object`:

```kotlin
    /**
     * Bewusst ohne Termintitel: der Bericht landet in einer Notion-Datenbank, und
     * Termine sind persönlich. Anzahl und Zeiten reichen, um eine falsch greifende
     * Sperre zu verstehen.
     */
    private fun kalenderZeile(state: LockState, now: Long): String {
        val c = state.calendar
        if (!c.enabled) return "aus"

        val laufend = CalendarPlanner.activeWindows(c, now).size
        val grenze = CalendarPlanner.nextBoundary(c, now)
        val nurStichwort = c.calendarRules.values.count { it.match == CalendarMatch.KEYWORD }
        val stichwortBereich =
            if (c.keywordCalendarIds.isEmpty()) "alle" else "${c.keywordCalendarIds.size}"
        val teile = mutableListOf(
            "an",
            "${c.calendarRules.size} Kalender zugeordnet ($nurStichwort nur Stichwort)",
            "Stichwortregel in $stichwortBereich Kalendern",
            "${c.cachedWindows.size} Termine im Speicher",
            "$laufend Termin(e) sperren gerade",
        )
        if (c.pinnedEnds.isNotEmpty()) teile += "${c.pinnedEnds.size} festgenagelt"
        if (c.suppressedUntil != null && now < c.suppressedUntil) teile += "unterdrückt"
        if (grenze != null) teile += "nächste Änderung in ${(grenze - now) / 60_000} min"
        return teile.joinToString(", ")
    }
```

- [x] **Schritt 4: Tests laufen lassen**

Erwartet: 166 Tests, 0 Fehlschläge.

- [x] **Schritt 5: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalenderlage im Fehlerbericht, ohne Termintitel"
```

---

### Task 11: Kanal für Kalendereinstellungen

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`

- [x] **Schritt 1: Zustand um den Kalender erweitern**

In der Methode, die den Zustand als Map liefert (`getState`), hinter `timeLocks`:

```kotlin
                        "calendar" to mapOf(
                            "enabled" to zustand.calendar.enabled,
                            // Als Karte von Kalender-ID auf eine kleine Karte —
                            // der MethodChannel überträgt keine eigenen Typen.
                            "calendarRules" to zustand.calendar.calendarRules
                                .mapValues { (_, regel) ->
                                    mapOf(
                                        "profileId" to regel.profileId,
                                        "match" to regel.match.name,
                                    )
                                },
                            "keywordMarker" to zustand.calendar.keywordMarker,
                            "keywordProfileId" to zustand.calendar.keywordProfileId,
                            "keywordCalendarIds" to zustand.calendar.keywordCalendarIds.toList(),
                            "permissionGranted" to CalendarPermission.granted(activity),
                            "windows" to zustand.calendar.cachedWindows
                                .sortedBy { it.startsAt }
                                .take(3)
                                .map { fenster ->
                                    mapOf(
                                        "eventId" to fenster.eventId,
                                        "title" to fenster.title,
                                        "startsAt" to fenster.startsAt,
                                        "endsAt" to fenster.endsAt,
                                        "profileId" to fenster.profileId,
                                    )
                                },
                            "activeWindows" to controller.engine.activeCalendarWindows(
                                System.currentTimeMillis()
                            ).map { fenster ->
                                mapOf(
                                    "eventId" to fenster.eventId,
                                    "title" to fenster.title,
                                    "startsAt" to fenster.startsAt,
                                    "endsAt" to fenster.endsAt,
                                    "profileId" to fenster.profileId,
                                )
                            },
                        ),
```

- [x] **Schritt 2: Vier Methoden ergänzen**

Im `when` über `call.method`, vor den `else`-Zweig:

```kotlin
                "deviceCalendars" ->
                    result.success(
                        ContentCalendarSource(activity).calendars().map {
                            mapOf("id" to it.id, "name" to it.name, "account" to it.account)
                        }
                    )

                "requestCalendarPermission" -> {
                    if (CalendarPermission.granted(activity)) {
                        result.success(true)
                    } else {
                        CalendarPermission.request(activity)
                        // Die Antwort kommt asynchron ins System zurück; die
                        // Oberfläche fragt den Zustand nach dem Dialog neu ab.
                        result.success(false)
                    }
                }

                "setCalendarSettings" -> {
                    val roh = call.argument<Map<String, Map<String, String>>>("calendarRules")
                        ?: emptyMap()
                    val regeln = roh.mapValues { (_, eintrag) ->
                        CalendarRule(
                            profileId = eintrag["profileId"] ?: "",
                            match = runCatching {
                                CalendarMatch.valueOf(eintrag["match"] ?: "ALL")
                            }.getOrDefault(CalendarMatch.ALL),
                        )
                    }.filterValues { it.profileId.isNotEmpty() }

                    controller.engine.updateCalendarSettings(
                        enabled = call.argument<Boolean>("enabled") ?: false,
                        calendarRules = regeln,
                        keywordMarker = call.argument<String>("keywordMarker") ?: "[Riegel]",
                        keywordProfileId = call.argument<String>("keywordProfileId"),
                        keywordCalendarIds =
                            call.argument<List<String>>("keywordCalendarIds")?.toSet()
                                ?: emptySet(),
                    )
                    controller.refreshCalendar()
                    result.success(true)
                }

                "refreshCalendar" -> {
                    controller.refreshCalendar()
                    result.success(true)
                }
```

- [x] **Schritt 3: Übersetzen**

Erwartet: BUILD SUCCESSFUL, 166 Tests. `flutter analyze` ist ab hier bis Task 13 nicht aussagekräftig.

- [x] **Schritt 4: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/android/app/src && git commit -m "feat: Kalendereinstellungen ueber den Kanal"
```

---

### Task 12: Dart-Zustand kennt den Kalender

**Files:**
- Modify: `nfc_riegel/lib/lock_status.dart`
- Modify: `nfc_riegel/lib/riegel_channel.dart`
- Test: `nfc_riegel/test/lock_status_test.dart`

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

Ans Ende von `test/lock_status_test.dart`, in die bestehende `main()`-Funktion:

```dart
  test('Kalendereinstellungen werden gelesen', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {
        'enabled': true,
        'calendarRules': {
          'cal1': {'profileId': 'p1', 'match': 'ALL'},
          'cal2': {'profileId': 'p2', 'match': 'KEYWORD'},
        },
        'keywordMarker': '[Fokus]',
        'keywordProfileId': 'p2',
        'keywordCalendarIds': ['cal3'],
        'permissionGranted': true,
        'windows': <dynamic>[],
        'activeWindows': <dynamic>[],
      },
    });

    expect(status.calendar.enabled, isTrue);
    expect(status.calendar.calendarRules['cal1']!.profileId, 'p1');
    expect(status.calendar.calendarRules['cal1']!.match, CalendarMatch.all);
    expect(status.calendar.calendarRules['cal2']!.match, CalendarMatch.keyword);
    expect(status.calendar.keywordMarker, '[Fokus]');
    expect(status.calendar.keywordCalendarIds, {'cal3'});
    expect(status.calendar.permissionGranted, isTrue);
  });

  test('leere Stichwort-Kalenderliste heisst alle', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {'enabled': true},
    });

    expect(status.calendar.keywordCalendarIds, isEmpty);
  });

  test('fehlender Kalenderblock ergibt die Vorgaben', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.calendar.enabled, isFalse);
    expect(status.calendar.keywordMarker, '[Riegel]');
  });

  test('laufendes Terminfenster gilt als Sperre', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {
        'enabled': true,
        'activeWindows': [
          {
            'eventId': 'e1',
            'title': 'Konzept',
            'startsAt': 1000,
            'endsAt': 2000,
            'profileId': 'p1',
          },
        ],
      },
    });

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.calendar.activeWindows.first.title, 'Konzept');
  });
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test test/lock_status_test.dart
```

Erwartet: „The getter 'calendar' isn't defined for the type 'LockStatus'".

- [x] **Schritt 3: `lock_status.dart` erweitern**

Vor `class LockStatus`:

```dart
/// Ein Termin, der sperrt oder sperren wird.
class CalendarWindowInfo {
  const CalendarWindowInfo({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.profileId,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String profileId;

  factory CalendarWindowInfo.fromMap(Map<dynamic, dynamic> map) => CalendarWindowInfo(
    eventId: map['eventId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    startsAt: DateTime.fromMillisecondsSinceEpoch(map['startsAt'] as int? ?? 0),
    endsAt: DateTime.fromMillisecondsSinceEpoch(map['endsAt'] as int? ?? 0),
    profileId: map['profileId'] as String? ?? '',
  );
}

/// Ein Kalender des Geräts, für die Auswahlliste.
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.account,
  });

  final String id;
  final String name;
  final String account;

  factory DeviceCalendarInfo.fromMap(Map<dynamic, dynamic> map) => DeviceCalendarInfo(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    account: map['account'] as String? ?? '',
  );
}

/// Welche Termine eines Kalenders sperren.
enum CalendarMatch { all, keyword }

CalendarMatch _matchFrom(String? raw) =>
    raw == 'KEYWORD' ? CalendarMatch.keyword : CalendarMatch.all;

String matchToNative(CalendarMatch m) =>
    m == CalendarMatch.keyword ? 'KEYWORD' : 'ALL';

/// Regel für einen Kalender des Geräts.
class CalendarRuleInfo {
  const CalendarRuleInfo({required this.profileId, required this.match});

  final String profileId;
  final CalendarMatch match;

  factory CalendarRuleInfo.fromMap(Map<dynamic, dynamic> map) => CalendarRuleInfo(
    profileId: map['profileId'] as String? ?? '',
    match: _matchFrom(map['match'] as String?),
  );

  Map<String, String> toMap() => {
    'profileId': profileId,
    'match': matchToNative(match),
  };
}

/// Kalenderteil des Zustands.
class CalendarInfo {
  const CalendarInfo({
    required this.enabled,
    required this.calendarRules,
    required this.keywordMarker,
    required this.keywordProfileId,
    required this.keywordCalendarIds,
    required this.permissionGranted,
    required this.windows,
    required this.activeWindows,
  });

  final bool enabled;

  /// Kalender-ID → Regel. Nicht enthaltene Kalender sperren nicht.
  final Map<String, CalendarRuleInfo> calendarRules;
  final String keywordMarker;
  final String? keywordProfileId;

  /// In welchen Kalendern die eigenständige Stichwortregel sucht. Leer = alle.
  final Set<String> keywordCalendarIds;
  final bool permissionGranted;

  /// Die nächsten drei Termine, für die Vorschau.
  final List<CalendarWindowInfo> windows;

  /// Termine, die gerade sperren.
  final List<CalendarWindowInfo> activeWindows;

  static const empty = CalendarInfo(
    enabled: false,
    calendarRules: {},
    keywordMarker: '[Riegel]',
    keywordProfileId: null,
    keywordCalendarIds: {},
    permissionGranted: false,
    windows: [],
    activeWindows: [],
  );

  factory CalendarInfo.fromMap(Map<dynamic, dynamic> map) => CalendarInfo(
    enabled: map['enabled'] as bool? ?? false,
    calendarRules: (map['calendarRules'] as Map<dynamic, dynamic>? ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        CalendarRuleInfo.fromMap(v as Map<dynamic, dynamic>),
      ),
    ),
    keywordMarker: map['keywordMarker'] as String? ?? '[Riegel]',
    keywordProfileId: map['keywordProfileId'] as String?,
    keywordCalendarIds:
        (map['keywordCalendarIds'] as List<dynamic>? ?? []).cast<String>().toSet(),
    permissionGranted: map['permissionGranted'] as bool? ?? false,
    windows: (map['windows'] as List<dynamic>? ?? [])
        .map((e) => CalendarWindowInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList(),
    activeWindows: (map['activeWindows'] as List<dynamic>? ?? [])
        .map((e) => CalendarWindowInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList(),
  );
}
```

In `LockStatus`: Feld ergänzen, im Konstruktor `required this.calendar`, in `fromMap`:

```dart
      calendar: map['calendar'] == null
          ? CalendarInfo.empty
          : CalendarInfo.fromMap(map['calendar'] as Map<dynamic, dynamic>),
```

und die beiden Getter ersetzen:

```dart
  bool get locked =>
      chipLockProfileId != null ||
      timeLocks.isNotEmpty ||
      calendar.activeWindows.isNotEmpty;

  /// Alle Profile, die gerade sperren — über alle drei Quellen.
  Set<String> get lockedProfileIds => {
    ?chipLockProfileId,
    ...timeLocks.map((l) => l.profileId),
    ...calendar.activeWindows.map((w) => w.profileId),
  };
```

- [x] **Schritt 4: Kanal-Methoden in `riegel_channel.dart`**

```dart
  Future<List<DeviceCalendarInfo>> deviceCalendars() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('deviceCalendars');
    return (raw ?? [])
        .map((e) => DeviceCalendarInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<bool> requestCalendarPermission() async =>
      await _channel.invokeMethod<bool>('requestCalendarPermission') ?? false;

  Future<void> setCalendarSettings({
    required bool enabled,
    required Map<String, CalendarRuleInfo> calendarRules,
    required String keywordMarker,
    String? keywordProfileId,
    Set<String> keywordCalendarIds = const {},
  }) async {
    await _channel.invokeMethod<bool>('setCalendarSettings', {
      'enabled': enabled,
      'calendarRules': calendarRules.map((k, v) => MapEntry(k, v.toMap())),
      'keywordMarker': keywordMarker,
      'keywordProfileId': keywordProfileId,
      'keywordCalendarIds': keywordCalendarIds.toList(),
    });
  }

  Future<void> refreshCalendar() async {
    await _channel.invokeMethod<bool>('refreshCalendar');
  }
```

- [x] **Schritt 5: Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter test
```

Erwartet: 19 Tests, alle grün.

- [x] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Dart-Zustand kennt den Kalender"
```

---

### Task 13: Kalenderbildschirm

**Files:**
- Create: `nfc_riegel/lib/calendar_screen.dart`
- Modify: `nfc_riegel/lib/home_screen.dart`
- Test: `nfc_riegel/test/calendar_screen_test.dart`

- [x] **Schritt 1: Die fehlschlagenden Tests schreiben**

Die Attrappe folgt dem Muster aus `home_screen_test.dart`: ein Mock-`MethodChannel`,
der in `RiegelChannel(channel)` gesteckt wird. **Eine Klasse `FakeRiegelChannel`
gibt es nicht** — `RiegelChannel` nimmt den Kanal als Konstruktorargument.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/calendar_screen.dart';
import 'package:nfc_riegel/lock_status.dart';
import 'package:nfc_riegel/riegel_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');

  /// Zuletzt an `setCalendarSettings` übergebene Argumente.
  Map<dynamic, dynamic>? gespeichert;

  void stub({List<Map<String, String>> kalender = const []}) {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'deviceCalendars':
          return kalender;
        case 'setCalendarSettings':
          gespeichert = call.arguments as Map<dynamic, dynamic>;
          return true;
        case 'requestCalendarPermission':
          return true;
        case 'refreshCalendar':
          return true;
      }
      return null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  LockStatus status({
    bool enabled = false,
    bool permission = true,
    Map<String, dynamic> rules = const {},
    List<Map<String, dynamic>> windows = const [],
  }) => LockStatus.fromMap({
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
    'calendar': {
      'enabled': enabled,
      'permissionGranted': permission,
      'calendarRules': rules,
      'keywordMarker': '[Riegel]',
      'keywordCalendarIds': <dynamic>[],
      'windows': windows,
      'activeWindows': <dynamic>[],
    },
  });

  Widget screen(LockStatus s) => MaterialApp(
    home: CalendarScreen(status: s, channel: RiegelChannel(channel)),
  );

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub();
    await tester.pumpWidget(screen(status(permission: false)));

    expect(find.textContaining('Berechtigung'), findsOneWidget);
  });

  testWidgets('ausgeschaltet bleibt die Kalenderliste verborgen', (tester) async {
    stub();
    await tester.pumpWidget(screen(status()));

    expect(find.text('KALENDER DES GERÄTS'), findsNothing);
  });

  testWidgets('eingeschaltet zeigt Kalenderliste und Stichwortabschnitt', (tester) async {
    stub(kalender: [
      {'id': 'cal1', 'name': 'Privat', 'account': 'ich@example.com'},
    ]);
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('KALENDER DES GERÄTS'), findsOneWidget);
    expect(find.text('Privat'), findsOneWidget);
    expect(find.text('STICHWORTREGEL'), findsOneWidget);
  });

  testWidgets('zugeordneter Kalender zeigt die Wahl der Trefferart', (tester) async {
    stub(kalender: [
      {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
    ]);
    await tester.pumpWidget(screen(status(
      enabled: true,
      rules: {
        'cal1': {'profileId': 'p1', 'match': 'ALL'},
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('alle Termine'), findsOneWidget);
    expect(find.text('nur Stichwort'), findsOneWidget);
  });

  testWidgets('nicht zugeordneter Kalender zeigt keine Trefferart', (tester) async {
    stub(kalender: [
      {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
    ]);
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('alle Termine'), findsNothing);
  });

  testWidgets('Umschalten auf nur Stichwort wird gespeichert', (tester) async {
    stub(kalender: [
      {'id': 'cal1', 'name': 'Arbeit', 'account': 'ich@example.com'},
    ]);
    await tester.pumpWidget(screen(status(
      enabled: true,
      rules: {
        'cal1': {'profileId': 'p1', 'match': 'ALL'},
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('nur Stichwort'));
    await tester.pumpAndSettle();

    final regeln = gespeichert!['calendarRules'] as Map<dynamic, dynamic>;
    expect((regeln['cal1'] as Map<dynamic, dynamic>)['match'], 'KEYWORD');
  });

  testWidgets('Vorschau nennt die naechsten Termine', (tester) async {
    stub();
    final jetzt = DateTime.now();
    await tester.pumpWidget(screen(status(enabled: true, windows: [
      {
        'eventId': 'e1',
        'title': 'Konzept schreiben',
        'startsAt': jetzt.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'endsAt': jetzt.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        'profileId': 'p1',
      },
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Konzept schreiben'), findsOneWidget);
  });
}
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Target of URI doesn't exist: 'package:nfc_riegel/calendar_screen.dart'".

- [x] **Schritt 3: `calendar_screen.dart` anlegen**

```dart
import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Kalenderfunktion einrichten: Schalter, Kalenderzuordnung, Stichwort, Vorschau.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.status,
    this.channel = const RiegelChannel(),
  });

  final LockStatus status;
  final RiegelChannel channel;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late bool _an = widget.status.calendar.enabled;
  late bool _berechtigt = widget.status.calendar.permissionGranted;
  late final Map<String, CalendarRuleInfo> _regeln =
      Map.of(widget.status.calendar.calendarRules);
  late String? _stichwortProfil = widget.status.calendar.keywordProfileId;
  late final Set<String> _stichwortKalender =
      Set.of(widget.status.calendar.keywordCalendarIds);
  late final TextEditingController _marker =
      TextEditingController(text: widget.status.calendar.keywordMarker);
  List<DeviceCalendarInfo> _geraeteKalender = const [];

  @override
  void initState() {
    super.initState();
    if (_an && _berechtigt) _ladeKalender();
  }

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  Future<void> _ladeKalender() async {
    final liste = await widget.channel.deviceCalendars();
    if (mounted) setState(() => _geraeteKalender = liste);
  }

  Future<void> _schalte(bool an) async {
    if (an && !_berechtigt) {
      final erteilt = await widget.channel.requestCalendarPermission();
      if (!erteilt) return;
      if (mounted) setState(() => _berechtigt = true);
    }
    setState(() => _an = an);
    await _speichere();
    if (an) await _ladeKalender();
  }

  Future<void> _speichere() async {
    await widget.channel.setCalendarSettings(
      enabled: _an,
      calendarRules: _regeln,
      keywordMarker: _marker.text,
      keywordProfileId: _stichwortProfil,
      keywordCalendarIds: _stichwortKalender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final beschriftung = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          if (!_berechtigt)
            Padding(
              padding: const EdgeInsets.only(bottom: RiegelSpacing.s4),
              child: Text(
                'Ohne Berechtigung für den Kalender kann Riegel keine Termine sehen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RiegelColors.danger,
                    ),
              ),
            ),
          SwitchListTile(
            title: const Text('Termine sperren'),
            subtitle: const Text('Läuft ein passender Termin, sperrt sein Profil'),
            value: _an,
            onChanged: _schalte,
          ),
          if (_an) ...[
            const SizedBox(height: RiegelSpacing.s4),
            Text('KALENDER DES GERÄTS', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (_geraeteKalender.isEmpty)
              const Text('Kein Kalender auf diesem Gerät gefunden.'),
            for (final kalender in _geraeteKalender)
              _KalenderZeile(
                kalender: kalender,
                profile: widget.status.profiles,
                regel: _regeln[kalender.id],
                onProfil: (profilId) async {
                  setState(() {
                    if (profilId == null) {
                      _regeln.remove(kalender.id);
                    } else {
                      _regeln[kalender.id] = CalendarRuleInfo(
                        profileId: profilId,
                        match: _regeln[kalender.id]?.match ?? CalendarMatch.all,
                      );
                    }
                  });
                  await _speichere();
                },
                onTrefferart: (art) async {
                  final vorhanden = _regeln[kalender.id];
                  if (vorhanden == null) return;
                  setState(() {
                    _regeln[kalender.id] = CalendarRuleInfo(
                      profileId: vorhanden.profileId,
                      match: art,
                    );
                  });
                  await _speichere();
                },
              ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('STICHWORTREGEL', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            const Text(
              'Greift zusätzlich, unabhängig von den Regeln oben.',
              style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
            ),
            const SizedBox(height: RiegelSpacing.s3),
            TextField(
              controller: _marker,
              decoration: const InputDecoration(
                labelText: 'Stichwort im Termintitel',
              ),
              onSubmitted: (_) => _speichere(),
            ),
            const SizedBox(height: RiegelSpacing.s3),
            DropdownButtonFormField<String?>(
              initialValue: _stichwortProfil,
              decoration: const InputDecoration(labelText: 'Profil für Treffer'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('aus')),
                for (final p in widget.status.profiles)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (wert) async {
                setState(() => _stichwortProfil = wert);
                await _speichere();
              },
            ),
            const SizedBox(height: RiegelSpacing.s3),
            const Text(
              'In welchen Kalendern gesucht wird. Nichts angekreuzt heißt: in allen.',
              style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
            ),
            for (final kalender in _geraeteKalender)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(kalender.name),
                value: _stichwortKalender.contains(kalender.id),
                onChanged: (an) async {
                  setState(() {
                    if (an == true) {
                      _stichwortKalender.add(kalender.id);
                    } else {
                      _stichwortKalender.remove(kalender.id);
                    }
                  });
                  await _speichere();
                },
              ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('NÄCHSTE TERMINE', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (widget.status.calendar.windows.isEmpty)
              const Text('Kein passender Termin in den nächsten 48 Stunden.')
            else
              for (final fenster in widget.status.calendar.windows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(fenster.title),
                  subtitle: Text(_zeitraum(fenster)),
                ),
          ],
        ],
      ),
    );
  }

  String _zeitraum(CalendarWindowInfo w) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${w.startsAt.day}.${w.startsAt.month}. ${hhmm(w.startsAt)} – ${hhmm(w.endsAt)}';
  }
}

/// Ein Kalender mit seiner Regel: welches Profil, und ob alle Termine oder nur
/// die mit Stichwort. Die Trefferart erscheint erst, wenn ein Profil gewählt ist —
/// vorher hat sie nichts, worauf sie sich beziehen könnte.
class _KalenderZeile extends StatelessWidget {
  const _KalenderZeile({
    required this.kalender,
    required this.profile,
    required this.regel,
    required this.onProfil,
    required this.onTrefferart,
  });

  final DeviceCalendarInfo kalender;
  final List<ProfileInfo> profile;
  final CalendarRuleInfo? regel;
  final ValueChanged<String?> onProfil;
  final ValueChanged<CalendarMatch> onTrefferart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(kalender.name),
          subtitle: Text(kalender.account),
          trailing: DropdownButton<String?>(
            value: regel?.profileId,
            hint: const Text('aus'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('aus')),
              for (final p in profile)
                DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: onProfil,
          ),
        ),
        if (regel != null)
          Padding(
            padding: const EdgeInsets.only(
              left: RiegelSpacing.s4,
              bottom: RiegelSpacing.s3,
            ),
            child: SegmentedButton<CalendarMatch>(
              segments: const [
                ButtonSegment(
                  value: CalendarMatch.all,
                  label: Text('alle Termine'),
                ),
                ButtonSegment(
                  value: CalendarMatch.keyword,
                  label: Text('nur Stichwort'),
                ),
              ],
              selected: {regel!.match},
              onSelectionChanged: (auswahl) => onTrefferart(auswahl.first),
            ),
          ),
      ],
    );
  }
}
```

- [x] **Schritt 4: Vom Hauptscreen erreichbar machen**

In `home_screen.dart` den Import ergänzen und hinter der Chips-Zeile eine weitere `_NavRow` einfügen:

```dart
            const SizedBox(height: RiegelSpacing.s3),
            _NavRow(
              title: 'Kalender',
              subtitle: status.calendar.enabled
                  ? '${status.calendar.calendarRules.length} Kalender zugeordnet'
                  : 'aus',
              enabled: !status.locked,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(
                      status: status,
                      channel: widget.channel,
                    ),
                  ),
                );
                await _refresh();
              },
            ),
```

- [x] **Schritt 5: Prüfen und Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: „No issues found!", 26 Tests grün.

- [x] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel/lib nfc_riegel/test && git commit -m "feat: Kalenderbildschirm"
```

---

### Task 14: Termin auf Sperrschirm und Statuskachel

**Files:**
- Modify: `nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt`
- Modify: `nfc_riegel/lib/home_screen.dart`
- Test: `nfc_riegel/test/home_screen_test.dart`

- [x] **Schritt 1: Den fehlschlagenden Test schreiben**

`home_screen_test.dart` benutzt **keinen** `FakeRiegelChannel`, sondern einen
Mock-`MethodChannel` über die dortige Hilfsfunktion `stub(...)`, die den
`getState`-Rückgabewert zusammensetzt. Ergänze diese Funktion zuerst um einen
Kalenderteil:

```dart
  void stub({
    required bool accessibility,
    String defaultMode = 'TIMER',
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>> timeLocks = const [],
    bool hasMasterTag = true,
    bool hasCode = true,
    Map<String, dynamic>? calendar,
  }) {
```

und im zurückgegebenen `getState`-Wert hinter `'hasCode': hasCode,`:

```dart
            'calendar': calendar,
```

Dann ans Ende der bestehenden `main()` den Test:

```dart
  testWidgets('laufender Termin steht in der Statuskachel', (tester) async {
    final jetzt = DateTime.now();
    stub(
      accessibility: true,
      calendar: {
        'enabled': true,
        'permissionGranted': true,
        'calendarRules': <dynamic, dynamic>{},
        'keywordMarker': '[Riegel]',
        'keywordCalendarIds': <dynamic>[],
        'windows': <dynamic>[],
        'activeWindows': [
          {
            'eventId': 'e1',
            'title': 'Konzept schreiben',
            'startsAt': jetzt.millisecondsSinceEpoch,
            'endsAt': jetzt.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            'profileId': 'p1',
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(channel: RiegelChannel(channel))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Konzept schreiben'), findsOneWidget);
  });
```

Der Kalenderteil ist `null`, wenn `stub` ihn nicht bekommt — alle bestehenden
Tests laufen dann unverändert weiter, weil `LockStatus.fromMap` bei fehlendem
`calendar` auf `CalendarInfo.empty` fällt.

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Erwartet: „Expected: exactly one matching candidate, Actual: _TextWidgetFinder:<zero widgets>".

- [x] **Schritt 3: `_StatusTile._subtitle` erweitern**

In `home_screen.dart` die Methode `_subtitle` ersetzen:

```dart
  String _subtitle(LockStatus status) {
    // Ein laufender Termin ist die aussagekräftigste Auskunft: er nennt den
    // Grund, nicht nur die Uhrzeit.
    final termin = status.calendar.activeWindows.firstOrNull;
    if (termin != null) {
      return '${termin.title} — frei ab ${_hhmm(termin.endsAt)}';
    }

    final gesperrt = status.lockedProfileIds;
    if (gesperrt.isEmpty) return 'Chip scannen oder Profil sperren';

    final ende = status.earliestEnd;
    if (gesperrt.length > 1) {
      return ende == null
          ? '${gesperrt.length} Sperren'
          : '${gesperrt.length} Sperren — frei ab ${_hhmm(ende)}';
    }

    final name = status.profiles
        .where((p) => p.id == gesperrt.first)
        .map((p) => p.name)
        .firstOrNull ?? 'Profil';
    return ende == null
        ? '$name — frei nach erneutem Scan'
        : '$name — frei ab ${_hhmm(ende)}';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
```

`firstOrNull` kommt aus `dart:collection` über `package:collection`. Steht es nicht in `pubspec.yaml`, stattdessen `isEmpty ? null : first` verwenden — **keine neue Abhängigkeit aufnehmen**.

- [x] **Schritt 4: Sperrschirm ergänzen**

In `BlockActivity.kt` dort, wo der Text über die laufende Sperre gesetzt wird, den Kalenderfall voranstellen:

```kotlin
        val termin = LockController(this).engine
            .activeCalendarWindows(System.currentTimeMillis())
            .firstOrNull()
        if (termin != null) {
            val ende = java.text.SimpleDateFormat("HH:mm", java.util.Locale.GERMANY)
                .format(java.util.Date(termin.endsAt))
            untertitel.text = "${termin.title} — frei ab $ende"
        }
```

- [x] **Schritt 5: Prüfen und Tests laufen lassen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test
```

Erwartet: sauber, 27 Tests grün. Danach die Kotlin-Tests:

Erwartet: 166 Tests, 0 Fehlschläge.

- [x] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel && git commit -m "feat: Termin auf Sperrschirm und Statuskachel"
```

---

### Task 15: Gerätetest, Bauen, Ablegen

**Files:**
- Modify: `nfc_riegel/GERAETETEST.md`
- Modify: `nfc_riegel/lib/build_info.dart`
- Modify: `nfc_riegel/pubspec.yaml`

- [ ] **Schritt 1: Prüfliste ergänzen**

Ans Ende von `GERAETETEST.md`:

```markdown
## Kalender

- [ ] Kalenderfunktion einschalten — Berechtigungsabfrage erscheint
- [ ] Abfrage ablehnen — Hinweis erscheint, Funktion bleibt aus
- [ ] Abfrage erlauben — Kalender des Geräts erscheinen in der Liste
- [ ] Einem Kalender ein Profil zuordnen, Trefferart „alle Termine"
- [ ] Termin in diesem Kalender anlegen, der in 2 Minuten beginnt und 5 Minuten dauert
- [ ] Bei Terminbeginn sperren die Apps des Profils
- [ ] Bei Terminende geben sie wieder frei
- [ ] Ganztägiger Termin sperrt nicht

### Trefferart je Kalender

- [ ] Denselben Kalender auf „nur Stichwort" umstellen
- [ ] Termin **ohne** Stichwort im Titel sperrt jetzt **nicht** mehr
- [ ] Termin **mit** `[Riegel]` im Titel sperrt weiterhin, mit dem Profil des Kalenders

### Eigenständige Stichwortregel

- [ ] Stichwortregel ein Profil zuweisen, keinen Kalender ankreuzen
- [ ] Termin mit `[Riegel]` im Titel in einem **nicht** zugeordneten Kalender sperrt
- [ ] Jetzt nur einen bestimmten Kalender ankreuzen
- [ ] Termin mit `[Riegel]` in **diesem** Kalender sperrt
- [ ] Termin mit `[Riegel]` in einem **anderen** Kalender sperrt nicht mehr
- [ ] Kalender auf „alle Termine" gestellt und Stichwortregel aktiv: der Termin
      sperrt mit dem Profil des **Kalenders**, nicht dem der Stichwortregel
- [ ] Laufenden Termin im Kalender verschieben — Sperre verschiebt sich mit
- [ ] Laufenden Termin löschen — Sperre endet
- [ ] Bei `pinCalendarEnd` im Profil: laufenden Termin löschen — Sperre bleibt bis zum
      ursprünglichen Ende
- [ ] Normalen Chip während einer Kalendersperre scannen — sperrt weiter
- [ ] Generalschlüssel während einer Kalendersperre — gibt frei, und der Termin
      sperrt bis zu seinem Ende nicht erneut
- [ ] Nächster Termin sperrt danach wieder normal
- [ ] Notfall-Code während einer Kalendersperre — gibt ebenfalls frei
- [ ] Kalenderberechtigung in den Systemeinstellungen entziehen — Warnung erscheint
- [ ] Handy neu starten während einer Kalendersperre — sperrt danach weiter
- [ ] Fehlerbericht senden — Zeile „Kalender" steht drin, **ohne** Termintitel
```

- [ ] **Schritt 2: Build-Nummer auf 4**

`lib/build_info.dart`:

```dart
const int kBuildNumber = 4;
```

`pubspec.yaml`:

```yaml
version: 1.0.0+4
```

- [ ] **Schritt 3: Alles prüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter analyze && flutter test && export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" && ./android/gradlew.bat -p android :app:testDebugUnitTest
```

Erwartet: sauber, 23 Dart-Tests, 159 Kotlin-Tests, 0 Fehlschläge.

- [ ] **Schritt 4: Bauen und ablegen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren/nfc_riegel" && flutter build apk --release && cp build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk" && md5sum build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

Erwartet: beide Prüfsummen gleich.

- [ ] **Schritt 5: `versionCode` gegenprüfen**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && "$LOCALAPPDATA/Android/Sdk/build-tools/36.1.0/aapt2.exe" dump badging "APKs/Android/Riegel.apk" | head -1
```

Erwartet: `versionCode='4'`, und in der Berechtigungsliste taucht `READ_CALENDAR` auf.

- [ ] **Schritt 6: Commit**

```bash
cd "C:/Users/klaas/Desktop/Programmieren" && git add nfc_riegel && git commit -m "docs: Geraetetest um Kalender ergaenzt, Build 4"
```

---

## Selbstprüfung gegen die Spec

| Spec-Abschnitt | Task |
|---|---|
| Kalenderquelle `CalendarContract` | 6 |
| `READ_CALENDAR` zur Laufzeit, sichtbar deaktiviert ohne sie | 7, 13 |
| Auslöser: ausgewählte Kalender | 4, 13 |
| Auslöser: Stichwort im Titel | 4, 13 |
| **Kalender wahlweise „alle Termine" oder „nur Stichwort"** | 1, 2, 4, 11, 12, 13 |
| **Stichwortregel auf bestimmte Kalender begrenzbar** | 1, 2, 4, 11, 12, 13 |
| Kalenderregel schlägt Stichwortregel | 4 |
| Ganztägige Termine ignoriert | 6 |
| Terminfenster, 48 Stunden Vorausschau | 1, 9 |
| Zwei Spuren, Vereinigung | 5 |
| Normaler Chip kommt nicht an die Kalendersperre | 5 |
| Generalschlüssel und Code beenden alles | 5 |
| `calendarSuppressedUntil` | 5 |
| Berechnet statt gespeichert | 3 |
| `pinCalendarEnd` | 3, 5 |
| Nägel werden aufgeräumt | 3, 5 |
| Auslöser: Alarm, ContentObserver, App-Start | 8, 9 |
| **Korrektur: Auffrischung alle 12 h** | 9 |
| Oberfläche: Kalender-Abschnitt, Vorschau | 13 |
| Oberfläche: Sperrschirm und Statuskachel | 14 |
| Fehlerfälle: Berechtigung entzogen, Profil gelöscht, Überlappung | 3, 4, 13 |
| Tests | 2–5, 10, 12–14 |

**Nicht aus der Spec, aber mit erledigt:** Task 1 berichtigt den Kommentar über `LockMode`, der seit der Zeitsperren-Umstellung noch behauptet, `TIMER` und `UNTIL` endeten durch erneuten Scan.

**Bewusst nicht enthalten** (wie in der Spec): Schreiben in den Kalender, Anbindung der eigenen Kalender-App über Supabase, Vorlaufzeit vor Terminbeginn, gesonderte Behandlung wiederkehrender Termine.

## Erwartete Testzahlen

| nach Task | Kotlin | Dart |
|---|---|---|
| Ausgangslage | 113 | 15 |
| 2 | 120 | 15 |
| 3 | 136 | 15 |
| 4 | 151 | 15 |
| 5 | 163 | 15 |
| 10 | 166 | 15 |
| 12 | 166 | 19 |
| 13 | 166 | 26 |
| 14 | 166 | 27 |

Weicht eine Zahl ab, **nicht** die Zahl anpassen, sondern nachsehen, welcher Test fehlt oder zu viel ist.

## Korrekturen aus der Umsetzung

1. **Task 2, `decodeCalendar`:** braucht `raw.split(FIELD, limit = 9)`. Das Fensterfeld enthält selbst FIELD-Trenner; ohne `limit` zerfällt der Datensatz in mehr als neun Teile und die Einstellungen gehen verloren. Der Kommentar über `encodeCalendar` war entsprechend falsch und ist berichtigt.
2. **Task 2, Schritt 5:** erwartet 120 statt 118 Tests (der Plan zählte die beiden Tests zur Trefferart nicht mit).
3. **Task 3, Schritt 4:** erwartet 136 statt 134 Tests.
4. **Task 4, Schritt 4:** erwartet 151 statt 144 Tests.
5. **Task 5, Schritt 7:** erwartet 163 statt 156 Tests.
6. **Task 13, Test „eingeschaltet zeigt Kalenderliste":** der Kalendername steht zweimal auf dem Schirm — in der Zuordnungsliste und als Ankreuzfeld der Stichwortregel. `findsNWidgets(2)` statt `findsOneWidget`.
7. **Task 14, `BlockActivity.refresh`:** der Plan ergänzte nur den Untertitel. `gesperrteProfile` kannte den Kalender aber nicht, also hätte sich der Sperrschirm bei einer reinen Kalendersperre sofort selbst beendet (`finish()`). Zusätzlich gehen jetzt die Terminenden in den Countdown ein, und der Hinweis nennt den Generalschlüssel statt „Chip scannen" — ein normaler Chip öffnet eine Kalendersperre nicht.
8. **Task 5, Testaufbau:** `arbeit` und `nacht` brauchen `LockMode.OPEN`. Mit dem Vorgabemodus `TIMER` startet `onTagScanned` eine Zeitsperre, statt die Chipsperre umzuschalten — der Test „normaler Chip beendet die Kalendersperre nicht" schlug mit `expected:<UNLOCKED> but was:<LOCKED>` fehl.
