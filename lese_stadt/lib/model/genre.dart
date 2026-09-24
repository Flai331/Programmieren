import 'package:flutter/painting.dart';

/// Baumaterial. Holz gibt es für jede Seite, alles andere kommt über das Genre.
enum Mat {
  holz('Holz', Color(0xFFB07A45)),
  stein('Stein', Color(0xFF8E9298)),
  kristall('Kristall', Color(0xFF9B6BDE)),
  metall('Metall', Color(0xFF5F8FB0)),
  papier('Papier', Color(0xFFE8DDBF)),
  blueten('Blüten', Color(0xFFE88BB0)),
  marmor('Marmor', Color(0xFFDCD6CF)),
  schattenholz('Schattenholz', Color(0xFF4A3F55)),
  gold('Gold', Color(0xFFE0B23A));

  const Mat(this.label, this.color);
  final String label;
  final Color color;
}

enum Genre {
  krimi('Krimi/Thriller', Mat.stein, 'Hafengasse'),
  fantasy('Fantasy', Mat.kristall, 'Burgdorf'),
  scifi('Sci-Fi', Mat.metall, 'Raumsiedlung'),
  sachbuch('Sachbuch', Mat.papier, 'Gelehrtenviertel'),
  romance('Romance', Mat.blueten, 'Rosengarten'),
  geschichte('Geschichte/Biografie', Mat.marmor, 'Altstadt'),
  horror('Horror', Mat.schattenholz, 'Nebelweiler'),
  klassiker('Klassiker', Mat.gold, 'Goldgasse');

  const Genre(this.label, this.material, this.viertelStil);
  final String label;
  final Mat material;

  /// Baustil eines Reihen-Viertels in diesem Genre.
  final String viertelStil;
}

/// Genres werden als kommagetrennte Namen gespeichert, z. B. "fantasy,klassiker".
String genresToText(List<Genre> genres) => genres.map((g) => g.name).join(',');

List<Genre> genresFromText(String text) => [
  for (final part in text.split(','))
    for (final g in Genre.values)
      if (g.name == part.trim()) g,
];
