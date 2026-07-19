# DokuBox — Dokumenten-System ohne Sortieren

**Konzept & Umsetzungsplan** · Stand: Juli 2026

---

## 1. Das Problem

Unterlagen (Versicherungen, Bank, Behörden, Verträge, Rechnungen) stapeln sich. Die klassische Lösung — mehrere Themenordner mit Registern — kostet genau die Zeit, die vermieden werden soll:

- **Einsortieren** dauert: Für jedes Blatt überlegen, in welchen Ordner und hinter welches Register es gehört.
- **Wiederfinden** dauert: War der Bescheid unter „Versicherung" oder unter „Auto"? Ordner durchblättern.
- **Mehrere Ordner** nehmen Platz weg und machen beides noch langsamer.

**Ziel:** Alle Dokumente digital durchsuchbar auf dem Handy, Originale bleiben erhalten, und sowohl Ablegen als auch Wiederfinden dauern unter einer Minute — ohne jemals zu sortieren.

## 2. Das System: „Nummer statt Ordner"

Das Grundprinzip: **Physisch wird chronologisch gestapelt, niemals thematisch sortiert. Das Ordnen übernimmt komplett die App.**

### Der Ablauf für jedes neue Dokument (~60 Sekunden)

1. **Scannen:** Dokument mit der App fotografieren (automatische Randerkennung, mehrseitig möglich).
2. **Nummer:** Die App vergibt automatisch die nächste laufende Nummer, z. B. `2026-0142`.
3. **Beschriften:** Nummer mit Bleistift (oder Nummernstempel) oben rechts aufs Original schreiben.
4. **Ablegen:** Original einfach **vorne/oben** in die eine Archivbox legen. Fertig. Nie sortieren.
5. **Bestätigen:** Die App hat Datum, Absender, Typ und Tags bereits vorausgefüllt — kurz kontrollieren, ggf. korrigieren, speichern.

### Wiederfinden (~30 Sekunden)

1. In der App suchen — Volltext („Beitragserhöhung"), Tag („KFZ-Versicherung") oder Absender.
2. Meist reicht das digitale PDF schon aus. Wird das **Original** gebraucht: Die App zeigt Nummer + Box (z. B. `2026-0142 · Box 2026`).
3. Da die Box chronologisch gestapelt ist, liegt die Nummer genau da, wo sie sein muss — in Sekunden gegriffen.

### Physische Ausstattung (Einkaufsliste, einmalig ~20–40 €)

| Was | Wozu |
|---|---|
| 1–2 Archiv-/Stülpdeckelboxen (DIN A4) | Die chronologische Ablage. Eine Box pro Jahr oder pro ~500 Blatt. Außen beschriften: „2026 · Nr. 0001–…" |
| Bleistift oder Paginierstempel | Nummer aufs Original. Bleistift reicht völlig. |
| 1 Dokumentenmappe „Wichtig im Original" | Ausnahmen (siehe unten), die man schnell greifbar braucht. |
| Optional: 1 Eingangskorb | Für Post, die noch nicht gescannt ist. Wird z. B. 1× pro Woche abgearbeitet. |

### Sonderfälle

- **Ausnahmen-Mappe „Wichtig im Original":** Urkunden (Geburt, Heirat), Zeugnisse, Ausweise, notarielle Verträge — Dinge mit Originalpflicht oder häufigem Zugriff. Werden trotzdem gescannt und nummeriert (Lagerort in der App: „Mappe" statt „Box").
- **Dickes/Gebundenes** (z. B. Versicherungspolicen-Hefte): nur Deckblatt + relevante Seiten scannen, Lagerort vermerken.
- **Bestandsdokumente** (der alte Papierberg): in kleinen Sprints nachscannen (z. B. 20 Min./Tag oder 1 Stunde/Wochenende). Reihenfolge ist egal — genau das ist der Vorteil des Systems. Alte Themenordner können danach aufgelöst werden.
- **Jährliches Ausmisten:** Die App führt Aufbewahrungsfristen pro Dokumenttyp und listet einmal im Jahr alles Ablaufbare — Original raussuchen, schreddern, in der App als „vernichtet" markieren (der Scan bleibt).

## 3. Die App „DokuBox" (Flutter)

Android zuerst (APK wie beim Sauerteig-Planer), iOS-fähig durch Flutter und die gewählten Pakete.

### Leitprinzipien

- **Datenschutz zuerst:** Alles bleibt auf dem Handy. Keine Cloud-KI, kein Server, keine laufenden Kosten. (Entschieden — Cloud-Sync kommt später als optionale Phase 2, siehe unten.)
- **Der Nutzer kontrolliert nur noch:** Nach jedem Scan sind die Metadaten automatisch vorausgefüllt; ein Bestätigen-Screen zeigt sie zur Kontrolle.
- **Sync-fähig gebaut:** Auch wenn das MVP lokal ist, ist die Architektur von Anfang an auf spätere Synchronisation (Familie, Zweitgerät) ausgelegt.

### MVP-Features

