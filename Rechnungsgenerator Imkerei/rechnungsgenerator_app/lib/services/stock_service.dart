import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import 'database_service.dart';
import 'season_service.dart';

/// Ein Lagerposten mit seinem errechneten Bestand.
class StockBalance {
  final StockItemModel item;

  /// Summe aller Bewegungen. Kann negativ werden – dann wurde mehr gebucht
  /// als vorhanden war, und das soll sichtbar bleiben statt stillschweigend
  /// auf 0 gekappt zu werden.
  final double quantity;

  const StockBalance({required this.item, required this.quantity});

  String get name => item.name;
  String get unit => item.unit;

  bool get isEmpty => quantity <= 0;

  /// Unter dem Mindestbestand? Ohne gesetzten Mindestbestand nie.
  bool get isBelowMinimum =>
      item.hasMinimum && quantity < item.minQuantity!;

  /// Fehlmenge bis zum Mindestbestand, 0 wenn er erreicht ist.
  double get shortfall {
    if (!item.hasMinimum) return 0;
    final fehlt = item.minQuantity! - quantity;
    return fehlt > 0 ? fehlt : 0;
  }

  /// Wert des Bestands, null ohne hinterlegten Preis.
  double? get value =>
      item.pricePerUnit == null ? null : item.pricePerUnit! * quantity;

  /// z.B. „12,5 kg"
  String get quantityLabel => formatQuantity(quantity, unit);

  static String formatQuantity(double value, String unit) {
    final zahl = AppUtils.formatNumber(value);
    return unit.isEmpty ? zahl : '$zahl $unit';
  }
}

/// Abgleich eines Packlisten-Postens mit dem Lager.
class StockCoverage {
  final PackListEntry entry;

  /// Passender Lagerposten, null wenn es ihn nicht gibt.
  final StockBalance? balance;

  const StockCoverage({required this.entry, this.balance});

  String get label => entry.label;

  /// Benötigte Menge, null bei Werkzeug.
  double? get required => entry.quantity;

  /// Fehlt etwas? Nur beurteilbar, wenn eine Menge gebraucht wird UND der
  /// Posten im Lager geführt wird. Ein unbekannter Posten gilt nicht als
  /// Fehlmenge – die App weiß dann einfach nichts darüber.
  bool get isShort {
    final brauche = required;
    final b = balance;
    if (brauche == null || b == null) return false;
    return b.quantity < brauche;
  }

  bool get isUnknown => balance == null;

  /// Fehlmenge, 0 wenn genug da oder nicht beurteilbar.
  double get missing {
    if (!isShort) return 0;
    return required! - balance!.quantity;
  }

  /// z.B. „20 Stk im Lager" oder „nicht im Lager geführt".
  String get stockLabel => balance == null
      ? 'nicht im Lager geführt'
      : '${balance!.quantityLabel} im Lager';
}

/// Vorschlag, eine Maßnahme ins Lager zu buchen.
class StockBookingSuggestion {
  final HiveActionModel action;

  /// Lagerposten der passenden Warengruppe, aus denen gewählt wird.
  final List<StockBalance> candidates;

  /// Vorzeichenbehaftete Menge, die gebucht würde.
  final double quantity;

  final String reason;

  /// Die bereits vorhandene Buchung dieser Maßnahme, falls es eine gibt.
  ///
  /// Dann geht es nicht um eine neue Buchung, sondern um das Nachziehen
  /// einer geänderten Menge. Ohne diesen Fall bliebe eine nachträglich
  /// korrigierte Fütterung mit der alten Menge im Lager stehen.
  final StockMovementModel? existing;

  const StockBookingSuggestion({
    required this.action,
    required this.candidates,
    required this.quantity,
    required this.reason,
    this.existing,
  });

  bool get isInbound => quantity > 0;

  /// Ersetzt der Vorschlag eine frühere Buchung?
  bool get isUpdate => existing != null;

