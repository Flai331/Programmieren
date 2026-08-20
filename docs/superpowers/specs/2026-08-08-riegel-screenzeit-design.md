# Screenzeit — Design

**Stand:** 2026-08-08
**Projekt:** NFC-Riegel (`nfc_riegel`), Branch `feature/nfc-riegel`
**Quelle:** Notion-Idee „Physischer App Blocker", 7. August 2026 —
„screentime locker auch auf dem Sperrbildschirm der App gesperrten app nutzung
von 0–24 Uhr und in einem Reiter der Riegel app"

## Wozu

Der Riegel sperrt Apps. Er sagt bisher nicht, wie lange man sie vorher benutzt
hat. Genau diese Zahl ist aber das Argument für die Sperre — wer schwarz auf
weiß sieht, dass heute zwei Stunden Instagram zusammengekommen sind, braucht
keine Ermahnung mehr.

Zwei Orte:

- **Sperrschirm:** die Tagesnutzung der App, die man gerade aufmachen wollte.
- **Eigener Reiter in der App:** alle heute benutzten Apps mit Tagessumme.

## Umfang

**Enthalten:** Tagesnutzung ab lokaler Mitternacht bis jetzt, je Paket;
Anzeige auf dem Sperrschirm für die abgefangene App; Reiter mit Liste aller
heute benutzten Apps; Abfrage der Sonderberechtigung im Reiter.

**Bewusst nicht enthalten:** Verlauf über mehrere Tage, Diagramme,
Wochenansicht, Zeitbudgets oder Warnungen bei Überschreitung, Export. Jedes
davon ist ein eigenes Vorhaben. Auch kein eigener Speicher — Android hält die
Daten vor, Riegel rechnet sie nur aus.

## Datenweg

### Warum Ereignisse und nicht Tagessummen

Android bietet zwei Wege:

`UsageStatsManager.queryUsageStats(INTERVAL_DAILY, …)` liefert fertige
Tageseimer. Deren Grenzen richten sich aber nach einer geräteeigenen
Tagesgrenze, nicht nach der lokalen Mitternacht des Nutzers. Je nach Gerät
kommt Zeit von gestern mit, oder die Werte sind gerundet. Für eine Anzeige, die
ausdrücklich „ab 0 Uhr" verspricht, ist das zu ungenau.

`UsageStatsManager.queryEvents(von, bis)` liefert die rohen Wechsel. Wer sie
selbst aufsummiert, bekommt exakt das gewünschte Fenster — und auf jedem Gerät
dasselbe Ergebnis.

**Entscheidung: Ereignisse.** Der Mehraufwand ist ein überschaubarer
Durchlauf; dafür stimmt die Zahl.

### Zuschnitt

Derselbe Schnitt wie bei der Kalenderfunktion: die Rechnung liegt in reinem
Kotlin, Android nur außen herum.

```kotlin
/** Ein Wechsel, reduziert auf das Nötige. */
data class UsageEvent(
    val packageName: String,
    val type: UsageEventType,
    val timestamp: Long,
)

enum class UsageEventType {
    /** App kommt nach vorn (ACTIVITY_RESUMED). */
    FOREGROUND,
    /** App geht nach hinten (ACTIVITY_PAUSED, ACTIVITY_STOPPED). */
    BACKGROUND,
    /** Bildschirm aus oder Sperrbildschirm an — beendet alles Offene. */
    SCREEN_OFF,
}
```

- **`ScreenTimeCalculator`** — reines Kotlin, ohne Android und ohne Speicher.
  Nimmt Ereignisse plus Fensterbeginn und -ende, gibt `Map<String, Long>`
  (Paketname → Millisekunden). Per JUnit prüfbar.
- **`UsageStatsSource`** — dünne Schicht auf `UsageStatsManager` hinter einer
  Schnittstelle, genau wie `CalendarSource`. Prüft die Berechtigung, übersetzt
  Android-Ereignisse in `UsageEvent`, verwirft alles Unbekannte.

### Die drei Ränder

Eine naive Summierung „Ende minus Start je Paar" rechnet in drei Fällen falsch:

1. **Um Mitternacht schon offen.** Die App hat im Fenster kein Startereignis,
   nur ein Ende. Ihre Zeit zählt ab Fensterbeginn — sonst fällt sie ganz weg.
2. **Jetzt gerade offen.** Kein Endeereignis. Zählt bis zum Fensterende.
3. **Bildschirm aus ohne Pausenereignis.** Auf manchen Geräten kommt beim
   Ausschalten kein `ACTIVITY_PAUSED`. Wer abends eine App offen lässt und das
   Handy weglegt, hätte sonst über Nacht acht Stunden angesammelt. Deshalb
   schließen `SCREEN_NON_INTERACTIVE` und `KEYGUARD_SHOWN` alles, was gerade
   offen ist.

