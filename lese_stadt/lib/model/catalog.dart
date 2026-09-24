import 'genre.dart';

enum Kategorie { grund, genre, kombi, denkmal }

/// Stadtstufe nach Gesamtzahl gelesener Seiten.
enum Stufe {
  dorf('Dorf', 0, 10),
  kleinstadt('Kleinstadt', 2000, 16),
  stadt('Stadt', 10000, 24),
  metropole('Metropole', 30000, 32);

  const Stufe(this.label, this.abSeiten, this.groesse);
  final String label;
  final int abSeiten;

  /// Kantenlänge der Baufläche in Feldern.
  final int groesse;

  static Stufe fuerSeiten(int seiten) {
    var result = Stufe.dorf;
    for (final s in Stufe.values) {
      if (seiten >= s.abSeiten) result = s;
    }
    return result;
  }

  Stufe? get naechste =>
      index + 1 < Stufe.values.length ? Stufe.values[index + 1] : null;
}

class BuildingType {
  const BuildingType({
    required this.id,
    required this.name,
    required this.kategorie,
    required this.kosten,
    this.abStufe = Stufe.dorf,
    this.genre,
    this.hoehe = 1.0,
  });

  final String id;
  final String name;
  final Kategorie kategorie;
  final Map<Mat, int> kosten;
  final Stufe abStufe;
  final Genre? genre;

  /// Relative Gebäudehöhe für die Darstellung.
  final double hoehe;

  bool get baubar => kategorie != Kategorie.denkmal;
}

/// Typ-Ids der Gebäude, die nicht im Baumenü stehen.
const typBuchDenkmal = 'buch';
const typJahresprojekt = 'jahr';

const _grund = [
  BuildingType(
    id: 'haus',
    name: 'Haus',
    kategorie: Kategorie.grund,
    kosten: {Mat.holz: 30},
    hoehe: 0.8,
  ),
  BuildingType(
    id: 'strasse',
    name: 'Straße',
    kategorie: Kategorie.grund,
    kosten: {Mat.holz: 5},
    hoehe: 0,
  ),
  BuildingType(
    id: 'baum',
    name: 'Baum',
    kategorie: Kategorie.grund,
    kosten: {Mat.holz: 8},
    hoehe: 0.9,
  ),
];

/// Pro Genre die Gebäude aus dem Konzept, in aufsteigender Stufe.
const _genreGebaeude = {
  Genre.krimi: ['Polizeiwache', 'Detektivbüro', 'Gefängnis'],
  Genre.fantasy: ['Magierturm', 'Burg', 'Drachenhort'],
  Genre.scifi: ['Observatorium', 'Raumhafen', 'Labor'],
  Genre.sachbuch: ['Bibliothek', 'Schule', 'Universität'],
  Genre.romance: ['Park', 'Café', 'Brunnen'],
  Genre.geschichte: ['Denkmal', 'Rathaus', 'Museum'],
  Genre.horror: ['Friedhof', 'Spukhaus'],
  Genre.klassiker: ['Theater', 'Oper'],
};

const _genreKosten = [
  (holz: 40, genre: 60, hoehe: 1.3),
  (holz: 60, genre: 120, hoehe: 1.7),
  (holz: 100, genre: 250, hoehe: 2.2),
];

String _slug(String name) => name
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('é', 'e')
    .replaceAll(' ', '_');

final List<BuildingType> _genreTypes = [
  for (final entry in _genreGebaeude.entries)
    for (var i = 0; i < entry.value.length; i++)
      BuildingType(
        id: _slug(entry.value[i]),
        name: entry.value[i],
        kategorie: Kategorie.genre,
        genre: entry.key,
        abStufe: Stufe.values[i],
        hoehe: _genreKosten[i].hoehe,
        kosten: {
          Mat.holz: _genreKosten[i].holz,
          entry.key.material: _genreKosten[i].genre,
        },
      ),
];

const _kombi = [
  BuildingType(
    id: 'marktplatz',
    name: 'Marktplatz',
    kategorie: Kategorie.kombi,
    abStufe: Stufe.kleinstadt,
    hoehe: 0.6,
    kosten: {Mat.holz: 80, Mat.stein: 40, Mat.blueten: 40, Mat.papier: 40},
  ),
  BuildingType(
    id: 'bahnhof',
    name: 'Bahnhof',
    kategorie: Kategorie.kombi,
    abStufe: Stufe.stadt,
    hoehe: 1.5,
    kosten: {Mat.holz: 120, Mat.metall: 80, Mat.stein: 80, Mat.marmor: 40},
  ),
  BuildingType(
    id: 'hafen',
    name: 'Hafen',
    kategorie: Kategorie.kombi,
    abStufe: Stufe.stadt,
    hoehe: 1.2,
    kosten: {
      Mat.holz: 150,
      Mat.stein: 60,
      Mat.metall: 60,
      Mat.schattenholz: 40,
    },
  ),
];

const _denkmaeler = [
  BuildingType(
    id: typBuchDenkmal,
    name: 'Buch-Denkmal',
    kategorie: Kategorie.denkmal,
    kosten: {},
    hoehe: 1.4,
  ),
  BuildingType(
    id: typJahresprojekt,
    name: 'Jahresbauwerk',
    kategorie: Kategorie.denkmal,
    kosten: {},
    hoehe: 2.6,
  ),
];

final List<BuildingType> catalog = [
  ..._grund,
  ..._genreTypes,
  ..._kombi,
  ..._denkmaeler,
];

final Map<String, BuildingType> _byId = {for (final t in catalog) t.id: t};

BuildingType? typeById(String id) => _byId[id];
