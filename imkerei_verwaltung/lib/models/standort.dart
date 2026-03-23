// ═══════════════════════════════════════════════════════════════
//  Modell: Standort (Bienenstand / Apiary)
// ═══════════════════════════════════════════════════════════════

class Standort {
  final String id;
  String name;
  String adresse;
  String beschreibung;
  String trachtpflanzen; // z.B. "Linde, Raps, Obstblüte"
  DateTime erstelltAm;

  Standort({
    required this.id,
    required this.name,
    this.adresse = '',
    this.beschreibung = '',
    this.trachtpflanzen = '',
    required this.erstelltAm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'adresse': adresse,
    'beschreibung': beschreibung,
    'trachtpflanzen': trachtpflanzen,
    'erstelltAm': erstelltAm.toIso8601String(),
  };

  factory Standort.fromJson(Map<String, dynamic> json) => Standort(
    id: json['id'],
    name: json['name'],
    adresse: json['adresse'] ?? '',
    beschreibung: json['beschreibung'] ?? '',
    trachtpflanzen: json['trachtpflanzen'] ?? '',
    erstelltAm: DateTime.parse(json['erstelltAm']),
  );
}
