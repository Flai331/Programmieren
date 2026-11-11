import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_services.dart';
import '../platform.dart';
import '../sync/pairing.dart';
import '../sync/sync_runner.dart';
import '../sync/sync_service.dart';

final _time = DateFormat('dd.MM.yyyy HH:mm');

/// Geräte koppeln und abgleichen (Handy, Tablet, Laptop) – direkt im WLAN,
/// verschlüsselt, ohne Cloud.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<PairedDevice> _devices = [];
  String _name = '';
  bool _main = true;
  String _tag = 'X';
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await SyncSettings.devices();
    final n = await SyncSettings.deviceName();
    final m = await SyncSettings.isMain();
    final t = await SyncSettings.deviceTag();
    if (mounted) {
      setState(() {
        _devices = d;
        _name = n;
        _main = m;
        _tag = t;
      });
    }
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<String?> _ask(String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _offer() async {
    final host = await SyncService.localAddress();
    if (host == null) {
      _snack('Kein WLAN gefunden.');
      return;
    }
    final offer = await services.sync.startServer(host: host);
    if (!mounted) return;
    final sub = services.sync.newPairings.listen((d) {
      if (mounted) Navigator.of(context).pop();
      _snack('${d.name} gekoppelt');
      _load();
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mit diesem Gerät koppeln'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(data: offer.encode(), size: 220),
          ),
          const SizedBox(height: 8),
          const Text('Auf dem anderen Gerät: Geräte & Abgleich → „Mit Gerät '
              'koppeln“ und diesen Code scannen. Beide im selben WLAN.'),
          const SizedBox(height: 8),
          SelectableText(offer.encode(), style: const TextStyle(fontSize: 10)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
        ],
      ),
    );
    await sub.cancel();
  }

  Future<void> _join() async {
    String? raw;
    if (isMobile) {
      raw = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const _PairScanScreen()));
    } else {
      raw = await _ask('Kopplungs-Code eingeben', '');
    }
    if (raw == null) return;
    final offer = PairingOffer.decode(raw);
    if (offer == null) {
      _snack('Das ist kein DokuBox-Kopplungs-Code.');
      return;
    }
    try {
      final d = await services.sync.pair(offer);
      _snack('Mit ${d.name} gekoppelt – gleiche ab …');
      await _sync(d);
    } catch (e) {
      _snack('Koppeln fehlgeschlagen: $e');
    }
    await _load();
  }

  Future<void> _sync(PairedDevice d) async {
    setState(() => _busy.add(d.id));
    try {
      final r = await runSync(d);
      _snack('${d.name}: $r');
    } catch (e) {
      _snack('${d.name} nicht erreichbar ($e). Gleiches WLAN? App dort geöffnet?');
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Geräte & Abgleich')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Column(children: [
              ListTile(
                leading: Icon(isMobile ? Icons.smartphone : Icons.laptop),
                title: Text(_name),
                subtitle: const Text('Name dieses Geräts'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final n = await _ask('Gerätename', _name);
                  if (n != null && n.trim().isNotEmpty) {
                    await SyncSettings.setDeviceName(n.trim());
                    await _load();
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.format_list_numbered),
                title: const Text('Haupt-Gerät (vergibt die Nummern)'),
                subtitle: Text(_main
                    ? 'Neue Dokumente bekommen hier ihre Nummer; vorläufige '
                        'Nummern anderer Geräte werden beim Abgleich ersetzt.'
                    : 'Neue Dokumente bekommen vorläufig V-${_tag}0001 …, '
                        'die endgültige Nummer vergibt das Haupt-Gerät.'),
                value: _main,
                onChanged: (v) async {
                  await SyncSettings.setMain(v);
                  await _load();
                },
              ),
              if (!_main)
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: Text('Kürzel für vorläufige Nummern: $_tag'),
                  onTap: () async {
                    final t = await _ask('Kürzel (ein Buchstabe)', _tag);
                    if (t != null && t.trim().isNotEmpty) {
                      await SyncSettings.setDeviceTag(t);
                      await _load();
                    }
                  },
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _offer,
                icon: const Icon(Icons.qr_code),
                label: const Text('Bereitstellen (QR)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _join,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Mit Gerät koppeln'),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
              'Typisch: am Laptop „Bereitstellen“, am Handy „Mit Gerät koppeln“. '
              'Abgleich läuft direkt im WLAN, verschlüsselt, ohne Cloud.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final d in _devices)
            Card(
              child: ListTile(
                leading: const Icon(Icons.devices),
                title: Text(d.name),
                subtitle: Text(d.lastSyncAt == null
                    ? 'noch nicht abgeglichen · ${d.host}'
                    : 'zuletzt ${_time.format(DateTime.fromMillisecondsSinceEpoch(d.lastSyncAt!))} · ${d.host}'),
                trailing: _busy.contains(d.id)
                    ? const SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'sync') await _sync(d);
                          if (v == 'remove') {
                            await SyncSettings.remove(d.id);
                            await _load();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'sync', child: Text('Jetzt abgleichen')),
                          PopupMenuItem(value: 'remove', child: Text('Kopplung entfernen')),
                        ],
                      ),
                onTap: () => _sync(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _PairScanScreen extends StatefulWidget {
  const _PairScanScreen();
  @override
  State<_PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends State<_PairScanScreen> {
  final _c = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kopplungs-Code scannen')),
        body: MobileScanner(
          controller: _c,
          onDetect: (cap) {
            if (_done) return;
            for (final b in cap.barcodes) {
              final v = b.rawValue;
              if (v != null && v.startsWith('dokubox-pair:')) {
                _done = true;
                Navigator.of(context).pop(v);
                return;
              }
            }
          },
        ),
      );
}
