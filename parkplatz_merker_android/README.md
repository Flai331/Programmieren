# Parkplatz-Merker

Android-App, die sich **automatisch** merkt, wo dein Auto steht. Wenn du die
App später öffnest, siehst du „Dein Auto steht seit 14:32 hier“ mit Karte und
dem Knopf „Navigation zum Auto“ (Fußweg in Google Maps).

Dein Handy muss dafür **nicht** per Bluetooth mit dem Auto oder dem
FM-Transmitter verbunden sein. Die App verbindet oder koppelt sich nie – sie
schaut höchstens, ob der Transmitter in der Nähe ist.

## Anleitung in der App

Alle Anleitungen stehen auch in der App: **?**-Symbol oben auf der Startseite
oder in den Einstellungen (dort je Abschnitt direkt zum passenden Thema).

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

## Apps im Auto automatisch öffnen (optional)

Wenn ein Transmitter/Beacon eingerichtet ist, kann die App **mehrere beliebige Apps** 
automatisch öffnen, sobald du dein Auto erkannt hast – z. B. Blitzer.de + Spotify + Google Maps.

**Einrichtung:**
1. Einstellungen → **„Im Auto: Apps & Lautstärke“** → **Apps hinzufügen**.
2. Jede gewünschte App aus der Liste auswählen. Die letzte der Liste liegt danach vorn.
3. Optional: **„Beim Aussteigen beenden“** aktivieren (schaltet zum Startbildschirm und
   versucht, die Apps zu beenden).
4. Optional: **„Über anderen Apps einblenden“** Berechtigung freigeben (damit die Apps
   direkt aufgehen; ohne die Berechtigung kommt statt dessen eine Benachrichtigung).

**Wie es funktioniert:**
- Sobald dein Transmitter/Beacon **während der Fahrt** erkannt wird, öffnen sich alle gewählten Apps
  nacheinander mit je 1,5 Sekunden Abstand. Die letzte liegt danach vorn.
  Die Suche startet, wenn Android „im Fahrzeug“ erkennt – meist 1–2 Minuten nach dem Losfahren
  (mit Beacon oft schneller). Eine einzelne verpasste Suche schließt nichts.
- Ohne Transmitter/Beacon: Jede erkannte Fahrt öffnet die Apps – auch Bus oder Taxi.
- Das funktioniert nur, wenn die App entweder die Berechtigung **„Über anderen Apps“**
  hat, oder der Nutzer eine Benachrichtigung antippen kann.
- Beim **Aussteigen** (wenn der Transmitter weg ist): Die App wechselt zum Startbildschirm und versucht,
  alle Apps zu beenden. Manche Blitzer-Apps laufen als Warnung im Hintergrund weiter –
  dann muss die Warnung in der App selbst beendet werden.

**Test:** Knopf **„Apps jetzt öffnen (Test)”** zum Probieren.

## Ganze Routine testen

Der Test spielt daheim eine echte Fahrt nach: Transmitter gefunden, ein kurzer Aussetzer (z. B. Tunnel), wieder gefunden, beim Aussteigen weg.

**Im Auto → „Ganze Routine testen”:**
1. Abstand zwischen den Suchen wählen (5 / 10 / 20 Sekunden, Standard 10 s).
2. „Test starten” – der Test zeigt 5 Schritte:
   - **Transmitter gefunden (RSSI −51):** Apps öffnen.
   - **Suche: nicht gefunden (einzelner Aussetzer):** Apps sollen offenbleiben.
   - **Suche: gefunden (RSSI −47):** Transmitter wieder da, Apps nicht erneut öffnen.
   - **Suche: gefunden (RSSI −49):** ok.
   - **Aussteigen: Transmitter weg:** Apps beenden, Lautstärke zurücksetzen.
3. Während der Abstand-Countdown läuft, kannst du prüfen: Apps oben? Lautstärke richtig? Energiesparmodus aus?

Jeder Schritt zeigt **✓** (ok), **✗** (fehler) oder **–** (übersprungen). Nach dem Test: **„Ergebnis kopieren”** → Text mit Schritten + Ereignissen in die Zwischenablage (zum Weiterschicken).

## Blitzer-App komplett beenden

Manche Blitzer-Apps wie Blitzer.de laufen nach dem Beenden als Warnung im Hintergrund weiter. Um die App beim Aussteigen komplett zu beenden, nutzt Parkplatz-Merker zwei Wege:

**Weg 1: Ausschaltknopf in der Benachrichtigung** (empfohlen)
- Funktioniert auch bei **gesperrtem Bildschirm**.
- Erfordert **Benachrichtigungszugriff**: Einstellungen → Benachrichtigungen → Parkplatz-Merker → Zugriff erlauben.
- In der Einstellung **„Ausschaltknopf”** kannst du auswählen, welcher Knopf der Benachrichtigung gedrückt werden soll (z. B. „Ausschalten”, „Beenden” oder ein Symbol). Oder: automatisch suchen.

