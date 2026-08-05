# Riegel v2 — Kalendereinbindung

Datum: 2026-08-04
Projekt: `Programmieren\nfc_riegel`
Setzt voraus: `2026-08-04-riegel-profile-chips-design.md`,
`2026-08-05-riegel-zeitsperren-design.md`

Nachtrag 2026-08-05: an das Zwei-Spuren-Modell der Zeitsperren-Spec angeglichen.
Betroffen sind „Sperrlogik" und „Datenmodell — Ergänzungen".

## Zweck

Termine sperren automatisch. Läuft ein passender Termin, sind die Apps des
zugeordneten Profils für dessen Dauer gesperrt — ohne Chip, ohne Zutun.

## Kalenderquelle

Der **Android-Systemkalender** über `CalendarContract`. Damit sieht Riegel alles,
was auf dem Handy eingerichtet ist: Google, Outlook, lokale Kalender.

Bewusst nicht die eigene Kalender-App über Supabase: Riegel läuft offline und ohne
Anmeldung, und ein Blocker, der auf eine Netzverbindung wartet, sperrt im Zweifel
nicht. Voraussetzung ist, dass die betreffenden Termine tatsächlich auf einem
Konto des Handys liegen.

Berechtigung: `READ_CALENDAR`, zur Laufzeit angefragt. Ohne sie bleibt die
Kalenderfunktion sichtbar deaktiviert statt still wirkungslos.

## Auslöser

Zwei Regeln, beide gleichzeitig aktiv:

1. **Ausgewählte Kalender** — jeder Termin darin sperrt. Pro Kalender wird ein
   Profil zugeordnet.
2. **Stichwort im Titel** — Termine, deren Titel den Marker enthält (Vorgabe
   `[Riegel]`), sperren auch aus nicht ausgewählten Kalendern. Sie nutzen ein
   festgelegtes Standardprofil.

Trifft beides zu, gewinnt die Kalenderzuordnung — sie ist die spezifischere Angabe.

Ganztägige Termine werden ignoriert. Ein Ganztagstermin würde 24 Stunden sperren,
was praktisch immer ein Versehen wäre; wer das will, legt einen Termin mit Uhrzeit
an.

## Terminfenster

Ein **Fenster** ist ein Termin, der sperren soll, reduziert auf das Nötige:

| Feld | Bedeutung |
|---|---|
| `eventId` | Kennung aus `CalendarContract` |
| `title` | Für die Anzeige auf dem Sperrschirm |
| `startsAt`, `endsAt` | Zeitraum |
| `profileId` | Aus Kalenderzuordnung oder Standardprofil |

Riegel liest die Fenster der **nächsten 48 Stunden** und legt sie im Zustand ab.
Das ist Zwischenspeicher, keine Wahrheit — die Wahrheit steht im Kalender.

## Sperrlogik

Die Kalendersperre ist eine **Zeitsperre** im Sinne der Zeitsperren-Spec: sie
startet ohne Chip und lässt sich vor ihrem Ende nur mit Generalschlüssel oder
Notfall-Code öffnen. Von `TIMER` und `UNTIL` unterscheidet sie sich allein darin,
woher Start und Ende stammen — aus dem Kalender statt aus dem Profil.

Drei Quellen laufen unabhängig nebeneinander, gesperrt ist ihre Vereinigung:
`chipLock`, `timeLocks` und die aus den Fenstern gerechneten Kalendersperren.

- Ein normaler Chip beendet **nur** die Chipsperre seines eigenen Profils — weder
  eine Zeit- noch eine Kalendersperre
- Ein **Generalschlüssel** beendet alles
- Der **Notfall-Code** beendet ebenfalls alles

Beendet ein Generalschlüssel oder der Code eine Kalendersperre, wird
`calendarSuppressedUntil` auf das Ende des laufenden Fensters gesetzt. Ohne dieses
Feld würde die Sperre sofort wieder greifen, weil sie ja aus dem Kalender berechnet
wird. Das nächste Fenster ist davon unberührt.

### Berechnet statt gespeichert

Die Kalendersperre ist **kein gespeicherter Zustand**, sondern ergibt sich aus den
zwischengespeicherten Fenstern und der aktuellen Uhrzeit. Verschiebst oder löschst
du einen laufenden Termin, verschwindet die Sperre mit — der Kalender bleibt die
Wahrheit über sich selbst.

### Ausnahme: festgenagelt

Steht im Profil `pinCalendarEnd = true`, wird beim Start eines Fensters dessen Ende
in `pinnedEnds[eventId]` festgeschrieben. Ab dann gilt dieses Ende, auch wenn der
Termin verschoben oder gelöscht wird. So lässt sich eine Sperre nicht durch Löschen
des Termins abkürzen.

Der Eintrag wird gelöscht, sobald sein Zeitpunkt vergangen ist.

## Wann Riegel nachschaut

Drei Auslöser, zusammen decken sie alles ab:

1. **Geplanter Alarm** auf die nächste Fenstergrenze — Start oder Ende des nächsten
   relevanten Termins. Nach jedem Feuern neu gesetzt.
2. **ContentObserver** auf `CalendarContract` — meldet Änderungen am Kalender,
   löst ein erneutes Einlesen und Neuplanen aus.
