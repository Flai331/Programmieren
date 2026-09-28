import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../logic/format.dart';
import '../native.dart';
import 'help_page.dart';

class HeadphonesPage extends StatefulWidget {
  const HeadphonesPage({super.key});

  @override
  State<HeadphonesPage> createState() => _HeadphonesPageState();
}

class _HeadphonesPageState extends State<HeadphonesPage> {
  List<Map<String, dynamic>> _headphones = [];

  @override
  void initState() {
    super.initState();
    _loadHeadphones();
  }

  Future<void> _loadHeadphones() async {
    final headphones = await NativeBridge.getHeadphones();
    if (mounted) {
      setState(() {
        _headphones = headphones;
      });
    }
  }

  Future<void> _forget(String address) async {
    await NativeBridge.forgetHeadphone(address);
    await _loadHeadphones();
  }

  Future<void> _addHeadphone() async {
    final controller = context.read<AppController>();
    final devices = await NativeBridge.listBondedDevices();
    if (!mounted) return;

    // Audio-Geräte zuerst sortieren
    devices.sort((a, b) {
      final aAudio = (a['audio'] as bool?) ?? false;
      final bAudio = (b['audio'] as bool?) ?? false;
      if (aAudio != bAudio) return bAudio ? 1 : -1;
      return 0;
    });

    final currentAddresses = (_headphones.map((h) => h['address'] as String?).toList());

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _AddHeadphonesDialog(
        devices: devices,
        selected: currentAddresses.whereType<String>().toSet(),
      ),
    );

    if (result == null) return;

    // Neue Kopfhörer = Adresse aus selected
    final newHeadphones = result
        .map((address) {
          final device = devices.firstWhere(
            (d) => d['address'] == address,
            orElse: () => <String, dynamic>{},
          );
          final known = _headphones.firstWhere(
            (h) => h['address'] == address,
            orElse: () => <String, dynamic>{},
          );
          return {
            'address': address,
            'name': device['name'] ?? known['name'] ?? address,
          };
        })
        .toList()
        .cast<Map<String, dynamic>>();

    await controller.updateConfig(headphones: newHeadphones);
    await _loadHeadphones();
  }

  Future<void> _removeHeadphone(String address) async {
    final controller = context.read<AppController>();
    final headphones = _headphones
        .where((h) => h['address'] != address)
        .toList()
        .cast<Map<String, dynamic>>();
    await controller.updateConfig(headphones: headphones);
    await _loadHeadphones();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_headphones.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kopfhörer'),
          actions: [
            IconButton(
              tooltip: 'Anleitung',
              icon: const Icon(Icons.help_outline),
              onPressed: () => HelpPage.show(context, HelpTopic.headphones),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headphones, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text(
                  'Keine Kopfhörer hinzugefügt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tippe auf den Knopf unten, um Kopfhörer hinzuzufügen.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _addHeadphone,
                  icon: const Icon(Icons.add),
                  label: const Text('Kopfhörer hinzufügen'),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addHeadphone,
          tooltip: 'Kopfhörer hinzufügen',
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kopfhörer'),
        actions: [
          IconButton(
            tooltip: 'Anleitung',
            icon: const Icon(Icons.help_outline),
            onPressed: () => HelpPage.show(context, HelpTopic.headphones),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHeadphones,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _headphones.length,
          itemBuilder: (ctx, idx) => _HeadphoneCard(
            headphone: _headphones[idx],
            onForget: () => _forget(_headphones[idx]['address'] as String),
            onRemove: () => _removeHeadphone(_headphones[idx]['address'] as String),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHeadphone,
        tooltip: 'Kopfhörer hinzufügen',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HeadphoneCard extends StatelessWidget {
  final Map<String, dynamic> headphone;
  final VoidCallback onForget;
  final VoidCallback onRemove;

  const _HeadphoneCard({
    required this.headphone,
    required this.onForget,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = headphone['name'] as String? ?? 'Unbekannt';
    final connected = (headphone['connected'] as bool?) ?? false;
    final lat = headphone['lat'] as num?;
    final lng = headphone['lng'] as num?;
    final acc = headphone['acc'] as num?;
    final changedAt = (headphone['changedAt'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (choice) {
                    if (choice == 'remove') onRemove();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Entfernen'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Optionen',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (connected)
              Text(
                'Gerade verbunden',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (changedAt == 0)
              Text(
                'Noch keine Trennung gespeichert',
                style: theme.textTheme.bodyMedium,
              )
            else if (lat == null || lng == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Getrennt am ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(changedAt))}, Ort unbekannt',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Getrennt am ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(changedAt))}${acc != null ? ' (± ${(acc + 0.5).toInt()} m)' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 180,
                      child: FlutterMap(
                        key: ValueKey('$lat-$lng'),
                        options: MapOptions(
                          initialCenter: LatLng(lat.toDouble(), lng.toDouble()),
                          initialZoom: 17,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.klaasotte.parkplatz_merker',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat.toDouble(), lng.toDouble()),
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primary,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.headphones,
                                    color: theme.colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('OpenStreetMap-Mitwirkende'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => NativeBridge.openNavigation(lat.toDouble(), lng.toDouble()),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigation'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onForget,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Vergessen'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AddHeadphonesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final Set<String> selected;

  const _AddHeadphonesDialog({
    required this.devices,
    required this.selected,
  });

  @override
  State<_AddHeadphonesDialog> createState() => _AddHeadphonesDialogState();
}

class _AddHeadphonesDialogState extends State<_AddHeadphonesDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) {
      return AlertDialog(
        title: const Text('Kopfhörer hinzufügen'),
        content: const Text(
          'Keine gekoppelten Geräte gefunden. Kopple deinen Kopfhörer zuerst in den '
          'Bluetooth-Einstellungen und erlaube „Geräte in der Nähe".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Kopfhörer hinzufügen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: widget.devices.length,
          itemBuilder: (ctx, idx) {
            final device = widget.devices[idx];
            final address = device['address'] as String? ?? '';
            final name = device['name'] as String? ?? 'Unbekannt';
            final audio = (device['audio'] as bool?) ?? false;

            return CheckboxListTile(
              value: _selected.contains(address),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(address);
                  } else {
                    _selected.remove(address);
                  }
                });
              },
              title: Row(
                children: [
                  Icon(
                    audio ? Icons.headphones : Icons.bluetooth,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name),
                        Text(address, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
