# DokuBox – Ausbauplan

Stand: November 2026. Entstanden aus einer Ideensammlung, einem Planungsdurchlauf
über den Code und den Entscheidungen des Nutzers. Reihenfolge = Etappen.

## Entscheidungen des Nutzers

| Thema | Entscheidung |
|---|---|
| Stapel sortieren | Erst alle Dokumente bestätigen, dann Nummern lückenlos **nach Dokumentdatum** (ältestes zuerst, ohne Datum ans Ende) vergeben; danach **Nummernliste** mit Vorschaubild, Datum, Absender, Titel – auch als PDF. |
| Geräte-Abgleich (5) | Alle Geräte (Handy, Tablet, Laptop) sehen alles. **Haupt-Handy vergibt die Nummern**, andere Geräte zeigen „vorläufig“ bis zum Abgleich. |
| Laptop | **DokuBox als Windows-App** (Flutter Desktop) mit Abgleich. Ersetzt den geplanten PC-Spiegel im Scan-Trenner. Scan-Trenner bleibt für den Einzugsscanner. |
| GiroCode (12) | Am Laptop/Tablet groß anzeigen **und** als Bild an die Banking-App teilen. |
| PC-Ordner (19) | Windows-App pflegt zusätzlich einen Ordner mit lesbaren Namen (`Ablage/<Jahr>/<Kategorie>/<Nummer> <Firma> <Titel>.pdf`). Startet mit Windows, gleicht im Hintergrund ab. |
| Backup (17) | Automatisch, verschlüsselt, **auf den Laptop** und zusätzlich **USB-Stick/externe Platte**, wenn eingesteckt. Abgeleiteter Schlüssel im geschützten Schlüsselspeicher. |
| Meine Daten (13) | Mehrere Personen, auf allen Geräten. IBAN in Listen maskiert. |
| Widerspruchsfrist (9) | Bundesland in den Einstellungen wählbar; Erinnerung 7 Tage vorher. |
| Steuer-Mappe (3) | Alle Kategorien (§35a, Spenden, Krankheitskosten, Versicherungen/Vorsorge, Lohnsteuerbescheinigung, Werbungskosten, Kinder, Vermietung, Sonstiges …). Erstellung **am Laptop**, verlustfrei (keine Bild-Seiten). |
| Widget (16) | **Zurückgestellt**, später evtl. |
| Suche mit Sprache/Frage | Nicht gewünscht. |

## Etappen

| Etappe | Inhalt |
|---|---|
| **S** | Stapel nach Datum sortieren + Nummernliste (siehe oben) |
| **E0 Fundament** | Schema v6 (alle Daten für 1–4, 6–15 auf einmal), Migrationstest mit gemeinsamer Downgrade-Hilfe, Backup-Umbau (Restore in `BackupService`, Manifest, Streaming-ZIP, Ordner `anhaenge`), PDF-Bericht-Baustein (`lib/reports/report_pdf.dart`), Referenz-Abgleich (`lib/extract/ref_matching.dart`), `ensureAutoTask(origin)` |
| **E1 Vorgänge & Fristen** | 1 Vorgänge/Mappen, 2 automatisch verknüpfen (nur Vorschlag), 9 Widerspruchsfrist, 11 Garantie (Aufbewahrung ≥ Garantieende), 6 Dubletten (Hash, RGNR+Firma, Textähnlichkeit) |
| **E2 Papier** | 7 Box-Inhaltsliste, 18 Vernichtungs-Protokoll |
| **E3 Geld** | 4 Verträge & Kosten, 10 Erstattungs-Statistik, 12 GiroCode |
| **E4 Ausfüllen & Versenden** | 13 Meine Daten, 8 Anhänge/Fotos, 14 E-Mail-Vorlagen (an Firmen), 15 Deckblatt/Brief DIN 5008 |
| **E5 Windows-App** | Flutter-Desktop-Build, Funktionen ohne Kamera/ML Kit/KI; Kopplung per QR, verschlüsselter Transport (AES-GCM) im WLAN; PC-Ordner (19), Suche (20), Backup-Empfang + USB (17), Steuer-Mappe verlustfrei (3), Autostart/Hintergrund |
| **E6 Geräte-Abgleich** | 5: Schema v7 (Geräte/Mitglieder, Zuweisung, Sync-Status, `document_tags` mit ID), Abgleich „letzte Änderung gewinnt“ + Dateien per sha256, Haupt-Handy vergibt Nummern, Firmen zusammenführen, Aufgaben zuweisen |
| später | 16 Widget |

## Querschnitt

- Neue Tabellen: UUID, `updatedAt`, `deletedAt`; Verknüpfungstabellen mit eigener ID (für den Abgleich).
- Backup/Restore enthält neue Tabellen und Ordner; Kopplungsgeheimnisse/Schlüssel nicht.
- Alles lokal bzw. im eigenen WLAN, verschlüsselt; nur private IP-Adressen.
- Widget/Benachrichtigungen ohne Beträge, IBAN oder Inhalte.
- Jede Etappe: bestehende Tests grün, neue Unit-/Repository-Tests, README/KONZEPT nachziehen.