3. **App-Start** — einmal einlesen und neu planen, als Netz für alles, was die
   ersten beiden verpasst haben.

**Korrektur 2026-08-05.** Diese drei reichen nicht. Der Alarm hängt an der nächsten
Fenstergrenze — gibt es zehn Tage lang keinen passenden Termin, gibt es auch keine
Grenze und keinen Alarm. Der ContentObserver lebt nur, solange der Prozess lebt.
Der Zwischenspeicher altert in dieser Zeit weg, und der Termin am Dienstag sperrt
nicht.

Der Alarm wird deshalb auf `min(nächste Fenstergrenze, jetzt + 12 h)` gesetzt und
liest bei jedem Feuern neu ein. Das ist kein regelmäßiges Abfragen im Sinne von
„alle paar Minuten nachsehen", sondern eine Obergrenze dafür, wie alt der
Zwischenspeicher werden darf: höchstens zwei Aufwachvorgänge am Tag.

## Datenmodell — Ergänzungen

Zum Zustand aus der Profil- und der Zeitsperren-Spec kommen:

| Feld | Typ | Bedeutung |
|---|---|---|
| `calendarProfiles` | Map\<String, String\> | Kalender-ID → Profil-ID |
| `keywordMarker` | String | Vorgabe `[Riegel]` |
| `keywordProfileId` | String? | Profil für Stichwort-Treffer |
| `cachedWindows` | List\<CalendarWindow\> | Fenster der nächsten 48 h |
| `windowsFetchedAt` | Long | Wann zuletzt eingelesen |
| `pinnedEnds` | Map\<String, Long\> | eventId → festgenageltes Ende |
| `calendarSuppressedUntil` | Long? | Vom Generalschlüssel oder Code gesetzt |

## Oberfläche

**Kalender-Abschnitt im Hauptscreen**
- Schalter „Termine sperren" mit Berechtigungsanfrage
- Liste der Kalender des Geräts, je mit Auswahlhaken und Profil-Zuordnung
- Stichwort-Feld mit Vorgabe `[Riegel]` und Standardprofil dazu
- Vorschau: die nächsten drei Fenster mit Titel, Zeitraum und Profil

**Sperrschirm**
- Bei Kalendersperre: Termintitel und Ende, z.B. „Konzept schreiben — frei ab 12:00"
- Laufen beide Spuren, zeigt er beide Zeilen

**Hauptscreen bei aktiver Kalendersperre**
- Statuskachel nennt den Termin statt des Profilnamens

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| `READ_CALENDAR` verweigert | Kalenderfunktion deaktiviert, Hinweis mit Schaltfläche zur Systemeinstellung |
| Berechtigung später entzogen | Beim nächsten Einlesen erkannt, Fenster verworfen, Warnung im Hauptscreen |
| Zugeordnetes Profil gelöscht | Zuordnung fällt auf das erste verbleibende Profil zurück |
| Kalender vom Gerät entfernt | Zuordnung wird beim nächsten Einlesen verworfen |
| Zwei Fenster überlappen | Beide gelten, Blocklisten werden vereinigt |
| Termin ohne Ende oder mit Ende vor Start | Fenster wird verworfen |
| Ganztägiger Termin | Ignoriert |
| Termin beginnt während laufender Chipsperre | Beide laufen, Vereinigung greift |
| Gerät war aus, als ein Fenster begann | Beim Start neu berechnet; läuft das Fenster noch, sperrt es sofort |

## Tests

**Kotlin, JUnit** — die Logik liegt in einer eigenen Klasse ohne Android-Bezug, die
Fenster als Eingabe bekommt:

- Aktives Fenster wird gefunden, vergangenes und künftiges nicht
- Überlappende Fenster: Vereinigung der Blocklisten
- `calendarSuppressedUntil` unterdrückt das laufende, nicht das nächste Fenster
- `pinCalendarEnd`: Ende bleibt nach Verschieben und nach Löschen bestehen
- Ohne `pinCalendarEnd`: gelöschtes Fenster beendet die Sperre
- Kalenderzuordnung schlägt Stichwort
- Ganztägige und ungültige Termine werden verworfen
- Nächste Fenstergrenze für den Alarm wird richtig bestimmt

Das Lesen aus `CalendarContract` selbst wird nicht getestet — es ist eine dünne
Abfrage hinter einer Schnittstelle, die im Test durch eine feste Fensterliste
ersetzt wird.

**Von Hand** — Ergänzung der `GERAETETEST.md`: Termin anlegen und sperren lassen,
Termin während der Sperre verschieben, dasselbe mit `pinCalendarEnd`,
Generalschlüssel während einer Kalendersperre, Berechtigung entziehen.

**Verifikation:** `flutter analyze`, `flutter test`,
`android\gradlew.bat -p android testDebugUnitTest`

## Bewusst nicht enthalten

- Schreiben in den Kalender
- Anbindung der eigenen Kalender-App über Supabase
- Wiederkehrende Termine gesondert behandeln — `CalendarContract` liefert
  Wiederholungen bereits als einzelne Instanzen
- Vorlaufzeit vor Terminbeginn
