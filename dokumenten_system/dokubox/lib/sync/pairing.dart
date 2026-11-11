import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Ein gekoppeltes Gerät.
class PairedDevice {
  final String id;
  final String name;
  final String secret; // base64
  String host;
  int port;

  /// Zeitstempel (Sekunden) für „seit dem letzten Abgleich“.
  int lastPulled;
  int lastPushed;
  int? lastSyncAt; // ms, Anzeige

  PairedDevice({
    required this.id,
    required this.name,
    required this.secret,
    required this.host,
    required this.port,
    this.lastPulled = 0,
    this.lastPushed = 0,
    this.lastSyncAt,
  });

  List<int> get secretBytes => base64Decode(secret);

  Map<String, Object?> toJson() => {
        'id': id, 'name': name, 'secret': secret, 'host': host, 'port': port,
        'lastPulled': lastPulled, 'lastPushed': lastPushed, 'lastSyncAt': lastSyncAt,
      };

  static PairedDevice fromJson(Map<String, dynamic> j) => PairedDevice(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Gerät',
        secret: j['secret'] as String,
        host: j['host'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? kSyncPort,
        lastPulled: (j['lastPulled'] as num?)?.toInt() ?? 0,
        lastPushed: (j['lastPushed'] as num?)?.toInt() ?? 0,
        lastSyncAt: (j['lastSyncAt'] as num?)?.toInt(),
      );
}

const kSyncPort = 47900;

/// Kopplungs-Code (im QR) eines Geräts, das sich bereitstellt.
class PairingOffer {
  final String host;
  final int port;
  final String deviceId;
  final String name;
  final String secret;
  const PairingOffer(this.host, this.port, this.deviceId, this.name, this.secret);

  String encode() => 'dokubox-pair:${base64Url.encode(utf8.encode(jsonEncode({
            'h': host, 'p': port, 'i': deviceId, 'n': name, 's': secret,
          })))}';

  static PairingOffer? decode(String raw) {
    final t = raw.trim();
    if (!t.startsWith('dokubox-pair:')) return null;
    try {
      final j = jsonDecode(utf8.decode(base64Url.decode(t.substring(13))))
          as Map<String, dynamic>;
      return PairingOffer(j['h'] as String, (j['p'] as num).toInt(),
          j['i'] as String, j['n'] as String, j['s'] as String);
    } catch (_) {
      return null;
    }
  }
}

/// Eigene Geräte-ID/Name, Rolle und Kopplungen.
class SyncSettings {
  static const _devicesKey = 'sync_devices';
  static const _idKey = 'sync_device_id';
  static const _nameKey = 'sync_device_name';
  static const _mainKey = 'sync_is_main';
  static const _tagKey = 'sync_device_tag';

  static Future<String> deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_idKey);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString(_idKey, id);
    }
    return id;
  }

  static Future<String> deviceName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey) ?? 'Mein Gerät';
  static Future<void> setDeviceName(String n) async =>
      (await SharedPreferences.getInstance()).setString(_nameKey, n);

  /// Haupt-Handy vergibt die endgültigen Nummern (Standard: ja).
  static Future<bool> isMain() async =>
      (await SharedPreferences.getInstance()).getBool(_mainKey) ?? true;
  static Future<void> setMain(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_mainKey, v);

  /// Kürzel für vorläufige Nummern weiterer Geräte (V-L0001 …).
  static Future<String> deviceTag() async =>
      (await SharedPreferences.getInstance()).getString(_tagKey) ?? 'X';
  static Future<void> setDeviceTag(String t) async => (await SharedPreferences
          .getInstance())
      .setString(_tagKey, t.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').padRight(1, 'X').substring(0, 1));

  static Future<List<PairedDevice>> devices() async {
    final raw = (await SharedPreferences.getInstance()).getString(_devicesKey);
    if (raw == null) return [];
    return [
      for (final j in jsonDecode(raw) as List) PairedDevice.fromJson(j as Map<String, dynamic>),
    ];
  }

  static Future<void> saveDevices(List<PairedDevice> list) async =>
      (await SharedPreferences.getInstance())
          .setString(_devicesKey, jsonEncode([for (final d in list) d.toJson()]));

  static Future<void> upsert(PairedDevice d) async {
    final list = await devices();
    list.removeWhere((x) => x.id == d.id);
    list.add(d);
    await saveDevices(list);
  }

  static Future<void> remove(String id) async {
    final list = await devices()..removeWhere((x) => x.id == id);
    await saveDevices(list);
  }
}

/// Speicher für Kopplungen (in Tests austauschbar).
abstract class PairingStore {
  Future<List<PairedDevice>> devices();
  Future<void> upsert(PairedDevice d);
  Future<String> deviceId();
  Future<String> deviceName();
}

class PrefsPairingStore implements PairingStore {
  const PrefsPairingStore();
  @override
  Future<List<PairedDevice>> devices() => SyncSettings.devices();
  @override
  Future<void> upsert(PairedDevice d) => SyncSettings.upsert(d);
  @override
  Future<String> deviceId() => SyncSettings.deviceId();
  @override
  Future<String> deviceName() => SyncSettings.deviceName();
}

class MemoryPairingStore implements PairingStore {
  final String id, name;
  final list = <PairedDevice>[];
  MemoryPairingStore(this.id, this.name);
  @override
  Future<List<PairedDevice>> devices() async => list;
  @override
  Future<void> upsert(PairedDevice d) async {
    list.removeWhere((x) => x.id == d.id);
    list.add(d);
  }
  @override
  Future<String> deviceId() async => id;
  @override
  Future<String> deviceName() async => name;
}
