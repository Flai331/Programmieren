import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../planer/planer_screen.dart';
import '../baking/recipe_list_screen.dart';
import '../starter/starter_screen.dart';
import '../starter/starter_storage.dart';
import '../starter/starter_models.dart';
import '../diary/diary_screen.dart';
import '../settings/settings_screen.dart';
import '../onboarding/tutorial_overlay.dart';
import '../fehlerbericht.dart';

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
  // Keys liegen direkt auf den Nav-Item-Containern (exakte visuelle Größe)
  final _navKeys = List.generate(4, (_) => GlobalKey());

  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
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
          title: 'Sauerteig-Rechner',
          description:
              'Gib deine Raumtemperatur ein und erhalte optimale Gärzeiten. '
              'Exportiere den Zeitplan direkt in deinen Kalender.',
          tapHint: 'Tippe auf Rechner',
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
              'mit täglichen Checklisten und dem Float-Test durch den Prozess.',
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
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('🍞 Sauerteig Planer',
            style: TextStyle(color: AppColors.gold)),
        actions: [
          // Feedback-Button
          GestureDetector(
            onTap: () => Fehlerbericht.melden(context),
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
          // Einstellungen-Button
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Startseite: einfache Hero-Ansicht ───────────────────────────
  Widget _buildHome() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🍞', style: TextStyle(fontSize: 80)),
          SizedBox(height: 20),
          Text(
            'Sauerteig Planer',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Wähle einen Bereich\nüber die Leiste unten.',
            style: TextStyle(
              color: AppColors.text2,
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Custom Bottom-NavBar ─────────────────────────────────────────
  Widget _buildBottomNav() {
    return FutureBuilder<StarterJourney?>(
      future: StarterStorage.load(),
      builder: (context, snap) {
        final starterActive =
            snap.hasData && snap.data != null && !snap.data!.isCompleted;
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
            child: Row(
              children: [
                _NavItem(
                  navKey: _navKeys[0],
                  emoji: '🧮',
                  label: 'Rechner',
                  color: AppColors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanerScreen()),
                  ),
                ),
                _NavItem(
                  navKey: _navKeys[1],
                  emoji: '📚',
                  label: 'Backtimer',
                  color: AppColors.gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecipeListScreen()),
                  ),
                ),
                _NavItem(
                  navKey: _navKeys[2],
                  emoji: '🌱',
                  label: 'Starter',
                  color: AppColors.green,
                  showBadge: starterActive,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StarterScreen()),
                  ),
                ),
                _NavItem(
                  navKey: _navKeys[3],
                  emoji: '📓',
                  label: 'Tagebuch',
                  color: AppColors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiaryScreen()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  const _NavItem({
    this.navKey,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Unsichtbarer Container mit Key füllt den gesamten Stack-Bereich →
            // gibt dem Tutorial-Overlay die exakte Kachelgröße (volle Breite + Höhe)
            Positioned.fill(
              child: Container(key: navKey),
            ),
            // Zentrierter sichtbarer Inhalt
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // "Aktiv"-Badge oben rechts
            if (showBadge)
              Positioned(
                top: 4,
                right: 12,
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
    );
  }
}
