import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

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
      return const Scaffold(
        backgroundColor: RiegelColors.bgBase,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riegel')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(RiegelSpacing.s4),
          children: [
            if (!_accessibility) ...[
              _AccessibilityWarning(
                onEnable: widget.channel.openAccessibilitySettings,
              ),
              const SizedBox(height: RiegelSpacing.s4),
            ],
            _StatusTile(status: status),
            const SizedBox(height: RiegelSpacing.s6),
            _ModeSection(
              status: status,
              onModeChanged: (mode) => _setMode(mode, status.durationMinutes),
              onDurationChanged: (minutes) => _setMode(LockMode.timer, minutes),
            ),
            const SizedBox(height: RiegelSpacing.s6),
            _AppsRow(
              status: status,
              onTap: status.locked ? null : () => _pickApps(status),
            ),
            if (status.locked) ...[
              const SizedBox(height: RiegelSpacing.s3),
              Text(
                'Einstellungen sind während einer Sperre gesperrt.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: RiegelColors.fg4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Einzige Lage, für die es rot gibt: der Dienst ist aus, die Sperre greift nicht.
class _AccessibilityWarning extends StatelessWidget {
  const _AccessibilityWarning({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        RiegelSpacing.s4,
        RiegelSpacing.s3,
        RiegelSpacing.s3,
        RiegelSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: RiegelColors.dangerDim,
        borderRadius: BorderRadius.circular(RiegelRadii.lg),
        border: Border.all(color: const Color(0x59FF6B7A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: RiegelColors.danger),
          const SizedBox(width: RiegelSpacing.s3),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sperre nicht wirksam',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RiegelColors.dangerText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bedienungshilfe ist ausgeschaltet',
                  style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEnable, child: const Text('Anschalten')),
        ],
      ),
    );
  }
}

/// Beantwortet die einzige Frage, mit der man die App öffnet: sperrt sie gerade?
///
/// Gesperrt bekommt Rahmenfarbe und Bernstein, offen nur einen dezent getönten
/// Rahmen — offen ist der Ruhezustand und muss nicht um Aufmerksamkeit bitten.
class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status});

  final LockStatus status;

  @override
  Widget build(BuildContext context) {
    final locked = status.locked;
    return Container(
      padding: const EdgeInsets.all(RiegelSpacing.s5),
      decoration: BoxDecoration(
        color: RiegelColors.bgElev1,
        borderRadius: BorderRadius.circular(RiegelRadii.xl),
        border: Border.all(
          color: locked ? const Color(0x59F5A65B) : const Color(0x4762D9E8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: locked
                  ? RiegelColors.lockedTint
                  : RiegelColors.accentTint,
              borderRadius: BorderRadius.circular(RiegelRadii.lg),
            ),
            child: Icon(
              locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 24,
              color: locked ? RiegelColors.locked : RiegelColors.accent,
            ),
          ),
          const SizedBox(width: RiegelSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? 'Riegel zu' : 'Riegel offen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: locked ? RiegelColors.lockedBright : RiegelColors.fg1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(status),
                  style: const TextStyle(fontSize: 13, color: RiegelColors.fg2),
                ),
              ],
            ),
          ),
        ],
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

class _ModeSection extends StatelessWidget {
  const _ModeSection({
    required this.status,
    required this.onModeChanged,
    required this.onDurationChanged,
  });

  final LockStatus status;
  final ValueChanged<LockMode> onModeChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final locked = status.locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MODUS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: locked ? RiegelColors.fg4 : RiegelColors.fg3,
          ),
        ),
        const SizedBox(height: RiegelSpacing.s2),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<LockMode>(
            segments: const [
              ButtonSegment(
                value: LockMode.open,
                label: Text('Bis Scan'),
                icon: Icon(Icons.all_inclusive, size: 18),
              ),
              ButtonSegment(
                value: LockMode.timer,
                label: Text('Auf Zeit'),
                icon: Icon(Icons.timer_outlined, size: 18),
              ),
            ],
            selected: {status.mode},
            showSelectedIcon: false,
            onSelectionChanged: locked
                ? null
                : (selection) => onModeChanged(selection.first),
          ),
        ),
        if (status.mode == LockMode.timer) ...[
          const SizedBox(height: RiegelSpacing.s2),
          Slider(
            value: status.durationMinutes.toDouble(),
            min: 15,
            max: 480,
            divisions: 31,
            onChanged: locked
                ? null
                : (value) => onDurationChanged(value.round()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RiegelSpacing.s1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sperrdauer',
                  style: TextStyle(
                    fontSize: 12,
                    color: locked ? RiegelColors.fg4 : RiegelColors.fg3,
                  ),
                ),
                Text(
                  '${status.durationMinutes} min',
                  style: TextStyle(
                    fontFamily: kMonoFamily,
                    fontSize: 12,
                    color: locked ? RiegelColors.fg4 : RiegelColors.fg1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AppsRow extends StatelessWidget {
  const _AppsRow({required this.status, required this.onTap});

  final LockStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status.locked;
    final count = status.blockedPackages.length;
    return Material(
      color: RiegelColors.bgElev1,
      borderRadius: BorderRadius.circular(RiegelRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RiegelRadii.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RiegelSpacing.s4,
            vertical: RiegelSpacing.s4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RiegelRadii.lg),
            border: Border.all(color: RiegelColors.borderDefault),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gesperrte Apps',
                      style: TextStyle(
                        fontSize: 14,
                        color: locked ? RiegelColors.fg4 : RiegelColors.fg1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked ? '$count gesperrt' : '$count ausgewählt',
                      style: const TextStyle(
                        fontSize: 12,
                        color: RiegelColors.fg3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: locked ? RiegelColors.fg4 : RiegelColors.fg3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
