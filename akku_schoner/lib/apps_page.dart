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
  Map<dynamic, dynamic> _status = {};
  bool _showSystem = false;
  bool _loading = false;

  // Automatik
  bool _autoSoft = false;
  bool _autoFull = false;
  double _unlockAfter = 30;

  // Laufender Auftrag „Beenden erzwingen“
  Timer? _poll;
  int _total = 0;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAuto();
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

  Future<void> _loadAuto() async {
    try {
      final w = await Native.watcher();
      if (!mounted) return;
      setState(() {
        _autoSoft = w['autoSoft'] == true;
        _autoFull = w['autoFull'] == true;
        _unlockAfter = ((w['unlockAfterMin'] as num?) ?? 30).toDouble();
      });
    } catch (_) {}
  }

  Future<void> _saveAuto() => Native.setWatcher({
        'autoSoft': _autoSoft,
        'autoFull': _autoFull,
        'unlockAfterMin': _unlockAfter.round(),
      });

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

  Future<void> _setLevel(AppEntry a, Level? level) async {
    await Native.setLevel(a.pkg, level);
    setState(() {
      _apps = [
        for (final x in _apps ?? <AppEntry>[])
          x.pkg == a.pkg ? x.copyWith(level: level ?? x.autoLevel) : x
      ];
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _cleanupNow() async {
    final plan = planCleanup(_apps ?? []);
    if (plan.isEmpty) {
      _snack('Keine App zum Aufräumen aktiv.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan.count} Apps aufräumen?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plan.full.isNotEmpty) ...[
                const Text('Komplett beenden:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(plan.full.map((a) => a.label).join(', ')),
                const SizedBox(height: 8),
              ],
              if (plan.soft.isNotEmpty) ...[
                const Text('Sanft beenden:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(plan.soft.map((a) => a.label).join(', ')),
                const SizedBox(height: 8),
              ],
              Text(
                plan.full.isEmpty
                    ? 'Sanft beendete Apps starten bei Bedarf wieder (Nachricht, Play am Kopfhörer).'
                    : _accessibility
                        ? 'Für jede „Komplett“-App öffnet sich kurz die App-Info. Bitte so lange das Handy nicht bedienen.'
                        : 'Ohne Bedienungshilfe werden auch die „Komplett“-Apps nur sanft beendet.',
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
              child: const Text('Aufräumen')),
        ],
      ),
    );
    if (ok != true) return;
    await Native.killBackground([...plan.soft, ...plan.full].map((a) => a.pkg).toList());
    if (plan.full.isEmpty || !_accessibility) {
      _snack('${plan.count} Apps sanft beendet.');
      _load();
      return;
    }
    await _forceStop(plan.full.map((a) => a.pkg).toList());
  }

  Future<void> _forceStop(List<String> pkgs) async {
    if (!_accessibility) {
      await Native.killBackground(pkgs);
      _snack('Nur sanft beendet – für komplettes Beenden die Bedienungshilfe einschalten.');
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
        title: Text('$stopped von ${results.length} komplett beendet'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _details(AppEntry a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: _AppIcon(a),
                title: Text(a.label),
                subtitle: Text(a.pkg),
              ),
              const Divider(height: 1),
              if (a.protected)
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Geschützt'),
                  subtitle: Text('Startbildschirm und Tastatur werden nie beendet.'),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('Stufe', style: Theme.of(ctx).textTheme.titleSmall),
                ),
                RadioListTile<Level?>(
                  value: null,
                  groupValue: a.manual ? a.level : null,
                  title: Text('Automatisch: ${levelName(a.autoLevel)}'),
                  subtitle: Text(autoReason(a)),
                  onChanged: (_) {
                    Navigator.pop(ctx);
                    _setLevel(a, null);
                  },
                ),
                for (final l in Level.values)
                  RadioListTile<Level?>(
                    value: l,
                    groupValue: a.manual ? a.level : null,
                    title: Text(levelName(l)),
                    subtitle: Text(levelHint(l)),
                    onChanged: (_) {
                      Navigator.pop(ctx);
                      _setLevel(a, l);
                    },
                  ),
                const Divider(height: 1),
                if (a.running)
                  ListTile(
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: const Text('Jetzt komplett beenden'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _forceStop([a.pkg]);
                    },
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: const Text('Akkunutzung einschränken'),
                subtitle: const Text(
                    'App-Info → Akku → „Eingeschränkt“. Wirkt dauerhaft. '
                    'Nicht bei Spotify & Co., sonst bricht die Musik bei gesperrtem Handy ab.'),
                onTap: () {
                  Navigator.pop(ctx);
                  Native.openAppDetails(a.pkg);
                },
              ),
            ],
          ),
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
    final plan = planCleanup(apps);
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
              text: 'Nötig, damit die Stufen nach deiner Nutzung gewählt werden (oft benutzt = wichtig, '
                  'lange nicht benutzt = komplett beenden). In der Liste „Akku-Schoner“ antippen und erlauben.',
              onTap: () => Native.openSettings('usage'),
            ),
          if (!_accessibility)
            _PermCard(
              icon: Icons.accessibility_new,
              title: 'Bedienungshilfe einschalten',
              text: 'Nur damit lassen sich Apps komplett beenden. '
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
                    LinearProgressIndicator(value: _done / _total),
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
              label: Text(plan.isEmpty
                  ? 'Nichts aufzuräumen'
                  : 'Jetzt aufräumen (${plan.full.length} komplett, ${plan.soft.length} sanft)'),
              onPressed: plan.isEmpty || _total > 0 ? null : _cleanupNow,
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Bei Bildschirm-Aus sanft aufräumen'),
                  subtitle: const Text(
                      '15 s nach dem Ausschalten fliegen „Sanft“- und „Komplett“-Apps aus dem Speicher. '
                      'Laufende Musik bleibt an, Play am Kopfhörer geht weiter.'),
                  value: _autoSoft,
                  onChanged: (v) {
                    setState(() => _autoSoft = v);
                    _saveAuto();
                  },
                ),
                SwitchListTile(
                  title: const Text('Beim Entsperren komplett beenden'),
                  subtitle: Text(
                      'War der Bildschirm mindestens ${_unlockAfter.round()} min aus, werden „Komplett“-Apps '
                      'beendet, die sich wieder eingeschlichen haben (App-Info blitzt kurz auf). '
                      'Nicht während eines Anrufs.'),
                  value: _autoFull,
                  onChanged: _accessibility
                      ? (v) {
                          setState(() => _autoFull = v);
                          _saveAuto();
                        }
                      : null,
                ),
                if (_autoFull)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('Pause ab'),
                        Expanded(
                          child: Slider(
                            value: _unlockAfter.clamp(10, 180),
                            min: 10,
                            max: 180,
                            divisions: 17,
                            label: '${_unlockAfter.round()} min',
                            onChanged: (v) => setState(() => _unlockAfter = v),
                            onChangeEnd: (_) => _saveAuto(),
                          ),
                        ),
                        SizedBox(
                            width: 60,
                            child: Text('${_unlockAfter.round()} min',
                                textAlign: TextAlign.end)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$running von ${visible.length} Apps aktiv · Antippen ändert die Stufe',
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
                  ? const Icon(Icons.lock_outline)
                  : _LevelChip(a),
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
      if (a.days7 != null) parts.add('${a.days7}/7 Tage');
      parts.add('benutzt ${formatAgo(a.lastUsed, now)}');
    }
    if (a.system) parts.add('vorinstalliert');
    return parts.join(' · ');
  }
}

class _LevelChip extends StatelessWidget {
  final AppEntry app;
  const _LevelChip(this.app);

  @override
  Widget build(BuildContext context) {
    final color = switch (app.level) {
      Level.keep => Colors.green,
      Level.soft => Colors.blue,
      Level.full => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: app.manual ? Border.all(color: color) : null,
      ),
      child: Text(levelName(app.level),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
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
