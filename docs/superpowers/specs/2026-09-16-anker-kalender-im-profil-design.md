# Anker: Kalender im Profil auswählen

Datum: 2026-09-16 · Projekt: `nfc_riegel` (App-Name „Anker") · Anlass: Fehlerbericht
„ich will die Kalender in den Profilen auswählen können nicht außerhalb der
Profile zuordnen"

## Ziel

Welche Kalender ein Profil sperren, stellt man **im Profil** ein. Der
Kalender-Schirm behält nur, was für alle Profile gilt.

Entscheidungen des Nutzers:

- Derselbe Kalender darf in **mehreren Profilen** gewählt sein. Ein Termin sperrt
  dann alle diese Profile gleichzeitig.
- Die Stichwortregel wird **je Kalender** gewählt (aus / alle Termine / nur
  Stichwort), dazu je Profil ein Schalter „Stichwort in jedem Kalender". Die
  eigenständige Stichwortregel im Kalender-Schirm entfällt.

## Datenmodell (Kotlin)

`Profile` bekommt zwei Felder, beide hinten angehängt:

```kotlin
/** Kalender-ID des Geräts → welche Termine dieses Profil sperren. Fehlt = aus. */
val calendars: Map<String, CalendarMatch> = emptyMap(),
/** Termine mit Stichwort sperren dieses Profil, egal in welchem Kalender. */
val keywordEverywhere: Boolean = false,
```

`CalendarSettings.calendarRules`, `keywordProfileId` und `keywordCalendarIds`
bleiben nur als **Altfelder zum Einlesen** bestehen (KDoc: „nur noch für den
Umzug"). Nach dem Umzug sind sie leer; nichts außer dem Umzug liest sie.
`CalendarRule` bleibt aus demselben Grund.

`CalendarMatch` (ALL, KEYWORD) bleibt unverändert.

## Codec

- Profilsatz: Feld 20 = `calendars` (Einträge mit ITEM getrennt, Paar
  `kalenderId PAIR MATCH`), Feld 21 = `keywordEverywhere` („1"/„0").
  `GUELTIGE_PROFILFELDER` um 21 erweitern. Ältere Sätze (7…19 Felder) lesen
  beide Felder mit Vorgabe (leer, aus). Unbekannter MATCH-Wert → Eintrag
  verworfen.
- Kalendersatz: Format mit 9 Feldern bleibt. Nach dem Umzug werden Feld 1, 3
  und 4 leer geschrieben.

## Rechnung

`CalendarPlanner.profileForEvent(c, calendarId, title): String?` wird ersetzt
durch

```kotlin
fun profilesForEvent(
    profiles: List<Profile>,
    marker: String,
    calendarId: String,
    title: String,
): Set<String>
```

Ein Profil trifft, wenn

- `calendars[calendarId] == ALL`, oder
- der Titel den Marker enthält (Marker nicht leer) und
  `calendars[calendarId] == KEYWORD` oder `keywordEverywhere`.

`CalendarSource` bekommt die Profilliste und erzeugt je getroffenem Profil ein
`CalendarWindow` mit derselben `eventId`. `CalendarWindow.profileId` bleibt ein
einzelnes Profil. Dadurch bleiben unverändert:

- `pinnedEnds` (Schlüssel `eventId`) — ein Nagel gilt für den Termin.
- `pinsToAdd` — nagelt, wenn eines der getroffenen Profile nagelt.
- `lockedProfileIds` — Menge, Doppel fallen weg.
- Countdown im Sperrschirm und auf dem Hauptschirm (spätestes Ende).

Genagelte Fenster eines gelöschten Termins bleiben wie heute über
`LockEngine.updateWindows` im Zwischenspeicher — der Filter dort behält alle
Fenster mit der genagelten `eventId`, also auch alle ihre Profile. Der Rückfall
in `CalendarPlanner.profileIdFor` (Nagel ganz ohne gespeichertes Fenster) kann
kein Stichwortprofil mehr nehmen und liefert `""`; ein solches Fenster sperrt
kein Profil.

## Umzug

Reine Funktion `LockMigration.calendarRulesIntoProfiles(state: LockState): LockState`,
aufgerufen in `SharedPrefsLockStore.load()`, wenn eines der Altfelder nicht leer
ist; Ergebnis sofort zurückschreiben.

- `calendarRules[X] = (P, m)` → `P.calendars[X] = m`.
- `keywordProfileId = Q`:
  - `keywordCalendarIds` leer → `Q.keywordEverywhere = true`.
  - sonst für jede `K` darin: `Q.calendars[K] = KEYWORD`, außer dort steht
    schon `ALL` (die stärkere Regel bleibt).
- Regeln auf Profile, die es nicht mehr gibt, fallen weg.
- Danach Altfelder leeren.

Wirkung auf dem Gerät vor und nach dem Umzug ist dieselbe — mit einer bewusst
hingenommenen Ausnahme: Früher hatte die Kalenderregel Vorrang vor der
Stichwortregel (ein Termin sperrte nur ein Profil). Jetzt sperren beide.

## Löschen eines Profils

Keine Sonderbehandlung: die Regeln stehen am Profil und verschwinden mit ihm.

## Kanal

- Profil-Map (beide Richtungen) um `calendars` (`Map<String,String>`, Werte
  `ALL`/`KEYWORD`) und `keywordEverywhere` (`bool`) erweitern.
- `setCalendarSettings` nimmt nur noch `enabled` und `keywordMarker`.
- Nach dem Speichern eines Profils werden die Kalenderfenster neu eingelesen
  (wie heute nach `setCalendarSettings`), damit eine neue Auswahl sofort greift.
- Kalenderstatus an Dart: `calendarRules`, `keywordProfileId`,
  `keywordCalendarIds` entfallen.

## Diagnose

Kalenderzeile: „an, 2 Profile mit Kalender (1 mit Stichwort überall), 0 Termine
im Speicher, 0 Termin(e) sperren gerade".

## Oberfläche

### Profil-Schirm

Neuer Abschnitt **KALENDER** unter „Kalender-Ende festnageln".

- Kalenderfunktion aus oder Berechtigung fehlt: ein Satz („Die Kalenderfunktion
  ist aus.") und Knopf „Zum Kalender" (öffnet den Kalender-Schirm; beim
  Zurückkommen Status und Gerätekalender neu laden).
- Sonst:
  - `SwitchListTile` „Stichwort „<Marker>" in jedem Kalender".
  - Je Gerätekalender eine Zeile: Name, Konto darunter, rechts
    `DropdownButton` mit **aus / alle Termine / nur Stichwort**.
  - Keine Gerätekalender: „Kein Kalender auf diesem Gerät gefunden."
- Regeln für Kalender, die das Gerät nicht mehr kennt, bleiben gespeichert und
  werden nicht angezeigt.
- Gespeichert wird mit dem Profil (Speichern-Knopf), Abbrechen verwirft.

### Kalender-Schirm

Bleibt: Hinweis Berechtigung, Hauptschalter, Stichwort-Text, „Nächste Termine".
Entfällt: Kalenderzeilen mit Profilauswahl, Abschnitt Stichwortregel mit
Profil und Kalender-Häkchen. Neu: ein Satz „Welche Kalender sperren, stellst
du im jeweiligen Profil ein." Die Vorschau zeigt je Termin die Profilnamen
(Fenster mit gleicher `eventId` zusammengefasst).

### Hauptschirm

Untertitel der Kalender-Kachel: „n Profile mit Kalender" (Profile mit nicht
leerem `calendars` oder `keywordEverywhere`), bei 0 „noch keinem Profil
zugeordnet".

## Tests

Kotlin:
- `CalendarPlannerTest`: ALL, KEYWORD mit/ohne Treffer, `keywordEverywhere`,
  leerer Marker, zwei Profile auf denselben Kalender → beide.
- `LockCodecTest`: Profil mit Feld 20/21 hin und zurück; 19-Feld-Satz liest mit
  Vorgaben; kaputter MATCH-Eintrag verworfen.
- `LockMigrationTest`: alle Umzugsregeln oben inkl. „ALL bleibt", verwaiste
  Profil-ID, Altfelder danach leer.
- `LockEngineCalendarTest`: Termin mit zwei Profilen sperrt beide; Nagel greift,
  wenn eines der Profile nagelt.
- `DiagnosticsTest`: neue Kalenderzeile.

Flutter:
- `lock_status_test`: Profil liest `calendars`/`keywordEverywhere`.
- `profile_screen_test`: Auswahl „nur Stichwort" und Schalter landen im
  gespeicherten Profil; bei ausgeschalteter Kalenderfunktion nur Hinweis.
- `calendar_screen_test`: keine Profilauswahl mehr; Speichern schickt nur
  `enabled` und `keywordMarker`.

Emulator: Profil-Schirm mit Kalenderabschnitt ansehen (Emulator hat
Google-Kalender).

## Nicht Teil davon

- Lautstärkeprofil je Kalendereintrag (weiter geparkt).
- Umbenennen des Markers `[Riegel]`.
