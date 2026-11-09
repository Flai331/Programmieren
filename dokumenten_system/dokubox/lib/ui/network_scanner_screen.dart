import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_services.dart';
import '../scan/escl_client.dart';
import '../scan/escl_discovery.dart';

/// Ergebnis eines Netzwerk-Scans: Seitenbilder (JPEG) in Scan-Reihenfolge.
class NetworkScanResult {
  final List<String> imagePaths;

  /// Doppelseitig gescannt → Seiten sind Vorder-/Rückseiten-Paare.
  final bool duplex;
  const NetworkScanResult(this.imagePaths, {required this.duplex});
}

/// Scanner im WLAN (Epson, Canon, HP, Brother … mit eSCL/AirScan/Mopria)
/// direkt vom Handy bedienen.
class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  final _found = <EsclScanner>[];
  EsclScanner? _scanner;
  EsclCapabilities? _caps;
  EsclStatus? _status;
  EsclScanSettings _settings = const EsclScanSettings();
  bool _searching = false;
  bool _connecting = false;
  bool _scanning = false;
  bool _cancel = false;
  int _pages = 0;
  String? _error;
  StreamSubscription<EsclScanner>? _search;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await ScannerPrefs.settings();
    final last = await ScannerPrefs.lastScanner();
    if (!mounted) return;
    setState(() => _settings = settings);
    if (last != null) await _select(last);
    _startSearch();
  }

  @override
  void dispose() {
    _search?.cancel();
    super.dispose();
  }

  void _startSearch() {
    _search?.cancel();
    setState(() => _searching = true);
    _search = EsclDiscovery.search().listen(
      (s) {
        if (!mounted) return;
        setState(() {
          if (!_found.any((f) => f.key == s.key)) _found.add(s);
        });
        // Erster Fund wird automatisch gewählt, wenn noch keiner verbunden ist.
        if (_caps == null && !_connecting) _select(s);
      },
      onError: (_) {},
      onDone: () {
        if (mounted) setState(() => _searching = false);
      },
    );
  }

  Future<void> _select(EsclScanner scanner) async {
    setState(() {
      _scanner = scanner;
      _caps = null;
      _status = null;
      _error = null;
      _connecting = true;
    });
    final client = EsclClient(scanner);
    try {
      final caps = await client.capabilities();
      final status = await client.status();
      await ScannerPrefs.saveScanner(scanner);
      if (!mounted || _scanner?.key != scanner.key) return;
      setState(() {
        _caps = caps;
        _status = status;
        _settings = EsclScanSettings(
          feeder: caps.hasFeeder && (_settings.feeder || !caps.hasPlaten),
          duplex: caps.hasDuplex && _settings.duplex,
          color: _settings.color,
          resolution: caps.resolutionNear(_settings.resolution),
        );
      });
    } on EsclException catch (e) {
      if (mounted && _scanner?.key == scanner.key) {
        setState(() => _error = e.message);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _enterAddress() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scanner-Adresse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Die IP-Adresse steht am Gerät im Netzwerk-/WLAN-Menü '
              '(oder auf dem Netzwerk-Statusblatt), z. B. 192.168.178.40.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: '192.168.…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Verbinden'),
          ),
        ],
      ),
    );
    final input = text?.trim();
    if (input == null || input.isEmpty) return;
    final scanner = _scannerFromInput(input);
    if (scanner == null) {
      setState(() => _error = 'Adresse nicht erkannt.');
      return;
    }
    await _select(scanner);
  }

  /// „192.168.1.5“, „192.168.1.5:8080“ oder eine komplette eSCL-URL.
  static EsclScanner? _scannerFromInput(String input) {
    if (input.startsWith('http')) {
      final uri = Uri.tryParse(input);
      if (uri == null || uri.host.isEmpty) return null;
      final path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
      return EsclScanner.fromAddress(uri.host,
          port: uri.hasPort ? uri.port : null,
          https: uri.scheme == 'https',
          path: path.isEmpty ? 'eSCL' : path);
    }
    final m = RegExp(r'^([\w.\-]+)(?::(\d+))?$').firstMatch(input);
    if (m == null) return null;
    return EsclScanner.fromAddress(m[1]!,
        port: m[2] == null ? null : int.parse(m[2]!));
  }

  Future<void> _scan() async {
    final scanner = _scanner;
    final caps = _caps;
    if (scanner == null || caps == null || _scanning) return;
    await ScannerPrefs.saveSettings(_settings);
    setState(() {
      _scanning = true;
      _cancel = false;
      _pages = 0;
      _error = null;
    });
    final client = EsclClient(scanner);
    try {
      final pages = await client.scan(
        _settings,
        caps,
        onPage: (n) {
          if (mounted) setState(() => _pages = n);
        },
        cancelled: () => _cancel,
      );
      final paths = await _savePages(pages);
      if (!mounted) return;
      final duplex =
          _settings.duplex && caps.hasDuplex && (_settings.feeder || !caps.hasPlaten);
      Navigator.of(context).pop(NetworkScanResult(paths, duplex: duplex));
    } on EsclException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      client.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Seiten als Bilddateien ablegen. Liefert der Scanner PDF statt JPEG,
  /// werden dessen Seiten gerendert.
  Future<List<String>> _savePages(List<EsclPage> pages) async {
    final dir = Directory(p.join(
        (await getTemporaryDirectory()).path, 'escl_${DateTime.now().millisecondsSinceEpoch}'));
    await dir.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (!page.isPdf) {
        final f = File(p.join(dir.path, 'seite_${i.toString().padLeft(3, '0')}.jpg'));
        await f.writeAsBytes(page.bytes, flush: true);
        paths.add(f.path);
        continue;
      }
      final pdf = File(p.join(dir.path, 'teil_$i.pdf'));
      await pdf.writeAsBytes(page.bytes, flush: true);
      final rendered = await services.fill.renderBackgrounds(pdf.path);
      for (var j = 0; j < rendered.length; j++) {
        final f = File(p.join(dir.path, 'seite_${i}_$j.jpg'));
        await f.writeAsBytes(rendered[j].image, flush: true);
        paths.add(f.path);
      }
      await pdf.delete();
    }
    return paths;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = _caps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner (WLAN)'),
        actions: [
          IconButton(
            tooltip: 'Erneut suchen',
            icon: const Icon(Icons.refresh),
            onPressed: _searching || _scanning ? null : _startSearch,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Scanner', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final s in _found)
            ListTile(
              selected: s.key == _scanner?.key,
              onTap: _scanning ? null : () => _select(s),
              leading: const Icon(Icons.print),
              title: Text(s.name),
              subtitle: Text(s.base.host),
              trailing: s.key == _scanner?.key
                  ? const Icon(Icons.check_circle)
                  : null,
            ),
          if (_scanner != null && !_found.any((f) => f.key == _scanner!.key))
            ListTile(
              selected: true,
              leading: const Icon(Icons.print),
              title: Text(caps?.makeAndModel.isNotEmpty == true
                  ? caps!.makeAndModel
                  : _scanner!.name),
              subtitle: Text('${_scanner!.base.host} · zuletzt benutzt'),
              trailing: const Icon(Icons.check_circle),
            ),
          ListTile(
            leading: _searching
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            title: Text(_searching
                ? 'Suche im WLAN …'
                : _found.isEmpty
                    ? 'Kein Scanner automatisch gefunden'
                    : '${_found.length} gefunden'),
            subtitle: const Text('Nicht dabei? IP-Adresse eingeben'),
            trailing: const Icon(Icons.keyboard),
            onTap: _scanning ? null : _enterAddress,
          ),
          const Divider(),
          if (_connecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),
          if (caps != null) ...[
            if (caps.makeAndModel.isNotEmpty)
              Text(caps.makeAndModel, style: theme.textTheme.titleMedium),
            if (_status != null)
              Text(_statusText(_status!), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (caps.hasFeeder && caps.hasPlaten)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.move_to_inbox),
                      label: Text('Einzug')),
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.crop_portrait),
                      label: Text('Glas')),
                ],
                selected: {_settings.feeder},
                onSelectionChanged: _scanning
                    ? null
                    : (v) => setState(() => _settings = _copy(feeder: v.first)),
              ),
            if (caps.hasDuplex && _settings.feeder)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Doppelseitig'),
                subtitle: const Text(
                    'Ein- und doppelseitige Blätter mischbar: leere Rückseiten '
                    'werden gelöscht, nur ein ganz leeres Blatt trennt Dokumente.'),
                value: _settings.duplex,
                onChanged: _scanning
                    ? null
                    : (v) => setState(() => _settings = _copy(duplex: v)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Farbe'),
              subtitle: const Text('Aus = Graustufen (kleinere Dateien)'),
              value: _settings.color,
              onChanged: _scanning
                  ? null
                  : (v) => setState(() => _settings = _copy(color: v)),
            ),
            if (caps.resolutions.length > 1)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auflösung'),
                trailing: DropdownButton<int>(
                  value: _settings.resolution,
                  items: [
                    for (final r in caps.resolutions.where((r) => r >= 150 && r <= 600))
                      DropdownMenuItem(value: r, child: Text('$r dpi')),
                  ],
                  onChanged: _scanning
                      ? null
                      : (v) => setState(() => _settings = _copy(resolution: v)),
                ),
              ),
            const SizedBox(height: 16),
            if (_scanning) ...[
              LinearProgressIndicator(
                  value: null, semanticsLabel: 'Scanne'),
              const SizedBox(height: 8),
              Text(_pages == 0
                  ? 'Scanner startet …'
                  : '$_pages Seite${_pages == 1 ? '' : 'n'} empfangen …'),
              TextButton(
                onPressed: () => setState(() => _cancel = true),
                child: const Text('Abbrechen'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scannen'),
              ),
          ],
        ],
      ),
    );
  }

  EsclScanSettings _copy(
          {bool? feeder, bool? duplex, bool? color, int? resolution}) =>
      EsclScanSettings(
        feeder: feeder ?? _settings.feeder,
        duplex: duplex ?? _settings.duplex,
        color: color ?? _settings.color,
        resolution: resolution ?? _settings.resolution,
      );

  static String _statusText(EsclStatus s) {
    final state = switch (s.state) {
      'Idle' => 'Bereit',
      'Processing' => 'Beschäftigt',
      'Stopped' => 'Gestoppt',
      _ => s.state,
    };
    final adf = switch (s.adfState) {
      'ScannerAdfLoaded' => ' · Papier im Einzug',
      'ScannerAdfEmpty' => ' · Einzug leer',
      'ScannerAdfJam' => ' · Papierstau!',
      _ => '',
    };
    return '$state$adf';
  }
}
