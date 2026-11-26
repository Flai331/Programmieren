import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../utils/app_utils.dart';
import '../utils/bucket_code.dart';
import '../utils/feedback_service.dart';
import 'database_service.dart';
import 'stock_service.dart';

/// Ein Eimer mit seinem errechneten Inhalt.
class HoneyBucketStatus {
  final HoneyBucketModel bucket;

  /// Summe aller Abfüllungen aus diesem Eimer, in kg.
  final double bottledKg;

  const HoneyBucketStatus({required this.bucket, this.bottledKg = 0});

  /// Was noch drin ist. Abgeleitet, nicht gespeichert: Einwaage minus allem,
  /// was abgefüllt wurde.
  double get currentKg {
    final rest = bucket.filledKg - bottledKg;
    // Rundungsreste aus Fließkomma nicht als Restmenge ausgeben.
    return rest.abs() < 0.001 ? 0 : rest;
  }

  /// Nichts mehr drin – unabhängig davon, ob der Zustand schon auf „leer"
  /// steht. Die beiden können auseinanderlaufen, wenn von Hand abgefüllt
  /// wurde, ohne den Zustand nachzuziehen.
  bool get isEmptied => currentKg <= 0;

  /// Anteil, der noch im Eimer ist – 0.0 bis 1.0.
  double get remainingShare =>
      bucket.filledKg <= 0 ? 0 : (currentKg / bucket.filledKg).clamp(0.0, 1.0);

  bool get needsAttention => bucket.needsAttention;

  String get code => bucket.code;
  String get state => bucket.state;

  /// z.B. „20 kg von 25 kg"
  String get fillLabel =>
      '${AppUtils.formatNumber(currentKg)} kg von '
      '${AppUtils.formatNumber(bucket.filledKg)} kg';

  String get currentLabel => '${AppUtils.formatNumber(currentKg)} kg';
}

/// Rechnung einer Abfüllung: kg im Eimer gegen Gläser im Regal.
class BottlingPlan {
  /// Entnommene Menge in kg.
  final double kg;

  /// Anzahl gefüllter Gläser.
  final int jars;

  /// Füllgewicht eines Glases in Gramm.
  final int jarSizeG;

  const BottlingPlan({
    required this.kg,
    required this.jars,
    required this.jarSizeG,
  });

  /// Was die Gläser nominal wiegen. Weicht von [kg] ab, wenn beim Abfüllen
  /// etwas im Hahn bleibt oder bewusst voller gefüllt wurde.
  double get nominalKg => jars * jarSizeG / 1000;

  /// Differenz zwischen Entnahme und nominalem Gewicht – der Verlust beim
  /// Abfüllen, wenn positiv.
  double get difference => kg - nominalKg;

  bool get isPlausible => difference.abs() <= nominalKg * 0.1 + 0.05;
}

/// Honig im Lager: Eimer, ihre Zustände und das Abfüllen in Gläser.
///
/// Der Inhalt eines Eimers wird abgeleitet, nicht gespeichert – wie beim
/// Saison-Stand und beim Materialbestand. Zustand und Platz dagegen stehen
/// als Spalte am Eimer: Sie werden direkt gesetzt, nicht errechnet. Jede
/// Änderung schreibt zusätzlich ein Ereignis, damit der Verlauf lückenlos
/// bleibt.
class HoneyService {
  final DatabaseService _db;
  final StockService _stock;

  HoneyService([DatabaseService? db, StockService? stock])
      : _db = db ?? DatabaseService(),
        _stock = stock ?? StockService();

  // ── Lesen ──────────────────────────────────────────────────────

  Future<List<HoneyBucketStatus>> loadBuckets() async {
    final buckets = await _db.getAllHoneyBuckets();
    final bottled = await _db.getBottledKgPerBucket();
    return buildStatuses(buckets: buckets, bottled: bottled);
  }

