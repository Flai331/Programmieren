# Riegel — Klingelmodus in der Ruhe

Stand: 2026-09-08

## Warum

Die Ruhe kennt bis jetzt nur einen Zustand: stumm. Entweder der Anruffilter
schaltet die gewählten Nummern stumm, oder — fehlt Riegel diese Rolle — „Bitte
nicht stören" stellt alles still. Ein Zwischenschritt fehlt. Wer nachts nicht
geweckt, aber auch nicht abgeschnitten werden will, hat heute keine Wahl.

Der Wunsch: die Ruhe soll das Lautstärke-Profil des Telefons setzen können —
vibrieren statt nur stumm.

## Was dazukommt

Ein Klingelmodus je Profil, der gilt, solange die Ruhe dieses Profils greift.
Vier Stufen:

| Stufe | Wirkung |
|---|---|
| `UNVERAENDERT` | Das Telefon wird nicht angefasst. Vorgabe. |
| `LAUT` | Klingeln erzwingen, auch wenn das Telefon vorher leise stand. |
| `VIBRIEREN` | Nur vibrieren. |
| `LAUTLOS` | Ganz still. |

Der Modus steht **neben** der bestehenden Nummernauswahl, nicht an ihrer
Stelle. Der Modus gilt fürs ganze Telefon; die Nummernauswahl schaltet darüber
hinaus einzelne Anrufe ganz stumm. Beides bleibt an denselben Auslöser
gebunden: die Ruhe muss am Profil eingeschaltet sein.

## Was Android erlaubt

`AudioManager.setRingerMode` braucht den „Bitte nicht stören"-Zugriff nur dann,
wenn der Wechsel den Zustand *Lautlos* betritt oder verlässt. Das steht so in
`AudioService.wouldToggleZenMode`: geprüft wird allein, ob alter oder neuer
Modus `RINGER_MODE_SILENT` ist.

Daraus folgt:

- **Vibrieren funktioniert ohne Sonderrecht** (solange das Telefon nicht gerade
  lautlos ist).
- **Lautlos braucht den Zugriff** — immer.
- **Laut braucht ihn**, wenn das Telefon gerade lautlos ist.

Auf dem Gerät des Nutzers ist der Zugriff laut Fehlerbericht verweigert und die
Anruffilter-Rolle nicht vergeben. Die Ruhe bewirkt dort heute nichts. Vibrieren
wäre die erste Einstellung, die sofort greift — das ist ein Grund mehr für
diese Stufe.

## Aufbau

Derselbe Schnitt wie überall im Riegel: die Entscheidung ist eine reine
Rechnung, das Anfassen von Android eine dünne Schicht darüber.

### 1. Datenmodell — `Quiet.kt`, `LockCodec.kt`

```kotlin
enum class RingerMode { UNVERAENDERT, LAUT, VIBRIEREN, LAUTLOS }
```

`QuietSettings` bekommt `val ringer: RingerMode = RingerMode.UNVERAENDERT`.

Im Codec kommt Feld 19 dazu (`p.quiet.ringer.name`). `decodeProfiles` liest
Sätze mit 18 Feldern weiter und setzt dann `UNVERAENDERT`; ein unbekannter Name
fällt ebenfalls auf `UNVERAENDERT` zurück. `GUELTIGE_PROFILFELDER` wird um 19
erweitert. Bestehende Profile verhalten sich damit exakt wie bisher.

### 2. Rechnung — `QuietPlanner`

```kotlin
fun ringerMode(state: LockState, now: Long, zone: TimeZone = TimeZone.getDefault()): RingerMode
```

Geht über `quietProfiles(state, now, zone)` und wählt den Modus mit dem
höchsten Rang:

```
LAUTLOS (3)  >  VIBRIEREN (2)  >  LAUT (1)  >  UNVERAENDERT (0)
```

Der leiseste gewinnt — dieselbe Doktrin wie bei `silences()`: ein Profil kann
die Ruhe eines anderen nicht aufheben. `UNVERAENDERT` steht bewusst ganz unten,
damit „egal" jeder ausdrücklichen Wahl weicht. Greift keine Ruhe, ist das
Ergebnis `UNVERAENDERT`.

Die Funktion bleibt rein und ohne Android, also per JUnit prüfbar.

### 3. Android-Schicht — `QuietRinger.kt` (neu)

Gebaut wie `QuietDnd`: eine Klasse, ein `apply`, der vorherige Zustand in den
SharedPreferences.

```kotlin
class QuietRinger(context: Context) {
    fun apply(mode: RingerMode)
}
```

- Beim ersten Setzen eines echten Modus wird der aktuelle Klingelmodus unter
  `ringerVorher` gemerkt. Das Vorhandensein des Schlüssels heißt: Riegel hat
  den Modus gesetzt.
