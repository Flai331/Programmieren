# Riegel v2 — Profile, mehrere Chips, Sperre bis Zeitpunkt

Datum: 2026-08-04
Projekt: `Programmieren\nfc_riegel`
Baut auf: `2026-08-03-nfc-riegel-design.md`

## Zweck

Drei Erweiterungen der bestehenden App:

1. **Mehrere NFC-Chips** — gleichwertige Ersatzschlüssel, jeder einem Profil zugeordnet
2. **Profile** — mehrere App-Listen mit eigenen Einstellungen statt einer einzigen
3. **Sperre bis Zeitpunkt** — dritter Modus neben „bis Scan" und „auf Zeit"

Die Kalendereinbindung ist bewusst **nicht** Teil dieser Spec. Sie steht in
`2026-08-04-riegel-kalender-design.md` und setzt diese hier voraus.

> **Teilweise abgelöst am 2026-08-05.** Die Abschnitte „Sperr-Modi",
> „Scan-Verhalten" und „Einstellungssperre" beschreiben den umgesetzten Stand von
> v2, nicht mehr den angestrebten. `TIMER` und `UNTIL` waren dort Endebedingungen
> einer Chipsperre und ließen sich durch erneuten Scan abkürzen; sie sind jetzt
> eigenständige Zeitsperren. Maßgeblich ist
> `2026-08-05-riegel-zeitsperren-design.md`. Datenmodell, Migration und Oberfläche
> aus dieser Spec gelten unverändert weiter.

## Datenmodell

### Profil

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | String | Erzeugt beim Anlegen, unveränderlich |
| `name` | String | „Arbeit", „Nacht" |
| `blockedPackages` | Set\<String\> | App-Liste dieses Profils |
| `defaultMode` | `OPEN` \| `TIMER` \| `UNTIL` | Vorgabe beim Chip-Scan |
| `durationMinutes` | Int | Für `TIMER` |
| `untilAt` | Long? | Für `UNTIL`, absoluter Zeitstempel |
| `pinCalendarEnd` | Boolean | Nur für die Kalender-Spec relevant; hier mitgeführt, damit das Modell später nicht wandert |

Mindestens ein Profil existiert immer. Das letzte lässt sich nicht löschen.

### Chip

| Feld | Typ | Bedeutung |
|---|---|---|
| `uid` | String | Tag-UID in Hex |
| `label` | String | „Schreibtisch", „Schlüsselbund" |
| `profileId` | String | Welches Profil dieser Chip schaltet |
| `isMaster` | Boolean | Generalschlüssel: beendet jede laufende Sperre |

Jeder Chip hat ein Profil, auch ein Generalschlüssel — er braucht eines, um selbst
sperren zu können.

### Chipsperre

Höchstens eine gleichzeitig, gespeichert.

| Feld | Typ | Bedeutung |
|---|---|---|
| `profileId` | String | Welches Profil gerade sperrt |
| `mode` | `OPEN` \| `TIMER` \| `UNTIL` | Beim Sperren aus dem Profil übernommen |
| `endsAt` | Long? | Bei `TIMER` und `UNTIL` gesetzt, bei `OPEN` null |

### Global

`codeHash`, `failedAttempts`, `codeLockedUntil` bleiben wie in v1.

## Sperr-Modi

| Modus | Ende |
|---|---|
| `OPEN` | Erneuter Scan |
| `TIMER` | Nach `durationMinutes`, erneuter Scan beendet vorzeitig |
| `UNTIL` | Zum Zeitpunkt `untilAt`, erneuter Scan beendet vorzeitig |

`UNTIL` verhält sich wie `TIMER`, nur mit absolutem statt relativem Ende. Bewusst
kein harter Modus: der Scan greift, damit es nichts Neues zu lernen gibt.

Liegt `untilAt` beim Sperren bereits in der Vergangenheit, wird nicht gesperrt und
der Hauptscreen meldet „Zeitpunkt liegt in der Vergangenheit".

## Scan-Verhalten

```
Unbekannte UID              → nichts passiert
Generalschlüssel, Sperre läuft → alle Sperren enden (auch Kalendersperren)
Generalschlüssel, nichts läuft → sperrt mit seinem eigenen Profil
Normaler Chip, keine Chipsperre → sperrt mit seinem Profil
Normaler Chip, gleiche Profil-Sperre läuft → gibt frei
Normaler Chip, andere Profil-Sperre läuft → übernimmt: alte endet, neue beginnt
```

Zur Übernahme: ein versehentlicher Scan eines anderen Chips gibt damit die gerade
gesperrten Apps frei, sofern sie nicht auch im neuen Profil stehen. Bewusst so
entschieden — die Alternative wäre Stapeln gewesen.

Ein normaler Chip lässt Kalendersperren unberührt. Nur der Generalschlüssel und der
Notfall-Code kommen an sie heran.

