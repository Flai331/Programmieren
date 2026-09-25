# Parkplatz-Merker

Android-App, die sich **automatisch** merkt, wo dein Auto steht. Wenn du die
App später öffnest, siehst du „Dein Auto steht seit 14:32 hier“ mit Karte und
dem Knopf „Navigation zum Auto“ (Fußweg in Google Maps).

Dein Handy muss dafür **nicht** per Bluetooth mit dem Auto oder dem
FM-Transmitter verbunden sein. Die App verbindet oder koppelt sich nie – sie
schaut höchstens, ob der Transmitter in der Nähe ist.

## Download

**[Parkplatz-Merker.apk](https://github.com/Flai331/Programmieren/releases/download/parkplatz-merker-android/Parkplatz-Merker.apk)**

Die Datei im Browser des Handys herunterladen und öffnen. Beim ersten Mal
fragt Android, ob der Browser Apps installieren darf → erlauben. Updates
lassen sich einfach über die alte Version installieren (gleicher Schlüssel);
deine Parkplätze bleiben erhalten.

## Einrichtung (einmalig, ca. 2 Minuten)

App öffnen → ⚙️ **Einstellungen** → Abschnitt **Einrichtung**. Jede Zeile mit
rotem Symbol antippen → **Erlauben**:

1. **Standort** → „Bei Nutzung der App“.
2. **Standort „Immer zulassen“** → im nächsten Fenster wirklich **„Immer
   zulassen“** wählen. Ohne das klappt die Erkennung bei geschlossener App nicht.
3. **Aktivitätserkennung** („Körperliche Aktivität“) → erlauben.
4. **Bluetooth-Suche** („Geräte in der Nähe“) → erlauben (nur für Transmitter/Beacon nötig).
5. **Benachrichtigungen** → erlauben.
6. **Akku „Nicht eingeschränkt“** → im Fenster „Zulassen“; oder unter
   Einstellungen → Apps → Parkplatz-Merker → Akku → „Nicht eingeschränkt“.
   Bei Samsung zusätzlich: Akku → „Apps im Standby“ – Parkplatz-Merker dort
   **nicht** eintragen.

**Schalter ausgegraut oder „Eingeschränkte Einstellung“?** Android sperrt
manches für Apps, die nicht aus dem Play Store kommen. In der App auf
„App-Info öffnen“ → oben rechts **⋮** → **„Eingeschränkte Einstellungen
zulassen“** → bestätigen, dann den Schritt wiederholen.

Wenn alles grün ist, verschwindet auf der Startseite der Hinweis
„Einrichtung unvollständig“. Mehr ist nicht zu tun – einfach losfahren.

## Transmitter einrichten (optional, empfohlen)

Mit dem Transmitter weiß die App, dass du in **deinem** Auto sitzt (nicht im
Bus oder Taxi) und wann der Motor aus ist.

1. Auto an, Transmitter steckt und leuchtet. Handy **nicht** mit dem Transmitter verbinden.
2. Einstellungen → **Gerät im Auto: Transmitter** → **„Transmitter suchen“** → **„Suche starten“**.
3. Nach ca. 15 Sekunden erscheint eine Liste mit Name, Adresse und Signalstärke (RSSI).
   Dein Transmitter ist meist der mit dem stärksten Signal (Zahl am nächsten an 0, z. B. −45 dBm).
4. Eintrag antippen → **„Verwenden“**.

### So testest du, ob die App deinen Transmitter sieht

1. **Gegenprobe:** Transmitter kurz ausstecken → noch einmal suchen → er darf
   **nicht** mehr in der Liste stehen. Wieder einstecken → noch mal suchen → er ist wieder da.
   Dann ist es sicher der richtige.
2. **Taucht er nie auf?** Manche Transmitter sind nur sichtbar, solange kein
   Handy verbunden ist – prüfe, dass auch kein anderes Handy im Auto mit ihm
   verbunden ist. Bluetooth und Standort (GPS) am Handy müssen an sein.
3. **Nach der ersten Fahrt:** Einstellungen → **Diagnose**. Unter „Gerät“
   muss „Zuletzt gesehen: …“ mit einer Uhrzeit während der Fahrt und einem
   RSSI-Wert stehen. Steht dort „noch nie“, schick mir den Diagnose-Text
   (Knopf „Kopieren“ oben rechts).

Wichtig: Ist ein Transmitter eingerichtet und wurde er während einer Fahrt
**nie** gesehen, speichert die App **keinen** Parkplatz (du warst dann
vermutlich in einem anderen Auto). Wenn die Suche selbst nicht klappt (z. B.
Bluetooth aus), gilt diese Regel nicht.

Alternativ kannst du einen kleinen **USB-BLE-Beacon** nehmen (Gerät im Auto:
Beacon) – funktioniert genauso, nur stromsparender.

## Blitzer-App automatisch öffnen (optional)

Wenn ein Transmitter/Beacon eingerichtet ist, kann die App eine beliebige
Blitzer- oder Navigation-App **automatisch öffnen**, sobald du dein Auto erkannt hast.

**Einrichtung:**
1. Einstellungen → Abschnitt **„App im Auto“** → **„App öffnen, wenn …“** → **„Wählen“**.
2. Die gewünschte App aus der Liste (z. B. Blitzer.de, Google Maps) auswählen.
3. Optional: **„Beim Aussteigen schließen“** aktivieren (schaltet zum Startbildschirm und
   versucht, die App zu beenden).
4. Optional: **„Über anderen Apps einblenden“** Berechtigung freigeben (damit die App
   direkt aufgeht; ohne die Berechtigung kommt statt dessen eine Benachrichtigung).

**Wie es funktioniert:**
- Sobald dein Transmitter/Beacon **während der Fahrt** erkannt wird, öffnet sich die App.
  Die Suche startet, wenn Android „im Fahrzeug“ erkennt – meist 1–2 Minuten nach dem Losfahren
  (mit Beacon oft schneller). Eine einzelne verpasste Suche schließt nichts.
- Das funktioniert nur, wenn die App entweder die Berechtigung **„Über anderen Apps“**
  hat, oder der Nutzer eine Benachrichtigung antippen kann.
- Beim **Aussteigen** (wenn der Transmitter weg ist): Die App wechselt zum Startbildschirm.
  Das Beenden funktioniert nur, wenn die App keinen eigenen Hintergrunddienst mit
  Benachrichtigung läuft. Blitzer-Apps tun das meist – dann bleibt die Warnung aktiv
  und muss in der App selbst beendet werden.

**Test:** Knopf **„Jetzt testen”** zum Probieren.

## Blitzer-App komplett beenden

Manche Blitzer-Apps wie Blitzer.de laufen nach dem Beenden als Warnung im Hintergrund weiter. Um die App beim Aussteigen komplett zu beenden, nutzt Parkplatz-Merker zwei Wege:

**Weg 1: Ausschaltknopf in der Benachrichtigung** (empfohlen)
- Funktioniert auch bei **gesperrtem Bildschirm**.
- Erfordert **Benachrichtigungszugriff**: Einstellungen → Benachrichtigungen → Parkplatz-Merker → Zugriff erlauben.
- In der Einstellung **„Ausschaltknopf”** kannst du auswählen, welcher Knopf der Benachrichtigung gedrückt werden soll (z. B. „Ausschalten”, „Beenden” oder ein Symbol). Oder: automatisch suchen.

**Weg 2: Beenden erzwingen per Bedienungshilfe** (Fallback)
- Falls Weg 1 nicht klappt oder die App nicht reagiert.
- Öffnet kurz die App-Info und drückt dort „Beenden erzwingen”.
- Erfordert **Bedienungshilfe**: Einstellungen → Bedienungshilfen → Installierte Apps → „Parkplatz-Merker: App beenden” einschalten. Ausgegraut? Erst „Eingeschränkte Einstellungen zulassen”.
- Nur bei **entsperrtem Bildschirm** möglich. Ist der Bildschirm gesperrt, erledigt es Parkplatz-Merker beim nächsten Entsperren (max. 30 Min. später).

**Einrichtung:**
1. Einstellungen → Abschnitt **„App im Auto”** → eine Blitzer-App auswählen.
2. **„Beim Aussteigen schließen”** aktivieren.
3. „Benachrichtigungszugriff”-Berechtigung freigeben.
4. Optional: „Notfalls ‚Beenden erzwingen' (Bedienungshilfe)” aktivieren und die Bedienungshilfe-Berechtigung freigeben.
5. Mit „Beenden jetzt testen” die Konfiguration prüfen.

## Widget und Schnelleinstellung

- **Widget:** Startbildschirm lange drücken → Widgets → Parkplatz-Merker →
  „Hier geparkt“ auf den Startbildschirm ziehen. Tippen merkt die aktuelle Position.
- **Kachel:** Benachrichtigungsleiste ganz herunterziehen → Stift/Bearbeiten →
  „Hier geparkt“ in die aktiven Kacheln ziehen.
- In der App: großer Knopf **„Hier geparkt“** unten.

## So funktioniert die Erkennung

- **Aktivitätserkennung** (Google Play-Dienste) meldet „fährt“ und
  „ausgestiegen/geht“. Während der Fahrt läuft ein Dienst mit dezenter
  Benachrichtigung „Fahrt erkannt“: er merkt alle 30 s die Position, sucht
  alle 2 Minuten kurz nach dem Transmitter und achtet aufs Ladekabel.
  Nach dem Aussteigen beendet er sich selbst (spätestens nach 3 Minuten).
- **Ausstiegszeitpunkt** = der genaueste verfügbare Hinweis:
  Ladekabel abgezogen → Transmitter verschwunden (Motor aus) → Aussteigen erkannt.
  Der Parkplatz ist die Position zu diesem Zeitpunkt.
- **Ignoriert** werden Fahrten unter 3 Minuten und Halte unter 2 Minuten
  (Ampel, Stau). Ein langer Stau ohne Aussteigen zählt auch nicht.
- Unter dem Parkplatz steht, woran er erkannt wurde, z. B.
  „erkannt über: Aussteigen + Transmitter weg“.
- Wurde etwas falsch erkannt: **„Falsch erkannt“** löscht den Eintrag.

## Weitere Funktionen

- **Notiz und Foto** zum Parkplatz (z. B. „Parkhaus Ebene 3, Platz 112“).
- **Parkschein:** Uhrzeit eingeben → 15 Minuten vorher kommt eine Erinnerung.
- **Verlauf** der letzten 30 Parkplätze.
- **Diagnose:** letzte 100 Ereignisse, Berechtigungen, Transmitter-Statistik –
  mit „Kopieren“ zum Weiterschicken.

## Datenschutz

Alles bleibt auf dem Handy: kein Konto, kein Server. Nur die Kartenbilder
kommen von OpenStreetMap, und für die Adresse wird der Android-Geocoder benutzt.

## Für Entwickler

Flutter (nur Android). Plan und Aufbau: [PLAN.md](PLAN.md).
Die APK baut GitHub Actions (`.github/workflows/parkplatz-merker-apk.yml`);
auf `main` wird das Release `parkplatz-merker-android` aktualisiert.
Tests: `flutter test` (Erkennungslogik in `lib/logic/`).
