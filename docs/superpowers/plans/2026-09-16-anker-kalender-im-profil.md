# Kalender im Profil — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Welche Kalender ein Profil sperren, wird im Profil eingestellt (je Kalender aus / alle Termine / nur Stichwort, dazu „Stichwort in jedem Kalender"); ein Kalender darf mehrere Profile sperren.

**Architecture:** Die Regeln wandern aus `CalendarSettings` an `Profile` (`calendars`, `keywordEverywhere`). `CalendarPlanner.profilesForEvent` liefert eine Profilmenge; `CalendarSource` erzeugt je getroffenem Profil ein `CalendarWindow` mit derselben `eventId`, sodass Nägel, Sperrmenge und Countdown unverändert bleiben. Alte zentrale Regeln werden beim Laden einmalig an die Profile gezogen.

**Tech Stack:** Kotlin (Android, JUnit 4), Flutter/Dart (flutter_test), MethodChannel `com.klaas.nfc_riegel/riegel`.

**Spec:** `docs/superpowers/specs/2026-09-16-anker-kalender-im-profil-design.md`

---

## Umgebung

- Git-Wurzel: `C:\Users\klaas\Desktop\Programmieren`, Projekt: `nfc_riegel/`. Alle Pfade unten relativ zu `nfc_riegel/`.
- Branch: `feature/anker-redesign` (bereits ausgecheckt). Nur eigene Dateien stagen — im Arbeitsbaum liegen fremde Änderungen anderer Projekte.
- Kotlin-Tests (Git Bash, aus `nfc_riegel/android`):
  ```bash
  JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" ./gradlew :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockCodecTest"
  ```
  Ergebnisse liegen unter `nfc_riegel/build/app/test-results/testDebugUnitTest/` (nicht unter `android/app/build`).
- Flutter-Tests (aus `nfc_riegel`): `flutter test test/<datei>.dart`
- Kotlin-Pfade: `K = android/app/src/main/kotlin/com/klaas/nfc_riegel`, `KT = android/app/src/test/kotlin/com/klaas/nfc_riegel`.
- Stil: deutsche Bezeichner und KDoc wie im Bestand, Kommentare erklären das Warum.

## Dateien

| Datei | Änderung |
|---|---|
| `K/Profile.kt` | Felder `calendars`, `keywordEverywhere` |
| `K/LockCodec.kt` | Profilfelder 20/21 |
| `K/CalendarPlanner.kt` | `profilesForEvent` statt `profileForEvent`; `profileIdFor` weg |
| `K/CalendarSource.kt` | `windows(settings, profiles, from, to)`, ein Fenster je Profil |
| `K/LockController.kt` | Profile an die Quelle geben |
| `K/LockMigration.kt` | `calendarRulesIntoProfiles` |
| `K/SharedPrefsLockStore.kt` | Umzug beim Laden |
| `K/CalendarWindow.kt` | KDoc: Altfelder |
| `K/LockEngine.kt` | `updateCalendarSettings(enabled, keywordMarker)` |
| `K/RiegelChannel.kt` | Profil-Map, `setCalendarSettings`, Kalender-Map, Neu-Einlesen nach Profil-Speichern |
| `K/Diagnostics.kt` | Kalenderzeile |
| `lib/lock_status.dart` | `ProfileInfo.calendars/keywordEverywhere/usesCalendar`; `CalendarRuleInfo` und drei `CalendarInfo`-Felder weg |
| `lib/riegel_channel.dart` | `updateProfile`, `setCalendarSettings` |
| `lib/calendar_screen.dart` | ohne Zuordnung, Vorschau mit Profilnamen |
| `lib/home_screen.dart` | Untertitel, Tagesband ohne Doppel, `calendar:` an ProfileScreen |
| `lib/profile_screen.dart` | Abschnitt KALENDER |
| Tests | `KT/LockCodecTest.kt`, `KT/CalendarPlannerTest.kt`, `KT/LockMigrationTest.kt`, `KT/LockEngineCalendarTest.kt`, `KT/DiagnosticsTest.kt`, `test/lock_status_test.dart`, `test/calendar_screen_test.dart`, `test/profile_screen_test.dart`, `test/home_screen_test.dart`, `test/riegel_channel_log_test.dart` |
| `GERAETETEST.md`, `pubspec.yaml` | Abschnitt Kalender, Build 21 |

---

### Task 1: Profilfelder und Codec

**Files:**
- Modify: `K/Profile.kt` (Ende der `data class Profile`)
- Modify: `K/LockCodec.kt:15-104`
- Test: `KT/LockCodecTest.kt`

- [ ] **Step 1: Failing Tests schreiben** — ans Ende der Klasse `LockCodecTest` anfügen:

```kotlin
    @Test
    fun `Kalenderauswahl am Profil uebersteht Kodieren und Dekodieren`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL, "7" to CalendarMatch.KEYWORD),
            keywordEverywhere = true,
        )

        val zurueck = LockCodec.decodeProfiles(LockCodec.encodeProfiles(listOf(profil))).single()

        assertEquals(profil, zurueck)
    }

    @Test
    fun `Profil mit neunzehn Feldern bekommt keine Kalenderauswahl`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL),
            keywordEverywhere = true,
        )

        val zurueck = LockCodec.decodeProfiles(satzMit(profil, felder = 19)).single()

        assertEquals(profil.copy(calendars = emptyMap(), keywordEverywhere = false), zurueck)
    }

    @Test
    fun `Profil mit zwanzig Feldern ist kein gueltiger Satz`() {
        val profil = Profile("p1", "Arbeit", calendars = mapOf("3" to CalendarMatch.ALL))

        assertTrue(LockCodec.decodeProfiles(satzMit(profil, felder = 20)).isEmpty())
    }

    @Test
    fun `unbekannte Trefferart am Profil wird verworfen`() {
        val profil = Profile(
            "p1",
            "Arbeit",
            calendars = mapOf("3" to CalendarMatch.ALL, "7" to CalendarMatch.KEYWORD),
        )
        val roh = LockCodec.encodeProfiles(listOf(profil)).replace("KEYWORD", "QUATSCH")

        assertEquals(
            mapOf("3" to CalendarMatch.ALL),
            LockCodec.decodeProfiles(roh).single().calendars,
        )
    }
```

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" ./gradlew :app:testDebugUnitTest --tests "com.klaas.nfc_riegel.LockCodecTest"`
Expected: Kompilierfehler „No parameter with name 'calendars' found".

- [ ] **Step 3: Profil erweitern** — in `K/Profile.kt` hinter `val quiet: QuietSettings = QuietSettings(),` einfügen:

```kotlin
    /**
     * Welche Kalender des Geräts dieses Profil sperren: Kalender-ID → welche
     * Termine. Fehlt ein Kalender, sperrt er dieses Profil nicht. Steht am
     * Profil und nicht zentral, damit derselbe Kalender mehrere Profile
     * sperren kann.
     */
    val calendars: Map<String, CalendarMatch> = emptyMap(),
    /** Termine mit dem Stichwort im Titel sperren dieses Profil, egal in welchem Kalender. */
    val keywordEverywhere: Boolean = false,
```

- [ ] **Step 4: Codec erweitern** — in `K/LockCodec.kt`:

Feldzahlen (Zeile 15–16) ersetzen durch:

```kotlin
    /** Feldzahlen, die je Ausbaustufe entstanden sind: 7, 10/11, 17, 18, 19, 21. */
    private val GUELTIGE_PROFILFELDER = setOf(7, 10, 11, 17, 18, 19, 21)
```

In `encodeProfiles` hinter `p.quiet.ringer.name,` anfügen:

