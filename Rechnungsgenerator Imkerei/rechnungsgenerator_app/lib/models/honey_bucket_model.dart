/// Imkerei: Ein Eimer Honig – ein Einzelstück mit eigener Geschichte.
///
/// Anders als Gläser sind Eimer nicht untereinander gleich: Jeder hat seine
/// Sorte, sein Erntedatum, seinen Wassergehalt, seinen Zustand und seinen
/// Platz im Keller. Deshalb ist der Eimer ein eigener Datensatz und keine
/// Menge auf einem Lagerposten.
///
/// Der aktuelle Inhalt steht bewusst NICHT als Feld in der Datenbank: Er
/// ergibt sich aus der Einwaage minus allem, was abgefüllt wurde (siehe
/// [HoneyBucketEventModel]). Zustand und Platz dagegen stehen als Spalte am
/// Eimer – sie werden direkt gesetzt und nicht aus etwas anderem errechnet.
/// Jede Änderung schreibt zusätzlich ein Ereignis, damit „wann wurde gerührt"
/// beantwortbar bleibt.
class HoneyBucketModel {
  final String id;

  /// Genau das, was von Hand auf dem Eimer steht, z.B. 'SO-042'.
  final String code;

  /// Laufende Nummer, global eindeutig – nicht je Sorte.
  ///
  /// Dadurch genügen die drei Ziffern zur Identifikation, auch wenn das
  /// Sortenkürzel auf dem Eimer verwischt ist. Das ist Absicht und der Grund
  /// für die globale Zählung.
  final int number;

  /// Sortenschlüssel, siehe [HoneyVarieties].
  final String variety;

  /// Freier Sortenname – nur bei [HoneyVarieties.other] gesetzt.
  final String? varietyName;

  final DateTime harvestDate;

  /// Gebindegröße in kg, z.B. 25. Nur zur Einordnung, nicht zur Rechnung.
  final double? bucketSizeKg;

  /// Einwaage beim Anlegen in kg. Grundlage des Inhalts.
  final double filledKg;

  /// Wassergehalt in Prozent, z.B. 17.2.
  final double? waterContent;

  /// Siehe [HoneyStates].
  final String state;

  /// Lagerplatz, z.B. 'Keller Regal B3'.
  final String? location;

  /// Dateiname des Fotos vom handgeschriebenen Etikett (siehe PhotoStorage).
  final String? labelPhoto;

