/// Steuer-Kategorien für die Steuer-Mappe.
const kTaxCategories = <String, String>{
  'lohnsteuer': 'Lohnsteuerbescheinigung / Einkünfte',
  'werbungskosten': 'Werbungskosten (Arbeitsmittel, Fortbildung, Fahrten, Arbeitszimmer)',
  'vorsorge': 'Versicherungen & Vorsorge (Kranken-, Pflege-, Renten-, Haftpflicht)',
  'krankheit': 'Krankheitskosten (Arzt, Zahnarzt, Medikamente, Brille)',
  'haushaltsnah': 'Handwerker & haushaltsnahe Dienste (§ 35a)',
  'spenden': 'Spenden & Mitgliedsbeiträge',
  'kinder': 'Kinder (Betreuung, Schulgeld)',
  'vermietung': 'Vermietung & Verpachtung',
  'kapital': 'Kapitalerträge (Jahressteuerbescheinigung)',
  'unterhalt': 'Unterhalt & außergewöhnliche Belastungen',
  'sonstiges': 'Sonstiges',
};

/// Kategorie vorschlagen (Regeln; Nutzer kann ändern).
String? suggestTaxCategory(String text, String? docType) {
  final t = text.toLowerCase();
  bool has(String p) => RegExp(p).hasMatch(t);
  if (has(r'lohnsteuerbescheinigung|ausdruck der elektronischen lohnsteuer')) {
    return 'lohnsteuer';
  }
  if (has(r'jahressteuerbescheinigung|kapitalerträge|abgeltungsteuer')) return 'kapital';
  if (has(r'zuwendungsbestätigung|spendenbescheinigung|spendenquittung')) return 'spenden';
  if (has(r'§\s?35a|haushaltsnahe|handwerkerleistung|arbeitskosten|lohnanteil')) {
    return 'haushaltsnah';
  }
  if (has(r'kita|kindergarten|kindertages|hort|schulgeld|tagesmutter')) return 'kinder';
  if (has(r'nebenkostenabrechnung.*mieter|mieteinnahmen|vermietung')) return 'vermietung';
  if (docType == 'Arztunterlage' || has(r'goä|goz|liquidation|apotheke|zahnarzt|optiker')) {
    return 'krankheit';
  }
  if (has(r'beitragsbescheinigung|haftpflicht|rentenversicherung|krankenversicherung.*beitr')) {
    return 'vorsorge';
  }
  if (has(r'fortbildung|fachliteratur|arbeitsmittel|seminar')) return 'werbungskosten';
  return null;
}
