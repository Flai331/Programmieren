/// Zentrale Konstanten: Dokumenttypen, Lagerorte, Aufbewahrungsfristen.
library;

/// Bekannte Dokumenttypen. Frei erweiterbar — in der DB steht nur der String.
const List<String> kDocTypes = [
  'Rechnung',
  'Kontoauszug',
  'Bescheid',
  'Vertrag',
  'Versicherungspolice',
  'Kündigung',
  'Mahnung',
  'Gehaltsabrechnung',
  'Bescheinigung',
  'Steuerunterlage',
  'Arztunterlage',
  'Urkunde',
  'Sonstiges',
];

/// Lagerorte für das Original.
class StorageLocations {
  StorageLocations._();

  static const mappe = 'Mappe „Wichtig"';
  static const digital = 'digital';
  static const vernichtet = 'vernichtet';

  /// Standard-Box für das aktuelle Jahr, z. B. "Box 2026".
  static String boxForYear(int year) => 'Box $year';

  static List<String> choices(int year) => [
        boxForYear(year),
        mappe,
        digital,
      ];
}

/// Empfohlene Aufbewahrungsdauer in Jahren pro Dokumenttyp.
/// `null` = dauerhaft aufbewahren (keine Ausmist-Empfehlung).
/// Richtwerte für Privatpersonen in Deutschland, keine Rechtsberatung.
const Map<String, int?> kRetentionYears = {
  'Kontoauszug': 3,
  'Rechnung': 2,
  'Mahnung': 3,
  'Gehaltsabrechnung': null,
  'Steuerunterlage': null,
  'Bescheid': null,
  'Vertrag': null,
  'Versicherungspolice': null,
  'Kündigung': 3,
  'Bescheinigung': null,
  'Arztunterlage': null,
  'Urkunde': null,
  'Sonstiges': null,
};

/// Liefert das empfohlene "aufbewahren bis"-Datum für einen Typ,
/// gerechnet ab [from] (Dokumentdatum), oder `null` für dauerhaft.
DateTime? suggestedRetentionUntil(String? docType, DateTime from) {
  final years = kRetentionYears[docType];
  if (years == null) return null;
  // Fristen laufen praktisch immer zum Jahresende ab.
  return DateTime(from.year + years, 12, 31);
}
