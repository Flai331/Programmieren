import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../model/genre.dart';

class BookInfo {
  BookInfo({
    this.isbn,
    this.titel = '',
    this.autor = '',
    this.seiten,
    this.genres = const [],
    this.reihe,
    this.band,
    this.schlagwoerter = const [],
  });

  final String? isbn;
  final String titel;
  final String autor;
  final int? seiten;
  final List<Genre> genres;
  final String? reihe;
  final int? band;

  /// Rohe Schlagwörter aller Quellen; daraus wird am Ende das Genre bestimmt.
  final List<String> schlagwoerter;

  BookInfo merge(BookInfo other) => BookInfo(
    isbn: isbn ?? other.isbn,
    titel: titel.isNotEmpty ? titel : other.titel,
    autor: autor.isNotEmpty ? autor : other.autor,
    seiten: seiten ?? other.seiten,
    genres: genres.isNotEmpty ? genres : other.genres,
    reihe: reihe ?? other.reihe,
    band: band ?? other.band,
    schlagwoerter: [...schlagwoerter, ...other.schlagwoerter],
  );

  /// Genre aus den Schlagwörtern aller Quellen zusammen, sonst das bisherige.
  BookInfo withPooledGenres() {
    final pooled = genresFromSubjects(schlagwoerter);
    return BookInfo(
      isbn: isbn,
      titel: titel,
      autor: autor,
      seiten: seiten,
      genres: pooled.isNotEmpty ? pooled : genres,
      reihe: reihe,
      band: band,
      schlagwoerter: schlagwoerter,
    );
  }
}

String normalizeIsbn(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

bool isValidIsbn(String raw) {
  final s = normalizeIsbn(raw);
  if (s.length == 13 && RegExp(r'^\d{13}$').hasMatch(s)) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(s[i]) * (i.isEven ? 1 : 3);
    }
    return (10 - sum % 10) % 10 == int.parse(s[12]);
  }
  if (s.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(s)) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final v = s[i] == 'X' ? 10 : int.parse(s[i]);
      sum += v * (10 - i);
    }
    return sum % 11 == 0;
  }
  return false;
}

// ------------------------------------------------------------ Genre-Erkennung

const _genreKeywords = <Genre, List<String>>{
  Genre.krimi: [
    'crime',
    'detective',
    'mystery',
    'thriller',
    'krimi',
    'kriminal',
    'suspense',
    'police',
    'murder',
    'spionage',
    'espionage',
  ],
  Genre.fantasy: [
    'fantasy',
    'magic',
    'wizard',
    'dragon',
    'zauber',
    'magie',
    'drachen',
    'elves',
    'elfen',
  ],
  Genre.scifi: [
    'science fiction',
    'science-fiction',
    'sci-fi',
    'scifi',
    'space',
    'dystop',
    'robot',
    'zukunft',
    'weltraum',
    'cyberpunk',
    'time travel',
  ],
  Genre.romance: ['romance', 'love stor', 'liebesroman', 'liebe', 'romantic'],
  Genre.geschichte: [
    'history',
    'biograph',
    'geschichte',
    'memoir',
    'autobiograph',
    'historical',
    'historisch',
    'biograf',
  ],
  Genre.horror: [
    'horror',
    'ghost',
    'vampire',
    'zombie',
    'supernatural',
    'grusel',
    'gespenst',
    'haunted',
  ],
  Genre.klassiker: [
    'classic',
    'klassiker',
    'classical literature',
    'weltliteratur',
  ],
  Genre.sachbuch: [
    'nonfiction',
    'sachliteratur',
    'non-fiction',
    'sachbuch',
    'science',
    'psychology',
    'self-help',
    'economics',
    'philosophy',
    'ratgeber',
    'wissenschaft',
    'politics',
    'business',
    'textbook',
  ],
};

/// Ordnet Schlagwörter (Open Library, Google Books) den Genres zu, häufigste
/// Treffer zuerst, höchstens drei.
List<Genre> genresFromSubjects(Iterable<String> subjects) {
  final hits = <Genre, int>{};
  for (final raw in subjects) {
    final s = raw.toLowerCase();
    for (final entry in _genreKeywords.entries) {
      if (entry.value.any(s.contains)) {
        hits[entry.key] = (hits[entry.key] ?? 0) + 1;
      }
    }
  }
  // "science" steckt auch in "science fiction".
  if (hits.containsKey(Genre.scifi)) hits.remove(Genre.sachbuch);
  final sorted = hits.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(3).map((e) => e.key).toList();
}

// ------------------------------------------------------------ Reihen-Parser

