# Atempause — Design

**Stand:** 2026-08-11
**Projekt:** NFC-Riegel (`nfc_riegel`), Branch `feature/nfc-riegel`
**Quelle:** Wunsch vom 2026-08-11 — „einstellbare Erinnerung oder automatische
Schließung der App nach x Minuten, damit man nicht ins Doomscrolling verfällt"

## Wozu

Der Riegel kennt bisher nur zwei Zustände: offen oder zu. Beides ist eine
Entscheidung, die man vorher trifft — mit dem Chip, der Uhr oder dem Kalender.
Doomscrolling entsteht aber nicht aus einer Entscheidung, sondern aus ihrem
Fehlen: man fängt unbewusst an und merkt nach vierzig Minuten, dass man nichts
davon wollte.

Dagegen hilft weder ein Verbot noch eine Ermahnung. Ein Verbot erzeugt
Umgehungen, eine wegtippbare Erinnerung wird nach drei Tagen reflexhaft
weggetippt. Was bleibt, ist **Reibung**: ein Moment, in dem nichts geht und man
gezwungen ist, die eigene Lage zur Kenntnis zu nehmen.

## Umfang

**Enthalten:** eine erzwungene Pause, die sich an der Tagesnutzung je App
staffelt und mit jeder Stufe länger wird; Einstellungen je Profil; ein eigener
Vollbildschirm dafür.

**Bewusst nicht enthalten:**

- **Keine Sperre.** Nach dem Countdown geht es immer weiter. Sperren bleiben,
  was sie sind: Chip, Zeitsperre, Kalender.
- **Keine Statistik über Pausen**, kein „du hast heute dreimal weitergemacht",
  keine Belohnung fürs Aufhören. Das wäre der Anfang einer Gamification, und
  die arbeitet gegen das Ziel — sie macht aus Einsicht einen Punktestand.
- **Kein Verlauf, kein Diagramm.** Dafür gibt es den Screenzeit-Reiter.

## Verhalten

### Die Pause

Du bist in Instagram. Bei 15 Minuten Tagesnutzung legt sich ein Schirm darüber:
App-Name, „Heute 15 min", ein Countdown von fünf Sekunden. Kein Knopf, keine
Zurück-Taste. Danach zwei Wege — **Weiter** oder **Schließen**.

| Tagesnutzung | Wartezeit |
|---|---|
| 15 min | 5 s |
| 30 min | 10 s |
| 45 min | 20 s |
| 60 min | 40 s |
| 75 min und darüber | 60 s |

Die Wartezeit verdoppelt sich je Stufe und wird bei **60 Sekunden gedeckelt**.
Alles darüber wäre Schikane statt Denkpause, und Schikane erzeugt Umgehungen.

Stufenabstand (hier 15 min) und Grundwartezeit (hier 5 s) sind je Profil
einstellbar. Die Verdopplung und der Deckel sind es nicht — zwei Regler reichen,
um das Verhalten zu verstehen.

### Wann sie kommt

Wird eine Stufe überschritten, **während die App im Vordergrund ist**, kommt die
Pause sofort. Wird sie kurz vor dem Weglegen überschritten, kommt sie **beim
nächsten Öffnen** dieser App — nicht Stunden später aus dem Nichts.

Um Mitternacht fängt alles von vorn an.

### Für welche Apps

Nur für Apps, die in einem Profil stehen, dessen Atempause eingeschaltet ist.
Alles andere bleibt unberührt — der Riegel mischt sich nicht in Apps ein, die
man ihm nie genannt hat.

Steht eine App in **mehreren** Profilen mit eingeschalteter Pause, gilt der
**kleinste Stufenabstand** und die **längste Grundwartezeit**. Strenger stellen
ist immer erlaubt, lockerer nie — dieselbe Linie wie bei den Zeitsperren, wo ein
späteres Ende überschreibt und ein früheres die laufende Sperre in Ruhe lässt.

### Was sie nicht tut

Sie sperrt nicht. Läuft ohnehin eine Sperre, kommt der Sperrschirm und keine
Pause — zwei Schirme übereinander wären albern.