Dazu die Kleinigkeit: ein zweites `FOREGROUND` für dasselbe Paket, ohne
`BACKGROUND` dazwischen, wird nicht doppelt gezählt — der erste Startzeitpunkt
gilt weiter.

**Bewusste Untertreibung:** Kommt der Bildschirm wieder an und liefert das
Gerät kein neues `ACTIVITY_RESUMED` für die App, die vorher offen war, geht
diese Zeit verloren. Das ist die gewollte Richtung des Fehlers — lieber ein
paar Minuten zu wenig als eine durchschlafene Nacht als Nutzung. Die Zahl soll
ein Argument sein, und ein Argument darf nicht übertreiben.

## Berechtigung

`PACKAGE_USAGE_STATS` ist keine gewöhnliche Laufzeitberechtigung. Sie steht im
Manifest und wird über einen eigenen Systemschirm erteilt
(`Settings.ACTION_USAGE_ACCESS_SETTINGS`) — dasselbe Muster wie die
Bedienungshilfe.

**Gefragt wird erst im Screenzeit-Reiter**, nicht im Einrichtungsassistenten.
Begründung wie beim Kalender: wer die Screenzeit nie ansieht, soll nie gefragt
werden. Eine Sperr-App, die beim ersten Start nach den Nutzungsdaten greift,
wirkt übergriffig.

Geprüft wird über `AppOpsManager.unsafeCheckOpNoThrow(OPSTR_GET_USAGE_STATS)`;
`checkSelfPermission` taugt hier nicht, weil die Berechtigung nicht über das
normale Berechtigungssystem läuft.

## Oberfläche

### Hauptschirm: zwei Reiter

Der Hauptschirm bekommt oben eine `TabBar` mit zwei Reitern:

| Reiter | Inhalt |
|---|---|
| **Sperre** | alles, was heute schon da ist: Statuskachel, Profile, Zeilen für Chips und Kalender |
| **Screenzeit** | Tagessumme und Liste |

Der erste Reiter heißt **Sperre**, nicht „Riegel": die Kopfzeile trägt bereits
den Namen der App, und dasselbe Wort direkt darunter liest sich wie ein
Versehen.

Der erste Reiter ändert sich inhaltlich nicht. Nur die Hülle wandert: aus dem
bisherigen `Scaffold`-Rumpf wird der Inhalt des ersten Reiters.

### Screenzeit-Reiter

**Ohne Berechtigung:** ein Satz und ein Knopf, der in den Systemschirm führt.
Keine leere Liste, kein Platzhalterdiagramm.

**Mit Berechtigung:**

- oben die Tagessumme — über **alle** benutzten Apps, auch die unter einer
  Minute, sonst stimmt sie nicht mit der Summe der Zeilen überein und niemand
  weiß warum
- darunter die Apps, längste zuerst, je Zeile Anzeigename und Dauer
- Apps unter einer Minute fallen aus der Liste — sonst besteht sie aus
  Zufallsberührungen
- am Fuß eine Zeile „14 weitere unter 1 Minute", damit erkennbar bleibt, dass
  nichts verschwiegen wird; bei null solchen Apps entfällt sie
- zum Aktualisieren herunterziehen, wie auf dem Hauptschirm schon üblich

Anzeigenamen kommen aus derselben nativen Quelle wie die App-Auswahl
(`MAIN`/`LAUNCHER`). Pakete ohne Startsymbol — Systemdienste, Launcher-Overlays
— tauchen nicht auf; sie sind keine „benutzten Apps" im Sinne der Frage.

**Riegel selbst fehlt in der Liste** und in der Tagessumme. Wer die Screenzeit
ansieht, erzeugt dabei Screenzeit; diese Zahl anzuzeigen wäre Rauschen. Die
Quelle für die Namen liefert Riegel ohnehin schon nicht aus (dort mit anderer
Begründung: wer ihn sperrt, kommt an keine Einstellung mehr).

**Dauerformat:** ab einer Stunde `1 h 23 min`, darunter `47 min`. Sekunden
nirgends — sie ändern sich beim Hinsehen und nützen nichts.

### Sperrschirm

Unter der bestehenden Zeile (Profilname oder Termintitel) eine weitere:

```
Heute: 1 h 23 min
```

Nur die abgefangene App, keine Liste.

**Fehlt die Berechtigung, bleibt die Zeile weg.** Der Sperrschirm ist der
falsche Ort, um etwas einzufordern — dort ist man ohnehin schon gebremst.

War die App heute noch nicht offen: `Heute noch nicht benutzt`.

Dafür muss der Sperrschirm wissen, welche App abgefangen wurde.
`BlockerService` startet `BlockActivity` bisher ohne diese Angabe; das Paket
kommt als Extra mit. Fehlt es — etwa bei einem Neustart der Activity durch das
System —, entfällt die Zeile.

