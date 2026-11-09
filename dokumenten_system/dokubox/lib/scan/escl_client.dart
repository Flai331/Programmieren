import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

/// Netzwerk-Scanner per eSCL („AirScan“/Mopria) – unterstützt von den
/// meisten aktuellen Geräten von Epson, Canon, HP, Brother.
///
/// Ablauf: Fähigkeiten lesen → Scan-Auftrag anlegen (POST ScanJobs) →
/// Seiten einzeln mit NextDocument abholen, bis der Scanner 404 meldet.
class EsclScanner {
  /// Basis-Adresse inkl. Ressourcenpfad, z. B. `http://192.168.1.30:80/eSCL/`.
  final Uri base;
  final String name;

  const EsclScanner(this.base, {this.name = 'Scanner'});

  /// Aus IP/Hostname (+ optional Port, https, Pfad) bauen.
  factory EsclScanner.fromAddress(String host,
      {int? port, bool https = false, String path = 'eSCL', String? name}) {
    final cleanPath = path.replaceAll(RegExp(r'^/+|/+$'), '');
    return EsclScanner(
      Uri(
        scheme: https ? 'https' : 'http',
        host: host,
        port: port ?? (https ? 443 : 80),
        path: cleanPath.isEmpty ? '/' : '/$cleanPath/',
      ),
      name: name ?? host,
    );
  }

  String get key => base.toString();
}

/// Was der Scanner kann.
class EsclCapabilities {
  final String makeAndModel;
  final bool hasPlaten;
  final bool hasFeeder;
  final bool hasDuplex;

  /// Maximalgröße in 1/300 Zoll (Feeder bevorzugt, sonst Glas).
  final int maxWidth;
  final int maxHeight;
  final List<int> resolutions;
  final List<String> colorModes;
  final List<String> formats;

  const EsclCapabilities({
    this.makeAndModel = '',
    this.hasPlaten = false,
    this.hasFeeder = false,
    this.hasDuplex = false,
    this.maxWidth = a4Width,
    this.maxHeight = a4Height,
    this.resolutions = const [300],
    this.colorModes = const ['RGB24'],
    this.formats = const ['image/jpeg'],
  });

  /// A4 in 1/300 Zoll.
  static const a4Width = 2480;
  static const a4Height = 3508;

  /// Nächste unterstützte Auflösung zu [wanted].
  int resolutionNear(int wanted) {
    if (resolutions.isEmpty) return wanted;
    return resolutions.reduce(
        (a, b) => (a - wanted).abs() <= (b - wanted).abs() ? a : b);
  }

  bool get supportsJpeg => formats.contains('image/jpeg');
}

String _local(XmlElement e) => e.name.local;

Iterable<XmlElement> _all(XmlNode node, String localName) =>
    node.descendants.whereType<XmlElement>().where((e) => _local(e) == localName);

