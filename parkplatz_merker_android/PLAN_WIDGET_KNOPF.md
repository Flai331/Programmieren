# Parkplatz-Merker – Plan „Ausschaltknopf im Benachrichtigungs-Widget drücken“

## Ausgangslage
Blitzer.de läuft nach dem Aussteigen im Hintergrund weiter. Seine Benachrichtigung
ist ein **eigenes Layout** („Widget“ in der Leiste, `RemoteViews`) – die Knöpfe darin
sind **keine** `Notification.Action`s. `NotifListener.pressStop` findet deshalb nichts.
Der Nutzer möchte **weder** Bedienungshilfe („Stopp erzwingen“) **noch** Shizuku.

## Idee (nur öffentliche Android-API)
Der `NotificationListenerService` sieht die `Notification` inklusive ihrer `RemoteViews`
(`bigContentView`, `contentView`, `headsUpContentView`). `RemoteViews.apply(context, parent)`
baut daraus echte Views – genau wie ein Launcher Widgets anzeigt. Die Views tragen die
Klick-Handler der fremden App; `performClick()` auf dem Aus-Knopf löst dessen
`PendingIntent` aus, als hätte man in der Leiste getippt. Die Views werden nie angezeigt.

## Kotlin – neue Datei `WidgetButtons.kt` (schreibt der Planer selbst)
- `list(pkg): List<Map<String, Any>>` – je klickbarem View: `key` (`"big:3"`),
  `name` (Ressourcen-Name der View-ID, z. B. `btn_exit`), `desc` (contentDescription).
- `press(pkg, key): Boolean` – Layout erneut aufbauen, View Nr. `index` klicken.
- `pressAuto(pkg): Boolean` – genau **ein** klickbarer View, dessen Name/Beschreibung
  nach Beenden klingt (exit, close, quit, stop, power, shutdown, beenden, schließen,
  ausschalten) → klicken. Sonst nichts tun.
- Nur auf dem Main-Thread; alles in try/catch.

Anbindung (Planer): `AppLauncher.closeAll` – wenn `pressStop` nichts gedrückt hat:
`closeWidget` der App gesetzt → `WidgetButtons.press`, sonst `WidgetButtons.pressAuto`;
Ergebnis in die Diagnose. `launchApps`-Einträge bekommen das Feld `closeWidget` (String,
leer = automatisch). `MainActivity`: `listCloseActions` liefert zusätzlich
`widgetButtons` (Liste wie oben); neue Methode `testWidgetButton(package, key)` → `Boolean`.

## Dart (Haiku-Agent)
- `NativeBridge.testWidgetButton(String package, String key)` → `Future<bool>`.
- `listCloseActions`: `widgetButtons` wie `actions` in `List<Map<String, dynamic>>` umwandeln.
- `car_page.dart`, Dialog „Ausschaltknopf“ für eine App:
  - Bisherige Einträge (Automatisch, Knöpfe der Benachrichtigung) bleiben.
  - **Neu:** Überschrift „Knöpfe im Benachrichtigungs-Widget“ und je Eintrag
    `Widget-Knopf N` + Name/Beschreibung (falls vorhanden) + rechts ein
    `IconButton` „Testen“ (Icon `play_arrow`) → `testWidgetButton` → SnackBar
    „Gedrückt – ist Blitzer.de jetzt aus?“ bzw. „Konnte nicht gedrückt werden“.
    Antippen des Eintrags → `closeWidget = key`, `closeActionIndex = -1`, `closeActionTitle = ''`.
  - „Automatisch“ setzt auch `closeWidget = ''`.
  - Hinweis oben: „Blitzer.de muss gerade laufen (Benachrichtigung sichtbar). Teste die
    Knöpfe nacheinander – beim richtigen geht Blitzer.de aus. Starte es danach wieder.“
  - Die bisherige Meldung „keine normalen Knöpfe … Bedienungshilfe“ nur noch zeigen,
    wenn es **weder** Aktionen **noch** Widget-Knöpfe gibt.
  - Untertitel des Eintrags in der App-Liste: gewählter Widget-Knopf („Widget-Knopf 3“)
    bzw. wie bisher.
- `updateConfig(launchApps: …)`: `closeWidget` pro App mitspeichern (Standard `''`).
- **Anleitung** (`help_page.dart`, Abschnitt `closeApp`): neuer Absatz „Blitzer.de & Co.
  zeigen oft ein eigenes Widget in der Benachrichtigung … Ausschaltknopf → Wählen →
  Widget-Knöpfe testen …“. README kurz ergänzen.

## Prüfen
`flutter analyze` ohne Fehler/Warnungen, `flutter test` grün; Kotlin Zeile für Zeile.
