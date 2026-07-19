/// Regelbasierte Extraktion aus OCR-Text — bewusst rein lokal und ohne
/// Cloud-KI. Alle Funktionen sind pur und damit unit-testbar.
library;

/// Deutsche Monatsnamen (auch abgekürzt) → Monatsnummer.
const Map<String, int> _germanMonths = {
  'januar': 1, 'jan': 1,
  'februar': 2, 'feb': 2,
  'märz': 3, 'maerz': 3, 'mrz': 3,
  'april': 4, 'apr': 4,
  'mai': 5,
  'juni': 6, 'jun': 6,
  'juli': 7, 'jul': 7,
  'august': 8, 'aug': 8,
  'september': 9, 'sep': 9, 'sept': 9,
  'oktober': 10, 'okt': 10,
  'november': 11, 'nov': 11,
  'dezember': 12, 'dez': 12,
};

final _numericDate = RegExp(r'\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4}|\d{2})\b');
final _writtenDate = RegExp(
  r'\b(\d{1,2})\.?\s(Januar|Februar|März|Maerz|April|Mai|Juni|Juli|August|'
  r'September|Oktober|November|Dezember|Jan|Feb|Mrz|Apr|Jun|Jul|Aug|Sep|'
  r'Sept|Okt|Nov|Dez)\.?\s(\d{4})\b',
  caseSensitive: false,
);
final _isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

