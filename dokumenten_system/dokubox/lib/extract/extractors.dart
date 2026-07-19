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

/// Keyword-Regeln für den Dokumenttyp — spezifische Begriffe zuerst.
const List<(String type, List<String> keywords)> _typeRules = [
  ('Kontoauszug', ['kontoauszug', 'auszug nr']),
  ('Versicherungspolice', [
    'versicherungsschein',
    'police',
    'versicherungspolice',
  ]),
  ('Gehaltsabrechnung', [
    'gehaltsabrechnung',
    'lohnabrechnung',
    'entgeltabrechnung',
    'verdienstabrechnung',
  ]),
  ('Mahnung', ['mahnung', 'zahlungserinnerung']),
  ('Kündigung', ['kündigung', 'kuendigung', 'vertragsbeendigung']),
  ('Steuerunterlage', [
    'steuerbescheid',
    'einkommensteuer',
    'lohnsteuerbescheinigung',
    'finanzamt',
  ]),
  ('Bescheid', ['bescheid']),
  ('Bescheinigung', ['bescheinigung', 'nachweis über', 'zertifikat']),
  ('Vertrag', ['vertrag', 'vereinbarung']),
  ('Arztunterlage', ['arztbrief', 'befund', 'diagnose', 'impfung']),
  ('Urkunde', ['urkunde', 'zeugnis']),
  // Allgemeinstes zuletzt, "beitragsrechnung" etc. matcht hier ebenfalls.
  ('Rechnung', ['rechnung', 'invoice', 'zu zahlender betrag']),
];

/// Dokumenttyp anhand von Keywords erraten; `null` wenn nichts passt.
String? guessDocType(String text) {
  final lower = text.toLowerCase();
  for (final (type, keywords) in _typeRules) {
    if (keywords.any(lower.contains)) return type;
  }
  return null;
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

/// Titelvorschlag: "Typ Absender" oder erste brauchbare Textzeile.
String suggestTitle({
  String? docType,
  String? correspondentName,
  required String ocrText,
}) {
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
