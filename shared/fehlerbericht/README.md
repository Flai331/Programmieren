# Fehlerbericht

Ein einziges, in sich geschlossenes Drop-in-Modul für Fehlerberichte in
Flutter-Apps. Eine Datei (`lib/fehlerbericht.dart`), keine relativen
Imports, keine Notion-Konfiguration pro App nötig — einfach kopieren und
einbinden.

Alle Berichte landen automatisch in Notion. Jede App richtet sich beim
allerersten Fehlerbericht selbst eine eigene Datenbank unter der
gemeinsamen "🐞 Fehlerzentrale" ein. Ist kein Notion-Token gesetzt oder
schlägt Notion endgültig fehl, öffnet sich stattdessen die E-Mail-App mit
dem vollständigen Berichtstext.

## Einmalig (nur ein Mal für alle Apps)

Damit die Fehlerberichte nicht mehr über die Integration einer einzelnen
App laufen, gibt es genau eine gemeinsame Notion-Integration:

1. Auf <https://notion.so/my-integrations> eine interne Integration
   anlegen, z. B. **„Fehlerzentrale"**, und das Token (`ntn_…`) kopieren.
2. In Notion die Seite **🐞 Fehlerzentrale** öffnen →
   `•••` → **Verbindungen** → die Integration hinzufügen.
   Alle Unterseiten und App-Datenbanken erben den Zugriff automatisch —
   für neue Apps muss also **nie wieder** etwas in Notion freigegeben
   oder angelegt werden.
3. Prüfen, ob alles sitzt:

   ```bash
   # Linux/macOS
   NOTION_TOKEN=DEIN_TOKEN python3 tools/notion_selbsttest.py
   ```

   ```powershell
   # Windows PowerShell
   $env:NOTION_TOKEN = "DEIN_TOKEN"
   python tools\notion_selbsttest.py
   ```

   `DEIN_TOKEN` durch das echte Token ersetzen — es beginnt mit `ntn_`.

   Das Skript geht genau die Aufrufe durch, die auch die App macht
   (Registry lesen, App-Seite und Datenbank anlegen, Bericht schreiben,
   Screenshot hochladen) und räumt die Testdaten danach wieder auf.

## Einbau in eine neue App

1. **Datei kopieren.** `lib/fehlerbericht.dart` unverändert in das
   `lib/`-Verzeichnis der neuen App kopieren.

2. **`pubspec.yaml` ergänzen** (falls noch nicht vorhanden):

   ```yaml
   dependencies:
     http: ^1.2.0
     url_launcher: ^6.2.5
   ```

   Mehr Abhängigkeiten braucht das Modul nicht — kein `path_provider`,
   kein `image_picker`, kein `flutter_email_sender`, kein
   `shared_preferences`.

3. **Android: Internet-Berechtigung sicherstellen.** In
   `android/app/src/main/AndroidManifest.xml` muss stehen:

   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

   Das ist die häufigste Stolperfalle: Flutters Vorlage legt diese Zeile
   nur in `src/debug/` und `src/profile/` ab. Debug-Builds funktionieren
   dadurch, **Release-Builds nicht** — jeder Notion-Aufruf scheitert dann
   mit `Failed host lookup: 'api.notion.com' … errno = 7`, und das Modul
   wechselt still auf den E-Mail-Fallback. Steht die Zeile schon im
   `main`-Manifest (viele Apps haben sie), ist nichts zu tun.

