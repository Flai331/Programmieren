// ═══════════════════════════════════════════════════════════════
//  RECHNUNGSNUMMER-GENERATOR
//
//  Pattern-Variablen (deutsch):
//    {JAHR}        → 2026 (4-stellig)
//    {JAHR2}       → 26   (2-stellig)
//    {MONAT}       → 05   (0-padded)
//    {NR}          → 001  (3-stellig, default)
//    {NR:N}        → N-stellig (z.B. {NR:4} → 0001)
//    {KUNDE}       → erste 3 Buchstaben Kundenname (Großbuchstaben)
//    {KUNDE:N}     → erste N Buchstaben
//    {KUNDENNR}    → fortlaufende Kundennummer (42)
//    {KUNDENNR:N}  → N-stellig (z.B. {KUNDENNR:4} → 0042)
//
//  Beispiele:
//    RE-{JAHR}-{NR:3}            → RE-2026-001
//    {JAHR}{MONAT}-{NR:4}        → 202605-0001
//    {KUNDE:3}-{JAHR}-{NR}       → MUS-2026-001
//    K{KUNDENNR:4}-{JAHR}-{NR:3} → K0042-2026-001
// ═══════════════════════════════════════════════════════════════

class InvoiceNumberGenerator {
  static const String defaultPattern = 'RE-{JAHR}-{NR:3}';
  static const String quoteDefaultPattern = 'AN-{JAHR}-{NR:3}';

  /// Die Platzhalter, die dieser Generator kennt.
  ///
  /// `KUNDENNR` steht vor `KUNDE`, sonst schluckte die kürzere Alternative
  /// den Anfang der längeren.
  static final RegExp _bekannt = RegExp(
      r'^\{(JAHR2|JAHR|MONAT|NR(?::\d+)?|KUNDENNR(?::\d+)?|KUNDE(?::\d+)?)\}$');

  /// Irgendein geschweiftes Gebilde – bekannt oder nicht.
  static final RegExp _geschweift = RegExp(r'\{[^{}]*\}');

  /// Eine Laufnummer, ohne die jede Rechnung gleich hieße.
  static final RegExp _laufnummer = RegExp(r'\{NR(?::(\d+))?\}');

  /// Platzhalter im Format, die der Generator nicht kennt.
  ///
  /// Die bleiben sonst wörtlich stehen: aus `RE-{YEAR}-{SEQ:3}` wird keine
  /// Nummer, sondern genau diese Zeichenkette – auf jeder Rechnung dieselbe.
  static List<String> unknownPlaceholders(String pattern) => _geschweift
      .allMatches(pattern)
      .map((m) => m.group(0)!)
      .where((p) => !_bekannt.hasMatch(p))
      .toList();

  /// Enthält das Format eine Laufnummer?
  static bool hasSequence(String pattern) => _laufnummer.hasMatch(pattern);

  /// Was an einem Format nicht stimmt, in Klartext.
  ///
  /// Leer heißt: brauchbar. Die Liste steht in den Einstellungen unter dem
  /// Eingabefeld, damit ein Tippfehler auffällt, bevor er auf einem Beleg
  /// landet.
  static List<String> problems(String pattern) {
    final gefunden = <String>[];
    if (pattern.trim().isEmpty) {
      gefunden.add('Das Format ist leer.');
      return gefunden;
    }
    final unbekannt = unknownPlaceholders(pattern);
    if (unbekannt.isNotEmpty) {
      gefunden.add(unbekannt.length == 1
          ? 'Den Platzhalter ${unbekannt.first} gibt es nicht.'
          : 'Diese Platzhalter gibt es nicht: ${unbekannt.join(', ')}.');
    }
    if (!hasSequence(pattern)) {
      gefunden.add('Ohne {NR} bekäme jede Rechnung dieselbe Nummer.');
    }
    return gefunden;
  }

  /// Taugt das Format, um daraus Nummern zu erzeugen?
  static bool isUsable(String pattern) => problems(pattern).isEmpty;

  /// Das Format, das wirklich benutzt wird: das eigene, wenn es taugt, sonst
  /// die Vorgabe.
  ///
  /// Lieber eine richtige Nummer nach Vorgabe als geschweifte Klammern auf
  /// einer Rechnung – und zweimal dieselbe Nummer wäre schlimmer als ein
  /// Format, das nicht nach Wunsch aussieht.
  static String effectivePattern(String pattern, {String? fallback}) =>
      isUsable(pattern) ? pattern : (fallback ?? defaultPattern);

