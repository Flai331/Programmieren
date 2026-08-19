# Riegel v3 — Zeitsperren ohne Chip

Datum: 2026-08-05
Projekt: `Programmieren\nfc_riegel`
Baut auf: `2026-08-04-riegel-profile-chips-design.md`
Löst ab: die Abschnitte „Sperr-Modi", „Scan-Verhalten" und „Einstellungssperre" jener Spec

## Anlass

Ein Profil mit Modus `UNTIL` hat nicht gesperrt. Kein Codefehler — die Sperre war
nie gestartet worden. `UNTIL` und `TIMER` waren als *Endebedingung einer
Chipsperre* gebaut: ohne Scan kein Start, und der Chip, der startet, beendet auch
wieder. Damit ist eine Zeitsperre genau so lange verbindlich, wie man den Chip
nicht in die Hand nimmt.

Gefordert ist das Gegenteil: **Zeitsperren starten ohne Chip und lassen sich vor
Ablauf nur mit einem Generalschlüssel öffnen.**

## Zwei Spuren

| Spur | Modus | Start | Frühes Ende |
|---|---|---|---|
| **Chipsperre** | `OPEN` | nur Chip-Scan | erneuter Scan eines Chips desselben Profils, Generalschlüssel, Notfall-Code |
| **Zeitsperre** | `TIMER`, `UNTIL`, Kalender | Schaltfläche, Chip-Scan oder Termin | **nur** Generalschlüssel oder Notfall-Code |

Beide Spuren laufen unabhängig nebeneinander. Gesperrt ist die **Vereinigung**
aller aktiven Sperren. Der Modus des Profils entscheidet, welche Spur ein Start
erzeugt — nicht, wodurch er ausgelöst wurde.

Daraus folgt der Kern der Änderung: **ein normaler Chip beendet nie eine
Zeitsperre.** Er beendet ausschließlich die Chipsperre seines eigenen Profils.

## Datenmodell

`LockState.chipLock` bleibt, verliert aber `mode` und `endsAt` — eine Chipsperre
ist immer `OPEN` und immer unbefristet.

```kotlin
data class ChipLock(val profileId: String)
```

Neu daneben:

```kotlin
data class TimeLock(
    val profileId: String,
    val mode: LockMode,   // TIMER oder UNTIL, nie OPEN
    val endsAt: Long,     // immer gesetzt
)
```

| Feld | Typ | Bedeutung |
|---|---|---|
| `chipLock` | `ChipLock?` | Höchstens eine, wie bisher |
| `timeLocks` | `List<TimeLock>` | Höchstens eine je Profil |

Höchstens eine Zeitsperre je Profil: zwei Sperren desselben Profils sperren
dieselben Apps, die zweite wäre nur eine andere Endzeit. Verschiedene Profile
dürfen gleichzeitig sperren.

Kalendersperren stehen **nicht** in `timeLocks`. Sie werden aus den Terminfenstern
gerechnet — siehe Kalender-Spec.

## Zeitsperre starten

`startTimeLock(profileId, now)` — aus der Oberfläche oder durch einen Chip-Scan.

| Lage | Ergebnis |
|---|---|
| Profil hat Modus `OPEN` | `WRONG_MODE` — `OPEN` gibt es nur als Chipsperre |
| Profil unbekannt | `NO_PROFILE` |
| `UNTIL`, `untilAt` fehlt oder liegt in der Vergangenheit | `UNTIL_IN_PAST`, keine Sperre |
| Keine Zeitsperre dieses Profils | `STARTED` |
| Zeitsperre läuft, neues Ende ist **später** | `EXTENDED`, Ende wird überschrieben |
| Zeitsperre läuft, neues Ende ist gleich oder früher | `ALREADY_RUNNING`, Zustand unverändert |

Verlängern ja, verkürzen nein. Strenger stellen darf man sich jederzeit — das ist
der einzige Weg, der die Sperre nicht untergräbt. Ein zweiter Druck auf „Sperren"
kann eine laufende Sperre also niemals verkürzen.

