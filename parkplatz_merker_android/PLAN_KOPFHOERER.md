# Parkplatz-Merker – Plan „Kopfhörer wiederfinden“

## Ziel
Neuer Bereich **„Kopfhörer“**: Wird ein gewählter, mit dem Handy gekoppelter Kopfhörer
getrennt, speichert die App den Ort des Handys in diesem Moment. So findet man verlorene
Kopfhörer wieder („Zuletzt getrennt um 14:32 – hier“ + Karte + Navigation).
(Nur Geräte, die der Nutzer selbst gekoppelt hat. Der Transmitter bleibt ungekoppelt.)

## Kotlin (fertig, vom Planer geschrieben)
- `Headphones.kt` + `HeadphoneReceiver` (Manifest: ACL/A2DP/Headset-Verbindungswechsel).
- `Config.headphones`: `getConfig()['headphones']` = `List<Map>` mit `address`, `name`;
  `setConfig({'headphones': [...]})` speichert die Auswahl.
- MethodChannel:
  - `listBondedDevices` → `List<Map>`: `address`, `name`, `audio` (bool; Audio-Geräte zuerst sortiert).
  - `getHeadphones` → `List<Map>` je gewähltem Kopfhörer: `address`, `name`, `connected` (bool),
    `changedAt` (ms, letzter Wechsel), `lat`, `lng`, `acc` (double oder null), `fixAt` (ms, 0 = keiner).
  - `forgetHeadphone({'address'})` → löscht den gespeicherten Ort.

## Dart (Haiku-Agent)
1. `lib/native.dart`: `listBondedDevices()`, `getHeadphones()`, `forgetHeadphone(String address)`
   im Stil der bestehenden Methoden (try/catch, `PlatformException`/`MissingPluginException` →
   leere Liste). Werte in `List<Map<String, dynamic>>` umwandeln (`Map<String, dynamic>.from`).
   `setConfig`/`updateConfig` um Parameter `List<Map<String, String>>? headphones` erweitern
   (in `native.dart` **und** `controller.dart`, wie `launchApps`).
2. Neue Seite `lib/pages/headphones_page.dart` („Kopfhörer“), StatefulWidget:
   - Lädt `getHeadphones()` beim Öffnen und bei „Aktualisieren“ (RefreshIndicator).
   - Je Kopfhörer eine Card:
     - Titel = Name, Icon `Icons.headphones`.
     - Verbunden → grüner Text „Gerade verbunden“.
     - Getrennt mit Ort → „Getrennt am <Datum Uhrzeit> (± <acc> m)“ (vorhandene Funktionen aus
       `lib/logic/format.dart` nutzen), darunter kleine Karte 180 px hoch (FlutterMap wie in
       `spot_view.dart`, gleicher Tile-Layer, Marker mit `Icons.headphones`), Knöpfe
       „Navigation“ (`NativeBridge.openNavigation(lat, lng)`) und „Vergessen“ (`forgetHeadphone`, neu laden).
     - Getrennt ohne Ort → „Getrennt am …, Ort unbekannt“.
     - Noch nie getrennt → „Noch keine Trennung gespeichert“.
     - Menü/IconButton „Entfernen“ → Kopfhörer aus der Auswahl nehmen (`updateConfig(headphones: …)`).
   - FloatingActionButton „Kopfhörer hinzufügen“ → Dialog/Seite mit `listBondedDevices()`:
     Liste (Audio-Geräte mit `Icons.headphones`, andere mit `Icons.bluetooth`), bereits gewählte
     mit Haken. Antippen fügt hinzu (`updateConfig(headphones: alt + neu)`). Leere Liste →
     Text „Keine gekoppelten Geräte gefunden. Kopple deinen Kopfhörer zuerst in den
     Bluetooth-Einstellungen und erlaube „Geräte in der Nähe“.“
   - AppBar-Aktion `Icons.help_outline` → Anleitung, Abschnitt `HelpTopic.headphones`
     (so, wie andere Seiten die Hilfe öffnen – nachsehen und gleich machen).
   - Leerer Zustand (keine Kopfhörer gewählt): kurzer Erklärtext + Knopf „Kopfhörer hinzufügen“.
3. Einstieg:
   - `home_page.dart`: in `actions` ein `IconButton(Icons.headphones, tooltip: 'Kopfhörer')` → Seite.
   - `settings_page.dart`: neuer Abschnitt `SectionHeader('Kopfhörer', help: HelpTopic.headphones)`
     mit ListTile „Kopfhörer wiederfinden“ → Seite.
4. Anleitung (`help_page.dart`): `HelpTopic.headphones` (vor `widgets`) + Abschnitt
   „Kopfhörer wiederfinden“, Icon `Icons.headphones`:
   - Was es macht (Trennung → Ort gespeichert, auch bei geschlossener App).
   - Einrichten: Kopfhörer normal in den Bluetooth-Einstellungen koppeln → Parkplatz-Merker →
     Kopfhörer (Symbol oben auf der Startseite) → „Kopfhörer hinzufügen“ → Gerät wählen.
     Voraussetzungen: Standort „Immer zulassen“ und „Geräte in der Nähe“.
   - Wiederfinden: Kopfhörer-Seite → Karte → „Navigation“. Der Ort ist dort, wo das **Handy**
     beim Trennen war – die Kopfhörer liegen meist in der Nähe (Bluetooth reicht ca. 10 m).
   - Testen: Kopfhörer verbinden, dann ausschalten oder ins Case legen → nach ein paar Sekunden
     steht auf der Kopfhörer-Seite „Getrennt am …“ mit Karte.
   - Hinweis: Das Parken im Auto ist davon unabhängig; der Transmitter wird nie gekoppelt.
5. `README.md`: kurzer Abschnitt „Kopfhörer wiederfinden“ (3–5 Zeilen).

## Regeln
- Texte Deutsch, „du“. Keine Kotlin-Dateien ändern.
- Am Ende `flutter analyze` (keine Fehler/Warnungen) und `flutter test` grün.
  Flutter: `/tmp/claude-0/sdk/flutter/bin/flutter`.
