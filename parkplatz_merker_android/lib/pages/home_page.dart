import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'spot_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _locating = false;
  SetupState? _setup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = context.read<AppController>();
    if (state == AppLifecycleState.resumed) {
      controller.resumedRefresh();
      _checkSetup();
    } else if (state == AppLifecycleState.paused) {
      controller.pausedRefresh();
    }
  }

  Future<void> _checkSetup() async {
    final setup = await SetupState.load();
    if (mounted) setState(() => _setup = setup);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    _checkSetup();
  }

  Future<void> _parkHere() async {
    final controller = context.read<AppController>();
    setState(() => _locating = true);
    final error = await controller.parkHere();
    if (!mounted) return;
    setState(() => _locating = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? 'Parkplatz gemerkt')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final latest = controller.latest;
    final setup = _setup;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parkplatz-Merker'),
        actions: [
          IconButton(
            tooltip: 'Verlauf',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (setup != null && !setup.essentialsOk)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('Einrichtung unvollständig – tippe hier'),
                  subtitle: const Text(
                    'Ohne diese Berechtigungen merkt sich die App den Parkplatz nicht automatisch.',
                  ),
                  onTap: _openSettings,
                ),
              ),
            if (controller.tripRunning)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.directions_car),
                  title: Text(
                    'Fahrt läuft – der Parkplatz wird beim Aussteigen gemerkt.',
                  ),
                ),
              ),
            if (!controller.ready)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (latest == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_parking,
                      size: 80,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Noch kein Parkplatz gemerkt.',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fahr einfach los – oder tippe auf „Hier geparkt“.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              SpotView(spot: latest, myLocation: controller.myLocation),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _locating ? null : _parkHere,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_parking),
            label: Text(
              _locating ? 'Standort wird bestimmt …' : 'Hier geparkt',
            ),
          ),
        ),
      ),
    );
  }
}