final _seriesPatterns = [
  // "Harry Potter ; 3", "Harry-Potter-Reihe ; Bd. 1", "Panem -- 2"
  RegExp(
    r'^(.+?)\s*(?:;|--|,|#|:)\s*(?:bd\.?|band|vol\.?|volume|book|teil|nr\.?)?\s*(\d+)\s*$',
    caseSensitive: false,
  ),
  // "Harry Potter Band 3"
  RegExp(
    r'^(.+?)\s+(?:bd\.?|band|vol\.?|volume|book|teil)\s*(\d+)\s*$',
    caseSensitive: false,
  ),
];

/// Liest Reihenname und Bandnummer aus Angaben wie "Harry Potter ; 3".
(String, int?)? parseSeries(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  for (final p in _seriesPatterns) {
    final m = p.firstMatch(s);
    if (m != null) {
      return (_cleanSeriesName(m.group(1)!), int.parse(m.group(2)!));
    }
  }
  return (_cleanSeriesName(s), null);
}

/// Reihe aus einem Titel wie "Die Tribute von Panem (Band 2)" oder
/// "The Hunger Games (The Hunger Games, #1)".
(String, int)? seriesFromTitle(String title) {
  final m = RegExp(
    r'\(([^()]*?)[,;]?\s*(?:#|band|bd\.?|teil|book|vol\.?)\s*(\d+)\)\s*$',
    caseSensitive: false,
  ).firstMatch(title);
  if (m == null) return null;
  final name = _cleanSeriesName(m.group(1)!);
  return (name.isEmpty ? '' : name, int.parse(m.group(2)!));
}

String _cleanSeriesName(String s) => s
    .replaceAll(RegExp(r'\s*-?\s*reihe$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[\s,;:.-]+$'), '')
    .trim();

// ------------------------------------------------------------ JSON-Parser

/// Open Library `api/books?jscmd=data`.
BookInfo? parseOpenLibraryData(String isbn, Map<String, dynamic> json) {
  final data = json['ISBN:$isbn'];
  if (data is! Map) return null;
  final authors = (data['authors'] as List? ?? const [])
      .map((a) => (a as Map)['name'] as String? ?? '')
      .where((n) => n.isNotEmpty);
  final subjects = (data['subjects'] as List? ?? const []).map(
    (s) => s is Map ? s['name'] as String? ?? '' : s.toString(),
  );
  final title = [
    data['title'],
    data['subtitle'],
  ].whereType<String>().where((t) => t.isNotEmpty).join(': ');
  return BookInfo(
    isbn: isbn,
    titel: data['title'] as String? ?? title,
    autor: authors.join(', '),
    seiten: (data['number_of_pages'] as num?)?.toInt(),
    genres: genresFromSubjects(subjects),
    schlagwoerter: subjects.toList(),
  );
}

/// Open Library Edition (`/isbn/<isbn>.json`): Reihe und Werk-Schlüssel.
({String? reihe, int? band, String? work, int? seiten}) parseOpenLibraryEdition(
  Map<String, dynamic> json,
) {
  String? reihe;
  int? band;
  for (final s in (json['series'] as List? ?? const [])) {
    final parsed = parseSeries(s.toString());
    if (parsed != null && parsed.$1.isNotEmpty) {
      reihe = parsed.$1;
      band = parsed.$2;
      break;
    }
  }
  final works = json['works'] as List? ?? const [];
  final work = works.isEmpty ? null : (works.first as Map)['key'] as String?;
  return (
    reihe: reihe,
    band: band,
    work: work,
    seiten: (json['number_of_pages'] as num?)?.toInt(),
  );
}

/// Google Books `volumes?q=isbn:`.
BookInfo? parseGoogleBooks(String isbn, Map<String, dynamic> json) {
  final items = json['items'] as List? ?? const [];
  if (items.isEmpty) return null;
  final info = (items.first as Map)['volumeInfo'] as Map? ?? const {};
  final title = info['title'] as String? ?? '';
  final seriesInfo = info['seriesInfo'] as Map?;
  var band = int.tryParse('${seriesInfo?['bookDisplayNumber'] ?? ''}');
  String? reihe;
  final fromTitle = seriesFromTitle(title);
  if (fromTitle != null) {
    reihe = fromTitle.$1.isEmpty ? null : fromTitle.$1;
    band ??= fromTitle.$2;
  }
  final categories = (info['categories'] as List? ?? const [])
      .map((c) => c.toString())
      .toList();
  return BookInfo(
    isbn: isbn,
    titel: title,
    autor: (info['authors'] as List? ?? const []).join(', '),
    seiten: (info['pageCount'] as num?)?.toInt(),
    genres: genresFromSubjects(categories),
    reihe: reihe,
    band: band,
    schlagwoerter: categories,
  );
}

