# DokuBox

Dokumente scannen, nummerieren, wiederfinden — ohne Sortieren.
Konzept: siehe [`../KONZEPT.md`](../KONZEPT.md).

**Alle Daten bleiben auf dem Gerät.** Keine Cloud, kein Konto, keine Kosten.

## Funktionsumfang (MVP, alle 6 Phasen umgesetzt)

- **Scannen** mit automatischer Randerkennung (ML Kit / VisionKit), mehrseitig → PDF
- **Leere Seiten: Trennen & löschen / Nur löschen / Aus** (Einstellungen oder direkt im Scan-Menü umschaltbar, wird gemerkt). *Trennen & löschen*: ein leeres Blatt trennt die Dokumente, jedes bekommt eine eigene Nummer. *Nur löschen*: alles bleibt ein Dokument, nur leere Seiten (z. B. leere Rückseiten) fliegen raus. Empfindlichkeit Vorsichtig/Normal/Großzügig. Das Desktop-Gegenstück für Scans vom Flachbett-/Einzugsscanner: [`../../scan_trenner`](../../scan_trenner).
- **PDF-Import** (kleiner Knopf über „Scannen“, mehrere Dateien auf einmal) und **„Teilen“ → DokuBox** aus Dateimanager, Mail oder Drive. Gedacht für Stapel vom Einzugsscanner, die der [`Scan-Trenner`](../../scan_trenner) am PC schon in einzelne PDFs zerlegt hat. Jede PDF läuft durch denselben Ablauf wie ein Kamera-Scan: Nummer → Text (vorhandene Textebene, sonst On-Device-OCR je Seite) → Regeln **und lokale KI** schlagen Absender, Datum, Typ, Titel und Tags vor → bestätigen.
- **Aufgaben & Erinnerungen** je Dokument: Aktion (Ausfüllen, Unterschreiben, Versenden, Bezahlen, Einreichen, Kündigen, Anrufen, Nachhaken, Prüfen, Original ablegen, Sonstiges) + Notiz („an Beihilfestelle per Mail“), Termin per Schnellwahl (heute Abend, morgen, in 3 Tagen, nächste Woche, …) oder frei, Wiederholung (monatlich, vierteljährlich, jährlich – nach dem Abhaken kommt die nächste). Übersicht ✓ oben mit Zähler (Überfällig, Heute, Nächste 7 Tage, Später, Erledigt), abhaken, +1 Tag/+1 Woche. „Jetzt ausfüllen / versenden / Bezahlt“ direkt aus der Aufgabe; nach Ausfüllen bzw. Versenden fragt die App, ob die Aufgabe erledigt ist. Benachrichtigung zeigt Aktion und Notiz, Antippen öffnet das Dokument.
- **Scanner im WLAN bedienen** („Scannen“ → *Mit dem Scanner (WLAN)*): DokuBox findet Netzwerk-Scanner per Bonjour/mDNS (eSCL/AirScan/Mopria – Epson, Canon, HP, Brother …) oder per eingetippter IP. Einzug oder Glas, **doppelseitig**, Farbe/Graustufen, Auflösung; zuletzt benutzter Scanner und Einstellungen werden gemerkt. Die Seiten laufen durch denselben Ablauf wie ein Kamera-Scan. **Doppelseitig:** nur ein beidseitig leeres Blatt trennt Dokumente, leere Rückseiten einseitiger Blätter werden einfach gelöscht – ein- und doppelseitige Blätter lassen sich mischen.
- **Ausfüllen & unterschreiben** (Detailansicht → ✎ bzw. „Ausfüllen / unterschreiben“): Werkzeug wählen (Text, Haken, Kreuz, Datum, Unterschrift), auf die Stelle tippen. Ziehen verschiebt, der runde Griff unten rechts ändert die Größe, zwei Finger zoomen. Farben Schwarz/Blau/Rot/Grün per Antippen; Text ändern, kopieren, löschen, Rückgängig; mehrseitige Formulare. **Speichern erzeugt eine ausgefüllte Kopie** – das Original bleibt unverändert; „Weiter ausfüllen“ jederzeit. Unterschriften kommen als Vorlagen vom PC (Scan-Trenner „✍ Unterschrift zeichnen…“ → WLAN) und liegen unter Einstellungen → „Unterschriften & Vorlagen“.
- **Original zum Kontrollieren:** Beim Bestätigen (Scan, Import, WLAN) und in der Detailansicht steht oben eine Vorschau der ersten Seite; Antippen öffnet das ganze Original in der App (blättern, zoomen). So lassen sich die Vorschläge von Regeln und KI direkt mit dem Dokument vergleichen. Extern öffnen: Detailansicht → ⋮ → „In anderer App öffnen“.
- **Vom PC per WLAN:** Im Scan-Trenner „📶 Per WLAN ans Handy…“ → Dateien wählen → QR-Code. In DokuBox *PDF importieren → Vom PC (WLAN)* scannt den Code, zeigt die Dateien und lädt sie direkt übers Heimnetz (kein Kabel, keine Cloud). Der Link hat einen Zufallsschlüssel, gilt max. 15 Minuten bzw. bis das Fenster am PC geschlossen wird; die App folgt nur Links auf private Adressen (192.168.x, 10.x, 172.16–31.x).
- **Firmen & Kategorien** (Einstellungen): eigene Kategorien anlegen (vorbelegt: Bank & Geldanlage, Versicherung, Energie & Wohnen, Gesundheit, Behörden & Steuern …) und Firmen zuordnen, z. B. Union Investment → Bank & Geldanlage, enviaM → Energie & Wohnen. Pro Firma zusätzliche Erkennungs-Stichwörter. Auf dem Startbildschirm filtert der Chip **„Kategorie“** alle Dokumente dieser Firmen. Beim Bestätigen lässt sich die Kategorie direkt setzen; für neue Firmen schlägt die lokale KI eine aus der eigenen Liste vor.
- **Automatische Nummernvergabe** `JJJJ-NNNN` — Nummer aufs Original schreiben, vorne in die Box legen
- **On-Device-OCR** (Google ML Kit) direkt nach dem Scan
- **Auto-Auslesen (lokal, kostenlos):** Datum, Dokumenttyp (Keyword-Regeln), IBAN/Versicherungsschein-/Kundennummern, lernende Absender-Wiedererkennung — Bestätigen-Screen zeigt alles vorausgefüllt
- **Volltextsuche** (SQLite FTS5) + Filter nach Typ und Jahr; Ergebnis zeigt Nummer + Box des Originals
- **Fristen & Erinnerungen** (Kündigungsfristen als lokale Benachrichtigung), Aufbewahrungsfristen mit **Ausmistliste**
- **Rechnungen & Erstattungen:** Beim Scannen werden Rechnungen automatisch klassifiziert – *zu bezahlen*, *wird abgebucht* (Lastschrift), *bezahlt* (Quittung/Kassenbon) oder *Gutschrift* – samt **Endbetrag** und **Fälligkeit** („zahlbar bis 05.11.2026", „innerhalb von 14 Tagen", Skonto → Netto-Ziel, „sofort fällig"). Für offene Rechnungen wird gleich eine **Zahlungserinnerung** X Tage vor Fälligkeit geplant.
  - **Arzt-, Zahnarzt-, Apotheken-, Physio-Rechnungen** (GOÄ/GOZ, Liquidation …) werden zum **Einreichen** vorgemerkt – bei den Stellen aus den Einstellungen: Krankenkasse, Private KV, **Beihilfe**, **Heilfürsorge**, Zusatzversicherung, Pflegekasse, BG, Arbeitgeber. Mehrere Stellen pro Rechnung möglich (z. B. Beihilfe + PKV).
  - Status je Einreichung: einzureichen → eingereicht → erstattet / teilweise erstattet (mit Betrag) / abgelehnt. Nach dem Einreichen erinnert die App nach X Wochen, falls die Erstattung ausbleibt.
  - Handwerker-/haushaltsnahe Rechnungen (Arbeitskosten, § 35a) und Spendenbescheinigungen → „Steuererklärung".
  - **Offene Posten** (💶-Symbol oben, mit Zähler): Zu bezahlen (Summe, Überfälliges rot) und Erstattungen (einzureichen / wartet auf Erstattung) mit Ein-Tipp-Aktionen „Bezahlt", „Eingereicht", „Erstattet". Filter „Zahlung" in der Liste.
- **Verschlüsseltes Backup** (AES-GCM, Passwort) als Export/Import, **App-Sperre** (Biometrie/Geräte-PIN)

## Bauen & Installieren (Android)

```bash
flutter pub get
dart run build_runner build   # nur nach Änderungen an lib/data/database.dart
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

Mindestanforderung: Android mit Google Play Services (ML Kit Dokumentenscanner).

**Signatur:** Release-APKs werden mit dem festen Schlüssel `android/app/dokubox-release.p12` signiert, damit sich jede neue Version als Update über die alte installieren lässt. Das Passwort liegt nur als GitHub-Secret `DOKUBOX_KEYSTORE_PASSWORD` vor (lokal ohne Passwort: Debug-Schlüssel). Fehlt das Secret, aktualisiert der Workflow das Release nicht.

## Tests & Analyse

```bash
flutter analyze
flutter test    # Extraktions-Regeln, Nummernvergabe, FTS-Suche, Repository
```

## Architektur

- `lib/data/` — Drift/SQLite-Datenbank (FTS5-Volltextindex), Repository. UUIDs, `updated_at`, Soft-Deletes: vorbereitet für späteren Cloud-Sync (Phase 7).
- `lib/extract/` — regelbasierte Extraktion + lernende Zuordnungen (pur, unit-getestet); `payment_extractors.dart` = Rechnungserkennung (dieselben Regeln wie `scan_trenner/rechnungen.py`)
- `lib/data/finance.dart` — Zahlungs-/Erstattungsstatus, Erstattungsstellen, Einstellungen
- `lib/scan/` — Scanner, PDF-Erzeugung, OCR
- `lib/ui/` — Startliste/Suche, Bestätigen-Screen, Detail, Ausmistliste, Einstellungen
- `lib/reminders/`, `lib/backup/`, `lib/lock/` — Benachrichtigungen, verschlüsseltes Backup, App-Sperre
