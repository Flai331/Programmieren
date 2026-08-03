# Riegel — Design System

Design-Tokens und Komponenten-Vorlagen für die NFC-Riegel-App
(`Programmieren\nfc_riegel`).

## Idee

Nachtblaue Basis, Eisblau als Akzent, Bernstein für den Zustand „gesperrt".

Die Schriftfamilie ist bewusst dieselbe wie im Rechnungsgenerator-DS (DM Sans,
JetBrains Mono) — die Farbwelt trennt die Apps, die Typografie hält sie zusammen.

Drei Regeln, die alles andere erklären:

1. **Bernstein heißt gesperrt, sonst nichts.** Nie für Buttons, nie für Fehler. Eine
   Sperre ist gewollt und darf nicht wie ein Defekt aussehen.
2. **Offen ist der Ruhezustand.** Er bekommt keinen Glow, keine Signalfarbe — nur
   einen dezent eingefärbten Rahmen. Auffällig ist der gesperrte Zustand.
3. **Zahlen, die sich bewegen, laufen in Mono.** Countdown und Notfall-Code. Sonst
   zappelt die Zeile bei jedem Sekundenwechsel.

## Dateien

| Pfad | Inhalt |
|---|---|
| `tokens.css` | Alle Tokens: Farben, Typografie, Abstände, Radien, Schatten, Motion |
| `preview/colors-brand.html` | Akzent- und Zustandsfarben |
| `preview/colors-surfaces.html` | Flächen-Hierarchie und Textstufen |
| `preview/colors-semantic.html` | Erfolg, Fehler, Warnung, Info |
| `preview/type-scale.html` | Schriftskala inklusive Countdown und Code |
| `preview/spacing-radii.html` | Abstände, Radien, Schatten |
| `preview/components-status.html` | Statuskachel offen / gesperrt |
| `preview/components-controls.html` | Buttons, Modus-Wahl, Schieberegler |
| `preview/components-lists.html` | App-Auswahl, Navigationszeile, Warnbanner |
| `preview/screens-home.html` | Hauptscreen in beiden Zuständen |
| `preview/screens-blockscreen.html` | Sperrschirm mit und ohne Timer |
| `preview/screens-wizard.html` | Einrichtung, Schritt 3 und 4 |

## Umsetzung in der App

Die Tokens landen an drei Stellen:

- `lib/theme.dart` — Flutter-`ThemeData`, gespeist aus denselben Werten
- `lib/*.dart` — Screens verwenden ausschließlich Token-Werte, keine losen Hex-Codes
- `android/app/src/main/kotlin/com/klaas/nfc_riegel/BlockActivity.kt` und
  `TagWriteActivity.kt` — diese beiden Schirme laufen ohne Flutter-Engine und tragen
  ihre Farben als Konstanten im Kotlin-Code

Ändert sich ein Token, müssen Flutter- und Kotlin-Seite gemeinsam nachgezogen werden.
Eine geteilte Quelle gibt es nicht — der Sperrschirm muss auch dann stehen, wenn
Flutter gar nicht läuft.
