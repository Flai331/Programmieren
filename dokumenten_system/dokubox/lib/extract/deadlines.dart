// Fristen aus Dokumenten: Widerspruchs-/Einspruchsfrist in Bescheiden und
// Garantie/Gewährleistung. Rein (ohne Datenbank), testbar.

/// Bundesländer (Kürzel → Name) für die Feiertage.
const kBundeslaender = {
  'BW': 'Baden-Württemberg',
  'BY': 'Bayern',
  'BE': 'Berlin',
  'BB': 'Brandenburg',
  'HB': 'Bremen',
  'HH': 'Hamburg',
  'HE': 'Hessen',
  'MV': 'Mecklenburg-Vorpommern',
  'NI': 'Niedersachsen',
  'NW': 'Nordrhein-Westfalen',
  'RP': 'Rheinland-Pfalz',
  'SL': 'Saarland',
  'SN': 'Sachsen',
  'ST': 'Sachsen-Anhalt',
  'SH': 'Schleswig-Holstein',
  'TH': 'Thüringen',
};

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Ostersonntag (Gauß/Anonymer gregorianischer Algorithmus).
DateTime easterSunday(int year) {
  final a = year % 19, b = year ~/ 100, c = year % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return _d(year, month, day);
}

/// Gesetzliche Feiertage eines Jahres (bundesweit + [state]).
Set<DateTime> holidays(int year, {String? state}) {
  final easter = easterSunday(year);
  DateTime e(int days) => easter.add(Duration(days: days));
  final s = state ?? '';
  // Buß- und Bettag: Mittwoch vor dem 23. November.
  var bb = _d(year, 11, 22);
  while (bb.weekday != DateTime.wednesday) {
    bb = bb.subtract(const Duration(days: 1));
  }
  return {
    _d(year, 1, 1),
    e(-2), // Karfreitag
    e(1), // Ostermontag
    _d(year, 5, 1),
    e(39), // Christi Himmelfahrt
    e(50), // Pfingstmontag
    _d(year, 10, 3),
    _d(year, 12, 25),
    _d(year, 12, 26),
    if (['BW', 'BY', 'ST'].contains(s)) _d(year, 1, 6),
    if (['BE', 'MV'].contains(s)) _d(year, 3, 8),
    if (['BW', 'BY', 'HE', 'NW', 'RP', 'SL'].contains(s)) e(60), // Fronleichnam
    if (s == 'SL') _d(year, 8, 15),
    if (s == 'TH') _d(year, 9, 20),
    if (['BB', 'HB', 'HH', 'MV', 'NI', 'SN', 'ST', 'SH', 'TH'].contains(s))
      _d(year, 10, 31),
    if (['BW', 'BY', 'NW', 'RP', 'SL'].contains(s)) _d(year, 11, 1),
    if (s == 'SN') bb,
  };
}

/// Fällt [d] auf Samstag, Sonntag oder Feiertag, endet die Frist am
/// nächsten Werktag (§ 108 Abs. 3 AO, § 26 Abs. 3 SGB X, § 193 BGB).
DateTime nextWorkday(DateTime d, {String? state}) {
  var day = DateTime(d.year, d.month, d.day);
  while (day.weekday == DateTime.saturday ||
      day.weekday == DateTime.sunday ||
      holidays(day.year, state: state).contains(day)) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}

DateTime addMonthsClamped(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

const _numbers = {
  'einer': 1, 'eines': 1, 'einem': 1, 'ein': 1, 'zwei': 2, 'drei': 3,
  'vier': 4, 'sechs': 6, 'acht': 8, 'zwölf': 12,
};

int? _num(String s) => int.tryParse(s) ?? _numbers[s.toLowerCase()];

/// Tage, die nach dem Briefdatum als Tag der Bekanntgabe gelten
/// (Bekanntgabefiktion bei Post seit 2025: 4 Tage).
const kNoticeFictionDays = 4;

/// Widerspruchs-/Einspruchsfrist aus einem Bescheid. Erkennt
/// „innerhalb eines Monats / von zwei Wochen nach Bekanntgabe“ und
/// „bis zum 12.03.2026“. `null`, wenn nichts erkennbar oder kein
/// Briefdatum für die Berechnung.
DateTime? extractObjectionDeadline(String text, DateTime? letterDate,
    {String? state}) {
  final lower = text.toLowerCase();
  final legal = lower.contains('rechtsbehelfsbelehrung') ||
      RegExp(r'widerspruch|einspruch|klage').hasMatch(lower);
  if (!legal) return null;

  final explicit = RegExp(
          r'(?:widerspruch|einspruch)[^.]{0,120}?bis\s+(?:zum\s+)?(\d{1,2})\.(\d{1,2})\.(\d{4})')
      .firstMatch(lower);
  if (explicit != null) {
    return DateTime(int.parse(explicit[3]!), int.parse(explicit[2]!),
        int.parse(explicit[1]!));
  }
  if (letterDate == null) return null;
  final period = RegExp(
          r'(?:innerhalb|binnen)\s+(?:von\s+)?(\d+|einem|eines|einer|ein|zwei|drei|vier|sechs|acht|zwölf)\s+(monat|monaten|monats|woche|wochen)')
      .firstMatch(lower);
  if (period == null) return null;
  final n = _num(period[1]!);
  if (n == null) return null;
  final notice = DateTime(letterDate.year, letterDate.month, letterDate.day)
      .add(const Duration(days: kNoticeFictionDays));
  final end = period[2]!.startsWith('monat')
      ? addMonthsClamped(notice, n)
      : notice.add(Duration(days: 7 * n));
  return nextWorkday(end, state: state);
}

/// Garantie/Gewährleistung aus einer Rechnung/einem Beleg: erkennt
/// „3 Jahre Garantie“, „Garantie: 24 Monate“. `null` sonst (Vorschlag im
/// Bestätigen-Bildschirm per Auswahl).
({DateTime until, String kind})? extractWarranty(String text, DateTime? date) {
  if (date == null) return null;
  final lower = text.toLowerCase();
  final m = RegExp(
          r'(\d{1,2}|zwei|drei|vier|fünf)\s*(jahre?|monate?)\s*(?:herstellergarantie|garantie)|garantie[^\d\n]{0,20}(\d{1,2})\s*(jahre?|monate?)')
      .firstMatch(lower);
  if (m == null) return null;
  final n = int.tryParse(m[1] ?? m[3]!) ??
      const {'zwei': 2, 'drei': 3, 'vier': 4, 'fünf': 5}[m[1]];
  if (n == null || n == 0) return null;
  final unit = (m[2] ?? m[4]!);
  final months = unit.startsWith('jahr') ? n * 12 : n;
  return (until: addMonthsClamped(date, months), kind: 'garantie');
}