```kotlin
                encodeCalendarMatches(p.calendars),
                if (p.keywordEverywhere) "1" else "0",
```

KDoc über `decodeProfiles` ersetzen durch:

```kotlin
    /**
     * Liest einundzwanzig Felder (mit Kalenderauswahl), neunzehn (mit
     * Klingelmodus), achtzehn (mit Freigabe auf Zeit), siebzehn (mit Ruhe), elf
     * und zehn (mit Atempause) und sieben (davor). Ein alter Satz bekommt die
     * Vorgaben — stillschweigend zu verwerfen hieße, gesperrte Apps zu vergessen.
     */
```

Im `Profile(...)`-Aufruf von `decodeProfiles` hinter `timedRelease = f.size >= 18 && f[17] == "1",` anfügen:

```kotlin
                // Felder 20 und 21 kamen gemeinsam mit der Kalenderauswahl am Profil.
                calendars = if (f.size >= 21) decodeCalendarMatches(f[19]) else emptyMap(),
                keywordEverywhere = f.size >= 21 && f[20] == "1",
```

Direkt vor `private fun encodeRules` einfügen:

```kotlin
    /** Kalenderauswahl eines Profils als `id PAIR ALL|KEYWORD`, durch ITEM getrennt. */
    private fun encodeCalendarMatches(auswahl: Map<String, CalendarMatch>): String =
        encodeMap(auswahl.mapValues { it.value.name })

    /** Ein unbekannter Wert fällt weg — „alle Termine" zu raten sperrte womöglich zu viel. */
    private fun decodeCalendarMatches(raw: String): Map<String, CalendarMatch> =
        decodeMap(raw).mapNotNull { (id, art) ->
            runCatching { CalendarMatch.valueOf(art) }.getOrNull()?.let { id to it }
        }.toMap()
```

- [ ] **Step 5: Tests grün**

Run: wie Step 2. Expected: `BUILD SUCCESSFUL`, alle `LockCodecTest` grün.

