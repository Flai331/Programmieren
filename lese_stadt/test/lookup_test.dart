import 'package:flutter_test/flutter_test.dart';
import 'package:lese_stadt/model/genre.dart';
import 'package:lese_stadt/services/book_lookup.dart';

void main() {
  test('ISBN-Prüfziffern', () {
    expect(isValidIsbn('978-3-551-55167-2'), isTrue);
    expect(isValidIsbn('9783551551673'), isFalse);
    expect(isValidIsbn('3-551-55167-7'), isTrue);
    expect(isValidIsbn('080442957X'), isTrue);
    expect(isValidIsbn('123'), isFalse);
  });

  test('Genres aus Schlagwörtern', () {
    expect(genresFromSubjects(['Fantasy fiction', 'Magic', 'Wizards']), [
      Genre.fantasy,
    ]);
    expect(genresFromSubjects(['Science fiction', 'Space warfare']), [
      Genre.scifi,
    ]);
    expect(genresFromSubjects(['Detective and mystery stories']), [
      Genre.krimi,
    ]);
    expect(genresFromSubjects(['Juvenile fiction']), isEmpty);
  });

  test('Reihenangaben', () {
    expect(parseSeries('Harry Potter ; 3'), ('Harry Potter', 3));
    expect(parseSeries('Harry-Potter-Reihe ; Bd. 1'), ('Harry-Potter', 1));
    expect(parseSeries('Die Tribute von Panem, Band 2'), (
      'Die Tribute von Panem',
      2,
    ));
    expect(parseSeries('Discworld'), ('Discworld', null));
    expect(seriesFromTitle('The Hunger Games (The Hunger Games, #1)'), (
      'The Hunger Games',
      1,
    ));
    expect(seriesFromTitle('Gefährliche Liebe (Band 3)'), ('', 3));
  });

  test('Open Library data', () {
    final info = parseOpenLibraryData('9783551551672', {
      'ISBN:9783551551672': {
        'title': 'Harry Potter und der Stein der Weisen',
        'authors': [
          {'name': 'J. K. Rowling'},
        ],
        'number_of_pages': 335,
        'subjects': [
          {'name': 'Magic'},
          {'name': 'Fantasy fiction'},
        ],
      },
    })!;
    expect(info.titel, 'Harry Potter und der Stein der Weisen');
    expect(info.autor, 'J. K. Rowling');
    expect(info.seiten, 335);
    expect(info.genres, [Genre.fantasy]);
  });

  test('Open Library Edition liefert Reihe', () {
    final ed = parseOpenLibraryEdition({
      'series': ['Harry Potter ; 1'],
      'works': [
        {'key': '/works/OL82563W'},
      ],
      'number_of_pages': 336,
    });
    expect(ed.reihe, 'Harry Potter');
    expect(ed.band, 1);
    expect(ed.work, '/works/OL82563W');
  });

  test('Google Books', () {
    final info = parseGoogleBooks('9780439023481', {
      'items': [
        {
          'volumeInfo': {
            'title': 'The Hunger Games (The Hunger Games, #1)',
            'authors': ['Suzanne Collins'],
            'pageCount': 374,
            'categories': ['Young Adult Fiction / Dystopian'],
            'seriesInfo': {'bookDisplayNumber': '1'},
          },
        },
      ],
    })!;
    expect(info.reihe, 'The Hunger Games');
    expect(info.band, 1);
    expect(info.genres, [Genre.scifi]);
    expect(parseGoogleBooks('x', {'totalItems': 0}), isNull);
  });

  test('Open Library Suche', () {
    final r = parseOpenLibrarySearch({
      'docs': [
        {
          'title': 'Dune',
          'author_name': ['Frank Herbert'],
          'number_of_pages_median': 604,
          'isbn': ['0441013597', '9780441013593'],
        },
        {'title': 'Ohne ISBN'},
      ],
    });
    expect(r.first.isbn, '9780441013593');
    expect(r.first.seiten, 604);
    expect(r.last.isbn, isNull);
  });

  test('Zusammenführen bevorzugt vorhandene Werte', () {
    final a = BookInfo(titel: 'A', seiten: null);
    final b = BookInfo(titel: 'B', seiten: 100, reihe: 'R', band: 2);
    final m = a.merge(b);
    expect(m.titel, 'A');
    expect(m.seiten, 100);
    expect(m.reihe, 'R');
  });
}
