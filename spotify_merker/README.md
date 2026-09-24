# Spotify-Merker

Eine Web-App (PWA) zum Aufzeichnen deines Spotify-Hörverlaufs – inklusive Minutenstand. Merke dir Hörbuch-Kapitel und springe später genau dort weiter, wo du aufgehört hast.

## Features

- 📚 **Hörbuch-Fortschritt speichern**: Die App merkt sich, in welchem Kapitel du bist und bei welcher Minute
- 📺 **Podcast-Verfolgung**: Verwalte deinen Podcast-Fortschritt
- 🎵 **Musik-Chronik**: Überblick über gehörte Songs
- 🔙 **"Zurück zu …"-Banner**: Springt direkt zur gespeicherten Position im Hörbuch
- 📱 **Installierbar**: PWA – App-Shell lädt offline, Tracking braucht Internet
- 🔐 **Privat**: Alle Daten bleiben lokal auf deinem Gerät
- 🌙 **Hell/Dunkel-Modus**: Folgt deinen System-Einstellungen

## Einrichtung

### 1. Spotify-App erstellen

1. Gehe zum [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Melde dich an oder erstelle ein Konto
3. Klicke auf "Create an App"
4. Akzeptiere die Spotify Developer-Nutzungsbedingungen
5. Erstelle die App (z. B. "Spotify-Merker")
6. Die **Client ID** wird dir angezeigt – kopiere sie

### 2. Dein Spotify-Konto hinzufügen

1. Im Developer Dashboard klickst du auf deine App
2. Gehe zu "User Management"
3. Klicke auf "Add User" und füge dein Spotify-Konto hinzu (es sollte Premium sein)
4. Gehe zur App-Übersicht und aktiviere "Web API" in den Scopes

### 3. Redirect URI eintragen

1. Klicke auf deine App im Developer Dashboard
2. Gehe zu "Edit Settings"
3. Bei "Redirect URIs" gibst du die folgende Adresse ein:
   ```
   https://flai331.github.io/Programmieren/spotify-merker/
   ```
   (oder die URL, unter der die App läuft)
4. Klicke "Save"

### 4. App installieren

- Die App läuft unter: https://flai331.github.io/Programmieren/spotify-merker/
- Im Browser: Menü → "App installieren" oder Adressleiste → Download-Icon

### 5. Client ID eingeben

1. Öffne die App
2. Gehe zu "Einstellungen"
3. Trage die **Client ID** aus dem Spotify Developer Dashboard ein
4. Speichern

### 6. Anmelden

1. Klicke auf "Anmelden"
2. Autorisiere die App (Spotify fragt nach Berechtigungen)
3. Du bist verbunden!

## Grenzen

- **Premium erforderlich**: Nur Spotify-Premium-Nutzer können Musik aus der App steuern
- **App muss offen sein**: Minutenstände für Songs werden nur erfasst, wenn die App im Browser-Tab oder PWA offen ist (Hintergrund-Tabs können vom Browser gedrosselt werden)
- **Hörbücher und Podcasts**: Spotify speichert Positionen selbst – die App zeigt diese im Tab "Hörbücher"
- **Lokal gespeichert**: Verlauf bleibt auf dem Gerät, auf dem er erstellt wurde. Zum Übertragen Export → Import nutzen
- **Keine Cloud-Synchronisierung**: Daten sind nicht zwischen Geräten synchronisiert

## Verwendung

### Jetzt
- **Aktuelle Musik**: Sieht, was gerade läuft
- **"Zurück zu …"-Banner**: Springt zum letzten Hörbuch (nur wenn nicht gerade das Hörbuch abgespielt wird)
- **Merken**: Anheften wichtiger Einträge

### Verlauf
- **Filter**: Nach Zeit, Art (Musik/Hörbuch/Podcast), gemerkte Einträge
- **Suche**: Nach Titel oder Künstler
- **"Was lief um …?"**: Finde Musik zu einer bestimmten Uhrzeit (±30 Min.)
- **Weiterhören**: Setzt die Musik bei der gespeicherten Stelle fort
- **In Spotify öffnen**: Startet das Stück in der Spotify-App

### Hörbücher
- **Stand laden**: Holt den aktuellen Kapitel-Fortschritt von Spotify
- **Weiterhören**: Setzt die Wiedergabe an der gespeicherten Stelle fort
- **Status**: Zeigt, welches Kapitel dran ist oder ob das Buch fertig ist

### Einstellungen
- **Client ID**: Deine Spotify-App-ID
- **Redirect URI**: URL der App (zum Eintragen im Spotify Dashboard)
- **Export/Import**: Sicherung und Übertragung des Verlaufs
- **Anleitung**: Schritt-für-Schritt-Hilfe
- **Datenschutz**: Verlauf komplett löschen

## Technologie

- Reine **HTML/CSS/JavaScript** (keine Frameworks, kein Build-Step)
- Spotify **Web API** (Authorization Code + PKCE)
- **localStorage** für Daten (privat, pro Gerät)
- **Service Worker** (PWA – App-Shell offline verfügbar)
- Systemschriften (kein CDN)

## Offline

Die App-Shell lädt offline, aber Tracking und Wiedergabesteuerung brauchen Internet.

## Datenquellen

- Aktive Wiedergabe: Polling alle 5 Sekunden (30 Sekunden wenn verborgen)
- Recently Played: Beim Öffnen, auf Sichtbarkeitsänderung und alle 5 Minuten
- Hörbücher: Nur auf Anfrage (Tab öffnen oder "Stand laden"-Button)

## Fehlerbehandlung

- **401 Unauthorized**: Sitzung abgelaufen, erneut anmelden
- **403 Premium Required**: Fernsteuerung funktioniert nur mit Premium
- **429 Too Many Requests**: App wartet automatisch und versucht erneut
- **NO_ACTIVE_DEVICE**: Kein Gerät aktiv – Spotify-App öffnen und erneut versuchen

## Support

- **Spotify Developer Docs**: https://developer.spotify.com/documentation/web-api
- **Issues**: Öffne ein Issue im Repository
