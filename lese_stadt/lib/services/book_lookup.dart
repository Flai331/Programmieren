import 'dart:convert';

import 'package:http/http.dart' as http;

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
  });

  final String? isbn;
  final String titel;
  final String autor;
  final int? seiten;
  final List<Genre> genres;
  final String? reihe;
  final int? band;

  BookInfo merge(BookInfo other) => BookInfo(
    isbn: isbn ?? other.isbn,
    titel: titel.isNotEmpty ? titel : other.titel,
    autor: autor.isNotEmpty ? autor : other.autor,
    seiten: seiten ?? other.seiten,
    genres: genres.isNotEmpty ? genres : other.genres,
    reihe: reihe ?? other.reihe,
    band: band ?? other.band,
  );
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
  return BookInfo(
    isbn: isbn,
    titel: title,
    autor: (info['authors'] as List? ?? const []).join(', '),
    seiten: (info['pageCount'] as num?)?.toInt(),
    genres: genresFromSubjects(
      (info['categories'] as List? ?? const []).map((c) => c.toString()),
    ),
    reihe: reihe,
    band: band,
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

// ------------------------------------------------------------ Abruf

class BookLookup {
  BookLookup([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final r = await _client.get(Uri.parse(url)).timeout(_timeout);
      if (r.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  /// Buchdaten per ISBN: Open Library zuerst, Google Books ergänzt Lücken
  /// (vor allem Reiheninfos). Null, wenn nichts gefunden wurde.
  Future<BookInfo?> byIsbn(String raw) async {
    final isbn = normalizeIsbn(raw);
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
      var genres = info?.genres ?? const <Genre>[];
      if (genres.isEmpty && ed.work != null) {
        final work = await _get('https://openlibrary.org${ed.work}.json');
        genres = genresFromSubjects(
          (work?['subjects'] as List? ?? const []).map((s) => s.toString()),
        );
      }
      info = (info ?? BookInfo(isbn: isbn)).merge(
        BookInfo(
          isbn: isbn,
          seiten: ed.seiten,
          genres: genres,
          reihe: ed.reihe,
          band: ed.band,
        ),
      );
    }
    final google = results[2] == null
        ? null
        : parseGoogleBooks(isbn, results[2]!);
    if (google != null) info = (info ?? BookInfo(isbn: isbn)).merge(google);
    if (info == null || info.titel.isEmpty) return null;
    return info;
  }

  Future<List<BookInfo>> search(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final json = await _get(
      'https://openlibrary.org/search.json?q=$q&limit=15&fields=title,author_name,number_of_pages_median,isbn,subject',
    );
    return json == null ? const [] : parseOpenLibrarySearch(json);
  }
}
