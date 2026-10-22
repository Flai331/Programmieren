/// Regelbasierte Rechnungs-Erkennung: Betrag, Fälligkeit, Zahlungsstatus,
/// Gesundheits- und Steuerrelevanz. Rein lokal, pur und unit-getestet.
/// Das PC-Programm (scan_trenner/rechnungen.py) nutzt dieselben Regeln.
library;

import '../data/finance.dart';
import 'extractors.dart';

/// Geldbetrag: "1.234,56", "1234,56", "12,50"; optional mit €/EUR davor
/// oder dahinter.
const _amount = r'(\d{1,3}(?:[. ]\d{3})+|\d+),(\d{2})(?!\d)';

/// Eindeutige Endbetrags-Beschriftungen. Steuer- und Zwischensummen
/// ("MwSt", "Netto") stehen bewusst nicht drin.
final _strongAmountLabel = RegExp(
  r'(zu zahlender (?:gesamt)?betrag|zahlbetrag|rechnungsbetrag|'
  r'gesamtbetrag|endbetrag|gesamtsumme|rechnungssumme|bruttobetrag|'
  r'summe brutto|brutto ?summe|offener betrag|forderungsbetrag|'
  r'zu zahlen|ihr (?:eigen)?anteil|eigenanteil)'
  '[^\\d\\n]{0,40}$_amount',
  caseSensitive: false,
);
final _weakAmountLabel = RegExp(
  '\\b(summe|betrag|total|gesamt)\\b[^\\d\\n]{0,30}$_amount',
  caseSensitive: false,
);
final _euroAmount = RegExp(
  '(?:(?:€|EUR)\\s?$_amount)|(?:$_amount\\s?(?:€|EUR))',
);

int _cents(String euros, String cents) =>
    int.parse(euros.replaceAll(RegExp(r'[. ]'), '')) * 100 + int.parse(cents);