1. **Scannen** — `flutter_doc_scanner` (nutzt ML Kit Document Scanner auf Android, VisionKit auf iOS): automatische Rand-/Eckenerkennung, Zuschnitt, Filter, mehrseitig, Ausgabe als PDF/JPEG.
2. **Nummernvergabe** — automatisch fortlaufend im Schema `JJJJ-NNNN` (z. B. `2026-0142`), Zähler pro Jahr. Nummer wird groß angezeigt („aufs Original schreiben"), plus Lagerort-Auswahl (Box 2026 / Mappe / …).
3. **OCR** — `google_mlkit_text_recognition`: on-device, offline, kostenlos. Läuft direkt nach dem Scan im Hintergrund.
4. **Auto-Auslesen (kostenlos & lokal)** — füllt den Bestätigen-Screen vor:
   - **Datumserkennung** im OCR-Text (deutsche Formate: `14.03.2026`, `14. März 2026`).
   - **Keyword-Regeln** für den Dokumenttyp: „Beitragsrechnung", „Kontoauszug", „Bescheid", „Kündigung", „Police" …
   - **Muster-Erkennung:** IBAN, Versicherungsschein-/Kunden-/Steuernummern → als durchsuchbare Referenzen gespeichert.
   - **Lernende Zuordnungen:** Erkennt bekannte Absender im Text wieder (z. B. „HUK-COBURG") und schlägt automatisch dieselben Tags/Typen/Fristen wie beim letzten Dokument dieses Absenders vor. Je länger man die App nutzt, desto weniger muss man korrigieren.
5. **Bestätigen-Screen** — ein Screen nach dem Scan: Datum ✓, Absender ✓, Typ ✓, Tags ✓, Frist (optional) → „Speichern". Ziel: im Normalfall 0–1 Korrekturen.
6. **Suche** — Volltextsuche über den gesamten OCR-Text (SQLite **FTS5**), kombiniert mit Filtern: Tag, Absender, Typ, Jahr, Lagerort. Ergebnis zeigt PDF-Vorschau + physische Fundstelle (Nummer + Box).
7. **Fristen & Erinnerungen** — Kündigungsfristen und Wiedervorlagen als lokale Benachrichtigung (`flutter_local_notifications`, bekannt aus dem Sauerteig-Planer). Aufbewahrungsfristen pro Typ hinterlegbar → Jahresliste „Kann vernichtet werden".
8. **Sicherheit & Backup** —
   - App-Sperre mit PIN/Biometrie (`local_auth`).
   - Backup-Export als verschlüsselte ZIP (alle PDFs + Datenbank) via `share_plus` → auf PC/USB/eigene Cloud sichern. Import-Funktion zum Wiederherstellen/Gerätewechsel.

### Später (Phase 2, optional)

- **Cloud-Sync + Familien-Sharing** über Supabase: Ende-zu-Ende-verschlüsselte Ablage, gemeinsames Archiv für Partner/Familie, Mehrgeräte-Zugriff. (Erst dann wird ein Supabase-Projekt angelegt.)
- **E-Mail-/PDF-Import:** digital erhaltene Rechnungen direkt einlesen (ohne Papier, bekommen trotzdem eine Nummer mit Lagerort „digital").
- **On-Device-KI (Gemini Nano / ML Kit GenAI):** auf unterstützten Geräten (Pixel 8+, neuere Samsung-Flaggschiffe) als kostenlose lokale KI für noch bessere Vorschläge und Kurz-Zusammenfassungen — weiterhin ohne dass Daten das Handy verlassen.

## 4. Technische Architektur

### Pakete (geprüft, aktiv gepflegt — Stand Juli 2026)

| Paket | Zweck |
|---|---|
| `flutter_doc_scanner` | Dokumentenscan mit Randerkennung (ML Kit / VisionKit), Android minSdk 21, iOS 13+ |
| `google_mlkit_text_recognition` | On-Device-OCR (verifizierter Publisher) |
| `drift` (auf SQLite) | Typsichere lokale Datenbank inkl. FTS5-Volltextindex |
| `pdf` | PDF-Erzeugung (bekannt aus sauerteig_planer) |
| `flutter_local_notifications` | Fristen-Erinnerungen (bekannt aus sauerteig_planer) |
| `share_plus`, `path_provider` | Backup-Export, Dateipfade (bekannt aus sauerteig_planer) |
| `local_auth` | PIN/Biometrie-Sperre |
| `uuid` | Sync-fähige Primärschlüssel |
| `archive` + `cryptography`/`encrypt` | Verschlüsselte Backup-ZIP |

### Datenmodell (Skizze)

```
documents
  id            TEXT (UUID, PK)
  doc_number    TEXT  -- "2026-0142", unique
  title         TEXT
  doc_date      DATE  -- Datum des Dokuments (nicht des Scans)
  scanned_at    DATETIME
  correspondent_id  TEXT (FK)
  doc_type      TEXT  -- Rechnung, Bescheid, Vertrag, Police, Kontoauszug, ...
  storage_location  TEXT  -- "Box 2026" | "Mappe Wichtig" | "digital" | "vernichtet"
  pdf_path      TEXT  -- Datei im App-Dokumentenverzeichnis
  ocr_text      TEXT  -- → FTS5-Index
  retention_until   DATE?  -- Aufbewahrung bis (für Jahres-Ausmistliste)
  reminder_at   DATETIME? -- Wiedervorlage/Kündigungsfrist
  updated_at    DATETIME  -- für späteren Sync
  deleted_at    DATETIME? -- Soft-Delete, für späteren Sync

correspondents (Absender)
  id, name, aliases (Erkennungs-Keywords), default_type, default_tags, updated_at

tags                  id, name, color, updated_at
document_tags         document_id, tag_id  (n:m)
extracted_refs        document_id, kind (IBAN|VSNR|KDNR|...), value  -- durchsuchbar
counters              year, last_number  -- Nummernvergabe
```

### Sync-Vorbereitung (ab Tag 1, ohne Mehraufwand im MVP)

- UUIDs als Primärschlüssel (nie Auto-Increment-IDs über Geräte hinweg).
- `updated_at` überall + Soft-Deletes (`deleted_at`) statt echtem Löschen.
- **Repository-Pattern:** UI spricht nur mit `DocumentRepository`-Interfaces; die lokale Drift-Implementierung kann später um eine Sync-Schicht (Supabase) ergänzt werden, ohne die App umzubauen.
- PDFs als einzelne Dateien (je Dokument) → später einzeln synchronisierbar.

### Projektstruktur

```
dokumenten_system/
  KONZEPT.md          ← dieses Dokument
  dokubox/            ← Flutter-Projekt (entsteht in Phase 1)
    lib/
      data/           (drift-Datenbank, Repositories)
      scan/           (Scan-Flow, OCR)
      extract/        (Regeln, lernende Zuordnungen)
      search/         (FTS5-Suche, Filter)
      documents/      (Liste, Detail, Bestätigen-Screen)
      reminders/      (Fristen)
      backup/         (Export/Import)
```

## 5. Umsetzungs-Roadmap

Jede Phase endet mit einem nutzbaren Stand (installierbare APK).

| Phase | Inhalt | Nutzen danach |
|---|---|---|
| **1** | Projekt-Setup, Datenmodell (drift + FTS5, UUIDs), Grundgerüst mit Dokumentenliste | Fundament steht |
| **2** | Scan-Flow (`flutter_doc_scanner`) → PDF speichern + automatische Nummernvergabe + Lagerort | **Ab hier ist das System benutzbar:** scannen, nummerieren, ablegen |
| **3** | OCR im Hintergrund + Volltextsuche mit Filtern | Wiederfinden funktioniert |
| **4** | Bestätigen-Screen mit Auto-Auslesen (Datums-/Keyword-/Muster-Regeln, lernende Absender-Zuordnungen), Tags & Korrespondenten-Verwaltung | „Nur noch kontrollieren" |
| **5** | Fristen & Erinnerungen, Aufbewahrungsfristen + Jahres-Ausmistliste | Nichts verpassen, Boxen bleiben schlank |
| **6** | Verschlüsseltes Backup (Export/Import), App-Sperre (PIN/Biometrie) | Sicher & gerätewechselfest — **MVP komplett** |
| **7** | *(Phase 2)* Supabase-Sync + Familien-Sharing; optional E-Mail-Import und Gemini Nano on-device | Familie nutzt ein gemeinsames Archiv |

## 6. Aufbewahrungsfristen (Voreinstellung in der App)

Richtwerte für Privatpersonen in Deutschland — in der App als Standard-Fristen pro Dokumenttyp hinterlegt, anpassbar. *(Keine Rechtsberatung.)*

| Dokumenttyp | Empfehlung |
|---|---|
| Kontoauszüge | 3 Jahre |
| Handwerker-/Dienstleistungsrechnungen | mind. 2 Jahre (Gewährleistung: bis 5) |
| Kaufbelege mit Garantie | Garantiedauer |
| Steuerbescheide + Unterlagen | mind. 4 Jahre, besser dauerhaft |
| Versicherungspolicen | Vertragslaufzeit + Verjährung |
| Ärztliche Unterlagen, Rentennachweise | dauerhaft |
| Urkunden, Zeugnisse, notarielle Verträge | lebenslang (→ Mappe „Wichtig im Original") |

## 7. Offene Punkte (vor/während Phase 1 zu klären)

- **App-Name:** „DokuBox" ist Arbeitstitel — Alternativen willkommen.
- **Backup-Erinnerung:** Soll die App z. B. monatlich an den Backup-Export erinnern? (Empfehlung: ja.)
- **Papierkorb-Verhalten:** Gelöschte Scans X Tage aufbewahren vor endgültigem Löschen? (Empfehlung: 30 Tage.)
- **iOS:** Zunächst nur Android-APK wie gewohnt; iOS später über TestFlight/„Zum Home-Bildschirm"-Alternative?
