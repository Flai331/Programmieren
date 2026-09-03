# Freigabe auf Zeit — Design

**Stand:** 2026-09-03
**Projekt:** NFC-Riegel (`nfc_riegel`), Branch `feature/nfc-riegel`
**Quelle:** Wunsch vom 2026-09-03 — „wenn die Sperre aktiv ist und ich die
wieder entsperren will, dann soll gefragt werden für wie lange"

## Wozu

Die Chipsperre kennt heute nur ganz auf oder ganz zu. Wer während einer Sperre
kurz an eine gesperrte App muss — eine Nachricht nachsehen, eine Adresse
heraussuchen —, hat nur einen Weg: den Chip auflegen. Danach ist der Riegel
offen und bleibt es. Der zweite Griff zum Chip, der wieder zusperrt, fällt in
genau dem Moment aus, in dem man ihn bräuchte: man ist schon drin.

Die Freigabe auf Zeit schließt diese Lücke. Der Chip öffnet nur für eine
gewählte Spanne, danach sperrt dasselbe Profil von selbst wieder. Die
Entscheidung „ich mache jetzt kurz auf" trägt ihr Ende schon in sich.

## Umfang

**Enthalten:** ein Schalter je Profil; ein Dialog beim Aufsperren mit vier
Stufen und freier Eingabe; ein Zustand, der die Chipsperre auf Zeit schlafen
legt; Wiederzusperren durch Ablauf oder erneuten Scan.

**Bewusst nicht enthalten:**

- **Keine Freigabe für Zeitsperren und Kalendertermine.** Sie enden vorzeitig
  nur durch Generalschlüssel oder Notfall-Code. Eine Freigabe dort wäre eine
  Hintertür um genau das Prinzip herum, das die Zeitsperre ausmacht.
- **Kein Verlängern.** Ein zweiter Scan während der Freigabe sperrt zu, statt
  Zeit draufzulegen. Verlängern ließe sich beliebig oft wiederholen, und damit
  wäre die Sperre eine Bitte.
- **Keine Warnung kurz vor Schluss.** Die laufende Benachrichtigung nennt die
  Uhrzeit; ein zweiter Wecker samt Hinweis wäre eine Unterbrechung mehr.
- **Kein Zählen der Freigaben**, keine Statistik, keine Obergrenze pro Tag.

## Verhalten

### Der Weg

Du bist gesperrt, Profil „Arbeit", Schalter „Freigabe auf Zeit" ist an. Chip
auflegen: ein schmaler Schirm kommt hoch — „Wie lange offen?", darunter
**5**, **10**, **15**, **30** Minuten, ein Feld für eine eigene Zahl, dann
**Öffnen** und **Abbrechen**.

Nach dem Tippen sind die Apps frei. Die Benachrichtigung sagt „Frei bis 14:35 —
danach wieder zu". Um 14:35 sperrt das Profil von selbst; es braucht keinen
Scan. Wer früher fertig ist, legt den Chip auf und ist sofort wieder zu.

### Alle Lagen

| Lage | Chip aufgelegt | Ergebnis |
|---|---|---|
| offen, keine Sperre | Scan | sperrt wie bisher |
| gesperrt, Schalter aus | Scan | öffnet dauerhaft wie bisher |
| gesperrt, Schalter an | Scan | Dialog, danach Freigabe |
| Dialog abgebrochen | — | bleibt zu, kurze Meldung |
| Freigabe läuft | Scan | sofort wieder zu |
| Freigabe abgelaufen | — | sperrt von selbst |
| Freigabe läuft, Generalschlüssel | Scan | alles auf, Freigabe fällt weg |
| Freigabe läuft, Notfall-Code | Code | alles auf, Freigabe fällt weg |
| Neustart während der Freigabe | — | Freigabe läuft bis zu ihrem Ende weiter |

### Grenzen der Wirkung

Die Freigabe wirkt allein auf die Chipsperre. Läuft daneben eine Zeitsperre
desselben Profils oder sperrt gerade ein Kalendertermin, bleibt gesperrt — die
Freigabe öffnet dann nichts. Das ist kein Sonderfall im Code, sondern fällt aus
der Stelle heraus, an der sie überhaupt wirkt (siehe unten).

