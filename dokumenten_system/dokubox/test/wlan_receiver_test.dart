import 'package:dokubox/scan/wlan_receiver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'Ab3_dEf-GhIjKlMnOpQrSt';

  group('parseWlanLink', () {
    test('Link vom Scan-Trenner wird erkannt', () {
      final uri = parseWlanLink('http://192.168.178.20:53211/dokubox/$token/');
      expect(uri.toString(), 'http://192.168.178.20:53211/dokubox/$token/');
      expect(uri!.resolve('liste').toString(),
          'http://192.168.178.20:53211/dokubox/$token/liste');
      // Ohne Schrägstrich am Ende / mit Leerzeichen.
      expect(parseWlanLink(' http://10.0.0.5:8000/dokubox/$token '),
          isNotNull);
      expect(parseWlanLink('http://172.20.1.2:8000/dokubox/$token/'),
          isNotNull);
    });

    test('nur eigenes Netz, nur http mit Port, nur DokuBox-Pfad', () {
      for (final bad in [
        'http://8.8.8.8:80/dokubox/$token/', // Internet
        'http://example.com:80/dokubox/$token/',
        'http://172.32.0.1:80/dokubox/$token/', // knapp außerhalb 172.16/12
        'http://127.0.0.1:80/dokubox/$token/',
        'https://192.168.1.2:443/dokubox/$token/',
        'http://192.168.1.2/dokubox/$token/', // kein Port
        'http://192.168.1.2:80/anders/$token/',
        'http://192.168.1.2:80/dokubox/kurz/',
        'http://192.168.1.2:80/dokubox/$token/datei/1',
        'irgendein Text',
      ]) {
        expect(parseWlanLink(bad), isNull, reason: bad);
      }
    });
  });

  group('parseWlanList', () {
    test('liest die Dateiliste', () {
      final files = parseWlanList('{"app": "dokubox-wlan", "version": 1, '
          '"dateien": [{"id": "1", "name": "Rechnung enviaM.pdf", '
          '"groesse": 1234}, {"id": "2", "name": "Depot.pdf"}]}');
      expect(files.map((f) => f.name), ['Rechnung enviaM.pdf', 'Depot.pdf']);
      expect(files.first.size, 1234);
      expect(files.last.size, 0);
    });

    test('fremde Antwort wird abgelehnt', () {
      expect(() => parseWlanList('{"dateien": []}'),
          throwsA(isA<WlanException>()));
    });
  });
}
