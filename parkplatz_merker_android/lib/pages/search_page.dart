import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import '../controller.dart';
import '../native.dart';

class SearchPage extends StatefulWidget {
  /// 'transmitter' oder 'beacon'
  final String mode;

  const SearchPage({Key? key, required this.mode}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  bool _isSearching = false;
  List<Map<String, dynamic>> _devices = [];
  Timer? _pollTimer;
  double _progress = 0;

  String get _kind => widget.mode == 'beacon' ? 'Beacon' : 'Transmitter';

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stopSearch();
    super.dispose();
  }

  Future<void> _startSearch() async {
    // Berechtigungen anfragen
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    if (!mounted) return;

    // Suche starten
    _pollTimer?.cancel();
    final result = await NativeBridge.startDeviceSearch();
    if (!mounted) return;
    if (result['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: ${result['error'] ?? "Unbekannt"}')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _devices = [];
      _progress = 0;
    });

    // Alle 500 ms Ergebnisse abrufen
    int elapsed = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      elapsed += 500;
      if (!mounted) {
        timer.cancel();
        return;
      }
      final results = await NativeBridge.getSearchResults();
      final running = results['running'] == true;
      final devices = List<Map<String, dynamic>>.from(
        (results['devices'] as List? ?? []).map((d) {
          if (d is Map<Object?, Object?>) {
            return Map<String, dynamic>.from(d);
          }
          return d as Map<String, dynamic>;
        }),
      );

      // Nach RSSI absteigend sortieren
      devices.sort((a, b) {
        final rssiA = (a['rssi'] as num? ?? 0).toInt();
        final rssiB = (b['rssi'] as num? ?? 0).toInt();
        return rssiB.compareTo(rssiA);
      });

      if (mounted) {
        setState(() {
          _devices = devices;
          _progress = elapsed / 15000; // 15 Sekunden
          if (_progress > 1) _progress = 1;
        });
      }

      if (!running) {
        timer.cancel();
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _stopSearch() async {
    _pollTimer?.cancel();
    await NativeBridge.stopDeviceSearch();
  }

  @override
  Widget build(BuildContext context) {
    final infoText = widget.mode == 'transmitter'
        ? 'Auto an, Handy NICHT mit dem Transmitter verbunden.'
        : 'Auto an, Beacon eingesteckt.';

    return Scaffold(
      appBar: AppBar(title: Text('$_kind suchen')),
      body: Column(
        children: [
          // Info-Karte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(infoText),
              ),
            ),
          ),

          // Knopf
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _startSearch,
                child: const Text('Suche starten'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 12),
                  Text('${(_progress * 100).toInt()}%'),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Geräteliste
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _isSearching ? 'Suche läuft…' : 'Keine Geräte gefunden',
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final rawName = device['name'] as String?;
                      final name = rawName ?? '(ohne Namen)';
                      final address = device['address'] as String? ?? '';
                      final rssi = (device['rssi'] as num?)?.toInt() ?? 0;
                      final isClassic = device['classic'] == true;
                      final isBle = device['ble'] == true;

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(address),
                        trailing: SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('RSSI $rssi dBm'),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isClassic)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                      ),
                                      child: const Text(
                                        'klassisch',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  if (isBle)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                      ),
                                      child: const Text(
                                        'BLE',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          _showConfirmDialog(context, rawName, address);
                        },
                      );
                    },
                  ),
          ),

          // Tipp
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tipp: Steck den $_kind einmal aus und such noch mal – das Gerät, das dann verschwindet, ist deins. Das stärkste Signal (RSSI nahe 0) ist meist das nächste Gerät.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmDialog(
    BuildContext context,
    String? name,
    String address,
  ) async {
    final controller = context.read<AppController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dieses Gerät verwenden?'),
        content: Text('${name ?? '(ohne Namen)'}\n$address'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Verwenden'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _stopSearch();
    await controller.updateConfig(
      deviceMode: widget.mode,
      deviceAddress: address,
      deviceName: name ?? '',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_kind gespeichert: ${name ?? address}')),
    );
    Navigator.pop(context);
  }
}
