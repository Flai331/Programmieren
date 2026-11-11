/// Vordefinierte Felder für „Meine Daten“ (Schlüssel → Bezeichnung).
const kPersonalFields = <String, String>{
  'anrede': 'Anrede',
  'vorname': 'Vorname',
  'nachname': 'Nachname',
  'geburtsdatum': 'Geburtsdatum',
  'geburtsort': 'Geburtsort',
  'strasse': 'Straße, Nr.',
  'plz_ort': 'PLZ Ort',
  'telefon': 'Telefon',
  'email': 'E-Mail',
  'iban': 'IBAN',
  'bic': 'BIC',
  'bank': 'Bank',
  'steuer_id': 'Steuer-ID',
  'steuernummer': 'Steuernummer',
  'kv_nummer': 'Krankenversicherungsnummer',
  'rv_nummer': 'Rentenversicherungsnummer',
  'beihilfe_nr': 'Beihilfe-/Personalnummer',
  'kfz': 'Kfz-Kennzeichen',
};

/// Felder, deren Wert in Listen maskiert wird.
const kSensitiveFields = {'iban', 'steuer_id', 'kv_nummer', 'rv_nummer'};

String maskValue(String key, String value) {
  if (!kSensitiveFields.contains(key) || value.length <= 4) return value;
  return '•••• ${value.replaceAll(' ', '').substring(value.replaceAll(' ', '').length - 4)}';
}

/// Fertige Kombinationen zum Einsetzen.
List<({String label, String text})> personalCombos(Map<String, String> v) {
  String g(String k) => (v[k] ?? '').trim();
  final name = [g('vorname'), g('nachname')].where((s) => s.isNotEmpty).join(' ');
  final address = [g('strasse'), g('plz_ort')].where((s) => s.isNotEmpty).join('\n');
  return [
    if (name.isNotEmpty) (label: 'Name', text: name),
    if (name.isNotEmpty && address.isNotEmpty)
      (label: 'Name + Anschrift', text: '$name\n$address'),
    if (address.isNotEmpty)
      (label: 'Anschrift (einzeilig)', text: address.replaceAll('\n', ', ')),
    for (final e in v.entries)
      if (e.value.trim().isNotEmpty)
        (label: kPersonalFields[e.key] ?? e.key, text: e.value.trim()),
  ];
}
