# Akku-Schoner (Android)

Hilft einem schwachen/kaputten Akku: beendet unwichtige Hintergrund-Apps,
warnt beim Laden ab einer Ladegrenze, bei wenig Akku und bei Hitze und führt
direkt zu den Einstellungen, die am meisten Strom sparen.

**APK:** https://github.com/Flai331/Programmieren/releases/download/akku-schoner/Akku-Schoner.apk

## Funktionen
- **Akku**: Ladestand, Temperatur, Spannung, Strom, Zustand, Ladezyklen (Android 14+), Hinweise.
  **Akku-Wächter** (optional): Benachrichtigung bei Ladegrenze (Standard 80 %), unter 20 % und ab 40 °C.
  Hört nur auf die Akku-Meldungen des Systems – kein Timer, kein GPS, kein Netz.
- **Apps**: alle Apps mit Status „aktiv/beendet“, Hintergrundzeit der letzten 24 h (mit Nutzungszugriff).
  ★ = wichtig (wird nie beendet; Messenger, Wecker, Telefon sind vorausgewählt).
  „Unwichtige Apps beenden“ beendet alle anderen aktiven Nutzer-Apps per „Beenden erzwingen“.
  Pro App: einzeln beenden oder „Akkunutzung einschränken“ (dauerhaft).
- **Sparen**: Abkürzungen zu Energiesparmodus, Akkuverbrauch, Bildschirm, Standort, Bluetooth, WLAN, NFC,
  Synchronisierung, Datensparmodus, Akku-Optimierung + Tipps für schwache Akkus.

## Einrichtung
1. APK installieren und öffnen.
2. Reiter **Apps** → „Nutzungszugriff erlauben“ → Akku-Schoner einschalten.
3. „Bedienungshilfe einschalten“ → Installierte Apps → **Akku-Schoner: Apps beenden**.
   Ausgegraut? App-Info → ⋮ → „Eingeschränkte Einstellungen zulassen“, dann nochmal.
4. Reiter **Akku** → Akku-Wächter einschalten, Benachrichtigungen erlauben.

## Grenzen
Android lässt keine App andere Apps direkt beenden. Ohne Bedienungshilfe geht nur das „sanfte“ Beenden
(`killBackgroundProcesses`), das Apps mit eigenem Dienst überleben. Mit Bedienungshilfe drückt die App
„Beenden erzwingen“ in der App-Info – wie von Hand. Beendete Apps bekommen keine Push-Nachrichten,
bis sie wieder geöffnet werden. Dauerhaft wirkt „Akku → Eingeschränkt“ in der App-Info.