  /// Reine Zuordnung ohne Datenbank – so ist die Logik testbar.
  static List<HoneyBucketStatus> buildStatuses({
    required List<HoneyBucketModel> buckets,
    required Map<String, double> bottled,
  }) =>
      [
        for (final b in buckets)
          HoneyBucketStatus(bucket: b, bottledKg: bottled[b.id] ?? 0),
      ];

  /// Eimer, an denen etwas zu tun ist – leere bleiben außen vor.
  static List<HoneyBucketStatus> needingAttention(
          List<HoneyBucketStatus> alle) =>
      alle
          .where((s) => s.needsAttention && !s.bucket.isEmpty)
          .toList(growable: false);

  /// Noch vorhandene kg je Sorte. Leere Eimer zählen nicht mit.
  static Map<String, double> kgPerVariety(List<HoneyBucketStatus> alle) {
    final summe = <String, double>{};
    for (final s in alle) {
      if (s.currentKg <= 0) continue;
      summe[s.bucket.variety] = (summe[s.bucket.variety] ?? 0) + s.currentKg;
    }
    return summe;
  }

  /// Gesamtmenge Honig in Eimern, in kg.
  static double totalKg(List<HoneyBucketStatus> alle) {
    var summe = 0.0;
    for (final s in alle) {
      if (s.currentKg > 0) summe += s.currentKg;
    }
    return summe;
  }

  /// Eimer nach Zustand gruppieren – Grundlage für die Filterleiste.
  static Map<String, List<HoneyBucketStatus>> byState(
      List<HoneyBucketStatus> alle) {
    final gruppen = <String, List<HoneyBucketStatus>>{};
    for (final s in alle) {
      (gruppen[s.bucket.state] ??= []).add(s);
    }
    return gruppen;
  }

  // ── Anlegen ────────────────────────────────────────────────────

  /// Neuen Eimer anlegen und seinen Code vergeben.
  ///
  /// Die Nummer ist global laufend. Der zurückgegebene Eimer trägt den Code,
  /// der von Hand aufzuschreiben ist – siehe [HoneyBucketModel.labelHint].
  Future<HoneyBucketModel> createBucket({
    required String variety,
    String? varietyName,
    required DateTime harvestDate,
    required double filledKg,
    double? bucketSizeKg,
    double? waterContent,
    String state = HoneyStates.extracted,
    String? location,
    String? labelPhoto,
    String? note,
  }) async {
    final nummer = BucketCode.nextNumber(await _db.getHighestBucketNumber());
    final bucket = HoneyBucketModel(
      id: const Uuid().v4(),
      code: BucketCode.format(variety, nummer),
      number: nummer,
      variety: variety,
      varietyName: varietyName,
      harvestDate: harvestDate,
      bucketSizeKg: bucketSizeKg,
      filledKg: filledKg,
      waterContent: waterContent,
      state: state,
      location: location,
      labelPhoto: labelPhoto,
      note: note,
      createdAt: DateTime.now(),
    );
    await _db.insertHoneyBucket(bucket);
    // Der Anfangszustand gehört in den Verlauf, sonst fehlt der erste
    // Eintrag und der Eimer sieht aus, als hätte er immer so dagestanden.
    await _logEvent(
      bucketId: bucket.id,
      date: harvestDate,
      kind: HoneyEventKinds.state,
      state: state,
      note: 'angelegt',
    );
    FeedbackService.logUserAction('Eimer angelegt', context: {
      'code': bucket.code,
      'kg': filledKg.toString(),
    });
    return bucket;
  }

  // ── Ändern ─────────────────────────────────────────────────────

  /// Zustand setzen und im Verlauf festhalten.
  Future<HoneyBucketModel> setState(
    HoneyBucketModel bucket,
    String newState, {
    DateTime? date,
    String? note,
  }) async {
    final geaendert =
        bucket.copyWith(state: newState, updatedAt: DateTime.now());
    await _db.updateHoneyBucket(geaendert);
    await _logEvent(
      bucketId: bucket.id,
      date: date ?? DateTime.now(),
      kind: HoneyEventKinds.state,
      state: newState,
      note: note,
    );
    return geaendert;
  }

