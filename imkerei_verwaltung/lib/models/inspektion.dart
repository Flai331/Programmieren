// ═══════════════════════════════════════════════════════════════
//  Modell: Inspektion (Stockkarte / Inspection)
// ═══════════════════════════════════════════════════════════════

enum BrutStatus {
  sehr_gut,
  gut,
  maessig,
  schlecht,
  keine_brut,
  weisellos,
}

extension BrutStatusLabel on BrutStatus {
  String get label {
    switch (this) {
      case BrutStatus.sehr_gut:  return 'Sehr gut';
      case BrutStatus.gut:       return 'Gut';
      case BrutStatus.maessig:   return 'Mäßig';
      case BrutStatus.schlecht:  return 'Schlecht';
      case BrutStatus.keine_brut: return 'Keine Brut';
      case BrutStatus.weisellos:  return 'Weisellos';
    }
  }
}

class Inspektion {
  final String id;
  String volkId;
  DateTime datum;
  int staerke;              // 1–10
  BrutStatus brutStatus;
  bool koeninginGesehen;
  int varroaSchaetzung;     // geschätzte Varroamilben pro 100 Bienen (%)
  bool honigvorrat;         // ausreichend Honigvorrat?
  bool pollenvorrat;
  bool schwarmstimmung;
  String beobachtungen;     // Freitext
  String massnahmen;        // Freitext, durchgeführte Maßnahmen
  int futterMenge;          // in Liter (0 = kein Futter gegeben)
  String wetter;            // Wetterbeschreibung

  Inspektion({
    required this.id,
    required this.volkId,
    required this.datum,
    this.staerke = 5,
    this.brutStatus = BrutStatus.gut,
    this.koeninginGesehen = false,
    this.varroaSchaetzung = 0,
    this.honigvorrat = true,
    this.pollenvorrat = true,
    this.schwarmstimmung = false,
    this.beobachtungen = '',
    this.massnahmen = '',
    this.futterMenge = 0,
    this.wetter = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'volkId': volkId,
    'datum': datum.toIso8601String(),
    'staerke': staerke,
    'brutStatus': brutStatus.index,
    'koeninginGesehen': koeninginGesehen,
    'varroaSchaetzung': varroaSchaetzung,
    'honigvorrat': honigvorrat,
    'pollenvorrat': pollenvorrat,
    'schwarmstimmung': schwarmstimmung,
    'beobachtungen': beobachtungen,
    'massnahmen': massnahmen,
    'futterMenge': futterMenge,
    'wetter': wetter,
  };

  factory Inspektion.fromJson(Map<String, dynamic> json) => Inspektion(
    id: json['id'],
    volkId: json['volkId'],
    datum: DateTime.parse(json['datum']),
    staerke: json['staerke'] ?? 5,
    brutStatus: BrutStatus.values[json['brutStatus'] ?? 1],
    koeninginGesehen: json['koeninginGesehen'] ?? false,
    varroaSchaetzung: json['varroaSchaetzung'] ?? 0,
    honigvorrat: json['honigvorrat'] ?? true,
    pollenvorrat: json['pollenvorrat'] ?? true,
    schwarmstimmung: json['schwarmstimmung'] ?? false,
    beobachtungen: json['beobachtungen'] ?? '',
    massnahmen: json['massnahmen'] ?? '',
    futterMenge: json['futterMenge'] ?? 0,
    wetter: json['wetter'] ?? '',
  );
}