## Fehlerbericht

Eine Zeile kommt dazu:

```
Nutzungsdaten: erlaubt | VERWEIGERT
```

**Die Zeiten selbst nicht.** Der Bericht landet in einer Notion-Datenbank.
Paketnamen stehen dort ohnehin schon (ohne sie ist ein Blockierfehler nicht zu
deuten), aber wie lange jemand welche App benutzt hat, gehört nicht dorthin —
dieselbe Linie wie bei Chip-Kennungen, Code-Hash und Termintiteln.

## Prüfung

### Reine Rechnung (JUnit, ohne Emulator)

- einfacher Wechsel rein/raus ergibt die Differenz
- App noch offen: zählt bis zum Fensterende
- App um Mitternacht schon offen: zählt ab Fensterbeginn
- Bildschirm aus schließt alles Offene
- zweites `FOREGROUND` ohne `BACKGROUND` zählt nicht doppelt
- `BACKGROUND` ohne vorheriges `FOREGROUND` und ohne Fensterbeginn-Fall wird
  nicht negativ
- unbekannte Ereignisarten werden übersprungen
- zwei Apps abwechselnd: beide Summen stimmen einzeln
- leere Ereignisliste ergibt eine leere Karte

### Oberfläche (Widget-Tests)

- ohne Berechtigung erscheint der Hinweis, keine Liste
- mit Daten erscheinen Tagessumme und Liste in absteigender Reihenfolge
- Apps unter einer Minute fehlen in der Liste
- die Zeile „N weitere unter 1 Minute" erscheint nur, wenn es solche gibt
- der Reiter wechselt, ohne den Riegel-Reiter zu verändern

### Am Gerät

- Berechtigung erteilen und entziehen, Reiter reagiert jeweils
- Zahlen gegen die Systemanzeige „Digital Wellbeing" gegenprüfen — kleine
  Abweichungen sind normal, große weisen auf einen Fehler in den Rändern hin
- Sperrschirm zeigt die Zeit der abgefangenen App
- über Mitternacht hinweg: die Summen fangen wieder bei null an

## Offene Kleinigkeiten

Keine. Alles oben ist entschieden.

---

## Nachtrag 2026-08-20: Hintergrundarbeit zählt mit

Gemeldet nach dem Benutzen: „es wird nicht alles getrackt, was die App macht."
Stimmt — gezählt wurde nur, was vorn stand. Eine App, die drei Stunden Musik
spielt oder navigiert, erschien mit null Minuten.

**Was Android hergibt.** Nur `FOREGROUND_SERVICE_START` und
`FOREGROUND_SERVICE_STOP`, also Dienste mit sichtbarer Benachrichtigung: Musik,
Navigation, Aufnahme, laufende Übertragungen. Stille Hintergrundarbeit —
Netzabfragen, Synchronisierung, Weckdienste — meldet das System überhaupt nicht.
Vollständigkeit ist hier also nicht zu haben; erfasst wird, was erfassbar ist.
Beide Ereignisse gibt es erst ab Android 10, auf älteren Geräten bleibt die
Hintergrundzeit null.

**Der Vordergrundanteil wird abgezogen.** Wer eine Stunde Spotify bedient, hat
dabei auch eine Stunde Dienstlaufzeit; beides zu addieren ergäbe zwei Stunden
für eine. `backgroundTotals` zieht die Vordergrundabschnitte desselben Pakets
ab. Übrig bleibt genau das, was die App tat, während man sie nicht ansah.

**Getrennt angezeigt, nicht dazugerechnet.** Die große Zahl bleibt die Zeit am
Schirm — Screenzeit ist Screenzeit. Darunter steht „+ 1 h 20 min im
Hintergrund", je App eine zweite Zeile. Eine App ohne Vordergrundzeit bekommt
einen Strich und bleibt trotzdem in der Liste; genau dieser Fall fehlte bisher
ganz.

**`SCREEN_OFF` beendet einen Dienstabschnitt nicht.** Musik bei ausgeschaltetem
Bildschirm ist der Regelfall, nicht der Fehler — genau anders herum als beim
Vordergrund, wo eine über Nacht offene App sonst acht Stunden sammelte.

**Mehrere gleichzeitige Dienste eines Pakets** (Wiedergabe und Download) ergeben
einen Abschnitt, nicht zwei. `serviceIntervals` zählt dafür die
Schachtelungstiefe.

**Die Atempause bleibt unberührt.** Sie rechnet weiter mit reiner
Vordergrundzeit. Doomscrolling passiert nicht im Hintergrund, und eine Pause,
die wegen laufender Musik aufpoppt, hätte mit dem Zweck nichts zu tun.