**Widget-Knöpfe:** Manche Apps wie Blitzer.de zeigen ein eigenes Layout mit zusätzlichen Knöpfen in der Benachrichtigung. Du siehst diese Widget-Knöpfe in der Einstellung **„Ausschaltknopf”** separat aufgelistet. Wähle einen → teste ihn mit dem Play-Symbol rechts. Beim richtigen geht die App aus.

**Weg 2: Beenden erzwingen per Bedienungshilfe** (Fallback)
- Falls Weg 1 nicht klappt oder die App nicht reagiert.
- Öffnet kurz die App-Info und drückt dort „Beenden erzwingen”.
- Erfordert **Bedienungshilfe**: Einstellungen → Bedienungshilfen → Installierte Apps → „Parkplatz-Merker: App beenden” einschalten. Ausgegraut? Erst „Eingeschränkte Einstellungen zulassen”.
- Nur bei **entsperrtem Bildschirm** möglich. Ist der Bildschirm gesperrt, erledigt es Parkplatz-Merker beim nächsten Entsperren (max. 30 Min. später).

**Einrichtung:**
1. Einstellungen → **„Im Auto: Apps & Lautstärke“** → Apps hinzufügen.
2. **„Beim Aussteigen beenden“** aktivieren.
3. „Benachrichtigungszugriff“-Berechtigung freigeben.
4. Optional: „Notfalls ‚Beenden erzwingen' (Bedienungshilfe)“ aktivieren und die Bedienungshilfe-Berechtigung freigeben.
5. Mit „Beenden jetzt testen“ die Konfiguration prüfen.

## Lautstärke im Auto automatisch anpassen (optional)

Mit dem Lautstärke-Profil stellst du dich automatisch auf feste Lautstärken um, wenn du einsteigst 
– z. B. Medien auf 70 %, Klingelton normal, Benachrichtigungen aus. Beim Aussteigen wird alles zurückgesetzt.

**Einrichtung:**
1. Einstellungen → **„Im Auto: Apps & Lautstärke“** → Abschnitt **„Lautstärke im Auto“**.
2. **„Lautstärke-Profil“** aktivieren.
3. Für jeden Stream (Medien, Klingelton, Benachrichtigungen) festlegen, ob und auf welche Stufe er umgestellt werden soll.
4. Optional: Klingelmodus auf „Lautlos“, „Vibration“ oder „Normal“ setzen.
5. **„Nicht-stören-Zugriff“-Berechtigung** freigeben, falls du Lautstärke auf 0 (lautlos) stellen möchtest.
6. Mit den Test-Knöpfen prüfen.

**Ohne Transmitter/Beacon:** Das Profil gilt für jede erkannte Fahrt – auch Bus oder Taxi.

## Widget und Schnelleinstellung

- **Widget „Hier geparkt“:** Startbildschirm lange drücken → Widgets → Parkplatz-Merker →
  „Hier geparkt“ auf den Startbildschirm ziehen. Tippen merkt die aktuelle Position.
- **Widget „Mein Auto“:** Startbildschirm lange drücken → Widgets → Parkplatz-Merker →
  „Mein Auto“ auf den Startbildschirm ziehen. Zeigt, wo dein Auto steht (Karte, Adresse,
  Zeit seit dem Parken). Tippt du auf die Karte oder den Text, öffnet sich die App.
  Der Knopf „Navigation“ startet den Fußweg in Google Maps. Der Knopf „Hier geparkt“
  merkt einen neuen Standort. Das Widget aktualisiert sich von selbst etwa 1 Minute nach
  dem Aussteigen.
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
- **Ignoriert** werden Halte unter 2 Minuten und Fahrten unter 3 Minuten – außer der
  Transmitter war dabei oder du bist mindestens 200 m gefahren (Tankstelle → Parkplatz).
  Ein langer Stau ohne Aussteigen zählt auch nicht.
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

## Energiesparmodus im Auto (Samsung)

Apps dürfen den Energiesparmodus nicht selbst umschalten. Bei Samsung geht es mit
„Modi und Routinen“: Routine „Wenn App geöffnet: Blitzer.de → Energiesparmodus aus“.
Weil der Parkplatz-Merker Blitzer.de beim Einsteigen öffnet und beim Aussteigen beendet,
schaltet Samsung den Modus automatisch aus und danach wieder zurück. Schritt für Schritt:
in der App unter **?** → „Energiesparmodus im Auto (Samsung)“.
