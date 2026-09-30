import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../planer/planer_screen.dart';
import '../backtimer/backtimer_screen.dart';
import '../starter/starter_screen.dart';
import '../starter/starter_storage.dart';
import '../starter/starter_models.dart';
import '../diary/diary_screen.dart';
import '../diary/diary_storage.dart';
import '../diary/diary_models.dart';
import '../diary/diary_entry_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../onboarding/tutorial_overlay.dart';
import '../untils/feedback_service.dart';
import '../tools/tools_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD — AppBar + Home-Body + Custom Bottom-NavBar
// ═══════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _settingsKey = GlobalKey();
  final _feedbackKey = GlobalKey();
  final _navKeys = List.generate(5, (_) => GlobalKey());

  OverlayEntry? _tutorialEntry;
  bool _starterActive = false;
  StarterJourney? _journey;
  DiaryEntry? _lastEntry;
  int _diaryCount = 0;
  int _selectedIndex = 0; // 0=Home, 1=Planer, 2=Backtimer, 3=Starter, 4=Tagebuch

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      StarterStorage.load(),
      DiaryStorage.loadAll(),
    ]);
    final journey = results[0] as StarterJourney?;
    final entries = results[1] as List<DiaryEntry>;
    if (mounted) {
      setState(() {
        _journey = journey;
        _starterActive = journey != null && !journey.isCompleted;
        _lastEntry = entries.isNotEmpty ? entries.first : null;
        _diaryCount = entries.length;
      });
    }
  }

  void _switchTab(int index) {
    if (_selectedIndex == index) {
      // Nochmal tippen → zurück zur Home-Übersicht
      setState(() => _selectedIndex = 0);
      _loadData();
    } else {
      setState(() => _selectedIndex = index);
      if (index == 0) _loadData();
    }
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    super.dispose();
  }

  Future<void> _checkTutorial() async {
    if (_tutorialEntry != null) return; // läuft bereits, kein zweites Overlay
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('onboarding_done') ?? false)) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    if (_tutorialEntry != null) return; // Doppel-Aufruf verhindern
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        steps: _buildSteps(),
        onComplete: _finishTutorial,
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  Future<void> _finishTutorial() async {
    _tutorialEntry?.remove();
    _tutorialEntry = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  List<TutorialStep> _buildSteps() => [
        TutorialStep(
          key: _settingsKey,
          emoji: '⚙️',
          title: 'Einstellungen',
          description:
              'Hier kannst du Erinnerungen für deinen Starter einrichten '
              'und das Tutorial jederzeit wiederholen.',
          tapHint: 'Tippe auf das Zahnrad',
        ),
        TutorialStep(
          key: _feedbackKey,
          emoji: '🐛',
          title: 'Fehler melden',
          description:
              'Etwas funktioniert nicht? Tippe hier, beschreibe das Problem '
              'und sende es direkt aus der App – optional mit Screenshot.',
          tapHint: 'Tippe auf das Käfer-Symbol',
        ),
        TutorialStep(
          key: _navKeys[0],
          emoji: '🧮',
          title: 'Mengenrechner',
          description:
              'Gib deine Raumtemperatur ein und erhalte optimale Gärzeiten. '
              'Exportiere den Zeitplan direkt in deinen Kalender.',
          tapHint: 'Tippe auf Mengenrechner',
        ),
        TutorialStep(
          key: _navKeys[1],
          emoji: '📚',
          title: 'Backtimer',
          description:
              'Erstelle eigene Schritt-Sets mit Timern: Autolyse, Dehnen & Falten, '
              'Gare, Backen – alles in einem Rezept.',
          tapHint: 'Tippe auf Backtimer',
        ),
        TutorialStep(
          key: _navKeys[2],
          emoji: '🌱',
          title: 'Starter-Guide',
          description:
              'Dein erster Sauerteig-Starter? Der 7-Tage-Begleiter führt dich '
              'mit täglichen Checklisten und dem Schwimmtest (Float-Test) durch den Prozess.',
          tapHint: 'Tippe auf Starter-Guide',
        ),
        TutorialStep(
          key: _navKeys[3],
          emoji: '📓',
          title: 'Tagebuch',
          description:
              'Halte Fütterungen, Backergebnisse und Beobachtungen fest – '
              'mit Fotos, Temperatur und persönlichen Notizen.',
          tapHint: 'Tippe auf Tagebuch',
        ),
        TutorialStep(
          key: _navKeys[4],
          emoji: '🔧',
          title: 'Tools',
          description:
              'Nützliche Helfer: Hefe/Sauerteig Umrechner und '
              'Discard-Rezepte für deinen Überschuss.',
          tapHint: 'Tippe auf Tools',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScaffold(),
          const PlanerScreen(),
          const BacktimerScreen(),
          const StarterScreen(),
          const DiaryScreen(),
          const ToolsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('🍞 Sauerteig Planer',
            style: TextStyle(color: AppColors.gold)),
        actions: [
          GestureDetector(
            onTap: () => FeedbackService.showReportDialog(context),
            child: SizedBox(
              key: _feedbackKey,
              width: 44,
              height: 44,
              child: const Center(
                child: Icon(Icons.bug_report_outlined,
                    color: AppColors.text2, size: 22),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _checkTutorial();
            },
            child: SizedBox(
              key: _settingsKey,
              width: 44,
              height: 44,
              child: const Center(
                child: Icon(Icons.settings_outlined,
                    color: AppColors.text2, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildHome(),
    );
  }

  // ── Dashboard: Heute-Übersicht ──────────────────────────────────
  Widget _buildHome() {
    final now = DateTime.now();
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day}. ${months[now.month - 1]}';

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Datum-Header ────────────────────────────────────
            Row(children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                      color: AppColors.text3,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (_diaryCount > 0)
                _StatBadge(
                  icon: '📓',
                  label: '$_diaryCount Einträge',
                  color: AppColors.orange,
                ),
            ]),
            const SizedBox(height: 14),

            // ── Starter-Status ─────────────────────────────────
            _StarterStatusCard(
              journey: _journey,
              onTap: () => _switchTab(3),
            ),

            // ── Heutiger Starter-Tag (Checkliste-Vorschau) ─────
            if (_journey != null && !_journey!.isCompleted) ...[
              const SizedBox(height: 12),
              _TodayTasksCard(
                journey: _journey!,
                onTap: () => _switchTab(3),
              ),
            ],

            // ── Letzter Tagebucheintrag ─────────────────────────
            if (_lastEntry != null) ...[
              const SizedBox(height: 20),
              _SectionHeader(
                label: 'Zuletzt notiert',
                actionLabel: 'Alle anzeigen',
                onAction: () => _switchTab(4),
              ),
              const SizedBox(height: 8),
              _LastEntryCard(
                entry: _lastEntry!,
                onTap: () => _switchTab(4),
              ),
              const SizedBox(height: 10),
              // Neuer Eintrag Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    FeedbackService.log('Dashboard → Neuer Tagebuch-Eintrag');
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DiaryEntryEditScreen()),
                    );
                    _loadData();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Neuer Eintrag'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side:
                        BorderSide(color: AppColors.orange.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],

            // ── Willkommen (erster Start) ───────────────────────
            if (_lastEntry == null && _journey == null) ...[
              const SizedBox(height: 20),
              _WelcomeCard(
                onStarterTap: () => _switchTab(3),
                onPlanerTap: () => _switchTab(1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Custom Bottom-NavBar ─────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
              color: AppColors.border.withValues(alpha: 0.6), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavItem(
                navKey: _navKeys[0],
                emoji: '🧮',
                label: 'Planer',
                color: AppColors.blue,
                isActive: _selectedIndex == 1,
                onTap: () {
                  FeedbackService.log('Navigation → Mengenrechner');
                  FeedbackService.setCurrentScreen('Planer');
                  _switchTab(1);
                },
              ),
              _NavItem(
                navKey: _navKeys[1],
                emoji: '⏱️',
                label: 'Backtimer',
                color: AppColors.gold,
                isActive: _selectedIndex == 2,
                onTap: () {
                  FeedbackService.log('Navigation → Backtimer');
                  FeedbackService.setCurrentScreen('Backtimer');
                  _switchTab(2);
                },
              ),
              _NavItem(
                navKey: _navKeys[2],
                emoji: '🌱',
                label: 'Starter',
                color: AppColors.green,
                isActive: _selectedIndex == 3,
                showBadge: _starterActive,
                onTap: () {
                  FeedbackService.log('Navigation → Starter');
                  FeedbackService.setCurrentScreen('Starter');
                  _switchTab(3);
                },
              ),
              _NavItem(
                navKey: _navKeys[3],
                emoji: '📓',
                label: 'Tagebuch',
                color: AppColors.orange,
                isActive: _selectedIndex == 4,
                onTap: () {
                  FeedbackService.log('Navigation → Tagebuch');
                  FeedbackService.setCurrentScreen('Tagebuch');
                  _switchTab(4);
                },
              ),
              _NavItem(
                navKey: _navKeys[4],
                emoji: '🔧',
                label: 'Tools',
                color: AppColors.text2,
                isActive: _selectedIndex == 5,
                onTap: () {
                  FeedbackService.log('Navigation → Tools');
                  FeedbackService.setCurrentScreen('Tools');
                  _switchTab(5);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav-Item ─────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final GlobalKey? navKey;
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showBadge;
  final bool isActive;

  const _NavItem({
    this.navKey,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.showBadge = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          key: navKey,
          alignment: Alignment.center,
          decoration: isActive
              ? BoxDecoration(
                  border: Border(
                      top: BorderSide(color: color, width: 2)),
                  color: color.withValues(alpha: 0.07),
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? color : AppColors.text3,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (showBadge)
                Positioned(
                  top: -8,
                  right: -14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.7),
                          width: 1),
                    ),
                    child: const Text(
                      'Aktiv',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD WIDGETS
// ═══════════════════════════════════════════════════════════════

// ── Starter-Status-Karte ─────────────────────────────────────────
class _StarterStatusCard extends StatelessWidget {
  final StarterJourney? journey;
  final VoidCallback onTap;

  const _StarterStatusCard({required this.journey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final j = journey;

    if (j == null) {
      return _cardShell(
        color: AppColors.green,
        child: const Row(children: [
          Text('🌱', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kein Starter aktiv',
                    style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                SizedBox(height: 2),
                Text('Starte jetzt die 7-Tage-Journey →',
                    style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.text3),
        ]),
      );
    }

    if (j.isCompleted) {
      return _cardShell(
        color: AppColors.green,
        child: Row(children: [
          const Text('✅', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.starterName,
                    style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Starter aktiv — bereit zum Backen',
                    style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.text3),
        ]),
      );
    }

    final day = j.currentDayNumber;
    final totalDays = j.days.length;
    final progress = day / totalDays;
    final todayLog = j.days.isNotEmpty && day <= j.days.length
        ? j.days[day - 1]
        : null;
    final doneCount = todayLog?.checks.values.where((v) => v).length ?? 0;
    final totalCount = todayLog?.checks.length ?? 4;

    return _cardShell(
      color: AppColors.green,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🌱', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.starterName,
                    style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('Tag $day / $totalDays · $doneCount/$totalCount Aufgaben heute',
                    style:
                        const TextStyle(color: AppColors.text2, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.text3),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surface2,
            color: AppColors.green,
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _cardShell({required Color color, required Widget child}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: child,
          ),
        ),
      );
}

// ── Abschnitts-Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.label, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: AppColors.text2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          ),
      ]);
}

// ── Heute-Aufgaben-Karte (Starter-Checkliste-Vorschau) ───────────
class _TodayTasksCard extends StatelessWidget {
  final StarterJourney journey;
  final VoidCallback onTap;

  const _TodayTasksCard({required this.journey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final day = journey.currentDayNumber;
    final log = day >= 1 && day <= journey.days.length
        ? journey.days[day - 1]
        : null;
    if (log == null) return const SizedBox.shrink();

    final done = log.checks.values.where((v) => v).length;
    final total = log.checks.length;
    final allDone = done == total;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: allDone
                    ? AppColors.green.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (allDone ? AppColors.green : AppColors.gold)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(allDone ? '✅' : '📋',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone ? 'Tag $day abgeschlossen!' : 'Tag $day – Aufgaben',
                    style: TextStyle(
                        color: allDone ? AppColors.green : AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$done von $total Aufgaben erledigt',
                    style: const TextStyle(
                        color: AppColors.text2, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.text3, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ── Willkommens-Karte ────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final VoidCallback onStarterTap;
  final VoidCallback onPlanerTap;

  const _WelcomeCard(
      {required this.onStarterTap, required this.onPlanerTap});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Text('🍞', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          const Text(
            'Willkommen beim Sauerteig Planer!',
            style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Starte mit dem 7-Tage-Guide wenn du noch\nkeinen Starter hast, oder berechne direkt\ndeine Gär- und Backzeiten.',
            style: TextStyle(
                color: AppColors.text2, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onStarterTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                ),
                child: const Text('🌱 Starter starten'),
              ),
              OutlinedButton(
                onPressed: onPlanerTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                ),
                child: const Text('🧮 Berechnen'),
              ),
            ],
          ),
        ]),
      );
}

// ── Statistik-Badge ──────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Letzter Eintrag ──────────────────────────────────────────────
class _LastEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;

  const _LastEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = entry.timestamp.day == DateTime.now().day
        ? 'Heute, ${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')} Uhr'
        : '${entry.timestamp.day}.${entry.timestamp.month}.${entry.timestamp.year}';

    final typeIcon = switch (entry.type) {
      DiaryEntryType.feeding => '🫙',
      DiaryEntryType.observation => '🔍',
      DiaryEntryType.baking => '🍞',
      DiaryEntryType.note => '📝',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Text(typeIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.starterName != null)
                    Text(entry.starterName!,
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  Text(
                    entry.text.isNotEmpty ? entry.text : entry.type.name,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(fmt,
                      style: const TextStyle(
                          color: AppColors.text3, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.text3, size: 18),
          ]),
        ),
      ),
    );
  }
}