4. **`main.dart` umstellen:**

   ```dart
   import 'package:flutter/material.dart';
   import 'fehlerbericht.dart';

   void main() => Fehlerbericht.runApp(
         appKey: 'meine_app',      // stabiler, klein geschriebener Schlüssel
         appName: 'Meine App',     // Anzeigename in Notion
         version: '1.0.0',         // optional, taucht in jedem Bericht auf
         builder: () => const MyApp(),
       );

   class MyApp extends StatelessWidget {
     const MyApp({super.key});

     @override
     Widget build(BuildContext context) {
       return MaterialApp(
         navigatorKey: Fehlerbericht.navigatorKey,
         navigatorObservers: [Fehlerbericht.observer],
         builder: Fehlerbericht.wrap,
         home: const StartSeite(),
       );
     }
   }
   ```

   Mehr ist nicht nötig. `Fehlerbericht.runApp` übernimmt
   `WidgetsFlutterBinding.ensureInitialized()`, verdrahtet
   `FlutterError.onError`, `PlatformDispatcher.instance.onError` und
   `runZonedGuarded`, sodass jeder unbehandelte Fehler automatisch erfasst
   und gemeldet wird. `Fehlerbericht.wrap` blendet außerdem einen kleinen,
   verschiebbaren Fehler-Button ein, über den Nutzer jederzeit manuell
   einen Bericht mit Beschreibung und Screenshot senden können.

   **`appKey` darf sich später nicht mehr ändern** — er identifiziert die
   App eindeutig in der Notion-Registry.

5. **Bauen** — das Notion-Token wird zur Build-Zeit gesetzt, nicht im
   Quellcode:

   ```bash
   flutter run --dart-define=NOTION_TOKEN=ntn_...
   flutter build apk --dart-define=NOTION_TOKEN=ntn_...
   flutter build web --dart-define=NOTION_TOKEN=ntn_...
   ```

   Ein Token gilt für **alle** Apps — dasselbe `NOTION_TOKEN` bei jeder
   App verwenden. Ohne Token funktioniert die App normal weiter, Berichte
   gehen dann per `mailto:` an die hinterlegte Support-Adresse.

## Was passiert beim ersten Fehlerbericht automatisch in Notion?

Ist eine App (`appKey`) der zentralen "📊 Apps"-Registry noch unbekannt,
richtet sie sich beim ersten Bericht selbst ein:

1. Eine neue Unterseite mit dem Namen der App wird unter der
   "🐞 Fehlerzentrale" angelegt (Icon 🐛).
2. Darin entsteht eine Datenbank `🐛 <App-Name>` mit dem festen Schema
   (Titel, Status, Art, Beschreibung, Fehler, Seite, Version, Plattform,
   OS, Gerät, Zeitstempel, Fingerprint).
3. Ein Registry-Eintrag in "📊 Apps" verlinkt die neue Datenbank
   (App-Key, Datenbank-ID, Seiten-ID, Berichte-Zähler, letzte Meldung
   usw.).

Alle folgenden Berichte derselben App landen direkt in dieser Datenbank —
Protokoll und Stacktrace als aufklappbare Code-Blöcke im Seiteninhalt,
nicht in den Properties. Ein Screenshot wird, falls vorhanden, als
Bild-Block angehängt (strikt best-effort: schlägt der Upload fehl, wird
der Bericht trotzdem gespeichert).

## Öffentliche API

| Methode | Zweck |
|---|---|
| `Fehlerbericht.runApp({appKey, appName, version, builder, button, ignorieren})` | Ersetzt `runApp()` in `main()`. |
| `Fehlerbericht.wrap` | `MaterialApp(builder: ...)` — Screenshot-Boundary + Overlay-Button. |
| `Fehlerbericht.navigatorKey` | An `MaterialApp(navigatorKey: ...)` übergeben. |
| `Fehlerbericht.observer` | An `MaterialApp(navigatorObservers: [...])` übergeben. |
| `Fehlerbericht.log(msg)` | Freie Protokollzeile. |
| `Fehlerbericht.logAktion(aktion, {kontext})` | Nutzeraktion protokollieren. |
| `Fehlerbericht.logSeite(name, {info})` | Screen-Wechsel protokollieren. |
| `Fehlerbericht.logApi(endpoint, methode, {statusCode, fehler})` | API-Aufruf protokollieren. |
| `Fehlerbericht.logDb(operation, tabelle, {id, erfolgreich})` | DB-Operation protokollieren. |
| `Fehlerbericht.logAuswahl(feld, wert, {optionen})` | Nutzer-Auswahl protokollieren. |
| `Fehlerbericht.logFehler(fehler, {kontext, stack})` | Abgefangenen Fehler protokollieren + automatisch (still) melden. |
| `Fehlerbericht.melden(context)` | Öffnet den Melde-Dialog manuell. |
| `Fehlerbericht.protokoll` | Aktuelles Protokoll (letzte 300 Einträge). |
| `FehlerButton` | AppBar-Icon-Button als Alternative/Ergänzung zum Overlay-Button. |

