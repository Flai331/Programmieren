/// Status eines Vorgangs.
const kCaseStatus = {
  'offen': 'Offen',
  'wartet': 'Wartet auf Antwort',
  'erledigt': 'Erledigt',
};

/// Rolle eines Dokuments im Vorgang.
const kCaseRoles = {
  'antrag': 'Antrag/Anschreiben',
  'rueckfrage': 'Rückfrage',
  'bescheid': 'Bescheid/Antwort',
  'widerspruch': 'Widerspruch',
  'rechnung': 'Rechnung',
  'mahnung': 'Mahnung',
  'sonstiges': 'Sonstiges',
};

/// Rolle aus dem Dokumenttyp raten.
String guessCaseRole(String? docType) => switch (docType) {
      'Bescheid' => 'bescheid',
      'Mitteilung' => 'rueckfrage',
      'Rechnung' => 'rechnung',
      'Mahnung' => 'mahnung',
      'Kündigung' || 'Vertrag' || 'Versicherungspolice' => 'antrag',
      _ => 'sonstiges',
    };