/// Alle plausiblen Datumsangaben im Text, in Reihenfolge des Auftretens.
List<DateTime> extractDates(String text, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final results = <({int pos, DateTime date})>[];

  void add(int pos, int year, int month, int day) {
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return;
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month) return; // z. B. 31.02.
    // Plausibel: nicht älter als 30 Jahre, höchstens 2 Jahre in der Zukunft.
    if (date.year < reference.year - 30 ||
        date.isAfter(reference.add(const Duration(days: 730)))) {
      return;
    }
    results.add((pos: pos, date: date));
  }

  for (final m in _numericDate.allMatches(text)) {
    add(m.start, int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  for (final m in _writtenDate.allMatches(text)) {
    final month = _germanMonths[m[2]!.toLowerCase().replaceAll('.', '')];
    if (month != null) {
      add(m.start, int.parse(m[3]!), month, int.parse(m[1]!));
    }
  }
  for (final m in _isoDate.allMatches(text)) {
    add(m.start, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  results.sort((a, b) => a.pos.compareTo(b.pos));
  return [for (final r in results) r.date];
}

/// Das wahrscheinlichste Dokumentdatum: Briefe tragen ihr Datum fast immer
/// im Kopf, daher gewinnt die erste Datumsangabe im Text.
DateTime? guessDocDate(String text, {DateTime? now}) {
  final dates = extractDates(text, now: now);
  return dates.isEmpty ? null : dates.first;
}

/// Keyword-Regeln für den Dokumenttyp mit Gewichtung.
///
/// `(muster, gewicht)`: Muster ist ein Teilstring oder — für generische
/// Wörter wie "vertrag", die in fast jedem Brief beiläufig vorkommen —
/// eine RegExp mit Wortgrenzen. Hohe Gewichte = eindeutige Begriffe.
/// Bei Punktgleichheit gewinnt der frühere Eintrag (spezifischere Typen
/// stehen vorn).
final List<(String type, List<(Pattern, int)> rules)> _typeRules = [
  ('Kontoauszug', [('kontoauszug', 3), ('auszug nr', 3)]),
  ('Versicherungspolice', [
    ('versicherungsschein', 3),
    ('versicherungspolice', 3),
    (RegExp(r'\bpolice\b'), 2),
  ]),
  ('Gehaltsabrechnung', [
    ('gehaltsabrechnung', 3),
    ('lohnabrechnung', 3),
    ('entgeltabrechnung', 3),
    ('verdienstabrechnung', 3),
  ]),
  ('Mahnung', [('mahnung', 3), ('zahlungserinnerung', 3)]),
  ('Kündigung', [
    (RegExp(r'\bkündigung\b'), 2),
    (RegExp(r'\bkuendigung\b'), 2),
    ('kündigungsbestätigung', 3),
    ('vertragsbeendigung', 2),
  ]),
  ('Steuerunterlage', [
    ('steuerbescheid', 3),
    ('einkommensteuer', 2),
    ('lohnsteuerbescheinigung', 3),
    ('finanzamt', 2),
  ]),
  ('Bescheid', [(RegExp(r'\bbescheid\b'), 2)]),
  ('Bescheinigung', [
    ('bescheinigung', 3),
    ('nachweis über', 2),
    ('zertifikat', 2),
  ]),
  ('Arztunterlage', [
    ('arztbrief', 3),
    (RegExp(r'\bbefund\b'), 2),
    (RegExp(r'\bdiagnose\b'), 2),
    ('impfung', 2),
  ]),
  ('Urkunde', [(RegExp(r'\burkunde\b'), 2), (RegExp(r'\bzeugnis\b'), 2)]),
  ('Rechnung', [
    ('rechnung', 2),
    ('invoice', 2),
    ('zu zahlender betrag', 2),
    ('zahlbetrag', 2),
  ]),
  ('Mitteilung', [
    (RegExp(r'\bmitteilung\b'), 3),
    ('wichtige information', 2),
    ('informationen zu ihrem', 2),
    ('änderung ihrer', 2),
    ('anpassung ihrer', 2),
    ('wir informieren sie', 2),
  ]),
  // "Vertrag" ist ein notorisches Streuwort ("zu Ihrem Vertrag", …):
  // niedrig gewichtet und nur als eigenständiges Wort — Komposita wie
  // "Vertragsnummer" zählen nicht. Ein echter Vertrag gewinnt über
  // die spezifischen Begriffe.
  ('Vertrag', [
    (RegExp(r'\bvertrag\b'), 1),
    ('vertragsbedingungen', 2),
    ('mietvertrag', 3),
    ('kaufvertrag', 3),
    ('arbeitsvertrag', 3),
    (RegExp(r'\bvereinbarung\b'), 1),
  ]),
];

/// Dokumenttyp per gewichtetem Keyword-Score erraten; `null` wenn nichts
/// passt. Treffer im Kopfbereich (erste ~400 Zeichen) zählen einen Punkt
/// extra, weil Überschriften den Typ am zuverlässigsten verraten.
String? guessDocType(String text) {
  final lower = text.toLowerCase();
  final head = lower.length > 400 ? lower.substring(0, 400) : lower;

  String? best;
  var bestScore = 0;
  for (final (type, rules) in _typeRules) {
    var score = 0;
    for (final (pattern, weight) in rules) {
      final matches = pattern is RegExp
          ? pattern.hasMatch(lower)
          : lower.contains(pattern as String);
      if (matches) {
        final inHead = pattern is RegExp
            ? pattern.hasMatch(head)
            : head.contains(pattern as String);
        score += weight + (inHead ? 1 : 0);
      }
    }
    if (score > bestScore) {
      best = type;
      bestScore = score;
    }
  }
  return best;
}

final _ibanCandidate =
    RegExp(r'\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]{2,4}){3,8}\b');

/// IBAN-Prüfsumme (ISO 13616, mod 97).
bool isValidIban(String iban) {
  final s = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (s.length < 15 || s.length > 34) return false;
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(s)) return false;
  final rearranged = s.substring(4) + s.substring(0, 4);
  var remainder = 0;
  for (final char in rearranged.codeUnits) {
    final value = char >= 0x41 ? char - 0x41 + 10 : char - 0x30;
    remainder = (remainder * (value >= 10 ? 100 : 10) + value) % 97;
  }
  return remainder == 1;
}

/// Beschriftete Referenznummern: "Kundennummer: 123-456" usw.
final _labeledRef = RegExp(
  r'(Versicherungsschein(?:-?\s?Nr\.?(?:ummer)?)?|Vertragsnummer|Vertrags-?Nr\.?|'
  r'Kundennummer|Kunden-?Nr\.?|Rechnungsnummer|Rechnungs-?Nr\.?|'
  r'Steuernummer|Steuer-?Nr\.?|Aktenzeichen|Vorgangsnummer|Mitgliedsnummer)'
  r'\s*[.:]?\s*([A-Z0-9][A-Z0-9 ./-]{2,24}[A-Z0-9])',
  caseSensitive: false,
);

const Map<String, String> _labelToKind = {
  'versicherungsschein': 'VSNR',
  'vertrag': 'VSNR',
  'kunde': 'KDNR',
  'rechnung': 'RGNR',
  'steuer': 'STNR',
  'aktenzeichen': 'AZ',
  'vorgang': 'AZ',
  'mitglied': 'KDNR',
};

/// Erkennt Referenzen im Text: IBANs und beschriftete Nummern.
/// Ergebnis: Art (IBAN/VSNR/KDNR/RGNR/STNR/AZ) → gefundene Werte.
Map<String, Set<String>> extractRefs(String text) {
  final refs = <String, Set<String>>{};

  for (final m in _ibanCandidate.allMatches(text.toUpperCase())) {
    final iban = m[0]!.replaceAll(RegExp(r'\s'), '');
    if (isValidIban(iban)) {
      refs.putIfAbsent('IBAN', () => {}).add(iban);
    }
  }

  for (final m in _labeledRef.allMatches(text)) {
    final label = m[1]!.toLowerCase();
    final value = m[2]!.trim();
    // Reine Fließtext-Treffer ohne Ziffern sind fast immer falsch erkannt.
    if (!RegExp(r'\d').hasMatch(value)) continue;
    final kind = _labelToKind.entries
        .firstWhere((e) => label.contains(e.key),
            orElse: () => const MapEntry('sonstige', 'REF'))
        .value;
    refs.putIfAbsent(kind, () => {}).add(value);
  }
  return refs;
}

/// Sucht bekannte Absender-Namen/Aliasse im Text. Liefert den Schlüssel des
/// längsten Treffers (längere Namen sind spezifischer), bevorzugt Treffer
/// im oberen Teil des Texts (Briefkopf).
String? matchKnownCorrespondent(String text, Map<String, String> aliasToId) {
  final lower = text.toLowerCase();
  final head = lower.length > 600 ? lower.substring(0, 600) : lower;
  String? bestId;
  var bestLen = 0;
  var bestInHead = false;

  for (final entry in aliasToId.entries) {
    final alias = entry.key.toLowerCase().trim();
    if (alias.length < 3) continue;
    final inHead = head.contains(alias);
    if (!inHead && !lower.contains(alias)) continue;
    final better = (inHead && !bestInHead) ||
        (inHead == bestInHead && alias.length > bestLen);
    if (better) {
      bestId = entry.value;
      bestLen = alias.length;
      bestInHead = inHead;
    }
  }
  return bestId;
}

/// Wortbestandteile, die stark auf einen Firmen-/Behörden-Namen hindeuten.
final _orgMarkers = RegExp(
  r'\b(GmbH|AG\b|KG\b|SE\b|e\.\s?V\.|eG\b|mbH|Bank|Sparkasse|Volksbank|'
  r'Versicherung|Versicherungen|Krankenkasse|Krankenversicherung|Kasse\b|'
  r'Stadtwerke|Gemeindewerke|Energie|Telekom|Vodafone|Amt\b|Finanzamt|'
  r'Landratsamt|Behörde|Ministerium|Agentur|Rentenversicherung|Inkasso|'
  r'Verlag|Verband|Verein|Institut|Praxis|Klinik|Apotheke|Kanzlei|Steuerberat)',
  caseSensitive: false,
);

/// Zeilen, die sicher kein Absendername sind.
final _notASender = RegExp(
  r'^\d|^(Seite|Datum|Betreff|Sehr geehrte|Guten Tag|An\b|Herrn?\b|Frau\b|'
  r'Postfach)|\bTelefon\b|\bTel\b\.?[.:\s]|\bFax\b|E-?Mail|www\.|@|'
  r'\bIBAN\b|\bBIC\b|Steuer-?Nr|\bUSt\b|\bHRB\b|\bAmtsgericht\b',
  caseSensitive: false,
);

/// Rät den Absender eines UNBEKANNTEN Briefs aus dem Briefkopf:
/// 1. „Absenderzeile" über dem Adressfeld: "Firma · Straße 1 · 12345 Ort"
/// 2. sonst die erste Kopfzeile mit einem Organisations-Marker (GmbH, Bank …)
String? guessCorrespondentFromLetterhead(String ocrText) {
  final lines = ocrText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .take(25)
      .toList();

  // 1. Absenderzeile: kleiner Einzeiler mit Trennzeichen und PLZ
  //    ("Firma · Straße 5 · 12345 Ort"). Fußzeilen-Zeilen (Telefon, IBAN …)
  //    sind ausgeschlossen, damit nicht die Bankverbindung zum Absender wird.
  final senderLine = RegExp(r'^(.{3,60}?)\s*[·•|,]\s*.*\b\d{5}\b(?!\d)');
  for (final line in lines) {
    if (_notASender.hasMatch(line)) continue;
    final m = senderLine.firstMatch(line);
    if (m != null) {
      final name = _cleanOrgName(m[1]!);
      if (name != null) return name;
    }
  }

  // 2. Erste plausible Kopfzeile mit Organisations-Marker.
  for (final line in lines.take(12)) {
    if (_notASender.hasMatch(line)) continue;
    if (line.length < 5 || line.length > 60) continue;
    if (_orgMarkers.hasMatch(line)) {
      final name = _cleanOrgName(line);
      if (name != null) return name;
    }
  }
  return null;
}

String? _cleanOrgName(String raw) {
  var name = raw
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'[·•|]+.*$'), '')
      .trim()
      .replaceAll(RegExp(r'[,;:\-–]+$'), '')
      .trim();
  if (name.length < 3 || !RegExp(r'[A-Za-zÄÖÜäöüß]{3}').hasMatch(name)) {
    return null;
  }
  return name;
}

/// Titelvorschlag: Betreffzeile, sonst "Typ Absender", sonst erste
/// brauchbare Textzeile.
String suggestTitle({
  String? docType,
  String? correspondentName,
  required String ocrText,
}) {
  final betreff = RegExp(r'^Betr(?:eff|\.)?\s*:?\s*(.{4,80})$',
      caseSensitive: false, multiLine: true);
  final m = betreff.firstMatch(ocrText);
  if (m != null) {
    final subject = m[1]!.trim();
    if (subject.isNotEmpty) return subject;
  }
  final parts = [
    if (docType != null && docType.isNotEmpty) docType,
    if (correspondentName != null && correspondentName.isNotEmpty)
      correspondentName,
  ];
  if (parts.isNotEmpty) return parts.join(' ');
  for (final line in ocrText.split('\n')) {
    final t = line.trim();
    if (t.length >= 8) return t.length > 60 ? '${t.substring(0, 60)}…' : t;
  }
  return 'Dokument';
}
