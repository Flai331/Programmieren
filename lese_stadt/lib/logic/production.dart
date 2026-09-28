import '../data/db.dart';
import '../model/catalog.dart';
import '../model/genre.dart';
import 'economy.dart';

/// Was ein Betrieb herstellt. Gearbeitet wird, wenn gelesen wird: Die Menge
/// ergibt sich aus den Seiten, die seit dem Bau des Gebäudes gelesen wurden.
class Betrieb {
  const Betrieb({
    required this.ware,
    required this.einheit,
    required this.seitenJe,
    required this.preisHolz,
    this.seitenJeMitHilfe,
    this.hilfe,
  });

  final String ware;

  /// Mehrzahl bzw. Maßeinheit für die Anzeige, z. B. "Brote".
  final String einheit;

  /// Gelesene Seiten für eine Einheit.
  final int seitenJe;

  /// Schneller, wenn es das Hilfsgebäude [hilfe] in der Stadt gibt.
  final int? seitenJeMitHilfe;
  final String? hilfe;

  /// Erlös am Markt pro Einheit.
  final int preisHolz;
}

const betriebe = {
  'wassermuehle': Betrieb(
    ware: 'Mehl',
    einheit: 'Sack Mehl',
    seitenJe: 15,
    preisHolz: 1,
  ),
  'baeckerei': Betrieb(
    ware: 'Brot',
    einheit: 'Brote',
    seitenJe: 25,
    seitenJeMitHilfe: 10,
    hilfe: 'wassermuehle',
    preisHolz: 2,
  ),
};

const markttypen = {typDorfmarkt, 'marktplatz'};

class Produktion {
  Produktion(this.gebaeude, this.betrieb, this.menge, this.mitHilfe);
  final Building gebaeude;
  final Betrieb betrieb;
  final int menge;
  final bool mitHilfe;

  int get erloes => menge * betrieb.preisHolz;
}

/// Produktion aller Betriebe der Stadt.
List<Produktion> produktion(
  List<Building> buildings,
  List<ReadingEntry> entries,
) {
  final typen = {for (final b in buildings) b.typeId};
  return [
    for (final b in buildings)
      if (betriebe[b.typeId] case final betrieb?)
        () {
          final seiten = entries
              .where((e) => !e.datum.isBefore(b.gebautAm))
              .fold(0, (s, e) => s + pagesOf(e));
          final mitHilfe =
              betrieb.hilfe != null && typen.contains(betrieb.hilfe);
          final je = mitHilfe ? betrieb.seitenJeMitHilfe! : betrieb.seitenJe;
          return Produktion(b, betrieb, seiten ~/ je, mitHilfe);
        }(),
  ];
}

/// Der Markt verkauft alles, was die Betriebe herstellen, gegen Holz.
/// Ohne Markt wird nichts verkauft.
Materials marktErloes(List<Building> buildings, List<ReadingEntry> entries) {
  if (!buildings.any((b) => markttypen.contains(b.typeId))) return {};
  final holz = produktion(buildings, entries).fold(0, (s, p) => s + p.erloes);
  return holz == 0 ? {} : {Mat.holz: holz};
}
