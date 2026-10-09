import 'dart:async';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'native.dart';

class BatteryPage extends StatefulWidget {
  /// Nur aktualisieren, solange der Reiter sichtbar ist (spart selbst Strom).
  final bool active;
  const BatteryPage({super.key, required this.active});

  @override
  State<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<BatteryPage> with WidgetsBindingObserver {
  BatteryState? _b;
  Timer? _timer;
  bool _resumed = true;

  bool _watcherOn = false;
  bool _watcherRunning = false;
  double _upper = 80;
  double _lower = 20;
  double _maxTemp = 40;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWatcher();
    _sync();
  }

  @override
  void didUpdateWidget(BatteryPage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    final want = widget.active && _resumed;
    if (want && _timer == null) {
      _refresh();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    } else if (!want) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _refresh() async {
    try {
      final b = await Native.battery();
      final s = await Native.status();
      if (!mounted) return;
      setState(() {
        _b = b;
        _watcherRunning = s['watcherRunning'] == true;
      });
    } catch (_) {}
  }

  Future<void> _loadWatcher() async {
    try {
      final w = await Native.watcher();
      if (!mounted) return;
      setState(() {
        _watcherOn = w['enabled'] == true;
        _upper = ((w['upper'] as num?) ?? 80).toDouble();
        _lower = ((w['lower'] as num?) ?? 20).toDouble();
        _maxTemp = ((w['maxTemp'] as num?) ?? 40).toDouble();
      });
    } catch (_) {}
  }

  Future<void> _saveWatcher() async {
    await Native.setWatcher({
      'enabled': _watcherOn,
      'upper': _upper.round(),
      'lower': _lower.round(),
      'maxTemp': _maxTemp.round(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) return const Center(child: CircularProgressIndicator());
    final cs = Theme.of(context).colorScheme;
    final advice = batteryAdvice(b,
        upper: _upper.round(), lower: _lower.round(), maxTemp: _maxTemp.round());

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LevelCard(b: b),
          const SizedBox(height: 12),
          for (final a in advice) _AdviceTile(a),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _Stat('Temperatur', '${b.temp.toStringAsFixed(1)} °C',
                      Icons.thermostat),
                  _Stat('Spannung',
                      '${(b.voltageMv / 1000).toStringAsFixed(2)} V', Icons.bolt),
                  _Stat('Zustand', healthText(b.health), Icons.health_and_safety),
                  if (b.currentMa != null)
                    _Stat('Strom', '${b.currentMa} mA', Icons.electric_meter),
                  if (b.cycles != null)
                    _Stat('Ladezyklen', '${b.cycles}', Icons.loop),
                  if (b.technology.isNotEmpty)
                    _Stat('Typ', b.technology, Icons.memory),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Akku-Wächter'),
                  subtitle: Text(_watcherOn
                      ? (_watcherRunning
                          ? 'Aktiv – warnt per Benachrichtigung'
                          : 'Startet …')
                      : 'Warnt beim Laden ab der Ladegrenze, bei wenig Akku und bei Hitze. '
                          'Verbraucht praktisch nichts (kein Timer, kein GPS).'),
                  value: _watcherOn,
                  onChanged: (v) {
                    setState(() => _watcherOn = v);
                    _saveWatcher();
                  },
                ),
                if (_watcherOn) ...[
                  _SliderRow(
                    label: 'Ladegrenze',
                    value: _upper,
                    min: 60,
                    max: 100,
                    divisions: 8,
                    unit: ' %',
                    onChanged: (v) => setState(() => _upper = v),
                    onChangeEnd: (_) => _saveWatcher(),
                  ),
                  _SliderRow(
                    label: 'Warnen unter',
                    value: _lower,
                    min: 10,
                    max: 40,
                    divisions: 6,
                    unit: ' %',
                    onChanged: (v) => setState(() => _lower = v),
                    onChangeEnd: (_) => _saveWatcher(),
                  ),
                  _SliderRow(
                    label: 'Hitzewarnung ab',
                    value: _maxTemp,
                    min: 35,
                    max: 50,
                    divisions: 15,
                    unit: ' °C',
                    onChanged: (v) => setState(() => _maxTemp = v),
                    onChangeEnd: (_) => _saveWatcher(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Keine Warnungen? Benachrichtigungen für Akku-Schoner erlauben.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final BatteryState b;
  const _LevelCard({required this.b});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final level = b.level.clamp(0, 100);
    final color = level <= 20
        ? Colors.red
        : level <= 40
            ? Colors.orange
            : Colors.green;
    final state = b.charging
        ? 'Lädt${b.plug.isNotEmpty ? ' über ${b.plug}' : ''}'
        : 'Entlädt';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$level',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 4),
                  child: Text('%', style: TextStyle(fontSize: 28)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(b.charging ? Icons.battery_charging_full : Icons.battery_std,
                        size: 36, color: color),
                    Text(state),
                    if (b.powerSave)
                      Text('Energiesparen an',
                          style: TextStyle(color: cs.primary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: level / 100,
                minHeight: 14,
                color: color,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceTile extends StatelessWidget {
  final Advice a;
  const _AdviceTile(this.a);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (a.severity) {
      Severity.danger => (Icons.warning_amber, Colors.red),
      Severity.warn => (Icons.info_outline, Colors.orange),
      Severity.info => (Icons.check_circle_outline, Colors.green),
    };
    return Card(
      color: color.withOpacity(0.12),
      child: ListTile(leading: Icon(icon, color: color), title: Text(a.text)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: '${value.round()}$unit',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
              width: 52,
              child: Text('${value.round()}$unit', textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
