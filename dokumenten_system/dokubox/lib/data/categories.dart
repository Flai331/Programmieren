/// Kategorien, die beim ersten Start angelegt werden. Umbenennen, löschen
/// und ergänzen geht unter Einstellungen → Firmen & Kategorien.
const kDefaultCategories = [
  'Bank & Geldanlage',
  'Versicherung',
  'Energie & Wohnen',
  'Gesundheit',
  'Behörden & Steuern',
  'Arbeit & Rente',
  'Telefon & Internet',
  'Auto & Verkehr',
  'Verträge & Einkäufe',
];

/// Beispiel-Firma, die mit Kategorie und Erkennungs-Stichwörtern angelegt
/// wird.
class DefaultFirm {
  final String name;
  final String category;
  final List<String> aliases;
  const DefaultFirm(this.name, this.category, this.aliases);
}

const kDefaultFirms = [
  DefaultFirm('Union Investment', 'Bank & Geldanlage', [
    'Union Investment',
    'UnionDepot',
    'Union Investment Service Bank',
    'Union Investment Privatfonds',
  ]),
  DefaultFirm('enviaM', 'Energie & Wohnen', [
    'enviaM',
    'envia Mitteldeutsche Energie',
    'envia Mitteldeutsche',
  ]),
];
