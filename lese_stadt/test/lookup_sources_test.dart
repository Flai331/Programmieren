import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lese_stadt/model/genre.dart';
import 'package:lese_stadt/services/book_lookup.dart';

// Gekürzte SRU-Antwort der DNB im Format MARC21-xml.
String dnbRecord({
  String titel = 'Die Tote im Watt',
  String sachgruppe = 'B',
  String gattung = 'Kriminalroman',
}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
  <version>1.1</version>
  <numberOfRecords>1</numberOfRecords>
  <records><record>
    <recordSchema>MARC21-xml</recordSchema>
    <recordPacking>xml</recordPacking>
    <recordData>
      <record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
        <leader>00000nam a22000008c 4500</leader>
        <controlfield tag="001">1234567890</controlfield>
        <datafield tag="020" ind1=" " ind2=" ">
          <subfield code="a">9783000000000</subfield>
        </datafield>
        <datafield tag="083" ind1="7" ind2="4">
          <subfield code="a">$sachgruppe</subfield>
          <subfield code="2">23sdnb</subfield>
        </datafield>
        <datafield tag="100" ind1="1" ind2=" ">
          <subfield code="a">Muster, Maria</subfield>
          <subfield code="4">aut</subfield>
        </datafield>
        <datafield tag="245" ind1="1" ind2="0">
          <subfield code="a">$titel :</subfield>
          <subfield code="b">Ein Nordsee-Krimi</subfield>
          <subfield code="c">Maria Muster</subfield>
        </datafield>
        <datafield tag="300" ind1=" " ind2=" ">
          <subfield code="a">412 Seiten</subfield>
          <subfield code="c">19 cm</subfield>
        </datafield>
        <datafield tag="490" ind1="1" ind2=" ">
          <subfield code="a">Kommissarin Janssen ermittelt</subfield>
          <subfield code="v">Band 3</subfield>
        </datafield>
        <datafield tag="655" ind1=" " ind2="7">
          <subfield code="a">$gattung</subfield>
          <subfield code="2">gnd-content</subfield>
        </datafield>
      </record>
    </recordData>
  </record></records>
</searchRetrieveResponse>''';

void main() {
  group('DNB', () {
    test('Titel, Autor, Seiten, Reihe und Genre', () {
      final info = parseDnb('9783000000000', dnbRecord())!;
      expect(info.titel, 'Die Tote im Watt');
      expect(info.autor, 'Maria Muster');
      expect(info.seiten, 412);
      expect(info.reihe, 'Kommissarin Janssen ermittelt');
      expect(info.band, 3);
      expect(info.genres, [Genre.krimi]);
    });

    test('Sachgruppe erkennt Sachbuch und Geschichte', () {
      expect(
        parseDnb(
          'x',
          dnbRecord(sachgruppe: '570', gattung: 'Einführung'),
        )!.genres,
        [Genre.sachbuch],
      );
      expect(
        parseDnb(
          'x',
          dnbRecord(sachgruppe: '943', gattung: 'Darstellung'),
        )!.genres,
        [Genre.geschichte],
      );
      expect(
        parseDnb(
          'x',
          dnbRecord(sachgruppe: '920', gattung: 'Biografie'),
        )!.genres,
        [Genre.geschichte],
      );
      expect(
        parseDnb('x', dnbRecord(sachgruppe: '830', gattung: 'Roman'))!.genres,
        isEmpty,
      );
    });

    test('keine Treffer oder kaputtes XML', () {
      expect(
        parseDnb(
          'x',
          '<searchRetrieveResponse><numberOfRecords>0</numberOfRecords>'
              '</searchRetrieveResponse>',
        ),
        isNull,
      );
      expect(parseDnb('x', 'kein xml'), isNull);
    });
  });

  group('Wikidata', () {
    test('Genre-Namen aus der Antwort', () {
      final genres = parseWikidataGenres({
        'head': {
          'vars': ['genreLabel'],
        },
        'results': {
          'bindings': [
            {
              'genreLabel': {
                'type': 'literal',
                'xml:lang': 'de',
                'value': 'Fantasy-Literatur',
              },
            },
            {
              'genreLabel': {'type': 'literal', 'value': 'Jugendliteratur'},
            },
          ],
        },
      });
      expect(genres, ['Fantasy-Literatur', 'Jugendliteratur']);
      expect(genresFromSubjects(genres), [Genre.fantasy]);
    });

    test('deutsche Genrenamen', () {
      expect(genresFromSubjects(['Science-Fiction-Literatur']), [Genre.scifi]);
      expect(genresFromSubjects(['Historischer Roman']), [Genre.geschichte]);
      expect(genresFromSubjects(['Horrorliteratur']), [Genre.horror]);
    });

    test('Anführungszeichen im Titel werden maskiert', () {
      final q = wikidataGenreQuery('Das "große" Buch');
      expect(q, contains(r'"Das \"große\" Buch"@de'));
    });
  });

  test('ISBN-Abruf kombiniert alle Quellen', () async {
    final angefragt = <String>[];
    final client = MockClient((req) async {
      angefragt.add(req.url.host);
      switch (req.url.host) {
        case 'services.dnb.de':
          return http.Response.bytes(utf8.encode(dnbRecord()), 200);
        case 'query.wikidata.org':
          expect(req.headers['User-Agent'], startsWith('LeseStadt/'));
          expect(
            req.url.queryParameters['query'],
            contains('Die Tote im Watt'),
          );
          return http.Response(
            jsonEncode({
              'results': {
                'bindings': [
                  {
                    'genreLabel': {'value': 'Kriminalroman'},
                  },
                ],
              },
            }),
            200,
          );
        default:
          // Open Library und Google Books kennen das Buch nicht.
          return http.Response('not found', 404);
      }
    });
    final info = (await BookLookup(client).byIsbn('9783000000000'))!;
    expect(info.titel, 'Die Tote im Watt');
    expect(info.seiten, 412);
    expect(info.band, 3);
    expect(info.genres, [Genre.krimi]);
    expect(angefragt, containsAll(['services.dnb.de', 'query.wikidata.org']));
  });

  test('Genre aus mehreren Quellen: Mehrheit gewinnt', () {
    final info = BookInfo(titel: 'X', schlagwoerter: ['Fantasy'])
        .merge(BookInfo(schlagwoerter: ['Fantasy-Literatur', 'Liebesroman']))
        .withPooledGenres();
    expect(info.genres.first, Genre.fantasy);
    expect(info.genres, contains(Genre.romance));
  });
}