- [ ] **Step 6: Commit**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockCodec.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockCodecTest.kt
git commit -m "feat: Profil traegt seine Kalenderauswahl"
```

---

### Task 2: Planer und Kalenderquelle — mehrere Profile je Termin

**Files:**
- Modify: `K/CalendarPlanner.kt:33-46` (`activeWindows`-Ende, `profileIdFor`), `K/CalendarPlanner.kt:84-116` (`profileForEvent`)
- Modify: `K/CalendarSource.kt:18`, `K/CalendarSource.kt:57-101`
- Modify: `K/LockController.kt:31-37`
- Test: `KT/CalendarPlannerTest.kt` (Tests ab `Kalender auf ALL sperrt mit jedem Termin` bis Dateiende ersetzen)

- [ ] **Step 1: Failing Tests schreiben** — in `KT/CalendarPlannerTest.kt` alle Tests von `` `Kalender auf ALL sperrt mit jedem Termin` `` bis einschließlich `` `leerer Marker trifft nie` `` löschen und stattdessen einfügen (vor der schließenden Klammer der Klasse):

```kotlin
    private fun profil(
        id: String,
        calendars: Map<String, CalendarMatch> = emptyMap(),
        ueberall: Boolean = false,
    ) = Profile(id, "Profil $id", calendars = calendars, keywordEverywhere = ueberall)

    private fun treffer(profile: List<Profile>, kalender: String, titel: String, marker: String = "[Riegel]") =
        CalendarPlanner.profilesForEvent(profile, marker, kalender, titel)

    @Test
    fun `Kalender auf ALL sperrt mit jedem Termin`() {
        val p = listOf(profil("p1", mapOf("cal1" to CalendarMatch.ALL)))

        assertEquals(setOf("p1"), treffer(p, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalender auf KEYWORD sperrt nur bei Treffer`() {
        val p = listOf(profil("p1", mapOf("cal1" to CalendarMatch.KEYWORD)))

        assertEquals(setOf("p1"), treffer(p, "cal1", "[Riegel] Konzept"))
        assertTrue(treffer(p, "cal1", "Zahnarzt").isEmpty())
    }

    @Test
    fun `nicht gewaehlter Kalender sperrt nicht`() {
        val p = listOf(profil("p1", mapOf("cal1" to CalendarMatch.ALL)))

        assertTrue(treffer(p, "cal2", "Zahnarzt").isEmpty())
    }

    @Test
    fun `Stichwort ueberall greift in jedem Kalender, aber nur mit Treffer`() {
        val p = listOf(profil("p1", ueberall = true))

        assertEquals(setOf("p1"), treffer(p, "cal9", "[Riegel] Sport"))
        assertTrue(treffer(p, "cal9", "Sport").isEmpty())
    }

    @Test
    fun `derselbe Kalender in zwei Profilen sperrt beide`() {
        val p = listOf(
            profil("p1", mapOf("cal1" to CalendarMatch.ALL)),
            profil("p2", mapOf("cal1" to CalendarMatch.ALL)),
        )

        assertEquals(setOf("p1", "p2"), treffer(p, "cal1", "Zahnarzt"))
    }

    @Test
    fun `Kalenderwahl und Stichwort ueberall sperren gemeinsam`() {
        // Früher hatte die Kalenderregel Vorrang und sperrte allein. Jetzt
        // stehen beide gleichberechtigt an ihren Profilen.
        val p = listOf(
            profil("p1", mapOf("cal1" to CalendarMatch.ALL)),
            profil("p2", ueberall = true),
        )

        assertEquals(setOf("p1", "p2"), treffer(p, "cal1", "[Riegel] Sport"))
    }

    @Test
    fun `leerer Marker trifft nie`() {
        val p = listOf(
            profil("p1", mapOf("cal1" to CalendarMatch.KEYWORD)),
            profil("p2", ueberall = true),
        )

        assertTrue(treffer(p, "cal1", "Irgendein Termin", marker = "").isEmpty())
    }
```

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `... --tests "com.klaas.nfc_riegel.CalendarPlannerTest"`
Expected: Kompilierfehler „Unresolved reference: profilesForEvent".

- [ ] **Step 3: Planer umbauen** — in `K/CalendarPlanner.kt`:

In `activeWindows` die Zeile

```kotlin
            .map { (id, ende) -> CalendarWindow(id, "Termin", 0L, ende, profileIdFor(c, id)) }
```

ersetzen durch

```kotlin
            // Ohne gespeichertes Fenster ist das Profil nicht mehr bekannt.
            // `updateWindows` behält genagelte Fenster deshalb im Speicher; dieser
            // Rest sperrt kein Profil, hält aber die Grenze fest.
            .map { (id, ende) -> CalendarWindow(id, "Termin", 0L, ende, "") }
```

Die Funktion `profileIdFor` samt KDoc löschen.

Die Funktion `profileForEvent` samt KDoc ersetzen durch:

```kotlin
    /**
     * Welche Profile ein Termin sperrt. Ein Profil trifft, wenn es den Kalender
     * auf [CalendarMatch.ALL] gesetzt hat — oder wenn der Titel den Marker
     * enthält und das Profil den Kalender auf [CalendarMatch.KEYWORD] oder
     * [Profile.keywordEverywhere] gesetzt hat. Alle Treffer sperren; es gibt
     * keine Rangfolge mehr.
     */
    fun profilesForEvent(
        profiles: List<Profile>,
        marker: String,
        calendarId: String,
        title: String,
    ): Set<String> {
        val trifftMarker = marker.isNotEmpty() && title.contains(marker)
        return profiles.filter { p ->
            when (p.calendars[calendarId]) {
                CalendarMatch.ALL -> true
                CalendarMatch.KEYWORD -> trifftMarker
                null -> trifftMarker && p.keywordEverywhere
            }
        }.map { it.id }.toSet()
    }
```

- [ ] **Step 4: Quelle umbauen** — in `K/CalendarSource.kt`:

Interface-Zeile ersetzen:

```kotlin
    fun windows(
        settings: CalendarSettings,
        profiles: List<Profile>,
        from: Long,
        to: Long,
    ): List<CalendarWindow>
```

Signatur in `ContentCalendarSource` ersetzen:

```kotlin
    override fun windows(
        settings: CalendarSettings,
        profiles: List<Profile>,
        from: Long,
        to: Long,
    ): List<CalendarWindow> {
```

Den Block von `val profil = CalendarPlanner.profileForEvent(settings, kalenderId, titel)` bis zum Ende von `ergebnis += CalendarWindow(...)` ersetzen durch:

```kotlin
                val getroffen = CalendarPlanner.profilesForEvent(
                    profiles, settings.keywordMarker, kalenderId, titel,
                )
                if (getroffen.isEmpty()) continue

                // Beginn angehängt: eine wiederkehrende Serie hat für alle Termine
                // dieselbe EVENT_ID, das Festnageln muss aber den einzelnen treffen.
                val eventId = "${c.getLong(0)}_$beginn"
                // Ein Fenster je Profil, alle mit derselben eventId: so bleiben
                // Nägel (nach eventId), Sperrmenge und Countdown wie sie sind.
                for (profilId in getroffen) {
                    ergebnis += CalendarWindow(
                        eventId = eventId,
                        title = titel,
                        startsAt = beginn,
                        endsAt = ende,
                        profileId = profilId,
                    )
                }
```

- [ ] **Step 5: Controller** — in `K/LockController.kt` in `refreshCalendar` die Zeile

```kotlin
        val fenster = quelle.windows(zustand.calendar, now, now + CALENDAR_LOOKAHEAD_MILLIS)
```

ersetzen durch

```kotlin
        val fenster = quelle.windows(
            zustand.calendar, zustand.profiles, now, now + CALENDAR_LOOKAHEAD_MILLIS,
        )
```

- [ ] **Step 6: Tests grün, Rest kompiliert**

Run: `... :app:testDebugUnitTest` (alle Kotlin-Tests)
Expected: `BUILD SUCCESSFUL`. (`LockEngineCalendarTest`/`DiagnosticsTest` nutzen noch die Altfelder — die existieren weiter, kompiliert also.)

- [ ] **Step 7: Commit**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarPlanner.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarSource.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/CalendarPlannerTest.kt
git commit -m "feat: ein Termin sperrt alle Profile, die seinen Kalender gewaehlt haben"
```

---

### Task 3: Umzug der alten Regeln an die Profile

**Files:**
- Modify: `K/LockMigration.kt` (neue Funktion am Ende des `object`)
- Modify: `K/SharedPrefsLockStore.kt:28-39`
- Modify: `K/CalendarWindow.kt` (KDoc der Altfelder und `CalendarRule`)
- Test: `KT/LockMigrationTest.kt`

- [ ] **Step 1: Failing Tests schreiben** — in `KT/LockMigrationTest.kt` Import `import org.junit.Assert.assertSame` ergänzen und ans Ende der Klasse anfügen:

```kotlin
    private val arbeit = Profile("p1", "Arbeit")
    private val nacht = Profile("p2", "Nacht")

    private fun mitKalender(c: CalendarSettings) =
        LockState(profiles = listOf(arbeit, nacht), calendar = c)

    @Test
    fun `ohne alte Regeln bleibt der Zustand dasselbe Objekt`() {
        val zustand = mitKalender(CalendarSettings(enabled = true))

        assertSame(zustand, LockMigration.calendarRulesIntoProfiles(zustand))
    }

    @Test
    fun `Kalenderregeln ziehen mit Trefferart an ihr Profil`() {
        val zustand = mitKalender(
            CalendarSettings(
                calendarRules = mapOf(
                    "cal1" to CalendarRule("p1", CalendarMatch.ALL),
                    "cal2" to CalendarRule("p1", CalendarMatch.KEYWORD),
                    "cal3" to CalendarRule("p2", CalendarMatch.ALL),
                ),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertEquals(
            mapOf("cal1" to CalendarMatch.ALL, "cal2" to CalendarMatch.KEYWORD),
            neu.profileById("p1")!!.calendars,
        )
        assertEquals(mapOf("cal3" to CalendarMatch.ALL), neu.profileById("p2")!!.calendars)
    }

    @Test
    fun `Stichwortregel ohne Kalenderauswahl wird Stichwort ueberall`() {
        val zustand = mitKalender(CalendarSettings(keywordProfileId = "p2"))

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertTrue(neu.profileById("p2")!!.keywordEverywhere)
        assertEquals(false, neu.profileById("p1")!!.keywordEverywhere)
    }

    @Test
    fun `Stichwortregel mit Kalenderauswahl wird nur Stichwort, alle Termine bleibt`() {
        val zustand = mitKalender(
            CalendarSettings(
                calendarRules = mapOf("cal1" to CalendarRule("p2", CalendarMatch.ALL)),
                keywordProfileId = "p2",
                keywordCalendarIds = setOf("cal1", "cal2"),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertEquals(
            mapOf("cal1" to CalendarMatch.ALL, "cal2" to CalendarMatch.KEYWORD),
            neu.profileById("p2")!!.calendars,
        )
        assertEquals(false, neu.profileById("p2")!!.keywordEverywhere)
    }

    @Test
    fun `Regeln auf verschwundene Profile fallen weg und Altfelder sind danach leer`() {
        val zustand = mitKalender(
            CalendarSettings(
                enabled = true,
                keywordMarker = "[Fokus]",
                calendarRules = mapOf("cal1" to CalendarRule("weg", CalendarMatch.ALL)),
                keywordProfileId = "weg",
                keywordCalendarIds = setOf("cal1"),
            ),
        )

        val neu = LockMigration.calendarRulesIntoProfiles(zustand)

        assertTrue(neu.profiles.all { it.calendars.isEmpty() && !it.keywordEverywhere })
        assertTrue(neu.calendar.calendarRules.isEmpty())
        assertNull(neu.calendar.keywordProfileId)
        assertTrue(neu.calendar.keywordCalendarIds.isEmpty())
        assertTrue(neu.calendar.enabled)
        assertEquals("[Fokus]", neu.calendar.keywordMarker)
    }
```

(Falls `LockState.profileById` nicht existiert: `neu.profiles.single { it.id == "p1" }` verwenden. Es existiert laut `BlockActivity.kt:220`.)

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `... --tests "com.klaas.nfc_riegel.LockMigrationTest"`
Expected: „Unresolved reference: calendarRulesIntoProfiles".

- [ ] **Step 3: Umzug implementieren** — in `K/LockMigration.kt` vor der schließenden Klammer des `object` einfügen:

```kotlin
    /**
     * Zieht die früher zentralen Kalenderregeln an die Profile. Die Wirkung
     * bleibt dieselbe — bis auf die Rangfolge: früher sperrte bei Kalender- und
     * Stichworttreffer nur das Profil der Kalenderregel, jetzt sperren beide.
     *
     * Ist nichts umzuziehen, kommt **dasselbe Objekt** zurück; daran erkennt der
     * Speicher, dass er nicht zurückschreiben muss.
     */
    fun calendarRulesIntoProfiles(state: LockState): LockState {
        val c = state.calendar
        if (c.calendarRules.isEmpty() &&
            c.keywordProfileId == null &&
            c.keywordCalendarIds.isEmpty()
        ) {
            return state
        }

        val profile = state.profiles.map { p ->
            val auswahl = p.calendars.toMutableMap()
            for ((kalender, regel) in c.calendarRules) {
                if (regel.profileId == p.id) auswahl[kalender] = regel.match
            }
            var ueberall = p.keywordEverywhere
            if (c.keywordProfileId == p.id) {
                if (c.keywordCalendarIds.isEmpty()) {
                    ueberall = true
                } else {
                    for (kalender in c.keywordCalendarIds) {
                        // „Alle Termine" schließt die mit Stichwort schon ein.
                        if (auswahl[kalender] != CalendarMatch.ALL) {
                            auswahl[kalender] = CalendarMatch.KEYWORD
                        }
                    }
                }
            }
            p.copy(calendars = auswahl, keywordEverywhere = ueberall)
        }

        return state.copy(
            profiles = profile,
            calendar = c.copy(
                calendarRules = emptyMap(),
                keywordProfileId = null,
                keywordCalendarIds = emptySet(),
            ),
        )
    }
```

- [ ] **Step 4: Speicher ruft den Umzug** — in `K/SharedPrefsLockStore.kt` in `load()` `return LockState(` ersetzen durch `val gelesen = LockState(` und nach der schließenden `)` dieses Aufrufs einfügen:

```kotlin

        // Kalenderregeln standen bis Build 20 zentral. Einmal an die Profile
        // ziehen und sofort zurückschreiben, damit es beim nächsten Laden
        // nichts mehr zu tun gibt.
        val umgezogen = LockMigration.calendarRulesIntoProfiles(gelesen)
        if (umgezogen !== gelesen) save(umgezogen)
        return umgezogen
```

- [ ] **Step 5: KDoc der Altfelder** — in `K/CalendarWindow.kt`:

KDoc über `data class CalendarRule` ersetzen durch:

```kotlin
/**
 * Frühere zentrale Regel für einen Kalender. Wird nur noch gelesen, um sie mit
 * [LockMigration.calendarRulesIntoProfiles] an die Profile zu ziehen; die
 * Auswahl steht heute in [Profile.calendars].
 */
```

In `CalendarSettings` die KDoc-Kommentare über `calendarRules`, `keywordProfileId` und `keywordCalendarIds` jeweils ersetzen durch:

```kotlin
    /** Nur noch für den Umzug, siehe [LockMigration.calendarRulesIntoProfiles]. */
```

- [ ] **Step 6: Tests grün**

Run: `... :app:testDebugUnitTest`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockMigration.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/SharedPrefsLockStore.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/CalendarWindow.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockMigrationTest.kt
git commit -m "feat: alte Kalenderregeln ziehen beim Laden an die Profile"
```

---

### Task 4: Engine, Kanal und Diagnose

**Files:**
- Modify: `K/LockEngine.kt:450-475` (`updateCalendarSettings`)
- Modify: `K/RiegelChannel.kt` (`updateProfile` ~Z. 29-72, `setCalendarSettings` ~Z. 241-264, `stateMap` Profile ~Z. 303-330 und Kalender ~Z. 354-372)
- Modify: `K/Diagnostics.kt:79-99`
- Test: `KT/LockEngineCalendarTest.kt`, `KT/DiagnosticsTest.kt`

- [ ] **Step 1: Failing Tests schreiben**

In `KT/LockEngineCalendarTest.kt` den Test `` `Einstellungen schreiben laesst den Zwischenspeicher stehen` `` ersetzen durch:

```kotlin
    @Test
    fun `Einstellungen schreiben laesst den Zwischenspeicher stehen`() {
        val (e, store) = engine(laufendesFenster())

        e.updateCalendarSettings(enabled = true, keywordMarker = "[Fokus]")

        assertEquals("[Fokus]", store.current.calendar.keywordMarker)
        assertEquals(1, store.current.calendar.cachedWindows.size)
    }

    @Test
    fun `Termin mit zwei Profilen sperrt beide`() {
        val (e, _) = engine(
            CalendarSettings(
                enabled = true,
                cachedWindows = listOf(
                    CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1"),
                    CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p2"),
                ),
            ),
        )

        assertEquals(setOf("com.a", "com.b"), e.blockedPackages(jetzt))
    }

    @Test
    fun `Nagel eines Profils haelt den Termin fuer beide Profile fest`() {
        val nagler = Profile("p1", "Arbeit", setOf("com.a"), LockMode.OPEN, pinCalendarEnd = true)
        val store = FakeLockStore(
            LockState(profiles = listOf(nagler, nacht), calendar = CalendarSettings(enabled = true))
        )
        val e = LockEngine(store)

        e.updateWindows(
            listOf(
                CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p1"),
                CalendarWindow("e1", "Konzept", jetzt - minute, jetzt + minute, "p2"),
            ),
            jetzt,
        )
        // Termin im Kalender gelöscht.
        e.updateWindows(emptyList(), jetzt)

        assertEquals(setOf("com.a", "com.b"), e.blockedPackages(jetzt))
    }
```

In `KT/DiagnosticsTest.kt` den Test `` `Kalenderlage nennt Anzahl und naechste Grenze` `` ersetzen durch:

```kotlin
    @Test
    fun `Kalenderlage nennt Anzahl und naechste Grenze`() {
        val jetzt = 1_000_000L
        val zustand = LockState(
            profiles = listOf(
                Profile("p1", "Arbeit", calendars = mapOf("cal1" to CalendarMatch.KEYWORD)),
                Profile("p2", "Nacht", keywordEverywhere = true),
                Profile("p3", "Frei"),
            ),
            calendar = CalendarSettings(
                enabled = true,
                cachedWindows = listOf(
                    CalendarWindow("e1", "Konzept", jetzt - 1, jetzt + 60_000, "p1"),
                ),
            ),
        )

        val zeile = Diagnostics.summarize(zustand, jetzt).getValue("Kalender")

        assertTrue(zeile.contains("an"))
        assertTrue(zeile.contains("2 Profile mit Kalender"))
        assertTrue(zeile.contains("1 mit Stichwort überall"))
        assertTrue(zeile.contains("1 Termin"))
        assertFalse(zeile.contains("Stichwortregel"))
    }
```

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `... :app:testDebugUnitTest`
Expected: Kompilierfehler „No value passed for parameter 'calendarRules'" in `LockEngineCalendarTest`.

- [ ] **Step 3: Engine** — in `K/LockEngine.kt` `updateCalendarSettings` samt KDoc ersetzen durch:

```kotlin
    /**
     * Speichert Hauptschalter und Stichwort — das, was für alle Profile gilt.
     * Welche Kalender sperren, steht an den Profilen. Der Zwischenspeicher
     * bleibt stehen, er wird gleich darauf ohnehin neu eingelesen.
     */
    fun updateCalendarSettings(enabled: Boolean, keywordMarker: String): LockState {
        val s = store.load()
        val next = s.copy(
            calendar = s.calendar.copy(enabled = enabled, keywordMarker = keywordMarker),
        )
        store.save(next)
        return next
    }
```

- [ ] **Step 4: Diagnose** — in `K/Diagnostics.kt` in `kalenderZeile` die Zeilen von `val nurStichwort = ...` bis einschließlich `"Stichwortregel in $stichwortBereich Kalendern",` ersetzen durch:

```kotlin
        val mitKalender = state.profiles.count { it.calendars.isNotEmpty() || it.keywordEverywhere }
        val ueberall = state.profiles.count { it.keywordEverywhere }
        val teile = mutableListOf(
            "an",
            "$mitKalender Profile mit Kalender ($ueberall mit Stichwort überall)",
```

(Die folgenden Zeilen `"${c.cachedWindows.size} Termine im Speicher",` usw. bleiben.)

- [ ] **Step 5: Kanal** — in `K/RiegelChannel.kt`:

(a) `updateProfile`: im `Profile(...)`-Aufruf hinter dem schließenden `),` von `quiet = QuietSettings(...)` einfügen:

```kotlin
                        calendars = (call.argument<Map<String, String>>("calendars") ?: emptyMap())
                            .mapNotNull { (id, art) ->
                                runCatching { CalendarMatch.valueOf(art) }.getOrNull()
                                    ?.let { id to it }
                            }
                            .toMap(),
                        keywordEverywhere = call.argument<Boolean>("keywordEverywhere") ?: false,
```

und

```kotlin
                    result.success(
                        controller.updateProfile(profile, System.currentTimeMillis())
                    )
```

ersetzen durch

```kotlin
                    val gespeichert = controller.updateProfile(profile, System.currentTimeMillis())
                    // Eine geänderte Kalenderauswahl soll sofort greifen, nicht
                    // erst beim nächsten Wecker.
                    if (gespeichert) controller.refreshCalendar()
                    result.success(gespeichert)
```

(b) `setCalendarSettings`-Zweig komplett ersetzen durch:

```kotlin
                "setCalendarSettings" -> {
                    controller.engine.updateCalendarSettings(
                        enabled = call.argument<Boolean>("enabled") ?: false,
                        keywordMarker = call.argument<String>("keywordMarker") ?: "[Riegel]",
                    )
                    controller.refreshCalendar()
                    result.success(true)
                }
```

(c) `stateMap`, Profil-Map: hinter `"quietRinger" to p.quiet.ringer.name,` einfügen:

```kotlin
                    "calendars" to p.calendars.mapValues { it.value.name },
                    "keywordEverywhere" to p.keywordEverywhere,
```

(d) `stateMap`, Kalender-Map: die Einträge `"calendarRules" to ...` (samt Kommentar darüber), `"keywordProfileId" to ...` und `"keywordCalendarIds" to ...` löschen. Den Eintrag `"windows" to ...` ersetzen durch:

```kotlin
                // Die nächsten drei Termine. Ein Termin mit zwei Profilen steht
                // zweimal im Speicher, zählt hier aber einmal — beide Fenster
                // gehen mit, damit die Vorschau beide Profile nennen kann.
                "windows" to s.calendar.cachedWindows
                    .sortedBy { it.startsAt }
                    .let { sortiert ->
                        val naechste = sortiert.map { it.eventId }.distinct().take(3).toSet()
                        sortiert.filter { it.eventId in naechste }
                    }
                    .map { windowMap(it) },
```

- [ ] **Step 6: Keine Altfeld-Nutzer mehr außerhalb von Umzug und Codec**

Run (aus `nfc_riegel`): `grep -rn "calendarRules\|keywordProfileId\|keywordCalendarIds" android/app/src/main`
Expected: Treffer nur in `CalendarWindow.kt`, `LockCodec.kt`, `LockMigration.kt`.

- [ ] **Step 7: Tests grün**

Run: `... :app:testDebugUnitTest`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Diagnostics.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/LockEngineCalendarTest.kt nfc_riegel/android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt
git commit -m "feat: Kanal und Diagnose fuehren die Kalenderauswahl am Profil"
```

---

### Task 5: Dart-Modell, Kanal, Kalender-Schirm, Hauptschirm

**Files:**
- Modify: `lib/lock_status.dart` (`ProfileInfo`, `CalendarRuleInfo`, `CalendarInfo`)
- Modify: `lib/riegel_channel.dart` (`updateProfile`, `setCalendarSettings`)
- Replace: `lib/calendar_screen.dart`
- Modify: `lib/home_screen.dart` (`_tagesfenster`, Kalender-`_NavRow`)
- Test: `test/lock_status_test.dart`, `test/calendar_screen_test.dart`, `test/home_screen_test.dart`, `test/riegel_channel_log_test.dart`

- [ ] **Step 1: Failing Tests schreiben**

(a) `test/lock_status_test.dart`: die Tests `'Kalendereinstellungen werden gelesen'` und `'leere Stichwort-Kalenderliste heisst alle'` ersetzen durch:

```dart
  test('Kalendereinstellungen werden gelesen', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {
        'enabled': true,
        'keywordMarker': '[Fokus]',
        'permissionGranted': true,
        'windows': <dynamic>[],
        'activeWindows': <dynamic>[],
      },
    });

    expect(status.calendar.enabled, isTrue);
    expect(status.calendar.keywordMarker, '[Fokus]');
    expect(status.calendar.permissionGranted, isTrue);
  });

  test('Profil liest seine Kalenderauswahl', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'calendars': {'cal1': 'ALL', 'cal2': 'KEYWORD'},
          'keywordEverywhere': true,
        },
        {'id': 'p2', 'name': 'Nacht'},
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    final arbeit = status.profiles.first;
    expect(arbeit.calendars, {
      'cal1': CalendarMatch.all,
      'cal2': CalendarMatch.keyword,
    });
    expect(arbeit.keywordEverywhere, isTrue);
    expect(arbeit.usesCalendar, isTrue);
    expect(status.profiles.last.calendars, isEmpty);
    expect(status.profiles.last.usesCalendar, isFalse);
  });
```

(b) `test/riegel_channel_log_test.dart`: im Test `'gespeichertes Profil steht mit Anzahl und Modus im Protokoll'` im `ProfileInfo(...)` hinter `quietSchedules: [],` ergänzen:

```dart
        calendars: {'cal1': CalendarMatch.all},
        keywordEverywhere: true,
```

und hinter `expect(protokolliert('Atempause an'), isTrue);` ergänzen:

```dart
    expect(protokolliert('1 Kalender, Stichwort überall an'), isTrue);
```

(c) `test/calendar_screen_test.dart` komplett ersetzen durch:

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

  void stub() {
    gespeichert = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
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

  Map<String, dynamic> profil(String id, String name) => {
    'id': id,
    'name': name,
    'blockedPackages': <dynamic>[],
    'defaultMode': 'TIMER',
    'durationMinutes': 60,
    'pinCalendarEnd': false,
  };

  LockStatus status({
    bool enabled = false,
    bool permission = true,
    List<Map<String, dynamic>> windows = const [],
  }) => LockStatus.fromMap({
    'profiles': [profil('p1', 'Arbeit'), profil('p2', 'Nacht')],
    'tags': <dynamic>[],
    'timeLocks': <dynamic>[],
    'calendar': {
      'enabled': enabled,
      'permissionGranted': permission,
      'keywordMarker': '[Riegel]',
      'windows': windows,
      'activeWindows': <dynamic>[],
    },
  });

  Widget screen(LockStatus s) => MaterialApp(
    home: CalendarScreen(status: s, channel: RiegelChannel(channel)),
  );

  Map<String, dynamic> fenster(String eventId, String profileId) {
    final jetzt = DateTime.now();
    return {
      'eventId': eventId,
      'title': 'Konzept schreiben',
      'startsAt': jetzt.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'endsAt': jetzt.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      'profileId': profileId,
    };
  }

  testWidgets('ohne Berechtigung erscheint der Hinweis', (tester) async {
    stub();
    await tester.pumpWidget(screen(status(permission: false)));

    expect(find.textContaining('Berechtigung'), findsOneWidget);
  });

  testWidgets('ausgeschaltet bleibt das Stichwort verborgen', (tester) async {
    stub();
    await tester.pumpWidget(screen(status()));

    expect(find.text('Stichwort im Termintitel'), findsNothing);
  });

  testWidgets('eingeschaltet zeigt Stichwort und Verweis aufs Profil, keine Zuordnung', (
    tester,
  ) async {
    stub();
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    expect(find.text('Stichwort im Termintitel'), findsOneWidget);
    expect(find.textContaining('im jeweiligen Profil'), findsOneWidget);
    expect(find.text('KALENDER DES GERÄTS'), findsNothing);
    expect(find.text('STICHWORTREGEL'), findsNothing);
  });

  testWidgets('Stichwort speichern schickt nur Schalter und Stichwort', (
    tester,
  ) async {
    stub();
    await tester.pumpWidget(screen(status(enabled: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '[Fokus]');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(gespeichert, {'enabled': true, 'keywordMarker': '[Fokus]'});
  });

  testWidgets('Vorschau nennt Termin einmal mit allen Profilen', (tester) async {
    stub();
    await tester.pumpWidget(
      screen(
        status(enabled: true, windows: [fenster('e1', 'p1'), fenster('e1', 'p2')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konzept schreiben'), findsOneWidget);
    expect(find.textContaining('Arbeit, Nacht'), findsOneWidget);
  });
}
```

(d) `test/home_screen_test.dart`: im Test `'laufender Termin steht in der Statuskachel'` die Zeilen `'calendarRules': <dynamic, dynamic>{},` und `'keywordCalendarIds': <dynamic>[],` löschen.

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/lock_status_test.dart test/calendar_screen_test.dart test/riegel_channel_log_test.dart`
Expected: Kompilierfehler („No named parameter with the name 'calendars'", „usesCalendar isn't defined").

- [ ] **Step 3: Modell** — in `lib/lock_status.dart`:

(a) Konstruktor `ProfileInfo`: hinter `this.quietRinger = RingerMode.unveraendert,` einfügen:

```dart
    this.calendars = const {},
    this.keywordEverywhere = false,
```

(b) Felder: hinter `final RingerMode quietRinger;` einfügen:

```dart

  /// Kalender-ID → welche Termine dieses Profil sperren. Fehlt = aus.
  final Map<String, CalendarMatch> calendars;

  /// Termine mit dem Stichwort sperren dieses Profil, egal in welchem Kalender.
  final bool keywordEverywhere;

  /// Ob überhaupt ein Termin dieses Profil sperren kann.
  bool get usesCalendar => calendars.isNotEmpty || keywordEverywhere;
```

(c) `ProfileInfo.fromMap`: hinter `quietRinger: _ringerFrom(map['quietRinger'] as String?),` einfügen:

```dart
      calendars: (map['calendars'] as Map<dynamic, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k as String, _matchFrom(v as String?)),
      ),
      keywordEverywhere: map['keywordEverywhere'] as bool? ?? false,
```

(d) Klasse `CalendarRuleInfo` samt Doc-Kommentar löschen (`CalendarMatch`, `_matchFrom`, `matchToNative` bleiben).

(e) `CalendarInfo`: Konstruktorparameter, Felder (samt Doc-Kommentaren), Einträge in `empty` und in `fromMap` für `calendarRules`, `keywordProfileId` und `keywordCalendarIds` löschen.

- [ ] **Step 4: Kanal** — in `lib/riegel_channel.dart`:

(a) `updateProfile`: den Protokolltext

```dart
      '(${profile.quietNumbers.length} Nummern, '
      '${profile.quietSchedules.length} Zeitfenster)',
```

ersetzen durch

```dart
      '(${profile.quietNumbers.length} Nummern, '
      '${profile.quietSchedules.length} Zeitfenster), '
      // Kalender-IDs und -Namen bleiben draußen, die Anzahl genügt.
      '${profile.calendars.length} Kalender, '
      'Stichwort überall ${profile.keywordEverywhere ? "an" : "aus"}',
```

und in der Argument-Map hinter `'quietRinger': ringerToNative(profile.quietRinger),` einfügen:

```dart
          'calendars': profile.calendars.map(
            (id, art) => MapEntry(id, matchToNative(art)),
          ),
          'keywordEverywhere': profile.keywordEverywhere,
```

(b) `setCalendarSettings` komplett ersetzen durch:

```dart
  /// Nur was für alle Profile gilt. Welche Kalender sperren, steht am Profil.
  Future<void> setCalendarSettings({
    required bool enabled,
    required String keywordMarker,
  }) async {
    FeedbackService.log('Kalender gespeichert: ${enabled ? "an" : "aus"}');
    await channel.invokeMethod<bool>('setCalendarSettings', {
      'enabled': enabled,
      'keywordMarker': keywordMarker,
    });
  }
```

- [ ] **Step 5: Kalender-Schirm** — `lib/calendar_screen.dart` komplett ersetzen durch:

```dart
import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Was für alle Profile gilt: Schalter, Stichwort, Vorschau. Welche Kalender
/// ein Profil sperren, stellt man im Profil ein — dort, wo man es sucht.
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
  late final TextEditingController _marker =
      TextEditingController(text: widget.status.calendar.keywordMarker);

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  Future<void> _schalte(bool an) async {
    if (an && !_berechtigt) {
      final erteilt = await widget.channel.requestCalendarPermission();
      if (!erteilt) return;
      if (mounted) setState(() => _berechtigt = true);
    }
    setState(() => _an = an);
    await _speichere();
  }

  Future<void> _speichere() => widget.channel.setCalendarSettings(
    enabled: _an,
    keywordMarker: _marker.text,
  );

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
                'Ohne Berechtigung für den Kalender kann Anker keine Termine sehen.',
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
            const SizedBox(height: RiegelSpacing.s3),
            const Text(
              'Welche Kalender sperren, stellst du im jeweiligen Profil ein.',
              style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
            ),
            const SizedBox(height: RiegelSpacing.s5),
            TextField(
              controller: _marker,
              decoration: const InputDecoration(
                labelText: 'Stichwort im Termintitel',
              ),
              onSubmitted: (_) => _speichere(),
            ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('NÄCHSTE TERMINE', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (widget.status.calendar.windows.isEmpty)
              const Text('Kein passender Termin in den nächsten 48 Stunden.')
            else
              for (final termin in _nachTermin(widget.status.calendar.windows))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(termin.first.title),
                  subtitle: Text(
                    '${_zeitraum(termin.first)} · ${_profilNamen(termin)}',
                  ),
                ),
          ],
        ],
      ),
    );
  }

  /// Ein Termin mit zwei Profilen kommt als zwei Fenster mit derselben
  /// `eventId`. Hier wird er wieder einer — in der Reihenfolge des ersten
  /// Auftretens, die Liste kommt schon nach Beginn sortiert.
  List<List<CalendarWindowInfo>> _nachTermin(List<CalendarWindowInfo> fenster) {
    final gruppen = <String, List<CalendarWindowInfo>>{};
    for (final f in fenster) {
      gruppen.putIfAbsent(f.eventId, () => []).add(f);
    }
    return gruppen.values.toList();
  }

  String _profilNamen(List<CalendarWindowInfo> termin) {
    final namen = <String>[];
    for (final f in termin) {
      for (final p in widget.status.profiles) {
        if (p.id == f.profileId) namen.add(p.name);
      }
    }
    return namen.join(', ');
  }

  String _zeitraum(CalendarWindowInfo w) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${w.startsAt.day}.${w.startsAt.month}. ${hhmm(w.startsAt)} – ${hhmm(w.endsAt)}';
  }
}
```

- [ ] **Step 6: Hauptschirm** — in `lib/home_screen.dart`:

(a) In `_tagesfenster` vor `for (final w in status.calendar.windows) {` einfügen:

```dart
    // Ein Termin mit zwei Profilen kommt doppelt — im Band zählt er einmal.
    final gesehen = <String>{};
```

und als erste Zeile im Schleifenrumpf:

```dart
      if (!gesehen.add(w.eventId)) continue;
```

(b) Im Kalender-`_NavRow` den `subtitle:`-Ausdruck ersetzen durch:

```dart
                    subtitle: status.calendar.enabled
                        ? _kalenderUntertitel(status)
                        : 'aus',
```

und in der State-Klasse (z. B. direkt über `_openCalendar`) einfügen:

```dart
  static String _kalenderUntertitel(LockStatus status) {
    final n = status.profiles.where((p) => p.usesCalendar).length;
    return switch (n) {
      0 => 'noch keinem Profil zugeordnet',
      1 => '1 Profil mit Kalender',
      _ => '$n Profile mit Kalender',
    };
  }
```

- [ ] **Step 7: Analyse und Tests grün**

Run: `flutter analyze` — Expected: keine Fehler (bestehende Infos sind in Ordnung).
Run: `flutter test` — Expected: alle grün. Bricht `profile_screen_test.dart` nicht, ist das richtig (Profil-Schirm kommt in Task 6).

- [ ] **Step 8: Commit**

```bash
git add nfc_riegel/lib/lock_status.dart nfc_riegel/lib/riegel_channel.dart nfc_riegel/lib/calendar_screen.dart nfc_riegel/lib/home_screen.dart nfc_riegel/test/lock_status_test.dart nfc_riegel/test/calendar_screen_test.dart nfc_riegel/test/home_screen_test.dart nfc_riegel/test/riegel_channel_log_test.dart
git commit -m "feat: Kalender-Schirm ohne Zuordnung, Modell traegt Auswahl am Profil"
```

---

### Task 6: Abschnitt KALENDER im Profil-Schirm

**Files:**
- Modify: `lib/profile_screen.dart` (Imports, Widget-Parameter, State-Felder, `initState`, `_save`, `build` hinter „Kalender-Ende festnageln")
- Modify: `lib/home_screen.dart:115-124` (`_editProfile`)
- Test: `test/profile_screen_test.dart`

- [ ] **Step 1: Failing Tests schreiben** — in `test/profile_screen_test.dart`:

(a) `stub` ersetzen durch:

```dart
  void stub({
    required bool usageGranted,
    List<Map<String, String>> kalender = const [],
  }) {
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
            case 'deviceCalendars':
              return kalender;
          }
          return null;
        });
  }