- Bei `UNVERAENDERT` wird der gemerkte Wert wiederhergestellt und der Schlüssel
  geräumt. Ist kein Schlüssel da, passiert nichts.
- Mehrfaches Aufrufen mit demselben Modus ändert nichts.
- `LAUTLOS` ohne DND-Zugriff fällt auf `VIBRIEREN` zurück, statt gar nichts zu
  tun. Halbe Ruhe ist besser als keine, und die Oberfläche sagt es an.
- Jeder `setRingerMode`-Aufruf steht in `runCatching`: das System wirft
  `SecurityException`, wenn der Wechsel Lautlos berührt und der Zugriff fehlt.
  Ein Fehlschlag darf die übrige Wirkung nicht abbrechen.

Aufgerufen in `LockController.applyEffects`, direkt neben `QuietDnd`:

```kotlin
QuietRinger(context).apply(QuietPlanner.ringerMode(state, now))
```

Ein eigener Wecker ist nicht nötig. `QuietPlanner.nextBoundary` deckt schon
jeden Zeitpunkt ab, an dem sich die Ruhelage ändert, und `applyEffects` läuft
an genau diesen Grenzen.

### 4. Kanal und Oberfläche

`ProfileInfo` bekommt `quietRinger`, der Kanal den Schlüssel `quietRinger` in
beide Richtungen (`getState` und `saveProfile`).

In `profile_screen.dart` unter dem Abschnitt RUHE, sichtbar nur bei
eingeschalteter Ruhe: ein Auswahlfeld „Klingelmodus während der Ruhe" mit den
vier Stufen. Vier Beschriftungen sind für einen `SegmentedButton` zu breit —
also ein `DropdownButtonFormField`.

Ist `LAUTLOS` gewählt und `dndGranted()` falsch, steht darunter: „Ohne ‚Bitte
nicht stören' bleibt es beim Vibrieren." Dazu der schon vorhandene Knopf
„‚Bitte nicht stören' erlauben" — er wird aus dem Anruffilter-Block
herausgezogen, damit er auch ohne die Nummernauswahl erscheint.

### 5. Diagnose — `Diagnostics.kt`

Eine Zeile „Klingelmodus: ist=…, soll=…". Der Ist-Wert kommt aus
`AudioManager.getRingerMode`, der Soll-Wert aus `QuietPlanner.ringerMode`.
Weicht beides ab, fehlt ein Recht — genau der Fall aus dem Fehlerbericht wäre
damit auf einen Blick sichtbar.

## Bewusst hingenommen

- **Handbetrieb während der Ruhe.** Dreht der Nutzer selbst am Klingelmodus,
  wird am Ende trotzdem der gemerkte Wert wiederhergestellt. `QuietDnd` macht
  das heute schon so; zwei verschiedene Regeln für dieselbe Sache wären
  schlimmer als eine unvollkommene.
- **Kein Vibrieren je Nummer.** Der Anruffilter kann einen Anruf nur
  stummschalten oder durchlassen. Ein Modus je Nummer ist technisch nicht
  möglich und steht deshalb nicht zur Wahl.
- **Der Modus wirkt auch auf Benachrichtigungen**, nicht nur auf Anrufe. Das
  ist die Natur des Klingelmodus und der Grund, warum `UNVERAENDERT` die
  Vorgabe bleibt.

## Nachweise

JUnit (`QuietPlannerRingerTest`):

- Ein Profil mit `VIBRIEREN` in Ruhe → `VIBRIEREN`.
- Zwei Profile in Ruhe, `LAUT` und `LAUTLOS` → `LAUTLOS`.
- Zwei Profile in Ruhe, `UNVERAENDERT` und `LAUT` → `LAUT`.
- Profil mit `LAUTLOS`, aber Ruhe greift gerade nicht → `UNVERAENDERT`.
- Profil mit `quiet.enabled == false` zählt nicht mit.
- Gar kein Profil in Ruhe → `UNVERAENDERT`.

JUnit (`LockCodecTest`):

- Rundlauf mit gesetztem `ringer`.
- Ein Satz mit 18 Feldern liest sich als `UNVERAENDERT`.
- Ein unbekannter Name liest sich als `UNVERAENDERT`.

Flutter (`profile_screen_test.dart`):

- Das Auswahlfeld erscheint nur bei eingeschalteter Ruhe.
- Der gewählte Modus geht beim Speichern über den Kanal mit.

Gerätetest (`GERAETETEST.md`, neuer Abschnitt): Vibrieren greift ohne DND-Recht;
Lautlos ohne Recht fällt auf Vibrieren zurück und die Oberfläche sagt es;
nach dem Ende der Ruhe steht der vorherige Modus wieder da.
