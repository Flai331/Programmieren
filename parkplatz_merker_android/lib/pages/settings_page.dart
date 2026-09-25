import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../native.dart';
import 'app_picker_page.dart';
import 'diagnostics_page.dart';
import 'search_page.dart';

/// Stand der Einrichtung (Berechtigungen + Akku).
class SetupState {
  final bool location;
  final bool locationAlways;
  final bool activity;
  final bool bluetooth;
  final bool notifications;
  final bool battery;
  final bool overlay;

  const SetupState({
    required this.location,
    required this.locationAlways,
    required this.activity,
    required this.bluetooth,
    required this.notifications,
    required this.battery,
    required this.overlay,
  });

  /// Das Nötigste für die automatische Erkennung.
  bool get essentialsOk =>
      location && locationAlways && activity && notifications;

  static Future<SetupState> load() async {
    final status = await NativeBridge.getNativeStatus();
    return SetupState(
      location: await Permission.locationWhenInUse.isGranted,
      locationAlways: await Permission.locationAlways.isGranted,
      activity: await Permission.activityRecognition.isGranted,
      bluetooth:
          await Permission.bluetoothScan.isGranted &&
          await Permission.bluetoothConnect.isGranted,
      notifications: await Permission.notification.isGranted,
      battery: status['ignoringBatteryOptimizations'] == true,
      overlay: status['overlayAllowed'] == true,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  SetupState? _setup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zurück aus den System-Einstellungen → Stand neu prüfen.
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final setup = await SetupState.load();
    if (!mounted) return;
    setState(() => _setup = setup);
    await context.read<AppController>().reloadConfig();
  }

  Future<void> _request(List<Permission> permissions) async {
    for (final p in permissions) {
      var status = await p.status;
      if (!status.isGranted) status = await p.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        break;
      }
      if (!status.isGranted) break;
    }
    await NativeBridge.registerTransitions();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final config = controller.config;
    final deviceMode = (config['deviceMode'] as String?) ?? 'none';
    final deviceAddress = config['deviceAddress'] as String?;
    final deviceName = config['deviceName'] as String?;
    final setup = _setup;
    final kind = deviceMode == 'beacon' ? 'Beacon' : 'Transmitter';

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const _Header('Erkennung'),
          SwitchListTile(
            title: const Text('Aktivitätserkennung (Aussteigen)'),
            subtitle: const Text('Hauptweg: erkennt Fahrt und Aussteigen'),
            value: config['activityEnabled'] != false,
            onChanged: (v) => controller.updateConfig(activityEnabled: v),
          ),
          SwitchListTile(
            title: const Text('Ladekabel als Hinweis'),
            subtitle: const Text(
              'Kabel ab beim Aussteigen = genauer Zeitpunkt',
            ),
            value: config['chargerEnabled'] != false,
            onChanged: (v) => controller.updateConfig(chargerEnabled: v),
          ),
          const ListTile(title: Text('Gerät im Auto')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'none', label: Text('Keins')),
                ButtonSegment(value: 'transmitter', label: Text('Transmitter')),
                ButtonSegment(value: 'beacon', label: Text('Beacon')),
              ],
              selected: {deviceMode},
              onSelectionChanged: (sel) =>
                  controller.updateConfig(deviceMode: sel.first),
            ),
          ),
          if (deviceMode != 'none')
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(
                deviceAddress == null
                    ? 'Noch kein $kind gewählt'
                    : ((deviceName == null || deviceName.isEmpty)
                          ? '(ohne Namen)'
                          : deviceName),
              ),
              subtitle: deviceAddress == null ? null : Text(deviceAddress),
              trailing: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SearchPage(mode: deviceMode),
                  ),
                ),
                child: Text('$kind suchen'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Die App verbindet sich nie mit dem Gerät – sie schaut nur, ob es in der Nähe ist. '
              'Nur während einer Fahrt wird alle 2 Minuten kurz gesucht.',
            ),
          ),
          if (deviceMode != 'none') ...[
            const Divider(),
            const _Header('App im Auto'),
            ListTile(
              title: const Text('App öffnen, wenn das Gerät erkannt wird'),
              subtitle: Text(
                ((config['launchPackage'] as String?) ?? '').isEmpty
                    ? 'Keine'
                    : config['launchLabel'] as String? ?? 'App',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppPickerPage(),
                  ),
                ),
                child: const Text('Wählen'),
              ),
            ),
            SwitchListTile(
              title: const Text('Beim Aussteigen schließen'),
              subtitle: const Text(
                'Wechselt zum Startbildschirm und beendet die App, wenn Android es erlaubt. '
                'Läuft sie mit eigener Benachrichtigung weiter, beende sie dort.',
              ),
              value: config['closeOnGone'] != false,
              onChanged: (v) => controller.updateConfig(closeOnGone: v),
            ),
            if (setup != null)
              _PermTile(
                title: 'Über anderen Apps einblenden',
                hint: 'Nötig, damit die App von selbst aufgeht. Ohne kommt eine Benachrichtigung zum Antippen.',
                ok: setup.overlay,
                onFix: () => NativeBridge.openOverlaySettings(),
              ),
            ListTile(
              title: const Text('Jetzt testen'),
              onTap: () => NativeBridge.testLaunch(),
            ),
          ],
          const Divider(),
          const _Header('Einrichtung'),
          if (setup == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          else ...[
            _PermTile(
              title: '1. Standort',
              ok: setup.location,
              onFix: () => _request([Permission.locationWhenInUse]),
            ),
            _PermTile(
              title: '2. Standort „Immer zulassen“',
              hint: 'Im nächsten Fenster „Immer zulassen“ wählen – sonst klappt es nicht bei geschlossener App.',
              ok: setup.locationAlways,
              onFix: setup.location
                  ? () => _request([Permission.locationAlways])
                  : null,
            ),
            _PermTile(
              title: '3. Aktivitätserkennung',
              hint: 'Erkennt, ob du fährst oder gehst.',
              ok: setup.activity,
              onFix: () => _request([Permission.activityRecognition]),
            ),
            _PermTile(
              title: '4. Bluetooth-Suche',
              hint: deviceMode == 'none'
                  ? 'Nur nötig mit Transmitter oder Beacon.'
                  : 'Zum „Sehen“ des Geräts.',
              ok: setup.bluetooth,
              onFix: () => _request([
                Permission.bluetoothScan,
                Permission.bluetoothConnect,
              ]),
            ),
            _PermTile(
              title: '5. Benachrichtigungen',
              hint: 'Für „Fahrt erkannt“ und die Parkschein-Erinnerung.',
              ok: setup.notifications,
              onFix: () => _request([Permission.notification]),
            ),
            _PermTile(
              title: '6. Akku „Nicht eingeschränkt“',
              hint: 'Sonst beendet Android die Erkennung im Hintergrund.',
              ok: setup.battery,
              onFix: () => NativeBridge.openBatterySettings(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schalter ausgegraut oder „Eingeschränkte Einstellung“? Android sperrt manche '
                      'Einstellungen für Apps, die nicht aus dem Play Store kommen. Freigeben: '
                      'App-Info öffnen → oben rechts ⋮ → „Eingeschränkte Einstellungen zulassen“.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => NativeBridge.openAppDetails(),
                      child: const Text('App-Info öffnen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnose'),
            subtitle: const Text(
              'Ereignisse, Berechtigungen, Gerät – zum Kopieren',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _PermTile extends StatelessWidget {
  final String title;
  final String? hint;
  final bool ok;
  final VoidCallback? onFix;

  const _PermTile({
    required this.title,
    required this.ok,
    this.hint,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? Colors.green : scheme.error,
      ),
      title: Text(title),
      subtitle: hint == null ? null : Text(hint!),
      trailing: ok
          ? null
          : FilledButton(onPressed: onFix, child: const Text('Erlauben')),
    );
  }
}
