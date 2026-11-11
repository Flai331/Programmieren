// Verträge: Kosten und Kündigungsfristen. Rein, testbar.

const kContractIntervals = {
  'monatlich': 'monatlich',
  'vierteljaehrlich': 'vierteljährlich',
  'halbjaehrlich': 'halbjährlich',
  'jaehrlich': 'jährlich',
  'einmalig': 'einmalig',
};

const _monthsPer = {
  'monatlich': 1,
  'vierteljaehrlich': 3,
  'halbjaehrlich': 6,
  'jaehrlich': 12,
};

/// Kosten pro Monat in Cent (einmalige zählen nicht).
int monthlyCents(int? amountCents, String interval) {
  final m = _monthsPer[interval];
  if (amountCents == null || m == null) return 0;
  return (amountCents / m).round();
}

int yearlyCents(int? amountCents, String interval) =>
    monthlyCents(amountCents, interval) * 12;

DateTime _addMonths(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

/// Nächstes Laufzeitende ab [now]: Mindestlaufzeit, danach Verlängerung um
/// [renewMonths] (0/null = monatlich kündbar nach Mindestlaufzeit).
DateTime? nextTermEnd({
  DateTime? minTermUntil,
  int? renewMonths,
  required DateTime now,
}) {
  if (minTermUntil == null) return null;
  var end = minTermUntil;
  final step = (renewMonths == null || renewMonths <= 0) ? 1 : renewMonths;
  while (!end.isAfter(now)) {
    end = _addMonths(end, step);
  }
  return end;
}

/// Letzter Tag, an dem die Kündigung eingehen muss, um zum [termEnd] zu
/// enden (bei `monatsende`: zum Ende eines beliebigen Monats ab jetzt).
DateTime? lastCancelDay({
  required DateTime? termEnd,
  int? noticeValue,
  String? noticeUnit,
  String? noticeToEndOf,
  required DateTime now,
}) {
  if (noticeValue == null || noticeUnit == null) return null;
  DateTime minus(DateTime d) => switch (noticeUnit) {
        'tage' => d.subtract(Duration(days: noticeValue)),
        'wochen' => d.subtract(Duration(days: 7 * noticeValue)),
        _ => _addMonths(d, -noticeValue),
      };
  if (noticeToEndOf == 'monatsende') {
    // Frühestes Monatsende, das mit Frist noch erreichbar ist.
    var end = DateTime(now.year, now.month + 1, 0);
    while (minus(end).isBefore(DateTime(now.year, now.month, now.day))) {
      end = DateTime(end.year, end.month + 2, 0);
    }
    return minus(end);
  }
  if (termEnd == null) return null;
  return minus(termEnd);
}