  /// Der naheliegendste Posten: der schon gebuchte, bei einer Behandlung
  /// der, dessen Name zum eingesetzten Mittel passt; sonst der einzige der
  /// Warengruppe.
  StockBalance? get preselected {
    if (candidates.isEmpty) return null;
    // Beim Nachziehen bleibt es beim Posten, auf den schon gebucht wurde.
    final frueher = existing?.itemId;
    if (frueher != null) {
      for (final k in candidates) {
        if (k.item.id == frueher) return k;
      }
    }
    final mittel = action.treatment;
    if (mittel != null && mittel.trim().isNotEmpty) {
      final gesucht = StockItemModel.normalizeName(mittel);
      for (final k in candidates) {
        if (k.item.matchKey == gesucht) return k;
      }
      for (final k in candidates) {
        if (k.item.matchKey.contains(gesucht) ||
            gesucht.contains(k.item.matchKey)) {
          return k;
        }
      }
    }
    return candidates.length == 1 ? candidates.first : null;
  }
}

/// Ein Rechnungsposten, dem ein Lagerposten zugeordnet werden konnte.
///
/// Rechnungsposten sind Freitext. Die Zuordnung über den Namen ist deshalb
/// ein Vorschlag und keine Tatsache – deswegen wird sie dem Imker gezeigt
/// und nicht stillschweigend gebucht.
class StockSaleLine {
  final InvoiceItemModel line;
  final StockBalance balance;

  const StockSaleLine({required this.line, required this.balance});

  /// Verkaufte Menge, wie sie auf der Rechnung steht.
  double get quantity => line.quantity;

  /// Reicht der Bestand? Negativ darf er werden – aber man soll es sehen.
  bool get exceedsStock => quantity > balance.quantity;

  String get label => line.description;
}

/// Vorschlag, den Verkauf einer Rechnung aus dem Lager abzubuchen.
class StockSaleSuggestion {
  final String invoiceId;
  final List<StockSaleLine> lines;

  /// Wurde diese Rechnung schon einmal gebucht? Dann geht es um das
  /// Nachziehen geänderter Posten, nicht um eine neue Buchung.
  final bool alreadyBooked;

  const StockSaleSuggestion({
    required this.invoiceId,
    required this.lines,
    this.alreadyBooked = false,
  });

  bool get isEmpty => lines.isEmpty;
}

/// Lager: Bestände, Warnungen und Buchungen.
///
/// Der Bestand wird abgeleitet, nicht gespeichert – wie beim Saison-Stand.
/// Jede Zahl im Lager lässt sich damit auf Bewegungen zurückführen.
class StockService {
  final DatabaseService _db;

  StockService([DatabaseService? db]) : _db = db ?? DatabaseService();

  /// Alle Posten mit Bestand, nach Name sortiert.
  Future<List<StockBalance>> loadBalances() async {
    final items = await _db.getAllStockItems();
    final balances = await _db.getStockBalances();
    return buildBalances(items: items, balances: balances);
  }

  /// Reine Zuordnung ohne Datenbank – so ist die Logik testbar.
  static List<StockBalance> buildBalances({
    required List<StockItemModel> items,
    required Map<String, double> balances,
  }) =>
      [
        for (final item in items)
          StockBalance(item: item, quantity: balances[item.id] ?? 0),
      ];

  /// Posten unter ihrem Mindestbestand – die größte Fehlmenge zuerst.
  static List<StockBalance> belowMinimum(List<StockBalance> alle) {
    final knapp = alle.where((b) => b.isBelowMinimum).toList()
      ..sort((a, b) => b.shortfall.compareTo(a.shortfall));
    return knapp;
  }

  /// Gesamtwert aller Posten mit hinterlegtem Preis.
  static double totalValue(List<StockBalance> alle) {
    var summe = 0.0;
    for (final b in alle) {
      summe += b.value ?? 0;
    }
    return summe;
  }

  /// Packliste gegen das Lager prüfen.
  static List<StockCoverage> coverage(
    List<PackListEntry> packliste,
    List<StockBalance> bestand,
  ) {
    final nachName = <String, StockBalance>{
      for (final b in bestand) b.item.matchKey: b,
    };
    return [
      for (final entry in packliste)
        StockCoverage(
          entry: entry,
          balance: _findMatch(nachName, entry.label),
        ),
    ];
  }

