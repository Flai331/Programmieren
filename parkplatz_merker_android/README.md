# Parkplatz-Merker

Eine Android-App, die automatisch erkennt, wo dein Auto abgestellt wurde – ohne ein Bluetooth-Gerät verbinden zu müssen.

## Download

[Parkplatz-Merker.apk](https://github.com/Flai331/Programmieren/releases/download/parkplatz-merker-android/Parkplatz-Merker.apk)

## Einrichtung

Damit die App funktioniert, musst du folgende Berechtigungen erteilen:

### 1. Standort (immer zulassen)
- Öffne die App.
- Tippe auf das Einstellungen-Symbol (⚙️).
- Wähle „Standort (immer zulassen)" und tippe „Erlauben".
- Im nächsten Dialog **wähle „Immer zulassen"** (nicht nur „Während der Nutzung").

### 2. Aktivitätserkennung
- Tippe in den Einstellungen auf „Aktivitätserkennung" und „Erlauben".
- Dies hilft der App, zu erkennen, wann du aussteigst.

### 3. Bluetooth-Suche (optional, falls du einen Transmitter/Beacon nutzen möchtest)
- Tippe auf „Bluetooth-Suche" und folge den Anweisungen.
- Verbinde das Gerät **nicht** per Bluetooth mit dem Handy – die App schaut nur, ob es in der Nähe ist.

### 4. Benachrichtigungen
- Tippe auf „Benachrichtigungen" und „Erlauben".

### 5. Akku (nicht eingeschränkt)
- Tippe auf „Akku" und folge den Anweisungen.
- Dies verhindert, dass Android die App drosselt.

### 6. Eingeschränkte Einstellungen (falls der Schalter ausgegraut ist)
- Öffne die App-Einstellungen.
- Öffne die App-Info für „Parkplatz-Merker".
- Tippe oben rechts auf ⋮ (drei Punkte).
- Wähle „Eingeschränkte Einstellungen zulassen".
- Öffne die App erneut und versuche es.

## So testest du, ob die App deinen Transmitter/Beacon sieht

### Mit Transmitter:
1. **Auto anstellen**.
2. **Handy NICHT** mit dem Transmitter verbinden.
3. Öffne die App → Einstellungen → Gerät im Auto: Transmitter → „Transmitter suchen".
4. Das Gerät sollte in der Liste erscheinen mit RSSI-Wert.
5. **Gegenprobe**: Transmitter ausstecken → erneut suchen → sollte verschwinden.

### Nach einer Fahrt:
1. Fahrt beenden und parken.
2. Öffne die App → Einstellungen → „Diagnose".
3. Scrolle zu „Zuletzt gesehen" – sollte die aktuelle Zeit zeigen.

## Widget & Schnelleinstellungs-Kachel hinzufügen

### Widget (auf dem Homescreen):
1. Langer Druck auf den Homescreen.
2. Wähle „Widgets".
3. Suche „Parkplatz-Merker".
4. Tippe auf das Widget zum Hinzufügen.
5. Das Widget zeigt die aktuelle Parkplatz-Koordinaten. Tippen speichert den Standort als Parkplatz.

### Schnelleinstellungs-Kachel:
1. Wische von oben nach unten (oder zweimal) bis zur Schnelleinstellung.
2. Tippe auf „Bearbeiten" oder das Plus-Symbol.
3. Suche und aktiviere „Hier geparkt".
4. Tippen speichert den aktuellen Standort als Parkplatz.

## Funktionsweise

### Automatische Erkennung:
1. Die App nutzt die **Aktivitätserkennung**, um zu merken, wenn du aussteigst (IN_VEHICLE → WALKING/RUNNING/STILL).
2. Sie speichert dann deinen **Standort** beim Aussteigen.
3. Optional kannst du einen **Transmitter/Beacon** im Auto verwenden – die App prüft, ob dieser noch in der Nähe ist.

### Parkplatz-Kriterien:
- **Aussteigen erkannt**: Aktivitätserkennung zeigt Übergang.
- **Ladekabel ab**: Dein Handy wird abgestöpselt → kann ein Hinweis sein.
- **Transmitter weg / Beacon weg**: Das Gerät verschwindet → dein Auto bleibt.
- **Standort**: GPS-Position wird gespeichert.

Die App sagt dir, **wie** der Parkplatz erkannt wurde (z. B. „Aussteigen + Transmitter weg").

### Manuelle Speicherung:
1. Tippe auf „Hier geparkt" → die App speichert deinen Standort sofort.
2. Alternativ: Nutze das Widget oder die Schnelleinstellungs-Kachel.

## Datenschutz

- **Alles lokal**: Deine Standorte, Fahrtdaten und Fotos werden nur auf deinem Handy gespeichert.
- **Keine Verbindung zum Internet**: Außer für Adressen-Umwandlung (Google Maps API, optional).
- **Keine Anmeldung**: Die App braucht keinen Account.
- **Kein Bluetooth-Verbinden**: Das Handy verbindet sich **nie** mit dem Transmitter/Beacon – es schaut nur, ob es in der Nähe ist.

## Diagnose

Falls die App nicht wie erwartet funktioniert:

1. Öffne die App.
2. Tippe auf Einstellungen → „Diagnose".
3. Tippe auf „Kopieren" (AppBar).
4. Sende den Text an den Support.

Die Diagnose zeigt:
- Welche Berechtigungen du erteilt hast.
- Den Status der Aktivitätserkennung und des Bluetooth.
- Deine letzten Fahrten und deren Status.
- Deine letzten 100 Ereignisse (Standorte, Scans, Fehler).

## Häufig gestellte Fragen

**F: Meine App erkennt den Parkplatz nicht automatisch.**
A: Prüfe, dass die Aktivitätserkennung und der Standort (immer) erlaubt sind. Du kannst jederzeit „Hier geparkt" drücken.

**F: Der Transmitter wird nicht gefunden.**
A: Stelle sicher, dass das Auto an ist, der Transmitter lädt, und du ihn nicht mit Bluetooth verbunden hast. Versuche die Suche in den Einstellungen.

**F: Die App wird vom System beendet.**
A: Stelle sicher, dass die Akku-Optimierung deaktiviert ist (Einstellungen → Akku).

**F: Kann ich mehrere Geräte nutzen?**
A: Derzeit unterstützt die App nur ein Gerät (Transmitter oder Beacon).