  /// Generiert die nächste Rechnungsnummer aus Pattern + Kontext.
  static String generate({
    required String pattern,
    required List<String> existingNumbers,
    String? customerName,
    int? customerNumber,
    DateTime? date,
    String? fallback,
  }) {
    pattern = effectivePattern(pattern, fallback: fallback);
    final now = date ?? DateTime.now();

    final seqMatch = RegExp(r'\{NR(?::(\d+))?\}').firstMatch(pattern);
    final seqWidth = seqMatch != null && seqMatch.group(1) != null
        ? int.parse(seqMatch.group(1)!)
        : 3;
    final nextSeq = _nextSequence(
        pattern, existingNumbers, now, customerName, customerNumber);

    String result = pattern;
    result = result.replaceAll('{JAHR}', now.year.toString());
    result = result.replaceAll(
        '{JAHR2}', now.year.toString().substring(2));
    result = result.replaceAll(
        '{MONAT}', now.month.toString().padLeft(2, '0'));
    result = result.replaceAllMapped(
      RegExp(r'\{NR(?::(\d+))?\}'),
      (_) => nextSeq.toString().padLeft(seqWidth, '0'),
    );
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDE(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 3;
        return _customerCode(customerName ?? '', n);
      },
    );
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDENNR(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 0;
        final num = customerNumber ?? 0;
        return n > 0 ? num.toString().padLeft(n, '0') : num.toString();
      },
    );

    return result;
  }

  /// Vorschau ohne echten NR (zeigt Platzhalter-Nummer).
  ///
  /// Zeigt, was wirklich auf der Rechnung stünde – also die Vorgabe, wenn das
  /// eigene Format nicht taugt. Dass ausgewichen wurde, sagt daneben
  /// [problems]; stillschweigend etwas anderes zu zeigen als zu drucken wäre
  /// die schlechteste aller Möglichkeiten.
  static String preview(String pattern,
      {String? customerName, int? customerNumber, String? fallback}) {
    final now = DateTime.now();
    String result = effectivePattern(pattern, fallback: fallback);
    result = result.replaceAll('{JAHR}', now.year.toString());
    result = result.replaceAll(
        '{JAHR2}', now.year.toString().substring(2));
    result = result.replaceAll(
        '{MONAT}', now.month.toString().padLeft(2, '0'));
    result = result.replaceAllMapped(
      RegExp(r'\{NR(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 3;
        return '1'.padLeft(n, '0');
      },
    );
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDE(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 3;
        return _customerCode(customerName ?? 'Mustermann', n);
      },
    );
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDENNR(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 0;
        final num = customerNumber ?? 42;
        return n > 0 ? num.toString().padLeft(n, '0') : num.toString();
      },
    );
    return result;
  }

  /// Liste der verfügbaren Variablen.
  static const List<PatternVariable> variables = [
    PatternVariable('{JAHR}', 'Jahr 4-stellig', '2026'),
    PatternVariable('{JAHR2}', 'Jahr 2-stellig', '26'),
    PatternVariable('{MONAT}', 'Monat (0-padded)', '05'),
    PatternVariable('{NR}', 'Laufnummer 3-stellig', '001'),
    PatternVariable('{NR:4}', 'Laufnummer 4-stellig', '0001'),
    PatternVariable('{KUNDE}', 'Kürzel Kundenname (3 Zeichen)', 'MUS'),
    PatternVariable('{KUNDE:5}', 'Kürzel Kundenname (5 Zeichen)', 'MUSTE'),
    PatternVariable('{KUNDENNR}', 'Kundennummer', '42'),
    PatternVariable('{KUNDENNR:4}', 'Kundennummer 4-stellig', '0042'),
  ];

  // ── Interne Hilfsmethoden ──────────────────────────────────────

  static int _nextSequence(
    String pattern,
    List<String> existingNumbers,
    DateTime now,
    String? customerName,
    int? customerNumber,
  ) {
    if (existingNumbers.isEmpty) return 1;

    final seqIdx = pattern.indexOf(RegExp(r'\{NR(?::(\d+))?\}'));
    if (seqIdx < 0) return existingNumbers.length + 1;

    final prefixPattern = pattern.substring(0, seqIdx);
    final resolvedPrefix = _resolveWithoutSeq(
        prefixPattern, now, customerName, customerNumber);

    final seqEnd = pattern.indexOf('}', seqIdx) + 1;
    final suffixPattern =
        seqEnd < pattern.length ? pattern.substring(seqEnd) : '';
    final resolvedSuffix = _resolveWithoutSeq(
        suffixPattern, now, customerName, customerNumber);

    int maxSeq = 0;
    for (final num in existingNumbers) {
      if (!num.startsWith(resolvedPrefix)) continue;
      if (resolvedSuffix.isNotEmpty && !num.endsWith(resolvedSuffix)) {
        continue;
      }
      final inner = num.substring(resolvedPrefix.length,
          num.length - resolvedSuffix.length);
      final parsed = int.tryParse(inner);
      if (parsed != null && parsed > maxSeq) maxSeq = parsed;
    }
    return maxSeq + 1;
  }

  static String _resolveWithoutSeq(String pattern, DateTime now,
      String? customerName, int? customerNumber) {
    String result = pattern;
    result = result.replaceAll('{JAHR}', now.year.toString());
    result = result.replaceAll(
        '{JAHR2}', now.year.toString().substring(2));
    result = result.replaceAll(
        '{MONAT}', now.month.toString().padLeft(2, '0'));
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDE(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 3;
        return _customerCode(customerName ?? '', n);
      },
    );
    // KUNDENNR mit echter Kundennummer auflösen (nicht strippen!),
    // damit Sequenz pro Kunde scoped ist statt über alle Kunden zu laufen.
    result = result.replaceAllMapped(
      RegExp(r'\{KUNDENNR(?::(\d+))?\}'),
      (m) {
        final n = m.group(1) != null ? int.parse(m.group(1)!) : 0;
        final num = customerNumber ?? 0;
        return n > 0 ? num.toString().padLeft(n, '0') : num.toString();
      },
    );
    return result;
  }

  static String _customerCode(String name, int length) {
    final clean = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) return 'XXX'.substring(0, length.clamp(1, 3));
    return clean.length >= length
        ? clean.substring(0, length)
        : clean.padRight(length, 'X');
  }
}

class PatternVariable {
  final String variable;
  final String description;
  final String example;

  const PatternVariable(this.variable, this.description, this.example);
}
