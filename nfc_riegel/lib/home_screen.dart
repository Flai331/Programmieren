import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'profile_screen.dart';
import 'riegel_channel.dart';
import 'tags_screen.dart';
import 'theme.dart';

/// Status, Profile und Chips.
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

  Future<void> _addProfile() async {
    await widget.channel.addProfile('Neues Profil');
    await _refresh();
  }

  Future<void> _editProfile(ProfileInfo profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(profile: profile, channel: widget.channel),
      ),
    );
    await _refresh();
  }

  Future<void> _openTags(LockStatus status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagsScreen(status: status, channel: widget.channel),
      ),
    );
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROFILE',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                TextButton(onPressed: _addProfile, child: const Text('Neu')),
              ],
            ),
            const SizedBox(height: RiegelSpacing.s2),
            for (final profile in status.profiles) ...[
              _ProfileRow(
                profile: profile,
                locked: status.isProfileLocked(profile.id),
                onTap: () => _editProfile(profile),
              ),
              const SizedBox(height: RiegelSpacing.s2),
            ],
            const SizedBox(height: RiegelSpacing.s4),
            _NavRow(
              title: 'Chips',
              subtitle: '${status.tags.length} angelernt',
              enabled: !status.locked,
              onTap: () => _openTags(status),
            ),
            if (status.tags.isEmpty) ...[
              const SizedBox(height: RiegelSpacing.s3),
              Text(
                'Kein Chip angelernt — nur der Notfall-Code öffnet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: RiegelColors.danger,
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
    final profile = status.activeProfile;
    if (profile == null) return 'Chip scannen, um zu sperren';
    final endsAt = status.endsAt;
    if (endsAt != null) {
      final h = endsAt.hour.toString().padLeft(2, '0');
      final m = endsAt.minute.toString().padLeft(2, '0');
      return '${profile.name} — frei ab $h:$m oder nach Scan';
    }
    return '${profile.name} — frei nach erneutem Scan';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.locked,
    required this.onTap,
  });

  final ProfileInfo profile;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (profile.mode) {
      LockMode.open => 'bis Scan',
      LockMode.timer => '${profile.durationMinutes} min',
      LockMode.until => 'bis Zeitpunkt',
    };
    return _NavRow(
      title: profile.name,
      subtitle: '${profile.blockedPackages.length} Apps · $modeLabel',
      enabled: !locked,
      onTap: onTap,
      trailingText: locked ? 'sperrt' : null,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailingText,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiegelColors.bgElev1,
      borderRadius: BorderRadius.circular(RiegelRadii.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(RiegelRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(RiegelSpacing.s4),
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
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? RiegelColors.fg1 : RiegelColors.fg4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: RiegelColors.fg3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RiegelColors.locked,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: enabled ? RiegelColors.fg3 : RiegelColors.fg4,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
