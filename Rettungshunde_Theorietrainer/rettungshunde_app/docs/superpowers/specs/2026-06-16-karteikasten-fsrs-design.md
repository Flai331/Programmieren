# Karteikasten (FSRS Spaced Repetition) — Design Spec

**Datum:** 2026-06-16
**App:** Wuff & Wissen (rettungshunde_app)
**Status:** Genehmigt (Design), bereit für Implementierungsplan

## 1. Ziel

Neuer 4. Lernmodus „Karteikasten" mit echtem Spaced-Repetition-Scheduling nach
**FSRS** (Free Spaced Repetition Scheduler — heutiger Anki-Standard). Karten
werden zeitlich optimal wiederholt; das Tempo neuer Karten passt sich an ein
**Prüfungsdatum** (Hauptziel) und einen **Zeitdeckel pro Tag** an. Der bestehende
gewichtete Lernmodus bleibt unverändert als freies Üben.

## 2. Festgelegte Entscheidungen

| Thema | Entscheidung |
|---|---|
| Algorithmus | FSRS via `fsrs` pub-Package (Default-Parameter, Retention 0.9 fix in v1) |
| Bewertung | Hybrid: falsch → `Again` automatisch; richtig → Nutzer wählt `Hard`/`Good`/`Easy` (Good vorausgewählt) |
| Integration | Neuer 4. Modus auf Home; Lernmodus unverändert |
| Tempo neue Karten | Prüfungsdatum + max. Minuten/Tag, beides optional, kombiniert |
| Gating | Wie Lernmodus: Gratis = `is_free`-Fragen, Pro = alle; Suchhundtyp-Filter aktiv |
| Fällige Wiederholungen | Immer alle, kein Zeitdeckel |

## 3. Abhängigkeit

`pubspec.yaml` → `dependencies: fsrs: ^2.0.1`. Pure Dart (einzige Abhängigkeit
`meta`), SDK `^3.3.0` kompatibel mit App-SDK `^3.12.0`, keine Native-Deps →
funktioniert auf Android **und** Web.

Relevante API:
```dart
final scheduler = Scheduler(desiredRetention: 0.9); // sonst Defaults
final card = await Card.create();                   // neue Karte, sofort fällig
final (:card, :reviewLog) = scheduler.reviewCard(card, Rating.good);
card.due;            // nächster Fälligkeitszeitpunkt (DateTime, UTC)
card.toMap();        // Serialisierung → Speicherung
Card.fromMap(map);   // Deserialisierung
// Rating.again==1, Rating.hard==2, Rating.good==3, Rating.easy==4
```

## 4. Datenmodell (DB-Version 2 → 3)

`DatabaseService.dbVersion` von 2 auf 3. `_onUpgrade` für `oldVersion < 3`
erzeugt zwei neue Tabellen (additiv, bestehende Daten unberührt). `_onCreate`
legt sie für Neuinstallationen ebenfalls an.

```sql
CREATE TABLE srs_cards(
  question_id   INTEGER PRIMARY KEY,
  card_json     TEXT    NOT NULL,        -- card.toMap() als JSON
  due           TEXT,                    -- card.due ISO8601 UTC (Query-Index)
  state         INTEGER NOT NULL DEFAULT 1, -- FSRS State.value: 1 learning, 2 review, 3 relearning
  introduced_at TEXT                     -- Zeitpunkt der ersten Bewertung

-- Hinweis: das fsrs-Package kennt KEINEN "new"-Status. "Neu/noch nie gezogen"
-- = es existiert KEINE Zeile in srs_cards für diese question_id. Eine Zeile wird
-- erst bei der ersten Bewertung angelegt.
);
CREATE INDEX idx_srs_due ON srs_cards(due);

CREATE TABLE srs_review_log(
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id INTEGER NOT NULL,
  rating      INTEGER NOT NULL,          -- 1..4
  reviewed_at TEXT    NOT NULL,
  elapsed_ms  INTEGER                    -- Antwortdauer, für Tempo-Schätzung
);
```

Begründung JSON-Blob: entkoppelt von der exakten Feldstruktur des `Card`-Objekts
(Vorwärtskompatibilität bei Package-Updates). `due`/`state`/`introduced_at` sind
denormalisiert herausgezogen, weil danach gefiltert/gezählt wird.

`progress`-Tabelle bleibt: Karteikasten-Antworten rufen weiterhin
`ProgressService.recordAnswer` → **Statistik vereinheitlicht** (Gesehen/Quote
gelten modusübergreifend).