**Verlängern gibt es nur über die Schaltfläche, nicht über den Chip.** Ein Chip
kommt beim Einstecken des Handys auch mal versehentlich vorbei; würde jeder Scan
verlängern, ließe sich eine Sperre unbeabsichtigt verdoppeln. Ein Scan bei bereits
laufender Zeitsperre desselben Profils ergibt daher `ALREADY_RUNNING` und ändert
nichts. Technisch: `startTimeLock(profileId, now, allowExtend)` — die Schaltfläche
übergibt `true`, der Scan `false`.

`TIMER` rechnet `endsAt = now + durationMinutes × 60000`. Beim Verlängern zählt
das Ergebnis, nicht die Dauer: ein 30-Minuten-Timer, 20 Minuten nach dem Start
erneut gedrückt, endet 50 statt 30 Minuten nach dem ersten Start.

## Scan-Verhalten

```
Kein Chip angelernt                              → nichts
Unbekannte UID                                   → nichts
Generalschlüssel, irgendeine Sperre läuft        → alle enden, Kalender unterdrückt
Generalschlüssel, nichts läuft                   → verhält sich wie ein normaler Chip
Chip mit OPEN-Profil, keine Chipsperre           → Chipsperre startet
Chip mit OPEN-Profil, Chipsperre desselben Profils → gibt frei
Chip mit OPEN-Profil, Chipsperre anderen Profils → übernimmt: alte endet, neue beginnt
Chip mit TIMER/UNTIL-Profil, keine Zeitsperre    → Zeitsperre startet
Chip mit TIMER/UNTIL-Profil, Zeitsperre läuft    → nichts, kein Verlängern
```

Ein Chip mit `TIMER`- oder `UNTIL`-Profil ist damit ein reiner **Startknopf**. Er
kann seine eigene Sperre nicht mehr aufheben. Der Profilbildschirm sagt das beim
Umschalten auf `TIMER`/`UNTIL` ausdrücklich an.

