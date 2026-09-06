import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'lock_status.dart';
import 'profile_screen.dart';
import 'riegel_channel.dart';
import 'screen_time_tab.dart';
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
  bool _adminActive = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    final accessibility = await widget.channel.isAccessibilityEnabled();
    final admin = await widget.channel.isAdminActive();
    if (mounted) {
      setState(() {
        _status = status;
        _accessibility = accessibility;
        _adminActive = admin;
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
        builder: (_) =>
            ProfileScreen(profile: profile, channel: widget.channel),
      ),
    );
    await _refresh();
  }

  /// Startet oder verlängert eine Zeitsperre. Vorher ein Dialog, der beim Namen
  /// nennt, worauf man sich einlässt — die Sperre lässt sich nicht zurücknehmen.
  Future<void> _startLock(ProfileInfo profile, LockStatus status) async {
    final laufend = status.timeLockFor(profile.id);
    // „Bis Scan" ergibt eine Chipsperre: sie hat kein Ende, das man ausrechnen
    // könnte, und wird deshalb an keiner Uhrzeit gemessen.
    final chipsperre = profile.mode == LockMode.open;
    final ende = chipsperre
        ? null
        : profile.mode == LockMode.until
        ? profile.untilAt
        : DateTime.now().add(Duration(minutes: profile.durationMinutes));

    if (!chipsperre && (ende == null || ende.isBefore(DateTime.now()))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Zeitpunkt liegt in der Vergangenheit.'),
        ),
      );
      return;
    }

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(laufend == null ? 'Sperren?' : 'Verlängern?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chipsperre
                  ? 'Sperrt ${profile.name}, bis du den Chip erneut scannst.\n'
                        'Ohne Chip öffnet nur der Notfall-Code.'
                  : 'Sperrt ${profile.name} bis ${_uhrzeit(ende!)}.\n'
                        'Vorher öffnet nur ein Generalschlüssel oder der Notfall-Code.',
            ),
            // Bei einer Chipsperre öffnet jeder Chip dieses Profils, nicht nur
            // der Generalschlüssel — gewarnt wird erst, wenn gar keiner da ist.
            if (chipsperre && status.tags.isEmpty) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Kein Chip angelernt — dann öffnet nur der Notfall-Code.',
                style: TextStyle(color: RiegelColors.danger),
              ),
            ],
            if (!chipsperre && !status.hasMasterTag) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Kein Generalschlüssel angelernt — dann öffnet nur der Notfall-Code.',
                style: TextStyle(color: RiegelColors.danger),
              ),
            ],
            if (!status.hasCode) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Kein Notfall-Code gesetzt.',
                style: TextStyle(color: RiegelColors.danger),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(laufend == null ? 'Sperren' : 'Verlängern'),
          ),
        ],
      ),
    );

    if (bestaetigt != true) return;

    final outcome = await widget.channel.startLock(profile.id);
    if (!mounted) return;
    if (outcome == 'UNTIL_IN_PAST') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Zeitpunkt liegt in der Vergangenheit.'),
        ),
      );
    } else if (outcome == 'ALREADY_RUNNING') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Läuft bereits und endet nicht früher.')),
      );
    }
    await _refresh();
  }

  /// Der Deinstallationsschutz braucht einen Notausgang für den Besitzer.
  /// Ohne ihn kommt man an die App nur noch über die Systemeinstellungen —
  /// und wer die nicht findet, sitzt fest.
  Future<void> _releaseAdmin() async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Administratorrecht abgeben?'),
        content: const Text(
          'Danach lässt sich Riegel wieder normal deinstallieren — der Schutz '
          'davor entfällt. Du kannst das Recht in der Einrichtung jederzeit '
          'wieder erteilen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abgeben'),
          ),
        ],
      ),
    );
    if (bestaetigt != true) return;

    final ok = await widget.channel.releaseAdmin();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geht nicht, solange etwas gesperrt ist.'),
        ),
      );
    }
    await _refresh();
  }

  String _uhrzeit(DateTime moment) {
    final h = moment.hour.toString().padLeft(2, '0');
    final m = moment.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Vor dem Öffnen des Dialogs den aktuellen Sperrzustand anhängen — sonst
  /// steht im Bericht nur, dass etwas nicht ging, aber nicht bei welcher
  /// Einstellung.
  Future<void> _reportProblem() async {
    final diagnostics = await widget.channel.getDiagnostics();
    for (final entry in diagnostics.entries) {
      FeedbackService.setSnapshot(entry.key, entry.value);
    }
    if (!mounted) return;
    await FeedbackService.showReportDialog(context);
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

  Future<void> _openCalendar(LockStatus status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(status: status, channel: widget.channel),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riegel'),
          actions: [
            IconButton(
              tooltip: 'Fehler melden',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: _reportProblem,
            ),
          ],
          // Der erste Reiter heißt „Sperre", nicht „Riegel" — die Kopfzeile
          // trägt schon den Namen der App.
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sperre'),
              Tab(text: 'Screenzeit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
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
                      TextButton(
                        onPressed: _addProfile,
                        child: const Text('Neu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: RiegelSpacing.s2),
                  for (final profile in status.profiles) ...[
                    _ProfileRow(
                      profile: profile,
                      locked: status.isProfileLocked(profile.id),
                      timeLock: status.timeLockFor(profile.id),
                      onTap: () => _editProfile(profile),
                      onLock: () => _startLock(profile, status),
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
                  const SizedBox(height: RiegelSpacing.s3),
                  _NavRow(
                    title: 'Kalender',
                    subtitle: status.calendar.enabled
                        ? '${status.calendar.calendarRules.length} Kalender zugeordnet'
                        : 'aus',
                    enabled: !status.locked,
                    onTap: () => _openCalendar(status),
                  ),
                  if (_adminActive) ...[
                    const SizedBox(height: RiegelSpacing.s8),
                    TextButton(
                      onPressed: _releaseAdmin,
                      style: TextButton.styleFrom(
                        foregroundColor: RiegelColors.fg3,
                      ),
                      child: const Text('Administratorrecht abgeben'),
                    ),
                  ],
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
            ScreenTimeTab(channel: widget.channel, tabIndex: 1),
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
              color: locked ? RiegelColors.lockedTint : RiegelColors.accentTint,
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
                    color: locked
                        ? RiegelColors.lockedBright
                        : RiegelColors.fg1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(status),
                  style: const TextStyle(fontSize: 13, color: RiegelColors.fg2),
                ),
                // Ruhe steht unter der Sperre, nicht daneben: sie kann auch
                // ohne Sperre gelten, ist aber nie die Hauptauskunft.
                if (status.quietNow) ...[
                  const SizedBox(height: 3),
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 13,
                        color: RiegelColors.fg3,
                      ),
                      SizedBox(width: RiegelSpacing.s1),
                      Text(
                        'Ruhe — Anrufe sind stumm',
                        style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(LockStatus status) {
    // Die Freigabe geht allem voraus: sie ist der Grund, aus dem gerade nichts
    // sperrt, und nennt zugleich den Zeitpunkt, ab dem es wieder sperrt.
    final freigabe = status.releaseEndsAt;
    if (freigabe != null) {
      final profil = status.profiles
          .where((p) => p.id == status.releaseProfileId)
          .map((p) => p.name)
          .join(', ');
      return '$profil — frei bis ${_hhmm(freigabe)}';
    }

    // Ein laufender Termin ist die aussagekräftigste Auskunft: er nennt den
    // Grund, nicht nur die Uhrzeit.
    final termine = status.calendar.activeWindows;
    if (termine.isNotEmpty) {
      final termin = termine.first;
      return '${termin.title} — frei ab ${_hhmm(termin.endsAt)}';
    }

    if (!status.locked) return 'Chip scannen oder Profil sperren';

    final ende = status.earliestEnd;
    final anzahl = status.lockedProfileIds.length;
    if (ende == null) {
      final profil = status.profiles
          .where((p) => status.isProfileLocked(p.id))
          .map((p) => p.name)
          .join(', ');
      return '$profil — frei nach erneutem Scan';
    }

    if (anzahl > 1) return '$anzahl Sperren — frei ab ${_hhmm(ende)}';

    final profil = status.profiles
        .where((p) => status.isProfileLocked(p.id))
        .map((p) => p.name)
        .join(', ');
    return '$profil — frei ab ${_hhmm(ende)}';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.locked,
    required this.timeLock,
    required this.onTap,
    required this.onLock,
  });

  final ProfileInfo profile;
  final bool locked;
  final TimeLockInfo? timeLock;
  final VoidCallback onTap;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (profile.mode) {
      LockMode.open => 'bis Scan',
      LockMode.timer => '${profile.durationMinutes} min',
      LockMode.until => 'bis Zeitpunkt',
    };
    final zeitsperre = timeLock;
    final subtitle = zeitsperre == null
        ? '${profile.blockedPackages.length} Apps · $modeLabel'
        : '${profile.blockedPackages.length} Apps · frei ab '
              '${zeitsperre.endsAt.hour.toString().padLeft(2, '0')}:'
              '${zeitsperre.endsAt.minute.toString().padLeft(2, '0')}';

    return _NavRow(
      title: profile.name,
      subtitle: subtitle,
      enabled: !locked,
      onTap: onTap,
      trailingText: locked && profile.mode == LockMode.open ? 'sperrt' : null,
      // Auch „Bis Scan" lässt sich ohne Chip zumachen — nur eben nicht ohne
      // Chip wieder auf. Läuft die Chipsperre schon, gibt es nichts zu drücken.
      action: locked && profile.mode == LockMode.open
          ? null
          : _RowAction(
              label: zeitsperre == null ? 'Sperren' : 'Verlängern',
              onPressed: onLock,
            ),
    );
  }
}

class _RowAction {
  const _RowAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailingText,
    this.action,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final String? trailingText;
  final _RowAction? action;

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
              if (action != null)
                TextButton(
                  onPressed: action!.onPressed,
                  child: Text(action!.label),
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