Neue Settings-Keys (`settings`-Tabelle, via `AppConstants`):
- `srs_exam_date` — ISO-Datum oder leer
- `srs_daily_minutes` — Ganzzahl oder leer
- `srs_intro_date` — Datum (yyyy-MM-dd) des letzten Einführungstages
- `srs_intro_count` — Anzahl heute schon eingeführter neuer Karten

## 5. SrsService (neuer Service)

Verantwortlich: Kartenzustand laden/speichern, Rating anwenden, Tageslimit +
Tempo berechnen, Queue für heute bauen.

Kernmethoden:
- `Future<Card> _load(int questionId)` — aus `srs_cards` (JSON → `Card.fromMap`)
  oder neue `Card(cardId: questionId)` falls keine Zeile existiert.
- `Future<void> review(int questionId, Rating rating, {int? elapsedMs})` —
  `scheduler.reviewCard(card, rating, reviewDuration: elapsedMs)`, persistiert
  `card.toMap()` + `due` (`card.due`) + `state` (`card.state.value`), setzt
  `introduced_at` falls Zeile neu, schreibt `srs_review_log`, ruft zusätzlich
  `progress.recordAnswer(questionId, rating != Rating.again)`.
- `Future<int> dueCount(scope)` — Zeilen mit `due <= now` im Scope (Existenz =
  eingeführt).
- `Future<int> remainingNewCount(scope)` — Fragen im Scope **ohne** `srs_cards`-Zeile.
- `Future<int> newAllowedToday(scope)` — siehe §6.
- `Future<List<Question>> buildTodayQueue(scope)` — fällige Wiederholungen
  (nach `due` aufsteigend) + bis zu `newAllowedToday` neue (Reihenfolge: nach
  `id`/Kategorie). **Reihenfolge: Wiederholungen zuerst, dann neue.**
- `Future<DateTime?> nextDue(scope)` — frühestes `due` für „Fertig"-Anzeige.
- `Future<void> resetSrs()` — `srs_cards` + `srs_review_log` leeren, Intro-Settings
  zurücksetzen.

„Scope" = `repo.questions(freeOnly: !isPro, excludeCategories: discipline.excluded)`
→ derselbe Fragenpool wie der Lernmodus.

## 6. Tempo-Logik (neue Karten heute)

```
heute        = Datumsteil(now)
faellig      = dueCount(scope)                       // alle, kein Deckel
rest_neu     = remainingNewCount(scope)

// Hauptziel Prüfungsdatum
wenn srs_exam_date gesetzt:
    tage_bis   = max(1, (exam_date - heute).inDays)
    intro_tage = max(1, ceil(tage_bis * 0.8))        // letzte 20% nur Wiederholen
    ziel_neu   = ceil(rest_neu / intro_tage)
sonst:
    ziel_neu   = 20                                  // Default ohne Datum

// Zeitdeckel
wenn srs_daily_minutes gesetzt:
    sek_karte  = avg(elapsed_ms letzte ~50 logs) / 1000, Fallback 20s, min 5s
    budget     = floor(daily_minutes*60 / sek_karte)
    deckel_neu = max(0, budget - faellig)            // Fällige haben Vorrang
sonst:
    deckel_neu = unendlich

// schon heute eingeführt (über App-Neustarts hinweg)
wenn srs_intro_date == heute: schon = srs_intro_count  sonst schon = 0 (reset)

neu_heute = clamp( min(ziel_neu, deckel_neu) - schon , 0 , rest_neu )
```

Effekt: näher an der Prüfung → `ziel_neu` steigt; Zeitdeckel bremst, wenn fällige
Wiederholungen den Tag füllen. **Nach** dem Prüfungsdatum (`tage_bis` würde ≤0):
`intro_tage = 1` → alles Restliche schnellstmöglich einführen (durch `deckel_neu`
noch begrenzt). Jede Einführung erhöht `srs_intro_count`; bei neuem Tag Reset.

## 7. Session-Ablauf (KarteikastenScreen)