Die Dauer wird auf **1 bis 240 Minuten** geklemmt. Alles darüber ist keine
kurze Freigabe mehr, sondern ein offener Riegel — dafür gibt es den Schalter
zum Ausschalten.

## Aufbau

### Modell

In [`Profile.kt`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/Profile.kt):

```kotlin
data class Profile(
    …
    /** Der Chip öffnet nur auf Zeit; danach sperrt dasselbe Profil wieder. */
    val timedRelease: Boolean = false,
)

/**
 * Eine laufende Freigabe. Hebt die Chipsperre nicht auf, sondern legt sie bis
 * [endsAt] schlafen — danach sperrt sie ohne Zutun weiter.
 */
data class Release(val profileId: String, val endsAt: Long)
```

In `LockState`: `val release: Release? = null`. Höchstens eine, weil es
höchstens eine Chipsperre gibt.

**Warum schlafen legen statt löschen:** Würde der Scan die Chipsperre löschen
und ein neuer Zustand das spätere Zusperren merken, müsste dieser Zustand
Profil, Ende und Grund mitführen — und beim Ablauf eine Sperre neu aufbauen,
die es vorher schon gab. Bleibt der `chipLock` stehen, ist der Ablauf ein
Wegfallen: das Feld `release` verschwindet, und alles sperrt wieder wie vorher.

### Logik

Alles in [`LockEngine`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockEngine.kt),
rein und ohne Android:

- **`lockedProfileIds`** — die einzige Stelle, an der die Freigabe wirkt: der
  `chipLock` zählt nicht, solange eine Freigabe für sein Profil läuft.
  `isBlocked`, Benachrichtigung, Sperrschirm und Statuskachel hängen alle daran
  und brauchen deshalb keine eigene Sonderbehandlung.
- **`onTagScanned`**, Profil im Modus `OPEN` mit laufender eigener Chipsperre,
  drei Fälle in dieser Reihenfolge:
  1. Freigabe läuft → `release = null`, Ergebnis `RELOCKED`.
  2. `profile.timedRelease` → Zustand unverändert, Ergebnis `ASK_RELEASE`.
  3. sonst → wie bisher `UNLOCKED`.
- **`startRelease(profileId, minutes, now)`** — setzt `release` auf
  `now + minutes * 60_000`, geklemmt auf 1…240 Minuten. Ohne laufende
  Chipsperre dieses Profils passiert nichts (`NO_LOCK`).
- **`onTimerElapsed`** — eine Freigabe mit `endsAt <= now` fällt weg. Damit
  sperrt der `chipLock` wieder; `restoreAfterBoot` ruft denselben Weg und trägt
  die Freigabe deshalb über einen Neustart.
- **`clearAll`** (Generalschlüssel, Notfall-Code) — räumt `release` mit weg.

Die Engine fragt nicht, sie meldet nur, dass zu fragen ist. `ASK_RELEASE` ist
ein Ergebniswert wie jeder andere; wer ihn beantwortet, ist Sache der
Oberfläche. So bleibt die Logik ohne Android prüfbar.

### Android

- [`LockController.naechsterWecker`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockController.kt)
  bekommt `release.endsAt` als weitere Grenze. Wecker, `TimerReceiver` und
  `expire` bleiben, wie sie sind.
- [`LockNotification`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/LockNotification.kt):
  läuft eine Freigabe, lautet der Text „Frei bis HH:MM — danach wieder zu".
- Neue **`ReleaseActivity`**, gebaut wie
  [`PauseActivity`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/PauseActivity.kt)
  aus Kotlin-Views mit `BlockColors`: Titel, vier Stufenknöpfe, Zahlenfeld,
  „Öffnen", „Abbrechen". Kein Flutter im Scanweg — `NfcToggleActivity` startet
  heute ohne Engine in Millisekunden, und das soll so bleiben.