String? _pickIsbn(List<String> isbns) {
  if (isbns.isEmpty) return null;
  return isbns.firstWhere((i) => i.length == 13, orElse: () => isbns.first);
}

/// Open Library `search.json`.
List<BookInfo> parseOpenLibrarySearch(Map<String, dynamic> json) => [
  for (final d in (json['docs'] as List? ?? const []).cast<Map>())
    BookInfo(
      isbn: _pickIsbn((d['isbn'] as List? ?? const []).cast<String>()),
      titel: d['title'] as String? ?? '',
      autor: (d['author_name'] as List? ?? const []).join(', '),
      seiten: (d['number_of_pages_median'] as num?)?.toInt(),
      genres: genresFromSubjects(
        (d['subject'] as List? ?? const []).map((s) => s.toString()),
      ),
    ),
];

/// Deutsche Nationalbibliothek, SRU-Antwort im Format MARC21-xml.
///
/// Genutzt werden Titel (245), Person (100), Umfang (300), Reihe (490),
/// Schlagwörter und Gattungsbegriffe (650, 655, 689) sowie die
/// DNB-Sachgruppe (082/083), an der Sachbuch und Geschichte erkennbar sind.
BookInfo? parseDnb(String isbn, String xmlText) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xmlText);
  } on XmlException {
    return null;
  }
  final record = doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'record' && e.getAttribute('type') != null)
      .firstOrNull;
  if (record == null) return null;

  List<Map<String, String>> fields(String tag) => [
    for (final f in record.descendants.whereType<XmlElement>())
      if (f.localName == 'datafield' && f.getAttribute('tag') == tag)
        {
          for (final sf in f.childElements)
            if (sf.localName == 'subfield')
              sf.getAttribute('code') ?? '': sf.innerText.trim(),
        },
  ];

  String clean(String s) =>
      s.replaceAll(RegExp(r'[\s/:;,.]+$'), '').replaceAll('¬', '').trim();

  final t = fields('245').firstOrNull ?? const {};
  final titel = clean(t['a'] ?? '');

  final person = fields('100').firstOrNull?['a'];
  var autor = '';
  if (person != null) {
    final teile = person.split(',').map((x) => x.trim()).toList();
    autor = teile.length == 2 ? '${teile[1]} ${teile[0]}' : person;
  }

  int? seiten;
  for (final f in fields('300')) {
    final m = RegExp(r'(\d+)\s*(?:S\.|Seiten)').firstMatch(f['a'] ?? '');
    if (m != null) {
      seiten = int.parse(m.group(1)!);
      break;
    }
  }

  String? reihe;
  int? band;
  for (final f in [...fields('490'), ...fields('830'), ...fields('800')]) {
    final name = clean(f['t'] ?? f['a'] ?? '');
    if (name.isEmpty) continue;
    reihe = name;
    band = int.tryParse(
      RegExp(r'\d+').firstMatch(f['v'] ?? '')?.group(0) ?? '',
    );
    break;
  }

  final schlagwoerter = <String>[
    for (final tag in ['650', '655', '689'])
      for (final f in fields(tag))
        if ((f['a'] ?? '').isNotEmpty) f['a']!,
  ];
  for (final tag in ['082', '083']) {
    for (final f in fields(tag)) {
      final hint = _sachgruppeHint(f['a'] ?? '');
      if (hint != null) schlagwoerter.add(hint);
    }
  }

  if (titel.isEmpty) return null;
  return BookInfo(
    isbn: isbn,
    titel: titel,
    autor: autor,
    seiten: seiten,
    genres: genresFromSubjects(schlagwoerter),
    reihe: reihe,
    band: band,
    schlagwoerter: schlagwoerter,
  );
}

/// DNB-Sachgruppe (Dewey-Hauptklasse) als Schlagwort. Belletristik (B, 800er)
/// und Kinderbuch (K) sagen nichts über das Genre aus.
String? _sachgruppeHint(String code) {
  final m = RegExp(r'^(\d{3})').firstMatch(code.trim());
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  if (n >= 800 && n < 900) return null;
  if (n == 910) return 'Sachbuch';
  if (n >= 900) return n == 920 ? 'Biografie' : 'Geschichte';
  return 'Sachbuch';
}

