# DokuBox

Dokumente scannen, nummerieren, wiederfinden — ohne Sortieren.
Konzept: siehe [`../KONZEPT.md`](../KONZEPT.md).

**Alle Daten bleiben auf dem Gerät.** Keine Cloud, kein Konto, keine Kosten.

## Funktionsumfang (MVP, alle 6 Phasen umgesetzt)

- **Scannen** mit automatischer Randerkennung (ML Kit / VisionKit), mehrseitig → PDF
- **Automatische Nummernvergabe** `JJJJ-NNNN` — Nummer aufs Original schreiben, vorne in die Box legen
- **On-Device-OCR** (Google ML Kit) direkt nach dem Scan
- **Auto-Auslesen (lokal, kostenlos):** Datum, Dokumenttyp (Keyword-Regeln), IBAN/Versicherungsschein-/Kundennummern, lernende Absender-Wiedererkennung — Bestätigen-Screen zeigt alles vorausgefüllt
- **Volltextsuche** (SQLite FTS5) + Filter nach Typ und Jahr; Ergebnis zeigt Nummer + Box des Originals
- **Fristen & Erinnerungen** (Kündigungsfristen als lokale Benachrichtigung), Aufbewahrungsfristen mit **Ausmistliste**
- **Verschlüsseltes Backup** (AES-GCM, Passwort) als Export/Import, **App-Sperre** (Biometrie/Geräte-PIN)

## Bauen & Installieren (Android)

```bash
flutter pub get
dart run build_runner build   # nur nach Änderungen an lib/data/database.dart
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

Mindestanforderung: Android mit Google Play Services (ML Kit Dokumentenscanner).

## Tests & Analyse

```bash
flutter analyze
flutter test    # Extraktions-Regeln, Nummernvergabe, FTS-Suche, Repository
```

## Architektur

- `lib/data/` — Drift/SQLite-Datenbank (FTS5-Volltextindex), Repository. UUIDs, `updated_at`, Soft-Deletes: vorbereitet für späteren Cloud-Sync (Phase 7).
- `lib/extract/` — regelbasierte Extraktion + lernende Zuordnungen (pur, unit-getestet)
- `lib/scan/` — Scanner, PDF-Erzeugung, OCR
- `lib/ui/` — Startliste/Suche, Bestätigen-Screen, Detail, Ausmistliste, Einstellungen
- `lib/reminders/`, `lib/backup/`, `lib/lock/` — Benachrichtigungen, verschlüsseltes Backup, App-Sperre
