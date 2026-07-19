import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../backup/backup_service.dart';
import '../lock/lock_gate.dart';
import '../scan/scan_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lockEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppLockSettings.isEnabled().then((value) {
      if (mounted) setState(() => _lockEnabled = value);
    });
  }

  Future<String?> _askPassword({required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Passwort',
            helperText: 'Ohne dieses Passwort ist das Backup unlesbar!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportBackup() async {
    final password = await _askPassword(title: 'Backup verschlüsseln');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final file = await services.backup.createBackup(password);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'DokuBox-Backup',
      ));
      // Temp-Datei nach dem Teilen aufräumen.
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      _snack('Backup fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return;
    final password = await _askPassword(title: 'Backup-Passwort eingeben');
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final restored =
          await services.backup.restoreToTemp(File(path), password);

      // Wiederhergestellte Daten an Ort und Stelle kopieren; die neue
      // Datenbank wird beim nächsten App-Start geladen.
      final docsDir = await getApplicationDocumentsDirectory();
      final pdfSource =
          Directory(p.join(restored.path, ScanService.pdfDirName));
      if (await pdfSource.exists()) {
        final pdfTarget = await ScanService.pdfDirectory();
        await for (final entity in pdfSource.list()) {
          if (entity is File) {
            await entity
                .copy(p.join(pdfTarget.path, p.basename(entity.path)));
          }
        }
      }
      final dbTarget = File(p.join(docsDir.path, 'dokubox_restore.sqlite'));
      await File(p.join(restored.path, 'dokubox.sqlite')).copy(dbTarget.path);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup bereit'),
            content: const Text(
                'Die Daten wurden entpackt. Bitte schließe die App vollständig '
                'und öffne sie neu, um die Wiederherstellung abzuschließen.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Wiederherstellung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('App-Sperre'),
            subtitle: const Text(
                'Beim Öffnen mit Fingerabdruck/Gesicht oder Geräte-PIN '
                'entsperren'),
            value: _lockEnabled,
            onChanged: (value) async {
              await AppLockSettings.setEnabled(value);
              setState(() => _lockEnabled = value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup erstellen'),
            subtitle: const Text(
                'Alle Dokumente + Datenbank als verschlüsselte Datei '
                'exportieren'),
            enabled: !_busy,
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Backup wiederherstellen'),
            subtitle: const Text('Eine .dokubak-Datei einspielen'),
            enabled: !_busy,
            onTap: _importBackup,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('DokuBox'),
            subtitle: Text(
                'Alle Daten bleiben auf diesem Gerät. Keine Cloud, kein '
                'Konto, keine Kosten.\nVersion 0.1.0'),
          ),
        ],
      ),
    );
  }
}