```

(b) Hinter `Widget screen() => ...;` einfügen:

```dart
  Widget kalenderSchirm({
    bool an = true,
    ProfileInfo profile = profil,
  }) => MaterialApp(
    home: ProfileScreen(
      profile: profile,
      channel: RiegelChannel(channel),
      calendar: CalendarInfo.fromMap({
        'enabled': an,
        'permissionGranted': true,
        'keywordMarker': '[Riegel]',
      }),
    ),
  );

  const privat = {'id': 'cal1', 'name': 'Privat', 'account': 'ich@example.com'};
```

(c) Am Ende von `main` einfügen:

```dart
  testWidgets('ausgeschalteter Kalender zeigt nur den Hinweis', (tester) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(kalenderSchirm(an: false));
    await tester.pumpAndSettle();

    await scrolleZu(tester, find.text('Die Kalenderfunktion ist aus.'));
    expect(find.text('Zum Kalender'), findsOneWidget);
    expect(find.text('Privat'), findsNothing);
  });

  testWidgets('gespeicherte Auswahl steht in der Kalenderzeile', (tester) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(
      kalenderSchirm(
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
          quietEnabled: false,
          quietScope: QuietScope.alle,
          quietNumbers: [],
          quietAfterEventMinutes: 0,
          quietWhileLocked: true,
          quietSchedules: [],
          calendars: {'cal1': CalendarMatch.all},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrolleZu(tester, find.byKey(const ValueKey('kalender-cal1')));
    expect(find.text('Privat'), findsOneWidget);
    expect(find.text('alle Termine'), findsOneWidget);
  });

  testWidgets('Kalenderauswahl und Stichwort ueberall werden gesichert', (
    tester,
  ) async {
    stub(usageGranted: true, kalender: [privat]);
    await tester.pumpWidget(kalenderSchirm());
    await tester.pumpAndSettle();

    final auswahl = find.byKey(const ValueKey('kalender-cal1'));
    await scrolleZu(tester, auswahl);
    await tester.tap(auswahl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('nur Stichwort').last);
    await tester.pumpAndSettle();

    final ueberall = find.textContaining('in jedem Kalender');
    await scrolleZu(tester, ueberall);
    await tester.tap(ueberall);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sichern'));
    await tester.pumpAndSettle();

    expect(gespeichert!['calendars'], {'cal1': 'KEYWORD'});
    expect(gespeichert!['keywordEverywhere'], isTrue);
  });
```

- [ ] **Step 2: Laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/profile_screen_test.dart`
Expected: Kompilierfehler „No named parameter with the name 'calendar'".

- [ ] **Step 3: Profil-Schirm** — in `lib/profile_screen.dart`:

(a) Import ergänzen (alphabetisch hinter `app_picker_screen.dart`):

```dart
import 'calendar_screen.dart';
```

(b) Widget: Konstruktor und Felder ersetzen durch:

```dart
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.channel,
    this.calendar = CalendarInfo.empty,
  });

  final ProfileInfo profile;
  final RiegelChannel channel;

  /// Hauptschalter, Berechtigung und Stichwort — gelten für alle Profile und
  /// entscheiden, ob der Abschnitt KALENDER Auswahl oder Hinweis zeigt.
  final CalendarInfo calendar;
```

(c) State-Felder: hinter `late RingerMode _quietRinger = widget.profile.quietRinger;` einfügen:

```dart
  late final Map<String, CalendarMatch> _kalenderAuswahl = Map.of(
    widget.profile.calendars,
  );
  late bool _stichwortUeberall = widget.profile.keywordEverywhere;
  late CalendarInfo _kalender = widget.calendar;
  List<DeviceCalendarInfo> _geraeteKalender = const [];
```

(d) `initState`: hinter `_ladeBerechtigung();` einfügen: `_ladeKalender();`

(e) Hinter `_ladeBerechtigung` einfügen:

```dart
  Future<void> _ladeKalender() async {
    if (!_kalender.enabled || !_kalender.permissionGranted) return;
    final liste = await widget.channel.deviceCalendars();
    if (mounted) setState(() => _geraeteKalender = liste);
  }

  /// Hauptschalter und Berechtigung liegen im Kalender-Schirm. Beim Zurückkommen
  /// den neuen Stand holen — sonst stünde der Hinweis noch da, obwohl der
  /// Kalender längst an ist.
  Future<void> _oeffneKalender() async {
    final status = await widget.channel.getState();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(status: status, channel: widget.channel),
      ),
    );
    final neu = await widget.channel.getState();
    if (!mounted) return;
    setState(() => _kalender = neu.calendar);
    await _ladeKalender();
  }
```

(f) `_save`: im `ProfileInfo(...)` hinter `quietRinger: _quietRinger,` einfügen:

```dart
        calendars: _kalenderAuswahl,
        keywordEverywhere: _stichwortUeberall,
```

(g) `build`: direkt hinter dem `SwitchListTile` „Kalender-Ende festnageln" (vor `const SizedBox(height: RiegelSpacing.s6), Text('ATEMPAUSE', ...)`) einfügen:

```dart
          const SizedBox(height: RiegelSpacing.s6),
          Text('KALENDER', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          ..._kalenderAbschnitt(),
```

(h) Methode in der State-Klasse (z. B. über `build`) einfügen:

```dart
  List<Widget> _kalenderAbschnitt() {
    if (!_kalender.enabled || !_kalender.permissionGranted) {
      return [
        const Text(
          'Die Kalenderfunktion ist aus.',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
        ),
        const SizedBox(height: RiegelSpacing.s3),
        OutlinedButton(
          onPressed: _oeffneKalender,
          child: const Text('Zum Kalender'),
        ),
      ];
    }
    return [
      SwitchListTile(
        value: _stichwortUeberall,
        onChanged: (v) => setState(() => _stichwortUeberall = v),
        title: Text('Stichwort „${_kalender.keywordMarker}" in jedem Kalender'),
        subtitle: const Text(
          'Termine mit dem Stichwort im Titel sperren dieses Profil, egal in '
          'welchem Kalender sie stehen',
        ),
        contentPadding: EdgeInsets.zero,
      ),
      if (_geraeteKalender.isEmpty)
        const Text(
          'Kein Kalender auf diesem Gerät gefunden.',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg3),
        ),
      // Kalender, die das Gerät nicht mehr kennt, bleiben in der Auswahl
      // gespeichert, erscheinen hier aber nicht — ändern lässt sich an ihnen
      // ohnehin nichts.
      for (final k in _geraeteKalender)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k.name),
          subtitle: Text(k.account),
          trailing: DropdownButton<CalendarMatch?>(
            key: ValueKey('kalender-${k.id}'),
            value: _kalenderAuswahl[k.id],
            items: const [
              DropdownMenuItem<CalendarMatch?>(value: null, child: Text('aus')),
              DropdownMenuItem<CalendarMatch?>(
                value: CalendarMatch.all,
                child: Text('alle Termine'),
              ),
              DropdownMenuItem<CalendarMatch?>(
                value: CalendarMatch.keyword,
                child: Text('nur Stichwort'),
              ),
            ],
            onChanged: (art) => setState(() {
              if (art == null) {
                _kalenderAuswahl.remove(k.id);
              } else {
                _kalenderAuswahl[k.id] = art;
              }
            }),
          ),
        ),
    ];
  }
```

- [ ] **Step 4: Hauptschirm übergibt den Kalenderstand** — in `lib/home_screen.dart` in `_editProfile` den `builder` ersetzen durch:

```dart
        builder: (_) => ProfileScreen(
          profile: profile,
          channel: widget.channel,
          calendar: _status?.calendar ?? CalendarInfo.empty,
        ),
```

- [ ] **Step 5: Tests grün**

Run: `flutter test test/profile_screen_test.dart` — Expected: alle grün.
Falls der Dropdown-Tipp im 800×600-Testfenster ins Leere geht (Menü außerhalb): wie in `setup_wizard_test.dart` das Fenster vergrößern — in den drei neuen Tests vor `pumpWidget`:

```dart
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
```

Run: `flutter analyze` und `flutter test` — Expected: keine Fehler, alles grün.

- [ ] **Step 6: Commit**

```bash
git add nfc_riegel/lib/profile_screen.dart nfc_riegel/lib/home_screen.dart nfc_riegel/test/profile_screen_test.dart
git commit -m "feat: Kalender im Profil auswaehlen"
```

---

### Task 7: Gerätetest-Liste, Build 21, Emulator, APK

**Files:**
- Modify: `GERAETETEST.md` (Abschnitt „## Kalender" bis vor den nächsten `## `-Abschnitt)
- Modify: `pubspec.yaml:19`

- [ ] **Step 1: GERAETETEST.md** — den Abschnitt `## Kalender` mit seinen Unterabschnitten `### Trefferart je Kalender` und `### Eigenständige Stichwortregel` (bis vor die nächste `## `-Überschrift) ersetzen durch:

```markdown
## Kalender

- [ ] Kalenderfunktion einschalten — Berechtigungsabfrage erscheint
- [ ] Abfrage ablehnen — Hinweis erscheint, Funktion bleibt aus
- [ ] Abfrage erlauben — Kalender-Schirm zeigt nur Schalter, Stichwort, Vorschau und den Satz „… im jeweiligen Profil ein"
- [ ] Update von Build 20: vorher zugeordnete Kalender stehen jetzt im jeweiligen Profil, Stichwortregel als „Stichwort in jedem Kalender" bzw. „nur Stichwort"
- [ ] Profil öffnen — Abschnitt KALENDER listet die Kalender des Geräts
- [ ] Einen Kalender auf „alle Termine", sichern
- [ ] Termin in diesem Kalender anlegen, der in 2 Minuten beginnt und 5 Minuten dauert
- [ ] Bei Terminbeginn sperren die Apps des Profils
- [ ] Sperrschirm zeigt den Termintitel und „frei ab HH:MM"
- [ ] Bei Terminende geben sie wieder frei
- [ ] Ganztägiger Termin sperrt nicht

### Trefferart je Kalender

- [ ] Denselben Kalender im Profil auf „nur Stichwort" umstellen
- [ ] Termin **ohne** Stichwort im Titel sperrt jetzt **nicht** mehr
- [ ] Termin **mit** `[Riegel]` im Titel sperrt weiterhin

### Stichwort in jedem Kalender

- [ ] Im zweiten Profil „Stichwort in jedem Kalender" einschalten, keinen Kalender wählen
- [ ] Termin mit `[Riegel]` in einem beliebigen Kalender sperrt dieses Profil

### Ein Kalender, mehrere Profile

- [ ] Denselben Kalender in zwei Profilen auf „alle Termine"
- [ ] Laufender Termin sperrt die Apps **beider** Profile
- [ ] Kalender-Schirm, Vorschau: Termin steht **einmal**, mit beiden Profilnamen
- [ ] Hauptschirm: Kalender-Kachel sagt „2 Profile mit Kalender", Tagesband zeigt den Termin einmal
- [ ] Fehlerbericht: Kalenderzeile nennt „2 Profile mit Kalender"
```

- [ ] **Step 2: Build-Nummer** — `pubspec.yaml`: `version: 1.0.0+20` → `version: 1.0.0+21`.

- [ ] **Step 3: Alles prüfen**

Run (aus `nfc_riegel`): `flutter analyze` → keine Fehler; `flutter test` → alles grün.
Run (aus `nfc_riegel/android`): `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" ./gradlew :app:testDebugUnitTest` → `BUILD SUCCESSFUL`.

- [ ] **Step 4: Emulator** (Regel aus `Programmieren/CLAUDE.md`)

`adb devices` — läuft `emulator-5554`, diesen nutzen; sonst `Pixel_8_API_35` im Hintergrund starten und auf `sys.boot_completed = 1` warten.

Debug-APK bauen und installieren (`flutter build apk --debug`, `adb install -r build/app/outputs/flutter-apk/app-debug.apk`). Zustand setzen mit dem Seed-Skript aus dem Scratchpad (`seed_prefs.py`) — dessen Profilsätze haben 19 Felder und werden mit leerer Kalenderauswahl gelesen. Kalender im Kalender-Schirm einschalten (Berechtigung im Emulator erlauben). Prüfen per Screenshot (`adb exec-out screencap -p > shot.png`):
- Kalender-Schirm ohne Zuordnungsliste, mit Verweissatz.
- Profil „Fokus" öffnen, nach unten zu KALENDER scrollen: Gerätekalender mit Auswahl „aus"; auf „alle Termine" stellen, sichern, erneut öffnen — Auswahl steht.
- Hauptschirm-Kachel „1 Profil mit Kalender".

- [ ] **Step 5: Release-APK und Ablage**

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "C:/Users/klaas/Desktop/Programmieren/APKs/Android/Anker.apk"
```

- [ ] **Step 6: Commit**

```bash
git add nfc_riegel/GERAETETEST.md nfc_riegel/pubspec.yaml
git commit -m "chore: Build 21 mit der Kalenderauswahl im Profil"
```
