import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lese_stadt/services/book_lookup.dart';

String dnbTreffer(List<(String, String, String)> buecher) =>
    '''
<searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
${buecher.map((b) => '''
<record><recordData><record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
<datafield tag="020" ind1=" " ind2=" "><subfield code="a">${b.$3}</subfield></datafield>
<datafield tag="100" ind1="1" ind2=" "><subfield code="a">Rossmann, Dirk</subfield></datafield>
<datafield tag="245" ind1="1" ind2="0"><subfield code="a">${b.$1}</subfield></datafield>
<datafield tag="300" ind1=" " ind2=" "><subfield code="a">${b.$2}</subfield></datafield>
</record></recordData></record>''').join()}
</records></searchRetrieveResponse>''';

void main() {
  test('gleiche Bücher aus mehreren Quellen werden zusammengefasst', () async {
    final angefragt = <String>{};
    final client = MockClient((req) async {
      angefragt.add(req.url.host);
      switch (req.url.host) {
        case 'openlibrary.org':
          // Open Library: dasselbe Buch zweimal, ein Buch fehlt.
          return http.Response(
            jsonEncode({
              'docs': [
                {
                  'title': 'Der neunte Arm des Oktopus',
                  'author_name': ['Dirk Rossmann'],
                  'isbn': ['9783785727294'],
                },
                {
                  'title': 'Der neunte Arm des Oktopus',
                  'author_name': ['Dirk Rossmann'],
                  'number_of_pages_median': 432,
                },
              ],
            }),
            200,
          );
        case 'www.googleapis.com':
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'volumeInfo': {
                    'title': 'Der Zorn des Oktopus',
                    'subtitle': 'Thriller',
                    'authors': ['Dirk Rossmann', 'Ralf Hoppe'],
                    'pageCount': 448,
                    'industryIdentifiers': [
                      {'type': 'ISBN_13', 'identifier': '9783785727935'},
                    ],
                  },
                },
                {
                  'volumeInfo': {
                    'title': 'Der neunte Arm des Oktopus',
                    'authors': ['Dirk Rossmann'],
                    'pageCount': 430,
                  },
                },
              ],
            }),
            200,
          );
        case 'services.dnb.de':
          expect(req.url.queryParameters['query'], 'woe=Dirk and woe=Rossmann');
          return http.Response.bytes(
            utf8.encode(
              dnbTreffer([
                (
                  'Der neunte Arm des Oktopus :',
                  '432 Seiten',
                  '978-3-7857-2729-4',
                ),
                (
                  '...dann bin ich auf den Baum geklettert! :',
                  '320 Seiten',
                  '9783548064208',
                ),
                ('Der neunte Arm des Oktopus', '1 Audio-CD', ''),
              ]),
            ),
            200,
          );
      }
      return http.Response('', 404);
    });

    final treffer = await BookLookup(client).search('Dirk Rossmann');
    expect(angefragt, {
      'openlibrary.org',
      'www.googleapis.com',
      'services.dnb.de',
    });
    final titel = treffer.map((b) => b.titel).toList();
    expect(titel.where((t) => t.startsWith('Der neunte Arm')), hasLength(1));
    expect(titel, contains('Der Zorn des Oktopus: Thriller'));
    expect(titel.any((t) => t.contains('Baum geklettert')), isTrue);
    final arm = treffer.firstWhere((b) => b.titel.startsWith('Der neunte Arm'));
    expect(arm.seiten, 432);
    expect(arm.isbn, '9783785727294');
  });

  test('Werkschlüssel ignoriert Untertitel und Schreibweise', () {
    expect(
      werkSchluessel(
        BookInfo(
          titel: 'Der Zorn des Oktopus: Thriller',
          autor: 'Dirk Rossmann, Ralf Hoppe',
        ),
      ),
      werkSchluessel(
        BookInfo(titel: 'DER ZORN DES OKTOPUS', autor: 'Rossmann'),
      ),
    );
  });

  test('ohne Netz leere Liste statt Fehler', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    expect(await BookLookup(client).search('Rossmann'), isEmpty);
  });
}