  final String? note;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const HoneyBucketModel({
    required this.id,
    required this.code,
    required this.number,
    required this.variety,
    this.varietyName,
    required this.harvestDate,
    this.bucketSizeKg,
    required this.filledKg,
    this.waterContent,
    required this.state,
    this.location,
    this.labelPhoto,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Sortenname zum Anzeigen: das Verzeichnis, bei 'Sonstige' der freie Name.
  String get varietyLabel {
    if (variety == HoneyVarieties.other) {
      final eigen = (varietyName ?? '').trim();
      if (eigen.isNotEmpty) return eigen;
    }
    return HoneyVarieties.labelOf(variety);
  }

  String get stateLabel => HoneyStates.labelOf(state);

  /// Ist an diesem Eimer etwas zu tun?
  bool get needsAttention => HoneyStates.needsAttention(state);

  bool get isEmpty => state == HoneyStates.empty;

  /// Was auf den Eimer zu malen ist, z.B. 'SO-042  [||]'.
  String get labelHint {
    final striche = HoneyStates.strokeHint(state);
    return striche.isEmpty ? code : '$code  [$striche]';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'number': number,
        'variety': variety,
        'variety_name': varietyName,
        'harvest_date': harvestDate.toIso8601String(),
        'bucket_size_kg': bucketSizeKg,
        'filled_kg': filledKg,
        'water_content': waterContent,
        'state': state,
        'location': location,
        'label_photo': labelPhoto,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory HoneyBucketModel.fromMap(Map<String, dynamic> m) => HoneyBucketModel(
        id: m['id'] as String,
        code: (m['code'] as String?) ?? '',
        number: (m['number'] as num?)?.toInt() ?? 0,
        variety: (m['variety'] as String?) ?? HoneyVarieties.other,
        varietyName: m['variety_name'] as String?,
        harvestDate: DateTime.parse(m['harvest_date'] as String),
        bucketSizeKg: (m['bucket_size_kg'] as num?)?.toDouble(),
        filledKg: (m['filled_kg'] as num?)?.toDouble() ?? 0,
        waterContent: (m['water_content'] as num?)?.toDouble(),
        state: (m['state'] as String?) ?? HoneyStates.fresh,
        location: m['location'] as String?,
        labelPhoto: m['label_photo'] as String?,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  HoneyBucketModel copyWith({
    String? id,
    String? code,
    int? number,
    String? variety,
    String? varietyName,
    DateTime? harvestDate,
    double? bucketSizeKg,
    double? filledKg,
    double? waterContent,
    String? state,
    String? location,
    String? labelPhoto,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HoneyBucketModel(
        id: id ?? this.id,
        code: code ?? this.code,
        number: number ?? this.number,
        variety: variety ?? this.variety,
        varietyName: varietyName ?? this.varietyName,
        harvestDate: harvestDate ?? this.harvestDate,
        bucketSizeKg: bucketSizeKg ?? this.bucketSizeKg,
        filledKg: filledKg ?? this.filledKg,
        waterContent: waterContent ?? this.waterContent,
        state: state ?? this.state,
        location: location ?? this.location,
        labelPhoto: labelPhoto ?? this.labelPhoto,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Ein Ereignis am Eimer – Zustandswechsel, Abfüllung, Platzwechsel, Notiz.
///
/// Ein Protokoll mit typabhängig leeren Spalten, wie es `hive_actions` schon
/// für die Stockkarte eines Volkes verwendet. Ein Eimer bekommt damit
/// denselben nachvollziehbaren Verlauf.
class HoneyBucketEventModel {
  final String id;
  final String bucketId;
  final DateTime date;

  /// Siehe [HoneyEventKinds].
  final String kind;

  /// Bei [HoneyEventKinds.state]: der neue Zustand.
  final String? state;

  /// Bei [HoneyEventKinds.bottling]: entnommene Menge in kg.
  final double? removedKg;

  /// Bei [HoneyEventKinds.bottling]: Lagerposten, in den abgefüllt wurde.
  final String? jarItemId;

  /// Bei [HoneyEventKinds.bottling]: Anzahl der gefüllten Gläser.
  final int? jarCount;

  /// Bei [HoneyEventKinds.location]: der neue Platz.
  final String? location;

  final String? note;

  /// Dateiname eines Fotos zum Ereignis (siehe PhotoStorage).
  final String? photo;

  final DateTime createdAt;

  const HoneyBucketEventModel({
    required this.id,
    required this.bucketId,
    required this.date,
    required this.kind,
    this.state,
    this.removedKg,
    this.jarItemId,
    this.jarCount,
    this.location,
    this.note,
    this.photo,
    required this.createdAt,
  });

  bool get isBottling => kind == HoneyEventKinds.bottling;

  /// Einzeilige Zusammenfassung für den Verlauf.
  String get summary => switch (kind) {
        HoneyEventKinds.state => HoneyStates.labelOf(state ?? ''),
        HoneyEventKinds.bottling => _bottlingSummary,
        HoneyEventKinds.location => location ?? '–',
        _ => (note ?? '').trim(),
      };

  String get _bottlingSummary {
    final teile = <String>[];
    if (jarCount != null) teile.add('$jarCount Gläser');
    if (removedKg != null) teile.add('${_kg(removedKg!)} kg');
    return teile.isEmpty ? 'Abfüllung' : teile.join(' · ');
  }

  static String _kg(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceAll('.', ',');

  Map<String, dynamic> toMap() => {
        'id': id,
        'bucket_id': bucketId,
        'date': date.toIso8601String(),
        'kind': kind,
        'state': state,
        'removed_kg': removedKg,
        'jar_item_id': jarItemId,
        'jar_count': jarCount,
        'location': location,
        'note': note,
        'photo': photo,
        'created_at': createdAt.toIso8601String(),
      };

  factory HoneyBucketEventModel.fromMap(Map<String, dynamic> m) =>
      HoneyBucketEventModel(
        id: m['id'] as String,
        bucketId: m['bucket_id'] as String,
        date: DateTime.parse(m['date'] as String),
        kind: (m['kind'] as String?) ?? HoneyEventKinds.note,
        state: m['state'] as String?,
        removedKg: (m['removed_kg'] as num?)?.toDouble(),
        jarItemId: m['jar_item_id'] as String?,
        jarCount: (m['jar_count'] as num?)?.toInt(),
        location: m['location'] as String?,
        note: m['note'] as String?,
        photo: m['photo'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Arten von Eimer-Ereignissen.
class HoneyEventKinds {
  static const String state = 'zustand';
  static const String bottling = 'abfuellung';
  static const String location = 'platz';
  static const String note = 'notiz';

  static const Map<String, String> _labels = {
    state: 'Zustand',
    bottling: 'Abfüllung',
    location: 'Platz',
    note: 'Notiz',
  };

  static String labelOf(String kind) => _labels[kind] ?? kind;
}

/// Honigsorten mit ihren Kürzeln.
///
/// Festes Verzeichnis im Code, wie [SeasonCatalog]: Die Kürzel stehen mit
/// Permanentmarker auf Eimern im Keller. Verschöbe sich ein Kürzel, zeigte
/// jeder alte Eimer plötzlich auf die falsche Sorte. Neue Sorten kommen
/// unten dazu, bestehende werden nie umbenannt.
class HoneyVarieties {
  static const String spring = 'FR';
  static const String summer = 'SO';
  static const String rape = 'RA';
  static const String lime = 'LI';
  static const String forest = 'WA';
  static const String acacia = 'AK';
  static const String chestnut = 'ED';
  static const String heather = 'HE';

  /// Alles andere – der Name wird am Eimer frei eingetragen.
  static const String other = 'XX';

  /// Reihenfolge der Auswahl in der App.
  static const List<String> all = [
    spring,
    summer,
    rape,
    lime,
    forest,
    acacia,
    chestnut,
    heather,
    other,
  ];

  static const Map<String, String> _labels = {
    spring: 'Frühjahrsblüte',
    summer: 'Sommerblüte',
    rape: 'Raps',
    lime: 'Linde',
    forest: 'Wald',
    acacia: 'Akazie',
    chestnut: 'Edelkastanie',
    heather: 'Heide',
    other: 'Sonstige',
  };

  static String labelOf(String variety) => _labels[variety] ?? variety;

  static bool isKnown(String variety) => _labels.containsKey(variety);
}

/// Der Weg des Honigs im Eimer – eine Kette mit zwei Abzweigen.
///
/// Die Kette beschreibt den Normalfall vom Schleudern bis zum leeren Eimer.
/// [coarse] und [solid] sind die Fälle, in denen es schiefgegangen ist; von
/// dort führt der Weg zurück ins Rühren.
///
/// Zu jedem Zustand gehört eine Strichzahl für das Kästchen, das von Hand
/// auf den Eimer gemalt wird. Die App liest diese Striche nicht – sie führt
/// den Zustand selbst und bleibt die Wahrheit. Die Striche sind allein für
/// das Auge am Regal.
class HoneyStates {
  static const String fresh = 'frisch';
  static const String toSeed = 'zu_impfen';
  static const String seeded = 'geimpft';
  static const String toStir = 'zu_ruehren';
  static const String stirred = 'geruehrt';
  static const String readyToBottle = 'abfuellfertig';
  static const String empty = 'leer';

  // ── Abzweige ────────────────────────────────────────────────
  static const String coarse = 'grob';
  static const String solid = 'fest';

  /// Reihenfolge der Auswahl in der App: erst die Kette, dann die Abzweige.
  static const List<String> all = [
    fresh,
    toSeed,
    seeded,
    toStir,
    stirred,
    readyToBottle,
    empty,
    coarse,
    solid,
  ];

  static const Map<String, String> _labels = {
    fresh: 'frisch geschleudert',
    toSeed: 'noch zu impfen',
    seeded: 'geimpft, ruht',
    toStir: 'noch zu rühren',
    stirred: 'gerührt',
    readyToBottle: 'abfüllfertig',
    empty: 'abgefüllt, leer',
    coarse: 'grob kristallin',
    solid: 'kandiert / fest',
  };

  static String labelOf(String state) => _labels[state] ?? state;

  /// Der nächste Schritt, null am Ende der Kette.
  ///
  /// Von den Abzweigen führt der Weg zurück ins Rühren: Grob kristalliner
  /// und fester Honig werden nachgerührt, nicht weggeworfen.
  static String? next(String state) => switch (state) {
        fresh => toSeed,
        toSeed => seeded,
        seeded => toStir,
        toStir => stirred,
        stirred => readyToBottle,
        readyToBottle => empty,
        coarse => toStir,
        solid => toStir,
        _ => null,
      };

  /// Wartet dieser Zustand auf eine Arbeit von mir?
  ///
  /// „Noch zu impfen" und „noch zu rühren" sind Aufträge. „Geimpft, ruht"
  /// ist keiner – da wartet der Honig, nicht der Imker. Grob kristallin und
  /// fest sind Aufträge, weil nachgerührt werden muss.
  static bool needsAttention(String state) =>
      state == toSeed || state == toStir || state == coarse || state == solid;

  /// Striche für das handgemalte Kästchen auf dem Eimer.
  ///
  /// Ein Strich je erreichtem Meilenstein, der leere Eimer wird
  /// durchgestrichen. Frühe Zustände bleiben ohne Strich – da ist noch
  /// nichts passiert, was man abhaken könnte.
  static String strokeHint(String state) => switch (state) {
        seeded => '|',
        toStir => '|',
        stirred => '||',
        coarse => '||',
        readyToBottle => '|||',
        empty => '✕',
        _ => '',
      };

  /// Farbe zur Anzeige, als ARGB-Wert.
  ///
  /// Bewusst eine Zahl statt `Color`: Die Modelle bleiben frei von
  /// Flutter-Abhängigkeiten, die Screens wickeln den Wert in `Color()`.
  static int colorOf(String state) => switch (state) {
        fresh => 0xFF60a5fa, // blau – flüssig, frisch
        toSeed => 0xFFf59e0b, // gelb – wartet auf mich
        seeded => 0xFF8a8a94, // grau – ruht
        toStir => 0xFFf59e0b, // gelb – wartet auf mich
        stirred => 0xFF4ade80, // grün – auf gutem Weg
        readyToBottle => 0xFF22c55e, // grün – fertig
        empty => 0xFF8a8a94, // grau – erledigt
        coarse => 0xFFff6b7a, // rot – da ist was schiefgegangen
        solid => 0xFFff6b7a,
        _ => 0xFF8a8a94,
      };
}
