import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../controller.dart';
import '../native.dart';
import 'search_page.dart';
import 'diagnostics_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> _nativeStatus = {};
  bool _isRegisteringTransitions = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await NativeBridge.getNativeStatus();
    setState(() => _nativeStatus = status);
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (mounted) {
      await _loadStatus();
      // Nach Berechtigungserteiling Transitions registrieren
      if (status.isGranted) {
        setState(() => _isRegisteringTransitions = true);
        await NativeBridge.registerTransitions();
        setState(() => _isRegisteringTransitions = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final config = controller.config;
    final deviceMode = config['deviceMode'] ?? 'none';
    final deviceAddress = config['deviceAddress'];
    final deviceName = config['deviceName'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          // Erkennung
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erkennung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text('Aktivitätserkennung'),
            subtitle: const Text('Aussteigen erkennen'),
            value: config['activityEnabled'] ?? true,
            onChanged: (value) {
              NativeBridge.setConfig(activityEnabled: value);
              controller.refresh();
            },
          ),
          SwitchListTile(
            title: const Text('Ladekabel als Hinweis'),
            subtitle: const Text('Verwendet Ladekabelabzug zur Parkplatzerkennung'),
            value: config['chargerEnabled'] ?? true,
            onChanged: (value) {
              NativeBridge.setConfig(chargerEnabled: value);
              controller.refresh();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Gerät im Auto', style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(label: Text('Keins'), value: 'none'),
                ButtonSegment(label: Text('Transmitter'), value: 'transmitter'),
                ButtonSegment(label: Text('Beacon'), value: 'beacon'),
              ],
              selected: {deviceMode},
              onSelectionChanged: (Set<String> selected) {
                NativeBridge.setConfig(deviceMode: selected.first);
                controller.refresh();
              },
            ),
          ),
          if (deviceMode != 'none')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (deviceName != null) Text('Name: $deviceName'),
                  if (deviceAddress != null) Text('Adresse: $deviceAddress'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final mode = deviceMode == 'transmitter' ? 'Transmitter' : 'Beacon';
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SearchPage(mode: mode),
                        ),
                      );
                    },
                    child: Text('$deviceMode suchen'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Die App verbindet sich nie mit dem Gerät – sie schaut nur, ob es in der Nähe ist.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),

          // Einrichtung
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Einrichtung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildPermissionTile(
            context,
            'Standort (wenn in Nutzung)',
            _nativeStatus['locationEnabled'] != true,
            () => _requestPermission(Permission.locationWhenInUse),
          ),
          _buildPermissionTile(
            context,
            'Standort (immer zulassen)',
            _nativeStatus['locationEnabled'] != true,
            () => _requestPermission(Permission.locationAlways),
          ),
          _buildPermissionTile(
            context,
            'Aktivitätserkennung',
            _nativeStatus['transitionsRegistered'] != true,
            () => _requestPermission(Permission.activityRecognition),
          ),
          if (deviceMode != 'none')
            _buildPermissionTile(
              context,
              'Bluetooth-Suche',
              _nativeStatus['bluetoothEnabled'] != true,
              () async {
                await _requestPermission(Permission.bluetoothScan);
                if (mounted) {
                  await _requestPermission(Permission.bluetoothConnect);
                }
              },
            ),
          _buildPermissionTile(
            context,
            'Benachrichtigungen',
            false, // Hinweis: sollte richtig geprüft werden
            () => _requestPermission(Permission.notification),
          ),
          _buildPermissionTile(
            context,
            'Akku (nicht eingeschränkt)',
            _nativeStatus['ignoringBatteryOptimizations'] != true,
            () => NativeBridge.openBatterySettings(),
          ),
          const Divider(),

          // Hinweis
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android blockiert manche Einstellungen',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Schalter ausgegraut oder „Eingeschränkte Einstellung"? App-Info öffnen → oben rechts ⋮ → „Eingeschränkte Einstellungen zulassen".',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => NativeBridge.openAppDetails(),
                      child: const Text('App-Info öffnen'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Diagnose
          const Divider(),
          ListTile(
            title: const Text('Diagnose'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiagnosticsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context,
    String title,
    bool needsPermission,
    VoidCallback onPressed,
  ) {
    return ListTile(
      title: Text(title),
      trailing: needsPermission
          ? FilledButton(
              onPressed: onPressed,
              child: const Text('Erlauben'),
            )
          : Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
    );
  }
}
