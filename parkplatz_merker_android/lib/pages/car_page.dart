import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../native.dart';
import 'app_picker_page.dart';
import 'common_widgets.dart';
import 'help_page.dart';
import 'routine_test_page.dart';

class CarPage extends StatefulWidget {
  const CarPage({super.key});

  @override
  State<CarPage> createState() => _CarPageState();
}

class _CarPageState extends State<CarPage> with WidgetsBindingObserver {
  Map<String, dynamic>? _volumeInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVolumeInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zurück aus den System-Einstellungen (z. B. Nicht-stören-Zugriff) → neu laden.
    if (state == AppLifecycleState.resumed) _loadVolumeInfo();
  }

  Future<void> _loadVolumeInfo() async {
    final info = await NativeBridge.getVolumeInfo();
    if (!mounted) return;
    setState(() => _volumeInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final config = controller.config;
    final deviceMode = (config['deviceMode'] as String?) ?? 'none';
    final launchApps = ((config['launchApps'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Im Auto: Apps & Lautstärke')),
      body: ListView(
        children: [
          if (deviceMode == 'none')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Theme.of(context).colorScheme.inverseSurface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Ohne Transmitter/Beacon gilt jede erkannte Fahrt – auch Bus oder Taxi.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          const Divider(),
          SectionHeader('Apps öffnen', help: HelpTopic.appInCar),
          if (launchApps.isEmpty)
            const ListTile(title: Text('Keine App ausgewählt'))
          else
            ...List.generate(launchApps.length, (i) {
              final app = launchApps[i];
              final pkg = app['package'] as String?;
              final label = app['label'] as String?;
              final closeWidget = app['closeWidget'] as String? ?? '';
              final closeActionTitle = app['closeActionTitle'] as String? ?? '';
              // Subtitle anzeigen: Widget-Knopf, Aktion oder Package
              String subtitle = pkg ?? '';
              if (closeWidget.isNotEmpty) {
                // Extract index from key like "big:3"
                final parts = closeWidget.split(':');
                if (parts.length == 2) {
                  final idx = int.tryParse(parts[1]) ?? 0;
                  subtitle = 'Aus-Knopf: Widget-Knopf ${idx + 1}${_widgetWhere(closeWidget)}';
                }
              } else if (closeActionTitle.isNotEmpty) {
                subtitle = closeActionTitle;
              }
              return _AppListTile(
                index: i,
                package: pkg ?? '',
                label: label ?? '',
                subtitleText: subtitle,
                onMoveUp: i > 0
                    ? () => _moveApp(launchApps, i, i - 1, controller)
                    : null,
                onMoveDown: i < launchApps.length - 1
                    ? () => _moveApp(launchApps, i, i + 1, controller)
                    : null,
                onDelete: () => _removeApp(launchApps, i, controller),
                onSelectCloseAction: () =>
                    _showCloseActionDialog(controller, pkg ?? '', label ?? ''),
              );
            }),
          ListTile(
            title: const Text('App hinzufügen'),
            trailing: const Icon(Icons.add),
            onTap: () => _addApp(controller, launchApps),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Die letzte App in der Liste liegt danach vorn.'),
          ),
          PermTile(
            title: 'Über anderen Apps einblenden',
            hint: 'Nötig, damit die App von selbst aufgeht. Ohne kommt eine Benachrichtigung zum Antippen.',
            ok: (config['overlayAllowed'] as bool?) ?? false,
            onFix: () => NativeBridge.openOverlaySettings(),
          ),
          if (launchApps.isNotEmpty)
            ListTile(
              title: const Text('Apps jetzt öffnen (Test)'),
              onTap: () => NativeBridge.testLaunch(),
            ),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Ganze Routine testen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const RoutineTestPage(),
            )),
          ),
          const Divider(),
          SectionHeader('Beim Aussteigen', help: HelpTopic.closeApp),
          SwitchListTile(
            title: const Text('Apps beim Aussteigen beenden'),
            subtitle: const Text(
              'Wechselt zum Startbildschirm und beendet die Apps. '
              'Laufen sie mit eigener Benachrichtigung weiter, beende sie dort.',
            ),
            value: (config['closeOnGone'] as bool?) ?? true,
            onChanged: (v) => controller.updateConfig(closeOnGone: v),
          ),
          if ((config['closeOnGone'] as bool?) ?? true)
            PermTile(
              title: 'Benachrichtigungszugriff',
              hint: 'Damit die Ausschaltknöpfe in den Benachrichtigungen gedrückt werden können.',
              ok: (config['notificationListener'] as bool?) ?? false,
              onFix: () => NativeBridge.openNotificationListenerSettings(),
            ),
          if ((config['closeOnGone'] as bool?) ?? true)
            SwitchListTile(
              title: const Text(
                'Notfalls „Beenden erzwingen" (Bedienungshilfe)',
              ),
              subtitle: const Text(
                'Öffnet kurz die App-Info und drückt „Beenden erzwingen". Nur bei entsperrtem Handy.',
              ),
              value: (config['forceStopFallback'] as bool?) ?? false,
              onChanged: (v) => controller.updateConfig(forceStopFallback: v),
            ),
          if ((config['closeOnGone'] as bool?) ?? true)
            if ((config['forceStopFallback'] as bool?) ?? false)
              PermTile(
                title: 'Bedienungshilfe',
                hint: 'Einstellungen → Bedienungshilfen → Installierte Apps → „Parkplatz-Merker: App beenden" einschalten.',
                ok: (config['accessibility'] as bool?) ?? false,
                onFix: () => NativeBridge.openAccessibilitySettings(),
              ),
          if ((config['closeOnGone'] as bool?) ?? true)
            ListTile(
              title: const Text('Beenden jetzt testen'),
              onTap: () => NativeBridge.testClose(),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            title: const Text('Energiesparmodus im Auto (Samsung)'),
            subtitle: const Text('Mit Samsung „Modi und Routinen“ – so richtest du es ein'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => HelpPage.show(context, HelpTopic.powerSaving),
          ),
          const Divider(),
          SectionHeader('Lautstärke im Auto', help: HelpTopic.volume),
          SwitchListTile(
            title: const Text('Lautstärke-Profil'),
            subtitle: const Text('Stellt Lautstärke beim Einsteigen um'),
            value: (config['volumeEnabled'] as bool?) ?? false,
            onChanged: (v) => controller.updateConfig(volumeEnabled: v),
          ),
          if ((config['volumeEnabled'] as bool?) ?? false) ...[
            _VolumeStreamTile(
              title: 'Medien',
              current: (config['volMusic'] as int?) ?? -1,
              max: (_volumeInfo?['musicMax'] as int?) ?? 15,
              onChangeEnd: (v) => controller.updateConfig(volMusic: v),
            ),
            _VolumeStreamTile(
              title: 'Klingelton',
              current: (config['volRing'] as int?) ?? -1,
              max: (_volumeInfo?['ringMax'] as int?) ?? 7,
              onChangeEnd: (v) => controller.updateConfig(volRing: v),
            ),
            _VolumeStreamTile(
              title: 'Benachrichtigungen',
              current: (config['volNotification'] as int?) ?? -1,
              max: (_volumeInfo?['notificationMax'] as int?) ?? 7,
              onChangeEnd: (v) => controller.updateConfig(volNotification: v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Klingelmodus',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'keep', label: Text('Nicht ändern')),
                      ButtonSegment(value: 'normal', label: Text('Normal')),
                      ButtonSegment(value: 'vibrate', label: Text('Vibration')),
                      ButtonSegment(value: 'silent', label: Text('Lautlos')),
                    ],
                    selected: {(config['ringerMode'] as String?) ?? 'keep'},
                    onSelectionChanged: (sel) =>
                        controller.updateConfig(ringerMode: sel.first),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Beim Aussteigen zurücksetzen'),
              value: (config['volumeRestore'] as bool?) ?? true,
              onChanged: (v) => controller.updateConfig(volumeRestore: v),
            ),
            // Nur nötig, wenn das Profil Klingelton/Benachrichtigungen auf 0 oder „Lautlos“ stellt.
            if (((config['volRing'] as num?)?.toInt() ?? -1) == 0 ||
                ((config['volNotification'] as num?)?.toInt() ?? -1) == 0 ||
                ((config['ringerMode'] as String?) ?? 'keep') == 'silent')
              if (!((_volumeInfo?['dndAccess'] as bool?) ?? false))
                PermTile(
                  title: 'Nicht-stören-Zugriff',
                  hint: 'Nötig um Lautstärke auf 0 zu setzen oder auf Lautlos zu schalten.',
                  ok: false,
                  onFix: () => NativeBridge.openDndSettings(),
                ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        await NativeBridge.applyVolumeNow();
                        await _loadVolumeInfo();
                      },
                      child: const Text('Jetzt anwenden'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => NativeBridge.restoreVolumeNow(),
                      child: const Text('Zurücksetzen'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _addApp(
    AppController controller,
    List<Map<String, dynamic>> launchApps,
  ) async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const AppPickerPage(returnSelection: true),
      ),
    );
    if (result != null && result['package'] != null && mounted) {
      final pkg = result['package'] as String;
      final label = result['label'] as String;
      final newList = List<Map<String, dynamic>>.from(launchApps);
      if (!newList.any((a) => a['package'] == pkg)) {
        newList.add({
          'package': pkg,
          'label': label,
          'closeActionIndex': -1,
          'closeActionTitle': '',
          'closeWidget': '',
        });
        await controller.updateConfig(launchApps: newList);
      }
    }
  }

  void _removeApp(
    List<Map<String, dynamic>> launchApps,
    int index,
    AppController controller,
  ) async {
    final newList = List<Map<String, dynamic>>.from(launchApps);
    newList.removeAt(index);
    await controller.updateConfig(launchApps: newList);
  }

  void _moveApp(
    List<Map<String, dynamic>> launchApps,
    int from,
    int to,
    AppController controller,
  ) async {
    final newList = List<Map<String, dynamic>>.from(launchApps);
    final app = newList.removeAt(from);
    newList.insert(to, app);
    await controller.updateConfig(launchApps: newList);
  }

  Future<void> _showCloseActionDialog(
    AppController controller,
    String pkg,
    String label,
  ) async {
    final actionList = await NativeBridge.listCloseActions(pkg);
    if (!mounted) return;

    final actions = ((actionList['actions'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final widgetButtons = ((actionList['widgetButtons'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final hasNotification = actionList['hasNotification'] == true;

    if (!hasNotification) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Öffne zuerst $label, damit ihre Benachrichtigung da ist.',
          ),
        ),
      );
      return;
    }

    final choices = [
      {'index': -1, 'type': 'auto', 'title': 'Automatisch', 'raw': ''},
      ...actions.map(
        (a) => {
          'index': a['index'] as int,
          'type': 'action',
          'raw': (a['title'] as String?) ?? '',
          'title': ((a['title'] as String?) ?? '').isEmpty
              ? 'Knopf ${((a['index'] as int?) ?? 0) + 1} (nur Symbol)'
              : 'Knopf ${((a['index'] as int?) ?? 0) + 1}: ${a['title']}',
        },
      ),
    ];

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (bctx) => AlertDialog(
        title: const Text('Ausschaltknopf wählen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '$label muss gerade laufen (Benachrichtigung sichtbar). Teste die Knöpfe nacheinander – beim richtigen geht $label aus. Starte es danach wieder.',
              ),
              const SizedBox(height: 12),
              // Automatisch + Benachrichtigungs-Aktionen
              if (actions.isNotEmpty) ...[
                Text(
                  'Benachrichtigungs-Knöpfe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...List.generate(choices.length, (idx) {
                  final choice = choices[idx];
                  return ListTile(
                    title: Text(choice['title'] as String),
                    onTap: () => _selectCloseAction(
                      controller,
                      pkg,
                      actions,
                      choice['index'] as int,
                      choice['raw'] as String,
                      '',
                      bctx,
                    ),
                  );
                }),
              ] else
                ...List.generate(choices.length, (idx) {
                  final choice = choices[idx];
                  return ListTile(
                    title: Text(choice['title'] as String),
                    onTap: () => _selectCloseAction(
                      controller,
                      pkg,
                      actions,
                      choice['index'] as int,
                      choice['raw'] as String,
                      '',
                      bctx,
                    ),
                  );
                }),
              // Widget-Knöpfe
              if (widgetButtons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Knöpfe im Benachrichtigungs-Widget',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...List.generate(widgetButtons.length, (idx) {
                  final btn = widgetButtons[idx];
                  final key = btn['key'] as String? ?? '';
                  final name = btn['name'] as String? ?? '';
                  final desc = btn['desc'] as String? ?? '';
                  final btnIdx = (int.tryParse(key.split(':').last) ?? idx) + 1;
                  final where = _widgetWhere(key);
                  return ListTile(
                    title: Text('Widget-Knopf $btnIdx$where'),
                    subtitle: (name.isNotEmpty || desc.isNotEmpty)
                        ? Text('$name $desc'.trim())
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _testWidgetButton(pkg, key, label),
                      tooltip: 'Testen',
                    ),
                    onTap: () => _selectCloseAction(
                      controller,
                      pkg,
                      actions,
                      -1,
                      '',
                      key,
                      bctx,
                    ),
                  );
                }),
              ],
              // Warnung wenn weder Aktionen noch Widget-Knöpfe
              if (actions.isEmpty && widgetButtons.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Keine Knöpfe gefunden. Die App muss gerade laufen und eine Benachrichtigung haben.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(bctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _testWidgetButton(String pkg, String key, String label) async {
    if (!mounted) return;

    final result = await NativeBridge.testWidgetButton(pkg, key);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? 'Gedrückt – ist $label jetzt aus?'
              : 'Konnte nicht gedrückt werden',
        ),
      ),
    );
  }

  void _selectCloseAction(
    AppController controller,
    String pkg,
    List<Map<String, dynamic>> actions,
    int actionIndex,
    String actionTitle,
    String widgetKey,
    BuildContext bctx,
  ) {
    final config = controller.config;
    final launchApps = ((config['launchApps'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final appIndex = launchApps.indexWhere((a) => a['package'] == pkg);

    if (appIndex != -1) {
      if (widgetKey.isNotEmpty) {
        // Widget-Knopf ausgewählt
        launchApps[appIndex]['closeWidget'] = widgetKey;
        launchApps[appIndex]['closeActionIndex'] = -1;
        launchApps[appIndex]['closeActionTitle'] = '';
      } else {
        // Benachrichtigungs-Aktion ausgewählt
        launchApps[appIndex]['closeActionIndex'] = actionIndex;
        launchApps[appIndex]['closeActionTitle'] = actionTitle.isEmpty ? '' : actionTitle;
        launchApps[appIndex]['closeWidget'] = '';
      }
      controller.updateConfig(launchApps: launchApps);
    }
    Navigator.pop(bctx);
  }
}

/// Wo der Widget-Knopf liegt – passend zum Schlüssel "big:3" / "normal:1" / "headsup:0".
String _widgetWhere(String key) {
  if (key.startsWith('big:')) return ' (große Ansicht)';
  if (key.startsWith('headsup:')) return ' (Einblendung)';
  return ' (kleine Ansicht)';
}

class _AppListTile extends StatelessWidget {
  final int index;
  final String package;
  final String label;
  final String subtitleText;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onSelectCloseAction;

  const _AppListTile({
    required this.index,
    required this.package,
    required this.label,
    required this.subtitleText,
    required this.onDelete,
    required this.onSelectCloseAction,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(subtitleText),
      trailing: SizedBox(
        width: 120,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMoveUp != null)
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: onMoveUp,
                tooltip: 'Nach oben',
              )
            else
              const SizedBox(width: 48),
            if (onMoveDown != null)
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: onMoveDown,
                tooltip: 'Nach unten',
              )
            else
              const SizedBox(width: 48),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
              tooltip: 'Löschen',
            ),
          ],
        ),
      ),
      onTap: onSelectCloseAction,
    );
  }
}

