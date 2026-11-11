import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../data/document_repository.dart';
import 'pairing.dart';
import 'sync_crypto.dart';
import 'sync_engine.dart';

/// Ordner, aus denen Dateien übertragen werden dürfen.
const _allowedDirs = {'pdfs', 'anhaenge', 'vorlagen'};

/// Relativen Pfad prüfen und auflösen (kein „..“, nur erlaubte Ordner).
String? safeLocalPath(String root, String rel) {
  final norm = p.normalize(rel).replaceAll('\\', '/');
  if (p.isAbsolute(norm) || norm.split('/').contains('..')) return null;
  if (!_allowedDirs.contains(norm.split('/').first)) return null;
  return p.join(root, norm);
}

/// Bericht eines Abgleichs.
class SyncReport {
  int received = 0, sent = 0, filesIn = 0, filesOut = 0;
  @override
  String toString() => '$received empfangen, $sent gesendet'
      '${filesIn + filesOut > 0 ? ', ${filesIn + filesOut} Dateien' : ''}';
}

/// Abgleich zwischen gekoppelten Geräten im WLAN: ein Gerät stellt sich
/// bereit (Server, z. B. Laptop), das andere gleicht ab (Client, z. B.
/// Handy). Alles AES-GCM-verschlüsselt mit dem Geheimnis der Kopplung.
class SyncService {
  final AppDatabase db;
  final DocumentRepository repo;
  final Future<Directory> Function() docsDir;

  /// Nach Änderungen (Suchindex ist schon aktualisiert), z. B. Erinnerungen.
  final Future<void> Function(Set<String> documentIds)? onChanged;

  /// Nur für Tests: auch 127.0.0.1 erlauben.
  final bool allowLoopback;
  final PairingStore store;

  SyncService(this.db, this.repo,
      {required this.docsDir,
      this.onChanged,
      this.allowLoopback = false,
      this.store = const PrefsPairingStore()});

  HttpServer? _server;
  PairingOffer? _offer;
  final _offerController = StreamController<PairedDevice>.broadcast();

  /// Neu gekoppelte Geräte (für die Anzeige beim Bereitstellen).
  Stream<PairedDevice> get newPairings => _offerController.stream;
  bool get serving => _server != null;

  // ---------------------------------------------------------------- Server

