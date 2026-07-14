# Design: Frei einstellbare Monats-Solls für Schichtvorlagen

Datum: 2026-07-14
Status: vom Nutzer freigegeben

## Ziel

Bisher hat jede Schichtvorlage ein eigenes Feld `minPerMonth` („Mindestanzahl
dieser Schicht pro Monat"). Das erlaubt keine Gruppen: Wer zwei
Spätschicht-Varianten (S1, S2) hat und „mindestens 5 Spätschichten pro Monat"
braucht, kann das nicht abbilden.

Neu: frei anlegbare **Solls**. Ein Soll hat einen Namen, eine Mindestanzahl
Schichten pro Monat und eine Liste zugeordneter Schichtvorlagen. Jede geplante
Schicht, deren Vorlage dem Soll zugeordnet ist, zählt für dieses Soll. Eine
Vorlage darf mehreren Solls zugeordnet sein (z. B. „Spät Sa" zählt zu
„Spätschichten" und „Wochenendschichten"). Das alte Feld `minPerMonth` an der
Einzelvorlage entfällt und wird automatisch migriert.

Entschiedene Fragen:

- Soll-Einheit: **Mindestanzahl Schichten** (keine Stunden).
- Vorlage in mehreren Solls: **ja**.
- Altes `minPerMonth`: **ersetzen + automatisch migrieren**.

## 1. Datenmodell

Neu `lib/models/shift_quota.dart`:

```dart
/// Frei einstellbares Monats-Soll (z. B. "Spätschichten": min. 5 Schichten
/// aus den zugeordneten Vorlagen pro Monat).
class ShiftQuota {
  final String id;
  String name;              // z. B. "Spätschichten"
  int minPerMonth;          // 0 = inaktiv
  List<String> templateIds; // zugeordnete Schichtvorlagen

  // toJson / fromJson im Stil der bestehenden Models
  // (fromJson mit Defaults: name '', minPerMonth 0, templateIds []).
}
```

`ShiftTemplate.minPerMonth`:

- Feld bleibt im Model, damit `fromJson` alte Daten lesen kann (Migration).
- `toJson` schreibt es **nicht** mehr.
- UI-Feld im Vorlagen-Editor entfällt (inkl. Anzeige „min. N×/Monat" in der
  Vorlagenliste).

## 2. Storage + State

- `storage_service`: `quotas`-Liste im gleichen Muster wie `templates`
  speichern/laden (eigener JSON-Key `quotas`).
- `app_state`:
  - `List<ShiftQuota> quotas` (+ ggf. `quotasById`, falls gebraucht),
  - `addQuota` / `updateQuota` / `removeQuota` mit Persistierung,
  - beim Löschen einer Vorlage: ihre ID aus `templateIds` aller Quotas
    entfernen und persistieren.

## 3. Migration

Beim Laden der gespeicherten Daten:

- Fehlt der Key `quotas` im JSON komplett → einmalige Migration: für jede
  Vorlage mit `minPerMonth > 0` ein Soll anlegen mit
  `name = vorlage.name`, `minPerMonth = vorlage.minPerMonth`,
  `templateIds = [vorlage.id]`. Ergebnis sofort speichern.
- Existiert der Key (auch als leere Liste) → keine Migration. Damit erzeugt
  „Nutzer löscht alle Solls" beim nächsten Start keine Re-Migration.

## 4. Logik (HoursService)

`missingMinimums` wird ersetzt durch:

```dart
/// Solls mit Mindestanzahl pro Monat: wie viele Schichten fehlen noch?
/// Liefert nur Solls, deren Vorgabe im Monat nicht erfüllt ist.
static List<(ShiftQuota, int)> missingQuotas(
  List<Shift> shifts,
  List<ShiftQuota> quotas,
  String yearMonth,
)
```

- Zählt Schichten des Monats, deren `templateId` in `quota.templateIds` liegt.
- Eine Schicht, deren Vorlage in mehreren Solls steckt, zählt in jedem davon.
- Solls mit `minPerMonth == 0` werden ignoriert.
- Rückgabe: `(quota, fehlendeAnzahl)` für alle unerfüllten Solls.

## 5. UI

- **`templates_screen`**: neuer Abschnitt „Monats-Solls" unter der
  Vorlagenliste.
  - Zeile pro Soll: `Spätschichten · min. 5×/Monat · S1, S2`
    (Kürzel der zugeordneten Vorlagen), antippen = bearbeiten, Plus-Button
    zum Anlegen, Löschen im Editor.
  - Soll-Editor-Dialog: Name (Text), Mindestanzahl (Zahl), Vorlagen-Auswahl
    als FilterChips (Mehrfachauswahl, Chip zeigt Kürzel/Name in
    Vorlagenfarbe).
- **Vorlagen-Editor**: Feld „Mindestanzahl pro Monat" entfernen.
- **`balance_card`**: statt `missingMinimums` jetzt `missingQuotas`;
  Anzeige unverändert im Stil „Fehlt noch: 2× Spätschichten, 1× Nachtdienst".

## 6. Fehlerfälle / Randfälle

- Soll ohne zugeordnete Vorlagen: zählt nie Schichten, erscheint bei
  `minPerMonth > 0` dauerhaft als unerfüllt. Kein Sonderfall im Code —
  Nutzer sieht das Problem direkt in der Karte.
- Soll mit `minPerMonth == 0`: inaktiv, keine Warnung.
- Gelöschte Vorlage: wird aus allen Solls entfernt (siehe State).
- Alte Datenstände ohne `quotas`-Key: Migration (siehe oben).

## 7. Tests

`hours_service_test` erweitern:

- Soll erfüllt / teilweise erfüllt / gar nicht erfüllt.
- Vorlage in zwei Solls: eine Schicht zählt in beiden.
- `minPerMonth == 0` wird ignoriert.
- Soll ohne Vorlagen bleibt unerfüllt.

Migrationstest (storage- oder state-nah, je nach Testbarkeit):

- JSON ohne `quotas`-Key + Vorlage mit `minPerMonth > 0` → Soll entsteht.
- JSON mit leerer `quotas`-Liste → keine Re-Migration.