## Was gesperrt ist

Vereinigung aller aktiven Sperren. Ein Paket wird geblockt, sobald *irgendeine*
aktive Sperre es enthält.

In dieser Spec gibt es nur die Chipsperre; die Vereinigung ist trotzdem schon so
gebaut, damit die Kalender-Spec nichts umbauen muss.

## Einstellungssperre

v1 sperrte *alle* Einstellungen, sobald *irgendetwas* lief. Jetzt feiner:

- Ein Profil ist bearbeitbar, solange keine aktive Sperre dieses Profil nutzt
- Profil „Nacht" bleibt also änderbar, während „Arbeit" sperrt
- Chips anlernen und löschen ist gesperrt, solange irgendeine Sperre läuft
- Der Notfall-Code lässt sich nur neu erzeugen, wenn nichts läuft

## Oberfläche

**Hauptscreen**
- Statuskachel zeigt bei aktiver Sperre den Profilnamen
- Profil-Auswahl entfällt: gesperrt wird über den Chip, nicht über den Bildschirm
- Liste der Profile, jedes mit Name, Anzahl Apps, Modus; Antippen öffnet die Bearbeitung
- Gesperrte Profile sind ausgegraut

**Profil bearbeiten**
- Name, App-Liste, Modus mit Dauer bzw. Zeitpunkt-Auswahl, `pinCalendarEnd`
- Bei `UNTIL`: Datums- und Uhrzeitwahl über die Standard-Dialoge

**Chips**
- Liste aller angelernten Chips: Label, zugeordnetes Profil, Markierung als Generalschlüssel
- Anlernen ergänzt die Liste statt zu ersetzen
- Löschen einzelner Chips möglich, solange nichts läuft
- Beim Anlernen: Label eingeben, Profil wählen, Generalschlüssel ja/nein

**Sperrschirm**
- Zeigt zusätzlich, welches Profil sperrt

## Migration

Bestehende Installationen haben genau ein Profil und höchstens einen Chip. Beim
ersten Start nach dem Update:

- Aus `blockedPackages`, `mode`, `durationMinutes` entsteht ein Profil namens
  „Standard"
- Aus `tagUid` entsteht ein Chip mit Label „Chip 1", diesem Profil zugeordnet,
  `isMaster = true` — sonst käme man an eine spätere Kalendersperre nicht heran
- Eine laufende Sperre wird als Chipsperre dieses Profils übernommen

Die Migration läuft einmalig in `SharedPrefsLockStore` beim Lesen eines Zustands
ohne Profilliste.

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| Letztes Profil löschen | Nicht möglich, Schaltfläche deaktiviert |
| Profil löschen, dem Chips zugeordnet sind | Nachfrage; danach zeigen diese Chips auf das erste verbleibende Profil |
| Profil löschen, das gerade sperrt | Nicht möglich, es ist ohnehin gesperrt |
| Chip anlernen, dessen UID schon bekannt ist | Bestehender Eintrag wird aktualisiert statt doppelt angelegt |
| Alle Chips gelöscht | Warnung im Hauptscreen: nur noch der Notfall-Code öffnet |
| `UNTIL` mit Zeitpunkt in der Vergangenheit | Sperre startet nicht, Meldung |
| Neustart während Sperre | Wie v1: Zustand wiederherstellen, Alarm neu setzen |

## Tests

**Kotlin, JUnit** — neue und erweiterte Fälle in `LockEngine`:

- Scan mit unbekannter UID bei mehreren angelernten Chips
- Normaler Chip sperrt, gleicher Chip gibt frei
- Normaler Chip übernimmt von anderem Profil
- Generalschlüssel beendet laufende Sperre
- Generalschlüssel sperrt, wenn nichts läuft
- `UNTIL`: Ablauf, vorzeitiger Scan, Zeitpunkt in der Vergangenheit
- Vereinigung der Blocklisten bei aktiver Sperre
- Einstellungssperre je Profil: gesperrtes Profil abgelehnt, anderes erlaubt
- Migration: v1-Zustand ergibt ein Profil und einen Generalschlüssel-Chip

**Flutter, widget test** — Profilliste, Chipliste, Statuskachel mit Profilnamen.

**Von Hand** — Ergänzung der bestehenden `GERAETETEST.md` um: zweiten Chip anlernen,
Profilwechsel per Scan, Generalschlüssel, `UNTIL` über Nacht.

**Verifikation:** `flutter analyze`, `flutter test`,
`android\gradlew.bat -p android testDebugUnitTest`

## Bewusst nicht enthalten

- Kalendereinbindung — eigene Spec
- Stapeln mehrerer gleichzeitiger Chipsperren — verworfen zugunsten der Übernahme
- Profile mit Zeitplänen ohne Kalender
- iOS
