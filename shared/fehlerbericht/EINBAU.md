# Einbau in eine neue App

Diese Datei ist zum Weiterreichen gedacht: Wer in einem anderen Chat eine
App um Fehlerberichte erweitern soll, bekommt hier alles, was nötig ist.

## Der kurze Weg (empfohlen)

Ein Befehl erledigt den kompletten mechanischen Einbau:

```bash
python3 shared/fehlerbericht/tools/einbauen.py <app-ordner> \
        --key meine_app --name "Meine App"
flutter pub get
python3 shared/fehlerbericht/tools/app_pruefen.py <app-ordner>
```

Das Skript kopiert `lib/fehlerbericht.dart` in die App, trägt `http` und
`url_launcher` in die `pubspec.yaml` ein, setzt die INTERNET-Berechtigung
ins Android-Manifest und verdrahtet `lib/main.dart`. Es ist gefahrlos
wiederholbar und legt vor jeder Änderung eine `.bak`-Kopie an. Was es
nicht automatisch lösen konnte, schreibt es mit `!` in die Ausgabe.

`app_pruefen.py` bestätigt anschließend, dass alles sitzt — Rückgabewert
0 heißt startklar.

## Der Weg von Hand

Falls das Skript nicht passt, sind es vier Dinge:

**1.** `shared/fehlerbericht/lib/fehlerbericht.dart` unverändert nach
`lib/fehlerbericht.dart` der App kopieren.

**2.** In die `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0
  url_launcher: ^6.2.5
```

**3.** In `android/app/src/main/AndroidManifest.xml` direkt unter
`<manifest …>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Nicht überspringen, auch wenn die Zeile schon in `src/debug/` steht:
Release-Builds erben sie von dort nicht, und ohne sie scheitert jeder
Notion-Aufruf mit `Failed host lookup … errno = 7` — die App weicht dann
still auf den E-Mail-Versand aus.

**4.** In `lib/main.dart`:

```dart
import 'fehlerbericht.dart';

void main() => Fehlerbericht.runApp(
      appKey: 'meine_app',       // klein, ohne Leerzeichen, nie mehr ändern
      appName: 'Meine App',      // Anzeigename in Notion
      version: '1.0.0',          // optional
      builder: () => const MyApp(),
    );
```

und an der `MaterialApp`:

```dart
MaterialApp(
  navigatorKey: Fehlerbericht.navigatorKey,
  navigatorObservers: [Fehlerbericht.observer],
  builder: Fehlerbericht.wrap,
  // … alles Übrige unverändert
)
```

Mehr ist nicht nötig. Der Fehler-Button erscheint danach auf jedem
Screen, Abstürze werden von allein gemeldet.

## Bauen

```bash
flutter build apk --release --dart-define=NOTION_TOKEN=<token>
```

Ein Token gilt für alle Apps. Ohne Token läuft die App normal weiter und
öffnet für Berichte die E-Mail-App.

## Was in Notion passiert

Nichts, was jemand vorbereiten müsste. Beim ersten Bericht sucht sich die
App über ihren `appKey` in der Registry **📊 Apps** unter der Seite
**🐞 Fehlerzentrale**. Findet sie sich dort nicht, legt sie selbst ihre
Unterseite samt Datenbank an und trägt sich ein.

Einzige Voraussetzung, und die gilt einmalig für alle Apps: Die Seite
**🐞 Fehlerzentrale** muss mit der Notion-Integration geteilt sein
(`••• → Verbindungen`). Alle Unterseiten erben den Zugriff.

## Nützliche Zusätze

Bekannte, harmlose Platform-Meldungen ausfiltern, damit sie die
Datenbank nicht zumüllen (sie bleiben im Protokoll sichtbar):

```dart
Fehlerbericht.runApp(
  …
  ignorieren: const ['NetworkManager', 'connectivity_plus'],
);
```

Statt des schwebenden Buttons ein AppBar-Symbol:

```dart
Fehlerbericht.runApp(…, button: false);   // Overlay aus
AppBar(actions: const [FehlerButton()]);  // stattdessen hier
```

Protokollieren, damit Berichte aussagekräftig werden:

```dart
Fehlerbericht.logSeite('Dashboard');
Fehlerbericht.logAktion('Rezept gespeichert', kontext: {'id': '42'});
Fehlerbericht.logFehler('PDF fehlgeschlagen', kontext: 'Export', stack: s);
```

Die vollständige API und ein Abschnitt zur Fehlersuche stehen in
`README.md` daneben.
