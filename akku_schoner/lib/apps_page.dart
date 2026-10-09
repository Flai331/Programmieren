import 'dart:async';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'native.dart';

class AppsPage extends StatefulWidget {
  final bool active;
  const AppsPage({super.key, required this.active});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> with WidgetsBindingObserver {
  List<AppEntry>? _apps;
  Set<String> _important = {...defaultImportant};
  Map<dynamic, dynamic> _status = {};
  bool _showSystem = false;
  bool _loading = false;

  // Laufender Auftrag „Beenden erzwingen“
  Timer? _poll;
  int _total = 0;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadImportant();
  }

  @override
  void didUpdateWidget(AppsPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zurück aus den Einstellungen (Berechtigung erteilt, App beendet …)
    if (state == AppLifecycleState.resumed && widget.active && _poll == null) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadImportant() async {
    try {
      final saved = await Native.important();
      if (saved != null && mounted) setState(() => _important = saved);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final status = await Native.status();
      final apps = await Native.apps();
      if (!mounted) return;
      setState(() {
        _status = status;
        _apps = sortApps(apps);
      });
    } catch (_) {
      // Nicht bei jedem Neuaufbau erneut laden (Endlosschleife) – Liste bleibt leer.
      if (mounted) setState(() => _apps ??= []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _usageAccess => _status['usageAccess'] == true;
  bool get _accessibility => _status['accessibility'] == true;

  void _toggleImportant(AppEntry a) {
    setState(() {
      if (!_important.remove(a.pkg)) _important.add(a.pkg);
    });
    Native.setImportant(_important);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _stopAll() async {
    final candidates = stopCandidates(_apps ?? [], _important);
    if (candidates.isEmpty) {
      _snack('Keine unwichtige App läuft gerade.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${candidates.length} Apps beenden?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(candidates.map((a) => a.label).join(', ')),
              const SizedBox(height: 12),
              Text(
                _accessibility
                    ? 'Für jede App öffnet sich kurz die App-Info und „Beenden erzwingen“ wird gedrückt. '
                        'Bitte so lange das Handy nicht bedienen.\n\n'
                        'Beendete Apps schicken keine Benachrichtigungen mehr, bis du sie wieder öffnest.'
                    : 'Ohne Bedienungshilfe kann Android die Apps nur sanft beenden – '
                        'Apps mit eigenem Dienst laufen dann weiter.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Beenden')),
        ],
      ),
    );
    if (ok != true) return;
    await _stop(candidates.map((a) => a.pkg).toList());
  }

  Future<void> _stop(List<String> pkgs) async {
    final soft = await Native.killBackground(pkgs);
    if (!_accessibility) {
      _snack('$soft Apps sanft beendet. Für komplettes Beenden die Bedienungshilfe einschalten.');
      _load();
      return;
    }
    final started = await Native.forceStop(pkgs);
    if (!started) {
      _snack('Bedienungshilfe reagiert nicht – aus- und wieder einschalten.');
      return;
    }
    setState(() {
      _total = pkgs.length;
      _done = 0;
    });
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _checkProgress());
  }

  Future<void> _checkProgress() async {
    final s = await Native.forceStopState();
    final pending = (s['pending'] as List?) ?? [];
    final results = ((s['results'] as List?) ?? []).cast<Map>();
    if (!mounted) return;
    setState(() {
      _total = (s['total'] as num?)?.toInt() ?? _total;
      _done = results.length;
    });
    if (pending.isNotEmpty) return;
    _poll?.cancel();
    _poll = null;
    setState(() => _total = 0);
    await _load();
    if (!mounted) return;
    _showResults(results);
  }

  void _showResults(List<Map> results) {
    final labels = {for (final a in _apps ?? <AppEntry>[]) a.pkg: a.label};
    final stopped = results.where((r) => r['result'] == 'beendet').length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$stopped von ${results.length} beendet'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${labels[r['pkg']] ?? r['pkg']}: ${r['result']}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _details(AppEntry a) {
    final important = _important.contains(a.pkg);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _AppIcon(a),
              title: Text(a.label),
              subtitle: Text(a.pkg),
            ),
            const Divider(height: 1),
            if (a.stoppable)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Jetzt beenden'),
                subtitle: a.system
                    ? const Text('Vorinstallierte App – nur beenden, wenn du sicher bist.')
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _stop([a.pkg]);
                },
              ),
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('Akkunutzung einschränken'),
              subtitle: const Text(
                  'Öffnet die App-Info → „Akku“ → „Eingeschränkt“. Wirkt dauerhaft, '
                  'die App darf dann nicht mehr im Hintergrund laufen.'),
              onTap: () {
                Navigator.pop(ctx);
                Native.openAppDetails(a.pkg);
              },
            ),
            if (!a.protected)
              ListTile(
                leading: Icon(important ? Icons.star : Icons.star_border),
                title: Text(important ? 'Nicht mehr wichtig' : 'Als wichtig markieren'),
                subtitle: const Text('Wichtige Apps werden nie automatisch beendet.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleImportant(a);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    if (apps == null) {
      if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      return const Center(child: CircularProgressIndicator());
    }
    final visible = apps.where((a) => _showSystem || !a.system).toList();
    final candidates = stopCandidates(apps, _important);
    final running = visible.where((a) => !a.stopped).length;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!_usageAccess)
            _PermCard(
              icon: Icons.query_stats,
              title: 'Nutzungszugriff erlauben',
              text: 'Damit siehst du, welche App wie lange im Hintergrund lief. '
                  'In der Liste „Akku-Schoner“ antippen und erlauben.',
              onTap: () => Native.openSettings('usage'),
            ),
          if (!_accessibility)
            _PermCard(
              icon: Icons.accessibility_new,
              title: 'Bedienungshilfe einschalten',
              text: 'Nur damit lassen sich Apps wirklich komplett beenden. '
                  'Bedienungshilfen → Installierte Apps → „Akku-Schoner: Apps beenden“. '
                  'Ausgegraut? In der App-Info oben rechts ⋮ → „Eingeschränkte Einstellungen zulassen“.',
              onTap: () => Native.openSettings('accessibility'),
              secondary: TextButton(
                onPressed: () => Native.openSettings('appInfo'),
                child: const Text('App-Info öffnen'),
              ),
            ),
          if (_total > 0)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Beende Apps … $_done von $_total'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                    TextButton(
                      onPressed: () => Native.cancelForceStop(),
                      child: const Text('Abbrechen'),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.cleaning_services),
              label: Text(candidates.isEmpty
                  ? 'Keine unwichtige App läuft'
                  : '${candidates.length} unwichtige Apps beenden'),
              onPressed: candidates.isEmpty || _total > 0 ? null : _stopAll,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$running von ${visible.length} Apps sind aktiv · ★ = wichtig, wird nie beendet',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilterChip(
                  label: const Text('Vorinstallierte'),
                  selected: _showSystem,
                  onSelected: (v) => setState(() => _showSystem = v),
                ),
              ],
            ),
          ),
          for (final a in visible)
            ListTile(
              leading: _AppIcon(a),
              title: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_subtitle(a, now)),
              onTap: () => _details(a),
              trailing: a.protected
                  ? const Tooltip(
                      message: 'Startbildschirm/Tastatur – wird nie beendet',
                      child: Icon(Icons.lock_outline))
                  : IconButton(
                      tooltip: 'Wichtig',
                      icon: Icon(
                        _important.contains(a.pkg) ? Icons.star : Icons.star_border,
                        color: _important.contains(a.pkg) ? Colors.amber : null,
                      ),
                      onPressed: () => _toggleImportant(a),
                    ),
            ),
        ],
      ),
    );
  }

  String _subtitle(AppEntry a, DateTime now) {
    final parts = <String>[a.stopped ? 'beendet' : 'aktiv'];
    if (_usageAccess) {
      if (a.fgService > const Duration(minutes: 1)) {
        parts.add('${formatDuration(a.fgService)} im Hintergrund');
      }
      parts.add('benutzt ${formatAgo(a.lastUsed, now)}');
    }
    if (a.system) parts.add('vorinstalliert');
    return parts.join(' · ');
  }
}

class _AppIcon extends StatelessWidget {
  final AppEntry app;
  const _AppIcon(this.app);

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    final child = icon == null
        ? const Icon(Icons.android, size: 40)
        : Image.memory(icon, width: 40, height: 40, gaplessPlayback: true);
    return Opacity(opacity: app.stopped ? 0.4 : 1, child: child);
  }
}

class _PermCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final Widget? secondary;

  const _PermCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text(text),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondary != null) secondary!,
                FilledButton.tonal(onPressed: onTap, child: const Text('Öffnen')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
