// ═══════════════════════════════════════════════════════════════
//  Modell: Ernte (Honigernte / Harvest)
// ═══════════════════════════════════════════════════════════════

enum Honigsorte {
  blütenhonig,
  rapshonig,
  lindenhonig,
  waldhonig,
  akazienhonig,
  sonnenblumenhonig,
  tannenhonig,
  sonstige,
}

extension HonigsortLabel on Honigsorte {
  String get label {
    switch (this) {
      case Honigsorte.blütenhonig:     return 'Blütenhonig';
      case Honigsorte.rapshonig:       return 'Rapshonig';
      case Honigsorte.lindenhonig:     return 'Lindenhonig';
      case Honigsorte.waldhonig:       return 'Waldhonig';
      case Honigsorte.akazienhonig:    return 'Akazienhonig';
      case Honigsorte.sonnenblumenhonig: return 'Sonnenblumenhonig';
      case Honigsorte.tannenhonig:     return 'Tannenhonig';
      case Honigsorte.sonstige:        return 'Sonstige';
    }
  }
}

class Ernte {
  final String id;
  String volkId;        // optional: spezifisches Volk (leer = Standort-Ernte)
  String standortId;
  DateTime datum;
  double mengeKg;       // Erntemengte in Kilogramm
  Honigsorte sorte;
  double wassergehalt;  // Wassergehalt in % (ideal < 18%)
  String qualitaet;     // Freitext: Farbe, Konsistenz, Geschmack
  String notizen;

  Ernte({
    required this.id,
    this.volkId = '',
    required this.standortId,
    required this.datum,
    required this.mengeKg,
    this.sorte = Honigsorte.blütenhonig,
    this.wassergehalt = 0.0,
    this.qualitaet = '',
    this.notizen = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'volkId': volkId,
    'standortId': standortId,
    'datum': datum.toIso8601String(),
    'mengeKg': mengeKg,
    'sorte': sorte.index,
    'wassergehalt': wassergehalt,
    'qualitaet': qualitaet,
    'notizen': notizen,
  };

  factory Ernte.fromJson(Map<String, dynamic> json) => Ernte(
    id: json['id'],
    volkId: json['volkId'] ?? '',
    standortId: json['standortId'],
    datum: DateTime.parse(json['datum']),
    mengeKg: (json['mengeKg'] ?? 0.0).toDouble(),
    sorte: Honigsorte.values[json['sorte'] ?? 0],
    wassergehalt: (json['wassergehalt'] ?? 0.0).toDouble(),
    qualitaet: json['qualitaet'] ?? '',
    notizen: json['notizen'] ?? '',
  );
}
