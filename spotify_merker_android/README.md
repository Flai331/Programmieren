# Spotify-Merker

Eine Android-App, die im Hintergrund mitschreibt, was in der Spotify-App läuft – perfekt zum Zurückspulen bei Hörbüchern.

## Installation

1. APK herunterladen: [Spotify-Merker.apk](https://github.com/Flai331/Programmieren/releases/download/spotify-merker-android/Spotify-Merker.apk)
2. Installation aus unbekannten Quellen erlauben (bei erstem Start)
3. APK installieren

## Erste Schritte

### Benachrichtigungszugriff

Die App braucht Zugriff auf Benachrichtigungen, um Spotify zu überwachen:

1. App starten
2. Knopf „Benachrichtigungszugriff erlauben" antippen
3. In den Benachrichtigungseinstellungen Spotify-Merker aktivieren
4. Zurück zur App

**Schalter ausgegraut / „Eingeschränkte Einstellung“?** Android (ab Version 13) sperrt diesen Zugriff für Apps, die nicht aus dem Play Store kommen. Freigeben: In der App auf „App-Info öffnen“ tippen → oben rechts ⋮ → „Eingeschränkte Einstellungen zulassen“ → bestätigen. Danach klappt Schritt 2–3.

### Spotify-Einstellung (optional, aber empfohlen)

Für zuverlässigeres Zurückspulen:

1. Spotify öffnen
2. Einstellungen (Zahnrad) → Schalter „Geräte-Broadcast-Status“ einschalten (je nach Version unter „Wiedergabe“ oder „Apps und Geräte“)

### Akku-Optimierung

Damit die App im Hintergrund läuft:

- Einstellungen → Apps → Spotify-Merker → Akku → „Nicht eingeschränkt“
- Vor allem bei Samsung und Xiaomi wichtig, sonst beendet das System die App im Hintergrund.

## Verwendung

### Jetzt-Tab

- Aktuelle Wiedergabe mit Fortschrittsbalken
- Knopf „📌 Merken" zum Speichern der Position
- Wenn ein Hörbuch/Podcast pausiert wurde: „Zurück zu ..."-Karte mit „▶ Weiterhören"-Knopf

### Verlauf-Tab

- Alle aufgezeichneten Titel, Hörbücher und Podcasts
- Filter nach Zeitraum (Alle, Diese Woche, Heute, Gestern)
- Filter nach Art (Alle, Hörbücher, Musik, Gespeichert)
- Suchfeld
- Aktionen: Weiterhören, Speichern, Löschen

### Einstellungen-Tab

- Berechtigung prüfen
- Hinweise zu Einrichtung und Spotify-Einstellung
- Verlauf exportieren (als JSON-Datei)
- Verlauf löschen
- Diagnose: Zeigt Status und Fehlerprotokolle (wichtig zum Fehlersuchen)

## Grenzen und bekannte Probleme

- **Nur Android**: iOS wird nicht unterstützt
- **Zurückspulen hängt vom Spotify-Abo ab**: Je nachdem, welche Aktionen Spotify für dein Abo erlaubt, kann das Zurückspulen fehlschlagen. In dem Fall wird Spotify mit der Suchseite geöffnet und du musst den Titel antippen.
- **Nur Spotify**: Andere Musik-Apps werden nicht unterstützt
- **Hintergrund-Zuverlässigkeit**: Auf manchen Android-Versionen kann das Hintergrund-Monitoring unterbrochen werden

## Fehlersuchen

Wenn die App nicht funktioniert:

1. **Diagnose öffnen**: Einstellungen → Diagnose
2. **„Kopieren" antippen** und den Text an den Entwickler schicken
3. **Prüfen**:
   - `permission: true` (Benachrichtigungszugriff erteilt?)
   - `spotifySessionFound: true` (Spotify läuft und ist mit Spotify-Merker verbunden?)
   - `lastResumeLog` auf Fehler prüfen

## Technische Details

- **Datenspeicherung**: Alle Daten werden lokal auf dem Handy gespeichert (JSON-Datei unter `Documents/history.json`)
- **Keine Internetverbindung**: Die App braucht keine Internetverbindung und sendet keine Daten
- **Bluetooth/AirPlay**: Funktioniert mit Spotify über Bluetooth/Kopfhörer, aber das Zurückspulen braucht die Spotify-App auf dem Handy
