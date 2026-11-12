import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Automatisches, verschlüsseltes Backup am PC: in einen Ordner auf dem
/// Laptop und auf USB-Stick/externe Platte. Ziele, die gerade nicht da sind
/// (Stick nicht eingesteckt), werden beim nächsten Mal nachgeholt.
class AutoBackupConfig {
  final bool enabled;
  final String password;
  final List<String> targets;
  final int intervalDays;
  final int keep;
  const AutoBackupConfig({
    this.enabled = false,
    this.password = '',
    this.targets = const [],
    this.intervalDays = 1,
    this.keep = 5,
  });

  AutoBackupConfig copyWith(
          {bool? enabled, String? password, List<String>? targets, int? intervalDays}) =>
      AutoBackupConfig(
        enabled: enabled ?? this.enabled,
        password: password ?? this.password,
        targets: targets ?? this.targets,
        intervalDays: intervalDays ?? this.intervalDays,
        keep: keep,
      );
}

class AutoBackupResult {
  final List<String> written;
  final List<String> missing;
  const AutoBackupResult(this.written, this.missing);
}

class AutoBackup {
  static const _kEnabled = 'autobackup_enabled';
  // Das Passwort liegt nur auf diesem Gerät (Wunsch: Schlüssel am Gerät).
  static const _kPassword = 'autobackup_password';
  static const _kTargets = 'autobackup_targets';
  static const _kInterval = 'autobackup_interval';
  static const _kLastPrefix = 'autobackup_last:';

  final Future<File> Function(String password) create;
  final DateTime Function() now;
  AutoBackup(this.create, {DateTime Function()? now}) : now = now ?? DateTime.now;

  static Future<AutoBackupConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    return AutoBackupConfig(
      enabled: sp.getBool(_kEnabled) ?? false,
      password: sp.getString(_kPassword) ?? '',
      targets: sp.getStringList(_kTargets) ?? const [],
      intervalDays: sp.getInt(_kInterval) ?? 1,
    );
  }

  static Future<void> save(AutoBackupConfig c) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabled, c.enabled);
    await sp.setString(_kPassword, c.password);
    await sp.setStringList(_kTargets, c.targets);
    await sp.setInt(_kInterval, c.intervalDays);
  }

  static Future<DateTime?> lastBackup(String target) async {
    final v = (await SharedPreferences.getInstance()).getString('$_kLastPrefix$target');
    return v == null ? null : DateTime.tryParse(v);
  }

  /// Ziel erreichbar? Der Ordner wird angelegt, wenn sein Laufwerk da ist.
  static Future<bool> available(String target) async {
    final dir = Directory(target);
    if (await dir.exists()) return true;
    final root = p.rootPrefix(target);
    if (root.isEmpty || !await Directory(root).exists()) return false;
    try {
      await dir.create(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Schreibt ein Backup in jedes fällige, erreichbare Ziel.
  static bool _running = false;

  Future<AutoBackupResult> runIfDue({bool force = false}) async {
    if (_running) return const AutoBackupResult([], []);
    _running = true;
    try {
      return await _run(force);
    } finally {
      _running = false;
    }
  }

  Future<AutoBackupResult> _run(bool force) async {
    final c = await load();
    if (!c.enabled || c.password.isEmpty || c.targets.isEmpty) {
      return const AutoBackupResult([], []);
    }
    final due = <String>[];
    final missing = <String>[];
    for (final t in c.targets) {
      final last = await lastBackup(t);
      final isDue = force ||
          last == null ||
          now().difference(last) >= Duration(days: c.intervalDays) - const Duration(hours: 1);
      if (!isDue) continue;
      if (await available(t)) {
        due.add(t);
      } else {
        missing.add(t);
      }
    }
    if (due.isEmpty) return AutoBackupResult(const [], missing);
    final file = await create(c.password);
    final sp = await SharedPreferences.getInstance();
    final stamp = now().toIso8601String().substring(0, 16).replaceAll(':', '-');
    final written = <String>[];
    try {
      for (final t in due) {
        try {
          final name = 'dokubox-backup-$stamp.dokubak';
          final tmp = File(p.join(t, '$name.part'));
          await file.copy(tmp.path);
          await tmp.rename(p.join(t, name));
          await rotate(Directory(t), c.keep);
          await sp.setString('$_kLastPrefix$t', now().toIso8601String());
          written.add(t);
        } catch (_) {
          missing.add(t);
        }
      }
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
    return AutoBackupResult(written, missing);
  }

  /// Behält nur die [keep] neuesten Backups im Ordner.
  static Future<void> rotate(Directory dir, int keep) async {
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File &&
          p.basename(e.path).startsWith('dokubox-backup-') &&
          e.path.endsWith('.dokubak')) {
        files.add(e);
      }
    }
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final f in files.skip(keep)) {
      await f.delete();
    }
  }

  /// Hinweis, wenn ein Ziel (z. B. USB-Stick) lange kein Backup bekam.
  static Future<String?> reminder({DateTime? at, int days = 14}) async {
    final c = await load();
    if (!c.enabled) return null;
    final t0 = at ?? DateTime.now();
    for (final t in c.targets) {
      final last = await lastBackup(t);
      if (last == null || t0.difference(last).inDays >= days) {
        return 'Backup nach „$t“ ist ${last == null ? 'noch nie' : 'seit ${t0.difference(last).inDays} Tagen nicht'} '
            'gelaufen – Laufwerk anschließen.';
      }
    }
    return null;
  }
}

/// Windows-Autostart (Registry-Eintrag „Run“ des Benutzers).
class WindowsAutostart {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'DokuBox';

  static Future<bool> isOn() async {
    if (!Platform.isWindows) return false;
    final r = await Process.run('reg', ['query', _key, '/v', _name]);
    return r.exitCode == 0;
  }

  static Future<void> set(bool on) async {
    if (!Platform.isWindows) return;
    if (on) {
      await Process.run('reg', [
        'add', _key, '/v', _name, '/t', 'REG_SZ', '/f', //
        '/d', '"${Platform.resolvedExecutable}" --minimized',
      ]);
    } else {
      await Process.run('reg', ['delete', _key, '/v', _name, '/f']);
    }
  }
}
