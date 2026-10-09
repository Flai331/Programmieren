# Akku-Schoner (Android)

Hilft einem schwachen/kaputten Akku: beendet unwichtige Hintergrund-Apps,
warnt beim Laden ab einer Ladegrenze, bei wenig Akku und bei Hitze und führt
direkt zu den Einstellungen, die am meisten Strom sparen.

**APK:** https://github.com/Flai331/Programmieren/releases/download/akku-schoner/Akku-Schoner.apk

## Funktionen
- **Akku**: Ladestand, Temperatur, Spannung, Strom, Zustand, Ladezyklen (Android 14+), Hinweise.
  **Akku-Wächter** (optional): Benachrichtigung bei Ladegrenze (Standard 80 %), unter 20 % und ab 40 °C.
  Hört nur auf die Akku-Meldungen des Systems – kein Timer, kein GPS, kein Netz.
- **Apps**: alle Apps mit Status „aktiv/beendet“, Hintergrundzeit (24 h) und Nutzungstagen (7 Tage).
  Jede App hat eine **Stufe**, automatisch nach Nutzung gewählt, pro App änderbar:
  - **Wichtig** (an ≥ 4 von 7 Tagen benutzt, vorinstallierte Apps): nie anfassen.
  - **Sanft** (ab und zu benutzt; Musik-Apps wie Spotify, Messenger, Wecker, Navigation): nur aus dem Speicher werfen –
    Push-Nachrichten und **Play am Kopfhörer bei gesperrtem Handy** funktionieren weiter.
  - **Komplett** (7 Tage nicht benutzt): „Beenden erzwingen“ per Bedienungshilfe.
- **Automatik**: 15 s nach Bildschirm-Aus „Sanft“+„Komplett“-Apps sanft beenden; beim Entsperren nach
  ≥ 30 min Pause (einstellbar) „Komplett“-Apps erzwungen beenden (nicht während Anrufen).
- **Sparen**: auf Samsung „Akku schützen“ (Ladegrenze) und „Schlafende Apps“; Abkürzungen zu Energiesparmodus, Akkuverbrauch, Bildschirm, Standort, Bluetooth, WLAN, NFC,
  Synchronisierung, Datensparmodus, Akku-Optimierung + Tipps für schwache Akkus.

## Einrichtung
1. APK installieren und öffnen.
2. Reiter **Apps** → „Nutzungszugriff erlauben“ → Akku-Schoner einschalten.
3. „Bedienungshilfe einschalten“ → Installierte Apps → **Akku-Schoner: Apps beenden**.
   Ausgegraut? App-Info → ⋮ → „Eingeschränkte Einstellungen zulassen“, dann nochmal.
4. Reiter **Akku** → Akku-Wächter einschalten, Benachrichtigungen erlauben.
5. Reiter **Apps** → Automatik-Schalter nach Wunsch. Reiter **Sparen** → (Samsung) „Akku schützen“ einschalten.

## Grenzen
Android lässt keine App andere Apps direkt beenden. Ohne Bedienungshilfe geht nur das „sanfte“ Beenden
(`killBackgroundProcesses`), das Apps mit eigenem Dienst überleben. Mit Bedienungshilfe drückt die App
„Beenden erzwingen“ in der App-Info – wie von Hand. Beendete Apps bekommen keine Push-Nachrichten,
bis sie wieder geöffnet werden. Dauerhaft wirkt „Akku → Eingeschränkt“ in der App-Info.
