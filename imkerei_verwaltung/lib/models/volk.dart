// ═══════════════════════════════════════════════════════════════
//  Modell: Volk (Bienenvolk / Colony)
// ═══════════════════════════════════════════════════════════════

enum Volksstatus { aktiv, schwach, erloschen, verkauft }
enum Bienenrasse { carnica, buckfast, ligustica, mellifera, hybrid, unbekannt }

extension VolksstatusLabel on Volksstatus {
  String get label {
    switch (this) {
      case Volksstatus.aktiv:    return 'Aktiv';
      case Volksstatus.schwach:  return 'Schwach';
      case Volksstatus.erloschen: return 'Erloschen';
      case Volksstatus.verkauft: return 'Verkauft';
    }
  }
}

extension BienenrasseLabel on Bienenrasse {
  String get label {
    switch (this) {
      case Bienenrasse.carnica:   return 'Carnica';
      case Bienenrasse.buckfast:  return 'Buckfast';
      case Bienenrasse.ligustica: return 'Ligustica';
      case Bienenrasse.mellifera: return 'Mellifera';
      case Bienenrasse.hybrid:    return 'Hybrid';
      case Bienenrasse.unbekannt: return 'Unbekannt';
    }
  }
}

class Volk {
  final String id;
  String name;           // z.B. "Volk 1" oder "Marie"
  String standortId;     // Referenz auf Standort
  Bienenrasse rasse;
  Volksstatus status;
  int staerke;           // 1–10 (Volksstärke)
  String koeninginId;    // interne Notiz
  String koeninginJahr;  // z.B. "2023"
  bool koeninginMarkiert;
  String koeninginFarbe; // Markierungsfarbe nach Int. Standard
  String notizen;
  DateTime erstelltAm;
  DateTime? naechsteInspektion;

  Volk({
    required this.id,
    required this.name,
    required this.standortId,
    this.rasse = Bienenrasse.carnica,
    this.status = Volksstatus.aktiv,
    this.staerke = 5,
    this.koeninginId = '',
    this.koeninginJahr = '',
    this.koeninginMarkiert = false,
    this.koeninginFarbe = '',
    this.notizen = '',
    required this.erstelltAm,
    this.naechsteInspektion,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'standortId': standortId,
    'rasse': rasse.index,
    'status': status.index,
    'staerke': staerke,
    'koeninginId': koeninginId,
    'koeninginJahr': koeninginJahr,
    'koeninginMarkiert': koeninginMarkiert,
    'koeninginFarbe': koeninginFarbe,
    'notizen': notizen,
    'erstelltAm': erstelltAm.toIso8601String(),
    'naechsteInspektion': naechsteInspektion?.toIso8601String(),
  };

  factory Volk.fromJson(Map<String, dynamic> json) => Volk(
    id: json['id'],
    name: json['name'],
    standortId: json['standortId'],
    rasse: Bienenrasse.values[json['rasse'] ?? 0],
    status: Volksstatus.values[json['status'] ?? 0],
    staerke: json['staerke'] ?? 5,
    koeninginId: json['koeninginId'] ?? '',
    koeninginJahr: json['koeninginJahr'] ?? '',
    koeninginMarkiert: json['koeninginMarkiert'] ?? false,
    koeninginFarbe: json['koeninginFarbe'] ?? '',
    notizen: json['notizen'] ?? '',
    erstelltAm: DateTime.parse(json['erstelltAm']),
    naechsteInspektion: json['naechsteInspektion'] != null
        ? DateTime.parse(json['naechsteInspektion'])
        : null,
  );

  /// Internationale Königinnen-Markierungsfarben nach Jahr
  static String markierungFarbeNachJahr(int jahr) {
    switch (jahr % 5) {
      case 1: return 'Weiß';
      case 2: return 'Gelb';
      case 3: return 'Rot';
      case 4: return 'Grün';
      case 0: return 'Blau';
      default: return '';
    }
  }
}
