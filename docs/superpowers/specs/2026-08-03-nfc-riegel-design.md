# NFC-Riegel — Design

Datum: 2026-08-03
Projektordner: `Programmieren\nfc_riegel`
App-Label: „Riegel"
Plattform: Android (Flutter + Kotlin)

## Zweck

Ein physischer NFC-Chip sperrt und entsperrt eine voreingestellte Liste von Apps.
Chip ans entsperrte Handy halten: Apps gesperrt. Nochmal halten: wieder frei.
Prinzip wie beim Gerät „Brick" — die Hürde ist der Griff zum Chip, nicht eine
Systemsperre.

Ziel ist **Reibung für die Selbstdisziplin**, nicht Unumgehbarkeit. Wer die Sperre
loswerden will, schafft das; es soll nur nicht nebenbei im Reflex passieren.

## Umfang v1

Enthalten:

- Ein Sperr-Profil: eine App-Liste, eine Modus-Einstellung
- Zwei Sperr-Modi, vor dem Sperren wählbar
- Genau ein angelernter Chip
- Notfall-Code als Hintertür
- Deinstallationsschutz per Device Admin

Bewusst nicht enthalten (spätere Ausbaustufen):

- Mehrere Profile mit je eigenem Chip — Datenmodell hält den Platz frei, UI nicht
- iOS — Hintergrund-App-Blocking ist dort systemseitig nicht möglich
- Statistiken, Nutzungszeiten, Auswertungen

## Sperr-Modi

**Modus A — offen:** Sperre gilt, bis der Chip erneut gescannt wird. Kein Zeitlimit.
Übersteht Neustarts.

**Modus B — Timer:** Sperre gilt bis zum Ablauf der eingestellten Dauer. Ein erneuter
Scan beendet sie auch vorzeitig. Es gilt, was zuerst eintritt.

Der Modus wird im Hauptscreen eingestellt und beim Sperren übernommen. Ein Wechsel
während einer laufenden Sperre ist nicht vorgesehen.

## Architektur

Flutter macht die Oberfläche, Kotlin die Arbeit.

Der Accessibility-Service läuft ohne Flutter-Engine. Deshalb liegt der Sperrzustand
**nativ** in `SharedPreferences`; Flutter liest und schreibt ausschließlich über einen
MethodChannel. Der Zustand wird nirgends doppelt gehalten.

### Kotlin-Komponenten

| Komponente | Aufgabe | Hängt ab von |
|---|---|---|
| `LockState` | Persistenter Zustand. Einzige Stelle, die Zustand ändert. | SharedPreferences |
| `BlockerService` | AccessibilityService: Fenster-Event → Paket gegen Blockliste → `BlockActivity` | `LockState` |
| `BlockActivity` | Vollbild „Gesperrt": Restzeit, Hinweis „Chip scannen", Button Notfall-Code | `LockState` |
| `NfcToggleActivity` | Empfängt NDEF-Intent vom Chip, prüft UID, togglet, zeigt 1,5 s Status, schließt | `LockState`, `LockScheduler` |
| `TagWriter` | Einmalig beim Einrichten: Chip mit AAR beschreiben, UID merken | `LockState` |
| `LockScheduler` | AlarmManager für Timer-Ablauf, `BootReceiver` zum Wiederherstellen | `LockState` |
| `UninstallAdmin` | DeviceAdminReceiver gegen Deinstallation — übernommen aus `wecker_schutz` | — |
| `RiegelChannel` | MethodChannel-Brücke Flutter ↔ nativ | `LockState` |

`LockState` kennt keine der anderen Komponenten. Alle greifen darüber zu, niemand
hält eine eigene Kopie. Damit ist die gesamte Sperrlogik ohne Emulator testbar.

### LockState — Felder