Mit `Fehlerbericht.runApp(..., button: false)` lässt sich der schwebende
Button abschalten — dann `FehlerButton()` z. B. in eine `AppBar` einbauen.

### Störmeldungen ausfiltern

Manche Plattform-Meldungen sind bekannt und harmlos, würden die
Notion-Datenbank aber zumüllen. Sie lassen sich per Textbaustein
ausschließen — sie stehen weiterhin im Protokoll, lösen aber keinen
Bericht aus:

```dart
Fehlerbericht.runApp(
  appKey: 'meine_app',
  appName: 'Meine App',
  ignorieren: const ['NetworkManager', 'connectivity_plus'],
  builder: () => const MyApp(),
);
```

Manuelle Meldungen über den Fehler-Button sind davon nie betroffen.

## Fehlersuche

**Kein Bericht kommt an, aber die App läuft normal weiter**
→ Wahrscheinlich fehlt `--dart-define=NOTION_TOKEN=...` beim Build. Ohne
Token wechselt das Modul automatisch (und lautlos für den Nutzer) auf den
E-Mail-Fallback. Im Protokoll (`Fehlerbericht.protokoll` bzw. Debug-Konsole)
steht dazu die Zeile *"Kein NOTION_TOKEN gesetzt ... nutze E-Mail-Fallback."*

**Release-Build meldet nichts, Debug-Build schon**
→ Die INTERNET-Berechtigung fehlt im `main`-Manifest (siehe Einbau,
Schritt 3). Im Protokoll steht dann `Failed host lookup` mit `errno = 7`.

**HTTP 401 von Notion**
→ Das Token ist falsch, abgelaufen oder wurde bei der Notion-Integration
nicht mit der "🐞 Fehlerzentrale"-Seite geteilt. In Notion: Seite öffnen →
"..." → "Verbindungen" → die Integration hinzufügen, die zum Token gehört.

**HTTP 404 von Notion**
→ Entweder die Integration hat keinen Zugriff auf `_wurzelSeiteId` /
`_registryDbId` (siehe vorheriger Punkt), oder die Notion-Struktur wurde
verschoben/gelöscht. Die IDs sind im Code fest verdrahtet und dürfen nicht
verändert werden, außer die Notion-Seiten wurden bewusst neu angelegt.

**Web: Es kommt nie ein Bericht in Notion an**
→ Erwartet. Die Notion-API blockiert Browser-Anfragen per CORS (kein
`Access-Control-Allow-Origin`-Header). Das Modul erkennt den ersten
fehlgeschlagenen Web-Versuch, merkt sich das für die laufende Session und
wechselt danach direkt auf den E-Mail-Fallback (im Protokoll sichtbar).
Für Web-Apps ist der E-Mail-Fallback der vorgesehene Weg, keine Notion-
Direktanbindung.

**Screenshot fehlt im Bericht**
→ Auf Web wird nie ein Screenshot erfasst (nicht unterstützt). Bei
automatischen Fehlern (Abstürze, `logFehler`) wird bewusst kein
Screenshot erstellt, um die App nicht zu verzögern — nur der manuelle
Melde-Dialog nimmt einen Screenshot auf.

**"Gerät" ist leer oder wenig aussagekräftig**
→ Bewusste Einschränkung: Das Modul darf laut Vorgabe kein zusätzliches
Paket wie `device_info_plus` verwenden, daher liefert es nur den
Hostnamen (`Platform.localHostname`), auf Web/manchen Plattformen auch
das nicht.

**Derselbe Fehler wird nicht erneut gemeldet**
→ Gewollt (Dedup): Ein identischer Fehler-Fingerprint wird innerhalb von
60 Sekunden nur einmal gesendet, damit z. B. Fehler in einer Schleife
nicht die Notion-Datenbank fluten.