  /// Einen Schritt weiter in der Kette. Gibt den Eimer unverändert zurück,
  /// wenn es keinen nächsten Schritt gibt.
  Future<HoneyBucketModel> advanceState(HoneyBucketModel bucket) async {
    final naechster = HoneyStates.next(bucket.state);
    if (naechster == null) return bucket;
    return setState(bucket, naechster);
  }

  /// Die Markierung setzen oder entfernen – grob kristallin, kandiert.
  ///
  /// Ändert die Haken nicht: das ist kein Arbeitsschritt, sondern etwas, das
  /// dazwischenkommt. Der Weg zurück ist [throughMelitherm].
  Future<HoneyBucketModel> setCrystallization(
    HoneyBucketModel bucket,
    String? value,
  ) async {
    final geaendert = bucket.copyWith(
      crystallization: value,
      clearCrystallization: value == null,
      updatedAt: DateTime.now(),
    );
    await _db.updateHoneyBucket(geaendert);
    await _logEvent(
      bucketId: bucket.id,
      date: DateTime.now(),
      kind: HoneyEventKinds.crystallization,
      note: value == null
          ? 'Markierung entfernt'
          : HoneyCrystallization.labelOf(value),
    );
    return geaendert;
  }

  /// Durch das Melitherm: Markierung weg, zurück auf den ersten Haken.
  ///
  /// Geschleudert und Melitherm sind derselbe Zustand – danach ist der Honig
  /// flüssig, und die Kette beginnt von vorn. Dabei gehen die späteren Haken
  /// verloren, deshalb fragt die Oberfläche vorher nach.
  Future<HoneyBucketModel> throughMelitherm(HoneyBucketModel bucket) async {
    final erster = HoneyStates.stateForTicks(1);
    final geaendert = bucket.copyWith(
      state: erster,
      clearCrystallization: true,
      updatedAt: DateTime.now(),
    );
    await _db.updateHoneyBucket(geaendert);
    await _logEvent(
      bucketId: bucket.id,
      date: DateTime.now(),
      kind: HoneyEventKinds.state,
      state: erster,
      note: 'durch das Melitherm',
    );
    return geaendert;
  }

  // ── Wärmeschrank ───────────────────────────────────────────────

  /// Die Uhr starten: der Eimer steht jetzt im Wärmeschrank.
  ///
  /// Von Hand gestartet, mit Absicht. Ein Haken beschreibt den Honig und
  /// sagt nichts darüber, wo der Eimer steht – deshalb hängt die Uhr nicht
  /// an der Hakenliste.
  ///
  /// Gespeichert wird allein die Verlaufszeile; Fälligkeit und Restzeit
  /// rechnet [HoneyWarmer.fromEvents] daraus. Keine neue Spalte, keine
  /// zweite Wahrheit. Die Stundenzahl steht als Notiz dabei, damit der
  /// Verlauf für einen Menschen lesbar bleibt.
  Future<HoneyWarmer> startWarmer(HoneyBucketModel bucket,
      {DateTime? at}) async {
    final jetzt = at ?? DateTime.now();
    final verlauf = await _db.getHoneyEvents(bucket.id);
    final stunden =
        HoneyWarmer.hoursFor(wasInBefore: HoneyWarmer.wasInBeforeFrom(verlauf));
    await _logEvent(
      bucketId: bucket.id,
      date: jetzt,
      kind: HoneyEventKinds.warmerIn,
      note: '$stunden h',
    );
    return HoneyWarmer(startedAt: jetzt, requiredHours: stunden);
  }

  /// Herausgenommen – die Uhr hört auf.
  Future<void> stopWarmer(HoneyBucketModel bucket, {DateTime? at}) =>
      _logEvent(
        bucketId: bucket.id,
        date: at ?? DateTime.now(),
        kind: HoneyEventKinds.warmerOut,
      );

