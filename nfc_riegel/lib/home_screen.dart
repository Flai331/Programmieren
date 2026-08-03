import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';

/// Status, Modus-Einstellung und Blockliste.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.channel = const RiegelChannel()});

  final RiegelChannel channel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LockStatus? _status;
  bool _accessibility = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    final accessibility = await widget.channel.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _status = status;
        _accessibility = accessibility;
      });
    }
  }

  Future<void> _pickApps(LockStatus status) async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(selected: status.blockedPackages),
      ),
    );
    if (picked != null) {
      await widget.channel.setBlockedPackages(picked);
      await _refresh();
    }
  }

  Future<void> _setMode(LockMode mode, int minutes) async {
    await widget.channel.setMode(mode, minutes);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riegel')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_accessibility)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('Sperre nicht wirksam'),
                  subtitle: const Text('Bedienungshilfe ist ausgeschaltet'),
                  trailing: TextButton(
                    onPressed: widget.channel.openAccessibilitySettings,
                    child: const Text('Anschalten'),
                  ),
                ),
              ),
            Card(
              child: ListTile(
                leading: Icon(status.locked ? Icons.lock : Icons.lock_open, size: 40),
                title: Text(
                  status.locked ? 'Riegel zu' : 'Riegel offen',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(_subtitle(status)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Modus', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<LockMode>(
              segments: const [
                ButtonSegment(
                  value: LockMode.open,
                  label: Text('Bis Scan'),
                  icon: Icon(Icons.all_inclusive),
                ),
                ButtonSegment(
                  value: LockMode.timer,
                  label: Text('Auf Zeit'),
                  icon: Icon(Icons.timer_outlined),
                ),
              ],
              selected: {status.mode},
              onSelectionChanged: status.locked
                  ? null
                  : (selection) =>
                      _setMode(selection.first, status.durationMinutes),
            ),
            if (status.mode == LockMode.timer)
              Slider(
                value: status.durationMinutes.toDouble(),
                min: 15,
                max: 480,
                divisions: 31,
                label: '${status.durationMinutes} min',
                onChanged: status.locked
                    ? null
                    : (value) => _setMode(LockMode.timer, value.round()),
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Gesperrte Apps'),
              subtitle: Text('${status.blockedPackages.length} ausgewählt'),
              trailing: const Icon(Icons.chevron_right),
              onTap: status.locked ? null : () => _pickApps(status),
            ),
            if (status.locked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Einstellungen sind während einer Sperre gesperrt.'),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(LockStatus status) {
    if (!status.locked) return 'Chip scannen, um zu sperren';
    final endsAt = status.endsAt;
    if (status.mode == LockMode.timer && endsAt != null) {
      final h = endsAt.hour.toString().padLeft(2, '0');
      final m = endsAt.minute.toString().padLeft(2, '0');
      return 'Frei ab $h:$m oder nach erneutem Scan';
    }
    return 'Frei nach erneutem Scan';
  }
}
