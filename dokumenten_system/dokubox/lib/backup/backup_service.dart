import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../scan/scan_service.dart';

/// Verschlüsseltes Backup: eine ZIP (Datenbank + alle PDFs), verschlüsselt
/// mit AES-GCM, Schlüssel per PBKDF2 aus dem Nutzer-Passwort.
///
/// Dateiformat: MAGIC(8) | salt(16) | nonce(12) | ciphertext | mac(16)
class BackupService {
  static const _magic = 'DOKUBOX1';
  static const _iterations = 150000;

  final AppDatabase db;

  BackupService(this.db);

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Erstellt die verschlüsselte Backup-Datei und liefert ihren Pfad.
  Future<File> createBackup(String password) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();

    // Konsistente DB-Kopie trotz geöffneter Verbindung.
    final dbCopy = File(p.join(tempDir.path, 'dokubox.sqlite'));
    if (await dbCopy.exists()) await dbCopy.delete();
    await db.customStatement('VACUUM INTO ?', [dbCopy.path]);

    final archive = Archive();
    archive.addFile(ArchiveFile(
      'dokubox.sqlite',
      await dbCopy.length(),
      await dbCopy.readAsBytes(),
    ));
    final pdfDir = Directory(p.join(docsDir.path, ScanService.pdfDirName));
    if (await pdfDir.exists()) {
      await for (final entity in pdfDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(
            p.join(ScanService.pdfDirName, p.basename(entity.path)),
            bytes.length,
            bytes,
          ));
        }
      }
    }
    final zipBytes = ZipEncoder().encode(archive);
    await dbCopy.delete();

    final algorithm = AesGcm.with256bits();
    final saltBytes = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(password, saltBytes);
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(
      zipBytes,
      secretKey: key,
      nonce: nonce,
    );

    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final out = File(p.join(tempDir.path, 'dokubox-backup-$stamp.dokubak'));
    final builder = BytesBuilder()
      ..add(utf8.encode(_magic))
      ..add(saltBytes)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    await out.writeAsBytes(builder.toBytes());
    return out;
  }

  /// Entschlüsselt [backupFile] und entpackt es in ein Temp-Verzeichnis.
  /// Wirft [BackupException] bei falschem Passwort oder ungültiger Datei.
  Future<Directory> restoreToTemp(File backupFile, String password) async {
    final raw = await backupFile.readAsBytes();
    if (raw.length < 8 + 16 + 12 + 16 ||
        utf8.decode(raw.sublist(0, 8)) != _magic) {
      throw const BackupException('Keine gültige DokuBox-Backup-Datei.');
    }
    final saltBytes = raw.sublist(8, 24);
    final nonce = raw.sublist(24, 36);
    final cipherText = raw.sublist(36, raw.length - 16);
    final mac = Mac(raw.sublist(raw.length - 16));

    final algorithm = AesGcm.with256bits();
    final key = await _deriveKey(password, saltBytes);
    final List<int> zipBytes;
    try {
      zipBytes = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupException('Falsches Passwort.');
    }

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final tempDir = await getTemporaryDirectory();
    final target = Directory(
        p.join(tempDir.path, 'restore-${DateTime.now().millisecondsSinceEpoch}'));
    await target.create(recursive: true);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final file = File(p.join(target.path, entry.name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content as List<int>);
    }
    if (!await File(p.join(target.path, 'dokubox.sqlite')).exists()) {
      throw const BackupException('Backup enthält keine Datenbank.');
    }
    return target;
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}