  /// Bereitstellen. Liefert einen neuen Kopplungs-Code (für den QR).
  Future<PairingOffer> startServer({required String host, int port = kSyncPort}) async {
    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen(_handle, onError: (_) {});
    }
    _offer = PairingOffer(host, _server!.port, await store.deviceId(),
        await store.deviceName(), base64Encode(SyncCrypto.newSecret()));
    return _offer!;
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _offer = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final body = await req.fold<BytesBuilder>(BytesBuilder(copy: false), (b, c) => b..add(c));
      final sealed = body.takeBytes();
      final peerId = req.headers.value('x-dokubox-peer') ?? '';
      final route = req.uri.path;
      if (route == '/pair') {
        final offer = _offer;
        if (offer == null) return _reply(req, 403);
        final crypto = await SyncCrypto.fromSecret(base64Decode(offer.secret));
        final msg = await crypto.open(sealed);
        final device = PairedDevice(
          id: msg.json['id'] as String,
          name: msg.json['name'] as String? ?? 'Gerät',
          secret: offer.secret,
          host: req.connectionInfo?.remoteAddress.address ?? '',
          port: kSyncPort,
        );
        await store.upsert(device);
        _offerController.add(device);
        return _reply(req, 200,
            await crypto.seal({'id': offer.deviceId, 'name': offer.name}));
      }
      final device = (await store.devices()).where((d) => d.id == peerId).firstOrNull;
      if (device == null) return _reply(req, 403);
      final crypto = await SyncCrypto.fromSecret(device.secretBytes);
      final msg = await crypto.open(sealed);
      final root = (await docsDir()).path;
      switch (route) {
        case '/pull':
          final since = (msg.json['since'] as num?)?.toInt();
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final changes = await SyncEngine(db).exportChanges(since: since);
          return _reply(req, 200,
              await crypto.seal({'changes': changes.toJson(), 'now': now}));
        case '/file':
          final path = safeLocalPath(root, msg.json['path'] as String? ?? '');
          final f = path == null ? null : File(path);
          if (f == null || !await f.exists()) {
            return _reply(req, 200, await crypto.seal({'missing': true}));
          }
          return _reply(req, 200, await crypto.seal({}, await f.readAsBytes()));
        case '/push':
          final imported = await _import(SyncChanges.fromJson(
              msg.json['changes'] as Map<String, dynamic>));
          final needed = [
            for (final f in imported.neededFiles)
              if (!await File(safeLocalPath(root, f) ?? '').exists()) f,
          ];
          return _reply(req, 200, await crypto.seal({
            'received': imported.inserted + imported.updated,
            'needed': needed,
          }));
        case '/upload':
          final path = safeLocalPath(root, msg.json['path'] as String? ?? '');
          if (path == null) return _reply(req, 400);
          await File(path).parent.create(recursive: true);
          await File(path).writeAsBytes(msg.data, flush: true);
          return _reply(req, 200, await crypto.seal({'ok': true}));
      }
      return _reply(req, 404);
    } on SyncAuthException {
      return _reply(req, 403);
    } catch (_) {
      return _reply(req, 500);
    }
  }

  Future<void> _reply(HttpRequest req, int status, [Uint8List? body]) async {
    req.response.statusCode = status;
    if (body != null) req.response.add(body);
    await req.response.close();
  }

  /// Import inkl. lokaler Umbenennungen und Suchindex.
  Future<SyncImport> _import(SyncChanges changes) async {
    final r = await SyncEngine(db).importChanges(changes);
    final root = (await docsDir()).path;
    for (final e in r.renames.entries) {
      final from = safeLocalPath(root, e.key), to = safeLocalPath(root, e.value);
      if (from == null || to == null) continue;
      if (await File(from).exists() && !await File(to).exists()) {
        await File(from).rename(to);
      } else if (!await File(to).exists()) {
        r.neededFiles.add(e.value);
      }
    }
    for (final id in r.changedDocuments) {
      await repo.rebuildFts(id);
    }
    if (r.changedDocuments.isNotEmpty) await onChanged?.call(r.changedDocuments);
    return r;
  }

  // ---------------------------------------------------------------- Client

  /// Eigene IPv4-Adresse im WLAN/LAN (für den Kopplungs-Code).
  static Future<String?> localAddress() async {
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in i.addresses) {
        final n = a.address.split('.').map(int.parse).toList();
        if (n[0] == 10 || (n[0] == 192 && n[1] == 168) ||
            (n[0] == 172 && n[1] >= 16 && n[1] <= 31)) {
          return a.address;
        }
      }
    }
    return null;
  }

  bool _hostAllowed(String host) {
    if (allowLoopback && (host == '127.0.0.1' || host == 'localhost')) return true;
    final n = host.split('.').map(int.tryParse).toList();
    if (n.length != 4 || n.contains(null)) return false;
    return n[0] == 10 ||
        (n[0] == 192 && n[1] == 168) ||
        (n[0] == 172 && n[1]! >= 16 && n[1]! <= 31);
  }

  Future<({Map<String, dynamic> json, Uint8List data})> _post(
      String host, int port, String route, SyncCrypto crypto, String peer,
      Map<String, Object?> json, [List<int>? data]) async {
    if (!_hostAllowed(host)) {
      throw const SocketException('Nur Geräte im eigenen WLAN erlaubt.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.post(host, port, route);
      req.headers.set('x-dokubox-peer', peer);
      req.add(await crypto.seal(json, data));
      final res = await req.close().timeout(const Duration(minutes: 2));
      final bytes = await res.fold<BytesBuilder>(BytesBuilder(copy: false), (b, c) => b..add(c));
      if (res.statusCode == 403) throw const SyncAuthException();
      if (res.statusCode != 200) {
        throw HttpException('Gegenstelle antwortet mit ${res.statusCode}');
      }
      return crypto.open(bytes.takeBytes());
    } finally {
      client.close(force: true);
    }
  }

  /// Mit einem Kopplungs-Code (aus dem QR) koppeln.
  Future<PairedDevice> pair(PairingOffer offer) async {
    final crypto = await SyncCrypto.fromSecret(base64Decode(offer.secret));
    final res = await _post(offer.host, offer.port, '/pair', crypto, 'pairing', {
      'id': await store.deviceId(),
      'name': await store.deviceName(),
    });
    final device = PairedDevice(
      id: res.json['id'] as String,
      name: res.json['name'] as String? ?? offer.name,
      secret: offer.secret,
      host: offer.host,
      port: offer.port,
    );
    await store.upsert(device);
    return device;
  }

  /// Abgleich mit [device]: holen, dann senden – inkl. Dateien.
  Future<SyncReport> syncWith(PairedDevice device) async {
    final report = SyncReport();
    final crypto = await SyncCrypto.fromSecret(device.secretBytes);
    final me = await store.deviceId();
    final root = (await docsDir()).path;
    final startedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const margin = 120; // Sekunden Puffer gegen Uhrabweichung

    // 1. Holen
    final pulled = await _post(device.host, device.port, '/pull', crypto, me,
        {'since': device.lastPulled == 0 ? null : device.lastPulled - margin});
    final imported = await _import(SyncChanges.fromJson(
        pulled.json['changes'] as Map<String, dynamic>));
    report.received = imported.inserted + imported.updated;
    for (final f in imported.neededFiles) {
      final local = safeLocalPath(root, f);
      if (local == null || await File(local).exists()) continue;
      final res = await _post(device.host, device.port, '/file', crypto, me, {'path': f});
      if (res.json['missing'] == true) continue;
      await File(local).parent.create(recursive: true);
      await File(local).writeAsBytes(res.data, flush: true);
      report.filesIn++;
    }

    // 2. Senden
    final out = await SyncEngine(db).exportChanges(
        since: device.lastPushed == 0 ? null : device.lastPushed - margin);
    if (!out.isEmpty) {
      final pushed = await _post(device.host, device.port, '/push', crypto, me,
          {'changes': out.toJson()});
      report.sent = out.rowCount;
      for (final f in (pushed.json['needed'] as List? ?? const [])) {
        final local = safeLocalPath(root, f as String);
        if (local == null || !await File(local).exists()) continue;
        await _post(device.host, device.port, '/upload', crypto, me, {'path': f},
            await File(local).readAsBytes());
        report.filesOut++;
      }
    }

    device
      ..lastPulled = (pulled.json['now'] as num?)?.toInt() ?? startedAt
      ..lastPushed = startedAt
      ..lastSyncAt = DateTime.now().millisecondsSinceEpoch;
    await store.upsert(device);
    return report;
  }
}
