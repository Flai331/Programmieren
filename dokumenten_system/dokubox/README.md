# DokuBox

Dokumente scannen, nummerieren, wiederfinden — ohne Sortieren.
Konzept: siehe [`../KONZEPT.md`](../KONZEPT.md).

**Alle Daten bleiben auf dem Gerät.** Keine Cloud, kein Konto, keine Kosten.

## Funktionsumfang (MVP, alle 6 Phasen umgesetzt)

- **Scannen** mit automatischer Randerkennung (ML Kit / VisionKit), mehrseitig → PDF
- **Leerseiten trennen & löschen:** Ein leeres Blatt im Stapel trennt die Dokumente, leere Seiten werden nicht gespeichert. Jedes Dokument bekommt eine eigene Nummer und wird einzeln bestätigt. Ein/aus und Empfindlichkeit (Vorsichtig/Normal/Großzügig) in den Einstellungen. Das Desktop-Gegenstück für Scans vom Flachbett-/Einzugsscanner: [`../../scan_trenner`](../../scan_trenner).
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
