import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'escl_client.dart';

/// Liest die TXT-Einträge eines mDNS-Dienstes (`key=value` je Zeile).
Map<String, String> parseTxt(String text) => {
      for (final line in text.split('\n'))
        if (line.contains('='))
          line.substring(0, line.indexOf('=')).trim().toLowerCase():
              line.substring(line.indexOf('=') + 1).trim(),
    };

/// Findet eSCL-Scanner im WLAN (Bonjour/mDNS: `_uscan._tcp`, `_uscans._tcp`).
class EsclDiscovery {
  static const _channel = MethodChannel('dokubox/multicast');

  /// Sucht [duration] lang und meldet jeden gefundenen Scanner einmal.
  static Stream<EsclScanner> search(
      {Duration duration = const Duration(seconds: 6)}) async* {
    // Android verwirft Multicast-Pakete ohne „MulticastLock“.
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('acquire');
      } catch (_) {}
    }
    // Android kann kein reusePort → eigene Socket-Fabrik ohne.
    final client = MDnsClient(
      rawDatagramSocketFactory: (dynamic host, int port,
              {bool reuseAddress = true, bool reusePort = false, int ttl = 255}) =>
          RawDatagramSocket.bind(host, port,
              reuseAddress: true, reusePort: false, ttl: ttl),
    );
    final seen = <String>{};
    try {
      await client.start();
      for (final service in const ['_uscan._tcp', '_uscans._tcp']) {
        final https = service == '_uscans._tcp';
        await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('$service.local'),
          timeout: duration ~/ 2,
        )) {
          final name = ptr.domainName;
          final srv = await client
              .lookup<SrvResourceRecord>(ResourceRecordQuery.service(name),
                  timeout: const Duration(seconds: 2))
              .firstOrNullAsync;
          if (srv == null) continue;
          final txt = await client
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(name),
                  timeout: const Duration(seconds: 2))
              .firstOrNullAsync;
          final ip = await client
              .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                  timeout: const Duration(seconds: 2))
              .firstOrNullAsync;
          final host = ip?.address.address ?? srv.target;
          final info = parseTxt(txt?.text ?? '');
          final label = info['ty'] ??
              name.replaceAll(RegExp(r'\._uscans?\._tcp\.local\.?$'), '');
          final scanner = EsclScanner.fromAddress(
            host,
            port: srv.port,
            https: https,
            path: info['rs'] ?? 'eSCL',
            name: label,
          );
          if (seen.add('$host:${srv.port}')) yield scanner;
        }
      }
    } finally {
      client.stop();
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod<void>('release');
        } catch (_) {}
      }
    }
  }
}

/// Merkt sich den zuletzt benutzten Scanner und die Einstellungen.
class ScannerPrefs {
  static const _url = 'escl_url';
  static const _name = 'escl_name';
  static const _feeder = 'escl_feeder';
  static const _duplex = 'escl_duplex';
  static const _color = 'escl_color';
  static const _res = 'escl_resolution';

  static Future<EsclScanner?> lastScanner() async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString(_url);
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return EsclScanner(uri, name: p.getString(_name) ?? uri.host);
  }

  static Future<void> saveScanner(EsclScanner s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_url, s.base.toString());
    await p.setString(_name, s.name);
  }

  static Future<EsclScanSettings> settings() async {
    final p = await SharedPreferences.getInstance();
    return EsclScanSettings(
      feeder: p.getBool(_feeder) ?? true,
      duplex: p.getBool(_duplex) ?? false,
      color: p.getBool(_color) ?? true,
      resolution: p.getInt(_res) ?? 300,
    );
  }

  static Future<void> saveSettings(EsclScanSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_feeder, s.feeder);
    await p.setBool(_duplex, s.duplex);
    await p.setBool(_color, s.color);
    await p.setInt(_res, s.resolution);
  }
}

extension<T> on Stream<T> {
  /// Erster Eintrag oder null, wenn der Stream leer endet.
  Future<T?> get firstOrNullAsync =>
      cast<T?>().firstWhere((_) => true, orElse: () => null);
}
