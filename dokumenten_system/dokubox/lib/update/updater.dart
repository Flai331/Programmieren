import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../scan/background_work.dart';

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

/// Aktualisierung über die GitHub-Releases (Handy: APK, PC: ZIP) – auf
/// Wunsch automatisch wie im Play Store: im Hintergrund laden (Handy nur im
/// WLAN), installieren, sobald man die App verlässt (PC: beim nächsten Start).
class Updater {
  static const _repo = 'Flai331/Programmieren';
  static const _ch = MethodChannel('dokubox/update');
  static const _kAuto = 'auto_update';

  static String get _tag => Platform.isWindows ? 'windows-latest' : 'apk-latest';
  static String get _asset => Platform.isWindows ? 'DokuBox-Windows.zip' : 'DokuBox.apk';

  static Future<bool> autoEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kAuto) ?? true;
  static Future<void> setAuto(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_kAuto, on);

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

  static Future<Directory> _dir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'update'));
    await d.create(recursive: true);
    return d;
  }

  static String _name(int build) =>
      Platform.isWindows ? 'DokuBox-$build.zip' : 'DokuBox-$build.apk';

  /// Fertig geladenes, noch nicht installiertes Update (neuer als installiert).
  static Future<File?> ready() async {
    final dir = await _dir();
    File? best;
    var bestBuild = kBuildNumber;
    await for (final e in dir.list()) {
      final m = RegExp(r'DokuBox-(\d+)\.(apk|zip)$').firstMatch(e.path);
      if (e is! File || m == null) continue;
      final b = int.parse(m.group(1)!);
      if (b > bestBuild) {
        best = e;
        bestBuild = b;
      } else {
        await e.delete(); // altes/installiertes Update aufräumen
      }
    }
    return best;
  }

  /// Lädt [info] (falls nicht schon da) und liefert die Datei.
  static Future<File> download(UpdateInfo info, {void Function(double)? progress}) async {
    final dir = await _dir();
    final file = File(p.join(dir.path, _name(info.build)));
    if (await file.exists() && await file.length() == info.size) return file;
    final part = File('${file.path}.part');
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      req.headers.set('User-Agent', 'DokuBox');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('Download: ${res.statusCode}');
      final total = res.contentLength > 0 ? res.contentLength : info.size;
      var got = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) progress?.call(got / total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
    return part.rename(file.path);
  }

  static bool _busy = false;

  /// Automatik: prüfen und im Hintergrund laden. Still bei Fehlern.
  static Future<void> autoFetch() async {
    if (_busy || !await autoEnabled()) return;
    _busy = true;
    try {
      final info = await check();
      if (info == null) return;
      if (!Platform.isWindows &&
          await _ch.invokeMethod<bool>('isMetered') == true) {
        return; // große APK nicht über mobile Daten
      }
      await download(info);
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  /// Automatik: fertiges Update einspielen, wenn gerade nichts läuft.
  /// Handy: beim Verlassen der App; PC: beim Start.
  static Future<bool> autoInstall() async {
    if (_busy || BackgroundWork.active || !await autoEnabled()) return false;
    final file = await ready();
    if (file == null) return false;
    await installFile(file, silent: true);
    return true;
  }

  /// Knopf „Nach Update suchen“: laden und sofort installieren.
  static Future<void> install(UpdateInfo info, void Function(double) progress) async {
    final file = await download(info, progress: progress);
    await installFile(file);
  }

  static Future<void> installFile(File file, {bool silent = false}) async {
    if (Platform.isWindows) {
      await _installWindows(file);
      return;
    }
    final r = await _ch.invokeMethod<String>(
        'installSession', {'path': file.path, 'silent': silent});
    if (r == 'permission') {
      throw const UpdateException(
          'Bitte „Unbekannte Apps installieren“ für DokuBox erlauben und '
          'dann nochmal auf Aktualisieren tippen.');
    }
  }

  /// Entpackt, ersetzt die Programmdateien nach dem Beenden und startet neu.
  static Future<void> _installWindows(File zip) async {
    final dir = await Directory.systemTemp.createTemp('dokubox_update');
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
      'del "${zip.path}"',
      'start "" "$exe"',
    ].join('\r\n'));
    await Process.start('cmd', ['/c', bat.path], mode: ProcessStartMode.detached);
    exit(0);
  }
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}