/// Endbetrag einer Rechnung in Cent, oder `null`.
///
/// Reihenfolge: eindeutig beschriftete Endbeträge → schwach beschriftete
/// ("Summe", "Betrag") → irgendein Euro-Betrag. Innerhalb einer Stufe
/// gewinnt der größte Wert, weil der Endbetrag nie kleiner ist als die
/// Einzelpositionen.
int? extractAmountCents(String text) {
  int? maxOf(Iterable<int> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

  final strong = maxOf(
      _strongAmountLabel.allMatches(text).map((m) => _cents(m[2]!, m[3]!)));
  if (strong != null && strong > 0) return strong;
  final weak = maxOf(
      _weakAmountLabel.allMatches(text).map((m) => _cents(m[2]!, m[3]!)));
  if (weak != null && weak > 0) return weak;
  final any = maxOf(_euroAmount.allMatches(text).map((m) =>
      m[1] != null ? _cents(m[1]!, m[2]!) : _cents(m[3]!, m[4]!)));
  return any != null && any > 0 ? any : null;
}

/// Beschriftungen, hinter denen das Fälligkeitsdatum steht.
final _dueLabel = RegExp(
  r'(zahlbar bis|fällig (?:am|bis|zum)|fälligkeit(?:sdatum)?|'
  r'zahlungsziel|zahlungsfrist|zahlungstermin|spätestens (?:am|bis)|'
  r'bis spätestens|(?:zahlen|überweisen|begleichen) sie[^.\n]{0,40}?bis(?: zum)?|'
  r'(?:zahlung|überweisung|ausgleich)[^.\n]{0,30}?bis(?: zum)?|'
  r'abbuchung (?:am|erfolgt am)|abgebucht am|einzug am)',
  caseSensitive: false,
);

/// "innerhalb von 14 Tagen", "binnen 30 Tagen", "14 Tage netto",
/// "Zahlungsziel: 30 Tage".
final _relativeDue = RegExp(
  r'(?:(?:innerhalb|binnen)\s+(?:von\s+)?(\d{1,3})\s+(?:kalender)?tag|'
  r'(\d{1,3})\s+tage?n?\s+(?:netto|ohne abzug|nach (?:erhalt|rechnungs))|'
  r'zahlungsziel[:\s]+(\d{1,3})\s+tag)',
  caseSensitive: false,
);
final _immediate = RegExp(
  r'sofort (?:fällig|zahlbar|nach erhalt)|ohne abzug sofort|'
  r'zahlbar sofort',
  caseSensitive: false,
);

/// Fälligkeitsdatum: zuerst ein ausdrückliches Datum hinter einer
/// Beschriftung ("zahlbar bis 15.11.2026"), sonst eine Frist in Tagen ab
/// [docDate] ("innerhalb von 14 Tagen"). Bei Skonto-Staffeln gewinnt die
/// längste Frist (Netto-Ziel). `null` wenn nichts erkennbar.
DateTime? extractDueDate(String text, {DateTime? docDate, DateTime? now}) {
  final reference = now ?? DateTime.now();
  for (final m in _dueLabel.allMatches(text)) {
    final window = text.substring(m.end, (m.end + 60).clamp(0, text.length));
    final dates = extractDates(window, now: reference);
    if (dates.isNotEmpty) return dates.first;
  }

  final base = docDate ?? reference;
  final start = DateTime(base.year, base.month, base.day);
  var maxDays = -1;
  for (final m in _relativeDue.allMatches(text)) {
    final days = int.parse(m[1] ?? m[2] ?? m[3]!);
    if (days > 0 && days <= 120 && days > maxDays) maxDays = days;
  }
  if (maxDays > 0) return start.add(Duration(days: maxDays));
  if (_immediate.hasMatch(text)) return start;
  return null;
}

final _paidMarkers = RegExp(
  r'betrag (?:dankend )?erhalten|bereits (?:bezahlt|beglichen|überwiesen)|'
  r'(?:bar|per karte|mit karte) bezahlt|zahlung (?:dankend )?erhalten|'
  r'rechnung (?:ist )?beglichen|betrag wurde[^.\n]{0,30}beglichen|'
  r'\bquittiert\b|zahlungsart:? ?(?:bar|ec|girocard|kreditkarte|paypal)|'
  r'\bgirocard\b|\bec-karte\b|kartenzahlung|gegeben\s+bar|rückgeld',
  caseSensitive: false,
);
final _debitMarkers = RegExp(
  r'(?:per|mittels|im) (?:sepa-)?lastschrift|lastschriftverfahren|'
  r'sepa-lastschrift|wird[^\n]{0,60}?(?:abgebucht|eingezogen)|'
  r'(?:buchen|ziehen) (?:wir )?den (?:rechnungs)?betrag[^.\n]{0,40}(?:ab|ein)\b|'
  r'abbuchung (?:am|erfolgt)|bankeinzug',
  caseSensitive: false,
);
final _creditMarkers = RegExp(
  r'\bgutschrift\b|ihr guthaben|guthaben (?:von|in höhe)|'
  r'(?:erstatten|überweisen) (?:wir )?ihnen|rückerstattung an sie',
  caseSensitive: false,
);
/// Hinweise, dass der Empfänger zahlen muss (schließt Gutschrift aus).
final _owesMarkers = RegExp(
  r'nachzahlung|zahlbar|fällig|zu zahlen|überweisen sie|'
  r'zahlungserinnerung|mahnung|offener betrag',
  caseSensitive: false,
);
final _billMarkers = RegExp(
  r'rechnung|liquidation|zahlbar|fällig|zahlungsziel|zu zahlen|'
  r'überweisen sie|zahlungserinnerung|mahnung|invoice|beitragsrechnung|'
  r'nachzahlung|forderung',
  caseSensitive: false,
);

/// Zahlungsstatus aus dem Text: bezahlt (Quittung, Kassenbon),
/// wird abgebucht (Lastschrift), Gutschrift, oder zu bezahlen, wenn es eine
/// Rechnung/Forderung ist. `null` = keine Zahlung betroffen.
String? guessPaymentStatus(String text, {String? docType}) {
  if (_paidMarkers.hasMatch(text)) return PaymentStatus.paid;
  if (_debitMarkers.hasMatch(text)) return PaymentStatus.directDebit;
  if (_creditMarkers.hasMatch(text) && !_owesMarkers.hasMatch(text)) {
    return PaymentStatus.credit;
  }
  final isBill = docType == 'Rechnung' ||
      docType == 'Mahnung' ||
      _billMarkers.hasMatch(text);
  if (isBill && extractAmountCents(text) != null) return PaymentStatus.open;
  return null;
}

final _medicalMarkers = RegExp(
  r'(?<![a-z])GO(?:Ä|AE)(?![a-z])|\bGOZ\b|\bGebüH\b|gebührenordnung für (?:ärzte|zahnärzte)|'
  r'\bliquidation\b|privatrechnung|arztrechnung|privatliquidation|'
  r'zahnarzt|kieferorthopäd|heilpraktiker|physiotherap|krankengymnastik|'
  r'ergotherap|logopäd|osteopath|psychotherap|heilmittel|hilfsmittel|'
  r'apotheke|\brezept\b|\bpzn\b|krankenhaus|klinik|\bpraxis\b|'
  r'facharzt|ärztin|\barzt\b|\bdr\. med|optiker|brillengläser|hörgerät|'
  r'diagnose|behandlung|wahlleistung|chefarzt',
  caseSensitive: false,
);

/// Gesundheitsrechnung (Arzt, Zahnarzt, Apotheke, Physio …), die man bei
/// Krankenkasse/Beihilfe/Heilfürsorge einreichen kann.
bool isMedicalBill(String text) {
  var hits = 0;
  for (final _ in _medicalMarkers.allMatches(text)) {
    if (++hits >= 2) return true;
  }
  // Ein einzelnes starkes Signal reicht.
  return RegExp(r'(?<![a-z])GO(?:Ä|AE)(?![a-z])|\bGOZ\b|\bliquidation\b|arztrechnung',
          caseSensitive: false)
      .hasMatch(text);
}

final _taxMarkers = RegExp(
  r'§\s?35a|haushaltsnahe|handwerkerleistung|arbeitskosten|lohnanteil|'
  r'lohnkosten|anteil (?:der )?arbeitsleistung|'
  r'spendenbescheinigung|zuwendungsbestätigung',
  caseSensitive: false,
);

/// Steuerlich absetzbar (Handwerker/haushaltsnahe Dienste, Spenden).
bool isTaxRelevant(String text) => _taxMarkers.hasMatch(text);

/// Vorgeschlagene Einreichungen: Gesundheitsrechnungen an die Stellen,
/// die der Nutzer in den Einstellungen gewählt hat; steuerlich relevante
/// Rechnungen zur Steuererklärung. Bereits bezahlte Gesundheitsrechnungen
/// werden genauso eingereicht (Erstattung nach Zahlung).
List<String> suggestClaimTargets(String text, FinanceSettings settings) {
  final targets = <String>[];
  if (isMedicalBill(text)) {
    targets.addAll(settings.claimTargets.where((t) => t != kTaxTarget));
  }
  final medicalForTax =
      isMedicalBill(text) && settings.claimTargets.contains(kTaxTarget);
  if (isTaxRelevant(text) || medicalForTax) {
    targets.add(kTaxTarget);
  }
  return targets;
}
