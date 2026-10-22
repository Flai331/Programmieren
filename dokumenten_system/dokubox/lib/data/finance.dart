/// Rechnungen & Erstattungen: Status, Erstattungsstellen, Einstellungen.
library;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zahlungsstatus eines Dokuments. `null` = keine Zahlung betroffen.
class PaymentStatus {
  PaymentStatus._();

  static const open = 'zu bezahlen';
  static const directDebit = 'wird abgebucht';
  static const paid = 'bezahlt';

  /// Geld kommt rein (Guthaben, Rückzahlung) — nichts zu tun.
  static const credit = 'Gutschrift';

  static const all = [open, directDebit, paid, credit];
}

/// Status einer Einreichung bei einer Erstattungsstelle.
class ClaimStatus {
  ClaimStatus._();

  static const toSubmit = 'einzureichen';
  static const submitted = 'eingereicht';
  static const reimbursed = 'erstattet';
  static const partly = 'teilweise erstattet';
  static const rejected = 'abgelehnt';

  static const all = [toSubmit, submitted, reimbursed, partly, rejected];

  /// Noch offen = taucht in „Offene Posten" auf.
  static bool isOpen(String status) =>
      status == toSubmit || status == submitted;
}

/// Stellen, bei denen man Rechnungen einreichen kann.
const List<String> kClaimTargets = [
  'Krankenkasse',
  'Private Krankenversicherung',
  'Beihilfe',
  'Heilfürsorge',
  'Zusatzversicherung',
  'Pflegekasse',
  'Unfallversicherung / BG',
  'Arbeitgeber',
  'Steuererklärung',
];

const kTaxTarget = 'Steuererklärung';

final _euro = NumberFormat.currency(locale: 'de_DE', symbol: '€');

/// 12345 → "123,45 €"
String formatEuro(int cents) => _euro.format(cents / 100);

/// "1.234,56", "1234,56 €", "12" → Cent. `null` bei ungültiger Eingabe.
int? parseEuro(String input) {
  var s = input.replaceAll(RegExp(r'[€\sEUReur]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', ''); // "1.234" = Tausenderpunkt
  }
  final value = double.tryParse(s);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

/// Zeitpunkt der Zahlungserinnerung: [leadDays] Tage vor Fälligkeit um
/// 9 Uhr. Liegt das schon in der Vergangenheit (Rechnung spät gescannt),
/// wird in zwei Stunden erinnert — lieber spät als gar nicht.
DateTime paymentReminderFor(DateTime dueDate, int leadDays, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final day = dueDate.subtract(Duration(days: leadDays));
  final candidate = DateTime(day.year, day.month, day.day, 9);
  if (candidate.isAfter(reference)) return candidate;
  return reference.add(const Duration(hours: 2));
}

/// Nachfassen bei der Erstattung: [weeks] Wochen nach dem Einreichen.
DateTime claimFollowUpFor(DateTime submittedAt, int weeks) {
  final day = submittedAt.add(Duration(days: weeks * 7));
  return DateTime(day.year, day.month, day.day, 9);
}

/// Nutzer-Einstellungen für Rechnungen. Unveränderlich, damit sie sich
/// in Tests einfach übergeben lässt.
class FinanceSettings {
  /// Tage vor Fälligkeit, an denen erinnert wird.
  final int leadDays;

  /// Wochen nach dem Einreichen, nach denen an die Erstattung erinnert wird.
  final int followUpWeeks;

  /// Wo der Nutzer Arzt-/Gesundheitsrechnungen einreicht (z. B. nur
  /// Heilfürsorge, oder Beihilfe + Private Krankenversicherung).
  final List<String> claimTargets;

  const FinanceSettings({
    this.leadDays = 3,
    this.followUpWeeks = 6,
    this.claimTargets = const ['Krankenkasse'],
  });

  static const _leadKey = 'finance_lead_days';
  static const _followUpKey = 'finance_follow_up_weeks';
  static const _targetsKey = 'finance_claim_targets';

  static Future<FinanceSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = FinanceSettings();
    return FinanceSettings(
      leadDays: prefs.getInt(_leadKey) ?? defaults.leadDays,
      followUpWeeks: prefs.getInt(_followUpKey) ?? defaults.followUpWeeks,
      claimTargets:
          prefs.getStringList(_targetsKey) ?? defaults.claimTargets,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leadKey, leadDays);
    await prefs.setInt(_followUpKey, followUpWeeks);
    await prefs.setStringList(_targetsKey, claimTargets);
  }

  FinanceSettings copyWith({
    int? leadDays,
    int? followUpWeeks,
    List<String>? claimTargets,
  }) =>
      FinanceSettings(
        leadDays: leadDays ?? this.leadDays,
        followUpWeeks: followUpWeeks ?? this.followUpWeeks,
        claimTargets: claimTargets ?? this.claimTargets,
      );
}