- [`NfcToggleActivity`](../../../nfc_riegel/android/app/src/main/kotlin/com/klaas/nfc_riegel/NfcToggleActivity.kt)
  startet bei `ASK_RELEASE` die `ReleaseActivity` mit Profil-ID und -Name;
  sonst bleibt es beim Toast. Die Activity ruft `LockController.startRelease`.
- Speicher: `LockCodec` bekommt `encodeRelease`/`decodeRelease`,
  `SharedPrefsLockStore` einen Schlüssel `release`. Fehlt er, gibt es keine
  Freigabe — alte Stände lesen sich unverändert.

### Flutter

- [`profile_screen.dart`](../../../nfc_riegel/lib/profile_screen.dart):
  Schalter „Freigabe auf Zeit", nur im Modus „Offen" sichtbar. Untertitel:
  „Der Chip öffnet nur für eine gewählte Zeit. Danach sperrt es von selbst
  wieder."
- [`lock_status.dart`](../../../nfc_riegel/lib/lock_status.dart):
  `ProfileInfo.timedRelease` und `StatusInfo.releaseEndsAt` über den
  bestehenden MethodChannel.
- [`home_screen.dart`](../../../nfc_riegel/lib/home_screen.dart): die
  Statuskachel zeigt bei laufender Freigabe „Frei bis HH:MM".

## Prüfen

**`LockEngineTest`** (JUnit, ohne Emulator):

- Scan bei eingeschaltetem Schalter lässt den Zustand unverändert und meldet
  `ASK_RELEASE`.
- `startRelease` öffnet: `isBlocked` ist während der Freigabe falsch, nach dem
  Ende wahr — geprüft über durchgereichte `now`-Werte, ohne zu warten.
- Scan während der Freigabe sperrt sofort (`RELOCKED`).
- Generalschlüssel und Notfall-Code räumen Chipsperre und Freigabe zusammen.
- `startRelease` ohne laufende Chipsperre des Profils ändert nichts.
- Zeitsperre und Kalendertermin desselben Profils sperren trotz Freigabe.
- `restoreAfterBoot` behält eine laufende Freigabe, verwirft eine abgelaufene.
- Minuten unter 1 und über 240 werden geklemmt.

**`LockCodecTest`**: Freigabe schreiben und lesen ergibt dasselbe; ein Stand
ohne den neuen Schlüssel liest sich als „keine Freigabe".

**Flutter-Widgettests**: der Schalter erscheint nur im Modus „Offen" und landet
im Kanalaufruf; die Statuskachel zeigt bei gesetztem `releaseEndsAt` „Frei bis".

**Gerätetest**, ergänzt in [`GERAETETEST.md`](../../../nfc_riegel/GERAETETEST.md)
— der Emulator hat kein NFC, der Weg ist nur am Gerät prüfbar: Dialog kommt
beim Scannen; 5 Minuten wählen öffnet und zeigt „Frei bis"; Ablauf sperrt auch
bei ausgeschaltetem Bildschirm; Scan während der Freigabe sperrt sofort;
Abbrechen lässt zu.

## Entschiedene Grenzfälle

- **Profil während der Freigabe umgestellt:** die laufende Freigabe endet
  trotzdem zu ihrer Zeit. Einstellungen bauen keine laufenden Sperren um.
- **Schalter während der Freigabe ausgeschaltet:** ändert nichts an der
  laufenden, gilt ab dem nächsten Aufsperren.
- **Zwei Profile:** die Freigabe gilt für das Profil der Chipsperre; Sperren
  anderer Profile bleiben.
- **Wecker vom System verschluckt** (Doze, aggressiver Hersteller): beim
  nächsten Ereignis — App-Start, Scan, Kalenderlauf — rechnet `onTimerElapsed`
  die Lage neu. Die Freigabe endet dann verspätet, nie unbemerkt dauerhaft.
- **Uhr zurückgestellt:** die Freigabe endet später als gedacht, weil `endsAt`
  ein absoluter Zeitpunkt ist. Bewusst hingenommen — jede Sperre des Riegels
  hängt an der Systemuhr, eine eigene Zeitrechnung nur hier wäre inkonsequent.
