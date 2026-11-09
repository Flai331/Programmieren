import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/scan/escl_client.dart';
import 'package:dokubox/scan/escl_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gekürzte, aber echte Struktur einer Epson-Antwort (Namensräume wie im
/// Gerät).
const epsonCaps = '''<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerCapabilities xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.63</pwg:Version>
  <pwg:MakeAndModel>EPSON ET-4850 Series</pwg:MakeAndModel>
  <scan:Platen><scan:PlatenInputCaps>
    <scan:MinWidth>16</scan:MinWidth><scan:MaxWidth>2550</scan:MaxWidth>
    <scan:MaxHeight>3508</scan:MaxHeight>
    <scan:SettingProfiles><scan:SettingProfile>
      <scan:ColorModes><scan:ColorMode>RGB24</scan:ColorMode><scan:ColorMode>Grayscale8</scan:ColorMode></scan:ColorModes>
      <scan:DocumentFormats><pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat><pwg:DocumentFormat>application/pdf</pwg:DocumentFormat><scan:DocumentFormatExt>image/jpeg</scan:DocumentFormatExt></scan:DocumentFormats>
      <scan:SupportedResolutions><scan:DiscreteResolutions>
        <scan:DiscreteResolution><scan:XResolution>100</scan:XResolution><scan:YResolution>100</scan:YResolution></scan:DiscreteResolution>
        <scan:DiscreteResolution><scan:XResolution>300</scan:XResolution><scan:YResolution>300</scan:YResolution></scan:DiscreteResolution>
        <scan:DiscreteResolution><scan:XResolution>600</scan:XResolution><scan:YResolution>600</scan:YResolution></scan:DiscreteResolution>
      </scan:DiscreteResolutions></scan:SupportedResolutions>
    </scan:SettingProfile></scan:SettingProfiles>
  </scan:PlatenInputCaps></scan:Platen>
  <scan:Adf>
    <scan:AdfSimplexInputCaps>
      <scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>4200</scan:MaxHeight>
      <scan:SettingProfiles><scan:SettingProfile>
        <scan:ColorModes><scan:ColorMode>RGB24</scan:ColorMode><scan:ColorMode>Grayscale8</scan:ColorMode></scan:ColorModes>
        <scan:DocumentFormats><pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat></scan:DocumentFormats>
        <scan:SupportedResolutions><scan:DiscreteResolutions>
          <scan:DiscreteResolution><scan:XResolution>200</scan:XResolution></scan:DiscreteResolution>
          <scan:DiscreteResolution><scan:XResolution>300</scan:XResolution></scan:DiscreteResolution>
        </scan:DiscreteResolutions></scan:SupportedResolutions>
      </scan:SettingProfile></scan:SettingProfiles>
    </scan:AdfSimplexInputCaps>
    <scan:AdfDuplexInputCaps><scan:MaxWidth>2550</scan:MaxWidth></scan:AdfDuplexInputCaps>
  </scan:Adf>
</scan:ScannerCapabilities>''';

/// Canon-Gerät nur mit Glas, nur PDF, ohne Präfixe (Default-Namensraum).
const canonCaps = '''<?xml version="1.0" encoding="UTF-8"?>
<ScannerCapabilities xmlns="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:MakeAndModel>Canon PIXMA TS5350</pwg:MakeAndModel>
  <Platen><PlatenInputCaps>
    <MaxWidth>2550</MaxWidth><MaxHeight>3508</MaxHeight>
    <SettingProfiles><SettingProfile>
      <ColorModes><ColorMode>RGB24</ColorMode></ColorModes>
      <DocumentFormats><pwg:DocumentFormat>application/pdf</pwg:DocumentFormat></DocumentFormats>
      <SupportedResolutions><DiscreteResolutions>
        <DiscreteResolution><XResolution>300</XResolution></DiscreteResolution>
      </DiscreteResolutions></SupportedResolutions>
    </SettingProfile></SettingProfiles>
  </PlatenInputCaps></Platen>
</ScannerCapabilities>''';

