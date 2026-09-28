import '../data/db.dart';
import '../model/catalog.dart';
import '../model/genre.dart';
import 'economy.dart';

/// Was ein Betrieb herstellt. Betriebe arbeiten von selbst, werktags wie
/// sonntags von 7 bis 18 Uhr – auch wenn gerade niemand liest.
class Betrieb {
  const Betrieb({
    required this.ware,
    required this.einheit,
    required this.minutenJe,
    required this.preisHolz,
    this.minutenJeMitHilfe,
    this.hilfe,
  });

  final String ware;

  /// Mehrzahl bzw. Maßeinheit für die Anzeige, z. B. "Brote".
  final String einheit;

  /// Arbeitsminuten für eine Einheit.
  final int minutenJe;

  /// Schneller, wenn es das Hilfsgebäude [hilfe] in der Stadt gibt.
  final int? minutenJeMitHilfe;
  final String? hilfe;

  /// Erlös am Markt pro Einheit.
  final int preisHolz;
}

const betriebe = {
  'wassermuehle': Betrieb(
    ware: 'Mehl',
    einheit: 'Sack Mehl',
    minutenJe: 120,
    preisHolz: 1,
  ),
  'baeckerei': Betrieb(
    ware: 'Brot',
    einheit: 'Brote',
    minutenJe: 180,
    minutenJeMitHilfe: 90,
    hilfe: 'wassermuehle',
    preisHolz: 2,
  ),
};

const markttypen = {typDorfmarkt, 'marktplatz'};

/// Arbeitszeit der Betriebe.
const arbeitsBeginn = 7;
const arbeitsEnde = 18;

/// Arbeitsminuten zwischen [von] und [bis] (jeweils 7 bis 18 Uhr).
int arbeitsminuten(DateTime von, DateTime bis) {
  if (!bis.isAfter(von)) return 0;
  var summe = 0;
  var tag = DateTime(von.year, von.month, von.day);
  while (tag.isBefore(bis)) {
    final a = DateTime(tag.year, tag.month, tag.day, arbeitsBeginn);
    final e = DateTime(tag.year, tag.month, tag.day, arbeitsEnde);
    final s = von.isAfter(a) ? von : a;
    final t = bis.isBefore(e) ? bis : e;
    if (t.isAfter(s)) summe += t.difference(s).inMinutes;
    tag = DateTime(tag.year, tag.month, tag.day + 1);
  }
  return summe;
}

class Produktion {
  Produktion(
    this.gebaeude,
    this.betrieb,
    this.menge,
    this.heute,
    this.mitHilfe,
  );
  final Building gebaeude;
  final Betrieb betrieb;

  /// Seit dem Bau hergestellt.
  final int menge;

  /// Davon heute.
  final int heute;
  final bool mitHilfe;

  int get erloes => menge * betrieb.preisHolz;
  int get minutenJe =>
      mitHilfe ? betrieb.minutenJeMitHilfe! : betrieb.minutenJe;
}

/// Produktion aller Betriebe der Stadt bis [now].
List<Produktion> produktion(List<Building> buildings, DateTime now) {
  final typen = {for (final b in buildings) b.typeId};
  final heuteFrueh = DateTime(now.year, now.month, now.day);
  return [
    for (final b in buildings)
      if (betriebe[b.typeId] case final betrieb?)
        () {
          final mitHilfe =
              betrieb.hilfe != null && typen.contains(betrieb.hilfe);
          final je = mitHilfe ? betrieb.minutenJeMitHilfe! : betrieb.minutenJe;
          final menge = arbeitsminuten(b.gebautAm, now) ~/ je;
          final bisGestern = b.gebautAm.isBefore(heuteFrueh)
              ? arbeitsminuten(b.gebautAm, heuteFrueh) ~/ je
              : 0;
          return Produktion(b, betrieb, menge, menge - bisGestern, mitHilfe);
        }(),
  ];
}

/// Der Markt verkauft alles, was die Betriebe herstellen, gegen Holz.
/// Ohne Markt wird nichts verkauft.
Materials marktErloes(List<Building> buildings, DateTime now) {
  if (!buildings.any((b) => markttypen.contains(b.typeId))) return {};
  final holz = produktion(buildings, now).fold(0, (s, p) => s + p.erloes);
  return holz == 0 ? {} : {Mat.holz: holz};
}
