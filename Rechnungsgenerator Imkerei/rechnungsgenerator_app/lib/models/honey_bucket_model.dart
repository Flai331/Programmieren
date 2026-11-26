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

  /// Grob kristallin oder kandiert, siehe [HoneyCrystallization]; null, wenn
  /// der Honig in Ordnung ist.
  ///
  /// Steht neben dem Zustand statt in der Kette: das ist kein Arbeitsschritt,
  /// sondern etwas, das dazwischenkommt. Der Weg zurück ist das Melitherm.
  final String? crystallization;

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
    this.crystallization,
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
  ///
  /// Der Zustand sagt das meiste, eine gesetzte Markierung kommt dazu. Die
  /// Wärmeschrank-Uhr kennt das Modell nicht – die steckt im Verlauf, deshalb
  /// liegt jener Teil beim HoneyService.
  bool get needsAttention =>
      HoneyStates.needsAttention(state) || crystallization != null;

  bool get isEmpty => HoneyStates.normalize(state) == HoneyStates.empty;

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
        'crystallization': crystallization,
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
        state: HoneyStates.normalize(
            (m['state'] as String?) ?? HoneyStates.extracted),
        crystallization: m['crystallization'] as String?,
        location: m['location'] as String?,
        labelPhoto: m['label_photo'] as String?,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  /// Eine Kopie mit geänderten Feldern.
  ///
  /// [clearCrystallization] gibt es, weil `null` hier „unverändert" heißt: zum
  /// Löschen der Markierung – nach dem Melitherm – braucht es einen eigenen
  /// Schalter.
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
    String? crystallization,
    bool clearCrystallization = false,
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
        crystallization: clearCrystallization
            ? null
            : (crystallization ?? this.crystallization),
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

  /// Eimer in den Wärmeschrank gestellt; `date` ist der Startpunkt der Uhr.
  static const String warmerIn = 'waermeschrank_ein';

  /// Eimer herausgenommen. Die Zahl dieser Zeilen entscheidet, ob der nächste
  /// Durchgang 48 oder 24 Stunden braucht – siehe [HoneyWarmer].
  static const String warmerOut = 'waermeschrank_aus';

  static const Map<String, String> _labels = {
    state: 'Zustand',
    bottling: 'Abfüllung',
    location: 'Platz',
    note: 'Notiz',
    warmerIn: 'In den Wärmeschrank',
    warmerOut: 'Aus dem Wärmeschrank',
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

/// Der Weg des Honigs im Eimer – eine Hakenliste, keine Auswahl.
///
/// Die vier Schritte bauen aufeinander auf: gerührt kann nicht sein, was nicht
/// geimpft war. Darum trägt ein Eimer nur EINEN Wert – den weitesten
/// erreichten Schritt – und welche Haken sitzen, ergibt sich daraus. Hakt man
/// einen Schritt an, haken sich die vorherigen mit. Abgeleitet, nicht
/// gespeichert.
///
/// Aus demselben Grund gibt es „noch zu impfen" und „noch zu rühren" nicht
/// mehr als eigene Zustände: ein leeres Kästchen sagt das schon.
///
/// Grob kristalliner und kandierter Honig sind keine Schritte, sondern ein
/// Zustand, der dazwischenkommt – sie stehen als [HoneyCrystallization] neben
/// der Liste. Der Weg zurück ist das Melitherm, nach dem der Honig im selben
/// Zustand ist wie frisch geschleuderter.
///
/// Zu jedem Zustand gehört eine Strichzahl für das Kästchen, das von Hand
/// auf den Eimer gemalt wird. Die App liest diese Striche nicht – sie führt
/// den Zustand selbst und bleibt die Wahrheit. Die Striche sind allein für
/// das Auge am Regal.
class HoneyStates {
  /// Frisch geschleudert – oder aus dem Melitherm. Derselbe Zustand.
  static const String extracted = 'geschleudert';

  /// Geimpft. Ab hier wird täglich gerührt, hier ruht nichts.
  static const String seeded = 'geimpft';

  static const String stirred = 'geruehrt';
  static const String readyToBottle = 'abfuellfertig';

  /// Leergeräumt. Kein Haken zum Antippen: das setzt der HoneyService selbst,
  /// sobald nichts mehr im Eimer ist.
  static const String empty = 'leer';

  /// Die Haken, in der Reihenfolge der Arbeit.
  static const List<String> steps = [
    extracted,
    seeded,
    stirred,
    readyToBottle,
  ];

  /// Jeder Wert, den ein Eimer tragen kann: die Haken und dazu [empty].
  static const List<String> all = [...steps, empty];

  static const Map<String, String> _labels = {
    extracted: 'geschleudert / Melitherm',
    seeded: 'geimpft – täglich rühren',
    stirred: 'fertig gerührt',
    readyToBottle: 'abfüllfertig',
    empty: 'abgefüllt, leer',
  };

  static String labelOf(String state) => _labels[normalize(state)] ?? state;

  /// Zustandswerte aus älteren Fassungen auf die heutige Kette abbilden.
  ///
  /// Die Migration auf Schema v6 schreibt die Datenbank einmalig um. Diese
  /// Abbildung ist der Gürtel dazu: taucht doch ein alter Wert auf – aus einer
  /// Sicherung, aus einem Gerät, das die Migration nie gesehen hat –, fällt er
  /// nicht als unbekannter Zustand durch.
  ///
  /// Dass `grob` und `fest` hier beide auf [extracted] zeigen, verliert die
  /// Information, DASS der Honig kristallin war. Genau deshalb setzt die
  /// Migration zusätzlich die Spalte `crystallization`; eine Abbildung von
  /// Zeichenkette auf Zeichenkette kann das nicht leisten.
  static const Map<String, String> legacy = {
    'frisch': extracted,
    'zu_impfen': extracted,
    'zu_ruehren': seeded,
    'grob': extracted,
    'fest': extracted,
  };

  /// Einen gespeicherten Wert auf einen heute gültigen bringen.
  ///
  /// Unbekanntes wird zum ersten Haken: lieber behaupten, es sei noch nichts
  /// getan, als Arbeit als erledigt ausgeben, die niemand getan hat.
  static String normalize(String state) {
    if (all.contains(state)) return state;
    return legacy[state] ?? extracted;
  }

  /// Wie viele Haken sitzen? 1 bis 4.
  ///
  /// Der erste Haken sitzt immer – der Eimer existiert, weil geschleudert
  /// wurde. Ein leerer Eimer ist durch und zählt als voll abgehakt.
  static int ticksOf(String state) {
    final wert = normalize(state);
    if (wert == empty) return steps.length;
    final i = steps.indexOf(wert);
    return i < 0 ? 1 : i + 1;
  }

  /// Der Zustand, der zu `anzahl` Haken gehört; 1 ist der erste Haken.
  ///
  /// Unter 1 gibt es nichts, deshalb die Klammer: Haken 1 lässt sich nicht
  /// abhaken.
  static String stateForTicks(int anzahl) =>
      steps[anzahl.clamp(1, steps.length) - 1];

  /// Ist `schritt` erledigt, wenn der Eimer auf `state` steht?
  static bool isDone(String state, String schritt) =>
      ticksOf(state) >= ticksOf(schritt);

  /// Der nächste Schritt, null am Ende der Kette.
  ///
  /// Nach [readyToBottle] kommt nichts mehr zum Anhaken: was folgt, ist das
  /// Abfüllen, und [empty] setzt der Dienst selbst.
  static String? next(String state) {
    final i = steps.indexOf(normalize(state));
    if (i < 0 || i + 1 >= steps.length) return null;
    return steps[i + 1];
  }

  /// Wartet dieser Zustand auf eine Arbeit von mir?
  ///
  /// [extracted] heißt: noch zu impfen. [seeded] heißt: täglich rühren – und
  /// das bleibt Arbeit, bis „fertig gerührt" gehakt ist.
  static bool needsAttention(String state) {
    final wert = normalize(state);
    return wert == extracted || wert == seeded;
  }

  /// Striche für das handgemalte Kästchen auf dem Eimer.
  ///
  /// Sie wachsen mit der Zahl der Haken und bleiben genau die, die heute schon
  /// auf den Eimern stehen.
  static String strokeHint(String state) => switch (normalize(state)) {
        seeded => '|',
        stirred => '||',
        readyToBottle => '|||',
        empty => '✕',
        _ => '',
      };

  /// Farbe zur Anzeige, als ARGB-Wert. Bewusst eine Zahl statt `Color`.
  static int colorOf(String state) => switch (normalize(state)) {
        extracted => 0xFF60a5fa, // blau – frisch, noch zu impfen
        seeded => 0xFFf59e0b, // gelb – wartet täglich auf mich
        stirred => 0xFF4ade80, // grün – auf gutem Weg
        readyToBottle => 0xFF22c55e, // grün – fertig
        empty => 0xFF8a8a94, // grau – erledigt
        _ => 0xFF8a8a94,
      };
}

/// Grob kristalliner und kandierter Honig.
///
/// Kein Arbeitsschritt, sondern ein Zustand, der dazwischenkommt – deshalb
/// eine Markierung neben der Hakenliste und kein Haken in der Kette. Der Weg
/// zurück ist das Melitherm: danach ist der Honig im selben Zustand wie frisch
/// geschleuderter, also wieder auf dem ersten Haken.
///
/// Bewusst nicht auf den Eimer gemalt: kandierten Honig sieht man durch den
/// Eimer, dafür braucht es keinen Strich.
class HoneyCrystallization {
  static const String coarse = 'grob';
  static const String solid = 'fest';

  static const List<String> all = [coarse, solid];

  static const Map<String, String> _labels = {
    coarse: 'grob kristallin',
    solid: 'kandiert / fest',
  };

  static String labelOf(String value) => _labels[value] ?? value;

  static bool isKnown(String value) => _labels.containsKey(value);

  /// Rot, wie die Abzweige vorher: da ist etwas schiefgegangen.
  static const int color = 0xFFff6b7a;
}

/// Die Wärmeschrank-Uhr eines Eimers.
///
/// Ein reiner Wert ohne Datenbankzugriff, damit die Rechnung ohne Gerät
/// prüfbar bleibt. Gespeichert wird nur, WANN der Eimer hineingestellt wurde –
/// als Ereigniszeile im Eimer-Verlauf. Fälligkeit und Restzeit ergeben sich
/// daraus.
///
/// Die Uhr hängt ausdrücklich nicht an der Hakenliste: ein Haken beschreibt
/// den Honig und heißt nicht, dass der Eimer im Schrank steht. Gestartet wird
/// sie von Hand.
class HoneyWarmer {
  /// Beim ersten Mal braucht ein Eimer 48 Stunden.
  static const int firstHours = 48;

  /// War er schon einmal drin, genügen 24.
  static const int repeatHours = 24;

  /// Wann der Eimer hineingestellt wurde.
  final DateTime startedAt;

  /// Wie lange er diesmal braucht – [firstHours] oder [repeatHours].
  final int requiredHours;

  const HoneyWarmer({required this.startedAt, required this.requiredHours});

  /// Die Stundenzahl für den nächsten Durchgang.
  ///
  /// `wasInBefore` kommt aus dem Eimer-Verlauf: stand der Eimer schon einmal
  /// im Schrank, ist er durchgewärmt und braucht weniger.
  static int hoursFor({required bool wasInBefore}) =>
      wasInBefore ? repeatHours : firstHours;

  /// Wann er fertig ist.
  DateTime get dueAt => startedAt.add(Duration(hours: requiredHours));

  /// Wie lange er schon drin steht.
  Duration elapsed(DateTime now) => now.difference(startedAt);

  /// Wie lange noch – negativ, wenn er überfällig ist.
  Duration remaining(DateTime now) => dueAt.difference(now);

  bool isDue(DateTime now) => !now.isBefore(dueAt);

  /// „noch 34 h", „noch 45 min", „seit 3 h fällig".
  ///
  /// Stunden und Minuten, keine Tage: eine 48-Stunden-Uhr in Tagen zu lesen
  /// hilft am Wärmeschrank niemandem.
  String readableRemaining(DateTime now) {
    if (isDue(now)) {
      final ueber = -remaining(now).inMinutes;
      return ueber < 60 ? 'fällig' : 'seit ${ueber ~/ 60} h fällig';
    }
    final rest = remaining(now);
    if (rest.inMinutes < 60) return 'noch ${rest.inMinutes} min';
    return 'noch ${rest.inHours} h';
  }
}