**„Schließen" bringt auf den Startbildschirm.** Die App direkt danach wieder zu
öffnen, verhindert die Pause nicht: die Stufe gilt als gezeigt. Wer wirklich
weitermachen will, kann das. Das ist Absicht — die Entscheidung fiel für Reibung
statt Verbot.

## Auslösung

### Das Problem

`BlockerService` horcht auf `typeWindowStateChanged`, also auf App-Wechsel (siehe
`res/xml`, `android:accessibilityEventTypes`). Wer zwanzig Minuten in einer App
scrollt, erzeugt kein einziges Ereignis. Eine Pause mitten in der Sitzung käme
so nie zustande.

### Die Lösung

**Den nächsten Prüfzeitpunkt ausrechnen, statt zu pollen.** Aus Tagesnutzung und
Stufenabstand ergibt sich, wie viele Vordergrundmillisekunden bis zur nächsten
Stufe fehlen. Der Dienst legt sich genau dafür einen verzögerten Aufruf zurecht
und verwirft ihn, sobald eine andere App nach vorn kommt.

Kein Sekundentakt, keine Batterielast, und die Pause kommt auf wenige Sekunden
genau. Verworfen wurden:

- **Sekundentakt** — Batterielast für nichts.
- **Mehr Ereignisarten abonnieren** (`typeWindowContentChanged`) — flutet den
  Dienst beim Scrollen und bleibt trotzdem unzuverlässig, weil nicht jede App
  solche Ereignisse schickt.

## Zuschnitt

Derselbe Schnitt wie bei Kalender und Screenzeit: die Rechnung rein, Android
außen herum.

- **`PausePlanner`** — reines Kotlin, ohne Android und ohne Speicher. Bekommt
  Tagesnutzung, Stufenabstand, Grundwartezeit und die zuletzt gezeigte Stufe;
  gibt zurück, ob eine Pause fällig ist, wie lang sie dauert und wann der nächste
  Blick nötig wird. Per JUnit prüfbar.
- **`PauseActivity`** — Vollbildschirm ohne Flutter, wie der Sperrschirm.
- **`PauseStore`** — merkt sich je App die zuletzt gezeigte Stufe und das Datum.

**`PauseStore` steht bewusst neben `LockState`, nicht darin.** Eine Atempause
ist keine Sperre. Der Sperrzustand ist die eine Sache in dieser App, die niemals
durcheinanderkommen darf; ihn um ein Feld zu erweitern, das mit Sperren nichts
zu tun hat, würde diese Grenze aufweichen.

**Aufräumarbeit:** die Farbkonstanten `BlockColors` liegen privat in
`BlockActivity.kt`. Der Pausenschirm braucht dieselben, also wandern sie in eine
eigene Datei — sonst stehen sie zweimal da und laufen beim nächsten Farbwechsel
auseinander.

## Einstellungen

Am Profil, unter den bestehenden Angaben:

- **Atempause** an/aus
- **Stufenabstand** in Minuten (Vorgabe 15)
- **Grundwartezeit** in Sekunden (Vorgabe 5)

Fehlt die Berechtigung für Nutzungsdaten, stehen dort ein Hinweis und der Weg in
den Systemschirm statt der Regler — ohne sie kann die Pause nicht rechnen.

## Randfälle

**Mehrere Stufen auf einmal** — etwa weil die Berechtigung spät erteilt wurde und
plötzlich zwei Stunden auf dem Konto stehen — ergeben **eine** Pause mit der
Wartezeit der höchsten erreichten Stufe. Vier Pausen hintereinander wären eine
Strafe, und Strafen erzeugen Trotz.

**Datumswechsel** setzt die Stufe zurück, erkennbar am mitgespeicherten Datum.

**Neustart** braucht nichts wiederherzustellen: die Tagesnutzung rechnet Android,
die zuletzt gezeigte Stufe steht im Speicher.

**Home-Taste während des Countdowns** umgeht die Pause. Dabei wird die App aber
verlassen — also genau das getan, worum es ging. Wird nicht abgefangen.

**Stufenabstand null oder negativ** löst gar nichts aus. Eine kaputte Einstellung
darf nicht in eine Dauerpause führen.