  /// Posten über den Namen finden. Exakter Treffer zuerst, danach ein
  /// Teiltreffer – „Ameisensäure 60%" auf der Packliste und
  /// „Ameisensäure" im Lager sollen zusammenfinden.
  static StockBalance? _findMatch(
      Map<String, StockBalance> nachName, String gesuchterName) {
    final key = StockItemModel.normalizeName(gesuchterName);
    final exakt = nachName[key];
    if (exakt != null) return exakt;
    for (final eintrag in nachName.entries) {
      if (key.contains(eintrag.key) || eintrag.key.contains(key)) {
        return eintrag.value;
      }
    }
    return null;
  }

  /// Eine Bewegung buchen. [quantity] ist vorzeichenbehaftet.
  Future<StockMovementModel> book({
    required String itemId,
    required double quantity,
    required String reason,
    DateTime? date,
    String? note,
    String? hiveActionId,
    String? invoiceId,
  }) async {
    final movement = StockMovementModel(
      id: const Uuid().v4(),
      itemId: itemId,
      date: date ?? DateTime.now(),
      quantity: quantity,
      reason: reason,
      note: note,
      hiveActionId: hiveActionId,
      invoiceId: invoiceId,
      createdAt: DateTime.now(),
    );
    await _db.insertStockMovement(movement);
    FeedbackService.logUserAction('Lagerbewegung gebucht', context: {
      'grund': reason,
      'menge': quantity.toString(),
    });
    return movement;
  }

  /// Bestand auf einen gezählten Wert setzen – Inventur.
  ///
  /// Gebucht wird die Differenz, nicht der Zielwert: Die Historie bleibt
  /// damit lückenlos und der alte Bestand nachvollziehbar.
  Future<StockMovementModel?> takeInventory({
    required String itemId,
    required double countedQuantity,
    String? note,
  }) async {
    final bestaende = await _db.getStockBalances();
    final aktuell = bestaende[itemId] ?? 0;
    final differenz = countedQuantity - aktuell;
    // Ohne Abweichung gibt es nichts zu buchen.
    if (differenz.abs() < 0.0001) return null;
    return book(
      itemId: itemId,
      quantity: differenz,
      reason: StockReasons.correction,
      note: note ?? 'Inventur',
    );
  }

  /// Soll diese Maßnahme ins Lager gebucht werden?
  ///
  /// Null, wenn die Maßnahme keine Menge hat, es keine passende Warengruppe
  /// gibt oder die Maßnahme schon gebucht wurde. Auch null, wenn für die
  /// Warengruppe noch kein Posten angelegt ist – dann gibt es nichts zu
  /// wählen, und ein Dialog wäre nur im Weg.
  Future<StockBookingSuggestion?> suggestBooking(
      HiveActionModel action) async {
    final menge = action.amount;
    if (menge == null || menge <= 0) return null;

    final kategorie = StockCategories.forActionType(action.type);
    if (kategorie == null) return null;

    final alle = await loadBalances();
    final kandidaten = alle
        .where((b) => b.item.category == kategorie)
        .toList(growable: false);
    if (kandidaten.isEmpty) return null;

    // Ernte füllt das Lager, alles andere zehrt daran.
    final vorzeichen = action.type == HiveActionTypes.harvest ? 1 : -1;
    final signierteMenge = menge * vorzeichen;

    final bereitsGebucht = await _db.getStockMovementsForAction(action.id);
    if (bereitsGebucht.isNotEmpty) {
      // Schon gebucht. Stimmt die Menge noch, gibt es nichts zu fragen.
      // Weicht sie ab, weil die Maßnahme nachträglich geändert wurde, soll
      // die Buchung nachziehen können – sonst steht im Lager eine Zahl,
      // die ihrer eigenen Quelle widerspricht.
      final vorhanden = bereitsGebucht.first;
      final summe = bereitsGebucht.fold<double>(0, (a, b) => a + b.quantity);
      if ((summe - signierteMenge).abs() < 0.0001) return null;
      return StockBookingSuggestion(
        action: action,
        candidates: kandidaten,
        quantity: signierteMenge,
        reason: StockReasons.forActionType(action.type),
        existing: vorhanden,
      );
    }

    return StockBookingSuggestion(
      action: action,
      candidates: kandidaten,
      quantity: signierteMenge,
      reason: StockReasons.forActionType(action.type),
    );
  }