| Feld | Typ | Bedeutung |
|---|---|---|
| `locked` | bool | Sperre aktiv? |
| `mode` | enum `open` \| `timer` | Modus der laufenden bzw. nächsten Sperre |
| `endsAt` | Zeitstempel (ms, Wall Clock) \| null | Ende der Sperre; nur bei `mode == timer` gesetzt |
| `durationMinutes` | int | Eingestellte Dauer für Modus B |
| `blockedPackages` | Set\<String\> | Paketnamen der gesperrten Apps |
| `tagUid` | String \| null | UID des angelernten Chips (Hex) |
| `codeHash` | String \| null | Hash des Notfall-Codes |

### Flutter-Screens

**Setup-Wizard** — einmalig, Schritt für Schritt:

1. Berechtigungen: Accessibility, Device Admin, Benachrichtigungen, Exact Alarm
2. Apps wählen (`installed_apps`)
3. Chip anlernen (`TagWriter` beschreibt den Tag, UID wird gespeichert)
4. Notfall-Code anzeigen — einmalig im Klartext, mit Hinweis zum Aufschreiben

**Hauptscreen:** Status (frei / gesperrt seit / Restzeit), Modus-Auswahl mit Dauer,
Blockliste bearbeiten, Warnbanner wenn der Accessibility-Dienst aus ist.

## Zustandsmaschine

```
FREI      --Scan (UID passt)-------->  GESPERRT
GESPERRT  --Scan (UID passt)-------->  FREI
GESPERRT  --Timer abgelaufen------->  FREI        (nur Modus B)
GESPERRT  --Notfall-Code korrekt--->  FREI
```

Andere Übergänge gibt es nicht. Ein Scan mit fremder UID ändert nichts.

## Datenfluss beim Scan

1. Chip ans **entsperrte** Handy. Android liest den NDEF-Inhalt, findet den Android
   Application Record und startet `NfcToggleActivity` mit `NDEF_DISCOVERED`.
2. Die Activity liest die Tag-UID aus dem Intent und vergleicht sie mit `tagUid`.
   Kein Treffer → Meldung „Fremder Chip", Zustand unverändert.
3. Treffer → `LockState` togglet:
   - **Sperren:** Modus und Dauer aus den Einstellungen übernehmen. Bei Modus B
     `endsAt` setzen und Exact Alarm scharfmachen. Dauerbenachrichtigung „Sperre
     aktiv" anzeigen. Einmalig `GLOBAL_ACTION_HOME`, falls gerade eine gesperrte App
     offen ist.
   - **Freigeben:** Alarm abbestellen, Benachrichtigung entfernen.
4. Die Activity zeigt 1,5 s das Ergebnis und schließt sich.

Der `BlockerService` wird dabei **nicht** benachrichtigt. Er liest bei jedem
Fenster-Event `LockState`. Damit kann kein Zustand zwischen Service und Activity
auseinanderlaufen.

Die Dauerbenachrichtigung ist eine gewöhnliche `ongoing`-Notification, kein
Foreground Service — den Accessibility-Service hält das System selbst am Leben.

Android liefert NFC-Tags nicht vom Sperrbildschirm aus — das Handy muss zum Scannen
entsperrt sein. Systemverhalten, nicht änderbar.

## Timer und Neustart

Die **Uhrzeit ist die Wahrheit**, nicht der Alarm.

- Alarm feuert → `LockState.locked = false`
- Boot während laufender Sperre → `BootReceiver` vergleicht `endsAt` mit der
  aktuellen Zeit: bereits vorbei → sofort freigeben; sonst Alarm neu setzen
- Modus A hat kein `endsAt` und bleibt nach dem Boot einfach gesperrt

## Notfall-Code

Beim Einrichten wird ein 8-stelliger Code erzeugt und **genau einmal** im Klartext
angezeigt. Gespeichert wird nur `codeHash`.

Eingabe erfolgt im `BlockActivity`. Nach 3 Fehlversuchen ist die Eingabe 60 s
gesperrt.

Der Code ist die Absicherung gegen echtes Aussperren: Chip verloren, kaputt oder zu
Hause liegen gelassen.

