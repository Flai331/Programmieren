# Parkplatz-Merker – Plan „Ganze Routine testen“

Ein Knopf spielt die komplette Auto-Routine im Stand durch und zeigt je Schritt ✓/✗.

## Native (fertig, vom Planer)
MethodChannel-Methoden in `MainActivity`:
- `scanOnce` → Map `{ok: bool, found: bool, error: String?}` (eine Suchrunde, ~12 s)
- `routineStart` → wie Einsteigen (`CarSession.testStart`: Lautstärke-Profil + alle Apps öffnen)
- `routineEnd` → wie Aussteigen (`CarSession.testEnd`: Apps beenden, Lautstärke zurück)
- `appRunning(package)` → bool (App hat noch eine Benachrichtigung = läuft noch)
Alle Schritte schreiben wie im Auto Ereignisse ins Journal (`info`/`scan`), die der
`AppController` mit `refresh()` abholt (`controller.events`).

## Dart (Haiku-Agent)
- `NativeBridge`: `scanOnce()`, `routineStart()`, `routineEnd()`, `appRunning(String package)`
  (Fehler abfangen; Maps mit `Map<String, dynamic>.from` umwandeln).
- Neue Seite `lib/pages/routine_test_page.dart` („Routine testen“), erreichbar oben auf der
  Seite „Im Auto“ (`car_page.dart`) über eine ListTile „Ganze Routine testen“ (Icon `science`).
- Oben Hinweis-Karte: „Der Test macht alles echt: Apps gehen auf und wieder zu, die Lautstärke
  ändert sich. Am besten im Stand, Transmitter eingesteckt.“
- Wartezeit wählbar: `SegmentedButton` 10 s / 30 s / 60 s (Standard 30 s).
- Knopf „Test starten“ (während des Tests deaktiviert). Ablauf, jeder Schritt als Zeile mit
  Symbol (⏳ läuft = CircularProgressIndicator klein, ✓ grün, ✗ rot, – übersprungen) und Detailtext:
  1. **Transmitter sehen** – nur wenn `config['deviceMode'] != 'none'` und Adresse gesetzt, sonst
     „–“ mit „Kein Gerät eingerichtet“. `scanOnce()` → ✓ „gesehen“ / ✗ „nicht gesehen – Auto an,
     Transmitter eingesteckt?“ / ✗ `error`.
  2. **Einsteigen** – `testStart = DateTime.now()`, `routineStart()`, 6 s warten,
     `controller.refresh()`, dann in `controller.events` mit `t >= testStart` und `type == 'info'`
     suchen: je App aus `config['launchApps']` „App geöffnet: <label>“ → ✓, „Hinweis gezeigt“ →
     ✗ „nur Benachrichtigung – ‚Über anderen Apps einblenden‘ erlauben“, sonst ✗ „nicht geöffnet“.
     Lautstärke: nur wenn `volumeEnabled` → „Lautstärke-Profil angewendet“ → ✓.
     Keine Apps eingerichtet → „–“.
  3. **Im Auto (Wartezeit)** – Countdown der gewählten Sekunden, Text: „Prüf jetzt: sind die Apps
     offen? Ist die Lautstärke richtig? Ist der Energiesparmodus aus (Samsung-Routine)?“
     Der Countdown läuft auch weiter, wenn eine geöffnete App im Vordergrund ist.
  4. **Aussteigen** – `routineEnd()`, 6 s warten, `refresh()`, dann je App:
     `appRunning(package)` false → ✓ „beendet“; true → ✗ „läuft noch“ + passende Info-Zeile aus
     den Ereignissen (`Ausschaltknopf von <label> …` bzw. `Widget-Knopf …`) als Detail.
     Lautstärke: „Lautstärke-Profil zurückgesetzt“ → ✓ (nur wenn `volumeEnabled` und `volumeRestore`).
  5. **Ergebnis** – „Alles in Ordnung ✓“ oder „N Punkte prüfen“; Knopf „Ergebnis kopieren“ →
     Text aller Schritte + alle `info`/`scan`-Ereignisse seit `testStart` (`describeEvent`)
     in die Zwischenablage, SnackBar „Kopiert“.
- `mounted` nach jedem `await` prüfen; Timer in `dispose` abbrechen.
- Anleitung (`help_page.dart`): Abschnitt `appInCar` um einen Absatz „Ganze Routine testen“
  ergänzen; README kurz. Test in `test/help_page_test.dart`, der den Absatz findet.