class _VolumeStreamTile extends StatefulWidget {
  final String title;
  final int current; // -1 = nicht ändern
  final int max;
  final ValueChanged<int> onChangeEnd;

  const _VolumeStreamTile({
    required this.title,
    required this.current,
    required this.max,
    required this.onChangeEnd,
  });

  @override
  State<_VolumeStreamTile> createState() => _VolumeStreamTileState();
}

class _VolumeStreamTileState extends State<_VolumeStreamTile> {
  /// Wert während des Ziehens; gespeichert wird erst beim Loslassen.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final max = widget.max < 1 ? 1 : widget.max;
    final isEnabled = widget.current >= 0;
    final value = (_dragging ?? widget.current.clamp(0, max).toDouble());
    final percent = ((value / max) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(isEnabled ? '$percent %' : 'nicht ändern'),
              Checkbox(
                value: isEnabled,
                // Einschalten startet bei der Hälfte (0 bräuchte „Nicht stören“-Zugriff).
                onChanged: (v) =>
                    widget.onChangeEnd((v ?? false) ? (max / 2).round() : -1),
              ),
            ],
          ),
          if (isEnabled)
            Slider(
              value: value,
              min: 0,
              max: max.toDouble(),
              divisions: max,
              label: '$percent %',
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                widget.onChangeEnd(v.round());
              },
            ),
        ],
      ),
    );
  }
}