## Umgehungsschutz

Während einer Sperre blockt der Service **nicht die ganze Einstellungen-App** — sonst
wären WLAN und Lautstärke unerreichbar. Er erkennt gezielt die **Accessibility- und
Device-Admin-Seiten** über Paketname plus Klassenname des Fensters und wirft dort
zurück. Der Rest der Einstellungen bleibt nutzbar.

Der Device Admin verhindert die Deinstallation der App.

Es bleiben als Auswege: Notfall-Code oder Safe Mode booten. Beides bewusst
umständlich. Das ist die beabsichtigte Obergrenze des Schutzes.

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| Accessibility-Dienst deaktiviert | Beim App-Start erkannt, Warnbanner „Sperre nicht wirksam"; Dauerbenachrichtigung zeigt es ebenfalls |
| Neustart während Sperre | `BootReceiver` stellt Zustand her, setzt Alarm neu |
| Timer während Ausschaltzeit abgelaufen | Beim Boot `endsAt` gegen Uhrzeit → sofort freigeben |
| Chip unlesbar oder fremd | Kurze Meldung, Zustand unverändert |
| Gesperrte App war beim Sperren offen | Nächstes Fenster-Event greift; zusätzlich einmalig `GLOBAL_ACTION_HOME` |
| App aus Blockliste deinstalliert | Paketname bleibt in der Liste, läuft ins Leere — kein Fehler |
| Notfall-Code 3× falsch | 60 s Eingabesperre |
| Chip beim Anlernen nicht beschreibbar | Setup-Schritt schlägt fehl mit Hinweis auf beschreibbaren Tag (z. B. NTAG21x) |

## Tests

**Kotlin, JUnit** — die Logik, die kaputtgehen kann, läuft ohne Emulator:

- `LockState`: alle vier Übergänge der Zustandsmaschine
- `LockScheduler`: Timer-Rechnung, Boot-Wiederherstellung mit abgelaufenem und
  laufendem `endsAt`
- UID-Vergleich: Treffer, Nichttreffer, kein Chip angelernt
- Notfall-Code: Hash-Prüfung, Fehlversuchszähler

**Flutter, widget test:**

- Setup-Wizard: Schrittabfolge
- Hauptscreen: Statusanzeige gegen einen gefälschten MethodChannel

**Von Hand** — alles mit echtem NFC oder echten Fenster-Events:

- [ ] Chip beschreiben, UID wird gespeichert
- [ ] Scan sperrt, zweiter Scan gibt frei
- [ ] Modus B: Timer läuft ab, Sperre endet
- [ ] Modus B: zweiter Scan beendet vorzeitig
- [ ] Gesperrte App öffnen → Blockscreen
- [ ] Nicht gesperrte App öffnen → normal nutzbar
- [ ] Während Sperre Accessibility-Einstellungen öffnen → Rauswurf
- [ ] Neustart während Sperre → Sperre besteht weiter
- [ ] Fremden NFC-Tag scannen → keine Wirkung
- [ ] Notfall-Code eingeben → Sperre endet

**Verifikation:** `flutter analyze`, `flutter test`, `gradlew testDebugUnitTest`

## Vorlagen aus dem Bestand

`Programmieren\wecker_schutz` enthält bereits einsetzbare Muster:

- `UninstallBlockerService.kt` — AccessibilityService-Grundgerüst
- `UninstallProtectionAdmin.kt` + `res/xml/device_admin.xml` — Device Admin
- `BootReceiver.kt` — Wiederherstellung nach Neustart
- Manifest-Einträge für `QUERY_ALL_PACKAGES`, Foreground Service, Exact Alarm
- `installed_apps` und `permission_handler` als Abhängigkeiten

## Build-Ablage

Fertige APK nach `C:\Users\klaas\Desktop\Programmieren\APKs\Android` (siehe
`Programmieren\CLAUDE.md`).