/// Wikidata-Abfrage: Genres (P136) von Werken oder Ausgaben mit genau diesem
/// Titel, bei Ausgaben über das zugehörige Werk (P629).
String wikidataGenreQuery(String titel) {
  final t = titel.replaceAll(r'\', '').replaceAll('"', r'\"');
  return '''
SELECT DISTINCT ?genreLabel WHERE {
  VALUES ?titel { "$t"@de "$t"@en }
  ?item rdfs:label ?titel .
  { ?item wdt:P136 ?genre } UNION { ?item wdt:P629 ?werk . ?werk wdt:P136 ?genre }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en". }
} LIMIT 20''';
}

/// Genre-Namen aus einer Wikidata-SPARQL-Antwort.
List<String> parseWikidataGenres(Map<String, dynamic> json) => [
  for (final b
      in ((json['results'] as Map?)?['bindings'] as List? ?? const [])
          .cast<Map>())
    if ((b['genreLabel'] as Map?)?['value'] is String)
      (b['genreLabel'] as Map)['value'] as String,
];

// ------------------------------------------------------------ Abruf

class BookLookup {
  BookLookup([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  // Wikidata verlangt einen aussagekräftigen User-Agent.
  static const _headers = {
    'User-Agent': 'LeseStadt/1.0 (https://github.com/Flai331/Programmieren)',
  };

  Future<String?> _getText(
    Uri url, [
    Map<String, String> extra = const {},
  ]) async {
    try {
      final r = await _client
          .get(url, headers: {..._headers, ...extra})
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      return utf8.decode(r.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _get(
    String url, [
    Map<String, String> extra = const {},
  ]) async {
    final text = await _getText(Uri.parse(url), extra);
    if (text == null) return null;
    try {
      final body = jsonDecode(text);
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  Future<BookInfo?> _dnb(String isbn) async {
    final xmlText = await _getText(
      Uri.https('services.dnb.de', '/sru/dnb', {
        'version': '1.1',
        'operation': 'searchRetrieve',
        'query': 'num=$isbn',
        'recordSchema': 'MARC21-xml',
        'maximumRecords': '1',
      }),
    );
    return xmlText == null ? null : parseDnb(isbn, xmlText);
  }

  Future<List<String>> _wikidataGenres(String titel) async {
    // Untertitel abschneiden, Wikidata führt meist nur den Haupttitel.
    final haupttitel = titel.split(RegExp(r'\s*[:.]\s')).first.trim();
    if (haupttitel.isEmpty) return const [];
    final url = Uri.https('query.wikidata.org', '/sparql', {
      'query': wikidataGenreQuery(haupttitel),
      'format': 'json',
    });
    final json = await _get(url.toString(), {
      'Accept': 'application/sparql-results+json',
    });
    return json == null ? const [] : parseWikidataGenres(json);
  }

  /// Buchdaten per ISBN: Open Library zuerst, die Deutsche Nationalbibliothek
  /// und Google Books ergänzen Lücken (deutsche Bücher, Reiheninfos). Das
  /// Genre ergibt sich aus den Schlagwörtern aller Quellen plus Wikidata.
  /// Null, wenn nichts gefunden wurde.
  Future<BookInfo?> byIsbn(String raw) async {
    final isbn = normalizeIsbn(raw);
    final dnbFuture = _dnb(isbn);
    final results = await Future.wait([
      _get(
        'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
      ),
      _get('https://openlibrary.org/isbn/$isbn.json'),
      _get('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn'),
    ]);
    var info = results[0] == null
        ? null
        : parseOpenLibraryData(isbn, results[0]!);
    if (results[1] != null) {
      final ed = parseOpenLibraryEdition(results[1]!);
      var subjects = const <String>[];
      if ((info?.genres ?? const []).isEmpty && ed.work != null) {
        final work = await _get('https://openlibrary.org${ed.work}.json');
        subjects = (work?['subjects'] as List? ?? const [])
            .map((s) => s.toString())
            .toList();
      }
      info = (info ?? BookInfo(isbn: isbn)).merge(
        BookInfo(
          isbn: isbn,
          seiten: ed.seiten,
          genres: genresFromSubjects(subjects),
          reihe: ed.reihe,
          band: ed.band,
          schlagwoerter: subjects,
        ),
      );
    }
    final google = results[2] == null
        ? null
        : parseGoogleBooks(isbn, results[2]!);
    final dnb = await dnbFuture;
    for (final extra in [dnb, google]) {
      if (extra != null) info = (info ?? BookInfo(isbn: isbn)).merge(extra);
    }
    if (info == null || info.titel.isEmpty) return null;
    final wikidata = await _wikidataGenres(info.titel);
    return info.merge(BookInfo(schlagwoerter: wikidata)).withPooledGenres();
  }

  Future<List<BookInfo>> search(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final json = await _get(
      'https://openlibrary.org/search.json?q=$q&limit=15&fields=title,author_name,number_of_pages_median,isbn,subject',
    );
    return json == null ? const [] : parseOpenLibrarySearch(json);
  }
}
