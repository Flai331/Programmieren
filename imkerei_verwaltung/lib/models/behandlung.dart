// ═══════════════════════════════════════════════════════════════
//  Modell: Behandlung (Varroabehandlung / Treatment)
// ═══════════════════════════════════════════════════════════════

enum BehandlungsTyp {
  varroaOxalsaeure,
  varroaAmeisenSaeure,
  varroaMilchsaeure,
  varroaThymol,
  varroaApivar,
  varroaSonstige,
  futterung,
  krankheit,
  sonstige,
}

extension BehandlungsTypLabel on BehandlungsTyp {
  String get label {
    switch (this) {
      case BehandlungsTyp.varroaOxalsaeure:    return 'Varroa – Oxalsäure';
      case BehandlungsTyp.varroaAmeisenSaeure: return 'Varroa – Ameisensäure';
      case BehandlungsTyp.varroaMilchsaeure:   return 'Varroa – Milchsäure';
      case BehandlungsTyp.varroaThymol:        return 'Varroa – Thymol';
      case BehandlungsTyp.varroaApivar:        return 'Varroa – Apivar';
      case BehandlungsTyp.varroaSonstige:      return 'Varroa – Sonstig';
      case BehandlungsTyp.futterung:           return 'Fütterung';
      case BehandlungsTyp.krankheit:           return 'Krankheitsbehandlung';
      case BehandlungsTyp.sonstige:            return 'Sonstige';
    }
  }

  bool get isVarroa =>
      index <= BehandlungsTyp.varroaSonstige.index;
}

class Behandlung {
  final String id;
  String volkId;        // leer = alle Völker am Standort
  String standortId;
  DateTime datum;
  DateTime? bisDate;    // Enddatum bei Langzeitbehandlungen
  BehandlungsTyp typ;
  String mittel;        // Handelsname / Produkt
  String dosis;         // z.B. "35 ml / Wabe" oder "2,5g sublimiert"
  String ergebnis;      // Freitext: beobachteter Erfolg
  String notizen;

  Behandlung({
    required this.id,
    this.volkId = '',
    required this.standortId,
    required this.datum,
    this.bisDate,
    this.typ = BehandlungsTyp.varroaOxalsaeure,
    this.mittel = '',
    this.dosis = '',
    this.ergebnis = '',
    this.notizen = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'volkId': volkId,
    'standortId': standortId,
    'datum': datum.toIso8601String(),
    'bisDate': bisDate?.toIso8601String(),
    'typ': typ.index,
    'mittel': mittel,
    'dosis': dosis,
    'ergebnis': ergebnis,
    'notizen': notizen,
  };

  factory Behandlung.fromJson(Map<String, dynamic> json) => Behandlung(
    id: json['id'],
    volkId: json['volkId'] ?? '',
    standortId: json['standortId'],
    datum: DateTime.parse(json['datum']),
    bisDate: json['bisDate'] != null ? DateTime.parse(json['bisDate']) : null,
    typ: BehandlungsTyp.values[json['typ'] ?? 0],
    mittel: json['mittel'] ?? '',
    dosis: json['dosis'] ?? '',
    ergebnis: json['ergebnis'] ?? '',
    notizen: json['notizen'] ?? '',
  );
}
