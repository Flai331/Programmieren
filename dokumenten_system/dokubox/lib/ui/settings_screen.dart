import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai_extraction_service.dart';
import '../app_services.dart';
import '../backup/backup_service.dart';
import '../data/finance.dart';
import '../lock/lock_gate.dart';
import '../scan/blank_pages.dart';
import '../data/setup_mode.dart';
import 'firms_screen.dart';
import 'templates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lockEnabled = false;
  BlankMode _blankMode = BlankMode.splitAndDelete;
  BlankSensitivity _blankSensitivity = BlankSensitivity.normal;
  bool _busy = false;
  bool _aiInstalled = false;
  bool _aiEnabled = false;
  int? _aiDownloadProgress;
  FinanceSettings _finance = const FinanceSettings();

  @override
  void initState() {
    super.initState();
    FinanceSettings.load().then((value) {
      if (mounted) setState(() => _finance = value);
    });
    AppLockSettings.isEnabled().then((value) {
      if (mounted) setState(() => _lockEnabled = value);
    });
    BlankPageSettings.mode().then((value) {
      if (mounted) setState(() => _blankMode = value);
    });
    BlankPageSettings.sensitivity().then((value) {
      if (mounted) setState(() => _blankSensitivity = value);
    });
    _refreshAiState();
  }

  Future<void> _refreshAiState() async {
    final installed = await services.ai.isInstalled();
    final enabled = await services.ai.isEnabled();
    if (mounted) {
      setState(() {
        _aiInstalled = installed;
        _aiEnabled = enabled;
      });
    }
  }

  Future<void> _downloadAiModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KI-Modell herunterladen?'),
        content: const Text(
            'Das Sprachmodell (Qwen3, ${AiExtractionService.modelSizeLabel}) '
            'wird einmalig heruntergeladen und läuft danach komplett offline '
            'auf diesem Gerät. Am besten im WLAN laden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Herunterladen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _aiDownloadProgress = 0);
    try {
      await services.ai.download(onProgress: (p) {
        if (mounted) setState(() => _aiDownloadProgress = p);
      });
      _snack('KI-Modell installiert – Auslesen läuft ab jetzt mit KI.');
    } catch (e) {
      _snack('Download fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _aiDownloadProgress = null);
      await _refreshAiState();
    }
  }

  Future<void> _deleteAiModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KI-Modell löschen?'),
        content: const Text(
            'Gibt den Speicherplatz wieder frei. Die Vorschläge kommen dann '
            'wieder nur aus den lokalen Regeln.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await services.ai.delete();
      await _refreshAiState();
    }
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
    // Teilen öffnet ein System-Sheet → App pausiert; Sperre kurz unterdrücken.
    LockController.suppressAutoLock = true;
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
      LockController.suppressAutoLock = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    // Datei-Auswahl ist eine eigene Activity → Sperre kurz unterdrücken.
    LockController.suppressAutoLock = true;
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles();
    } finally {
      LockController.suppressAutoLock = false;
    }
    final path = picked?.files.single.path;
    if (path == null) return;
    final password = await _askPassword(title: 'Backup-Passwort eingeben');
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final restored =
          await services.backup.restoreToTemp(File(path), password);

      await services.backup.applyRestore(restored);

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

  Future<void> _updateFinance(FinanceSettings value) async {
    setState(() => _finance = value);
    await value.save();
  }

  List<Widget> _financeSettings() => [
        const ListTile(
          leading: Icon(Icons.payments_outlined),
          title: Text('Rechnungen & Erstattung'),
          subtitle: Text(
              'Rechnungen werden beim Scannen erkannt: Betrag, Fälligkeit, '
              'bezahlt/zu bezahlen/Lastschrift. Arzt- und Apothekenrechnungen '
              'werden zum Einreichen vorgemerkt.'),
        ),
        ListTile(
          leading: const SizedBox(width: 24),
          title: const Text('Zahlungserinnerung'),
          subtitle: const Text('Wie früh vor der Fälligkeit erinnern?'),
          trailing: DropdownButton<int>(
            value: _finance.leadDays,
            onChanged: (v) {
              if (v != null) _updateFinance(_finance.copyWith(leadDays: v));
            },
            items: [
              for (final d in const [0, 1, 2, 3, 5, 7, 14])
                DropdownMenuItem(
                    value: d,
                    child: Text(d == 0 ? 'am Fälligkeitstag' : '$d Tage vorher')),
            ],
          ),
        ),
        ListTile(
          leading: const SizedBox(width: 24),
          title: const Text('Erstattung nachfassen'),
          subtitle: const Text('Erinnern, wenn nach dem Einreichen nichts kam'),
          trailing: DropdownButton<int>(
            value: _finance.followUpWeeks,
            onChanged: (v) {
              if (v != null) {
                _updateFinance(_finance.copyWith(followUpWeeks: v));
              }
            },
            items: [
              for (final w in const [2, 4, 6, 8, 12])
                DropdownMenuItem(value: w, child: Text('nach $w Wochen')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 4, 16, 0),
          child: Text('Arztrechnungen einreichen bei:',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final target in kClaimTargets)
                FilterChip(
                  label: Text(target),
                  selected: _finance.claimTargets.contains(target),
                  onSelected: (selected) => _updateFinance(_finance.copyWith(
                    claimTargets: selected
                        ? [..._finance.claimTargets, target]
                        : _finance.claimTargets
                            .where((t) => t != target)
                            .toList(),
                  )),
                ),
            ],
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          FutureBuilder<bool>(
            future: SetupMode.isOn(),
            builder: (context, snap) => SwitchListTile(
              secondary: const Icon(Icons.playlist_add_check),
              title: const Text('Ersterfassung'),
              subtitle: const Text(
                  'Alle vorhandenen Dokumente erst einscannen (vorläufige '
                  'Nummern V-0001 …), am Ende auf dem Startbildschirm '
                  '„Nummern vergeben“ – nach Datum sortiert.'),
              value: snap.data ?? false,
              onChanged: (v) async {
                await SetupMode.set(v);
                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Firmen & Kategorien'),
            subtitle: const Text(
                'Firmen anlegen, Kategorien vergeben – danach in der Liste '
                'nach Kategorie filtern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FirmsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.draw),
            title: const Text('Unterschriften & Vorlagen'),
            subtitle: const Text(
                'Am PC gezeichnet, per WLAN übertragen – zum Ausfüllen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TemplatesScreen()),
            ),
          ),
          const Divider(),
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
            leading: const Icon(Icons.content_cut),
            title: const Text('Leere Seiten beim Scannen'),
            subtitle: Text(_blankMode.description),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: BlankModeSelector(
              value: _blankMode,
              onChanged: (value) async {
                await BlankPageSettings.setMode(value);
                setState(() => _blankMode = value);
              },
            ),
          ),
          if (_blankMode.detect)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Empfindlichkeit'),
              subtitle: const Text(
                  'Vorsichtig: nur ganz weiße Blätter · Großzügig: auch '
                  'Blätter mit Staub oder Flecken'),
              trailing: DropdownButton<BlankSensitivity>(
                value: _blankSensitivity,
                onChanged: (value) async {
                  if (value == null) return;
                  await BlankPageSettings.setSensitivity(value);
                  setState(() => _blankSensitivity = value);
                },
                items: [
                  for (final s in BlankSensitivity.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ),
          const Divider(),
          ..._financeSettings(),
          const Divider(),
          if (!_aiInstalled)
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('KI-Auslesen aktivieren'),
              subtitle: Text(_aiDownloadProgress == null
                  ? 'Lokales Sprachmodell '
                      '(${AiExtractionService.modelSizeLabel}) einmalig laden — '
                      'liest Absender, Datum, Typ und Titel. Läuft offline, '
                      'nichts verlässt das Gerät.'
                  : 'Wird geladen … $_aiDownloadProgress %'),
              enabled: _aiDownloadProgress == null && !_busy,
              onTap: _downloadAiModel,
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('KI-Auslesen'),
              subtitle: const Text(
                  'Füllt nach dem Scan Absender, Datum, Typ und Titel per '
                  'lokalem KI-Modell vor'),
              value: _aiEnabled,
              onChanged: (value) async {
                await services.ai.setEnabled(value);
                await _refreshAiState();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('KI-Modell löschen'),
              subtitle:
                  const Text('Speicherplatz freigeben (Regeln bleiben aktiv)'),
              onTap: _deleteAiModel,
            ),
          ],
          if (_aiDownloadProgress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(value: _aiDownloadProgress! / 100),
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

/// Auswahl Trennen & löschen / Nur löschen / Aus – in den Einstellungen und
/// direkt vor dem Scannen.
class BlankModeSelector extends StatelessWidget {
  final BlankMode value;
  final ValueChanged<BlankMode> onChanged;
  const BlankModeSelector(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BlankMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
            value: BlankMode.splitAndDelete,
            icon: Icon(Icons.content_cut),
            label: Text('Trennen & löschen')),
        ButtonSegment(
            value: BlankMode.deleteOnly,
            icon: Icon(Icons.delete_sweep_outlined),
            label: Text('Nur löschen')),
        ButtonSegment(
            value: BlankMode.off,
            icon: Icon(Icons.block),
            label: Text('Aus')),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}
