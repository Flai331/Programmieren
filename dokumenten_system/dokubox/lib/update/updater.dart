import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Eigene Build-Nummer (vom GitHub-Build per --dart-define gesetzt; lokal 0).
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER');

class UpdateInfo {
  final int build;
  final String url;
  final int size;
  const UpdateInfo(this.build, this.url, this.size);
}

/// Liest „Build N“ aus dem Release-Text.
int? parseBuild(String? body) {
  final m = RegExp(r'Build\s+(\d+)').firstMatch(body ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}

/// Aktualisierung über die GitHub-Releases (Handy: APK, PC: ZIP).
class Updater {
  static const _repo = 'Flai331/Programmieren';
  static const _ch = MethodChannel('dokubox/update');

  static String get _tag => Platform.isWindows ? 'windows-latest' : 'apk-latest';
  static String get _asset => Platform.isWindows ? 'DokuBox-Windows.zip' : 'DokuBox.apk';

  /// Neuere Version vorhanden? `null` = aktuell.
  static Future<UpdateInfo?> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$_repo/releases/tags/$_tag'));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'DokuBox');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('GitHub: ${res.statusCode}');
      final json = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      final build = parseBuild(json['body'] as String?);
      final asset = (json['assets'] as List)
          .cast<Map>()
          .where((a) => a['name'] == _asset)
          .firstOrNull;
      if (build == null || asset == null || build <= kBuildNumber) return null;
      return UpdateInfo(build, asset['browser_download_url'] as String,
          (asset['size'] as num).toInt());
    } finally {
      client.close();
    }
  }

  /// Lädt herunter (Fortschritt 0…1) und startet die Installation.
  static Future<void> install(UpdateInfo info, void Function(double) progress) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'update'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, _asset));
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      req.headers.set('User-Agent', 'DokuBox');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('Download: ${res.statusCode}');
      final total = res.contentLength > 0 ? res.contentLength : info.size;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress(got / total);
      }
      await sink.close();
    } finally {
      client.close();
    }
    if (Platform.isWindows) {
      await _installWindows(file, dir);
    } else {
      final r = await _ch.invokeMethod<String>('install', {'path': file.path});
      if (r == 'permission') {
        throw const UpdateException(
            'Bitte „Unbekannte Apps installieren“ für DokuBox erlauben und '
            'dann nochmal auf Aktualisieren tippen.');
      }
    }
  }

  /// Entpackt, ersetzt die Programmdateien nach dem Beenden und startet neu.
  static Future<void> _installWindows(File zip, Directory dir) async {
    final out = Directory(p.join(dir.path, 'neu'));
    await extractFileToDisk(zip.path, out.path);
    final appDir = p.dirname(Platform.resolvedExecutable);
    final exe = Platform.resolvedExecutable;
    final bat = File(p.join(dir.path, 'update.bat'));
    await bat.writeAsString([
      '@echo off',
      ':warte',
      'tasklist /FI "PID eq $pid" | find "$pid" >nul',
      'if not errorlevel 1 (timeout /t 1 /nobreak >nul & goto warte)',
      'robocopy "${out.path}" "$appDir" /E /NFL /NDL /NJH /NJS >nul',
      'start "" "$exe"',
    ].join('\r\n'));
    await Process.start('cmd', ['/c', bat.path],
        mode: ProcessStartMode.detached);
    exit(0);
  }
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}
