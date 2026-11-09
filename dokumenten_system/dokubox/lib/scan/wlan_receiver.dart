import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Eine vom PC (Scan-Trenner → „Per WLAN ans Handy“) angebotene Datei.
class WlanFile {
  final String id;
  final String name;
  final int size;
  const WlanFile(this.id, this.name, this.size);
}

/// Prüft einen gescannten/eingetippten Link. Erlaubt sind nur Links des
/// Scan-Trenners auf eine Adresse im eigenen Netz (192.168.x.x, 10.x.x.x,
/// 172.16–31.x.x) — so schickt ein fremder QR-Code die App nicht ins
/// Internet. Liefert die Basis-Adresse (endet auf `/`) oder `null`.
Uri? parseWlanLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'http' || !uri.hasPort) return null;
  if (!isPrivateIPv4(uri.host)) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2 || segments[0] != 'dokubox') return null;
  if (!RegExp(r'^[A-Za-z0-9_-]{16,}$').hasMatch(segments[1])) return null;
  return Uri(
    scheme: 'http',
    host: uri.host,
    port: uri.port,
    path: '/dokubox/${segments[1]}/',
  );
}

bool isPrivateIPv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final n = <int>[];
  for (final part in parts) {
    final v = int.tryParse(part);
    if (v == null || v < 0 || v > 255) return false;
    n.add(v);
  }
  return n[0] == 10 ||
      (n[0] == 192 && n[1] == 168) ||
      (n[0] == 172 && n[1] >= 16 && n[1] <= 31);
}

/// Liest die Antwort von `<basis>/liste`.
List<WlanFile> parseWlanList(String body) {
  final json = jsonDecode(body);
  if (json is! Map || json['app'] != 'dokubox-wlan') {
    throw const WlanException('Das ist kein DokuBox-Link vom Scan-Trenner.');
  }
  final files = json['dateien'];
  if (files is! List) return const [];
  return [
    for (final f in files)
      if (f is Map && f['id'] != null && f['name'] is String)
        WlanFile('${f['id']}', f['name'] as String,
            (f['groesse'] as num?)?.toInt() ?? 0),
  ];
}

class WlanException implements Exception {
  final String message;
  const WlanException(this.message);
  @override
  String toString() => message;
}

/// Holt die angebotenen PDFs vom PC.
class WlanReceiver {
  static const _timeout = Duration(seconds: 20);
  static const maxFileBytes = 200 * 1024 * 1024;

  final Uri base;
  WlanReceiver(this.base);

  Future<List<WlanFile>> list() async {
    final body = await _get(base.resolve('liste'), (r) => utf8.decodeStream(r));
    return parseWlanList(body);
  }

  /// Lädt [files] in ein temporäres Verzeichnis und liefert die Pfade.
  /// [onProgress] bekommt (fertig, gesamt).
  Future<List<String>> download(
    List<WlanFile> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'wlan_import'));
    await dir.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final safe = f.name.replaceAll(RegExp(r'[^\w.\- äöüÄÖÜß]'), '_');
      final target = File(p.join(dir.path,
          '${DateTime.now().microsecondsSinceEpoch}_$safe'));
      await _get(base.resolve('datei/${Uri.encodeComponent(f.id)}'),
          (r) async {
        final sink = target.openWrite();
        var received = 0;
        try {
          await for (final chunk in r) {
            received += chunk.length;
            if (received > maxFileBytes) {
              throw const WlanException('Datei ist zu groß.');
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
      });
      paths.add(target.path);
      onProgress?.call(i + 1, files.length);
    }
    return paths;
  }

  Future<T> _get<T>(
      Uri url, Future<T> Function(HttpClientResponse r) read) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(url).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode == 404) {
        await response.drain<void>();
        throw const WlanException(
            'Link abgelaufen oder ungültig – am PC neu erzeugen.');
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw WlanException('PC antwortet mit Fehler ${response.statusCode}.');
      }
      return await read(response);
    } on SocketException {
      throw const WlanException(
          'PC nicht erreichbar. Sind Handy und PC im selben WLAN? '
          'Evtl. die Windows-Firewall für Python erlauben.');
    } on HttpException catch (e) {
      throw WlanException('Übertragung abgebrochen (${e.message}).');
    } finally {
      client.close(force: true);
    }
  }
}
