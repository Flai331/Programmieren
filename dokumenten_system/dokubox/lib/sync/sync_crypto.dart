import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Verschlüsselte Nachrichten zwischen gekoppelten Geräten (AES-GCM mit
/// einem aus dem Kopplungs-Geheimnis abgeleiteten Schlüssel). Jede
/// Nachricht trägt einen Zeitstempel gegen Wiederholung.
class SyncCrypto {
  static const maxSkew = Duration(minutes: 10);
  final SecretKey _key;
  SyncCrypto._(this._key);

  static Future<SyncCrypto> fromSecret(List<int> secret) async {
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(secret),
      nonce: utf8.encode('dokubox-sync'),
      info: utf8.encode('v1'),
    );
    return SyncCrypto._(key);
  }

  static List<int> newSecret() => SecretKeyData.random(length: 32).bytes;

  /// [json] + optionale Rohdaten → nonce(12) | ciphertext | mac(16).
  Future<Uint8List> seal(Map<String, Object?> json, [List<int>? data]) async {
    final header = utf8.encode(jsonEncode({
      ...json,
      '_ts': DateTime.now().millisecondsSinceEpoch,
    }));
    final plain = BytesBuilder(copy: false)
      ..add((ByteData(4)..setUint32(0, header.length)).buffer.asUint8List())
      ..add(header)
      ..add(data ?? const []);
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(plain.toBytes(), secretKey: _key);
    return (BytesBuilder(copy: false)
          ..add(box.nonce)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .toBytes();
  }

  /// Entschlüsseln und prüfen. Wirft [SyncAuthException] bei falschem
  /// Schlüssel, Manipulation oder zu altem Zeitstempel.
  Future<({Map<String, dynamic> json, Uint8List data})> open(
      List<int> sealed) async {
    if (sealed.length < 12 + 16 + 4) throw const SyncAuthException();
    final aes = AesGcm.with256bits();
    final List<int> plain;
    try {
      plain = await aes.decrypt(
        SecretBox(
          sealed.sublist(12, sealed.length - 16),
          nonce: sealed.sublist(0, 12),
          mac: Mac(sealed.sublist(sealed.length - 16)),
        ),
        secretKey: _key,
      );
    } on SecretBoxAuthenticationError {
      throw const SyncAuthException();
    }
    final bytes = Uint8List.fromList(plain);
    final len = ByteData.sublistView(bytes, 0, 4).getUint32(0);
    final json = jsonDecode(utf8.decode(bytes.sublist(4, 4 + len)))
        as Map<String, dynamic>;
    final ts = json['_ts'];
    if (ts is! int ||
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(ts))
                .abs() >
            maxSkew) {
      throw const SyncAuthException('Uhrzeit der Geräte weicht zu stark ab.');
    }
    return (json: json, data: bytes.sublist(4 + len));
  }
}

class SyncAuthException implements Exception {
  final String message;
  const SyncAuthException([this.message = 'Gerät nicht gekoppelt oder Nachricht ungültig.']);
  @override
  String toString() => message;
}