/// Kleiner eSCL-Scanner zum Testen.
class FakeScanner {
  late HttpServer server;
  int pagesLeft;
  int busyBeforeStart;
  int busyBeforePage;
  String? lastSettings;
  final requests = <String>[];
  bool deleted = false;
  int _busyPage = 0;

  FakeScanner({this.pagesLeft = 3, this.busyBeforeStart = 0, this.busyBeforePage = 0});

  Future<EsclScanner> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add('${req.method} ${req.uri.path}');
      final res = req.response;
      final path = req.uri.path;
      if (path == '/eSCL/ScannerCapabilities') {
        res.headers.contentType = ContentType('text', 'xml');
        res.write(epsonCaps);
      } else if (path == '/eSCL/ScannerStatus') {
        res.write('<scan:ScannerStatus xmlns:scan="x" xmlns:pwg="y">'
            '<pwg:State>Idle</pwg:State><scan:AdfState>ScannerAdfLoaded</scan:AdfState>'
            '</scan:ScannerStatus>');
      } else if (path == '/eSCL/ScanJobs' && req.method == 'POST') {
        lastSettings = String.fromCharCodes(
            await req.fold<List<int>>([], (a, b) => a..addAll(b)));
        if (busyBeforeStart > 0) {
          busyBeforeStart--;
          res.statusCode = 503;
        } else if (pagesLeft == 0) {
          res.statusCode = 409;
        } else {
          res.statusCode = 201;
          // Absolute URL wie bei Epson.
          res.headers.set('Location',
              'http://127.0.0.1:${server.port}/eSCL/ScanJobs/abc-123');
        }
      } else if (path == '/eSCL/ScanJobs/abc-123/NextDocument') {
        if (_busyPage < busyBeforePage) {
          _busyPage++;
          res.statusCode = 503;
        } else if (pagesLeft > 0) {
          pagesLeft--;
          _busyPage = 0;
          res.headers.contentType = ContentType('image', 'jpeg');
          res.add([0xFF, 0xD8, pagesLeft, 0xFF, 0xD9]);
        } else {
          res.statusCode = 404;
        }
      } else if (path == '/eSCL/ScanJobs/abc-123' && req.method == 'DELETE') {
        deleted = true;
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
    return EsclScanner.fromAddress('127.0.0.1', port: server.port);
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  group('Fähigkeiten lesen', () {
    test('Epson mit Einzug, Duplex, Glas', () {
      final c = parseCapabilities(epsonCaps);
      expect(c.makeAndModel, 'EPSON ET-4850 Series');
      expect([c.hasPlaten, c.hasFeeder, c.hasDuplex], [true, true, true]);
      expect(c.resolutions, [200, 300]); // vom Einzug
      expect(c.colorModes, containsAll(['RGB24', 'Grayscale8']));
      expect(c.supportsJpeg, isTrue);
      expect(c.maxWidth, 2550);
    });

    test('Canon ohne Präfixe, nur Glas, nur PDF', () {
      final c = parseCapabilities(canonCaps);
      expect(c.makeAndModel, 'Canon PIXMA TS5350');
      expect([c.hasPlaten, c.hasFeeder, c.hasDuplex], [true, false, false]);
      expect(c.supportsJpeg, isFalse);
      expect(c.formats, ['application/pdf']);
    });

    test('Status', () {
      final s = parseStatus('<a xmlns:pwg="p" xmlns:scan="s"><pwg:State>Idle'
          '</pwg:State><scan:AdfState>ScannerAdfEmpty</scan:AdfState></a>');
      expect(s.idle, isTrue);
      expect(s.adfEmpty, isTrue);
    });
  });

  group('Scan-Einstellungen', () {
    test('Einzug doppelseitig, Graustufen, nächstliegende Auflösung', () {
      final xml = buildScanSettings(
        const EsclScanSettings(
            feeder: true, duplex: true, color: false, resolution: 250),
        parseCapabilities(epsonCaps),
      );
      expect(xml, contains('<pwg:InputSource>Feeder</pwg:InputSource>'));
      expect(xml, contains('<scan:Duplex>true</scan:Duplex>'));
      expect(xml, contains('<scan:ColorMode>Grayscale8</scan:ColorMode>'));
      expect(xml, contains('<scan:XResolution>200</scan:XResolution>'));
      expect(xml, contains('<pwg:Width>2480</pwg:Width>')); // A4
      expect(xml, contains('image/jpeg'));
    });

    test('Canon: Glas und PDF, Duplex wird nicht angefordert', () {
      final xml = buildScanSettings(
          const EsclScanSettings(feeder: true, duplex: true),
          parseCapabilities(canonCaps));
      expect(xml, contains('<pwg:InputSource>Platen</pwg:InputSource>'));
      expect(xml, contains('<scan:Duplex>false</scan:Duplex>'));
      expect(xml, contains('application/pdf'));
    });
  });

  group('Scannen gegen nachgebauten eSCL-Scanner', () {
    late FakeScanner fake;
    tearDown(() => fake.stop());

    test('holt alle Seiten, wartet bei „beschäftigt“', () async {
      fake = FakeScanner(pagesLeft: 3, busyBeforeStart: 2, busyBeforePage: 2);
      final scanner = await fake.start();
      final client = EsclClient(scanner,
          retryDelay: const Duration(milliseconds: 5));
      final caps = await client.capabilities();
      expect((await client.status()).adfState, 'ScannerAdfLoaded');
      final progress = <int>[];
      final pages = await client.scan(
          const EsclScanSettings(duplex: true), caps,
          onPage: progress.add);
      client.close();
      expect(pages.length, 3);
      expect(progress, [1, 2, 3]);
      expect(pages.first.contentType, startsWith('image/jpeg'));
      expect(pages.first.bytes, Uint8List.fromList([0xFF, 0xD8, 2, 0xFF, 0xD9]));
      expect(fake.lastSettings, contains('<scan:Duplex>true</scan:Duplex>'));
      expect(
          fake.requests.where((r) => r == 'POST /eSCL/ScanJobs').length, 3);
    });

    test('leerer Einzug → verständliche Meldung', () async {
      fake = FakeScanner(pagesLeft: 0);
      final scanner = await fake.start();
      final client = EsclClient(scanner);
      final caps = await client.capabilities();
      await expectLater(
        client.scan(const EsclScanSettings(), caps),
        throwsA(isA<EsclException>().having(
            (e) => e.message, 'message', contains('Kein Papier'))),
      );
      client.close();
    });

    test('Abbrechen löscht den Auftrag am Scanner', () async {
      fake = FakeScanner(pagesLeft: 5);
      final scanner = await fake.start();
      final client = EsclClient(scanner);
      final caps = await client.capabilities();
      var n = 0;
      final pages = await client.scan(const EsclScanSettings(), caps,
          onPage: (p) => n = p, cancelled: () => n >= 2);
      client.close();
      expect(pages.length, 2);
      expect(fake.deleted, isTrue);
    });
  });

  test('nicht erreichbarer Scanner → verständliche Meldung', () async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    final client =
        EsclClient(EsclScanner.fromAddress('127.0.0.1', port: port));
    await expectLater(client.capabilities(),
        throwsA(isA<EsclException>().having(
            (e) => e.message, 'message', contains('nicht erreichbar'))));
    client.close();
  });

  test('mDNS-TXT: Ressourcenpfad und Modell', () {
    final txt = parseTxt('txtvers=1\nty=EPSON ET-4850 Series\nrs=eSCL\n'
        'pdl=application/pdf,image/jpeg\nis=platen,adf,duplex\n');
    expect(txt['ty'], 'EPSON ET-4850 Series');
    expect(txt['rs'], 'eSCL');
    final s = EsclScanner.fromAddress('192.168.1.40',
        port: 443, https: true, path: '/eSCL/');
    expect(s.base.toString(), 'https://192.168.1.40/eSCL/');
    expect(s.base.resolve('ScannerCapabilities').toString(),
        'https://192.168.1.40/eSCL/ScannerCapabilities');
  });
}