1. `buildTodayQueue` laden. Leer → „Fertig für heute"-Ansicht mit `nextDue`
   („nächste Wiederholung in N Tagen / am <Datum>"); wenn gar keine Karten im
   Scope/Prüfungsdatum fehlt → passender Hinweis.
2. Pro Karte: `QuestionCard` (wiederverwendet) → „Antwort prüfen".
3. Nach Aufdecken (Erklärung sichtbar):
   - MC **falsch** → Bewertung automatisch `Again`, Button „Weiter".
   - MC **richtig** → Zeile mit `Schwer` / `Gut` (hervorgehoben) / `Leicht`.
4. Bewertung → `SrsService.review(...)` (mit gemessener `elapsed_ms` seit
   Kartenanzeige) → nächste Karte.
5. FSRS-Lernschritte: `Again`/`Hard` machen Karten innerhalb von Minuten erneut
   fällig → erscheinen ggf. nochmals in derselben Session (Queue prüft `due<=now`).
6. Ende, wenn keine Karte mehr `due<=now`.

## 8. UI-Änderungen

- **home_screen.dart:** 4. `_ModeCard` „Karteikasten" (eigene Akzentfarbe, z.B.
  `successColor`/violett), Untertitel als Live-Badge „X fällig · Y neu". Lädt
  Zahlen via `SrsService` (FutureBuilder).
- **karteikasten_screen.dart (neu):** Session-Screen analog `_LearnSession`,
  Fortschritt „erledigt / heute gesamt", Bewertungs-Buttons, „Fertig"-Ansicht.
- **settings_screen.dart:** neuer Abschnitt „KARTEIKASTEN":
  - Prüfungsdatum (`showDatePicker`, optional, löschbar)
  - Max. Minuten/Tag (Eingabe/Slider, optional)
  - „Karteikasten zurücksetzen" (Bestätigungsdialog → `resetSrs`)
- **stats_screen.dart:** kleine Sektion „Karteikasten" — Karten je Zustand
  + „heute fällig". Zustands-Mapping: **neu** = keine `srs_cards`-Zeile;
  **lernend** = `state` 1 oder 3 (learning/relearning); **reif** = `state` 2 (review).
- **main.dart:** `SrsService` als Provider registrieren.

## 9. Bewusst NICHT in v1 (YAGNI)

FSRS-Parameter-Optimierung/Training, Retention-Regler, Fälligkeits-Prognosegraph,
Undo letzter Bewertung, Karten-Suspendieren, mehrere Decks. Retention fest 0.9,
Default-Lernschritte (1 min / 10 min).

## 10. Datei-Änderungsliste

| Datei | Änderung |
|---|---|
| `pubspec.yaml` | `fsrs: ^2.0.1` |
| `lib/utils/app_constants.dart` | Settings-Keys, dbVersion-Konstante prüfen, ggf. Akzentfarbe |
| `lib/services/database_service.dart` | dbVersion 3, `_onCreate` + `_onUpgrade` neue Tabellen |
| `lib/services/srs_service.dart` (neu) | FSRS-Wrapper, Tempo, Queue |
| `lib/models/srs_card.dart` (neu, optional) | Hülle um `Card` + Meta |
| `lib/main.dart` | Provider `SrsService` |
| `lib/screens/home_screen.dart` | 4. Modus-Kachel + Badge |
| `lib/screens/karteikasten_screen.dart` (neu) | Session + Bewertung |
| `lib/screens/settings_screen.dart` | Abschnitt KARTEIKASTEN |
| `lib/screens/stats_screen.dart` | SRS-Zustandsanzeige |
| `lib/build_info.dart` + `pubspec.yaml` | Build-Nr. erhöhen vor Release (`catalogVersion` bleibt unberührt) |

## 11. Testplan

- Unit: Tempo-Logik (`newAllowedToday`) — Fälle: kein Datum/keine Zeit; nur Datum;
  nur Zeit; beides; nach Prüfungsdatum; Tageslimit-Reset über Datumswechsel.
- Unit: `SrsService.review` — neue Karte bekommt `introduced_at`, `due` steigt bei
  `Good`, `Again` macht früh wieder fällig; Persistenz JSON round-trip
  (`Card.fromMap(card.toMap())`).
- Migration: DB v2 → v3 erzeugt Tabellen, Bestandsdaten (`progress`) intakt.
- Manuell: Home-Badge zählt korrekt; Session-Flow falsch/richtig; „Fertig"-Ansicht;
  Gating (Gratis nur Free-Fragen); Web + Android.

## 12. Risiken / offene Punkte

- **Zeit-Schätzung** anfangs ungenau (wenig `elapsed_ms`-Daten) → Fallback 20 s,
  konvergiert mit Nutzung.
- **`Card.toMap` Feldnamen** package-spezifisch → ausschließlich über JSON-Blob
  speichern, nicht auf interne Felder verlassen (außer `due`/`state` aus dem
  Card-Objekt gelesen).
- **Zeitzonen:** `card.due` ist UTC; Tagesvergleiche konsequent lokal/`toLocal()`.
- FSRS-Default-Parameter (untrainiert) liefern brauchbare, nicht individuell
  optimale Intervalle — für v1 akzeptiert.