Die Übernahme („alte endet, neue beginnt") gilt weiterhin nur zwischen
Chipsperren. Eine Zeitsperre wird nie übernommen, nur ergänzt.

### Warum ein normaler Chip nicht mehr freigibt

Vorher beendete jeder Scan des passenden Chips jede Sperre dieses Profils. Wer
den Chip zur Hand hatte, hatte auch den Ausgang. Das ist für `OPEN` gewollt — der
Chip *ist* dort der Schalter. Für eine Zeitsperre hebt es die Zusage auf, die
gerade den Zweck ausmacht.

## Alles beenden

Generalschlüssel und Notfall-Code räumen weiterhin gemeinsam ab: `chipLock = null`,
`timeLocks = []`, `failedAttempts = 0`, `codeLockedUntil = null`. Zusätzlich setzt
die Kalender-Spec `calendarSuppressedUntil`.

Kein Zwischending: es gibt keine Möglichkeit, eine einzelne von mehreren
gleichzeitig laufenden Sperren gezielt zu beenden. Wer den Generalschlüssel zieht,
zieht ihn ganz. Ein gezieltes Beenden wäre eine zweite Bedienoberfläche für den
Ausnahmefall — und ein zweiter Weg, sich Ausnahmen zu gewöhnen.

## Ablauf und Alarm

`onTimerElapsed(now)` entfernt **alle** abgelaufenen Zeitsperren, nicht nur die
erste. Die Uhrzeit entscheidet, nicht das Feuern des Alarms — wie bisher.

Der Alarm wird auf `min(endsAt)` aller laufenden Zeitsperren gesetzt und nach
jedem Feuern neu geplant, solange noch welche laufen. Eine Chipsperre plant keinen
Alarm, sie hat kein Ende.

`restoreAfterBoot(now)` bleibt derselbe Aufruf: abgelaufene Zeitsperren fallen
weg, nicht abgelaufene bleiben samt neu gesetztem Alarm, die Chipsperre bleibt
unverändert bestehen.

## Was gesperrt ist

```
blockedPackages(now) = Vereinigung der blockedPackages aller Profile,
                       die über chipLock oder eine nicht abgelaufene
                       timeLocks-Zeile aktiv sind
```

## Einstellungssperre

Bisher fragten die Wächter `chipLock != null` — ohne Uhrzeit. Eine abgelaufene,
aber noch nicht aufgeräumte Sperre blockierte damit weiter das Anlernen von Chips
und das Erzeugen des Notfall-Codes, bis der Alarm feuerte. Alle Wächter fragen
künftig `hasActiveLock(now)` und rechnen den Ablauf mit.

| Vorgang | Erlaubt, solange |
|---|---|
| Profil ändern | keine aktive Sperre **dieses** Profils läuft |
| Profil löschen | dasselbe, und es ist nicht das letzte |
| Chip anlernen oder löschen | **keine** Sperre läuft |
| Notfall-Code erzeugen | **keine** Sperre läuft |

Ein Profil mit laufender Zeitsperre ist damit genauso gesperrt wie eines mit
laufender Chipsperre. Sonst ließe sich die App-Liste während der Sperre leeren.

## Oberfläche

**Profilzeile im Hauptscreen** bekommt bei `TIMER` und `UNTIL` eine Schaltfläche
**„Sperren"**. Bei `OPEN` steht dort weiterhin nur der Hinweis auf den Chip.
Läuft die Sperre bereits, zeigt die Zeile das Ende und die Schaltfläche heißt
**„Verlängern"**.

**Bestätigung vor dem Start.** Ein Dialog, der beim Namen nennt, worauf man sich
einlässt:

> Sperrt **Arbeit** bis **18:30**.
> Vorher öffnet nur ein Generalschlüssel oder der Notfall-Code.

Zwei zusätzliche Warnzeilen, wenn zutreffend:

- **Kein Generalschlüssel angelernt** — dann öffnet ausschließlich der Notfall-Code
- **Kein Notfall-Code gesetzt** — zusammen mit dem ersten Fall die einzige Lage,
  in der eine Sperre gar nicht vorzeitig zu öffnen ist. Der Dialog sagt das
  deutlich und in Rot.

Die Bestätigung entfällt beim Chip-Scan: der Scan ist die Bestätigung, und ein
Dialog auf dem Sperrschirm-Weg wäre nur ein Klick, den man wegtippt.

**Statuskachel** zeigt bei mehreren gleichzeitigen Sperren die früheste Endzeit
und die Anzahl: „2 Sperren — frei ab 18:30". Bei genau einer bleibt es beim
bisherigen Text mit Profilnamen.

**Sperrschirm** nennt das Profil und, bei einer Zeitsperre, das Ende. Sperren
mehrere Profile dieselbe App, steht die Sperre mit dem spätesten Ende oben — sie
ist die, die zählt.

## Migration

Zustände aus v2 haben `chipLock` mit `mode` und `endsAt`:

- `mode == OPEN` → bleibt `chipLock`, Felder fallen weg
- `mode == TIMER` oder `UNTIL` mit `endsAt` in der Zukunft → wird eine Zeile in
  `timeLocks`
- abgelaufen → verworfen

Die Migration läuft in `LockMigration` beim Lesen eines Zustands im alten Format,
wie die v1→v2-Migration. `LockCodec` bekommt dafür eine Fassung mehr.

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| „Sperren" bei `UNTIL` mit Zeitpunkt in der Vergangenheit | Sperre startet nicht, Meldung im Hauptscreen |
| Zweiter Druck auf „Sperren" bei laufendem `TIMER` | Verlängert um die volle Dauer ab jetzt |
| „Sperren" bei laufendem `UNTIL` mit unverändertem Zeitpunkt | `ALREADY_RUNNING`, nichts passiert |
| Normaler Chip während Zeitsperre desselben Profils | Nichts — Meldung „Zeitsperre läuft, nur Generalschlüssel öffnet" |
| Normaler Chip mit `OPEN`-Profil während fremder Zeitsperre | Chipsperre startet zusätzlich, beide gelten |
| Profil einer laufenden Zeitsperre löschen | Nicht möglich |
| Neustart während mehrerer Zeitsperren | Alle nicht abgelaufenen bleiben, Alarm auf die früheste |
| Uhr des Geräts zurückgestellt | Sperre läuft länger. Bewusst hingenommen — die Alternative wäre eine eigene Zeitquelle |

## Tests

**Kotlin, JUnit** — in `LockEngine`:

- `startTimeLock`: `STARTED`, `EXTENDED`, `ALREADY_RUNNING`, `WRONG_MODE`,
  `UNTIL_IN_PAST`, `NO_PROFILE`
- Verlängern verkürzt nie: früheres Ende lässt `endsAt` unverändert
- Normaler Chip beendet eine Zeitsperre **nicht**
- Normaler Chip mit `OPEN`-Profil sperrt zusätzlich zu laufender Zeitsperre
- Chip mit `TIMER`-Profil startet eine Zeitsperre statt einer Chipsperre
- Generalschlüssel beendet Chip- und Zeitsperren gemeinsam
- Notfall-Code ebenso
- `blockedPackages`: Vereinigung über Chipsperre und mehrere Zeitsperren
- `onTimerElapsed` räumt mehrere abgelaufene Zeilen zugleich ab und lässt
  laufende stehen
- Wächter mit abgelaufener, nicht aufgeräumter Sperre erlauben wieder
- Profil mit laufender Zeitsperre ist nicht änderbar, ein anderes schon
- Migration: v2-`chipLock` mit `TIMER` wird zur Zeitsperre, `OPEN` bleibt Chipsperre,
  abgelaufene wird verworfen

**Flutter, widget test** — Schaltfläche „Sperren" nur bei `TIMER`/`UNTIL`,
Bestätigungsdialog mit Endzeit, Warnzeile ohne Generalschlüssel.

**Von Hand** — `GERAETETEST.md`: Zeitsperre ohne Chip starten, normalen Chip
dagegen scannen (darf nicht öffnen), Generalschlüssel dagegen (muss öffnen),
Neustart während laufender Zeitsperre.

**Verifikation:** `flutter analyze`, `flutter test`,
`android\gradlew.bat -p android :app:testDebugUnitTest`

## Bewusst nicht enthalten

- Gezieltes Beenden einer einzelnen von mehreren Sperren
- Mehrere gleichzeitige Zeitsperren desselben Profils
- Verkürzen einer laufenden Sperre, auf welchem Weg auch immer
- Schutz gegen das Zurückstellen der Geräteuhr
- Kalendersperren — eigene Spec, baut auf dieser auf

---

## Nachtrag 2026-08-14: Chipsperre ohne Chip starten

Die ursprüngliche Fassung ließ `OPEN` nur durch einen Scan beginnen; die
Schaltfläche gab es nur für `TIMER` und `UNTIL`. Damit ließ sich ein Profil im
Modus „Bis Scan" ohne Chip gar nicht zumachen.

**Neu:** `startLock` (vormals `startTimeLock`) startet die Sperre, für die das
Profil eingerichtet ist — bei `OPEN` eine Chipsperre. Zumachen geht damit immer
ohne Chip. Aufmachen nicht: die so gestartete Sperre endet erst durch einen
Scan, den Generalschlüssel oder den Notfall-Code.

Das ist der Kern des Zwei-Spuren-Modells, nur konsequent zu Ende gedacht — der
Griff zum Riegel soll leicht sein, der Weg zurück nicht.

`StartOutcome.WRONG_MODE` entfällt, weil es keinen Modus mehr gibt, der
abgelehnt wird. Der Bestätigungsdialog warnt bei einer Chipsperre erst, wenn
**gar kein** Chip angelernt ist — anders als bei einer Zeitsperre öffnet hier
jeder Chip des Profils, nicht nur der Generalschlüssel.

## Nachtrag 2026-08-14: Notausgang aus dem Administratorrecht

Der Deinstallationsschutz hatte keinen Ausweg für den Besitzer: Android
verweigert die Deinstallation, solange die App Geräteadministrator ist, und der
einzige Weg führte über die Systemeinstellungen. Wer die nicht findet, sitzt
fest — genau das ist am 2026-08-14 passiert.

**Neu:** ein Knopf „Administratorrecht abgeben" am Fuß des Sperre-Reiters, nur
sichtbar, solange das Recht aktiv ist. Er ruft `removeActiveAdmin`.

**Während einer laufenden Sperre verweigert er den Dienst.** Sonst wäre der
Umgehungsschutz eine Attrappe: man könnte im Sperrmoment das Recht abgeben und
die App löschen. Dieselbe Bedingung wie bei allen anderen Einstellungen.