  /// Lagerplatz setzen und im Verlauf festhalten.
  Future<HoneyBucketModel> setLocation(
    HoneyBucketModel bucket,
    String location, {
    String? photo,
  }) async {
    final geaendert =
        bucket.copyWith(location: location, updatedAt: DateTime.now());
    await _db.updateHoneyBucket(geaendert);
    await _logEvent(
      bucketId: bucket.id,
      date: DateTime.now(),
      kind: HoneyEventKinds.location,
      location: location,
      photo: photo,
    );
    return geaendert;
  }

  // ── Abfüllen ───────────────────────────────────────────────────

  /// Abfüllung rechnen: Aus einer der beiden Angaben die andere ableiten.
  ///
  /// Ein 500-g-Glas wiegt 0,5 kg – Honig wird nach Gewicht verkauft, nicht
  /// nach Volumen. Sind beide Angaben da, bleiben beide stehen; die
  /// Differenz ist dann der Verlust beim Abfüllen.
  static BottlingPlan planBottling({
    required int jarSizeG,
    double? kg,
    int? jars,
  }) {
    if (jarSizeG <= 0) {
      return BottlingPlan(kg: kg ?? 0, jars: jars ?? 0, jarSizeG: jarSizeG);
    }
    if (jars != null && kg != null) {
      return BottlingPlan(kg: kg, jars: jars, jarSizeG: jarSizeG);
    }
    if (jars != null) {
      return BottlingPlan(
          kg: jars * jarSizeG / 1000, jars: jars, jarSizeG: jarSizeG);
    }
    if (kg != null) {
      // Abgerundet: Ein halb volles Glas kommt nicht ins Regal.
      final anzahl = (kg * 1000 / jarSizeG).floor();
      return BottlingPlan(kg: kg, jars: anzahl, jarSizeG: jarSizeG);
    }
    return BottlingPlan(kg: 0, jars: 0, jarSizeG: jarSizeG);
  }

  /// Honig aus dem Eimer in Gläser füllen.
  ///
  /// Schreibt drei Dinge: das Abfüll-Ereignis am Eimer, den Zugang beim
  /// Glas-Posten und – falls leere Gläser dieser Größe im Lager geführt
  /// werden – deren Abgang. Ist der Eimer danach leer, wird sein Zustand
  /// nachgezogen.
  Future<void> bottle({
    required HoneyBucketModel bucket,
    required StockItemModel jarItem,
    required BottlingPlan plan,
    DateTime? date,
    String? note,
  }) async {
    final wann = date ?? DateTime.now();

    await _logEvent(
      bucketId: bucket.id,
      date: wann,
      kind: HoneyEventKinds.bottling,
      removedKg: plan.kg,
      jarItemId: jarItem.id,
      jarCount: plan.jars,
      note: note,
    );

    // Gefüllte Gläser kommen ins Lager.
    await _stock.book(
      itemId: jarItem.id,
      quantity: plan.jars.toDouble(),
      reason: StockReasons.bottling,
      date: wann,
      note: 'aus ${bucket.code}',
    );

    // Leere Gläser derselben Größe gehen ab – aber nur, wenn sie überhaupt
    // geführt werden. Wer sie nicht im Lager hat, soll damit nicht behelligt
    // werden.
    final leere = await findEmptyJarItem(jarItem.jarSizeG);
    if (leere != null) {
      await _stock.book(
        itemId: leere.id,
        quantity: -plan.jars.toDouble(),
        reason: StockReasons.bottling,
        date: wann,
        note: 'abgefüllt ${bucket.code}',
      );
    }

    // Ist nichts mehr drin, den Zustand nachziehen.
    final bottled = await _db.getBottledKgPerBucket();
    final status =
        HoneyBucketStatus(bucket: bucket, bottledKg: bottled[bucket.id] ?? 0);
    if (status.isEmptied && bucket.state != HoneyStates.empty) {
      await setState(bucket, HoneyStates.empty,
          date: wann, note: 'vollständig abgefüllt');
    }

    FeedbackService.logUserAction('Abgefüllt', context: {
      'eimer': bucket.code,
      'glaeser': plan.jars.toString(),
      'kg': plan.kg.toString(),
    });
  }

