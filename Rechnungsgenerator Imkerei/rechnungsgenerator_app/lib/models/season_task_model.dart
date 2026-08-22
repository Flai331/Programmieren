import 'hive_action_model.dart';

/// Ein Posten auf der Packliste einer Saison-Aufgabe.
///
/// [perHive] null bedeutet: einmal mitnehmen, unabhängig von der Völkerzahl
/// (Werkzeug). Sonst wird die Menge mit der Zahl der offenen Völker
/// multipliziert – die Packliste passt sich damit an den Bestand an.
class PackItem {
  final String name;
  final double? perHive;
  final String? unit;

  const PackItem(this.name, {this.perHive, this.unit});

  bool get scalesWithHives => perHive != null;

  /// Benötigte Menge für [hiveCount] Völker, null bei Werkzeug.
  double? quantityFor(int hiveCount) =>
      perHive == null ? null : perHive! * hiveCount;
}

/// Wiederkehrende Arbeit im Imkerjahr.
class SeasonTask {
  final String id;
  final String title;

  /// Monatsfenster, 1–12, beide Grenzen einschließlich. [startMonth] darf
  /// größer als [endMonth] sein – dann läuft das Fenster über den
  /// Jahreswechsel (z.B. November bis Februar).
  final int startMonth;
  final int endMonth;

  /// Maßnahmenart, mit der die Aufgabe erledigt wird.
  final String actionType;

  final String description;
  final List<PackItem> material;

  const SeasonTask({
    required this.id,
    required this.title,
    required this.startMonth,
    required this.endMonth,
    required this.actionType,
    required this.description,
    this.material = const [],
  });

  bool get wrapsYear => startMonth > endMonth;

  /// Liegt [month] (1–12) im Fenster?
  bool coversMonth(int month) => wrapsYear
      ? month >= startMonth || month <= endMonth
      : month >= startMonth && month <= endMonth;

  /// Zeitraum des laufenden Durchgangs, bezogen auf [reference].
  ///
  /// Innerhalb des Fensters ist es der aktuelle Durchgang; außerhalb der
  /// zuletzt abgeschlossene. So bleibt nach dem Fenster sichtbar, was in
  /// dieser Saison erledigt wurde.
  SeasonWindow currentWindow(DateTime reference) {
    var jahr = reference.year;

    if (wrapsYear) {
      // Fenster über den Jahreswechsel: Beginn liegt im Vorjahr, sobald
      // das Referenzdatum vor dem Startmonat liegt.
      if (reference.month < startMonth) jahr -= 1;
      return SeasonWindow(
        start: DateTime(jahr, startMonth, 1),
        end: _endOfMonth(jahr + 1, endMonth),
      );
    }

    // Vor dem Fenster: der letzte abgeschlossene Durchgang war im Vorjahr.
    if (reference.month < startMonth) jahr -= 1;
    return SeasonWindow(
      start: DateTime(jahr, startMonth, 1),
      end: _endOfMonth(jahr, endMonth),
    );
  }

  static DateTime _endOfMonth(int year, int month) =>
      DateTime(year, month + 1, 1).subtract(const Duration(microseconds: 1));

  /// Erledigt eine Maßnahme diese Aufgabe?
  ///
  /// Maßnahmen, die aus der Saison-Ansicht heraus erfasst wurden, tragen die
  /// Aufgaben-Id und zählen nur für genau diese Aufgabe. Frei erfasste
  /// Maßnahmen zählen über ihre Art – sonst würde eine von Hand eingetragene
  /// Varroabehandlung die Saison-Aufgabe nicht abhaken.
  bool isFulfilledBy(HiveActionModel action) {
    if (action.seasonTask != null) return action.seasonTask == id;
    return action.type == actionType;
  }
}

/// Zeitraum eines Aufgaben-Durchgangs.
///
/// Eigener Typ statt Flutters `DateTimeRange`: Die Modelle bleiben frei von
/// Flutter-Abhängigkeiten, und in den Screens gibt es keine Namenskollision
/// mit `material.dart`.
class SeasonWindow {
  final DateTime start;
  final DateTime end;

  const SeasonWindow({required this.start, required this.end});

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && !moment.isAfter(end);
}