**Riegel selbst** löst nie eine Pause aus; `BlockerService` überspringt das eigene
Paket bereits.

## Prüfung

### Reine Rechnung (JUnit, ohne Emulator)

- unterhalb der ersten Stufe keine Pause
- Pause genau beim Erreichen der Stufe
- Wartezeit verdoppelt sich je Stufe
- Wartezeit bei 60 s gedeckelt
- mehrere Stufen auf einmal ergeben eine Pause mit der höchsten Wartezeit
- bereits gezeigte Stufe löst nicht erneut aus
- Datumswechsel setzt die Stufe zurück
- Stufenabstand null oder negativ löst nichts aus
- nächster Prüfzeitpunkt entspricht den fehlenden Millisekunden bis zur Stufe
- ohne fällige Stufe und ohne Rest kommt kein Prüfzeitpunkt zustande
- bei mehreren Profilen gewinnen der kleinste Stufenabstand und die längste
  Grundwartezeit

### Oberfläche (Widget-Tests)

- Schalter und Regler erscheinen am Profil
- ohne Nutzungsdaten-Berechtigung erscheint der Hinweis statt der Regler
- geänderte Werte landen im Kanalaufruf

### Am Gerät

- Pause kommt **mitten im Scrollen**, nicht erst beim App-Wechsel — der Punkt,
  an dem das Vorhaben hängt
- Countdown lässt sich nicht überspringen, Zurück-Taste wirkt nicht
- „Weiter" führt zurück in die App, „Schließen" auf den Startbildschirm
- zweite Stufe wartet doppelt so lang
- während einer laufenden Sperre erscheint der Sperrschirm, keine Pause
- über Mitternacht hinweg beginnt die Staffelung von vorn

## Offene Kleinigkeiten

Keine. Alles oben ist entschieden.

---

## Nachtrag 2026-08-20: Sitzungszeit statt Tagessumme

Beim Entwurf fiel die Wahl auf die **Tagesnutzung** — mit dem Argument, kurz
herauszuspringen dürfe die Staffelung nicht zurücksetzen. Nach dem Benutzen
wurde daraus der umgekehrte Wunsch, und der ist berechtigt: an einem langen Tag
kommt die Pause irgendwann im Minutentakt, auch wenn man die App nur kurz und
bewusst aufmacht. Das bestraft die gute Nutzung mit.

**Neu:** gemessen wird die Zeit **am Stück**. Die Staffelung beginnt von vorn,
sobald die App eine einstellbare Weile (Vorgabe 15 Minuten) unbenutzt bleibt.

`ScreenTimeCalculator.sessionMillis` summiert dafür rückwärts über die
Vordergrund-Abschnitte, bis eine Lücke von mindestens dieser Länge kommt. Kurz
herauszuspringen hilft also weiterhin nicht — man muss die App wirklich
liegenlassen.

`PauseSettings` bekommt `resetMinutes`; der Profilsatz wächst von zehn auf elf
Felder und liest weiterhin sieben und zehn.

**`PauseDecision.step` meldet jetzt immer die tatsächlich erreichte Stufe**, auch
wenn keine Pause fällig ist. Nur so erkennt der Dienst am Absinken, dass eine
neue Sitzung begonnen hat, und setzt den gespeicherten Zähler zurück.

## Nachtrag 2026-08-20: Die Pause ließ sich wegwischen

Gemeldet aus Build 9: der Pausenschirm ließ sich abwischen und die App danach
weiter benutzen, obwohl der Countdown nicht abgelaufen war.

Zwei Ursachen, beide behoben:

1. **Die Stufe galt als gezeigt, sobald der Schirm startete.** Vermerkt wird sie
   jetzt erst, wenn der Countdown wirklich abgelaufen ist. Wer vorher wegwischt,
   bekommt dieselbe Stufe beim nächsten Blick in die App wieder — die Pause
   lässt sich aussitzen, aber nicht abschütteln.
2. **Der Schirm lag in derselben Aufgabe wie Riegel** und war damit aus der
   Übersicht wischbar. Er bekommt jetzt eine eigene Aufgabe wie der Sperrschirm.
   Das ursprüngliche „die Pause darf im Verlauf auftauchen" war falsch gedacht.