  /// Posten für leere Gläser einer Größe – null, wenn keiner geführt wird.
  Future<StockItemModel?> findEmptyJarItem(int? jarSizeG) async {
    if (jarSizeG == null || jarSizeG <= 0) return null;
    final alle = await _db.getAllStockItems();
    for (final item in alle) {
      if (item.isEmptyJar && item.jarSizeG == jarSizeG) return item;
    }
    return null;
  }

  /// Posten für abgefüllte Gläser einer Sorte und Größe.
  Future<StockItemModel?> findFilledJarItem({
    required String variety,
    required int jarSizeG,
  }) async {
    final alle = await _db.getAllStockItems();
    for (final item in alle) {
      if (item.isFilledJar &&
          item.variety == variety &&
          item.jarSizeG == jarSizeG) {
        return item;
      }
    }
    return null;
  }

  // ── Code erkennen ──────────────────────────────────────────────

  /// Eine Lesung (Kamera oder Tastatur) einem Eimer zuordnen.
  ///
  /// Gibt das Abgleichergebnis samt Eimer zurück. Bei Mehrdeutigkeit bleibt
  /// [HoneyCodeLookup.bucket] leer und die Kandidaten stehen zur Auswahl –
  /// geraten wird nicht.
  Future<HoneyCodeLookup> lookupCode(String read) async {
    final codes = await _db.getAllBucketCodes();
    final treffer = BucketCode.match(read, codes);
    if (treffer.code == null) {
      return HoneyCodeLookup(match: treffer, candidates: const []);
    }
    final bucket = await _db.getHoneyBucketByCode(treffer.code!);
    return HoneyCodeLookup(match: treffer, bucket: bucket);
  }

  /// Eine Kamera-Lesung einem Eimer zuordnen.
  ///
  /// Wie [lookupCode], nur mit vielen Bruchstücken statt einer Eingabe:
  /// Ein Foto liefert immer mehr Text als den Code. Welches Bruchstück
  /// gewinnt, entscheidet [BucketCode.matchAny] – zeichengenau schlägt
  /// korrigiert, und bei Gleichstand wird gefragt.
  Future<HoneyCodeLookup> lookupReading(List<String> fragments) async {
    final codes = await _db.getAllBucketCodes();
    final treffer = BucketCode.matchAny(fragments, codes);
    if (treffer.code == null) {
      return HoneyCodeLookup(match: treffer, candidates: const []);
    }
    final bucket = await _db.getHoneyBucketByCode(treffer.code!);
    return HoneyCodeLookup(match: treffer, bucket: bucket);
  }

  // ── intern ─────────────────────────────────────────────────────

  Future<void> _logEvent({
    required String bucketId,
    required DateTime date,
    required String kind,
    String? state,
    double? removedKg,
    String? jarItemId,
    int? jarCount,
    String? location,
    String? note,
    String? photo,
  }) async {
    await _db.insertHoneyEvent(HoneyBucketEventModel(
      id: const Uuid().v4(),
      bucketId: bucketId,
      date: date,
      kind: kind,
      state: state,
      removedKg: removedKg,
      jarItemId: jarItemId,
      jarCount: jarCount,
      location: location,
      note: note,
      photo: photo,
      createdAt: DateTime.now(),
    ));
  }
}

/// Ergebnis einer Code-Suche.
class HoneyCodeLookup {
  final BucketCodeMatch match;

  /// Der gefundene Eimer, null bei Mehrdeutigkeit oder ohne Treffer.
  final HoneyBucketModel? bucket;

  /// Bei Mehrdeutigkeit: die Eimer, die in Frage kommen.
  final List<HoneyBucketModel> candidates;

  const HoneyCodeLookup({
    required this.match,
    this.bucket,
    this.candidates = const [],
  });

  bool get isResolved => bucket != null;

  bool get isAmbiguous =>
      match.confidence == BucketCodeConfidence.ambiguous;

  /// Soll der Treffer dem Nutzer zur Bestätigung gezeigt werden?
  bool get needsConfirmation => match.needsConfirmation;
}