/// Das Imkerjahr als feste Liste. Bewusst im Code statt in der Datenbank:
/// Es ist Fachwissen, kein Nutzerinhalt.
class SeasonCatalog {
  static const List<SeasonTask> tasks = [
    SeasonTask(
      id: 'auswinterung',
      title: 'Auswinterung / Frühjahrsdurchsicht',
      startMonth: 3,
      endMonth: 4,
      actionType: HiveActionTypes.inspection,
      description:
          'Erster Blick ins Volk: Weiselrichtigkeit, Futtervorrat und '
          'Volksstärke prüfen, Totenfall entfernen.',
      material: [
        PackItem('Stockmeißel'),
        PackItem('Smoker + Rauchmaterial'),
        PackItem('Futterteig', perHive: 1, unit: 'kg'),
        PackItem('Ersatzwaben', perHive: 2, unit: 'Stk'),
      ],
    ),
    SeasonTask(
      id: 'wabentausch',
      title: 'Alte Waben austauschen',
      startMonth: 3,
      endMonth: 5,
      actionType: HiveActionTypes.combs,
      description:
          'Dunkle Waben aus dem Brutraum nehmen und durch Mittelwände '
          'ersetzen, Schiede setzen.',
      material: [
        PackItem('Mittelwände', perHive: 4, unit: 'Stk'),
        PackItem('Schiede', perHive: 2, unit: 'Stk'),
        PackItem('Stockmeißel'),
      ],
    ),
    SeasonTask(
      id: 'drohnenrahmen',
      title: 'Drohnenrahmen einsetzen',
      startMonth: 4,
      endMonth: 5,
      actionType: HiveActionTypes.combs,
      description:
          'Baurahmen als Varroa-Falle in den Brutraum hängen und regelmäßig '
          'ausschneiden.',
      material: [
        PackItem('Drohnenrahmen', perHive: 1, unit: 'Stk'),
        PackItem('Stockmeißel'),
      ],
    ),
    SeasonTask(
      id: 'honigraum',
      title: 'Honigraum aufsetzen',
      startMonth: 4,
      endMonth: 5,
      actionType: HiveActionTypes.other,
      description:
          'Bei einsetzender Tracht den Honigraum mit Absperrgitter geben.',
      material: [
        PackItem('Honigraum-Zarge', perHive: 1, unit: 'Stk'),
        PackItem('Absperrgitter', perHive: 1, unit: 'Stk'),
        PackItem('Rähmchen', perHive: 10, unit: 'Stk'),
      ],
    ),
    SeasonTask(
      id: 'schwarmkontrolle',
      title: 'Schwarmkontrolle',
      startMonth: 5,
      endMonth: 6,
      actionType: HiveActionTypes.swarm,
      description:
          'Alle 7–9 Tage auf Weiselzellen kontrollieren, Schwarmtrieb '
          'rechtzeitig erkennen.',
      material: [
        PackItem('Stockmeißel'),
        PackItem('Smoker + Rauchmaterial'),
        PackItem('Ablegerkasten'),
      ],
    ),
    SeasonTask(
      id: 'honigernte',
      title: 'Honigernte',
      startMonth: 6,
      endMonth: 8,
      actionType: HiveActionTypes.harvest,
      description:
          'Verdeckelte Honigwaben ernten. Wassergehalt vor dem Schleudern '
          'prüfen.',
      material: [
        PackItem('Bienenflucht', perHive: 1, unit: 'Stk'),
        PackItem('Abkehrbesen'),
        PackItem('Leerzarge', perHive: 1, unit: 'Stk'),
        PackItem('Refraktometer'),
      ],
    ),
    SeasonTask(
      id: 'varroa_sommer',
      title: 'Varroabehandlung (Sommer)',
      startMonth: 7,
      endMonth: 9,
      actionType: HiveActionTypes.varroa,
      description:
          'Direkt nach der letzten Ernte behandeln. Temperatur und '
          'Verdunstung im Blick behalten.',
      material: [
        PackItem('Ameisensäure 60%', perHive: 200, unit: 'ml'),
        PackItem('Schwammtuch / Dispenser', perHive: 1, unit: 'Stk'),
        PackItem('Schutzbrille + Handschuhe'),
        PackItem('Bodenschieber zur Kontrolle', perHive: 1, unit: 'Stk'),
      ],
    ),
    SeasonTask(
      id: 'einfuetterung',
      title: 'Einfütterung',
      startMonth: 8,
      endMonth: 9,
      actionType: HiveActionTypes.feeding,
      description:
          'Winterfutter in mehreren Gaben geben, bis das Volk sein '
          'Wintergewicht erreicht hat.',
      material: [
        PackItem('Futtersirup', perHive: 15, unit: 'kg'),
        PackItem('Futtertasche / Eimer', perHive: 1, unit: 'Stk'),
      ],
    ),
    SeasonTask(
      id: 'wintervorbereitung',
      title: 'Wintervorbereitung',
      startMonth: 10,
      endMonth: 11,
      actionType: HiveActionTypes.other,
      description:
          'Mäusegitter anbringen, Beuten gegen Sturm sichern, Fluglöcher '
          'verkleinern.',
      material: [
        PackItem('Mäusegitter', perHive: 1, unit: 'Stk'),
        PackItem('Spanngurt', perHive: 1, unit: 'Stk'),
      ],
    ),
    SeasonTask(
      id: 'restentmilbung',
      title: 'Restentmilbung',
      startMonth: 12,
      endMonth: 1,
      actionType: HiveActionTypes.varroa,
      description:
          'In der brutfreien Zeit mit Oxalsäure träufeln – nur einmal je '
          'Winter.',
      material: [
        PackItem('Oxalsäure-Lösung', perHive: 50, unit: 'ml'),
        PackItem('Dosierspritze'),
        PackItem('Schutzbrille + Handschuhe'),
      ],
    ),
  ];

  static SeasonTask? byId(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Aufgaben, die im Monat [month] (1–12) anstehen.
  static List<SeasonTask> forMonth(int month) =>
      tasks.where((t) => t.coversMonth(month)).toList(growable: false);
}
