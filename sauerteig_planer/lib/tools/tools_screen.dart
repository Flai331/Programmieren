// ═══════════════════════════════════════════════════════════════
//  TOOLS — Nützliche kleine Helfer
//  lib/tools/tools_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../planer/hefe_rechner_screen.dart';
import '../untils/discard_recipes.dart';
import '../untils/feedback_service.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  double _discardAmount = 100;

  @override
  void initState() {
    super.initState();
    FeedbackService.setCurrentScreen('Tools');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('🔧 Tools',
            style: TextStyle(color: AppColors.gold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: AppColors.text2),
            tooltip: 'Fehler melden',
            onPressed: () => FeedbackService.showReportDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hefe / Sauerteig Rechner ──────────────────────
            _SectionHeader(label: 'Umrechner'),
            const SizedBox(height: 8),
            _ToolCard(
              emoji: '⚖️',
              title: 'Hefe / Sauerteig Rechner',
              description: 'Hefe und Sauerteig gegenseitig umrechnen — '
                  'Frischhefe, Trockenhefe und Starter.',
              color: AppColors.blue,
              onTap: () {
                FeedbackService.log('Tools → Hefe/Sauerteig Rechner');
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HefeRechnerScreen()));
              },
            ),
            const SizedBox(height: 24),

            // ── Discard-Rezepte ───────────────────────────────
            _SectionHeader(label: 'Discard-Rezepte'),
            const SizedBox(height: 8),

            // Menge-Regler
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.kitchen, color: AppColors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Überschuss: ${_discardAmount.round()} g',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                _AdjBtn(icon: Icons.remove,
                    onTap: () => setState(() =>
                        _discardAmount = (_discardAmount - 10).clamp(10, 500))),
                const SizedBox(width: 6),
                _AdjBtn(icon: Icons.add,
                    onTap: () => setState(() =>
                        _discardAmount = (_discardAmount + 10).clamp(10, 500))),
              ]),
            ),
            const SizedBox(height: 12),

            // Rezept-Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kDiscardRecipes.entries.map((e) {
                final recipe = e.value;
                return _RecipeChip(
                  emoji: recipe.emoji,
                  label: recipe.name
                      .replaceFirst('Sauerteig-', '')
                      .replaceFirst('Überschuss (Discard)', 'Discard'),
                  onTap: () => showDiscardRecipe(
                      context, e.key, _discardAmount.round()),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hilfwidgets ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
            color: AppColors.text2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9),
      );
}

class _ToolCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.text2, fontSize: 12, height: 1.4)),
              ]),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6), size: 20),
          ]),
        ),
      ),
    );
  }
}

class _RecipeChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _RecipeChip({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _AdjBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AdjBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 16, color: AppColors.green),
      ),
    );
  }
}
