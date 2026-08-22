import '../models/models.dart';
import 'database_service.dart';

/// Ein Volk im Zusammenhang einer Saison-Aufgabe.
class SeasonHiveStatus {
  final HiveModel hive;

  /// Die Maßnahme, mit der die Aufgabe erledigt wurde – null, wenn offen.
  final HiveActionModel? fulfilledBy;

  const SeasonHiveStatus({required this.hive, this.fulfilledBy});

  bool get isDone => fulfilledBy != null;
}

/// Stand einer Saison-Aufgabe über alle aktiven Völker.
class SeasonTaskStatus {
  final SeasonTask task;
  final List<SeasonHiveStatus> hives;

  /// Zeitraum, für den der Stand berechnet wurde.
  final SeasonWindow window;

  /// Steht die Aufgabe im Referenzmonat an?
  final bool isDue;

  const SeasonTaskStatus({
    required this.task,
    required this.hives,
    required this.window,
    required this.isDue,
  });

  List<SeasonHiveStatus> get openHives =>
      hives.where((h) => !h.isDone).toList(growable: false);

  List<SeasonHiveStatus> get doneHives =>
      hives.where((h) => h.isDone).toList(growable: false);

  int get total => hives.length;
  int get doneCount => doneHives.length;
  int get openCount => total - doneCount;

  bool get isComplete => total > 0 && openCount == 0;

  /// 0.0–1.0; ohne Völker 0.
  double get progress => total == 0 ? 0 : doneCount / total;

  /// Packliste für die noch offenen Völker.
  List<PackListEntry> get packList => [
        for (final item in task.material)
          PackListEntry(item: item, quantity: item.quantityFor(openCount)),
      ];
}

/// Ein Posten der Packliste mit ausgerechneter Menge.
class PackListEntry {
  final PackItem item;

  /// Null bei Werkzeug, das unabhängig von der Völkerzahl einmal mitkommt.
  final double? quantity;

  const PackListEntry({required this.item, this.quantity});

  String get label => item.name;

  /// z.B. „3 kg", „600 ml" oder '' bei Werkzeug.
  String get quantityLabel {
    final q = quantity;
    if (q == null) return '';
    final zahl = q == q.roundToDouble()
        ? q.toStringAsFixed(0)
        : q.toStringAsFixed(1).replaceAll('.', ',');
    final einheit = item.unit;
    return einheit == null || einheit.isEmpty ? zahl : '$zahl $einheit';
  }
}

/// Berechnet aus Völkern und erfassten Maßnahmen, was in der Saison ansteht.
///
/// Der Stand wird abgeleitet, nicht gespeichert: Was erledigt ist, steht
/// bereits als Maßnahme in der Stockkarte. Damit kann kein zweiter
/// Wahrheitsstand entstehen.
class SeasonService {
  final DatabaseService _db;

  SeasonService([DatabaseService? db]) : _db = db ?? DatabaseService();

  /// Stand aller Aufgaben des Imkerjahres.
  Future<List<SeasonTaskStatus>> loadAll({DateTime? reference}) async {
    final now = reference ?? DateTime.now();
    final hives = await _db.getAllHives();
    final actions = await _db.getAllHiveActions();
    return buildStatuses(hives: hives, actions: actions, reference: now);
  }

  /// Reine Berechnung ohne Datenbank – so ist die Logik testbar.
  static List<SeasonTaskStatus> buildStatuses({
    required List<HiveModel> hives,
    required List<HiveActionModel> actions,
    required DateTime reference,
  }) {
    // Nur aktive Völker: Für abgegebene oder eingegangene Völker steht
    // nichts mehr an, sie würden die Fortschrittsanzeige verfälschen.
    final aktive = hives.where((h) => h.isActive).toList(growable: false);

    final proVolk = <String, List<HiveActionModel>>{};
    for (final a in actions) {
      (proVolk[a.hiveId] ??= []).add(a);
    }

    return [
      for (final task in SeasonCatalog.tasks)
        _statusFor(task, aktive, proVolk, reference),
    ];
  }

  static SeasonTaskStatus _statusFor(
    SeasonTask task,
    List<HiveModel> hives,
    Map<String, List<HiveActionModel>> actionsByHive,
    DateTime reference,
  ) {
    final window = task.currentWindow(reference);

    final stati = <SeasonHiveStatus>[];
    for (final hive in hives) {
      HiveActionModel? treffer;
      for (final action in actionsByHive[hive.id] ?? const <HiveActionModel>[]) {
        if (!window.contains(action.date)) continue;
        if (!task.isFulfilledBy(action)) continue;
        // Jüngste passende Maßnahme gewinnt.
        if (treffer == null || action.date.isAfter(treffer.date)) {
          treffer = action;
        }
      }
      stati.add(SeasonHiveStatus(hive: hive, fulfilledBy: treffer));
    }

    return SeasonTaskStatus(
      task: task,
      hives: stati,
      window: window,
      isDue: task.coversMonth(reference.month),
    );
  }

  /// Aufgaben, die im Referenzmonat anstehen – offene zuerst.
  static List<SeasonTaskStatus> due(List<SeasonTaskStatus> alle) {
    final anstehend = alle.where((s) => s.isDue).toList()
      ..sort((a, b) {
        // Was noch offen ist, gehört nach oben.
        if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
        return b.openCount.compareTo(a.openCount);
      });
    return anstehend;
  }

  /// Aufgaben der kommenden [months] Monate, die jetzt noch nicht anstehen.
  static List<SeasonTaskStatus> upcoming(
    List<SeasonTaskStatus> alle,
    DateTime reference, {
    int months = 2,
  }) {
    final kommende = <SeasonTaskStatus>[];
    for (var offset = 1; offset <= months; offset++) {
      final monat = ((reference.month - 1 + offset) % 12) + 1;
      for (final s in alle) {
        if (s.isDue) continue;
        if (!s.task.coversMonth(monat)) continue;
        if (kommende.any((k) => k.task.id == s.task.id)) continue;
        kommende.add(s);
      }
    }
    return kommende;
  }
}