  /// Rechnungsposten den Glas-Posten im Lager zuordnen.
  ///
  /// Reine Funktion ohne Datenbank. Zugeordnet wird über den Namen, mit
  /// demselben Abgleich wie bei der Packliste: exakt, sonst Teiltreffer.
  /// Was nicht passt, bleibt außen vor – geraten wird nicht.
  static List<StockSaleLine> matchInvoiceLines(
    List<InvoiceItemModel> items,
    List<StockBalance> bestand,
  ) {
    final nachName = <String, StockBalance>{
      for (final b in bestand) b.item.matchKey: b,
    };
    final treffer = <StockSaleLine>[];
    for (final zeile in items) {
      if (zeile.quantity <= 0) continue;
      final posten = _findMatch(nachName, zeile.description);
      if (posten == null) continue;
      treffer.add(StockSaleLine(line: zeile, balance: posten));
    }
    return treffer;
  }

  /// Soll der Verkauf dieser Rechnung ins Lager gebucht werden?
  ///
  /// Null, wenn sich kein Posten zuordnen ließ oder die Rechnung schon mit
  /// genau diesen Mengen gebucht ist. Nur Honig und Gläser werden
  /// angeboten – eine Rechnung über Arbeitszeit mindert kein Lager.
  Future<StockSaleSuggestion?> suggestSale({
    required String invoiceId,
    required List<InvoiceItemModel> items,
  }) async {
    final alle = await loadBalances();
    final verkaeuflich = alle
        .where((b) =>
            b.item.category == StockCategories.honey ||
            b.item.category == StockCategories.jars)
        .toList(growable: false);
    final zeilen = matchInvoiceLines(items, verkaeuflich);
    if (zeilen.isEmpty) return null;

    final gebucht = await _db.getStockMovementsForInvoice(invoiceId);
    if (gebucht.isNotEmpty) {
      // Stimmen die gebuchten Mengen noch mit der Rechnung überein, gibt
      // es nichts zu fragen.
      final gebuchtJePosten = <String, double>{};
      for (final b in gebucht) {
        gebuchtJePosten[b.itemId] =
            (gebuchtJePosten[b.itemId] ?? 0) + b.quantity;
      }
      final sollJePosten = <String, double>{};
      for (final z in zeilen) {
        sollJePosten[z.balance.item.id] =
            (sollJePosten[z.balance.item.id] ?? 0) - z.quantity;
      }
      var gleich = gebuchtJePosten.length == sollJePosten.length;
      if (gleich) {
        for (final e in sollJePosten.entries) {
          final ist = gebuchtJePosten[e.key];
          if (ist == null || (ist - e.value).abs() > 0.0001) {
            gleich = false;
            break;
          }
        }
      }
      if (gleich) return null;
      return StockSaleSuggestion(
          invoiceId: invoiceId, lines: zeilen, alreadyBooked: true);
    }

    return StockSaleSuggestion(invoiceId: invoiceId, lines: zeilen);
  }

  /// Verkauf einer Rechnung buchen.
  ///
  /// Frühere Buchungen derselben Rechnung weichen den neuen, damit eine
  /// nachträglich geänderte Rechnung nicht doppelt zählt.
  Future<void> bookSale({
    required String invoiceId,
    required List<StockSaleLine> lines,
    required DateTime date,
  }) async {
    await _db.deleteStockMovementsForInvoice(invoiceId);
    for (final z in lines) {
      await book(
        itemId: z.balance.item.id,
        quantity: -z.quantity,
        reason: StockReasons.sale,
        date: date,
        note: z.label,
        invoiceId: invoiceId,
      );
    }
  }

  /// Buchung einer Maßnahme übernehmen.
  Future<void> bookFromAction({
    required HiveActionModel action,
    required String itemId,
    required double quantity,
  }) async {
    // Eine frühere Buchung derselben Maßnahme weicht der neuen, sonst zählt
    // eine nachträglich geänderte Menge doppelt.
    await _db.deleteStockMovementsForAction(action.id);
    await book(
      itemId: itemId,
      quantity: quantity,
      reason: StockReasons.forActionType(action.type),
      date: action.date,
      note: action.typeLabel,
      hiveActionId: action.id,
    );
  }
}