String? _text(XmlNode node, String localName) {
  final e = _all(node, localName).firstOrNull;
  final t = e?.innerText.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Liest `ScannerCapabilities` (Namensräume werden ignoriert, die Hersteller
/// schreiben sie unterschiedlich).
EsclCapabilities parseCapabilities(String xml) {
  final doc = XmlDocument.parse(xml);
  final platen = _all(doc, 'PlatenInputCaps').firstOrNull;
  final adf = _all(doc, 'AdfSimplexInputCaps').firstOrNull;
  final duplex = _all(doc, 'AdfDuplexInputCaps').firstOrNull;
  final source = adf ?? platen ?? doc;

  int intOf(XmlNode n, String name, int fallback) =>
      int.tryParse(_text(n, name) ?? '') ?? fallback;

  final resolutions = {
    for (final r in _all(source, 'DiscreteResolution'))
      ?int.tryParse(_text(r, 'XResolution') ?? ''),
  }.toList()
    ..sort();
  final colorModes = {
    for (final c in _all(source, 'ColorMode')) c.innerText.trim(),
  }.where((c) => c.isNotEmpty).toList();
  final formats = {
    for (final f in [
      ..._all(source, 'DocumentFormatExt'),
      ..._all(source, 'DocumentFormat'),
    ])
      f.innerText.trim(),
  }.where((f) => f.isNotEmpty).toList();

  return EsclCapabilities(
    makeAndModel: _text(doc, 'MakeAndModel') ?? '',
    hasPlaten: platen != null,
    hasFeeder: adf != null,
    hasDuplex: duplex != null,
    maxWidth: intOf(source, 'MaxWidth', EsclCapabilities.a4Width),
    maxHeight: intOf(source, 'MaxHeight', EsclCapabilities.a4Height),
    resolutions: resolutions.isEmpty ? const [300] : resolutions,
    colorModes: colorModes.isEmpty ? const ['RGB24'] : colorModes,
    formats: formats.isEmpty ? const ['image/jpeg'] : formats,
  );
}

/// Zustand laut `ScannerStatus`.
class EsclStatus {
  /// Idle, Processing, Stopped, Testing …
  final String state;

  /// z. B. ScannerAdfLoaded, ScannerAdfEmpty, ScannerAdfJam (oder null).
  final String? adfState;
  const EsclStatus(this.state, this.adfState);

  bool get idle => state == 'Idle';
  bool get adfEmpty => adfState == 'ScannerAdfEmpty';
  bool get adfJam => adfState == 'ScannerAdfJam';
}

EsclStatus parseStatus(String xml) {
  final doc = XmlDocument.parse(xml);
  return EsclStatus(_text(doc, 'State') ?? 'Unknown', _text(doc, 'AdfState'));
}

/// Scan-Einstellungen.
class EsclScanSettings {
  final bool feeder;
  final bool duplex;
  final bool color;
  final int resolution;

  const EsclScanSettings({
    this.feeder = true,
    this.duplex = false,
    this.color = true,
    this.resolution = 300,
  });
}

/// Baut das `ScanSettings`-XML für einen Auftrag. Fläche: A4, aber nie größer
/// als der Scanner kann.
String buildScanSettings(EsclScanSettings s, EsclCapabilities caps) {
  final width = caps.maxWidth < EsclCapabilities.a4Width
      ? caps.maxWidth
      : EsclCapabilities.a4Width;
  final height = caps.maxHeight < EsclCapabilities.a4Height
      ? caps.maxHeight
      : EsclCapabilities.a4Height;
  final res = caps.resolutionNear(s.resolution);
  final mode = s.color
      ? (caps.colorModes.contains('RGB24') ? 'RGB24' : caps.colorModes.first)
      : (caps.colorModes.contains('Grayscale8')
          ? 'Grayscale8'
          : caps.colorModes.first);
  final format = caps.supportsJpeg ? 'image/jpeg' : caps.formats.first;
  final useFeeder = s.feeder && caps.hasFeeder || !caps.hasPlaten;
  final duplex = useFeeder && s.duplex && caps.hasDuplex;
  return '''<?xml version="1.0" encoding="UTF-8"?>
<scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.0</pwg:Version>
  <pwg:ScanRegions>
    <pwg:ScanRegion>
      <pwg:ContentRegionUnits>escl:ThreeHundredthsOfInches</pwg:ContentRegionUnits>
      <pwg:XOffset>0</pwg:XOffset>
      <pwg:YOffset>0</pwg:YOffset>
      <pwg:Width>$width</pwg:Width>
      <pwg:Height>$height</pwg:Height>
    </pwg:ScanRegion>
  </pwg:ScanRegions>
  <pwg:DocumentFormat>$format</pwg:DocumentFormat>
  <scan:DocumentFormatExt>$format</scan:DocumentFormatExt>
  <pwg:InputSource>${useFeeder ? 'Feeder' : 'Platen'}</pwg:InputSource>
  <scan:ColorMode>$mode</scan:ColorMode>
  <scan:XResolution>$res</scan:XResolution>
  <scan:YResolution>$res</scan:YResolution>
  <scan:Duplex>$duplex</scan:Duplex>
</scan:ScanSettings>''';
}

class EsclException implements Exception {
  final String message;
  const EsclException(this.message);
  @override
  String toString() => message;
}

/// Eine empfangene Seite.
class EsclPage {
  final Uint8List bytes;
  final String contentType;
  const EsclPage(this.bytes, this.contentType);
  bool get isPdf => contentType.contains('pdf');
}

/// Spricht mit einem eSCL-Scanner.
class EsclClient {
  final EsclScanner scanner;
  final HttpClient _http;

  /// Wartezeit zwischen Wiederholungen, wenn der Scanner „beschäftigt“ (503)
  /// meldet oder die Seite noch nicht fertig ist.
  final Duration retryDelay;

  EsclClient(this.scanner, {this.retryDelay = const Duration(seconds: 1)})
      : _http = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8)
          // Canon/Epson nutzen bei https selbstsignierte Zertifikate. Nur
          // für Geräte im eigenen Netz akzeptieren.
          ..badCertificateCallback =
              ((X509Certificate cert, String host, int port) =>
                  _isLocalHost(host));

  static bool _isLocalHost(String host) {
    final p = host.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.contains(null)) return host.endsWith('.local');
    return p[0] == 10 ||
        (p[0] == 192 && p[1] == 168) ||
        (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31) ||
        (p[0] == 169 && p[1] == 254);
  }

  void close() => _http.close(force: true);

  Future<({int status, Map<String, String> headers, Uint8List body})> _send(
    String method,
    Uri url, {
    String? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final req = await _http.openUrl(method, url).timeout(timeout);
      if (body != null) {
        req.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
        req.write(body);
      }
      final res = await req.close().timeout(timeout);
      final bytes = await res
          .fold<BytesBuilder>(BytesBuilder(copy: false), (b, c) => b..add(c))
          .timeout(const Duration(minutes: 3));
      final headers = <String, String>{};
      res.headers.forEach((k, v) => headers[k.toLowerCase()] = v.join(','));
      return (status: res.statusCode, headers: headers, body: bytes.takeBytes());
    } on SocketException {
      throw const EsclException(
          'Scanner nicht erreichbar. Ist er eingeschaltet und im selben WLAN?');
    } on TimeoutException {
      throw const EsclException('Der Scanner antwortet nicht (Zeitüberschreitung).');
    } on HandshakeException {
      throw const EsclException('Sichere Verbindung zum Scanner fehlgeschlagen.');
    }
  }

  Future<EsclCapabilities> capabilities() async {
    final r = await _send('GET', scanner.base.resolve('ScannerCapabilities'));
    if (r.status != 200) {
      throw EsclException('Das Gerät kann nicht per eSCL scannen '
          '(Antwort ${r.status}). Ist es ein Netzwerk-Scanner mit AirScan/Mopria?');
    }
    try {
      return parseCapabilities(String.fromCharCodes(r.body));
    } on XmlException {
      throw const EsclException('Antwort des Scanners nicht lesbar.');
    }
  }

  Future<EsclStatus> status() async {
    final r = await _send('GET', scanner.base.resolve('ScannerStatus'));
    if (r.status != 200) return const EsclStatus('Unknown', null);
    try {
      return parseStatus(String.fromCharCodes(r.body));
    } on XmlException {
      return const EsclStatus('Unknown', null);
    }
  }

  /// Scannt und liefert die Seiten nacheinander. [onPage] wird nach jeder
  /// empfangenen Seite aufgerufen. Bricht ab, wenn [cancelled] true liefert.
  Future<List<EsclPage>> scan(
    EsclScanSettings settings,
    EsclCapabilities caps, {
    void Function(int pages)? onPage,
    bool Function()? cancelled,
  }) async {
    final xml = buildScanSettings(settings, caps);
    // Manche Geräte melden kurz nach dem Aufwachen „503 beschäftigt“.
    late final ({int status, Map<String, String> headers, Uint8List body}) job;
    for (var attempt = 0;; attempt++) {
      final r = await _send('POST', scanner.base.resolve('ScanJobs'), body: xml);
      if (r.status == 201 || r.status == 200) {
        job = r;
        break;
      }
      if (r.status == 503 && attempt < 10) {
        await Future<void>.delayed(retryDelay * 2);
        continue;
      }
      if (r.status == 409) {
        throw const EsclException('Kein Papier im Einzug – oder der Scanner '
            'ist gerade beschäftigt.');
      }
      throw EsclException('Scan konnte nicht gestartet werden (${r.status}).');
    }
    final location = job.headers['location'];
    if (location == null || location.isEmpty) {
      throw const EsclException('Scanner hat keinen Auftrag zurückgegeben.');
    }
    final jobUrl = scanner.base.resolve(location);
    final next = Uri.parse(
        '${jobUrl.toString().replaceAll(RegExp(r'/+$'), '')}/NextDocument');

    final pages = <EsclPage>[];
    var waits = 0;
    while (true) {
      if (cancelled?.call() ?? false) {
        await _send('DELETE', jobUrl).catchError((_) =>
            (status: 0, headers: <String, String>{}, body: Uint8List(0)));
        break;
      }
      final r = await _send('GET', next, timeout: const Duration(minutes: 2));
      if (r.status == 200 && r.body.isNotEmpty) {
        pages.add(EsclPage(r.body, r.headers['content-type'] ?? 'image/jpeg'));
        onPage?.call(pages.length);
        waits = 0;
        continue;
      }
      if (r.status == 404 || r.status == 410) break; // fertig
      if (r.status == 503 && waits < 120) {
        waits++;
        await Future<void>.delayed(retryDelay);
        continue;
      }
      if (pages.isEmpty) {
        throw EsclException(
            'Keine Seite empfangen (${r.status}). Papier eingelegt?');
      }
      break;
    }
    if (pages.isEmpty) {
      throw const EsclException('Keine Seite empfangen. Papier eingelegt?');
    }
    return pages;
  }
}
